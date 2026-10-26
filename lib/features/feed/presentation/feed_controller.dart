import 'dart:async';

import 'package:dio/dio.dart' show CancelToken;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:prisma_app/app/app.dart';
import 'package:prisma_app/backend/backend.dart';
import 'package:prisma_app/core/utils/result.dart';
import 'package:prisma_app/features/providers/presentation/providers_controller.dart';
import 'feed_state.dart';

final feedControllerProvider =
    AsyncNotifierProvider<FeedController, FeedState>(FeedController.new);

class FeedController extends AsyncNotifier<FeedState> {
  Timer? _providerDebounce;
  Timer? _suggestionDebounce;
  StreamSubscription<ProviderSoftRetryResult>? _softRetrySubscription;
  CancelToken? _activeLoadToken;
  int _loadRequestId = 0;
  int _suggestionRequestId = 0;

  @override
  Future<FeedState> build() async {
    ref.onDispose(() {
      _providerDebounce?.cancel();
      _suggestionDebounce?.cancel();
      _softRetrySubscription?.cancel();
      _activeLoadToken?.cancel();
    });
    _softRetrySubscription ??= ref
        .read(providerManagerProvider)
        .softRetryResults
        .listen(_applySoftRetryResult);
    final providers = await _loadProviders();
    final settings = await _settings();
    final providerIds = providers.map((provider) => provider.id).toSet();
    final selectedProviders =
        settings.lastFeedProviderIds.where(providerIds.contains).toList();
    final activeConfigs = selectedProviders.isEmpty
        ? providers
        : providers.where((p) => selectedProviders.contains(p.id)).toList();
    final supported = resolveSupportedTopPeriods(activeConfigs);
    final initialPeriod = TopPeriodFilter.values.firstWhere(
      (value) => value.name == settings.lastFeedTopPeriod,
      orElse: () => TopPeriodFilter.none,
    );
    final effectivePeriod = supported.contains(initialPeriod)
        ? initialPeriod
        : (supported.contains(TopPeriodFilter.allTime) &&
                initialPeriod != TopPeriodFilter.none
            ? TopPeriodFilter.allTime
            : (supported.contains(TopPeriodFilter.none)
                ? TopPeriodFilter.none
                : supported.first));

    final initial = FeedState(
      providers: providers,
      topPeriodFilter: effectivePeriod,
      selectedTags: settings.lastFeedTags,
      selectedProviderIds: selectedProviders,
      ratingFilter: settings.lastFeedRating ?? settings.defaultRatingFilter,
    );
    state = AsyncData(initial);
    await loadInitial();
    return state.value ?? initial;
  }

  Future<void> loadInitial() async {
    final current = state.value ?? const FeedState();
    final requestId = ++_loadRequestId;
    state = const AsyncLoading();
    final posts = await _load(refresh: true, current: current);
    if (requestId != _loadRequestId) return;
    final status = await _providerStatus(current);
    // All selected sources failed and nothing is cached: surface a retryable
    // error instead of the misleading "no posts" empty state.
    final loadFailed = posts.isEmpty && status.failedProviders.isNotEmpty;
    final strings = ref.read(appStringsProvider);
    state = AsyncData(current.copyWith(
      posts: posts,
      hasMore: true,
      emptyPageStreak: 0,
      error: loadFailed ? strings.feedLoadFailed : null,
      clearError: !loadFailed,
      providerStatusMessage: status.message,
    ));
    // A failed search records an `offline` health entry, so the feed/Artists
    // banners need rebuilding after every load.
    ref.invalidate(enabledProviderHealthProvider);
  }

  Future<void> refresh() async {
    final current = state.value ?? const FeedState();
    final requestId = ++_loadRequestId;
    state = AsyncData(current.copyWith(isLoadingMore: true, clearError: true));
    final posts = await _load(refresh: true, current: current);
    if (requestId != _loadRequestId) return;
    final status = await _providerStatus(current);
    final loadFailed = posts.isEmpty && status.failedProviders.isNotEmpty;
    final strings = ref.read(appStringsProvider);
    state = AsyncData(current.copyWith(
      posts: posts,
      isLoadingMore: false,
      hasMore: true,
      emptyPageStreak: 0,
      error: loadFailed ? strings.feedLoadFailed : null,
      clearError: !loadFailed,
      providerStatusMessage: status.message,
    ));
    ref.invalidate(enabledProviderHealthProvider);
  }

