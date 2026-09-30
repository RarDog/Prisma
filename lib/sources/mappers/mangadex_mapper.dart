import 'package:gel_rule_app/core/models/post.dart';

class MangaDexMapper {
  static List<Post> postsFromSearchResponse(
    dynamic data, {
    required String providerId,
    required String providerName,
  }) {
    if (data is! Map) return const [];
    final items = data['data'];
    if (items is! List) return const [];

    final posts = <Post>[];
    for (final item in items) {
      if (item is Map) {
        final post = postFromMangaJson(
          item,
          providerId: providerId,
          providerName: providerName,
        );
        if (post != null) {
          posts.add(post);
        }
      }
    }
    return posts;
  }

  static Post? postFromMangaJson(
    Map<dynamic, dynamic> item, {
    required String providerId,
    required String providerName,
  }) {
    final id = item['id']?.toString();
    if (id == null || id.isEmpty) return null;

    final attributes = item['attributes'] as Map<dynamic, dynamic>? ?? {};
    final titleMap = attributes['title'] as Map<dynamic, dynamic>? ?? {};
    final altTitles = attributes['altTitles'] as List<dynamic>?;
    final title = extractTitle(titleMap, altTitles);

    final descMap = attributes['description'] as Map<dynamic, dynamic>?;
    final description = extractDescription(descMap);

    final contentRating = attributes['contentRating']?.toString();

    // Relationships: cover_art, author, artist
    String? coverFileName;
    String? authorName;
    String? artistName;

    final relationships = item['relationships'];
    if (relationships is List) {
      for (final rel in relationships) {
        if (rel is Map) {
          final type = rel['type']?.toString();
          final attrs = rel['attributes'] as Map<dynamic, dynamic>?;
          if (type == 'cover_art' && attrs != null) {
            coverFileName = attrs['fileName']?.toString();
          } else if (type == 'author' && attrs != null) {
            authorName = attrs['name']?.toString();
          } else if (type == 'artist' && attrs != null) {
            artistName = attrs['name']?.toString();
          }
        }
      }
    }

    final previewUrl = coverFileName != null
        ? 'https://uploads.mangadex.org/covers/$id/$coverFileName.256.jpg'
        : '';
    final sampleUrl = coverFileName != null
        ? 'https://uploads.mangadex.org/covers/$id/$coverFileName.512.jpg'
        : '';
    final fileUrl = coverFileName != null
        ? 'https://uploads.mangadex.org/covers/$id/$coverFileName'
        : '';

    final status = attributes['status']?.toString();

    // Tags
    final allTags = <String>[];
    final genreTags = <String>[];
    final themeTags = <String>[];
    final formatTags = <String>[];
    final contentTags = <String>[];

    final tagList = attributes['tags'] as List<dynamic>?;
    if (tagList != null) {
      for (final t in tagList) {
        if (t is Map && t['attributes'] is Map) {
          final group = t['attributes']['group']?.toString().toLowerCase();
          final nameMap = t['attributes']['name'] as Map<dynamic, dynamic>?;
          if (nameMap != null) {
            final name = nameMap['en']?.toString() ??
                (nameMap.values.isNotEmpty ? nameMap.values.first?.toString() : null);
            if (name != null && name.trim().isNotEmpty) {
              final trimmed = name.trim();
              allTags.add(trimmed);
              if (group == 'genre') {
                genreTags.add(trimmed);
              } else if (group == 'theme') {
                themeTags.add(trimmed);
              } else if (group == 'format') {
                formatTags.add(trimmed);
              } else if (group == 'content') {
                contentTags.add(trimmed);
              }
            }
          }
        }
      }
    }

    final tagGroups = <String, List<String>>{
      'copyright': [title],
      if (artistName != null && artistName.isNotEmpty) 'artist': [artistName],
      if (authorName != null && authorName.isNotEmpty) 'author': [authorName],
      'general': allTags,
      if (genreTags.isNotEmpty) 'genre': genreTags,
      if (themeTags.isNotEmpty) 'theme': themeTags,
      if (formatTags.isNotEmpty) 'format': formatTags,
      if (contentTags.isNotEmpty) 'content': contentTags,
      if (contentRating != null) 'content_rating': [contentRating],
      if (status != null && status.isNotEmpty) 'status': [status],
      'is_comic': ['true'],
      'media_type': ['manga'],
      if (description != null && description.isNotEmpty) 'description': [description],
    };

    DateTime createdAt = DateTime.now();
    final createdAtRaw = attributes['createdAt']?.toString();
    if (createdAtRaw != null) {
      createdAt = DateTime.tryParse(createdAtRaw) ?? DateTime.now();
    }

    return Post(
      id: id,
      providerId: providerId,
      providerName: providerName,
      previewUrl: previewUrl,
      sampleUrl: sampleUrl,
      fileUrl: fileUrl,
      tags: allTags,
      rating: contentRating == 'safe' ? 'g' : (contentRating == 'suggestive' ? 's' : 'e'),
      width: 700,
      height: 1000,
      source: 'https://mangadex.org/title/$id',
      createdAt: createdAt,
      fileType: 'jpg',
      score: 0,
      tagGroups: tagGroups,
    );
  }

  static String extractTitle(Map<dynamic, dynamic> titleMap, List<dynamic>? altTitles) {
    if (titleMap['ru']?.toString().trim().isNotEmpty == true) {
      return titleMap['ru'].toString().trim();
    }
    if (titleMap['en']?.toString().trim().isNotEmpty == true) {
      return titleMap['en'].toString().trim();
    }
    for (final v in titleMap.values) {
      if (v != null && v.toString().trim().isNotEmpty) {
        return v.toString().trim();
      }
    }
    if (altTitles != null) {
      for (final alt in altTitles) {
        if (alt is Map) {
          if (alt['ru']?.toString().trim().isNotEmpty == true) {
            return alt['ru'].toString().trim();
          }
          if (alt['en']?.toString().trim().isNotEmpty == true) {
            return alt['en'].toString().trim();
          }
        }
      }
    }
    return 'Untitled';
  }

  static String? extractDescription(Map<dynamic, dynamic>? descMap) {
    if (descMap == null) return null;
    if (descMap['ru']?.toString().trim().isNotEmpty == true) {
      return descMap['ru'].toString().trim();
    }
    if (descMap['en']?.toString().trim().isNotEmpty == true) {
      return descMap['en'].toString().trim();
    }
    for (final v in descMap.values) {
      if (v != null && v.toString().trim().isNotEmpty) {
        return v.toString().trim();
      }
    }
    return null;
  }
}
