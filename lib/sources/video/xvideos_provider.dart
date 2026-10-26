import 'dart:async';
import 'dart:isolate';

import 'package:dio/dio.dart';
import 'package:prisma_app/core/http/app_headers.dart';
import 'package:prisma_app/core/http/dio_client.dart';
import 'package:prisma_app/core/models/post.dart';
import 'package:prisma_app/core/models/provider_health.dart';
import 'package:prisma_app/core/models/tag_suggestion.dart';
import 'package:prisma_app/core/models/top_period_filter.dart';
import 'package:prisma_app/sources/interfaces/content_provider.dart';

/// Scraper for XVideos (xvideos.com) HTML web interface.
/// Extracts video feeds, direct MP4 streams (high/low quality), HLS playlists,
/// metadata (title, duration, uploader, tags, views), and supports direct playback
/// and downloads through the app's native video player.
class XVideosProvider
    implements
        ContentProvider,
        PostPageProvider,
        MediaHeadersProvider,
        TagSuggestionProvider {
  XVideosProvider({
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
  Set<TopPeriodFilter> get supportedTopPeriods => const {
        TopPeriodFilter.none,
        TopPeriodFilter.allTime,
      };

  static const _popularTags = <String>[
    'amateur', 'anal', 'anime', 'arab', 'asian', 'asmr', 'ass', 'bbw', 'bdsm', 'babe',
    'beauty', 'big ass', 'big cock', 'big tits', 'black', 'blonde', 'blowjob', 'brunette',
    'cam', 'celebrity', 'chubby', 'cleavage', 'close up', 'college', 'cosplay', 'creampie',
    'cuckold', 'cumshot', 'deepthroat', 'double penetration', 'ebony', 'feet', 'femdom',
    'fisting', 'funny', 'gangbang', 'gamer', 'gay', 'german', 'glamour', 'granny', 'group',
    'hardcore', 'hentai', 'homemade', 'hotel', 'housewife', 'indian', 'interracial',
    'japanese', 'korean', 'latex', 'latina', 'lesbian', 'lingerie', 'maid', 'massage',
    'masturbation', 'mature', 'milf', 'model', 'nurse', 'office', 'old and young', 'orgy',
    'outdoor', 'panties', 'pantyhose', 'party', 'petite', 'pissing', 'pornstar', 'pov',
    'pregnant', 'public', 'pussy', 'reality', 'redhead', 'romance', 'rough', 'russian',
    'school', 'seduction', 'shemale', 'shower', 'skinny', 'sleep', 'small tits', 'solo',
    'spanking', 'squirt', 'stockings', 'striptease', 'student', 'swinger', 'tattoo', 'teen',
    'threesome', 'toys', 'uniform', 'vintage', 'voyeur', 'vr', 'webcam', 'wife',
  ];

  static final _blockPattern = RegExp(
    r'<div[^>]+id="video_([a-zA-Z0-9]+)"[^>]*data-id="(\d+)".*?(?=<div[^>]+id="video_|<div[^>]+class="pagination"|<div[^>]+id="content-under-media"|$)',
    dotAll: true,
  );

  static final _titlePattern =
      RegExp(r'<p class="title"><a[^>]+title="([^"]+)"');
  static final _hrefPattern = RegExp(r'<a[^>]+href="(/video[^"]+)"');
  static final _dataSrcPattern = RegExp(r'data-src="([^"]+)"');
  static final _srcPattern = RegExp(r'src="([^"]+)"');
  static final _durationPattern =
      RegExp(r'<span class="duration">([^<]+)</span>');
  static final _uploaderPattern = RegExp(
    r'<p class="metadata">.*?<span class="name">([^<]+)</span>',
    dotAll: true,
  );
  static final _viewsPattern = RegExp(
    r'([0-9.]+[KMB]?)\s*(?:<span class="sprfluous">)?Views',
    caseSensitive: false,
  );

  static final _jsTitlePattern =
      RegExp(r'''setVideoTitle\(['"]([^'"]+)['"]\)''');
  static final _jsHighPattern =
      RegExp(r'''setVideoUrlHigh\(['"]([^'"]+)['"]\)''');
  static final _jsLowPattern =
      RegExp(r'''setVideoUrlLow\(['"]([^'"]+)['"]\)''');
  static final _jsHlsPattern =
      RegExp(r'''setVideoHLS\(['"]([^'"]+)['"]\)''');
  static final _jsThumb169Pattern =
      RegExp(r'''setThumbUrl169\(['"]([^'"]+)['"]\)''');
  static final _jsThumbPattern =
      RegExp(r'''setThumbUrl\(['"]([^'"]+)['"]\)''');
  static final _tagPattern =
      RegExp(r'<a href="/tags/([^"]+)"[^>]*>([^<]+)</a>');
  static final _detailUploaderPattern = RegExp(
    r'class="btn btn-default label main uploader-tag[^>]*>.*?<span class="name">([^<]+)</span>',
    dotAll: true,
  );
  static final _fallbackMp4Pattern =
      RegExp(r'''https?://[^\s"'<>]+\.mp4\?[^\s"'<>]+''');

  Options get _htmlOptions => Options(
        responseType: ResponseType.plain,
        headers: {
          'User-Agent': AppHeaders.desktopChromeUserAgent,
          'Referer': '$baseUrl/',
        },
      );

  @override
  Future<List<TagSuggestion>> suggestTags(String query, {int limit = 20}) async {
    final clean = query.trim().toLowerCase();
    if (clean.isEmpty) {
      return _popularTags.take(limit).map((t) => TagSuggestion(
        name: t,
        category: TagCategory.general,
        postCount: 0,
        providerId: id,
      )).toList();
    }
    final matches = _popularTags.where((t) => t.contains(clean)).toList()
      ..sort((a, b) {
        final aStarts = a.startsWith(clean);
        final bStarts = b.startsWith(clean);
        if (aStarts && !bStarts) return -1;
        if (!aStarts && bStarts) return 1;
        return a.compareTo(b);
      });
    return matches.take(limit).map((t) => TagSuggestion(
      name: t,
      category: TagCategory.general,
      postCount: 0,
      providerId: id,
    )).toList();
  }

  @override
  Future<List<Post>> searchPosts({
    required List<String> tags,
    required int page,
    int limit = 50,
    String? rating,
    TopPeriodFilter topPeriod = TopPeriodFilter.none,
    CancelToken? cancelToken,
  }) async {
    final effectiveTags = tags
        .where((t) =>
            t.trim().isNotEmpty &&
            !t.startsWith('sort:') &&
            !t.startsWith('order:'))
        .join(' ');

    String path;
    final queryParameters = <String, dynamic>{};

    if (effectiveTags.isNotEmpty) {
      path = '/';
      queryParameters['k'] = effectiveTags;
      if (page > 1) {
        queryParameters['p'] = page - 1;
      }
    } else {
      if (page <= 1) {
        path = '/';
      } else {
        path = '/new/$page';
      }
    }

    final response = await _dio.get<String>(
      path,
      queryParameters: queryParameters,
      options: _htmlOptions,
      cancelToken: cancelToken,
    );

    final html = response.data ?? '';
    // Snapshot sendable locals — the parse closure must not capture `this`.
    final providerId = id;
    final providerName = name;
    final base = baseUrl;
    // Parsing 100s of KB of HTML with a dozen regexes janks the UI thread;
    // run it in a short-lived isolate.
    return Isolate.run(() => parseVideoList(
          html,
          providerId: providerId,
          providerName: providerName,
          baseUrl: base,
          queryTags: effectiveTags,
        ));
  }

  static List<Post> parseVideoList(
    String html, {
    required String providerId,
    required String providerName,
    required String baseUrl,
    String queryTags = '',
  }) {
    final posts = <Post>[];
    final matches = _blockPattern.allMatches(html);

    for (final match in matches) {
      final block = match.group(0)!;
      final eid = match.group(1)!;
      final numericId = match.group(2)!;

      final titleMatch = _titlePattern.firstMatch(block);
      final rawTitle = titleMatch?.group(1) ?? '';
      final title = _unescapeHtml(rawTitle);

      final hrefMatch = _hrefPattern.firstMatch(block);
      final relativePath = hrefMatch?.group(1) ?? '/video.$eid/_';

      final thumbMatch =
          _dataSrcPattern.firstMatch(block) ?? _srcPattern.firstMatch(block);
      final thumbUrl = thumbMatch?.group(1) ?? '';

      final durMatch = _durationPattern.firstMatch(block);
      final durText = durMatch?.group(1)?.trim() ?? '';
      final durationSeconds = _parseDuration(durText);

      final uploaderMatch = _uploaderPattern.firstMatch(block);
      final uploader = _unescapeHtml(uploaderMatch?.group(1)?.trim() ?? '');

      final viewsMatch = _viewsPattern.firstMatch(block);
      final viewsText = viewsMatch?.group(1) ?? '';
      final score = _parseViews(viewsText);

      final titleWords = title
          .toLowerCase()
          .split(RegExp(r'[\s,._\-+()\[\]「」]+'))
          .where((w) => w.length > 2)
          .toList();

      final postTags = <String>{
        if (uploader.isNotEmpty) uploader,
        if (durText.isNotEmpty) durText,
        if (queryTags.isNotEmpty)
          ...queryTags.split(RegExp(r'\s+')).where((t) => t.isNotEmpty),
        ...titleWords,
      }.toList();

      final tagGroups = <String, List<String>>{
        if (title.isNotEmpty) 'title': [title],
        if (uploader.isNotEmpty) 'artist': [uploader],
        if (durText.isNotEmpty) 'duration_text': [durText],
        if (durationSeconds > 0) 'duration': [durationSeconds.toString()],
        if (viewsText.isNotEmpty) 'views': [viewsText],
        'numeric_id': [numericId],
        'path': [relativePath],
      };

      posts.add(Post(
        id: eid,
        providerId: providerId,
        providerName: providerName,
        previewUrl: thumbUrl,
        sampleUrl: thumbUrl,
        fileUrl: thumbUrl,
        tags: postTags,
        rating: 'e',
        width: 1280,
        height: 720,
        source: '$baseUrl$relativePath',
        createdAt: DateTime.now(),
        fileType: 'mp4',
        score: score,
        tagGroups: tagGroups,
      ));
    }

    return posts;
  }

  @override
  Future<Post?> getPost(String id) async {
    try {
      final path = id.startsWith('/')
          ? id
          : (id.startsWith('video') ? '/$id' : '/video.$id/_');

      Response<String> response;
      try {
        response = await _dio.get<String>(
          path,
          options: _htmlOptions.copyWith(
            followRedirects: true,
            maxRedirects: 5,
          ),
        );
      } catch (dioError) {
        if (id.contains('.')) {
          final cleanId = id.split('.').last;
          response = await _dio.get<String>(
            '/video.$cleanId/_',
            options: _htmlOptions.copyWith(
              followRedirects: true,
              maxRedirects: 5,
            ),
          );
        } else {
          rethrow;
        }
      }

      if (response.statusCode == 301 || response.statusCode == 302) {
        final loc = response.headers.value('location');
        if (loc != null && loc.isNotEmpty) {
          response = await _dio.get<String>(
            loc,
            options: _htmlOptions.copyWith(followRedirects: true),
          );
        }
      }

      final html = response.data ?? '';
      if (html.isEmpty) return null;

      return parsePostDetail(id, html);
    } catch (_) {
      return null;
    }
  }

  Post? parsePostDetail(String postId, String html) {
    final titleMatch = _jsTitlePattern.firstMatch(html) ??
        RegExp(r'<title>(.*?)(?: - XVIDEOS|\s*-\s*XVIDEOS\.COM)?</title>',
                caseSensitive: false)
            .firstMatch(html);
    final title = _unescapeHtml(titleMatch?.group(1) ?? '');

    final high = _jsHighPattern.firstMatch(html)?.group(1);
    final low = _jsLowPattern.firstMatch(html)?.group(1);
    final hls = _jsHlsPattern.firstMatch(html)?.group(1);

    final fallbackMp4 = _fallbackMp4Pattern.firstMatch(html)?.group(0);
    final videoUrl = high ?? low ?? hls ?? fallbackMp4;
    if (videoUrl == null || videoUrl.isEmpty) return null;

    final thumbMatch =
        _jsThumb169Pattern.firstMatch(html) ?? _jsThumbPattern.firstMatch(html);
    final thumb = thumbMatch?.group(1) ?? '';

    final tagMatches = _tagPattern.allMatches(html);
    final tags = tagMatches
        .map((m) => _unescapeHtml(m.group(2)!.trim()))
        .where((t) => t.isNotEmpty && !t.startsWith('+') && t != 'Edit tags')
        .toSet()
        .toList();

    final uploaderMatch = _detailUploaderPattern.firstMatch(html);
    final uploader = _unescapeHtml(uploaderMatch?.group(1)?.trim() ?? '');

    final tagGroups = <String, List<String>>{
      'general': tags,
      if (title.isNotEmpty) 'title': [title],
      if (uploader.isNotEmpty) 'artist': [uploader],
      'is_detailed': ['true'],
    };

    return Post(
      id: postId,
      providerId: id,
      providerName: name,
      previewUrl: thumb.isNotEmpty ? thumb : videoUrl,
      sampleUrl: videoUrl,
      fileUrl: videoUrl,
      tags: [
        if (uploader.isNotEmpty) uploader,
        ...tags,
      ],
      rating: 'e',
      width: 1280,
      height: 720,
      source: '$baseUrl/video.$postId/_',
      createdAt: DateTime.now(),
      fileType: 'mp4',
      score: 1,
      tagGroups: tagGroups,
    );
  }

  @override
  Map<String, String> mediaHeaders(Post post) => {
        'Referer': '$baseUrl/',
        'User-Agent': AppHeaders.desktopChromeUserAgent,
      };

  @override
  String? postPageUrl(Post post) {
    final s = post.source;
    return (s != null && s.isNotEmpty) ? s : '$baseUrl/video.${post.id}/_';
  }

  @override
  Future<ProviderHealth> checkHealth() async {
    final sw = Stopwatch()..start();
    try {
      final response = await _dio.get<String>(
        '/',
        options: _htmlOptions,
      );
      sw.stop();
      final healthy = (response.statusCode == 200) &&
          (response.data?.contains('thumb-block') ?? false);
      return ProviderHealth(
        providerId: id,
        status: healthy ? ProviderStatus.online : ProviderStatus.offline,
        pingMs: healthy ? sw.elapsedMilliseconds : 0,
        lastCheckedAt: DateTime.now(),
        apiVersion: 'xvideos-web',
        errorMessage: healthy ? null : 'No video blocks found on front page',
      );
    } catch (e) {
      sw.stop();
      return ProviderHealth(
        providerId: id,
        status: ProviderStatus.offline,
        pingMs: 0,
        lastCheckedAt: DateTime.now(),
        apiVersion: 'xvideos-web',
        errorMessage: e.toString(),
      );
    }
  }

  static int _parseDuration(String durationText) {
    final text = durationText.trim().toLowerCase();
    int total = 0;
    final hMatch = RegExp(r'(\d+)\s*h').firstMatch(text);
    if (hMatch != null) {
      total += (int.tryParse(hMatch.group(1)!) ?? 0) * 3600;
    }
    final mMatch = RegExp(r'(\d+)\s*min').firstMatch(text);
    if (mMatch != null) {
      total += (int.tryParse(mMatch.group(1)!) ?? 0) * 60;
    }
    final sMatch = RegExp(r'(\d+)\s*sec').firstMatch(text);
    if (sMatch != null) {
      total += int.tryParse(sMatch.group(1)!) ?? 0;
    }
    return total;
  }

  static int _parseViews(String text) {
    final clean = text.trim().toUpperCase();
    if (clean.isEmpty) return 0;
    double mult = 1.0;
    if (clean.endsWith('K')) {
      mult = 1000.0;
    } else if (clean.endsWith('M')) {
      mult = 1000000.0;
    } else if (clean.endsWith('B')) {
      mult = 1000000000.0;
    }
    final numStr = clean.replaceAll(RegExp(r'[KMB]'), '').trim();
    final val = double.tryParse(numStr) ?? 0.0;
    return (val * mult).round();
  }

  static String _unescapeHtml(String input) {
    if (input.isEmpty) return input;
    return input
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&#039;', "'")
        .replaceAll('&nbsp;', ' ')
        .trim();
  }
}
