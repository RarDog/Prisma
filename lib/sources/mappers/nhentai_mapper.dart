import 'dart:convert';

import 'package:gel_rule_app/core/models/post.dart';

class NHentaiMapper {
  static dynamic _normalizeJson(dynamic data) {
    if (data is String) {
      try {
        return jsonDecode(data);
      } catch (_) {
        return null;
      }
    }
    return data;
  }

  /// Convert type abbreviation ('j', 'p', 'g', 'w') to file extension
  static String extensionFromType(dynamic type) {
    if (type == null) return 'jpg';
    final t = type.toString().toLowerCase();
    switch (t) {
      case 'p':
      case 'png':
        return 'png';
      case 'g':
      case 'gif':
        return 'gif';
      case 'w':
      case 'webp':
        return 'webp';
      case 'j':
      case 'jpg':
      case 'jpeg':
      default:
        return 'jpg';
    }
  }

  /// Parses search response /api/galleries/search or /api/galleries/all
  /// Structure: { "result": [ { book }, ... ], "num_pages": 10, "per_page": 25 }
  static List<Post> postsFromSearchResponse(
    dynamic data, {
    required String providerId,
    required String providerName,
    String imagesHost = 'i.nhentai.net',
    String thumbsHost = 't.nhentai.net',
  }) {
    final parsed = _normalizeJson(data);
    if (parsed is! Map) return const [];
    final items = parsed['result'];
    if (items is! List) return const [];

    final posts = <Post>[];
    for (final raw in items) {
      if (raw is! Map) continue;
      final post = postFromGalleryJson(
        raw,
        providerId: providerId,
        providerName: providerName,
        imagesHost: imagesHost,
        thumbsHost: thumbsHost,
      );
      if (post != null) {
        posts.add(post);
      }
    }
    return posts;
  }

