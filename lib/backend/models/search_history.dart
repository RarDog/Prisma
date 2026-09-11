class SearchHistory {
  const SearchHistory({
    required this.id,
    required this.query,
    required this.tags,
    required this.searchedAt,
    required this.resultCount,
  });

  final String id;
  final String query;
  final List<String> tags;
  final DateTime searchedAt;
  final int resultCount;

  Map<String, dynamic> toJson() => {
        'id': id,
        'query': query,
        'tags': tags,
        'searchedAt': searchedAt.toIso8601String(),
        'resultCount': resultCount,
      };

  factory SearchHistory.fromJson(Map<String, dynamic> json) => SearchHistory(
        id: (json['id'] ?? json['historyId'] ?? '').toString(),
        query: (json['query'] ?? '').toString(),
        tags: List<String>.from((json['tags'] as List?) ?? const []),
        searchedAt: DateTime.tryParse(json['searchedAt']?.toString() ?? '') ??
            DateTime.now(),
        resultCount: (json['resultCount'] as num?)?.toInt() ?? 0,
      );
}
