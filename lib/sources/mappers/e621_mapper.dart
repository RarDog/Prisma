import 'package:gel_rule_app/core/models/post.dart';

class E621Mapper {
  /// In-memory tag category lookup cache shared with [E621Provider].
  static final Map<String, String> tagCategoryCache = {};

  /// Synchronously groups known tags from [tagCategoryCache].
  static Map<String, List<String>> getCachedCategorizedTags(List<String> tags) {
    if (tags.isEmpty || tagCategoryCache.isEmpty) return const {};
    final groups = <String, List<String>>{};
    for (final tag in tags) {
      final category = tagCategoryCache[tag];
      if (category != null && category.isNotEmpty) {
        groups.putIfAbsent(category, () => []).add(tag);
      }
    }
    return groups;
  }
  static List<Post> postsFromResponse(
    dynamic data, {
    required String providerId,
    required String providerName,
  }) {
    if (data is Map && data['post'] is Map) {
      return [
        postFromJson(
          Map<String, dynamic>.from(data['post'] as Map),
          providerId: providerId,
          providerName: providerName,
        ),
      ];
    }
    if (data is Map && data['id'] != null && (data['files'] != null || data['file'] != null)) {
      return [
        postFromJson(
          Map<String, dynamic>.from(data),
          providerId: providerId,
          providerName: providerName,
        ),
      ];
    }
    final posts = data is Map ? (data['posts'] ?? data['post']) : data;
    final items = posts is List ? posts : (posts is Map ? [posts] : const []);
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
    // Supports both new e621 schema ("files": {"original": ..., "preview": ..., "sample": ..., "meta": ...})
    // and legacy Danbooru schema ("file": ..., "preview": ..., "sample": ...).
    final files =
        Map<String, dynamic>.from((json['files'] as Map?) ?? const {});
    final original =
        Map<String, dynamic>.from((files['original'] as Map?) ?? const {});
    final fileMeta =
        Map<String, dynamic>.from((files['meta'] as Map?) ?? const {});
    final oldFile =
        Map<String, dynamic>.from((json['file'] as Map?) ?? const {});

    final fileUrl = _string(original['url'] ?? oldFile['url']);
    final width = _int(original['width'] ?? oldFile['width']);
    final height = _int(original['height'] ?? oldFile['height']);
    final fileExt = fileMeta['ext'] ?? oldFile['ext'];

    final isVideo = _fileType(fileUrl, fileExt) == 'video';

    // Parse video transcoding variants and samples if present in files.video
    final videoObj =
        Map<String, dynamic>.from((files['video'] as Map?) ?? const {});
    final videoVariants =
        Map<String, dynamic>.from((videoObj['variants'] as Map?) ?? const {});
    final videoSamples =
        Map<String, dynamic>.from((videoObj['samples'] as Map?) ?? const {});
    final mp4Variant =
        Map<String, dynamic>.from((videoVariants['mp4'] as Map?) ?? const {});
    final sample720p =
        Map<String, dynamic>.from((videoSamples['720p'] as Map?) ?? const {});
    final sample480p =
        Map<String, dynamic>.from((videoSamples['480p'] as Map?) ?? const {});

    final mp4Url = _string(mp4Variant['url']);
    final sample720Url = _string(sample720p['url']);
    final sample480Url = _string(sample480p['url']);

    final previewMap = Map<String, dynamic>.from(
        (files['preview'] as Map?) ?? (json['preview'] as Map?) ?? const {});
    final previewUrl = _string(
      previewMap['webp'] ?? previewMap['jpg'] ?? previewMap['url'] ?? fileUrl,
    );

    final sampleMap = Map<String, dynamic>.from(
        (files['sample'] as Map?) ?? (json['sample'] as Map?) ?? const {});
    final sampleUrl = isVideo
        ? (mp4Url.isNotEmpty
            ? mp4Url
            : (sample720Url.isNotEmpty ? sample720Url : fileUrl))
        : _string(
            sampleMap['webp'] ??
                sampleMap['jpg'] ??
                sampleMap['url'] ??
                fileUrl,
          );

    final stats =
        Map<String, dynamic>.from((json['stats'] as Map?) ?? const {});
    final scoreMap = Map<String, dynamic>.from(
        (stats['score'] as Map?) ?? (json['score'] as Map?) ?? const {});
    final score = _int(scoreMap['total'] ?? stats['score'] ?? json['score']);

    final tagGroups = <String, List<String>>{};
    final rawTags = json['tags'];
    final List<String> tags;
    if (rawTags is Map) {
      for (final entry in rawTags.entries) {
        final list = List<String>.from((entry.value as List?) ?? const []);
        if (list.isNotEmpty) {
          tagGroups[entry.key.toString()] = list;
        }
      }
      tags = tagGroups.values.expand((items) => items).toSet().toList();
    } else if (rawTags is List) {
      tags = rawTags
          .map((e) => e?.toString() ?? '')
          .where((s) => s.isNotEmpty)
          .toList();
      final cachedGroups = getCachedCategorizedTags(tags);
      if (cachedGroups.isNotEmpty) {
        tagGroups.addAll(cachedGroups);
        final categorizedSet = cachedGroups.values.expand((e) => e).toSet();
        final uncached =
            tags.where((t) => !categorizedSet.contains(t)).toList();
        if (uncached.isNotEmpty) {
          tagGroups.putIfAbsent('general', () => []).addAll(uncached);
        }
      } else {
        tagGroups['general'] = tags;
      }
    } else {
      tags = const [];
    }

    final relationships =
        Map<String, dynamic>.from((json['relationships'] as Map?) ?? const {});
    final parentId = relationships['parent_id']?.toString();
    if (parentId != null && parentId.isNotEmpty && parentId != 'null') {
      tagGroups['parent_id'] = [parentId];
    }
    final children = (relationships['children'] as List?)
        ?.map((e) => e?.toString() ?? '')
        .where((s) => s.isNotEmpty && s != 'null')
        .toList();
    if (children != null && children.isNotEmpty) {
      tagGroups['children'] = children;
    }

    final rawPools = (json['pools'] as List?)
        ?.map((e) => e?.toString() ?? '')
        .where((s) => s.isNotEmpty)
        .toList();
    if (rawPools != null && rawPools.isNotEmpty) {
      tagGroups['pools'] = rawPools;
    }

    final favCount = stats['fav_count'] ?? json['fav_count'];
    if (favCount != null) {
      tagGroups['fav_count'] = [favCount.toString()];
    }

    final commentsCount = stats['comment_count'] ?? json['comment_count'];
    if (commentsCount != null) {
      tagGroups['comments_count'] = [commentsCount.toString()];
    }

    final desc = _string(json['description']);
    if (desc.isNotEmpty) {
      tagGroups['description'] = [desc];
    }

    final hasNotes = json['has_notes'] == true ||
        json['last_noted_at'] != null ||
        (json['has'] is Map && (json['has'] as Map)['notes'] == true) ||
        (json['flags'] is Map && (json['flags'] as Map)['has_notes'] == true);
    if (hasNotes) {
      tagGroups['has_notes'] = ['true'];
    }

    final duration = fileMeta['duration'];
    if (duration != null && duration is num && duration > 0) {
      tagGroups['duration'] = [duration.toInt().toString()];
    }

    final variantList = <String>[];
    if (mp4Url.isNotEmpty) variantList.add('1080p MP4|$mp4Url');
    if (sample720Url.isNotEmpty) variantList.add('720p MP4|$sample720Url');
    if (sample480Url.isNotEmpty) variantList.add('480p MP4|$sample480Url');
    if (fileUrl.isNotEmpty && isVideo) variantList.add('Original|$fileUrl');
    if (variantList.isNotEmpty) {
      tagGroups['video_variants'] = variantList;
    }

    final uploader = json['uploader_name']?.toString();
    if (uploader != null && uploader.isNotEmpty && !tagGroups.containsKey('artist')) {
      tagGroups['uploader'] = [uploader];
    }

    return Post(
      id: _string(json['id']),
      providerId: providerId,
      providerName: providerName,
      previewUrl: previewUrl,
      sampleUrl: sampleUrl,
      fileUrl: fileUrl,
      tags: tags,
      rating: _rating(_string(json['rating'], fallback: 'unknown')),
      width: width,
      height: height,
      source: _sources(json['sources']),
      createdAt:
          DateTime.tryParse(_string(json['created_at'])) ?? DateTime.now(),
      fileType: _fileType(fileUrl, fileExt),
      score: score,
      tagGroups: tagGroups,
    );
  }

  static String _rating(String value) {
    return switch (value.toLowerCase()) {
      's' => 'safe',
      'q' => 'questionable',
      'e' => 'explicit',
      _ => value,
    };
  }

  static String? _sources(dynamic value) {
    if (value is List && value.isNotEmpty) return value.first.toString();
    final text = value?.toString();
    return text == null || text.isEmpty ? null : text;
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
}
