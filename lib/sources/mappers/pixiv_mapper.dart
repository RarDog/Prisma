import 'dart:convert';

import 'package:gel_rule_app/core/models/post.dart';

class PixivMapper {
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

  static String toMasterUrl(String thumbUrl) {
    if (thumbUrl.isEmpty) return thumbUrl;
    var url = thumbUrl.replaceAll(RegExp(r'/c/[^/]+/'), '/');
    url = url.replaceAll('square1200', 'master1200');
    return url;
  }

  static String _fileType(String url) {
    final clean = url.split('?').first.toLowerCase();
    if (clean.endsWith('.png')) return 'png';
    if (clean.endsWith('.gif')) return 'gif';
    if (clean.endsWith('.webm')) return 'webm';
    if (clean.endsWith('.mp4')) return 'mp4';
    return 'jpg';
  }

  static List<Post> postsFromRankingResponse(
    dynamic data, {
    required String providerId,
    required String providerName,
  }) {
    final parsed = _normalizeJson(data);
    if (parsed is! Map) return const [];
    final contents = parsed['contents'];
    if (contents is! List) return const [];

    final posts = <Post>[];
    for (final raw in contents) {
      if (raw is! Map) continue;
      final item = Map<String, dynamic>.from(raw);
      final rawId = item['illust_id'] ?? item['id'];
      if (rawId == null) continue;
      final id = rawId.toString();

      final thumbUrl = item['url']?.toString() ?? '';
      final masterUrl = toMasterUrl(thumbUrl);
      final pageCount = int.tryParse('${item['illust_page_count'] ?? 1}') ?? 1;
      final artist = item['user_name']?.toString() ?? '';
      final title = item['title']?.toString() ?? '';

      final rawTags = item['tags'];
      final tags = <String>[];
      if (rawTags is List) {
        for (final t in rawTags) {
          if (t != null && t.toString().isNotEmpty) {
            tags.add(t.toString());
          }
        }
      }

      final isExplicit = item['illust_content_type'] is Map &&
          ((item['illust_content_type']['sexual'] as num?) ?? 0) > 0;

      final tagGroups = <String, List<String>>{
        'general': tags,
        if (artist.isNotEmpty) 'artist': [artist],
        if (title.isNotEmpty) 'copyright': [title],
        if (pageCount > 1)
          'children': List.generate(pageCount - 1, (i) => '${id}_p${i + 1}'),
      };

      DateTime createdAt;
      final uploadTs = item['illust_upload_timestamp'];
      if (uploadTs is num) {
        createdAt =
            DateTime.fromMillisecondsSinceEpoch(uploadTs.toInt() * 1000);
      } else {
        createdAt = DateTime.now();
      }

      final ratingCount = int.tryParse('${item['rating_count'] ?? 0}') ?? 0;
      final viewCount = int.tryParse('${item['view_count'] ?? 0}') ?? 0;

      posts.add(Post(
        id: id,
        providerId: providerId,
        providerName: providerName,
        previewUrl: thumbUrl,
        sampleUrl: masterUrl.isNotEmpty ? masterUrl : thumbUrl,
        fileUrl: masterUrl.isNotEmpty ? masterUrl : thumbUrl,
        tags: tags,
        rating: isExplicit ? 'e' : 's',
        width: int.tryParse('${item['width'] ?? 0}') ?? 0,
        height: int.tryParse('${item['height'] ?? 0}') ?? 0,
        source: 'https://www.pixiv.net/artworks/$id',
        createdAt: createdAt,
        fileType: _fileType(masterUrl.isNotEmpty ? masterUrl : thumbUrl),
        score: ratingCount > 0 ? ratingCount : viewCount,
        tagGroups: tagGroups,
      ));
    }
    return posts;
  }

  static List<Post> postsFromSearchResponse(
    dynamic data, {
    required String providerId,
    required String providerName,
  }) {
    final parsed = _normalizeJson(data);
    if (parsed is! Map) return const [];
    final body = parsed['body'];
    if (body is! Map) return const [];
    final illustManga = body['illustManga'];
    if (illustManga is! Map) return const [];
    final items = illustManga['data'];
    if (items is! List) return const [];

    return _postsFromIllustList(
      items,
      providerId: providerId,
      providerName: providerName,
    );
  }

