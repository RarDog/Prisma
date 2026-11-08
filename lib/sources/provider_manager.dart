import 'dart:async';

import 'package:dio/dio.dart';
import 'package:gel_rule_app/core/errors/failure.dart';
import 'package:gel_rule_app/core/http/app_headers.dart';
import 'package:gel_rule_app/core/models/post.dart';
import 'package:gel_rule_app/core/models/post_comment.dart';
import 'package:gel_rule_app/core/models/post_note.dart';
import 'package:gel_rule_app/core/models/provider_health.dart';
import 'package:gel_rule_app/core/models/tag_suggestion.dart';
import 'package:gel_rule_app/core/models/top_period_filter.dart';
import 'package:gel_rule_app/core/utils/result.dart';
import 'package:gel_rule_app/features/providers/data/provider_repository.dart';
import 'package:gel_rule_app/features/providers/models/content_provider_config.dart';
import 'package:gel_rule_app/sources/interfaces/content_provider.dart';
import 'package:gel_rule_app/sources/manager/provider_config_classifier.dart';
import 'package:gel_rule_app/sources/manager/provider_search_coordinator.dart';
import 'package:gel_rule_app/sources/manager/provider_soft_retry_result.dart';
import 'package:gel_rule_app/sources/manager/tag_group_splitter.dart';
import 'package:gel_rule_app/sources/manager/tag_suggestion_aggregator.dart';
import 'package:gel_rule_app/sources/provider_factory.dart';

export 'manager/provider_soft_retry_result.dart';

class ProviderManager {
  ProviderManager(this._repository, this._factory)
      : _searchCoordinator = ProviderSearchCoordinator(_repository),
        _suggestionAggregator = TagSuggestionAggregator();

  final ProviderRepository _repository;
  final ProviderFactory _factory;
  final ProviderSearchCoordinator _searchCoordinator;
  final TagSuggestionAggregator _suggestionAggregator;

  /// Per-provider search timeout in seconds, refreshed on every config load
  /// so the per-provider `timeoutSeconds` setting actually governs searches
  /// instead of a global hardcode.
  final Map<String, int> _providerTimeouts = {};

  Stream<ProviderSoftRetryResult> get softRetryResults =>
      _searchCoordinator.softRetryResults;

  /// Short-lived cache of the full provider config list. Every getPost /
  /// getMediaHeaders / getComments round-trip goes through loadConfigs, which
  /// is an Isar query + factory churn — a 10s TTL keeps hot paths cheap while
  /// still seeing config edits almost immediately (CRUD also invalidates).
  List<ContentProviderConfig>? _configsCache;
  DateTime? _configsCacheAt;
  static const _configsCacheTtl = Duration(seconds: 10);

  Future<Result<List<ContentProviderConfig>>> loadConfigs({
    bool enabledOnly = true,
  }) async {
    final cached = _configsCache;
    final cachedAt = _configsCacheAt;
    if (cached != null &&
        cachedAt != null &&
        DateTime.now().difference(cachedAt) < _configsCacheTtl) {
      return Success(
        enabledOnly
            ? cached.where((config) => config.enabled).toList(growable: false)
            : cached,
      );
    }
    await _repository.ensureSeedProviders();
    final result = await _repository.getProviders(enabledOnly: false);
    if (result is Error<List<ContentProviderConfig>>) return result;
    final configs = (result as Success<List<ContentProviderConfig>>)
        .data
        .where((config) => !ProviderConfigClassifier.isLegacyRemovedConfig(config))
        .toList(growable: false);
    _configsCache = configs;
    _configsCacheAt = DateTime.now();
    _providerTimeouts.clear();
    for (final config in configs) {
      if (config.timeoutSeconds > 0) {
        _providerTimeouts[config.id] = config.timeoutSeconds;
      }
    }
    return Success(
      enabledOnly
          ? configs.where((config) => config.enabled).toList(growable: false)
          : configs,
    );
  }

