import 'dart:async';

import 'package:dio/dio.dart';
import 'package:gel_rule_app/core/errors/app_exception.dart';
import 'package:gel_rule_app/core/models/post.dart';
import 'package:gel_rule_app/core/models/provider_diagnostics.dart';
import 'package:gel_rule_app/core/models/provider_health.dart';
import 'package:gel_rule_app/core/models/top_period_filter.dart';
import 'package:gel_rule_app/core/utils/result.dart';
import 'package:gel_rule_app/features/providers/data/provider_repository.dart';
import 'package:gel_rule_app/sources/interfaces/content_provider.dart';

import 'provider_soft_retry_result.dart';
import 'tag_group_splitter.dart';

/// Orchestrates concurrent search across multiple booru providers, FNV-1a
/// result interleaving, per-provider timeout gating, and transient error soft-retries.
class ProviderSearchCoordinator {
  ProviderSearchCoordinator(this._repository);

  final ProviderRepository _repository;
  final Set<String> _softRetryKeys = {};
  final _softRetryController =
      StreamController<ProviderSoftRetryResult>.broadcast();

  static const defaultSearchTimeoutSeconds = 14;

  Stream<ProviderSoftRetryResult> get softRetryResults =>
      _softRetryController.stream;

  Future<Result<List<Post>>> searchAcrossProviders({
    required List<ContentProvider> activeFeedProviders,
    required Map<String, int> providerTimeouts,
    required List<String> tags,
    required int page,
    int limit = 50,
    String? rating,
    String? providerId,
    TopPeriodFilter topPeriod = TopPeriodFilter.none,
    CancelToken? cancelToken,
  }) async {
    var providers = activeFeedProviders;
    if (providerId != null) {
      providers =
          providers.where((provider) => provider.id == providerId).toList();
    }

    final tagGroups = TagGroupSplitter.split(tags);

    if (tagGroups.length <= 1) {
      final effectiveTags = tagGroups.isEmpty ? tags : tagGroups.first;
      return _searchForTagGroup(
        providers: providers,
        providerTimeouts: providerTimeouts,
        tags: effectiveTags,
        page: page,
        limit: limit,
        rating: rating,
        providerId: providerId,
        topPeriod: topPeriod,
        cancelToken: cancelToken,
      );
    }

    // Multiple independent tag groups: query each tag group as if other tags are not present, then interleave
    final seen = <String>{};
    final groupPerLimit = (limit / tagGroups.length).ceil().clamp(10, 50);
    final groupFutures = tagGroups.map((groupTags) {
      return _searchForTagGroup(
        providers: providers,
        providerTimeouts: providerTimeouts,
        tags: groupTags,
        page: page,
        limit: groupPerLimit,
        rating: rating,
        providerId: providerId,
        topPeriod: topPeriod,
        cancelToken: cancelToken,
      );
    }).toList(growable: false);

    final results = await Future.wait(groupFutures);
    final validGroupPosts = <List<Post>>[];
    for (final res in results) {
      if (res is Success<List<Post>>) {
        validGroupPosts.add(res.data);
      }
    }

    final interleaved = _interleaveTagGroupResults(validGroupPosts, seen);
    return Success(interleaved);
  }

