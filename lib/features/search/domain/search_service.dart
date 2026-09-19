import 'dart:async';

import 'package:gel_rule_app/core/utils/result.dart';
import 'package:gel_rule_app/features/search/models/search_history.dart';
import 'package:gel_rule_app/core/models/tag_suggestion.dart';
import 'package:gel_rule_app/sources/provider_manager.dart';
import 'package:gel_rule_app/features/search/data/search_repository.dart';
import 'package:gel_rule_app/features/search/domain/tag_cache_service.dart';

class SearchService {
  SearchService(
    this._repository, [
    this._providerManager,
    this._tagCacheService,
  ]);

  final SearchRepository _repository;
  final ProviderManager? _providerManager;
  final TagCacheService? _tagCacheService;
  final _historyChangesController = StreamController<void>.broadcast();

  Stream<void> get historyChanges => _historyChangesController.stream;

  TagCacheService? get tagCacheService => _tagCacheService;

  static String sanitizeToken(String raw) {
    return raw.trim().toLowerCase();
  }

  List<String> parseTags(String query) {
    final seen = <String>{};
    final result = <String>[];
    for (final raw in query.trim().split(RegExp(r'\s+'))) {
      final tag = raw.trim();
      if (tag.isEmpty) continue;
      if (tag.toLowerCase() != 'and' && !seen.add(tag.toLowerCase())) continue;
      result.add(tag);
    }
    return result;
  }

  Future<Result<void>> saveSearch(
    String query,
    int resultCount, {
    int maxHistory = 500,
  }) async {
    final tags = parseTags(query);
    final history = SearchHistory(
      id: '${DateTime.now().microsecondsSinceEpoch}:${tags.join(',')}',
      query: query.trim(),
      tags: tags,
      searchedAt: DateTime.now(),
      resultCount: resultCount,
    );

    // Also register user-searched tags in persistent tag cache
    if (_tagCacheService != null && tags.isNotEmpty) {
      unawaited(
        _tagCacheService.cacheTags(
          tags.map(
            (tag) => TagSuggestion(
              name: tag,
              category: TagCategory.general,
              postCount: resultCount,
              providerId: 'history',
            ),
          ),
        ),
      );
    }

    final result = await _repository.save(history, maxItems: maxHistory);
    if (!_historyChangesController.isClosed) {
      _historyChangesController.add(null);
    }
    return result;
  }

  Future<Result<List<SearchHistory>>> recentSearches({int? limit}) {
    return _repository.recent(limit: limit);
  }

  /// Instant local tag suggestions (0 ms) from disk cache & recent search history.
  List<TagSuggestion> instantSuggestions(
    String prefix, {
    int limit = 16,
    Iterable<String>? priorityTags,
  }) {
    final clean = sanitizeToken(prefix);
    if (clean.isEmpty || clean == 'and') return const [];
    return _tagCacheService?.findLocal(
          clean,
          limit: limit,
          priorityTags: priorityTags,
        ) ??
        const [];
  }

  Future<Result<List<String>>> autocomplete(
    String prefix, {
    int limit = 10,
  }) async {
    final result = await autocompleteDetailed(prefix, limit: limit);
    return result.fold(
      onSuccess: (items) => Success(items.map((item) => item.name).toList()),
      onError: Error<List<String>>.new,
    );
  }

  Future<Result<List<TagSuggestion>>> autocompleteDetailed(
    String prefix, {
    int limit = 16,
    int tagCacheLimit = 5000,
    Iterable<String>? priorityTags,
  }) async {
    final clean = sanitizeToken(prefix);
    if (clean.isEmpty || clean == 'and') return const Success([]);

    final manager = _providerManager;
    if (manager == null) {
      final local = instantSuggestions(clean, limit: limit, priorityTags: priorityTags);
      return Success(local);
    }

    final netResult = await manager.suggestTags(clean, limit: limit);
    if (netResult is Error<List<TagSuggestion>>) {
      // Fallback to local cached suggestions if network fails
      final local = instantSuggestions(clean, limit: limit, priorityTags: priorityTags);
      return Success(local);
    }

    final remoteItems = (netResult as Success<List<TagSuggestion>>).data;

    // Cache remote suggestions to disk
    if (_tagCacheService != null && remoteItems.isNotEmpty) {
      unawaited(_tagCacheService.cacheTags(remoteItems, maxLimit: tagCacheLimit));
    }

    // Merge local matches with remote results
    final merged = <String, TagSuggestion>{};
    for (final item in instantSuggestions(clean, limit: limit, priorityTags: priorityTags)) {
      merged[item.name.toLowerCase()] = item;
    }
    for (final item in remoteItems) {
      final key = item.name.toLowerCase();
      final existing = merged[key];
      if (existing == null || item.postCount > existing.postCount) {
        merged[key] = item;
      }
    }

    final sorted = merged.values.toList()
      ..sort((a, b) {
        final aKey = a.name.toLowerCase();
        final bKey = b.name.toLowerCase();
        final aExact = aKey == clean;
        final bExact = bKey == clean;
        if (aExact != bExact) return aExact ? -1 : 1;

        final countCmp = b.postCount.compareTo(a.postCount);
        if (countCmp != 0) return countCmp;
        return aKey.compareTo(bKey);
      });

    return Success(sorted.take(limit).toList(growable: false));
  }

  Future<Result<bool>> deleteHistoryItem(String historyId) async {
    final result = await _repository.delete(historyId);
    if (!_historyChangesController.isClosed) {
      _historyChangesController.add(null);
    }
    return result;
  }

  Future<Result<void>> clearHistory() async {
    final result = await _repository.clear();
    if (!_historyChangesController.isClosed) {
      _historyChangesController.add(null);
    }
    return result;
  }

  Future<void> clearTagCache() async {
    await _tagCacheService?.clear();
  }

  void dispose() {
    _historyChangesController.close();
  }
}
