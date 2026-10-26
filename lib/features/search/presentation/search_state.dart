import 'package:prisma_app/backend/backend.dart';

class SearchState {
  const SearchState({
    this.recent = const [],
    this.historyTags = const [],
    this.selectedProviderFilter,
    this.suggestions = const [],
    this.query = '',
  });

  final List<SearchHistory> recent;
  final List<HistoryTagItem> historyTags;
  final String? selectedProviderFilter;
  final List<TagSuggestion> suggestions;
  final String query;

  List<HistoryTagItem> get filteredHistoryTags {
    var tags = historyTags;
    if (selectedProviderFilter != null && selectedProviderFilter!.isNotEmpty) {
      tags = tags
          .where((t) =>
              t.providerId.toLowerCase() ==
              selectedProviderFilter!.toLowerCase())
          .toList();
    }
    final q = query.trim().toLowerCase();
    if (q.isNotEmpty) {
      tags = tags.where((t) => t.tag.toLowerCase().contains(q)).toList();
    }
    return tags;
  }

  List<SearchHistory> get filteredRecent {
    var items = recent;
    if (selectedProviderFilter != null && selectedProviderFilter!.isNotEmpty) {
      items = items
          .where((r) =>
              r.providerId.toLowerCase() ==
              selectedProviderFilter!.toLowerCase())
          .toList();
    }
    final q = query.trim().toLowerCase();
    if (q.isNotEmpty) {
      items = items
          .where((r) =>
              r.query.toLowerCase().contains(q) ||
              r.tags.any((t) => t.toLowerCase().contains(q)))
          .toList();
    }
    return items;
  }

  SearchState copyWith({
    List<SearchHistory>? recent,
    List<HistoryTagItem>? historyTags,
    String? Function()? selectedProviderFilter,
    List<TagSuggestion>? suggestions,
    String? query,
  }) {
    return SearchState(
      recent: recent ?? this.recent,
      historyTags: historyTags ?? this.historyTags,
      selectedProviderFilter: selectedProviderFilter != null
          ? selectedProviderFilter()
          : this.selectedProviderFilter,
      suggestions: suggestions ?? this.suggestions,
      query: query ?? this.query,
    );
  }
}
