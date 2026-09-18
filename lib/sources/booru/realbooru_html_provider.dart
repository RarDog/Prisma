import 'dart:convert';

import 'package:dio/dio.dart';

import 'package:gel_rule_app/core/http/dio_client.dart';
import 'package:gel_rule_app/core/models/post.dart';
import 'package:gel_rule_app/core/models/post_comment.dart';
import 'package:gel_rule_app/core/models/provider_health.dart';
import 'package:gel_rule_app/core/models/tag_suggestion.dart';
import 'package:gel_rule_app/core/models/top_period_filter.dart';
import 'package:gel_rule_app/sources/interfaces/content_provider.dart';

class RealbooruHtmlProvider
    implements
        ContentProvider,
        PostPageProvider,
        MediaHeadersProvider,
        TagSuggestionProvider,
        CommentProvider {
  RealbooruHtmlProvider({
    required this.id,
    required this.name,
    required this.baseUrl,
    required DioClient dioClient,
  }) : _dio = dioClient.dio;

  @override
  final String id;
  @override
  final String name;
  @override
  final String baseUrl;
  final Dio _dio;

  @override
  Future<List<Post>> searchPosts({
    required List<String> tags,
    required int page,
    int limit = 50,
    String? rating,
    TopPeriodFilter topPeriod = TopPeriodFilter.none,
  }) async {
    final topTags = switch (topPeriod) {
      TopPeriodFilter.none => const <String>[],
      _ => const ['sort:score:desc'],
    };
    final effectiveTags = [
      if (tags.isEmpty && topTags.isEmpty) 'all',
      ...tags,
      if (rating != null && rating.isNotEmpty) 'rating:$rating',
      if (topTags.isNotEmpty &&
          !tags.any((t) => t.startsWith('sort:') || t.startsWith('order:')))
        ...topTags,
    ].where((t) => t.isNotEmpty).join(' ');

    final response = await _dio.get<String>(
      '/index.php',
      queryParameters: {
        'page': 'post',
        's': 'list',
        'tags': effectiveTags.isEmpty ? 'all' : effectiveTags,
        'pid': page * limit,
      },
      options: Options(responseType: ResponseType.plain),
    );
    return _parseList(response.data ?? '').take(limit).toList(growable: false);
  }

  @override
  Future<Post?> getPost(String id) async {
    final response = await _dio.get<String>(
      '/index.php',
      queryParameters: {'page': 'post', 's': 'view', 'id': id},
      options: Options(responseType: ResponseType.plain),
    );
    return _parseDetails(id, response.data ?? '');
  }

  @override
  Future<List<PostComment>> getComments(String postId) async {
    try {
      final response = await _dio.get<String>(
        '/index.php',
        queryParameters: {'page': 'post', 's': 'view', 'id': postId},
        options: Options(responseType: ResponseType.plain),
      );
      return _parseComments(postId, response.data ?? '');
    } catch (_) {
      return const [];
    }
  }

  @override
  Future<ProviderHealth> checkHealth() async {
    final startedAt = DateTime.now();
    try {
      final posts = await searchPosts(tags: const ['all'], page: 0, limit: 1);
      return ProviderHealth(
        providerId: id,
        status: posts.isEmpty ? ProviderStatus.offline : ProviderStatus.online,
        pingMs: DateTime.now().difference(startedAt).inMilliseconds,
        lastCheckedAt: DateTime.now(),
        apiVersion: 'realbooru-html',
        errorMessage: posts.isEmpty ? 'No posts found in HTML response' : null,
      );
    } catch (error) {
      return ProviderHealth(
        providerId: id,
        status: ProviderStatus.offline,
        pingMs: DateTime.now().difference(startedAt).inMilliseconds,
        lastCheckedAt: DateTime.now(),
        errorMessage: error.toString(),
      );
    }
  }

  @override
  String postPageUrl(Post post) =>
      '$baseUrl/index.php?page=post&s=view&id=${post.id}';

  @override
  Map<String, String> mediaHeaders(Post post) => {
        'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        'Accept':
            'video/webm,video/mp4,image/avif,image/webp,image/apng,image/*,*/*;q=0.8',
        'Referer': '$baseUrl/',
      };

  @override
  Future<List<TagSuggestion>> suggestTags(String query,
      {int limit = 20}) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return const [];

    try {
      final response = await _dio.get<dynamic>(
        '/autocomplete.php',
        queryParameters: {'q': trimmed},
      );
      final suggestions = _parseAutocomplete(response.data);
      if (suggestions.isNotEmpty) {
        return suggestions.take(limit.clamp(1, 50)).toList(growable: false);
      }
    } catch (_) {}

    try {
      final response = await _dio.get<dynamic>(
        '/index.php',
        queryParameters: {
          'page': 'autocomplete',
          'term': trimmed,
        },
      );
      final values = _autocompleteItems(response.data);
      return values
          .map((name) => TagSuggestion(
                name: name,
                category: TagCategory.unknown,
                postCount: 0,
                providerId: id,
              ))
          .where((item) => item.name.toLowerCase().startsWith(
                trimmed.toLowerCase(),
              ))
          .take(limit.clamp(1, 50))
          .toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  List<Post> _parseList(String html) {
    final posts = <Post>[];
    final pattern = RegExp(
      r'''<div[^>]*class=["'][^"']*\bthumb\b[^"']*["'][^>]*id=["']s(\d+)["'][\s\S]*?<a[^>]+href=["']([^"']*page=post[^"']*s=view[^"']*id=\d+[^"']*)["'][\s\S]*?<img[^>]+src=["']([^"']+)["'][^>]*>''',
      caseSensitive: false,
    );
    for (final match in pattern.allMatches(html)) {
      final id = match.group(1) ?? '';
      final imgTag = match.group(0) ?? '';
      final previewUrl = _absolute(_decode(match.group(3) ?? ''));
      final tags = _tags(_attribute(imgTag, 'title'));
      final isVideo = imgTag.contains('#0000ff') ||
          tags.contains('webm') ||
          tags.contains('video');
      final isGif =
          !isVideo && (tags.contains('gif') || tags.contains('animated_gif'));
      final derivedOriginal = _imageUrlFromThumbnail(
        previewUrl,
        gif: isGif,
        video: isVideo,
      );
      posts.add(
        Post(
          id: id,
          providerId: this.id,
          providerName: name,
          previewUrl: previewUrl,
          sampleUrl: derivedOriginal.isEmpty ? previewUrl : derivedOriginal,
          fileUrl: derivedOriginal.isEmpty ? previewUrl : derivedOriginal,
          tags: tags,
          rating: 'explicit',
          width: 0,
          height: 0,
          source: postPageUrlById(id),
          createdAt: DateTime.now(),
          fileType: isVideo
              ? 'video'
              : isGif
                  ? 'gif'
                  : 'image',
          score: 0,
          tagGroups: _tagGroups(tags),
        ),
      );
    }
    return posts;
  }

  Post? _parseDetails(String postId, String html) {
    final imageTag = RegExp(
      r'''<(?:img|video)[^>]+(?:id=["']image["'][^>]*|[^>]*id=["']image["'])''',
      caseSensitive: false,
    ).firstMatch(html)?.group(0);
    final originalUrl = _absolute(
      RegExp(
            r'''<a[^>]+href=["']([^"']+)["'][^>]*>\s*Original\s*</a>''',
            caseSensitive: false,
          ).firstMatch(html)?.group(1) ??
          '',
    );
    final videoSources = RegExp(
      r'''<source[^>]+src=["']([^"']+\.(?:webm|mp4)[^"']*)["']''',
      caseSensitive: false,
    )
        .allMatches(html)
        .map((match) => _absolute(match.group(1) ?? ''))
        .where((url) => url.isNotEmpty)
        .toList();

    // Prefer MP4 first for smooth hardware video playback, followed by WebM
    videoSources.sort((left, right) {
      final leftMp4 = left.toLowerCase().split('?').first.endsWith('.mp4');
      final rightMp4 = right.toLowerCase().split('?').first.endsWith('.mp4');
      if (leftMp4 != rightMp4) return leftMp4 ? -1 : 1;
      return 0;
    });

    final imageUrl = _absolute(_attribute(imageTag ?? '', 'src'));
    final isVideo = videoSources.isNotEmpty ||
        (originalUrl.isNotEmpty && _fileType(originalUrl) == 'video');

    final mediaUrl = videoSources.isNotEmpty
        ? videoSources.first
        : originalUrl.isNotEmpty
            ? originalUrl
            : imageUrl;
    final sampleUrl = videoSources.length > 1 ? videoSources[1] : mediaUrl;

    // For video posts, derive the poster thumbnail image (.jpg) so the UI doesn't break
    final previewUrl = isVideo
        ? (imageUrl.isNotEmpty ? imageUrl : _thumbnailFromMediaUrl(mediaUrl))
        : (imageUrl.isEmpty ? mediaUrl : imageUrl);

    final source = _attribute(
      RegExp(r'''<input[^>]+id=["']source["'][^>]*>''', caseSensitive: false)
              .firstMatch(html)
              ?.group(0) ??
          '',
      'value',
    );

    // Parse score
    final scoreMatch = RegExp(
      r'''Current Score:\s*<b>\s*<span[^>]*>([+-]?\d+)</span>''',
      caseSensitive: false,
    ).firstMatch(html);
    final score = scoreMatch != null
        ? int.tryParse(scoreMatch.group(1) ?? '0') ?? 0
        : 0;

    // Parse Date and Author
    final metaMatch = RegExp(
      r'''Posted at\s*([^<]+?)\s*by\s*<a[^>]*>([^<]+)''',
      caseSensitive: false,
    ).firstMatch(html);
    final rawDate = metaMatch?.group(1)?.trim();
    final author = metaMatch?.group(2)?.trim() ?? '';
    final createdAt = _parseRealbooruDate(rawDate);

    // Parse categorized tags from <div id="tagLink">
    final tagLinkMatches = RegExp(
      r'''<a\s+class=["']([^"']+)["']\s+href=["'][^"']*tags=([^"'&]+)[^"']*["']>([^<]+)</a>''',
      caseSensitive: false,
    ).allMatches(html);

    final tagGroups = <String, List<String>>{
      'artist': [],
      'character': [],
      'copyright': [],
      'metadata': [],
      'general': [],
    };
    final allTags = <String>{};

    for (final match in tagLinkMatches) {
      final cls = (match.group(1) ?? '').toLowerCase();
      final tag = _decode(match.group(2) ?? '').trim().replaceAll(' ', '_');
      if (tag.isEmpty) continue;
      allTags.add(tag);

      if (cls.contains('model') || cls.contains('artist')) {
        tagGroups['artist']!.add(tag);
      } else if (cls.contains('character')) {
        tagGroups['character']!.add(tag);
      } else if (cls.contains('copyright')) {
        tagGroups['copyright']!.add(tag);
      } else if (cls.contains('metadata')) {
        tagGroups['metadata']!.add(tag);
      } else {
        tagGroups['general']!.add(tag);
      }
    }

    // Fallback tags from alt or textarea if tagLink had none
    if (allTags.isEmpty) {
      final tagsText = _attribute(imageTag ?? '', 'alt').isNotEmpty
          ? _attribute(imageTag ?? '', 'alt')
          : RegExp(
                r'''<textarea[^>]+id=["']tags["'][^>]*>([\s\S]*?)</textarea>''',
                caseSensitive: false,
              ).firstMatch(html)?.group(1) ??
              '';
      allTags.addAll(_tags(tagsText));
      tagGroups['general'] = allTags.toList();
    }

    // Attach author to artist group if present and not anonymous
    if (author.isNotEmpty &&
        !author.toLowerCase().contains('anonymous') &&
        !author.toLowerCase().contains('none')) {
      final normalizedAuthor = author.replaceAll(' ', '_');
      if (!tagGroups['artist']!.contains(normalizedAuthor)) {
        tagGroups['artist']!.insert(0, normalizedAuthor);
      }
    }

    tagGroups.removeWhere((_, list) => list.isEmpty);

    if (mediaUrl.isEmpty) return null;
    return Post(
      id: postId,
      providerId: id,
      providerName: name,
      previewUrl: previewUrl,
      sampleUrl: sampleUrl,
      fileUrl: mediaUrl,
      tags: allTags.toList(growable: false),
      rating: 'explicit',
      width: 0,
      height: 0,
      source: source.isEmpty ? postPageUrlById(postId) : source,
      createdAt: createdAt,
      fileType: _fileType(mediaUrl),
      score: score,
      tagGroups: tagGroups,
    );
  }

  String postPageUrlById(String postId) =>
      '$baseUrl/index.php?page=post&s=view&id=$postId';

  String _attribute(String source, String name) {
    final match = RegExp(
      '''$name\\s*=\\s*["']([^"']*)["']''',
      caseSensitive: false,
    ).firstMatch(source);
    return _decode(match?.group(1) ?? '');
  }

  List<String> _tags(String value) {
    return _decode(value)
        .replaceAll(',', ' ')
        .split(RegExp(r'\s+'))
        .map((tag) => tag.trim().replaceAll(' ', '_'))
        .where((tag) => tag.isNotEmpty)
        .toSet()
        .toList(growable: false);
  }

  Map<String, List<String>> _tagGroups(List<String> tags) =>
      tags.isEmpty ? const {} : {'general': tags};

  String _fileType(String url) {
    final lower = url.toLowerCase().split('?').first;
    if (lower.endsWith('.webm') || lower.endsWith('.mp4')) return 'video';
    if (lower.endsWith('.gif')) return 'gif';
    return 'image';
  }

  String _absolute(String url) {
    final value = _decode(url.trim());
    if (value.startsWith('//')) return _normalizeUrl('https:$value');
    if (value.startsWith('/')) return _normalizeUrl('$baseUrl$value');
    return _normalizeUrl(value);
  }

  String _normalizeUrl(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) return url;
    final normalizedPath = uri.path.replaceFirst(RegExp(r'^/+'), '/');
    return uri.replace(path: normalizedPath).toString();
  }

  String _imageUrlFromThumbnail(
    String thumbnailUrl, {
    bool gif = false,
    bool video = false,
  }) {
    final uri = Uri.tryParse(thumbnailUrl);
    if (uri == null) return '';
    final match = RegExp(r'/+thumbnails/([^/]+)/([^/]+)/thumbnail_([^/.]+)\.')
        .firstMatch(uri.path);
    if (match == null) return '';
    final extension = video ? 'mp4' : (gif ? 'gif' : 'jpeg');
    final path =
        '/images/${match.group(1)}/${match.group(2)}/${match.group(3)}.$extension';
    return uri.replace(path: path, query: null).toString();
  }

  String _thumbnailFromMediaUrl(String mediaUrl) {
    final uri = Uri.tryParse(mediaUrl);
    if (uri == null) return mediaUrl;
    final match = RegExp(r'/+images/([^/]+)/([^/]+)/([^/.]+)\.')
        .firstMatch(uri.path);
    if (match == null) return mediaUrl;
    final path =
        '/thumbnails/${match.group(1)}/${match.group(2)}/thumbnail_${match.group(3)}.jpg';
    return uri.replace(path: path, query: null).toString();
  }

  DateTime _parseRealbooruDate(String? raw) {
    if (raw == null || raw.trim().isEmpty) return DateTime.now();
    final clean = raw.trim().replaceAll(',', '');
    final parts = clean.split(RegExp(r'\s+'));
    if (parts.length >= 3) {
      const months = {
        'jan': 1, 'feb': 2, 'mar': 3, 'apr': 4,
        'may': 5, 'jun': 6, 'jul': 7, 'aug': 8,
        'sep': 9, 'oct': 10, 'nov': 11, 'dec': 12,
      };
      final monthStr = parts[0].toLowerCase();
      final month =
          months[monthStr.length >= 3 ? monthStr.substring(0, 3) : monthStr] ??
              1;
      final day = int.tryParse(parts[1]) ?? 1;
      final year = int.tryParse(parts[2]) ?? DateTime.now().year;
      return DateTime(year, month, day);
    }
    return DateTime.tryParse(clean) ?? DateTime.now();
  }

  String _stripTags(String html) =>
      html.replaceAll(RegExp(r'<[^>]+>'), '');

  String _cleanCommentBody(String raw) {
    var text = raw.replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n');
    text = text.replaceAll(RegExp(r'<[^>]+>'), '');
    return _decode(text).trim();
  }

  List<PostComment> _parseComments(String postId, String html) {
    final comments = <PostComment>[];
    final commentBlockPattern = RegExp(
      r'''<div[^>]*class=["'][^"']*\buserComment\b[^"']*["'][^>]*id=["']c(\d+)["'][^>]*>([\s\S]*?)(?=<div[^>]*class=["'][^"']*\buserComment\b|<div[^>]*id=["']paginator|</body>|$)''',
      caseSensitive: false,
    );

    for (final match in commentBlockPattern.allMatches(html)) {
      final commentId = match.group(1) ?? '';
      final block = match.group(2) ?? '';

      final authorMatch = RegExp(
        r'''<a[^>]*uname=([^"&]+)[^>]*>([\s\S]*?)</a>''',
        caseSensitive: false,
      ).firstMatch(block);
      String authorName = '';
      if (authorMatch != null) {
        authorName =
            _stripTags(_decode(authorMatch.group(2) ?? authorMatch.group(1) ?? ''))
                .trim();
      } else {
        final anonMatch = RegExp(
          r'''<div[^>]*font-style:\s*italic[^>]*>([\s\S]*?)<span''',
          caseSensitive: false,
        ).firstMatch(block);
        if (anonMatch != null) {
          authorName = _stripTags(_decode(anonMatch.group(1) ?? '')).trim();
        }
      }
      if (authorName.isEmpty) authorName = 'Anonymous';

      final dateMatch = RegExp(
        r'''Posted on\s+(\d{4}-\d{2}-\d{2}\s+\d{2}:\d{2}:\d{2})''',
        caseSensitive: false,
      ).firstMatch(block);
      DateTime createdAt = DateTime.now();
      if (dateMatch != null) {
        createdAt =
            DateTime.tryParse(dateMatch.group(1)!.replaceAll(' ', 'T')) ??
                DateTime.now();
      }

      final bodyMatch = RegExp(
        r'''<div[^>]*font-size:\s*\.?8em[^>]*>([\s\S]*?)</div>''',
        caseSensitive: false,
      ).firstMatch(block);
      String body = '';
      if (bodyMatch != null) {
        body = _cleanCommentBody(bodyMatch.group(1) ?? '');
      }

      if (commentId.isNotEmpty && body.isNotEmpty) {
        comments.add(
          PostComment(
            id: commentId,
            postId: postId,
            providerId: id,
            authorName: authorName,
            body: body,
            createdAt: createdAt,
          ),
        );
      }
    }
    return comments;
  }

  String _decode(String value) {
    var result = value
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#039;', "'")
        .replaceAll('&apos;', "'")
        .replaceAll('&nbsp;', ' ');

    result = result.replaceAllMapped(RegExp(r'&#(\d+);'), (match) {
      final code = int.tryParse(match.group(1) ?? '');
      if (code != null && code > 0 && code <= 0x10FFFF) {
        return String.fromCharCode(code);
      }
      return match.group(0)!;
    });

    result = result.replaceAllMapped(RegExp(r'&#x([0-9a-fA-F]+);'), (match) {
      final code = int.tryParse(match.group(1) ?? '', radix: 16);
      if (code != null && code > 0 && code <= 0x10FFFF) {
        return String.fromCharCode(code);
      }
      return match.group(0)!;
    });

    const namedEntities = {
      '&ccedil;': 'ç',
      '&Ccedil;': 'Ç',
      '&atilde;': 'ã',
      '&Atilde;': 'Ã',
      '&eacute;': 'é',
      '&Eacute;': 'É',
      '&aacute;': 'á',
      '&Aacute;': 'Á',
      '&iacute;': 'í',
      '&Iacute;': 'Í',
      '&oacute;': 'ó',
      '&Oacute;': 'Ó',
      '&uacute;': 'ú',
      '&Uacute;': 'Ú',
      '&ntilde;': 'ñ',
      '&Ntilde;': 'Ñ',
      '&uuml;': 'ü',
      '&Uuml;': 'Ü',
    };
    namedEntities.forEach((k, v) {
      result = result.replaceAll(k, v);
    });

    return result;
  }

  List<TagSuggestion> _parseAutocomplete(dynamic data) {
    final source = data is String ? jsonDecode(data) : data;
    if (source is! List) return const [];
    final suggestions = <TagSuggestion>[];
    final countRegExp = RegExp(r'\((\d+)\)');

    for (final item in source) {
      if (item is Map) {
        final val =
            (item['value'] ?? '').toString().trim().replaceAll(' ', '_');
        if (val.isEmpty) continue;
        final label = (item['label'] ?? '').toString();
        final countMatch = countRegExp.firstMatch(label);
        final postCount = countMatch != null
            ? int.tryParse(countMatch.group(1) ?? '0') ?? 0
            : 0;
        suggestions.add(
          TagSuggestion(
            name: val,
            category: TagCategory.general,
            postCount: postCount,
            providerId: id,
          ),
        );
      }
    }
    return suggestions;
  }

  List<String> _autocompleteItems(dynamic data) {
    final source = data is String ? jsonDecode(data) : data;
    if (source is List) {
      return source
          .map((item) => item.toString().trim().replaceAll(' ', '_'))
          .where((item) => item.isNotEmpty)
          .toSet()
          .toList(growable: false);
    }
    return const [];
  }
}
