class PostNote {
  const PostNote({
    required this.id,
    required this.postId,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    required this.body,
    this.authorName,
    this.isActive = true,
  });

  final String id;
  final String postId;
  final int x;
  final int y;
  final int width;
  final int height;
  final String body;
  final String? authorName;
  final bool isActive;

  factory PostNote.fromJson(Map<String, dynamic> json) {
    return PostNote(
      id: (json['id'] ?? '').toString(),
      postId: (json['post_id'] ?? '').toString(),
      x: (json['x'] as num?)?.toInt() ?? 0,
      y: (json['y'] as num?)?.toInt() ?? 0,
      width: (json['width'] as num?)?.toInt() ?? 0,
      height: (json['height'] as num?)?.toInt() ?? 0,
      body: (json['body'] ?? '').toString(),
      authorName: json['creator_name']?.toString(),
      isActive: json['is_active'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'post_id': postId,
        'x': x,
        'y': y,
        'width': width,
        'height': height,
        'body': body,
        if (authorName != null) 'creator_name': authorName,
        'is_active': isActive,
      };
}