  Future<Result<List<ContentProviderConfig>>> loadFeedConfigs({
    bool enabledOnly = true,
  }) async {
    final result = await loadConfigs(enabledOnly: enabledOnly);
    if (result is Error<List<ContentProviderConfig>>) {
      return Error(result.failure);
    }
    final configs = (result as Success<List<ContentProviderConfig>>)
        .data
        .where(ProviderConfigClassifier.isFeedConfig)
        .toList()
      ..sort((a, b) => a.priority.compareTo(b.priority));
    return Success(configs);
  }

  Future<Result<List<ContentProviderConfig>>> loadArtistConfigs({
    bool enabledOnly = true,
  }) async {
    final result = await loadConfigs(enabledOnly: enabledOnly);
    if (result is Error<List<ContentProviderConfig>>) {
      return Error(result.failure);
    }
    final configs = (result as Success<List<ContentProviderConfig>>)
        .data
        .where(ProviderConfigClassifier.isArtistConfig)
        .toList()
      ..sort((a, b) => a.priority.compareTo(b.priority));
    return Success(configs);
  }

  Future<Result<List<ContentProvider>>> activeProviders() async {
    final result = await loadConfigs();
    if (result is Error<List<ContentProviderConfig>>) {
      return Error(result.failure);
    }
    final configs = (result as Success<List<ContentProviderConfig>>).data
      ..sort((a, b) => a.priority.compareTo(b.priority));
    return Success(configs.map(_factory.create).toList());
  }

  Future<Result<List<ContentProvider>>> activeFeedProviders() async {
    final result = await loadFeedConfigs();
    if (result is Error<List<ContentProviderConfig>>) {
      return Error(result.failure);
    }
    final configs = (result as Success<List<ContentProviderConfig>>).data;
    return Success(configs.map(_factory.create).toList());
  }

  Future<Result<List<ArtistProvider>>> activeArtistProviders() async {
    final result = await loadArtistConfigs();
    if (result is Error<List<ContentProviderConfig>>) {
      return Error(result.failure);
    }
    final configs = (result as Success<List<ContentProviderConfig>>).data;
    final providers = configs
        .map(_factory.create)
        .whereType<ArtistProvider>()
        .toList(growable: false);
    return Success(providers);
  }

  Future<Result<List<ContentProviderConfig>>> loadMangaConfigs({
    bool enabledOnly = true,
  }) async {
    final result = await loadConfigs(enabledOnly: enabledOnly);
    if (result is Error<List<ContentProviderConfig>>) {
      return Error(result.failure);
    }
    final configs = (result as Success<List<ContentProviderConfig>>)
        .data
        .where(ProviderConfigClassifier.isMangaConfig)
        .toList()
      ..sort((a, b) => a.priority.compareTo(b.priority));
    return Success(configs);
  }

  Future<Result<List<ContentProvider>>> activeMangaProviders() async {
    final result = await loadMangaConfigs();
    if (result is Error<List<ContentProviderConfig>>) {
      return Error(result.failure);
    }
    final configs = (result as Success<List<ContentProviderConfig>>).data;
    return Success(configs.map(_factory.create).toList());
  }

  Future<Result<void>> enableProvider(String id, bool enabled) async {
    final result = await _repository.getProvider(id);
    return result.fold(
      onSuccess: (config) {
        if (config == null) {
          return const Error<void>(
            Failure(code: 'not_found', message: 'Provider not found'),
          );
        }
        return _repository
            .saveProvider(
          config.copyWith(enabled: enabled, updatedAt: DateTime.now()),
        )
            .then((result) {
          _clearSuggestionCaches();
          return result;
        });
      },
      onError: Error<void>.new,
    );
  }

  Future<Result<void>> addCustomProvider(ContentProviderConfig config) {
    return _repository
        .saveProvider(config.copyWith(updatedAt: DateTime.now()))
        .then((result) {
      _clearSuggestionCaches();
      return result;
    });
  }

  Future<Result<void>> deleteProvider(String id) {
    return _repository.deleteProvider(id).then((result) {
      _clearSuggestionCaches();
      return result;
    });
  }

  Future<ContentProvider?> getProviderInstance(String id) async {
    final result = await loadConfigs(enabledOnly: false);
    if (result is Success<List<ContentProviderConfig>>) {
      for (final config in result.data) {
        if (config.id == id) return _factory.create(config);
      }
    }
    return null;
  }

