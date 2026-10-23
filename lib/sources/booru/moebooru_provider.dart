import 'package:dio/dio.dart';

import 'package:gel_rule_app/core/http/app_headers.dart';
import 'package:gel_rule_app/core/http/dio_client.dart';
import 'package:gel_rule_app/sources/mappers/moebooru_mapper.dart';
import 'package:gel_rule_app/core/models/post.dart';
import 'package:gel_rule_app/core/models/post_comment.dart';
import 'package:gel_rule_app/core/models/provider_health.dart';
import 'package:gel_rule_app/core/models/tag_suggestion.dart';
import 'package:gel_rule_app/core/models/top_period_filter.dart';
import 'package:gel_rule_app/sources/interfaces/content_provider.dart';

class MoebooruProvider
    implements
        ContentProvider,
        TagSuggestionProvider,
        CommentProvider,
        PostPageProvider,
        MediaHeadersProvider {
  MoebooruProvider({
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
  Set<TopPeriodFilter> get supportedTopPeriods => const {
        TopPeriodFilter.none,
        TopPeriodFilter.day,
        TopPeriodFilter.week,
        TopPeriodFilter.month,
        TopPeriodFilter.year,
        TopPeriodFilter.allTime,
      };

  @override
  String postPageUrl(Post post) => '$baseUrl/post/show/${post.id}';

  @override
  Map<String, String> mediaHeaders(Post post) {
    return {
      'User-Agent': AppHeaders.defaultUserAgent,
      'Referer': baseUrl.endsWith('/') ? baseUrl : '$baseUrl/',
    };
  }

  @override
  Future<List<Post>> searchPosts({
    required List<String> tags,
    required int page,
    int limit = 50,
    String? rating,
    TopPeriodFilter topPeriod = TopPeriodFilter.none,
  }) async {
    final hasTags = tags.isNotEmpty || (rating != null && rating.isNotEmpty);

    // If topPeriod is day/week/month/year and no tags are provided, use popular_recent endpoint
    if (!hasTags &&
        topPeriod != TopPeriodFilter.none &&
        topPeriod != TopPeriodFilter.allTime) {
      final periodParam = switch (topPeriod) {
        TopPeriodFilter.day => '1d',
        TopPeriodFilter.week => '1w',
        TopPeriodFilter.month => '1m',
        TopPeriodFilter.year => '1y',
        _ => '1d',
      };
      final response = await _dio.get<dynamic>(
        '/post/popular_recent.json',
        queryParameters: {
          'period': periodParam,
          ..._queryParameters,
        },
      );
      return MoebooruMapper.postsFromResponse(
        response.data,
        providerId: id,
        providerName: name,
      );
    }

    final queryTags = [
      ...tags,
      if (rating != null && rating.isNotEmpty) 'rating:$rating',
      ..._topTags(topPeriod),
    ];
    final response = await _dio.get<dynamic>(
      '/post.json',
      queryParameters: {
        'page': page + 1,
        'limit': limit.clamp(1, 100),
        if (queryTags.isNotEmpty) 'tags': queryTags.join(' '),
        ..._queryParameters,
      },
    );
    return MoebooruMapper.postsFromResponse(
      response.data,
      providerId: id,
      providerName: name,
    );
  }

  @override
  Future<Post?> getPost(String id) async {
    final response = await _dio.get<dynamic>(
      '/post.json',
      queryParameters: {'id': id, 'limit': 1, ..._queryParameters},
    );
    final posts = MoebooruMapper.postsFromResponse(
      response.data,
      providerId: this.id,
      providerName: name,
    );
    return posts.isEmpty ? null : posts.first;
  }

  @override
  Future<ProviderHealth> checkHealth() async {
    final sw = Stopwatch()..start();
    try {
      await _dio.get<dynamic>(
        '/post.json',
        queryParameters: {'limit': 1, ..._queryParameters},
        options: Options(
          receiveTimeout: const Duration(seconds: 6),
          sendTimeout: const Duration(seconds: 5),
        ),
      );
      sw.stop();
      return ProviderHealth(
        providerId: id,
        status: ProviderStatus.online,
        pingMs: sw.elapsedMilliseconds,
        lastCheckedAt: DateTime.now(),
        apiVersion: 'moebooru',
      );
    } catch (error) {
      sw.stop();
      return ProviderHealth(
        providerId: id,
        status: ProviderStatus.offline,
        pingMs: 0,
        lastCheckedAt: DateTime.now(),
        errorMessage: error.toString(),
        apiVersion: 'moebooru',
      );
    }
  }

  @override
  Future<List<TagSuggestion>> suggestTags(String query,
      {int limit = 20}) async {
    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty) return const [];
    final response = await _dio.get<dynamic>(
      '/tag.json',
      queryParameters: {
        'name': '$cleanQuery*',
        'limit': limit.clamp(1, 50),
        'order': 'count',
        ..._queryParameters,
      },
    );
    final items = response.data is List ? response.data as List : const [];
    return items
        .whereType<Map>()
        .map((item) {
          final json = Map<String, dynamic>.from(item);
          return TagSuggestion(
            name: (json['name'] ?? '').toString(),
            category: tagCategoryFromString(
              (json['type'] ?? json['tag_type']).toString(),
            ),
            postCount: _int(json['count'] ?? json['post_count']),
            providerId: id,
          );
        })
        .where((tag) => tag.name.isNotEmpty)
        .toList();
  }

  @override
  Future<List<PostComment>> getComments(String postId) async {
    final response = await _dio.get<dynamic>(
      '/comment.json',
      queryParameters: {
        'post_id': postId,
        'limit': 50,
        ..._queryParameters,
      },
    );
    final items = response.data is List ? response.data as List : const [];
    return items
        .whereType<Map>()
        .map((item) {
          final json = Map<String, dynamic>.from(item);
          return PostComment(
            id: (json['id'] ?? '').toString(),
            postId: (json['post_id'] ?? postId).toString(),
            providerId: id,
            authorName:
                (json['creator'] ?? json['author'] ?? json['user'] ?? 'user')
                    .toString(),
            body: (json['body'] ?? json['comment'] ?? json['text'] ?? '')
                .toString(),
            createdAt: DateTime.tryParse(
                  (json['created_at'] ?? json['created_on'] ?? '').toString(),
                ) ??
                DateTime.fromMillisecondsSinceEpoch(0),
          );
        })
        .where((comment) => comment.body.trim().isNotEmpty)
        .toList();
  }

  List<String> _topTags(TopPeriodFilter period) {
    return switch (period) {
      TopPeriodFilter.allTime ||
      TopPeriodFilter.day ||
      TopPeriodFilter.week ||
      TopPeriodFilter.month ||
      TopPeriodFilter.year =>
        const ['order:score'],
      _ => const [],
    };
  }

  int _int(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}
