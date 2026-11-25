import 'package:gel_rule_app/core/models/cloud_media_link.dart';
import 'package:gel_rule_app/core/utils/cloud_link_extractor.dart';

class Post {
  const Post({
    required this.id,
    required this.providerId,
    required this.providerName,
    required this.previewUrl,
    required this.sampleUrl,
    required this.fileUrl,
    required this.tags,
    required this.rating,
    required this.width,
    required this.height,
    this.source,
    required this.createdAt,
    required this.fileType,
    required this.score,
    this.tagGroups = const {},
  });

  final String id;
  final String providerId;
  final String providerName;
  final String previewUrl;
  final String sampleUrl;
  final String fileUrl;
  final List<String> tags;
  final String rating;
  final int width;
  final int height;
  final String? source;
  final DateTime createdAt;
  final String fileType;
  final int score;
  final Map<String, List<String>> tagGroups;

  String get cacheKey => '$providerId:$id';

  /// Non-tag metadata keys stored in [tagGroups] that must not be treated
  /// as categorised post tags or tag groups.
  static const nonTagMetadataKeys = {
    'cloud_links',
    'description',
    'content',
    'links',
    'external_links',
    'is_detailed',
    'parent_id',
    'children',
    'pools',
    'page_count',
    'media_type',
    'has_notes',
    'fav_count',
    'comments_count',
    'duration',
    'duration_text',
    'video_variants',
    'uploader',
    'md5',
    'title',
    'type',
    'rus_title',
    'eng_title',
  };

  /// Returns `true` if this post contains domain tag categories
  /// beyond 'general' (e.g. artist, character, copyright, species, meta, lore).
  bool get hasCategorizedTagGroups {
    return tagGroups.entries.any(
      (entry) =>
          !nonTagMetadataKeys.contains(entry.key.toLowerCase()) &&
          entry.key != 'general' &&
          entry.value.isNotEmpty,
    );
  }

  static final RegExp _md5Regex = RegExp(r'([a-fA-F0-9]{32})');

  String? get md5Hash {
    final direct = tagGroups['md5']?.firstOrNull;
    if (direct != null && direct.trim().length == 32) {
      return direct.trim().toLowerCase();
    }
    final fileMatch = _md5Regex.firstMatch(fileUrl);
    if (fileMatch != null) {
      return fileMatch.group(1)!.toLowerCase();
    }
    final sampleMatch = _md5Regex.firstMatch(sampleUrl);
    if (sampleMatch != null) {
      return sampleMatch.group(1)!.toLowerCase();
    }
    return null;
  }

  /// Distinct content signature across providers. If an MD5 hash is known,
  /// two posts from different providers with the same image content match,
  /// preventing duplicates in cross-provider feeds.
  String get contentDedupeKey {
    final hash = md5Hash;
    return (hash != null && hash.isNotEmpty) ? 'md5:$hash' : cacheKey;
  }

  List<CloudMediaLink> get cloudLinks {
    final list = tagGroups['cloud_links'];
    if (list != null && list.isNotEmpty) {
      return list
          .map((e) => CloudMediaLink.tryDecode(e))
          .whereType<CloudMediaLink>()
          .toList(growable: false);
    }
    if (source != null && source!.isNotEmpty) {
      return CloudLinkExtractor.extractLinks(source: source);
    }
    return const [];
  }

  String? get commentary {
    final list = tagGroups['description'];
    if (list != null && list.isNotEmpty) {
      return list.first;
    }
    return null;
  }

  String? get description => commentary;

  String? get parentId {
    final list = tagGroups['parent_id'];
    return (list != null && list.isNotEmpty && list.first.trim().isNotEmpty)
        ? list.first.trim()
        : null;
  }

  List<String> get childrenIds => tagGroups['children'] ?? const [];

  int get pageCount {
    final explicitCount = tagGroups['page_count']?.firstOrNull;
    if (explicitCount != null) {
      final parsed = int.tryParse(explicitCount);
      if (parsed != null && parsed > 1) return parsed;
    }
    return childrenIds.isNotEmpty ? childrenIds.length + 1 : 1;
  }

  bool get isMultiPage => pageCount > 1;

  List<String> get poolIds => tagGroups['pools'] ?? const [];

  bool get hasRelations =>
      (parentId != null && parentId!.isNotEmpty) ||
      (childrenIds.isNotEmpty && providerId != 'pixiv');

  bool get hasPools => poolIds.isNotEmpty;

  bool get isUgoira =>
      fileType.toLowerCase() == 'ugoira' ||
      (tagGroups['media_type']?.contains('ugoira') ?? false);

  bool get hasNotes => tagGroups['has_notes']?.firstOrNull == 'true';

  /// Returns artist/creator tags for this post.
  List<String> get artistTags {
    final direct = tagGroups['artist'];
    if (direct != null && direct.isNotEmpty) return direct;
    final prefixMatch = tags
        .where((t) => t.startsWith('artist:') || t.startsWith('creator:'))
        .map((t) => t.replaceFirst('artist:', '').replaceFirst('creator:', ''))
        .where((t) => t.isNotEmpty)
        .toList();
    if (prefixMatch.isNotEmpty) return prefixMatch;
    return const [];
  }

  /// Primary clean artist name, excluding technical flags like conditional_dnp or unknown_artist.
  String? get artistName {
    final list = artistTags;
    if (list.isEmpty) return null;
    const nonArtistTags = {
      'conditional_dnp',
      'avoid_posting',
      'soundless',
      'third_party_edit',
      'unknown_artist',
      'anonymous_artist',
    };
    final real =
        list.where((a) => !nonArtistTags.contains(a.toLowerCase())).toList();
    final first = real.isNotEmpty ? real.first : list.first;
    return nonArtistTags.contains(first.toLowerCase()) ? null : first;
  }

