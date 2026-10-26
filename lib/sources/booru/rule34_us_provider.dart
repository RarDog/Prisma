import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:prisma_app/core/http/app_headers.dart';
import 'package:prisma_app/core/http/dio_client.dart';
import 'package:prisma_app/core/models/post.dart';
import 'package:prisma_app/core/models/provider_health.dart';
import 'package:prisma_app/core/models/tag_suggestion.dart';
import 'package:prisma_app/core/models/top_period_filter.dart';
import 'package:prisma_app/sources/interfaces/content_provider.dart';

class Rule34UsProvider
    implements
        ContentProvider,
        PostPageProvider,
        MediaHeadersProvider,
        TagSuggestionProvider,
        TagMetadataProvider {
  Rule34UsProvider({
    required this.id,
    required this.name,
    required this.baseUrl,
    required DioClient dioClient,
    Map<String, String> queryParameters = const {},
  })  : _dio = dioClient.dio,
        _queryParameters = queryParameters;

  @override
  final String id;
  @override
  final String name;
  @override
  final String baseUrl;
  final Dio _dio;
  final Map<String, String> _queryParameters;

  @override
  String postPageUrl(Post post) =>
      '$baseUrl/index.php?r=posts/view&id=${post.id}';

  @override
  Map<String, String> mediaHeaders(Post post) => AppHeaders.mediaHeaders(
        referer: '$baseUrl/',
      );

  @override
  Set<TopPeriodFilter> get supportedTopPeriods => const {
        TopPeriodFilter.none,
        TopPeriodFilter.allTime,
      };

  @override
  Future<List<Post>> searchPosts({
    required List<String> tags,
    required int page,
    int limit = 50,
    String? rating,
    TopPeriodFilter topPeriod = TopPeriodFilter.none,
    CancelToken? cancelToken,
  }) async {
    final topTags = switch (topPeriod) {
      TopPeriodFilter.none => const <String>[],
      _ => const ['sort:score:desc'],
    };

    final effectiveTags = [
      ...tags,
      if (rating != null && rating.isNotEmpty && rating.toLowerCase() != 'all')
        'rating:$rating',
      if (topTags.isNotEmpty &&
          !tags.any((t) => t.startsWith('sort:') || t.startsWith('order:')))
        ...topTags,
    ].where((t) => t.isNotEmpty).join(' ');

    try {
      final response = await _dio.get<String>(
        '/index.php',
        queryParameters: {
          'r': 'posts/index',
          'page': page,
          if (effectiveTags.trim().isNotEmpty) 'q': effectiveTags.trim(),
          ..._queryParameters,
        },
        options: Options(responseType: ResponseType.plain),
        cancelToken: cancelToken,
      );

      final html = response.data ?? '';
      return _parseList(html).take(limit).toList(growable: false);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return const [];
      rethrow;
    }
  }

  @override
  Future<Post?> getPost(String id) async {
    try {
      final response = await _dio.get<String>(
        '/index.php',
        queryParameters: {
          'r': 'posts/view',
          'id': id,
          ..._queryParameters,
        },
        options: Options(responseType: ResponseType.plain),
      );

      return _parseDetails(id, response.data ?? '');
    } catch (_) {
      return null;
    }
  }

  @override
  Future<List<TagSuggestion>> suggestTags(
    String query, {
    int limit = 20,
  }) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return const [];

    try {
      final response = await _dio.get<dynamic>(
        '/index.php',
        queryParameters: {
          'r': 'autocomplete',
          'term': trimmed,
          ..._queryParameters,
        },
      );

      final data = response.data;
      if (data is! List) return const [];

      final suggestions = <TagSuggestion>[];
      for (final item in data) {
        if (item is! Map) continue;
        final json = Map<String, dynamic>.from(item);
        final name = (json['name'] ?? '').toString().trim();
        if (name.isEmpty) continue;

        final rawCount = json['post_count'] ?? json['count'];
        final count = int.tryParse(rawCount?.toString() ?? '') ?? 0;
        final categoryStr = (json['category'] ?? '').toString().toLowerCase();

        final category = switch (categoryStr) {
          'character' => TagCategory.character,
          'copyright' => TagCategory.copyright,
          'artist' => TagCategory.artist,
          'meta' || 'metadata' => TagCategory.meta,
          _ => TagCategory.general,
        };

        suggestions.add(
          TagSuggestion(
            name: name,
            category: category,
            postCount: count,
            providerId: id,
          ),
        );

        if (suggestions.length >= limit) break;
      }
      return suggestions;
    } catch (_) {
      return const [];
    }
  }

  @override
  Future<Map<String, List<String>>> categorizeTags(List<String> tags) async {
    return {'general': tags};
  }

  @override
  Future<ProviderHealth> checkHealth() async {
    final sw = Stopwatch()..start();
    try {
      final response = await _dio.get<String>(
        '/index.php',
        queryParameters: {'r': 'posts/index', 'page': 0},
        options: Options(
          responseType: ResponseType.plain,
          receiveTimeout: const Duration(seconds: 6),
          sendTimeout: const Duration(seconds: 5),
        ),
      );
      sw.stop();
      final isOk = (response.statusCode ?? 500) < 400 &&
          (response.data?.contains('thumbail-container') ?? false);
      return ProviderHealth(
        providerId: id,
        status: isOk ? ProviderStatus.online : ProviderStatus.offline,
        pingMs: isOk ? sw.elapsedMilliseconds : 0,
        lastCheckedAt: DateTime.now(),
        apiVersion: 'rule34us-html',
        errorMessage: isOk ? null : 'No posts found in HTML response',
      );
    } catch (error) {
      sw.stop();
      return ProviderHealth(
        providerId: id,
        status: ProviderStatus.offline,
        pingMs: 0,
        lastCheckedAt: DateTime.now(),
        errorMessage: error.toString(),
      );
    }
  }

  @visibleForTesting
  List<Post> parseList(String html) => _parseList(html);

  @visibleForTesting
  Post? parseDetails(String postId, String html) => _parseDetails(postId, html);

  List<Post> _parseList(String html) {
    final posts = <Post>[];

    // Pattern matching post card container in rule34.us
    // <div style="... [border: 3px solid #0000ff;]"><a id="123" href="..."><img src="..." title="..." alt="..."></a></div>
    final pattern = RegExp(
      r'''<div\b([^>]*)>\s*<a\b[^>]*\bid=["']?(\d+)["']?[^>]*href=["']([^"']*id=\d+[^"']*)["'][^>]*>\s*<img\b([^>]*)>''',
      caseSensitive: false,
    );

    for (final match in pattern.allMatches(html)) {
      final divAttr = match.group(1) ?? '';
      final id = match.group(2) ?? '';
      final linkHref = match.group(3) ?? '';
      final imgAttr = match.group(4) ?? '';

      final previewUrl = _absolute(_attribute(imgAttr, 'src'));
      if (previewUrl.isEmpty) continue;

      final title = _attribute(imgAttr, 'title');
      final tags = _tagsFromTitle(title);

      final isVideo = divAttr.contains('#0000ff') ||
          tags.contains('video') ||
          tags.contains('mp4') ||
          tags.contains('webm');
      final isGif = !isVideo && (tags.contains('gif') || tags.contains('animated_gif'));

      final derivedMedia = _deriveMediaUrl(
        previewUrl,
        isVideo: isVideo,
        isGif: isGif,
        tags: tags,
      );

      final postPage = linkHref.startsWith('http')
          ? linkHref
          : '$baseUrl/${linkHref.startsWith('/') ? linkHref.substring(1) : linkHref}';

      posts.add(
        Post(
          id: id,
          providerId: this.id,
          providerName: name,
          previewUrl: previewUrl,
          sampleUrl: isVideo ? previewUrl : derivedMedia,
          fileUrl: derivedMedia,
          tags: tags,
          rating: 'explicit',
          width: 0,
          height: 0,
          source: postPage,
          createdAt: DateTime.now(),
          fileType: isVideo
              ? 'video'
              : isGif
                  ? 'gif'
                  : 'image',
          score: 0,
          tagGroups: {'general': tags},
        ),
      );
    }

    return posts;
  }

  Post? _parseDetails(String postId, String html) {
    // 1. Original link: <a href="https://.../images/xx/xx/hash.ext"><li class="character-tag" ...>Original</li></a>
    final originalUrl = _absolute(
      RegExp(
            r'''<a[^>]+href=["']([^"']+)["'][^>]*>\s*<li[^>]*>\s*Original\s*</li>\s*</a>''',
            caseSensitive: false,
          ).firstMatch(html)?.group(1) ??
          RegExp(
            r'''<a[^>]+href=["']([^"']+)["'][^>]*>\s*Original\s*</a>''',
            caseSensitive: false,
          ).firstMatch(html)?.group(1) ??
          '',
    );

    // 2. Video elements
    final videoSources = RegExp(
      r'''<source[^>]+src=["']([^"']+\.(?:webm|mp4)[^"']*)["']''',
      caseSensitive: false,
    )
        .allMatches(html)
        .map((m) => _absolute(m.group(1) ?? ''))
        .where((u) => u.isNotEmpty)
        .toList();

    // Prefer MP4 first for hardware accelerated playback
    videoSources.sort((a, b) {
      final aMp4 = a.toLowerCase().endsWith('.mp4');
      final bMp4 = b.toLowerCase().endsWith('.mp4');
      if (aMp4 != bMp4) return aMp4 ? -1 : 1;
      return 0;
    });

    final videoTag = RegExp(
      r'''<video\b[^>]*>''',
      caseSensitive: false,
    ).firstMatch(html)?.group(0);

    final videoPoster = _absolute(
      _attribute(videoTag ?? '', 'poster'),
    );

    // 3. Image tag
    final imgTag = RegExp(
      r'''<img\b[^>]+(?:alt=["'][^"']*["'])?[^>]*style=["'][^"']*max-width:\s*100%[^"']*["'][^>]*>''',
      caseSensitive: false,
    ).firstMatch(html)?.group(0);

    final imgSrc = _absolute(_attribute(imgTag ?? '', 'src'));
    final width = int.tryParse(_attribute(imgTag ?? '', 'width')) ??
        int.tryParse(_attribute(videoTag ?? '', 'width')) ??
        0;
    final height = int.tryParse(_attribute(imgTag ?? '', 'height')) ??
        int.tryParse(_attribute(videoTag ?? '', 'height')) ??
        0;

    final isVideo = videoSources.isNotEmpty ||
        (originalUrl.isNotEmpty && _fileType(originalUrl) == 'video');

    final fileUrl = videoSources.isNotEmpty
        ? videoSources.first
        : originalUrl.isNotEmpty
            ? originalUrl
            : imgSrc;

    final previewUrl = videoPoster.isNotEmpty
        ? videoPoster
        : imgSrc.isNotEmpty
            ? imgSrc
            : fileUrl;

    final sampleUrl = isVideo ? previewUrl : fileUrl;

    // 4. Categorized tags from sidebar
    final tagGroups = <String, List<String>>{
      'artist': [],
      'character': [],
      'copyright': [],
      'metadata': [],
      'meta': [],
      'general': [],
      'is_detailed': ['true'],
    };
    final allTags = <String>{};

    final tagPattern = RegExp(
      r'''<li\s+class=["']([^"']+-tag)["'][^>]*>[\s\S]*?<a\b[^>]*href=["'][^"']*(?:[?&]|&amp;)q=([^"'&]+)[^"']*["'][^>]*>([\s\S]*?)</a>''',
      caseSensitive: false,
    );

    for (final match in tagPattern.allMatches(html)) {
      final cls = (match.group(1) ?? '').toLowerCase();
      final rawTag = (match.group(2) ?? '').trim();
      final tag = Uri.decodeQueryComponent(rawTag).replaceAll(' ', '_');
      if (tag.isEmpty) continue;

      allTags.add(tag);

      if (cls.contains('artist')) {
        tagGroups['artist']!.add(tag);
      } else if (cls.contains('character')) {
        tagGroups['character']!.add(tag);
      } else if (cls.contains('copyright')) {
        tagGroups['copyright']!.add(tag);
      } else if (cls.contains('meta')) {
        tagGroups['metadata']!.add(tag);
        tagGroups['meta']!.add(tag);
      } else {
        tagGroups['general']!.add(tag);
      }
    }

    if (allTags.isEmpty && imgTag != null) {
      allTags.addAll(_tagsFromTitle(_attribute(imgTag, 'alt')));
      tagGroups['general']!.addAll(allTags);
    }

    return Post(
      id: postId,
      providerId: id,
      providerName: name,
      previewUrl: previewUrl,
      sampleUrl: sampleUrl,
      fileUrl: fileUrl,
      tags: allTags.toList(growable: false),
      rating: 'explicit',
      width: width,
      height: height,
      source: '$baseUrl/index.php?r=posts/view&id=$postId',
      createdAt: DateTime.now(),
      fileType: isVideo
          ? 'video'
          : fileUrl.toLowerCase().endsWith('.gif')
              ? 'gif'
              : 'image',
      score: 0,
      tagGroups: tagGroups,
    );
  }

  List<String> _tagsFromTitle(String title) {
    if (title.isEmpty) return const [];
    return title
        .split(',')
        .map((t) => t.trim().replaceAll(' ', '_'))
        .where((t) => t.isNotEmpty)
        .toSet()
        .toList(growable: false);
  }

  String _deriveMediaUrl(
    String thumbUrl, {
    required bool isVideo,
    required bool isGif,
    required List<String> tags,
  }) {
    // Format: https://img2.rule34.us/thumbnails/f1/44/thumbnail_f144a96b2677d95b38b8a771c5a908dd.jpg
    final match = RegExp(
      r'thumbnails/([a-f0-9]+)/([a-f0-9]+)/thumbnail_([a-f0-9]+)\.',
      caseSensitive: false,
    ).firstMatch(thumbUrl);

    if (match == null) return thumbUrl;
    final d1 = match.group(1)!;
    final d2 = match.group(2)!;
    final hash = match.group(3)!;

    if (isVideo) {
      return 'https://video.rule34.us/images/$d1/$d2/$hash.mp4';
    }
    if (isGif) {
      return 'https://img2.rule34.us/images/$d1/$d2/$hash.gif';
    }
    if (tags.contains('png')) {
      return 'https://img2.rule34.us/images/$d1/$d2/$hash.png';
    }
    return 'https://img2.rule34.us/images/$d1/$d2/$hash.jpeg';
  }

  String _attribute(String tag, String name) {
    final match = RegExp(
      '''$name\\s*=\\s*["']([^"']*)["']''',
      caseSensitive: false,
    ).firstMatch(tag);
    return match?.group(1) ?? '';
  }

  String _absolute(String url) {
    if (url.isEmpty) return '';
    if (url.startsWith('//')) return 'https:$url';
    if (url.startsWith('http://') || url.startsWith('https://')) return url;
    final cleanBase = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;
    final cleanPath = url.startsWith('/') ? url : '/$url';
    return '$cleanBase$cleanPath';
  }

  String _fileType(String url) {
    final lower = url.toLowerCase().split('?').first;
    if (lower.endsWith('.mp4') || lower.endsWith('.webm')) return 'video';
    if (lower.endsWith('.gif')) return 'gif';
    return 'image';
  }
}
