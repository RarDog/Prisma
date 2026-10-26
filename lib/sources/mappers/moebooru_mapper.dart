import 'package:gel_rule_app/core/models/post.dart';

class MoebooruMapper {
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
    final rawFileUrl = _string(json['file_url'] ?? json['jpeg_url']);
    final rawSampleUrl =
        _string(json['sample_url'] ?? json['jpeg_url'] ?? rawFileUrl);
    final rawPreviewUrl = _string(json['preview_url'] ?? rawSampleUrl);

    final fileUrl = rawFileUrl.isNotEmpty ? rawFileUrl : rawSampleUrl;
    final sampleUrl = rawSampleUrl.isNotEmpty ? rawSampleUrl : fileUrl;
    final previewUrl = rawPreviewUrl.isNotEmpty ? rawPreviewUrl : sampleUrl;

    final tags = _tags(json['tags'] ?? json['tag_string']);
    final parentId = _nullableString(json['parent_id']);
    final hasChildren = json['has_children'] == true;

    final tagGroups = <String, List<String>>{
      'general': tags,
      if (parentId != null && parentId.isNotEmpty && parentId != '0')
        'parent_id': [parentId],
      if (hasChildren) 'has_children': ['true'],
    };

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

    final width =
        _int(json['width'] ?? json['jpeg_width'] ?? json['sample_width']);
    final height =
        _int(json['height'] ?? json['jpeg_height'] ?? json['sample_height']);

    return Post(
      id: _string(json['id']),
      providerId: providerId,
      providerName: providerName,
      previewUrl: previewUrl,
      sampleUrl: sampleUrl,
      fileUrl: fileUrl,
      tags: tags,
      rating: _string(json['rating'], fallback: 's'),
      width: width,
      height: height,
      source: _nullableString(json['source']),
      createdAt: createdAt,
      fileType: _fileType(fileUrl, json['file_ext']),
      score: _int(json['score']),
      tagGroups: tagGroups,
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
    if (lower.endsWith('.png') || ext == 'png') return 'png';
    if (lower.isEmpty) return 'unknown';
    return 'jpg';
  }
}