  Future<Result<List<Post>>> _searchForTagGroup({
    required List<ContentProvider> providers,
    required Map<String, int> providerTimeouts,
    required List<String> tags,
    required int page,
    required int limit,
    required String? rating,
    required String? providerId,
    required TopPeriodFilter topPeriod,
    CancelToken? cancelToken,
  }) async {
    final cleanTags = tags
        .map((t) => t.trim())
        .where((t) => t.isNotEmpty && t.toLowerCase() != 'and')
        .toList(growable: false);

    final seen = <String>{};
    final providerFutures = providers.map((provider) async {
      try {
        final searchTimeout = Duration(
          seconds: providerTimeouts[provider.id] ?? defaultSearchTimeoutSeconds,
        );
        // Per-provider child token: cancelling it on timeout (or when the
        // caller cancels) must not abort the sibling providers sharing the
        // caller's token.
        final searchToken = CancelToken();
        if (cancelToken != null) {
          unawaited(cancelToken.whenCancel.then((_) {
            if (!searchToken.isCancelled) {
              searchToken.cancel('parent cancelled');
            }
          }));
        }
        final limitProvider =
            provider is TagLimitProvider ? (provider as TagLimitProvider) : null;
        final effectiveTags = (limitProvider != null &&
                cleanTags.length > limitProvider.maxSearchTags)
            ? cleanTags
                .take(limitProvider.maxSearchTags)
                .toList(growable: false)
            : cleanTags;
        final providerPosts = await provider
            .searchPosts(
              tags: effectiveTags,
              page: page,
              limit: limit,
              rating: rating,
              topPeriod: topPeriod,
              cancelToken: searchToken,
            )
            .timeout(searchTimeout, onTimeout: () {
          // Abandoning without cancelling left the request running until the
          // provider's own (longer) timeout, holding sockets.
          searchToken.cancel('search timeout');
          return const <Post>[];
        });
        unawaited(_repository.saveDiagnostics(
          ProviderDiagnostics(
            providerId: provider.id,
            lastSearchAt: DateTime.now(),
            lastResultCount: providerPosts.length,
          ),
        ));
        return providerPosts;
      } catch (error) {
        // User-initiated cancellation is not a provider failure: skip the
        // offline marking and soft retry entirely.
        final cancelled = (cancelToken?.isCancelled ?? false) ||
            (error is DioException && error.type == DioExceptionType.cancel);
        if (cancelled) {
          return const <Post>[];
        }
        final errorMsg = error is AppException
            ? error.message
            : (error is DioException
                ? (error.message ?? error.toString())
                : error.toString());
        unawaited(_repository.saveDiagnostics(
          ProviderDiagnostics(
            providerId: provider.id,
            lastSearchAt: DateTime.now(),
            lastResultCount: 0,
            lastErrorMessage: errorMsg,
          ),
        ));
        // A transient failure (timeout, 429/5xx) must not flip the provider
        // to offline on the first hiccup — the soft retry marks it online
        // again when it succeeds. Deterministic errors (bad API key, deleted
        // resource) still surface as offline immediately.
        final isQueryValidationError = error is DioException &&
            error.response?.statusCode == 422;
        if (!_isRetryableError(error) && !isQueryValidationError) {
          unawaited(_repository.saveHealth(
            ProviderHealth(
              providerId: provider.id,
              status: ProviderStatus.offline,
              pingMs: 0,
              lastCheckedAt: DateTime.now(),
              errorMessage: errorMsg,
            ),
          ));
        }
        if (_isRetryableError(error)) {
          _scheduleSoftSearchRetry(
            provider,
            tags: tags,
            page: page,
            limit: limit,
            rating: rating,
            topPeriod: topPeriod,
            cancelToken: cancelToken,
          );
        }
        return const <Post>[];
      }
    }).toList(growable: false);

    final rawResults = await Future.wait(providerFutures);
    final providerResults =
        rawResults.where((list) => list.isNotEmpty).toList(growable: false);
    final posts = providerId == null
        ? _interleaveProviderResults(providerResults, seen)
        : _flattenProviderResults(providerResults, seen);
    return Success(posts);
  }

  List<Post> _interleaveTagGroupResults(
      List<List<Post>> groupResults, Set<String> seen) {
    final combined = <Post>[];
    var hasMore = true;
    var index = 0;

    while (hasMore) {
      hasMore = false;
      for (final group in groupResults) {
        if (index < group.length) {
          hasMore = true;
          final post = group[index];
          if (seen.add(post.cacheKey)) {
            combined.add(post);
          }
        }
      }
      index++;
    }

    return combined;
  }

  List<Post> _flattenProviderResults(
      List<List<Post>> results, Set<String> seen) {
    final posts = <Post>[];
    for (final providerPosts in results) {
      for (final post in providerPosts) {
        if (seen.add(post.cacheKey)) posts.add(post);
      }
    }
    return posts;
  }

