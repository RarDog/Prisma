import 'package:gel_rule_app/core/models/post.dart';

class DanbooruMapper {
  static List<Post> postsFromResponse(
    dynamic data, {
    required String providerId,
    required String providerName,
  }) {
    final items = data is List ? data : const [];
    return items
        .whereType<Map>()
        .map((item) => postFromJson(
              Map<String, dynamic>.from(item),
              providerId: providerId,
              providerName: providerName,
            ))
        .toList();
  }

  static Post postFromJson(
    Map<String, dynamic> json, {
    required String providerId,
    required String providerName,
  }) {
    String fileUrl = _string(json['file_url'] ?? json['large_file_url']);
    String sampleUrl =
        _string(json['large_file_url'] ?? json['sample_file_url'] ?? fileUrl);
    String previewUrl = _string(json['preview_file_url'] ?? sampleUrl);

    if (json['media_asset'] is Map) {
      final mediaAsset = Map<String, dynamic>.from(json['media_asset']);
      final variants = mediaAsset['variants'];
      if (variants is List) {
        for (final v in variants) {
          if (v is! Map) continue;
          final type = v['type']?.toString();
          final url = v['url']?.toString() ?? '';
          if (url.isEmpty) continue;
          if (type == 'original' && fileUrl.isEmpty) {
            fileUrl = url;
          } else if ((type == 'sample' || type == '720x720') &&
              sampleUrl.isEmpty) {
            sampleUrl = url;
          } else if ((type == '360x360' || type == '180x180') &&
              previewUrl.isEmpty) {
            previewUrl = url;
          }
        }
      }
    }
    if (fileUrl.isEmpty) fileUrl = sampleUrl;
    if (sampleUrl.isEmpty) sampleUrl = fileUrl;
    if (previewUrl.isEmpty) previewUrl = sampleUrl;

    DateTime createdAt;
    final rawCreated = json['created_at'];
    if (rawCreated is num) {
      final ts = rawCreated.toInt();
      createdAt = DateTime.fromMillisecondsSinceEpoch(
          ts > 10000000000 ? ts : ts * 1000);
    } else {
      final parsed = DateTime.tryParse(_string(rawCreated));
      if (parsed != null) {
        createdAt = parsed;
      } else {
        final ts = int.tryParse(_string(rawCreated));
        createdAt = ts != null
            ? DateTime.fromMillisecondsSinceEpoch(
                ts > 10000000000 ? ts : ts * 1000)
            : DateTime.now();
      }
    }
    final tagGroups = _tagGroups(json);
    final tags = tagGroups.isEmpty
        ? _tags(json['tag_string'] ?? json['tags'])
        : tagGroups.values.expand((items) => items).toSet().toList();
    return Post(
      id: _string(json['id']),
      providerId: providerId,
      providerName: providerName,
      previewUrl: previewUrl,
      sampleUrl: sampleUrl,
      fileUrl: fileUrl,
      tags: tags,
      rating: _string(json['rating'], fallback: 'unknown'),
      width: _int(json['image_width'] ?? json['width']),
      height: _int(json['image_height'] ?? json['height']),
      source: _nullableString(json['source']),
      createdAt: createdAt,
      fileType: _fileType(fileUrl, json['file_ext']),
      score: _int(json['score']),
      tagGroups: tagGroups.isEmpty ? {'general': tags} : tagGroups,
    );
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

  static Map<String, List<String>> _tagGroups(Map<String, dynamic> json) {
    final groups = <String, List<String>>{};
    void add(String key, dynamic value) {
      final tags = _tags(value);
      if (tags.isNotEmpty) groups[key] = tags;
    }

    add('general', json['tag_string_general']);
    add('artist', json['tag_string_artist']);
    add('copyright', json['tag_string_copyright']);
    add('character', json['tag_string_character']);
    add('meta', json['tag_string_meta']);
    return groups;
  }
}
