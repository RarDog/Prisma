class ArtistWorkQuery {
  const ArtistWorkQuery({
    required this.providerId,
    required this.service,
    required this.artistId,
    required this.artistName,
    this.queryText,
    this.tagFilter,
    this.mediaFilter,
    this.groupByPost = false,
  });

  final String providerId;
  final String service;
  final String artistId;
  final String artistName;
  final String? queryText;
  final String? tagFilter;
  final String? mediaFilter;
  final bool groupByPost;

  ArtistWorkQuery copyWith({
    String? providerId,
    String? service,
    String? artistId,
    String? artistName,
    String? queryText,
    String? tagFilter,
    String? mediaFilter,
    bool? groupByPost,
  }) {
    return ArtistWorkQuery(
      providerId: providerId ?? this.providerId,
      service: service ?? this.service,
      artistId: artistId ?? this.artistId,
      artistName: artistName ?? this.artistName,
      queryText: queryText ?? this.queryText,
      tagFilter: tagFilter ?? this.tagFilter,
      mediaFilter: mediaFilter ?? this.mediaFilter,
      groupByPost: groupByPost ?? this.groupByPost,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is ArtistWorkQuery &&
        other.providerId == providerId &&
        other.service == service &&
        other.artistId == artistId &&
        other.artistName == artistName &&
        other.queryText == queryText &&
        other.tagFilter == tagFilter &&
        other.mediaFilter == mediaFilter &&
        other.groupByPost == groupByPost;
  }

  @override
  int get hashCode => Object.hash(
        providerId,
        service,
        artistId,
        artistName,
        queryText,
        tagFilter,
        mediaFilter,
        groupByPost,
      );
}
