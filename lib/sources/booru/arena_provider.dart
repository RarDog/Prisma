import 'dart:async';
import 'package:dio/dio.dart';
import 'package:gel_rule_app/core/errors/app_exception.dart';
import 'package:gel_rule_app/core/http/dio_client.dart';
import 'package:gel_rule_app/core/models/post.dart';
import 'package:gel_rule_app/core/models/provider_health.dart';
import 'package:gel_rule_app/core/models/tag_suggestion.dart';
import 'package:gel_rule_app/core/models/top_period_filter.dart';
import 'package:gel_rule_app/sources/interfaces/content_provider.dart';

class ArenaProvider
    implements
        ContentProvider,
        PostPageProvider,
        MediaHeadersProvider,
        TagSuggestionProvider {
  ArenaProvider({
    required this.id,
    required this.name,
    required this.baseUrl,
    required this.dioClient,
    this.token,
  });

  @override
  final String id;
  @override
  final String name;
  @override
  final String baseUrl;
  final DioClient dioClient;
  final String? token;

  @override
  Set<TopPeriodFilter> get supportedTopPeriods => const {
        TopPeriodFilter.none,
      };

  @override
  String? postPageUrl(Post post) => 'https://www.are.na/block/${post.id}';

  @override
  Map<String, String> mediaHeaders(Post post) => {
        'User-Agent': 'Prisma/4.2.0',
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
    final query = tags.isNotEmpty ? tags.join(' ') : 'moodboard';

    try {
      final searchResp = await dioClient.dio.get<Map<String, dynamic>>(
        '/search',
        queryParameters: {
          'q': query,
          'page': page,
          'per': 8,
        },
        cancelToken: cancelToken,
      );

      final searchData = searchResp.data;
      final channels = searchData?['channels'] as List?;
      if (channels == null || channels.isEmpty) return [];

      final posts = <Post>[];
      final seenBlockIds = <String>{};

      final channelFetches = channels.take(4).map((ch) async {
        if (ch is! Map<String, dynamic>) return <Post>[];
        final chId = ch['id'];
        final chTitle = ch['title']?.toString() ?? '';
        final chSlug = ch['slug']?.toString() ?? '';
        if (chId == null) return <Post>[];

        try {
          final contentResp = await dioClient.dio.get<Map<String, dynamic>>(
            '/channels/$chId/contents',
            queryParameters: {'per': 15},
            cancelToken: cancelToken,
          );
          final contents = contentResp.data?['contents'] as List?;
          if (contents == null) return <Post>[];

          final channelPosts = <Post>[];
          for (final block in contents) {
            if (block is! Map<String, dynamic>) continue;
            final blockClass = block['class']?.toString();
            if (blockClass != 'Image' && blockClass != 'Link') continue;
            final img = block['image'] as Map<String, dynamic>?;
            if (img == null) continue;

            final post = _mapBlockToPost(block,
                channelTitle: chTitle, channelSlug: chSlug);
            if (post != null) {
              channelPosts.add(post);
            }
          }
          return channelPosts;
        } catch (_) {
          return <Post>[];
        }
      });

      final results = await Future.wait(channelFetches);
      for (final list in results) {
        for (final p in list) {
          if (seenBlockIds.add(p.id)) {
            posts.add(p);
          }
        }
      }

      return posts;
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout) {
        throw RequestTimeoutException('Are.na timeout: ${e.message}');
      }
      throw NetworkException('Are.na network error: ${e.message}');
    }
  }

  @override
  Future<Post?> getPost(String id) async {
    try {
      final response =
          await dioClient.dio.get<Map<String, dynamic>>('/blocks/$id');
      final data = response.data;
      if (data == null) return null;
      return _mapBlockToPost(data);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout) {
        throw RequestTimeoutException('Are.na timeout: ${e.message}');
      }
      throw NetworkException('Are.na network error: ${e.message}');
    }
  }

  Post? _mapBlockToPost(
    Map<String, dynamic> block, {
    String? channelTitle,
    String? channelSlug,
  }) {
    final idStr = block['id']?.toString();
    if (idStr == null || idStr.isEmpty) return null;

    final img = block['image'] as Map<String, dynamic>?;
    if (img == null) return null;

    final orig = img['original'] as Map<String, dynamic>?;
    final display = img['display'] as Map<String, dynamic>?;
    final thumb = img['thumb'] as Map<String, dynamic>?;

    final originalUrl = orig?['url'] as String?;
    final displayUrl = display?['url'] as String?;
    final thumbUrl = thumb?['url'] as String?;

    final previewUrl = displayUrl ?? thumbUrl ?? originalUrl;
    final fileUrl = originalUrl ?? displayUrl ?? thumbUrl;
    if (previewUrl == null || fileUrl == null) return null;

    final width = (orig?['width'] as num?)?.toInt() ??
        (display?['width'] as num?)?.toInt() ??
        0;
    final height = (orig?['height'] as num?)?.toInt() ??
        (display?['height'] as num?)?.toInt() ??
        0;

    final tags = <String>['are.na'];
    if (channelTitle != null && channelTitle.isNotEmpty) {
      tags.add(channelTitle.toLowerCase().replaceAll(' ', '_'));
    }
    if (channelSlug != null && channelSlug.isNotEmpty) {
      tags.add(channelSlug.toLowerCase().replaceAll('-', '_'));
    }
    final user = block['user'] as Map<String, dynamic>?;
    final username = user?['username']?.toString();
    if (username != null && username.isNotEmpty) {
      tags.add(username.toLowerCase().replaceAll(' ', '_'));
    }

    DateTime? createdAt;
    final rawDate = block['created_at'] as String?;
    if (rawDate != null) {
      createdAt = DateTime.tryParse(rawDate);
    }

    final title = block['title']?.toString();
    final description = block['description']?.toString();
    final displayTitle = (title != null && title.isNotEmpty)
        ? title
        : (description != null && description.isNotEmpty
            ? description
            : channelTitle);

    final fileType = fileUrl.toLowerCase().endsWith('.gif')
        ? 'gif'
        : (fileUrl.toLowerCase().endsWith('.png') ? 'png' : 'jpg');

    return Post(
      id: idStr,
      providerId: id,
      providerName: name,
      previewUrl: previewUrl,
      sampleUrl: displayUrl ?? previewUrl,
      fileUrl: fileUrl,
      width: width,
      height: height,
      score: (block['comment_count'] as num?)?.toInt() ?? 0,
      rating: 's',
      tags: tags,
      createdAt: createdAt ?? DateTime.now(),
      fileType: fileType,
      source: block['source']?['url'] as String?,
      tagGroups: {
        if (displayTitle != null && displayTitle.isNotEmpty)
          'description': [displayTitle],
      },
    );
  }

  @override
  Future<List<TagSuggestion>> suggestTags(String query,
      {int limit = 20}) async {
    final trimmed = query.trim().toLowerCase();
    if (trimmed.isEmpty) return [];
    const candidates = [
      'moodboard',
      'design',
      'poster',
      'architecture',
      'typography',
      'branding',
      'photography',
      'illustration',
      'art',
      'graphic_design',
      'editorial',
      'layout',
      'minimalism',
      'film',
      'color_palette',
      'fashion',
      'interior',
      'painting',
      'sculpture',
      'zine'
    ];
    return candidates
        .where((t) => t.contains(trimmed))
        .take(limit)
        .map((t) => TagSuggestion(
              name: t,
              category: TagCategory.general,
              postCount: 0,
              providerId: id,
            ))
        .toList();
  }

  @override
  Future<ProviderHealth> checkHealth() async {
    final sw = Stopwatch()..start();
    try {
      final response = await dioClient.dio.get<Map<String, dynamic>>(
        '/search',
        queryParameters: {'q': 'art', 'per': 1},
        options: Options(
          receiveTimeout: const Duration(seconds: 6),
          sendTimeout: const Duration(seconds: 5),
        ),
      );
      sw.stop();
      return ProviderHealth(
        providerId: id,
        status: response.statusCode == 200
            ? ProviderStatus.online
            : ProviderStatus.offline,
        pingMs: response.statusCode == 200 ? sw.elapsedMilliseconds : 0,
        lastCheckedAt: DateTime.now(),
        apiVersion: 'are.na-v2',
        errorMessage:
            response.statusCode == 200 ? null : 'Status ${response.statusCode}',
      );
    } catch (e) {
      sw.stop();
      return ProviderHealth(
        providerId: id,
        status: ProviderStatus.offline,
        pingMs: 0,
        lastCheckedAt: DateTime.now(),
        errorMessage: e.toString(),
      );
    }
  }
}