  Future<Result<List<ContentProvider>>> allProviders() async {
    final result = await _repository.getProviders();
    if (result is Error<List<ContentProviderConfig>>) {
      return Error(result.failure);
    }
    final configs = (result as Success<List<ContentProviderConfig>>).data;
    final providers = configs
        .map((config) {
          try {
            return _factory.create(config);
          } catch (_) {
            return null;
          }
        })
        .whereType<ContentProvider>()
        .toList();
    return Success(providers);
  }

  Future<Result<List<ProviderHealth>>> checkAll({
    int concurrency = 4,
    void Function(ProviderHealth)? onProgress,
    bool onlyEnabled = false,
  }) async {
    final providersResult =
        onlyEnabled ? await activeProviders() : await allProviders();
    if (providersResult is Error<List<ContentProvider>>) {
      return Error(providersResult.failure);
    }
    final providers = (providersResult as Success<List<ContentProvider>>).data;
    if (providers.isEmpty) return const Success([]);
    final results = await _runLimited(
      providers,
      concurrency,
      (provider) async {
        final health = await provider.checkHealth();
        await _repository.saveHealth(health);
        onProgress?.call(health);
        return health;
      },
    );
    return Success(results);
  }

  static List<List<String>> splitTagGroups(List<String> rawTags) =>
      TagGroupSplitter.split(rawTags);

  Future<Result<List<Post>>> searchAcrossProviders({
    required List<String> tags,
    required int page,
    int limit = 50,
    String? rating,
    String? providerId,
    TopPeriodFilter topPeriod = TopPeriodFilter.none,
    CancelToken? cancelToken,
  }) async {
    final providersResult = await activeFeedProviders();
    if (providersResult is Error<List<ContentProvider>>) {
      return Error(providersResult.failure);
    }
    final providers = (providersResult as Success<List<ContentProvider>>).data;
    return _searchCoordinator.searchAcrossProviders(
      activeFeedProviders: providers,
      providerTimeouts: _providerTimeouts,
      tags: tags,
      page: page,
      limit: limit,
      rating: rating,
      providerId: providerId,
      topPeriod: topPeriod,
      cancelToken: cancelToken,
    );
  }

  Future<Result<List<PostComment>>> getComments(
    String providerId,
    String postId,
  ) async {
    final providersResult = await activeProviders();
    if (providersResult is Error<List<ContentProvider>>) {
      return Error(providersResult.failure);
    }
    final providers = (providersResult as Success<List<ContentProvider>>).data;
    final matches = providers.where((provider) => provider.id == providerId);
    if (matches.isEmpty) {
      return const Error(
        Failure(code: 'not_found', message: 'Provider not found'),
      );
    }
    final provider = matches.first;
    if (provider is! CommentProvider) return const Success([]);
    try {
      return Success(await (provider as CommentProvider).getComments(postId));
    } catch (error) {
      return Error(
        Failure(
          code: 'comments_unavailable',
          message: 'Comments unavailable',
          details: error,
        ),
      );
    }
  }

  Future<Result<List<Post>>> getPostPages(Post post) async {
    final providersResult = await activeProviders();
    if (providersResult is Error<List<ContentProvider>>) {
      return Error(providersResult.failure);
    }
    final providers = (providersResult as Success<List<ContentProvider>>).data;
    final matches =
        providers.where((provider) => provider.id == post.providerId);
    if (matches.isEmpty) {
      return Success([post]);
    }
    final provider = matches.first;
    if (provider is! MultiPageProvider) return Success([post]);
    try {
      final pages = await (provider as MultiPageProvider).getPostPages(post);
      return Success(pages);
    } catch (_) {
      return Success([post]);
    }
  }

  Future<Result<List<PostNote>>> getNotes(
    String providerId,
    String postId,
  ) async {
    final providersResult = await activeProviders();
    if (providersResult is Error<List<ContentProvider>>) {
      return Error(providersResult.failure);
    }
    final providers = (providersResult as Success<List<ContentProvider>>).data;
    final matches = providers.where((provider) => provider.id == providerId);
    if (matches.isEmpty) {
      return const Success([]);
    }
    final provider = matches.first;
    if (provider is! NoteProvider) return const Success([]);
    try {
      return Success(await (provider as NoteProvider).getNotes(postId));
    } catch (error) {
      return Error(
        Failure(
          code: 'notes_unavailable',
          message: 'Notes unavailable',
          details: error,
        ),
      );
    }
  }