  Future<void> loadNextPage() async {
    final current = state.value;
    if (current == null || current.isLoadingMore || !current.hasMore) return;
    final requestId = ++_loadRequestId;
    state = AsyncData(current.copyWith(isLoadingMore: true, clearError: true));
    final posts = <Post>[];
    const maxEmptyPageSkips = 3;
    var attempts = 0;
    while (posts.isEmpty && attempts < maxEmptyPageSkips) {
      attempts++;
      posts.addAll(await _load(refresh: false, current: current));
      if (requestId != _loadRequestId) return;
    }
    if (requestId != _loadRequestId) return;
    final existingKeys = current.posts.map((post) => post.cacheKey).toSet();
    final newPosts = posts
        .where((post) => existingKeys.add(post.cacheKey))
        .toList(growable: false);
    final emptyPageStreak =
        newPosts.isEmpty ? current.emptyPageStreak + attempts : 0;
    state = AsyncData(
      current.copyWith(
        posts: [...current.posts, ...newPosts],
        isLoadingMore: false,
        hasMore: newPosts.isNotEmpty || emptyPageStreak < maxEmptyPageSkips,
        emptyPageStreak: emptyPageStreak,
      ),
    );
  }

  Future<void> search(String query) async {
    final tags = ref.read(searchServiceProvider).parseTags(query);
    final current = state.value ?? const FeedState();
    state = AsyncData(
      current.copyWith(
        selectedTags: tags,
        posts: [],
        tagSuggestions: [],
        hasMore: true,
        emptyPageStreak: 0,
      ),
    );
    await saveSession(scrollOffset: 0);
    final settingsRes = await ref.read(settingsServiceProvider).getSettings();
    final settings = settingsRes is Success<AppSettings>
        ? settingsRes.data
        : AppSettings.defaults;
    final activeProviderId = current.selectedProviderIds.length == 1
        ? current.selectedProviderIds.first
        : '';
    final activeProviderName = activeProviderId.isNotEmpty
        ? (current.providers
                .where((p) => p.id == activeProviderId)
                .firstOrNull
                ?.name ??
            '')
        : '';

    try {
      await refresh();
      final count = state.value?.posts.length ?? 0;
      await ref.read(searchServiceProvider).saveSearch(
            query,
            count,
            maxHistory: settings.searchHistoryLimit,
            providerId: activeProviderId,
            providerName: activeProviderName,
          );
    } catch (_) {
      await ref.read(searchServiceProvider).saveSearch(
            query,
            0,
            maxHistory: settings.searchHistoryLimit,
            providerId: activeProviderId,
            providerName: activeProviderName,
          );
      rethrow;
    }
  }

  Future<void> updateTagSuggestions(String query) async {
    final current = state.value ?? const FeedState();
    final rawLast =
        query.trim().isEmpty ? '' : query.trim().split(RegExp(r'\s+')).last;
    final cleanToken = SearchService.sanitizeToken(rawLast);
    final requestId = ++_suggestionRequestId;
    _suggestionDebounce?.cancel();

    if (cleanToken.isEmpty || cleanToken == 'and') {
      state = AsyncData(current.copyWith(tagSuggestions: []));
      return;
    }

    // Instant local suggestions from disk cache & history (0 ms)
    final localMatches = ref
        .read(searchServiceProvider)
        .instantSuggestions(cleanToken, limit: 16);
    if (localMatches.isNotEmpty) {
      state = AsyncData(current.copyWith(tagSuggestions: localMatches));
    }

    _suggestionDebounce = Timer(const Duration(milliseconds: 160), () async {
      final settingsRes = await ref.read(settingsServiceProvider).getSettings();
      final appSettings = settingsRes is Success<AppSettings>
          ? settingsRes.data
          : AppSettings.defaults;
      final result = await ref.read(searchServiceProvider).autocompleteDetailed(
            cleanToken,
            limit: 16,
            tagCacheLimit: appSettings.tagCacheLimit,
          );
      if (requestId != _suggestionRequestId) return;
      final suggestions =
          result is Success<List<TagSuggestion>> ? result.data : localMatches;
      final latest = state.value ?? current;
      state = AsyncData(latest.copyWith(tagSuggestions: suggestions));
    });
  }