  int? get favCount {
    final raw = tagGroups['fav_count']?.firstOrNull;
    return raw != null ? int.tryParse(raw) : null;
  }

  int get videoDurationSeconds {
    final raw = tagGroups['duration']?.firstOrNull;
    if (raw != null) {
      final parsed = int.tryParse(raw);
      if (parsed != null && parsed > 0) return parsed;
    }
    final text = tagGroups['duration_text']?.firstOrNull;
    if (text != null && text.trim().isNotEmpty) {
      return parseDurationString(text);
    }
    return 0;
  }

  List<String> get videoVariants => tagGroups['video_variants'] ?? const [];

  static int parseDurationString(String text) {
    final clean = text.trim();
    if (clean.isEmpty) return 0;
    final parts = clean.split(':');
    if (parts.length == 2) {
      final min = int.tryParse(parts[0]) ?? 0;
      final sec = int.tryParse(parts[1]) ?? 0;
      return min * 60 + sec;
    } else if (parts.length == 3) {
      final hr = int.tryParse(parts[0]) ?? 0;
      final min = int.tryParse(parts[1]) ?? 0;
      final sec = int.tryParse(parts[2]) ?? 0;
      return hr * 3600 + min * 60 + sec;
    }
    final mMatch = RegExp(r'(\d+)\s*m').firstMatch(clean);
    final sMatch = RegExp(r'(\d+)\s*s').firstMatch(clean);
    var total = 0;
    if (mMatch != null) total += (int.tryParse(mMatch.group(1)!) ?? 0) * 60;
    if (sMatch != null) total += int.tryParse(sMatch.group(1)!) ?? 0;
    return total;
  }

  String? get title {
    final list = tagGroups['title'] ?? tagGroups['copyright'];
    if (list != null && list.isNotEmpty) {
      return list.first;
    }
    return null;
  }

  List<String> get cleanTags {
    return tags.where((tag) {
      final t = tag.trim();
      if (t.isEmpty) return false;
      if (t == 'cloud_mirror' || t == 'text_post') return false;
      if (t.startsWith('{') && t.endsWith('}')) return false;
      if (t.contains('"url"') || t.contains('"service"')) return false;
      if (t.startsWith('http://') || t.startsWith('https://')) return false;
      if (t.contains('mega.nz') ||
          t.contains('drive.google.com') ||
          t.contains('dropbox.com') ||
          t.contains('pixeldrain.com') ||
          t.contains('catbox.moe') ||
          t.contains('mediafire.com')) {
        return false;
      }
      return true;
    }).toList(growable: false);
  }

  Post copyWith({
    String? id,
    String? providerId,
    String? providerName,
    String? previewUrl,
    String? sampleUrl,
    String? fileUrl,
    List<String>? tags,
    String? rating,
    int? width,
    int? height,
    String? source,
    DateTime? createdAt,
    String? fileType,
    int? score,
    Map<String, List<String>>? tagGroups,
  }) {
    return Post(
      id: id ?? this.id,
      providerId: providerId ?? this.providerId,
      providerName: providerName ?? this.providerName,
      previewUrl: previewUrl ?? this.previewUrl,
      sampleUrl: sampleUrl ?? this.sampleUrl,
      fileUrl: fileUrl ?? this.fileUrl,
      tags: tags ?? this.tags,
      rating: rating ?? this.rating,
      width: width ?? this.width,
      height: height ?? this.height,
      source: source ?? this.source,
      createdAt: createdAt ?? this.createdAt,
      fileType: fileType ?? this.fileType,
      score: score ?? this.score,
      tagGroups: tagGroups ?? this.tagGroups,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'providerId': providerId,
        'providerName': providerName,
        'previewUrl': previewUrl,
        'sampleUrl': sampleUrl,
        'fileUrl': fileUrl,
        'tags': tags,
        'rating': rating,
        'width': width,
        'height': height,
        'source': source,
        'createdAt': createdAt.toIso8601String(),
        'fileType': fileType,
        'score': score,
        'tagGroups': tagGroups,
      };

  factory Post.fromJson(Map<String, dynamic> json) => Post(
        id: json['id'].toString(),
        providerId: json['providerId'] as String,
        providerName: json['providerName'] as String,
        previewUrl: (json['previewUrl'] as String?) ?? '',
        sampleUrl: (json['sampleUrl'] as String?) ?? '',
        fileUrl: (json['fileUrl'] as String?) ?? '',
        tags: List<String>.from((json['tags'] as List?) ?? const []),
        rating: (json['rating'] as String?) ?? 'unknown',
        width: (json['width'] as num?)?.toInt() ?? 0,
        height: (json['height'] as num?)?.toInt() ?? 0,
        source: json['source'] as String?,
        createdAt: DateTime.tryParse((json['createdAt'] as String?) ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0),
        fileType: (json['fileType'] as String?) ?? 'unknown',
        score: (json['score'] as num?)?.toInt() ?? 0,
        tagGroups: (json['tagGroups'] as Map?)?.map(
              (key, value) => MapEntry(
                key.toString(),
                List<String>.from((value as List?) ?? const []),
              ),
            ) ??
            const {},
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Post &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          providerId == other.providerId;

  @override
  int get hashCode => id.hashCode ^ providerId.hashCode;
}

class PostNavigationContext {
  const PostNavigationContext({
    required this.currentPost,
    required this.posts,
    this.fromFeed = false,
  });

  final Post currentPost;
  final List<Post> posts;
  final bool fromFeed;
}
