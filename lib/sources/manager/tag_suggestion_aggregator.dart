import 'dart:async';

import 'package:gel_rule_app/core/models/tag_suggestion.dart';
import 'package:gel_rule_app/core/utils/result.dart';
import 'package:gel_rule_app/sources/interfaces/content_provider.dart';

/// Aggregates and caches tag autocomplete suggestions concurrently across all
/// active providers that implement [TagSuggestionProvider].
class TagSuggestionAggregator {
  final Map<String, _SuggestionCacheEntry> _suggestionCache = {};
  _SuggestionProviderCacheEntry? _suggestionProviderCache;

  static const _suggestionCacheTtl = Duration(seconds: 45);
  static const _suggestionProviderCacheTtl = Duration(seconds: 60);
  static const _suggestionTimeout = Duration(milliseconds: 1500);

  Future<Result<List<TagSuggestion>>> suggestTags(
    String query, {
    required Future<Result<List<ContentProvider>>> Function() getActiveSuggestionProviders,
    int limit = 20,
  }) async {
    final normalizedQuery = query.trim().toLowerCase();
    if (normalizedQuery.isEmpty) return const Success([]);

    final providersResult = await getActiveSuggestionProviders();
    if (providersResult is Error<List<ContentProvider>>) {
      return Error(providersResult.failure);
    }
    final providers = (providersResult as Success<List<ContentProvider>>).data;
    if (providers.isEmpty) return const Success([]);

    final cappedLimit = limit.clamp(1, 50);
    final providerIds = providers.map((provider) => provider.id).join(',');
    final cacheKey = '$normalizedQuery|$providerIds|$cappedLimit';
    final cached = _suggestionCache[cacheKey];
    if (cached != null &&
        DateTime.now().difference(cached.createdAt) < _suggestionCacheTtl) {
      return Success(cached.items.take(cappedLimit).toList(growable: false));
    }

    final providerResults = await Future.wait(
      providers.map(
        (provider) => _suggestionsFromProvider(
          provider as TagSuggestionProvider,
          normalizedQuery,
          cappedLimit,
        ),
      ),
    );
    final suggestions = <String, TagSuggestion>{};
    for (final items in providerResults) {
      for (final item in items) {
        final nameKey = item.name.trim().toLowerCase();
        if (nameKey.isEmpty) continue;
        final current = suggestions[nameKey];
        if (current == null || item.postCount > current.postCount) {
          suggestions[nameKey] = item;
        }
      }
    }
    final values = suggestions.values.toList()
      ..sort((a, b) {
        final count = b.postCount.compareTo(a.postCount);
        return count != 0 ? count : a.name.compareTo(b.name);
      });
    _suggestionCache[cacheKey] = _SuggestionCacheEntry(
      DateTime.now(),
      values,
    );
    _pruneSuggestionCache();
    return Success(values.take(cappedLimit).toList());
  }

  Future<Result<List<ContentProvider>>> activeSuggestionProviders({
    required Future<Result<List<ContentProvider>>> Function() getActiveFeedProviders,
  }) async {
    final cached = _suggestionProviderCache;
    if (cached != null &&
        DateTime.now().difference(cached.createdAt) <
            _suggestionProviderCacheTtl) {
      return Success(cached.providers);
    }

    final providersResult = await getActiveFeedProviders();
    if (providersResult is Error<List<ContentProvider>>) {
      return Error(providersResult.failure);
    }
    final providers = <ContentProvider>[
      for (final provider
          in (providersResult as Success<List<ContentProvider>>).data)
        if (provider is TagSuggestionProvider) provider,
    ];
    _suggestionProviderCache = _SuggestionProviderCacheEntry(
      DateTime.now(),
      providers,
    );
    return Success(providers);
  }

  Future<List<TagSuggestion>> _suggestionsFromProvider(
    TagSuggestionProvider provider,
    String query,
    int limit,
  ) async {
    try {
      return await provider
          .suggestTags(query, limit: limit)
          .timeout(_suggestionTimeout);
    } catch (_) {
      // Suggestions are non-critical; a failed provider should not affect UI.
      return const [];
    }
  }

  void _pruneSuggestionCache() {
    final now = DateTime.now();
    _suggestionCache.removeWhere(
      (_, entry) => now.difference(entry.createdAt) >= _suggestionCacheTtl,
    );
  }

  void clearCaches() {
    _suggestionCache.clear();
    _suggestionProviderCache = null;
  }
}

class _SuggestionCacheEntry {
  const _SuggestionCacheEntry(this.createdAt, this.items);

  final DateTime createdAt;
  final List<TagSuggestion> items;
}

class _SuggestionProviderCacheEntry {
  const _SuggestionProviderCacheEntry(this.createdAt, this.providers);

  final DateTime createdAt;
  final List<ContentProvider> providers;
}
