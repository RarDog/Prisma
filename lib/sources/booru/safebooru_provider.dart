import 'package:dio/dio.dart';
import 'package:prisma_app/core/http/app_headers.dart';

import 'package:prisma_app/sources/mappers/gelbooru_mapper.dart';
import 'package:prisma_app/core/models/post.dart';
import 'package:prisma_app/core/models/tag_suggestion.dart';
import 'package:prisma_app/core/models/top_period_filter.dart';
import 'package:prisma_app/sources/booru/gelbooru_provider.dart';

class SafebooruProvider extends GelbooruProvider {
  SafebooruProvider({
    required super.id,
    required super.name,
    required super.baseUrl,
    required super.dioClient,
    super.queryParameters,
  });

  @override
  String postPageUrl(Post post) =>
      '$baseUrl/index.php?page=post&s=view&id=${post.id}';

  @override
  Map<String, String> mediaHeaders(Post post) => AppHeaders.mediaHeaders(
        referer: '$baseUrl/',
      );

  @override
  Future<List<Post>> searchPosts({
    required List<String> tags,
    required int page,
    int limit = 50,
    String? rating,
    TopPeriodFilter topPeriod = TopPeriodFilter.none,
    CancelToken? cancelToken,
  }) async {
    try {
      final response = await dio.get<dynamic>(
        '/index.php',
        queryParameters: dapiQuery('post', params: {
          'pid': page,
          'limit': limit,
          'tags': [
            ...tags,
            ...topTagsFor(topPeriod),
          ].join(' '),
        }),
        cancelToken: cancelToken,
      );

      final data = response.data;
      if (data == null || (data is String && data.trim().isEmpty)) {
        return const [];
      }

      return GelbooruMapper.postsFromResponse(
        data,
        providerId: id,
        providerName: name,
      );
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return const [];
      rethrow;
    }
  }

  @override
  Future<Post?> getPost(String id) async {
    try {
      final response = await dio.get<dynamic>(
        '/index.php',
        queryParameters: dapiQuery('post', params: {'id': id}),
      );

      final data = response.data;
      if (data == null || (data is String && data.trim().isEmpty)) {
        return null;
      }

      final posts = GelbooruMapper.postsFromResponse(
        data,
        providerId: this.id,
        providerName: name,
      );
      return posts.firstOrNull;
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
      // First attempt Safebooru's fast autocomplete API
      final response = await dio.get<dynamic>(
        '/autocomplete.php',
        queryParameters: {'q': trimmed},
      );

      final suggestions = suggestionsFromAutocomplete(
        response.data,
        limit: limit,
      );
      if (suggestions.isNotEmpty) return suggestions;
    } catch (_) {
      // Fallback to dapi tag search
    }

    return super.suggestTags(query, limit: limit);
  }
}
