class FavoriteArtistItem {
  const FavoriteArtistItem({
    required this.id,
    required this.service,
    required this.providerId,
    required this.name,
    this.avatarUrl,
    this.bannerUrl,
    this.postCount,
    this.updatedAt,
  });

  const FavoriteArtistItem.empty()
      : id = '',
        service = '',
        providerId = '',
        name = '',
        avatarUrl = null,
        bannerUrl = null,
        postCount = null,
        updatedAt = null;

  final String id;
  final String service;
  final String providerId;
  final String name;
  final String? avatarUrl;
  final String? bannerUrl;
  final int? postCount;
  final DateTime? updatedAt;

  bool get isEmpty => id.isEmpty;
  String get key => '$providerId:$service:$id';

  Map<String, dynamic> toJson() => {
        'id': id,
        'service': service,
        'providerId': providerId,
        'name': name,
        'avatarUrl': avatarUrl,
        if (bannerUrl != null) 'bannerUrl': bannerUrl,
        if (postCount != null) 'postCount': postCount,
        if (updatedAt != null) 'updatedAt': updatedAt!.toIso8601String(),
      };

  factory FavoriteArtistItem.fromJson(Map<String, dynamic> json) =>
      FavoriteArtistItem(
        id: (json['id'] ?? '').toString(),
        service: (json['service'] ?? '').toString(),
        providerId: (json['providerId'] ?? '').toString(),
        name: (json['name'] ?? '').toString(),
        avatarUrl: json['avatarUrl'] as String?,
        bannerUrl: json['bannerUrl'] as String?,
        postCount: json['postCount'] is int
            ? json['postCount'] as int
            : int.tryParse(json['postCount']?.toString() ?? ''),
        updatedAt: json['updatedAt'] != null
            ? DateTime.tryParse(json['updatedAt'].toString())
            : null,
      );

  FavoriteArtistItem copyWith({
    String? id,
    String? service,
    String? providerId,
    String? name,
    String? avatarUrl,
    String? bannerUrl,
    int? postCount,
    DateTime? updatedAt,
  }) {
    return FavoriteArtistItem(
      id: id ?? this.id,
      service: service ?? this.service,
      providerId: providerId ?? this.providerId,
      name: name ?? this.name,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      bannerUrl: bannerUrl ?? this.bannerUrl,
      postCount: postCount ?? this.postCount,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FavoriteArtistItem &&
          runtimeType == other.runtimeType &&
          key == other.key;

  @override
  int get hashCode => key.hashCode;
}
