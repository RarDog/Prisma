class PostCardBadgeConfig {
  const PostCardBadgeConfig({
    this.showProvider = true,
    this.showMediaType = true,
    this.showRating = true,
    this.showStatus = true,
    this.showFavorite = true,
    this.providerPosition = 'topLeft',
    this.mediaTypePosition = 'topRight',
    this.ratingPosition = 'bottomLeft',
    this.statusPosition = 'bottomLeft',
    this.favoritePosition = 'bottomRight',
  });

  final bool showProvider;
  final bool showMediaType;
  final bool showRating;
  final bool showStatus;
  final bool showFavorite;

  final String providerPosition;
  final String mediaTypePosition;
  final String ratingPosition;
  final String statusPosition;
  final String favoritePosition;

  static const List<String> positions = [
    'topLeft',
    'topRight',
    'bottomLeft',
    'bottomRight',
  ];

  PostCardBadgeConfig copyWith({
    bool? showProvider,
    bool? showMediaType,
    bool? showRating,
    bool? showStatus,
    bool? showFavorite,
    String? providerPosition,
    String? mediaTypePosition,
    String? ratingPosition,
    String? statusPosition,
    String? favoritePosition,
  }) {
    return PostCardBadgeConfig(
      showProvider: showProvider ?? this.showProvider,
      showMediaType: showMediaType ?? this.showMediaType,
      showRating: showRating ?? this.showRating,
      showStatus: showStatus ?? this.showStatus,
      showFavorite: showFavorite ?? this.showFavorite,
      providerPosition: providerPosition ?? this.providerPosition,
      mediaTypePosition: mediaTypePosition ?? this.mediaTypePosition,
      ratingPosition: ratingPosition ?? this.ratingPosition,
      statusPosition: statusPosition ?? this.statusPosition,
      favoritePosition: favoritePosition ?? this.favoritePosition,
    );
  }

  Map<String, dynamic> toJson() => {
        'showProvider': showProvider,
        'showMediaType': showMediaType,
        'showRating': showRating,
        'showStatus': showStatus,
        'showFavorite': showFavorite,
        'providerPosition': providerPosition,
        'mediaTypePosition': mediaTypePosition,
        'ratingPosition': ratingPosition,
        'statusPosition': statusPosition,
        'favoritePosition': favoritePosition,
      };

  factory PostCardBadgeConfig.fromJson(Map<String, dynamic> json) {
    return PostCardBadgeConfig(
      showProvider: (json['showProvider'] as bool?) ?? true,
      showMediaType: (json['showMediaType'] as bool?) ?? true,
      showRating: (json['showRating'] as bool?) ?? true,
      showStatus: (json['showStatus'] as bool?) ?? true,
      showFavorite: (json['showFavorite'] as bool?) ?? true,
      providerPosition:
          (json['providerPosition'] as String?) ?? 'topLeft',
      mediaTypePosition:
          (json['mediaTypePosition'] as String?) ?? 'topRight',
      ratingPosition:
          (json['ratingPosition'] as String?) ?? 'bottomLeft',
      statusPosition:
          (json['statusPosition'] as String?) ?? 'bottomLeft',
      favoritePosition:
          (json['favoritePosition'] as String?) ?? 'bottomRight',
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PostCardBadgeConfig &&
          runtimeType == other.runtimeType &&
          showProvider == other.showProvider &&
          showMediaType == other.showMediaType &&
          showRating == other.showRating &&
          showStatus == other.showStatus &&
          showFavorite == other.showFavorite &&
          providerPosition == other.providerPosition &&
          mediaTypePosition == other.mediaTypePosition &&
          ratingPosition == other.ratingPosition &&
          statusPosition == other.statusPosition &&
          favoritePosition == other.favoritePosition;

  @override
  int get hashCode => Object.hash(
        showProvider,
        showMediaType,
        showRating,
        showStatus,
        showFavorite,
        providerPosition,
        mediaTypePosition,
        ratingPosition,
        statusPosition,
        favoritePosition,
      );
}
