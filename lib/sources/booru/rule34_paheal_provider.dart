import 'dart:isolate';

import 'package:dio/dio.dart';

import 'package:gel_rule_app/core/http/dio_client.dart';
import 'package:gel_rule_app/core/models/post.dart';
import 'package:gel_rule_app/core/models/provider_health.dart';
import 'package:gel_rule_app/core/models/top_period_filter.dart';
import 'package:gel_rule_app/sources/interfaces/content_provider.dart';

class Rule34PahealProvider implements ContentProvider, PostPageProvider {
  Rule34PahealProvider({
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
    // Paheal's public HTML list ignores common sort/top query parameters and
    // exposes no stable top-period endpoint, so non-latest filters fall back
    // to the regular list instead of pretending to support ranking.
    final query = tags
        .where((tag) => tag.trim().isNotEmpty && tag.trim() != 'all')
        .map((tag) => tag.trim().replaceAll(' ', '_'))
        .join('_');
    final path = query.isEmpty
        ? '/post/list/${page + 1}'
        : '/post/list/$query/${page + 1}';
    final response = await _dio.get<String>(
      path,
      options: Options(responseType: ResponseType.plain),
      cancelToken: cancelToken,
    );
    final html = response.data ?? '';
    // Snapshot sendable locals — the parse closure must not capture `this`.
    final providerId = id;
    final providerName = name;
    final base = baseUrl;
    return (await Isolate.run(() => parseListHtml(
                html,
                providerId: providerId,
                providerName: providerName,
                baseUrl: base,
              )))
        .take(limit)
        .toList(growable: false);
  }

  @override
  Future<Post?> getPost(String id) async {
    final response = await _dio.get<String>(
      '/post/view/$id',
      options: Options(responseType: ResponseType.plain),
    );
    final html = response.data ?? '';
    final providerId = id;
    final providerName = name;
    final base = baseUrl;
    return await Isolate.run(() => parseSingleHtml(
          id,
          html,
          providerId: providerId,
          providerName: providerName,
          baseUrl: base,
        ));
  }

  @override
  Future<ProviderHealth> checkHealth() async {
    final sw = Stopwatch()..start();
    try {
      final response = await _dio.get<String>(
        '/post/list/1',
        options: Options(
          responseType: ResponseType.plain,
          receiveTimeout: const Duration(seconds: 6),
          sendTimeout: const Duration(seconds: 5),
        ),
      );
      sw.stop();
      final isOk = (response.statusCode ?? 500) < 400 &&
          (response.data?.contains('shm-thumb') ?? false);
      return ProviderHealth(
        providerId: id,
        status: isOk ? ProviderStatus.online : ProviderStatus.offline,
        pingMs: isOk ? sw.elapsedMilliseconds : 0,
        lastCheckedAt: DateTime.now(),
        apiVersion: 'paheal-html',
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
        apiVersion: 'paheal-html',
      );
    }
  }

  @override
  String postPageUrl(Post post) => '$baseUrl/post/view/${post.id}';

  static List<Post> parseListHtml(
    String html, {
    required String providerId,
    required String providerName,
    required String baseUrl,
  }) {
    final posts = <Post>[];
    final pattern = RegExp(
      r'''<div[^>]+class=['"][^'"]*\bshm-thumb\b[^'"]*['"][\s\S]*?</div>''',
      caseSensitive: false,
    );
    for (final match in pattern.allMatches(html)) {
      final block = match.group(0) ?? '';
      final postId = _attribute(block, 'data-post-id');
      final fileUrl = _absolute(
        RegExp(
              r'''<a[^>]+href=['"]([^'"]+)['"][^>]*>\s*File Only\s*</a>''',
              caseSensitive: false,
            ).firstMatch(block)?.group(1) ??
            '',
        baseUrl,
      );
      final previewUrl = _absolute(
        RegExp(r'''<img[^>]+src=['"]([^'"]+)['"]''', caseSensitive: false)
                .firstMatch(block)
                ?.group(1) ??
            '',
        baseUrl,
      );
      if (postId.isEmpty || (fileUrl.isEmpty && previewUrl.isEmpty)) continue;
      final tags = _tags(_attribute(block, 'data-tags'));
      final ext = _attribute(block, 'data-ext');
      final dimensions = _dimensions(_attribute(block, 'title'));
      final mediaUrl = fileUrl.isEmpty ? previewUrl : fileUrl;
      posts.add(
        Post(
          id: postId,
          providerId: providerId,
          providerName: providerName,
          previewUrl: previewUrl.isEmpty ? mediaUrl : previewUrl,
          sampleUrl: mediaUrl,
          fileUrl: mediaUrl,
          tags: tags,
          rating: 'explicit',
          width: dimensions.$1,
          height: dimensions.$2,
          source: '$baseUrl/post/view/$postId',
          createdAt: DateTime.now(),
          fileType: _fileType('$ext $mediaUrl'),
          score: 0,
          tagGroups: tags.isEmpty ? const {} : {'general': tags},
        ),
      );
    }
    if (posts.isNotEmpty) return posts;
    final singleId = RegExp(r'''/post/view/(\d+)''').firstMatch(html)?.group(1);
    final single = singleId == null
        ? null
        : parseSingleHtml(singleId, html,
            providerId: providerId,
            providerName: providerName,
            baseUrl: baseUrl);
    return single == null ? const [] : [single];
  }

  static Post? parseSingleHtml(
    String postId,
    String html, {
    required String providerId,
    required String providerName,
    required String baseUrl,
  }) {
    final fileUrl = _absolute(
      RegExp(
            r'''<a[^>]+href=['"]([^'"]+)['"][^>]*>\s*(?:File|Image) Only\s*</a>''',
            caseSensitive: false,
          ).firstMatch(html)?.group(1) ??
          RegExp(
            r'''<(?:img|video|source)[^>]+src=['"]([^'"]+(?:jpg|jpeg|png|gif|webm|mp4)[^'"]*)['"]''',
            caseSensitive: false,
          ).firstMatch(html)?.group(1) ??
          '',
      baseUrl,
    );
    final previewUrl = _absolute(
      RegExp(
            r'''<meta[^>]+property=['"]og:image['"][^>]+content=['"]([^'"]+)['"]''',
            caseSensitive: false,
          ).firstMatch(html)?.group(1) ??
          '',
      baseUrl,
    );
    final tagsText = RegExp(
          r'''<meta[^>]+name=['"]keywords['"][^>]+content=['"]([^'"]+)['"]''',
          caseSensitive: false,
        ).firstMatch(html)?.group(1) ??
        '';
    final mediaUrl = fileUrl.isEmpty ? previewUrl : fileUrl;
    if (mediaUrl.isEmpty) return null;
    final tags = _tags(tagsText);
    return Post(
      id: postId,
      providerId: providerId,
      providerName: providerName,
      previewUrl: previewUrl.isEmpty ? mediaUrl : previewUrl,
      sampleUrl: mediaUrl,
      fileUrl: mediaUrl,
      tags: tags,
      rating: 'explicit',
      width: 0,
      height: 0,
      source: '$baseUrl/post/view/$postId',
      createdAt: DateTime.now(),
      fileType: _fileType(mediaUrl),
      score: 0,
      tagGroups: tags.isEmpty ? const {} : {'general': tags},
    );
  }

  static String _attribute(String source, String name) {
    return _decode(
      RegExp(
            '''$name\\s*=\\s*['"]([^'"]*)['"]''',
            caseSensitive: false,
          ).firstMatch(source)?.group(1) ??
          '',
    );
  }

  static (int, int) _dimensions(String value) {
    final match = RegExp(r'(\d+)x(\d+)').firstMatch(value);
    return (
      int.tryParse(match?.group(1) ?? '') ?? 0,
      int.tryParse(match?.group(2) ?? '') ?? 0,
    );
  }

  static List<String> _tags(String value) {
    return _decode(value)
        .replaceAll(',', ' ')
        .split(RegExp(r'\s+'))
        .map((tag) => tag.trim().replaceAll(' ', '_').toLowerCase())
        .where((tag) => tag.isNotEmpty)
        .toSet()
        .toList(growable: false);
  }

  static String _fileType(String value) {
    final lower = value.toLowerCase().split('?').first;
    if (lower.contains('webm') || lower.contains('mp4')) return 'video';
    if (lower.contains('gif')) return 'gif';
    if (lower.contains('png')) return 'png';
    return 'image';
  }

  static String _absolute(String url, String baseUrl) {
    final value = _decode(url.trim());
    if (value.isEmpty) return '';
    if (value.startsWith('//')) return 'https:$value';
    if (value.startsWith('/')) return '$baseUrl$value';
    return value;
  }

  static String _decode(String value) {
    return value
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#039;', "'")
        .replaceAll('&apos;', "'");
  }
}
