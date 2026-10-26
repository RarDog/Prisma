import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:gel_rule_app/backend/backend.dart';
import 'package:gel_rule_app/core/utils/result.dart';
import 'search_state.dart';

final searchControllerProvider =
    AsyncNotifierProvider<SearchController, SearchState>(SearchController.new);

class SearchController extends AsyncNotifier<SearchState> {
  Timer? _suggestionDebounce;
  int _suggestionRequestId = 0;
  StreamSubscription<void>? _historySubscription;

  @override
  Future<SearchState> build() async {
    await _historySubscription?.cancel();
    _historySubscription = ref
        .watch(searchServiceProvider)
        .historyChanges
        .listen((_) => unawaited(reloadHistory()));
    ref.onDispose(() {
      _suggestionDebounce?.cancel();
      _historySubscription?.cancel();
    });
    final recent = await _recent();
    final tags = await _loadHistoryTags();
    return SearchState(recent: recent, historyTags: tags);
  }

  Future<void> reloadHistory() async {
    final recent = await _recent();
    final tags = await _loadHistoryTags();
    if (state.hasValue) {
      state = AsyncData(
        (state.value ?? const SearchState()).copyWith(
          recent: recent,
          historyTags: tags,
        ),
      );
    }
  }

  void setProviderFilter(String? providerId) {
    if (!state.hasValue) return;
    state = AsyncData(
      state.value!.copyWith(
        selectedProviderFilter: () => providerId,
      ),
    );
  }

  Future<void> updateQuery(String query) async {
    final rawLast =
        query.trim().isEmpty ? '' : query.trim().split(RegExp(r'\s+')).last;
    final cleanToken = SearchService.sanitizeToken(rawLast);
    final requestId = ++_suggestionRequestId;
    _suggestionDebounce?.cancel();

    if (cleanToken.isEmpty || cleanToken == 'and') {
      state = AsyncData(
        (state.value ?? const SearchState()).copyWith(
          query: query,
          suggestions: const [],
        ),
      );
      return;
    }

    // Instant local suggestions from disk cache & history (0 ms)
    final localMatches = ref
        .read(searchServiceProvider)
        .instantSuggestions(cleanToken, limit: 16);

    state = AsyncData(
      (state.value ?? const SearchState()).copyWith(
        query: query,
        suggestions: localMatches,
      ),
    );

    _suggestionDebounce = Timer(const Duration(milliseconds: 160), () async {
      final settingsRes = await ref.read(settingsServiceProvider).getSettings();
      final appSettings = settingsRes is Success<AppSettings>
          ? settingsRes.data
          : AppSettings.defaults;
      final suggestionsResult =
          await ref.read(searchServiceProvider).autocompleteDetailed(
                cleanToken,
                limit: 16,
                tagCacheLimit: appSettings.tagCacheLimit,
              );
      if (requestId != _suggestionRequestId) return;
      final suggestions = suggestionsResult is Success<List<TagSuggestion>>
          ? suggestionsResult.data
          : localMatches;
      state = AsyncData(
        (state.value ?? const SearchState()).copyWith(
          query: query,
          suggestions: suggestions,
        ),
      );
    });
  }

  Future<void> deleteHistory(String historyId) async {
    await ref.read(searchServiceProvider).deleteHistoryItem(historyId);
    final recent = await _recent();
    final tags = await _loadHistoryTags();
    state = AsyncData(
      (state.value ?? const SearchState()).copyWith(
        recent: recent,
        historyTags: tags,
      ),
    );
  }

  Future<void> clearHistory() async {
    await ref.read(searchServiceProvider).clearHistory();
    state = AsyncData(
      (state.value ?? const SearchState()).copyWith(
        recent: const [],
        historyTags: const [],
      ),
    );
  }

  Future<List<SearchHistory>> _recent() async {
    final result = await ref.read(searchServiceProvider).recentSearches();
    return result is Success<List<SearchHistory>> ? result.data : const [];
  }

  Future<List<HistoryTagItem>> _loadHistoryTags() async {
    final Map<String, _TagAggregator> aggregated = {};

    // 1. Gather tags from viewed posts
    try {
      final viewedEntriesRes =
          await ref.read(viewedHistoryServiceProvider).getViewedPostEntries();
      if (viewedEntriesRes is Success<List<ViewedPostEntry>>) {
        for (final entry in viewedEntriesRes.data) {
          final post = entry.post;
          final pId = post.providerId;
          final pName = post.providerName;
          final seenAt = entry.viewedAt;

          for (final rawTag in post.tags) {
            final tag = rawTag.trim();
            if (tag.isEmpty || tag.length < 2) continue;
            final key = '$tag@$pId'.toLowerCase();
            final existing = aggregated[key];
            if (existing != null) {
              existing.count++;
              if (seenAt.isAfter(existing.lastSeen)) {
                existing.lastSeen = seenAt;
              }
            } else {
              aggregated[key] = _TagAggregator(
                tag: tag,
                providerId: pId,
                providerName: pName,
                count: 1,
                lastSeen: seenAt,
              );
            }
          }
        }
      }
    } catch (e, st) {
      // History-tag aggregation is best-effort: keep whatever was gathered
      // before the failure, but make the failure diagnosable.
      AppLogger.log('search history aggregation failed', e, st);
    }

    // 2. Gather from search queries
    try {
      final recentSearches = await _recent();
      for (final s in recentSearches) {
        for (final rawTag in s.tags) {
          final tag = rawTag.trim();
          if (tag.isEmpty || tag.length < 2) continue;
          // Look for any existing provider entry for this tag or generic
          final matched = aggregated.values.firstWhere(
            (a) => a.tag.toLowerCase() == tag.toLowerCase(),
            orElse: () => _TagAggregator(
              tag: tag,
              providerId: '',
              providerName: 'General',
              count: 0,
              lastSeen: s.searchedAt,
            ),
          );
          matched.count += 2;
          if (s.searchedAt.isAfter(matched.lastSeen)) {
            matched.lastSeen = s.searchedAt;
          }
          if (matched.providerId.isEmpty) {
            aggregated['$tag@search'.toLowerCase()] = matched;
          }
        }
      }
    } catch (e, st) {
      AppLogger.log('recent-search tag aggregation failed', e, st);
    }

    final list = aggregated.values
        .map((a) => HistoryTagItem(
              tag: a.tag,
              providerId: a.providerId,
              providerName: a.providerName,
              count: a.count,
              lastSeen: a.lastSeen,
            ))
        .toList();

    // Sort by count desc, then lastSeen desc
    list.sort((a, b) {
      final cmp = b.count.compareTo(a.count);
      if (cmp != 0) return cmp;
      return b.lastSeen.compareTo(a.lastSeen);
    });

    return list;
  }
}

class _TagAggregator {
  _TagAggregator({
    required this.tag,
    required this.providerId,
    required this.providerName,
    required this.count,
    required this.lastSeen,
  });

  final String tag;
  final String providerId;
  final String providerName;
  int count;
  DateTime lastSeen;
}
