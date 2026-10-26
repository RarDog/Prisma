import 'package:prisma_app/core/models/post.dart';

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
    final rawExt = _string(
      json['file_ext'] ??
          (json['media_asset'] is Map
              ? json['media_asset']['file_ext']
              : null),
    ).toLowerCase();

    final hash = _string(
      json['md5'] ??
          (json['media_asset'] is Map
              ? (json['media_asset']['pixel_hash'] ??
                  json['media_asset']['md5'])
              : null),
    );

    String? cdnOriginal;
    String? cdn720;
    String? cdn360;
    String? cdn180;
    if (hash.length >= 4) {
      final prefix = '${hash.substring(0, 2)}/${hash.substring(2, 4)}';
      final ext = rawExt.isNotEmpty ? rawExt : 'jpg';
      cdnOriginal = 'https://cdn.donmai.us/original/$prefix/$hash.$ext';
      cdn720 = 'https://cdn.donmai.us/720x720/$prefix/$hash.webp';
      cdn360 = 'https://cdn.donmai.us/360x360/$prefix/$hash.jpg';
      cdn180 = 'https://cdn.donmai.us/180x180/$prefix/$hash.jpg';
    }

    String? variantOriginal;
    String? variantSample;
    String? variant720;
    String? variant360;
    String? variant180;

    if (json['media_asset'] is Map) {
      final mediaAsset = Map<String, dynamic>.from(json['media_asset']);
      final variants = mediaAsset['variants'];
      if (variants is List) {
        for (final v in variants) {
          if (v is! Map) continue;
          final type = v['type']?.toString();
          final url = v['url']?.toString() ?? '';
          if (url.isEmpty) continue;
          switch (type) {
            case 'original':
              variantOriginal = url;
              break;
            case 'sample':
              variantSample = url;
              break;
            case '720x720':
              variant720 = url;
              break;
            case '360x360':
              variant360 = url;
              break;
            case '180x180':
              variant180 = url;
              break;
          }
        }
      }
    }

    final rawFileUrl = _string(json['file_url']);
    final rawLargeUrl = _string(json['large_file_url']);
    final rawPreviewUrl = _string(json['preview_file_url']);

    final isVideo = rawExt == 'mp4' ||
        rawExt == 'webm' ||
        rawExt == 'mov' ||
        rawExt == 'mkv' ||
        _looksLikeVideo(rawFileUrl) ||
        _looksLikeVideo(rawLargeUrl) ||
        (variantOriginal != null && _looksLikeVideo(variantOriginal));

    String fileUrl;
    String sampleUrl;
    String previewUrl;

    if (isVideo) {
      fileUrl = variantOriginal ??
          (rawFileUrl.isNotEmpty ? rawFileUrl : null) ??
          (rawLargeUrl.isNotEmpty ? rawLargeUrl : null) ??
          cdnOriginal ??
          '';

      final nonVideoPreview =
          rawPreviewUrl.isNotEmpty && !_looksLikeVideo(rawPreviewUrl)
              ? rawPreviewUrl
              : null;
      final nonVideoLarge =
          rawLargeUrl.isNotEmpty && !_looksLikeVideo(rawLargeUrl)
              ? rawLargeUrl
              : null;

      previewUrl = variant180 ??
          cdn180 ??
          variant360 ??
          cdn360 ??
          nonVideoPreview ??
          variant720 ??
          cdn720 ??
          '';

      sampleUrl = variant720 ??
          cdn720 ??
          variant360 ??
          cdn360 ??
          nonVideoLarge ??
          previewUrl;

      if (previewUrl.isEmpty) previewUrl = sampleUrl;
    } else {
      fileUrl = variantOriginal ??
          (rawFileUrl.isNotEmpty ? rawFileUrl : null) ??
          (rawLargeUrl.isNotEmpty ? rawLargeUrl : null) ??
          cdnOriginal ??
          '';

      sampleUrl = variantSample ??
          variant720 ??
          (rawLargeUrl.isNotEmpty ? rawLargeUrl : null) ??
          cdn720 ??
          (json['sample_file_url'] != null &&
                  _string(json['sample_file_url']).isNotEmpty
              ? _string(json['sample_file_url'])
              : null) ??
          fileUrl;

      previewUrl = variant180 ??
          cdn180 ??
          variant360 ??
          cdn360 ??
          (rawPreviewUrl.isNotEmpty ? rawPreviewUrl : null) ??
          sampleUrl;

      if (fileUrl.isEmpty) fileUrl = sampleUrl;
      if (sampleUrl.isEmpty) sampleUrl = fileUrl;
      if (previewUrl.isEmpty) previewUrl = sampleUrl;
    }

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
      fileType: isVideo ? 'video' : _fileType(fileUrl, rawExt),
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

  static bool _looksLikeVideo(String url) {
    if (url.isEmpty) return false;
    final lower = url.toLowerCase().split('?').first;
    return lower.endsWith('.webm') ||
        lower.endsWith('.mp4') ||
        lower.endsWith('.mov') ||
        lower.endsWith('.mkv');
  }

  static String _fileType(String url, dynamic fileExt) {
    final lower = url.toLowerCase().split('?').first;
    final ext = _string(fileExt).toLowerCase();
    if (lower.endsWith('.webm') ||
        lower.endsWith('.mp4') ||
        lower.endsWith('.mov') ||
        lower.endsWith('.mkv') ||
        ext == 'webm' ||
        ext == 'mp4' ||
        ext == 'mov' ||
        ext == 'mkv') {
      return 'video';
    }
    if (lower.endsWith('.gif') || ext == 'gif') return 'gif';
    if (lower.endsWith('.zip') ||
        lower.endsWith('.rar') ||
        ext == 'zip' ||
        ext == 'rar') {
      return 'archive';
    }
    if (lower.isEmpty && ext.isEmpty) return 'unknown';
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