  Future<void> setProviders(List<String> providerIds) async {
    final current = state.value ?? const FeedState();
    final enabledIds = current.providers.map((provider) => provider.id).toSet();
    final selected = providerIds.where(enabledIds.contains).toList();
    final activeConfigs = selected.isEmpty
        ? current.providers
        : current.providers.where((p) => selected.contains(p.id)).toList();
    final supported = resolveSupportedTopPeriods(activeConfigs);
    var targetPeriod = current.topPeriodFilter;
    if (!supported.contains(targetPeriod)) {
      targetPeriod = supported.contains(TopPeriodFilter.allTime) &&
              current.topPeriodFilter != TopPeriodFilter.none
          ? TopPeriodFilter.allTime
          : (supported.contains(TopPeriodFilter.none)
              ? TopPeriodFilter.none
              : supported.first);
    }
    state = AsyncData(current.copyWith(
      selectedProviderIds: selected,
      topPeriodFilter: targetPeriod,
      posts: [],
      hasMore: true,
      emptyPageStreak: 0,
    ));
    final settings = await _settings();
    await ref.read(settingsServiceProvider).updateSettings(
          settings.copyWith(
            selectedFeedProviderIds: selected,
            lastFeedProviderIds: selected,
            lastFeedTopPeriod: targetPeriod.name,
          ),
        );
    _providerDebounce?.cancel();
    _providerDebounce = Timer(const Duration(milliseconds: 320), () {
      refresh();
    });
  }

  Future<void> setTopPeriod(TopPeriodFilter period) async {
    final current = state.value ?? const FeedState();
    state = AsyncData(current.copyWith(
      topPeriodFilter: period,
      posts: [],
      hasMore: true,
      emptyPageStreak: 0,
    ));
    final settings = await _settings();
    await ref.read(settingsServiceProvider).updateSettings(
          settings.copyWith(defaultTopPeriodFilter: period.name),
        );
    await saveSession(scrollOffset: 0);
    await refresh();
  }

  Future<void> setRating(String? rating) async {
    final current = state.value ?? const FeedState();
    state = AsyncData(
      current.copyWith(
        ratingFilter: rating,
        clearRating: rating == null,
        posts: [],
        hasMore: true,
        emptyPageStreak: 0,
      ),
    );
    await refresh();
    await saveSession(scrollOffset: 0);
  }

  Future<void> clearFilters() async {
    final current = state.value ?? const FeedState();
    state = AsyncData(
      current.copyWith(
        selectedTags: [],
        selectedProviderIds: [],
        tagSuggestions: [],
        clearRating: true,
        posts: [],
        hasMore: true,
        emptyPageStreak: 0,
      ),
    );
    final settings = await _settings();
    await ref.read(settingsServiceProvider).updateSettings(settings.copyWith(
          selectedFeedProviderIds: [],
          lastFeedTags: [],
          lastFeedProviderIds: [],
          clearLastFeedRating: true,
          clearDefaultRatingFilter: true,
          lastFeedTopPeriod: TopPeriodFilter.none.name,
          lastFeedScrollOffset: 0,
        ));
    await refresh();
  }

  Future<void> hidePost(Post post) async {
    final current = state.value;
    if (current == null) return;
    final result =
        await ref.read(settingsServiceProvider).hidePostKey(post.cacheKey);
    if (result is Error<void>) return;
    state = AsyncData(
      current.copyWith(
        posts: current.posts
            .where((item) => item.cacheKey != post.cacheKey)
            .toList(growable: false),
      ),
    );
    ref.invalidate(appSettingsProvider);
  }

  Future<void> saveSession({double? scrollOffset}) async {
    final current = state.value;
    if (current == null) return;
    final settings = await _settings();
    await ref.read(settingsServiceProvider).updateSettings(
          settings.copyWith(
            lastFeedTags: current.selectedTags,
            lastFeedProviderIds: current.selectedProviderIds,
            lastFeedRating: current.ratingFilter,
            clearLastFeedRating: current.ratingFilter == null,
            defaultRatingFilter: current.ratingFilter,
            clearDefaultRatingFilter: current.ratingFilter == null,
            lastFeedTopPeriod: current.topPeriodFilter.name,
            lastFeedScrollOffset: scrollOffset ?? settings.lastFeedScrollOffset,
          ),
        );
  }