  /// Parses /ajax/follow_latest/illust response (body.thumbnails.illust[])
  static List<Post> postsFromFollowFeedResponse(
    dynamic data, {
    required String providerId,
    required String providerName,
  }) {
    final parsed = _normalizeJson(data);
    if (parsed is! Map) return const [];
    final body = parsed['body'];
    if (body is! Map) return const [];
    final thumbnails = body['thumbnails'];
    if (thumbnails is! Map) return const [];
    final items = thumbnails['illust'];
    if (items is! List) return const [];

    return _postsFromIllustList(
      items,
      providerId: providerId,
      providerName: providerName,
    );
  }

  /// Shared parser for both search and follow-feed illust items
  /// (same structure: id, title, url, tags, userName, pageCount, xRestrict, createDate)
  static List<Post> _postsFromIllustList(
    List<dynamic> items, {
    required String providerId,
    required String providerName,
  }) {
    final posts = <Post>[];
    for (final raw in items) {
      if (raw is! Map) continue;
      final item = Map<String, dynamic>.from(raw);
      final rawId = item['id'];
      if (rawId == null) continue;
      final id = rawId.toString();

      final thumbUrl = item['url']?.toString() ?? '';
      final masterUrl = toMasterUrl(thumbUrl);
      final pageCount = int.tryParse('${item['pageCount'] ?? 1}') ?? 1;
      final artist = item['userName']?.toString() ?? '';
      final title = item['title']?.toString() ?? '';

      final rawTags = item['tags'];
      final tags = <String>[];
      if (rawTags is List) {
        for (final t in rawTags) {
          if (t != null && t.toString().isNotEmpty) {
            tags.add(t.toString());
          }
        }
      }

      final xRestrict = int.tryParse('${item['xRestrict'] ?? 0}') ?? 0;
      final isExplicit = xRestrict > 0;

      final description = item['description']?.toString() ?? '';

      final tagGroups = <String, List<String>>{
        'general': tags,
        if (artist.isNotEmpty) 'artist': [artist],
        if (title.isNotEmpty) 'copyright': [title],
        if (description.isNotEmpty) 'description': [description],
        if (pageCount > 1)
          'children': List.generate(pageCount - 1, (i) => '${id}_p${i + 1}'),
      };

      final createDateStr = item['createDate']?.toString();
      final createdAt = createDateStr != null
          ? DateTime.tryParse(createDateStr) ?? DateTime.now()
          : DateTime.now();

      final bookmarkCount =
          int.tryParse('${item['bookmarkCount'] ?? 0}') ?? 0;
      final likeCount = int.tryParse('${item['likeCount'] ?? 0}') ?? 0;

      posts.add(Post(
        id: id,
        providerId: providerId,
        providerName: providerName,
        previewUrl: thumbUrl,
        sampleUrl: masterUrl.isNotEmpty ? masterUrl : thumbUrl,
        fileUrl: masterUrl.isNotEmpty ? masterUrl : thumbUrl,
        tags: tags,
        rating: isExplicit ? 'e' : 's',
        width: int.tryParse('${item['width'] ?? 0}') ?? 0,
        height: int.tryParse('${item['height'] ?? 0}') ?? 0,
        source: 'https://www.pixiv.net/artworks/$id',
        createdAt: createdAt,
        fileType: _fileType(masterUrl.isNotEmpty ? masterUrl : thumbUrl),
        score: likeCount > 0 ? likeCount : bookmarkCount,
        tagGroups: tagGroups,
      ));
    }
    return posts;
  }

