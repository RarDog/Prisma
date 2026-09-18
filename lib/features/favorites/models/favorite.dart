class Favorite {
  const Favorite({
    required this.id,
    required this.postId,
    required this.providerId,
    required this.savedAt,
  });

  final String id;
  final String postId;
  final String providerId;
  final DateTime savedAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'postId': postId,
        'providerId': providerId,
        'savedAt': savedAt.toIso8601String(),
      };

  factory Favorite.fromJson(Map<String, dynamic> json) => Favorite(
        id: (json['id'] ?? json['favoriteKey'] ?? '').toString(),
        postId: (json['postId'] ?? '').toString(),
        providerId: (json['providerId'] ?? '').toString(),
        savedAt: DateTime.tryParse(json['savedAt']?.toString() ?? '') ??
            DateTime.now(),
      );
}