  Future<Result<Post?>> getPost(String providerId, String postId) async {
    final providersResult = await activeProviders();
    if (providersResult is Error<List<ContentProvider>>) {
      return Error(providersResult.failure);
    }
    final providers = (providersResult as Success<List<ContentProvider>>).data;
    final matches = providers.where((provider) => provider.id == providerId);
    if (matches.isEmpty) {
      return const Error(
          Failure(code: 'not_found', message: 'Provider not found'));
    }
    try {
      return Success(await matches.first.getPost(postId));
    } catch (error) {
      return Error(
        Failure(
          code: 'provider_get_post',
          message: 'Could not load post',
          details: error,
        ),
      );
    }
  }

  Future<Result<String?>> getPostPageUrl(Post post) async {
    final providersResult = await activeProviders();
    if (providersResult is Error<List<ContentProvider>>) {
      return Error(providersResult.failure);
    }
    final providers = (providersResult as Success<List<ContentProvider>>).data;
    final matches =
        providers.where((provider) => provider.id == post.providerId);
    if (matches.isEmpty || matches.first is! PostPageProvider) {
      return const Success(null);
    }
    return Success((matches.first as PostPageProvider).postPageUrl(post));
  }

  Future<Result<Map<String, String>>> getMediaHeaders(Post post) async {
    final providersResult = await activeProviders();
    if (providersResult is Error<List<ContentProvider>>) {
      return Error(providersResult.failure);
    }
    final providers = (providersResult as Success<List<ContentProvider>>).data;
    final matches =
        providers.where((provider) => provider.id == post.providerId);
    if (matches.isNotEmpty && matches.first is MediaHeadersProvider) {
      return Success(
        (matches.first as MediaHeadersProvider).mediaHeaders(post),
      );
    }
    return Success(AppHeaders.mediaHeaders());
  }

  Future<Result<Post>> enrichPostTags(Post post) async {
    final hasUsefulGroups = post.tagGroups.entries.any(
      (entry) => entry.key != 'general' && entry.value.isNotEmpty,
    );
    if (hasUsefulGroups || post.tags.isEmpty) return Success(post);

    final providersResult = await activeFeedProviders();
    if (providersResult is Error<List<ContentProvider>>) {
      return Error(providersResult.failure);
    }
    final providers = (providersResult as Success<List<ContentProvider>>).data;
    final matches =
        providers.where((provider) => provider.id == post.providerId);
    if (matches.isEmpty || matches.first is! TagMetadataProvider) {
      return Success(post);
    }

    try {
      final groups = await (matches.first as TagMetadataProvider)
          .categorizeTags(post.tags);
      if (groups.isEmpty) return Success(post);
      return Success(post.copyWith(tagGroups: groups));
    } catch (error) {
      return Success(post);
    }
  }

  Future<Result<List<TagSuggestion>>> suggestTags(
    String query, {
    int limit = 20,
  }) =>
      _suggestionAggregator.suggestTags(
        query,
        getActiveSuggestionProviders: activeSuggestionProviders,
        limit: limit,
      );

  Future<Result<List<ContentProvider>>> activeSuggestionProviders() =>
      _suggestionAggregator.activeSuggestionProviders(
        getActiveFeedProviders: activeFeedProviders,
      );

  void _clearSuggestionCaches() {
    _suggestionAggregator.clearCaches();
    _configsCache = null;
    _configsCacheAt = null;
  }

  Future<List<R>> _runLimited<T, R>(
    List<T> items,
    int concurrency,
    Future<R> Function(T item) action,
  ) async {
    final results = <R>[];
    var index = 0;

    Future<void> worker() async {
      while (index < items.length) {
        final current = items[index++];
        results.add(await action(current));
      }
    }

    await Future.wait(
      List.generate(concurrency.clamp(1, items.length), (_) => worker()),
    );
    return results;
  }
}