  static Post? postFromIllustResponse(
    dynamic data, {
    required String providerId,
    required String providerName,
  }) {
    final parsed = _normalizeJson(data);
    if (parsed is! Map) return null;
    final body = parsed['body'];
    if (body is! Map) return null;

    final rawId = body['id'] ?? body['illustId'];
    if (rawId == null) return null;
    final id = rawId.toString();

    final urls = body['urls'] is Map ? Map<String, dynamic>.from(body['urls']) : const {};
    final original = urls['original']?.toString() ?? '';
    final regular = urls['regular']?.toString() ?? '';
    final small = urls['small']?.toString() ?? '';
    final thumb = urls['thumb']?.toString() ?? '';

    final fileUrl = original.isNotEmpty ? original : regular;
    final sampleUrl = regular.isNotEmpty ? regular : fileUrl;
    final previewUrl = small.isNotEmpty ? small : (thumb.isNotEmpty ? thumb : sampleUrl);

    final title = body['title']?.toString() ?? '';
    final artist = body['userName']?.toString() ?? '';
    final description = body['description']?.toString() ?? '';

    final tags = <String>[];
    final rawTagsObj = body['tags'];
    if (rawTagsObj is Map && rawTagsObj['tags'] is List) {
      for (final t in rawTagsObj['tags']) {
        if (t is Map && t['tag'] != null) {
          tags.add(t['tag'].toString());
          final translation = t['translation'];
          if (translation is Map && translation['en'] != null) {
            tags.add(translation['en'].toString());
          }
        }
      }
    }

    final pageCount = int.tryParse('${body['pageCount'] ?? 1}') ?? 1;
    final xRestrict = int.tryParse('${body['xRestrict'] ?? 0}') ?? 0;
    final isExplicit = xRestrict > 0;

    final bookmarkCount = int.tryParse('${body['bookmarkCount'] ?? 0}') ?? 0;
    final likeCount = int.tryParse('${body['likeCount'] ?? 0}') ?? 0;
    final score = likeCount > 0 ? likeCount : bookmarkCount;

    final createDateStr = body['createDate']?.toString();
    final createdAt = createDateStr != null
        ? DateTime.tryParse(createDateStr) ?? DateTime.now()
        : DateTime.now();

    final tagGroups = <String, List<String>>{
      'general': tags,
      if (artist.isNotEmpty) 'artist': [artist],
      if (title.isNotEmpty) 'copyright': [title],
      if (description.isNotEmpty) 'description': [description],
      if (pageCount > 1)
        'children': List.generate(pageCount - 1, (i) => '${id}_p${i + 1}'),
    };

    return Post(
      id: id,
      providerId: providerId,
      providerName: providerName,
      previewUrl: previewUrl,
      sampleUrl: sampleUrl,
      fileUrl: fileUrl,
      tags: tags,
      rating: isExplicit ? 'e' : 's',
      width: int.tryParse('${body['width'] ?? 0}') ?? 0,
      height: int.tryParse('${body['height'] ?? 0}') ?? 0,
      source: 'https://www.pixiv.net/artworks/$id',
      createdAt: createdAt,
      fileType: _fileType(fileUrl),
      score: score,
      tagGroups: tagGroups,
    );
  }

  static Post? postFromPageResponse({
    required dynamic pageData,
    required Post parentPost,
    required int pageIndex,
  }) {
    if (pageData is! Map) return null;
    final urls = pageData['urls'] is Map
        ? Map<String, dynamic>.from(pageData['urls'])
        : const {};
    final original = urls['original']?.toString() ?? '';
    final regular = urls['regular']?.toString() ?? '';
    final small = urls['small']?.toString() ?? '';
    final thumbMini = urls['thumb_mini']?.toString() ?? '';

    final fileUrl = original.isNotEmpty ? original : regular;
    final sampleUrl = regular.isNotEmpty ? regular : fileUrl;
    final previewUrl = small.isNotEmpty ? small : (thumbMini.isNotEmpty ? thumbMini : sampleUrl);

    final width = int.tryParse('${pageData['width'] ?? 0}') ?? parentPost.width;
    final height = int.tryParse('${pageData['height'] ?? 0}') ?? parentPost.height;

    final tagGroups = Map<String, List<String>>.from(parentPost.tagGroups)
      ..['parent_id'] = [parentPost.id]
      ..remove('children');

    return Post(
      id: '${parentPost.id}_p$pageIndex',
      providerId: parentPost.providerId,
      providerName: parentPost.providerName,
      previewUrl: previewUrl,
      sampleUrl: sampleUrl,
      fileUrl: fileUrl,
      tags: parentPost.tags,
      rating: parentPost.rating,
      width: width,
      height: height,
      source: parentPost.source,
      createdAt: parentPost.createdAt,
      fileType: _fileType(fileUrl),
      score: parentPost.score,
      tagGroups: tagGroups,
    );
  }
}
