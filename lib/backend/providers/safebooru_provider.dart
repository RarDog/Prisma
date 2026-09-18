import 'package:dio/dio.dart';

import '../mappers/gelbooru_mapper.dart';
import '../models/post.dart';
import '../models/tag_suggestion.dart';
import '../models/top_period_filter.dart';
import 'gelbooru_provider.dart';

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
  Map<String, String> mediaHeaders(Post post) => {
        'User-Agent': 'Prisma/4.0.0 Flutter local booru browser',
        'Accept': '*/*',
        'Referer': '$baseUrl/',
      };

  @override
  Future<List<Post>> searchPosts({
    required List<String> tags,
    required int page,
    int limit = 50,
    String? rating,
    TopPeriodFilter topPeriod = TopPeriodFilter.none,
  }) async {
    final topTags = switch (topPeriod) {
      TopPeriodFilter.allTime => const ['sort:score:desc'],
      _ => const <String>[],
    };

    try {
      final response = await dio.get<dynamic>(
        '/index.php',
        queryParameters: {
          'page': 'dapi',
          's': 'post',
          'q': 'index',
          'json': '1',
          'pid': page,
          'limit': limit,
          'tags': [
            ...tags,
            if (rating != null && rating.isNotEmpty) 'rating:$rating',
            ...topTags,
          ].join(' '),
          ...queryParameters,
        },
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
        queryParameters: {
          'page': 'dapi',
          's': 'post',
          'q': 'index',
          'json': '1',
          'id': id,
          ...queryParameters,
        },
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

      final data = response.data;
      if (data is List) {
        final countRegExp = RegExp(r'\((\d+)\)');
        final suggestions = <TagSuggestion>[];
        for (final item in data) {
          if (item is Map) {
            final value = (item['value'] ?? '').toString();
            final label = (item['label'] ?? '').toString();
            if (value.isNotEmpty) {
              int count = 0;
              final match = countRegExp.firstMatch(label);
              if (match != null) {
                count = int.tryParse(match.group(1) ?? '') ?? 0;
              }
              suggestions.add(TagSuggestion(
                name: value,
                postCount: count,
                category: TagCategory.general,
                providerId: id,
              ));
            }
          }
          if (suggestions.length >= limit) break;
        }
        if (suggestions.isNotEmpty) return suggestions;
      }
    } catch (_) {
      // Fallback to dapi tag search
    }

    return super.suggestTags(query, limit: limit);
  }
}