  List<Post> _interleaveProviderResults(
    List<List<Post>> results,
    Set<String> seen,
  ) {
    final posts = <Post>[];
    for (final providerPosts in results) {
      for (final post in providerPosts) {
        if (seen.add(post.cacheKey)) posts.add(post);
      }
    }
    posts.sort((a, b) => _mixKey(a).compareTo(_mixKey(b)));
    return posts;
  }

  // Deterministic rank used to interleave results from different providers:
  // FNV-1a over cacheKey yields a stable, provider-agnostic shuffle that is
  // consistent across paginated refreshes, so users don't see blocks from a
  // single provider grouped together.
  static int _mixKey(Post post) {
    var hash = 0x811c9dc5;
    for (final code in post.cacheKey.codeUnits) {
      hash ^= code;
      hash = (hash * 0x01000193) & 0x7fffffff;
    }
    return hash;
  }

  /// Returns true when re-sending the same request could plausibly succeed.
  /// Timeouts, connection failures and 429/5xx are transient; other 4xx
  /// responses (bad API key, deleted resource) are deterministic and must not
  /// be retried — repeating them only delays the error surfacing to the UI.
  static bool _isRetryableError(Object error) {
    if (error is BadResponseException ||
        error is ProviderUnavailableException) {
      // Deterministic server answers (bad response body, Cloudflare block):
      // an immediate retry gets the same answer.
      return false;
    }
    if (error is DioException) {
      if (error.type == DioExceptionType.connectionError ||
          error.type == DioExceptionType.connectionTimeout ||
          error.type == DioExceptionType.sendTimeout ||
          error.type == DioExceptionType.receiveTimeout) {
        return true;
      }
      final status = error.response?.statusCode;
      if (status == null) return true;
      return status == 429 || status >= 500;
    }
    return true;
  }

  void _scheduleSoftSearchRetry(
    ContentProvider provider, {
    required List<String> tags,
    required int page,
    required int limit,
    required String? rating,
    required TopPeriodFilter topPeriod,
    CancelToken? cancelToken,
  }) {
    // The originating search is already gone — don't resurrect it.
    if (cancelToken?.isCancelled ?? false) return;
    final key = [
      provider.id,
      page,
      limit,
      rating ?? '',
      topPeriod.name,
      ...tags,
    ].join('\u001f');
    if (!_softRetryKeys.add(key)) return;
    unawaited(Future<void>.delayed(const Duration(milliseconds: 900), () async {
      if (cancelToken?.isCancelled ?? false) {
        // The finally below is not reached from this early return — release
        // the key or the provider+query is blacklisted from retries forever.
        _softRetryKeys.remove(key);
        return;
      }
      try {
        final posts = await provider.searchPosts(
          tags: tags,
          page: page,
          limit: limit,
          rating: rating,
          topPeriod: topPeriod,
          cancelToken: cancelToken,
        );
        await _repository.saveDiagnostics(
          ProviderDiagnostics(
            providerId: provider.id,
            lastSearchAt: DateTime.now(),
            lastResultCount: posts.length,
          ),
        );
        await _repository.saveHealth(
          ProviderHealth(
            providerId: provider.id,
            status: ProviderStatus.online,
            pingMs: 0,
            lastCheckedAt: DateTime.now(),
          ),
        );
        if (posts.isNotEmpty) {
          _softRetryController.add(
            ProviderSoftRetryResult(
              providerId: provider.id,
              tags: tags,
              page: page,
              limit: limit,
              rating: rating,
              topPeriod: topPeriod,
              posts: posts,
            ),
          );
        }
      } catch (error) {
        final errorMsg = error is AppException
            ? error.message
            : (error is DioException
                ? (error.message ?? error.toString())
                : error.toString());
        await _repository.saveDiagnostics(
          ProviderDiagnostics(
            providerId: provider.id,
            lastSearchAt: DateTime.now(),
            lastResultCount: 0,
            lastErrorMessage: 'Search failed after retry: $errorMsg',
          ),
        );
      } finally {
        _softRetryKeys.remove(key);
      }
    }));
  }

  void dispose() {
    _softRetryController.close();
  }
}