  Future<List<Post>> _load({
    required bool refresh,
    required FeedState current,
  }) async {
    final service = ref.read(feedServiceProvider);
    // Abort whatever the previous load still has in flight (e.g. the user
    // changed tags mid-search); cancelling a finished request is a no-op.
    _activeLoadToken?.cancel();
    final cancelToken = CancelToken();
    _activeLoadToken = cancelToken;
    final providerIds = current.selectedProviderIds.isEmpty
        ? <String?>[null]
        : current.selectedProviderIds;
    // Fetch every selected provider concurrently — sequential awaits
    // multiplied the latency of the slowest source by the provider count.
    final providerResults = await Future.wait(
      providerIds.map((providerId) async {
        final result = refresh
            ? await service.refresh(
                tags: current.selectedTags,
                rating: current.ratingFilter,
                providerId: providerId,
                topPeriod: current.topPeriodFilter,
                cancelToken: cancelToken,
              )
            : await service.loadNextPage(
                tags: current.selectedTags,
                rating: current.ratingFilter,
                providerId: providerId,
                topPeriod: current.topPeriodFilter,
                cancelToken: cancelToken,
              );
        return result is Success<List<Post>> ? result.data : const <Post>[];
      }),
    );
    final posts = <Post>[];
    final seen = <String>{};
    for (final group in providerResults) {
      for (final post in group) {
        if (seen.add(post.cacheKey)) posts.add(post);
      }
    }
    final nonEmptyGroups =
        providerResults.where((group) => group.isNotEmpty).length;
    if (nonEmptyGroups > 1) {
      _sortMixed(posts);
    }
    return posts;
  }

  void _applySoftRetryResult(ProviderSoftRetryResult result) {
    final current = state.value;
    if (current == null || result.page != 0) return;
    if (!_sameTags(current.selectedTags, result.tags)) return;
    if (current.ratingFilter != result.rating) return;
    if (current.topPeriodFilter != result.topPeriod) return;
    if (current.selectedProviderIds.isNotEmpty &&
        !current.selectedProviderIds.contains(result.providerId)) {
      return;
    }
    final seen = current.posts.map((post) => post.cacheKey).toSet();
    final newPosts = result.posts
        .where((post) => seen.add(post.cacheKey))
        .toList(growable: false);
    if (newPosts.isEmpty) return;
    final combined = [...current.posts, ...newPosts];
    _sortMixed(combined);
    state = AsyncData(
      current.copyWith(
        posts: combined,
        providerStatusMessage:
            ref.read(appStringsProvider).retryAddedPosts(newPosts.length),
      ),
    );
  }

  bool _sameTags(List<String> left, List<String> right) {
    if (left.length != right.length) return false;
    for (var i = 0; i < left.length; i++) {
      if (left[i] != right[i]) return false;
    }
    return true;
  }

  Future<({String? message, Set<String> failedProviders})> _providerStatus(
    FeedState current,
  ) async {
    final result = await ref.read(providerRepositoryProvider).getDiagnostics();
    if (result is! Success<List<ProviderDiagnostics>>) {
      return (message: null, failedProviders: const <String>{});
    }
    final selected = current.selectedProviderIds.isEmpty
        ? current.providers.map((provider) => provider.id).toSet()
        : current.selectedProviderIds.toSet();
    final failed = result.data
        .where((item) =>
            selected.contains(item.providerId) &&
            item.lastErrorMessage != null &&
            item.lastErrorMessage!.isNotEmpty)
        .map((item) => item.providerId)
        .toSet();
    if (failed.isEmpty) {
      return (message: null, failedProviders: failed);
    }
    return (
      message: ref.read(appStringsProvider).retryingProviders(failed.length),
      failedProviders: failed,
    );
  }

  void _sortMixed(List<Post> posts) {
    if (posts.length <= 1) return;
    final keys = <String, int>{};
    for (final post in posts) {
      keys[post.cacheKey] = _mixKey(post);
    }
    posts.sort((a, b) => keys[a.cacheKey]!.compareTo(keys[b.cacheKey]!));
  }

  int _mixKey(Post post) {
    var hash = 0x811c9dc5;
    for (final code in post.cacheKey.codeUnits) {
      hash ^= code;
      hash = (hash * 0x01000193) & 0x7fffffff;
    }
    return hash;
  }

  Future<List<ContentProviderConfig>> _loadProviders() async {
    final result = await ref
        .read(providerManagerProvider)
        .loadFeedConfigs(enabledOnly: true);
    return result is Success<List<ContentProviderConfig>>
        ? result.data
        : const [];
  }

  Future<AppSettings> _settings() async {
    final result = await ref.read(settingsServiceProvider).getSettings();
    return result is Success<AppSettings> ? result.data : AppSettings.defaults;
  }
}