  /// Parses a single gallery JSON object into a Post
  static Post? postFromGalleryJson(
    dynamic data, {
    required String providerId,
    required String providerName,
    String imagesHost = 'i.nhentai.net',
    String thumbsHost = 't.nhentai.net',
  }) {
    final parsed = _normalizeJson(data);
    if (parsed is! Map) return null;
    final item = Map<String, dynamic>.from(parsed);

    final rawId = item['id'];
    if (rawId == null) return null;
    final id = rawId.toString();

    final rawMediaId = item['media_id'];
    final mediaId = rawMediaId != null ? rawMediaId.toString() : id;

    // Title parsing (english, japanese, pretty)
    final titleMap = item['title'] is Map ? item['title'] as Map : const {};
    final titlePretty = titleMap['pretty']?.toString() ?? '';
    final titleEnglish = titleMap['english']?.toString() ?? '';
    final titleJapanese = titleMap['japanese']?.toString() ?? '';
    final mainTitle = titlePretty.isNotEmpty
        ? titlePretty
        : (titleEnglish.isNotEmpty ? titleEnglish : titleJapanese);

    // Tags & categories extraction
    final rawTags = item['tags'];
    final tags = <String>[];
    final artists = <String>[];
    final parodies = <String>[];
    final characters = <String>[];
    final groups = <String>[];
    final languages = <String>[];
    final categories = <String>[];

    if (rawTags is List) {
      for (final t in rawTags) {
        if (t is! Map) continue;
        final name = t['name']?.toString() ?? '';
        final type = t['type']?.toString() ?? 'tag';
        if (name.isEmpty) continue;

        tags.add(name);
        switch (type) {
          case 'artist':
            artists.add(name);
            break;
          case 'parody':
            parodies.add(name);
            break;
          case 'character':
            characters.add(name);
            break;
          case 'group':
            groups.add(name);
            break;
          case 'language':
            if (name != 'translated') languages.add(name);
            break;
          case 'category':
            categories.add(name);
            break;
        }
      }
    }

    final images = item['images'] is Map ? item['images'] as Map : const {};
    final cover = images['cover'] is Map ? images['cover'] as Map : const {};
    final coverExt = extensionFromType(cover['t']);
    final coverWidth = int.tryParse('${cover['w'] ?? 0}') ?? 0;
    final coverHeight = int.tryParse('${cover['h'] ?? 0}') ?? 0;

    final pagesList = images['pages'] is List ? images['pages'] as List : const [];
    final pageCount = int.tryParse('${item['num_pages'] ?? pagesList.length}') ?? pagesList.length;

    // First page image URL (page 1)
    String firstPageUrl = '';
    String firstPageExt = 'jpg';
    if (pagesList.isNotEmpty && pagesList.first is Map) {
      firstPageExt = extensionFromType(pagesList.first['t']);
      firstPageUrl = 'https://$imagesHost/galleries/$mediaId/1.$firstPageExt';
    }

    // Cover thumbnail and sample
    final previewUrl = 'https://$thumbsHost/galleries/$mediaId/cover.$coverExt';
    final sampleUrl = firstPageUrl.isNotEmpty ? firstPageUrl : previewUrl;
    final fileUrl = sampleUrl;

    // Upload date
    DateTime createdAt = DateTime.now();
    final uploadDate = item['upload_date'];
    if (uploadDate is num) {
      createdAt = DateTime.fromMillisecondsSinceEpoch(uploadDate.toInt() * 1000);
    }

    // Children page IDs for reader: [id_p1, id_p2, ...]
    final children = <String>[];
    for (int i = 0; i < pageCount; i++) {
      children.add('${id}_p$i');
    }

    final numFavorites = int.tryParse('${item['num_favorites'] ?? 0}') ?? 0;

    final tagGroups = <String, List<String>>{
      'general': tags,
      if (artists.isNotEmpty) 'artist': artists,
      'copyright': [
        if (mainTitle.isNotEmpty) mainTitle,
        ...parodies,
      ],
      if (characters.isNotEmpty) 'character': characters,
      if (groups.isNotEmpty) 'group': groups,
      if (languages.isNotEmpty) 'language': languages,
      if (categories.isNotEmpty) 'category': categories,
      if (mainTitle.isNotEmpty) 'title': [mainTitle],
      if (children.isNotEmpty) 'children': children,
      'is_comic': ['true'],
      'media_id': [mediaId],
      'page_count': [pageCount.toString()],
    };

    return Post(
      id: id,
      providerId: providerId,
      providerName: providerName,
      previewUrl: previewUrl,
      sampleUrl: sampleUrl,
      fileUrl: fileUrl,
      tags: tags,
      rating: 'e', // nhentai is explicitly R-18/18+
      width: coverWidth,
      height: coverHeight,
      source: 'https://nhentai.net/g/$id/',
      createdAt: createdAt,
      fileType: coverExt,
      score: numFavorites,
      tagGroups: tagGroups,
    );
  }

  /// Maps an individual page from gallery details to a Post child
  static Post? postFromPageData({
    required dynamic pageItem,
    required Post parentPost,
    required int pageIndex, // 0-based
    String imagesHost = 'i.nhentai.net',
    String thumbsHost = 't.nhentai.net',
  }) {
    if (pageItem is! Map) return null;
    final mediaId = parentPost.tagGroups['media_id']?.firstOrNull ?? parentPost.id;
    final ext = extensionFromType(pageItem['t']);
    final pageNum = pageIndex + 1;

    final fileUrl = 'https://$imagesHost/galleries/$mediaId/$pageNum.$ext';
    final previewUrl = 'https://$thumbsHost/galleries/$mediaId/${pageNum}t.$ext';
    final width = int.tryParse('${pageItem['w'] ?? 0}') ?? parentPost.width;
    final height = int.tryParse('${pageItem['h'] ?? 0}') ?? parentPost.height;

    final tagGroups = Map<String, List<String>>.from(parentPost.tagGroups)
      ..['parent_id'] = [parentPost.id]
      ..['page_index'] = [pageIndex.toString()]
      ..remove('children');

    return Post(
      id: '${parentPost.id}_p$pageIndex',
      providerId: parentPost.providerId,
      providerName: parentPost.providerName,
      previewUrl: previewUrl,
      sampleUrl: fileUrl,
      fileUrl: fileUrl,
      tags: parentPost.tags,
      rating: parentPost.rating,
      width: width,
      height: height,
      source: parentPost.source,
      createdAt: parentPost.createdAt,
      fileType: ext,
      score: parentPost.score,
      tagGroups: tagGroups,
    );
  }
}
