import 'dart:convert';

import 'package:gel_rule_app/core/models/post.dart';

class GelbooruMapper {
  static List<Post> postsFromResponse(
    dynamic data, {
    required String providerId,
    required String providerName,
    String? baseUrl,
  }) {
    final items = _extractItems(data);
    return items
        .whereType<Map>()
        .map((item) => postFromJson(
              Map<String, dynamic>.from(item),
              providerId: providerId,
              providerName: providerName,
              baseUrl: baseUrl,
            ))
        .toList();
  }

  static Post postFromJson(
    Map<String, dynamic> json, {
    required String providerId,
    required String providerName,
    String? baseUrl,
  }) {
    final id = _string(json['id']);
    var fileUrl = _string(json['file_url'] ?? json['fileUrl']);
    var sampleUrl = _string(json['sample_url'] ??
        json['sampleUrl'] ??
        json['large_file_url'] ??
        fileUrl);
    var previewUrl =
        _string(json['preview_url'] ?? json['previewUrl'] ?? sampleUrl);

    // Fallback URL construction for Gelbooru 0.2 / TBIB engines
    if (fileUrl.isEmpty && json['image'] != null && json['directory'] != null) {
      final image = _string(json['image']);
      final directory = _string(json['directory']);
      if (image.isNotEmpty && directory.isNotEmpty) {
        final cleanBase = (baseUrl != null && baseUrl.isNotEmpty)
            ? (baseUrl.endsWith('/')
                ? baseUrl.substring(0, baseUrl.length - 1)
                : baseUrl)
            : 'https://tbib.org';
        final dotIndex = image.lastIndexOf('.');
        final baseName = dotIndex != -1 ? image.substring(0, dotIndex) : image;
        fileUrl = '$cleanBase/images/$directory/$image';
        final hasSample = json['sample'] == true ||
            json['sample'] == 1 ||
            json['sample'] == 'true';
        sampleUrl = hasSample
            ? '$cleanBase/samples/$directory/sample_$baseName.jpg'
            : fileUrl;
        previewUrl = '$cleanBase/thumbnails/$directory/thumbnail_$baseName.jpg';
      }
    }
    final explicitGroups = _tagGroupsFromJson(json);
    final tags = explicitGroups.isEmpty
        ? _tags(json['tags'] ?? json['tag_string'])
        : explicitGroups.values.expand((items) => items).toSet().toList();
    return Post(
      id: id,
      providerId: providerId,
      providerName: providerName,
      previewUrl: previewUrl,
      sampleUrl: sampleUrl,
      fileUrl: fileUrl,
      tags: tags,
      rating: _string(json['rating'], fallback: 'unknown'),
      width: _int(json['width']),
      height: _int(json['height']),
      source: _nullableString(json['source']),
      createdAt: _date(json['created_at'] ?? json['createdAt'] ?? json['change']),
      fileType: _fileType(fileUrl, json['file_ext']),
      score: _int(json['score']),
      tagGroups: explicitGroups.isEmpty ? _tagGroups(tags) : explicitGroups,
    );
  }

  static List<dynamic> _extractItems(dynamic data) {
    if (data is List) return data;
    if (data is String) {
      final trimmed = data.trim();
      if (trimmed.startsWith('[') || trimmed.startsWith('{')) {
        try {
          final decoded = jsonDecode(trimmed);
          return _extractItems(decoded);
        } catch (_) {}
      }
      return _extractItemsFromText(data);
    }
    if (data is Map) {
      final posts = data['post'] ?? data['posts'];
      if (posts is List) return posts;
      if (posts is Map && posts['post'] is List) return posts['post'] as List;
      if (posts is Map) return [posts];
    }
    return const [];
  }

  static List<Map<String, dynamic>> _extractItemsFromText(String text) {
    final items = <Map<String, dynamic>>[];
    for (final match
        in RegExp(r'<post\b([^>]*)/?>', caseSensitive: false, dotAll: true)
            .allMatches(text)) {
      final attrs = _attributes(match.group(1) ?? '');
      if (attrs.isNotEmpty) items.add(attrs);
    }
    return items;
  }

  static Map<String, dynamic> _attributes(String source) {
    final result = <String, dynamic>{};
    for (final match in RegExp(r'''([A-Za-z0-9_:-]+)\s*=\s*["']([^"']*)["']''')
        .allMatches(source)) {
      result[match.group(1)!] = _decodeEntities(match.group(2) ?? '');
    }
    return result;
  }

  static List<String> _tags(dynamic value) {
    if (value is List) return value.map((tag) => tag.toString()).toList();
    return _string(value)
        .split(RegExp(r'\s+'))
        .where((tag) => tag.trim().isNotEmpty)
        .toSet()
        .toList();
  }

  static int _int(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static String _string(dynamic value, {String fallback = ''}) {
    final text = value?.toString();
    return text == null || text.isEmpty ? fallback : text;
  }

  static String? _nullableString(dynamic value) {
    final text = value?.toString();
    return text == null || text.isEmpty ? null : text;
  }

  static DateTime _date(dynamic value) {
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value * 1000);
    if (value is String) {
      final asInt = int.tryParse(value);
      if (asInt != null && asInt > 1000000000) {
        return DateTime.fromMillisecondsSinceEpoch(asInt * 1000);
      }
    }
    return DateTime.tryParse(value?.toString() ?? '') ?? DateTime.now();
  }

  static String _fileType(String url, dynamic fileExt) {
    final lower = url.toLowerCase().split('?').first;
    final ext = _string(fileExt).toLowerCase();
    if (lower.endsWith('.webm') ||
        lower.endsWith('.mp4') ||
        ext == 'webm' ||
        ext == 'mp4') {
      return 'video';
    }
    if (lower.endsWith('.gif') || ext == 'gif') return 'gif';
    if (lower.isEmpty) return 'unknown';
    return 'image';
  }

  static Map<String, List<String>> _tagGroups(List<String> tags) {
    return tags.isEmpty ? const {} : {'general': tags};
  }

  static Map<String, List<String>> _tagGroupsFromJson(
    Map<String, dynamic> json,
  ) {
    final groups = <String, List<String>>{};
    void add(String key, dynamic value) {
      final tags = _tags(value);
      if (tags.isNotEmpty) groups[key] = tags;
    }

    add('general', json['tag_string_general'] ?? json['tags_general']);
    add('artist', json['tag_string_artist'] ?? json['tags_artist']);
    add('copyright', json['tag_string_copyright'] ?? json['tags_copyright']);
    add('character', json['tag_string_character'] ?? json['tags_character']);
    add('meta', json['tag_string_meta'] ?? json['tags_meta']);
    return groups;
  }

  static String _decodeEntities(String value) {
    return value
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#039;', "'")
        .replaceAll('&apos;', "'");
  }
}
