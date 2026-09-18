class Collection {
  const Collection({
    required this.id,
    required this.name,
    this.description,
    this.coverUrl,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String name;
  final String? description;
  final String? coverUrl;
  final DateTime createdAt;
  final DateTime updatedAt;

  Collection copyWith({
    String? id,
    String? name,
    String? description,
    String? coverUrl,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) =>
      Collection(
        id: id ?? this.id,
        name: name ?? this.name,
        description: description ?? this.description,
        coverUrl: coverUrl ?? this.coverUrl,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'coverUrl': coverUrl,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory Collection.fromJson(Map<String, dynamic> json) => Collection(
        id: (json['id'] ?? json['collectionId'] ?? '').toString(),
        name: (json['name'] ?? '').toString(),
        description: json['description']?.toString(),
        coverUrl: json['coverUrl']?.toString(),
        createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
            DateTime.now(),
        updatedAt: DateTime.tryParse(json['updatedAt']?.toString() ?? '') ??
            DateTime.now(),
      );
}
