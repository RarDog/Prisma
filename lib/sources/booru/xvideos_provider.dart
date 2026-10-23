import 'dart:async';

import 'package:dio/dio.dart';
import 'package:gel_rule_app/core/http/app_headers.dart';
import 'package:gel_rule_app/core/http/dio_client.dart';
import 'package:gel_rule_app/core/models/post.dart';
import 'package:gel_rule_app/core/models/provider_health.dart';
import 'package:gel_rule_app/core/models/top_period_filter.dart';
import 'package:gel_rule_app/sources/interfaces/content_provider.dart';

/// Scraper for XVideos (xvideos.com) HTML web interface.
/// Extracts video feeds, direct MP4 streams (high/low quality), HLS playlists,
/// metadata (title, duration, uploader, tags, views), and supports direct playback
/// and downloads through the app's native video player.
class XVideosProvider
    implements ContentProvider, PostPageProvider, MediaHeadersProvider {
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

  static final _blockPattern = RegExp(
    r'<div[^>]+id="video_([a-zA-Z0-9]+)"[^>]*data-id="(\d+)".*?(?=<div[^>]+id="video_|<div[^>]+class="pagination"|<div[^>]+id="content-under-media"|$)',
    dotAll: true,
  );

  static final _titlePattern =
      RegExp(r'<p class="title"><a[^>]+title="([^"]+)"');
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
      RegExp(r"html5player\.setVideoTitle\('([^']+)'\)");
  static final _jsHighPattern =
      RegExp(r"html5player\.setVideoUrlHigh\('([^']+)'\)");
  static final _jsLowPattern =
      RegExp(r"html5player\.setVideoUrlLow\('([^']+)'\)");
  static final _jsHlsPattern =
      RegExp(r"html5player\.setVideoHLS\('([^']+)'\)");
  static final _jsThumb169Pattern =
      RegExp(r"html5player\.setThumbUrl169\('([^']+)'\)");
  static final _jsThumbPattern =
      RegExp(r"html5player\.setThumbUrl\('([^']+)'\)");
  static final _tagPattern =
      RegExp(r'<a href="/tags/([^"]+)"[^>]*>([^<]+)</a>');
  static final _detailUploaderPattern = RegExp(
    r'class="btn btn-default label main uploader-tag[^>]*>.*?<span class="name">([^<]+)</span>',
    dotAll: true,
  );

  Options get _htmlOptions => Options(
        responseType: ResponseType.plain,
        headers: {
          'User-Agent': AppHeaders.desktopChromeUserAgent,
          'Referer': '$baseUrl/',
        },
      );

  @override
  Future<List<Post>> searchPosts({
    required List<String> tags,
    required int page,
    int limit = 50,
    String? rating,
    TopPeriodFilter topPeriod = TopPeriodFilter.none,
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
    );

    final html = response.data ?? '';
    return parseVideoList(html);
  }

  List<Post> parseVideoList(String html) {
    final posts = <Post>[];
    final matches = _blockPattern.allMatches(html);

    for (final match in matches) {
      final block = match.group(0)!;
      final eid = match.group(1)!;
      final numericId = match.group(2)!;

      final titleMatch = _titlePattern.firstMatch(block);
      final rawTitle = titleMatch?.group(1) ?? '';
      final title = _unescapeHtml(rawTitle);

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

      final postTags = <String>[
        if (uploader.isNotEmpty) uploader,
        if (durText.isNotEmpty) durText,
      ];

      final tagGroups = <String, List<String>>{
        if (title.isNotEmpty) 'title': [title],
        if (uploader.isNotEmpty) 'artist': [uploader],
        if (durText.isNotEmpty) 'duration_text': [durText],
        if (durationSeconds > 0) 'duration': [durationSeconds.toString()],
        if (viewsText.isNotEmpty) 'views': [viewsText],
        'numeric_id': [numericId],
      };

      posts.add(Post(
        id: eid,
        providerId: id,
        providerName: name,
        previewUrl: thumbUrl,
        sampleUrl: thumbUrl,
        fileUrl: thumbUrl,
        tags: postTags,
        rating: 'e',
        width: 1280,
        height: 720,
        source: '$baseUrl/video.$eid/_',
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
      final response = await _dio.get<String>(
        '/video.$id/_',
        options: _htmlOptions.copyWith(
          followRedirects: true,
          validateStatus: (status) => status != null && status < 400,
        ),
      );

      final html = response.data ?? '';
      if (html.isEmpty) return null;

      return parsePostDetail(id, html);
    } catch (_) {
      return null;
    }
  }

  Post? parsePostDetail(String postId, String html) {
    final titleMatch = _jsTitlePattern.firstMatch(html);
    final title = _unescapeHtml(titleMatch?.group(1) ?? '');

    final high = _jsHighPattern.firstMatch(html)?.group(1);
    final low = _jsLowPattern.firstMatch(html)?.group(1);
    final hls = _jsHlsPattern.firstMatch(html)?.group(1);

    final videoUrl = high ?? low ?? hls;
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
