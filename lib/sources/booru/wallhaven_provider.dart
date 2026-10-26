import 'dart:async';
import 'package:dio/dio.dart';
import 'package:gel_rule_app/core/errors/app_exception.dart';
import 'package:gel_rule_app/core/http/dio_client.dart';
import 'package:gel_rule_app/core/models/post.dart';
import 'package:gel_rule_app/core/models/provider_health.dart';
import 'package:gel_rule_app/core/models/tag_suggestion.dart';
import 'package:gel_rule_app/core/models/top_period_filter.dart';
import 'package:flutter/foundation.dart';
import 'package:gel_rule_app/sources/interfaces/content_provider.dart';

class WallhavenProvider
    implements
        ContentProvider,
        PostPageProvider,
        MediaHeadersProvider,
        TagSuggestionProvider {
  WallhavenProvider({
    required this.id,
    required this.name,
    required this.baseUrl,
    required this.dioClient,
    this.apiKey,
    this.categories = '111',
  });

  @override
  final String id;
  @override
  final String name;
  @override
  final String baseUrl;
  final DioClient dioClient;
  final String? apiKey;
  final String categories;

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
  String? postPageUrl(Post post) => 'https://wallhaven.cc/w/${post.id}';

  @override
  Map<String, String> mediaHeaders(Post post) => {
        'Referer': 'https://wallhaven.cc/',
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
    // Wallhaven API pages are 1-based (p=1, 2, 3...).
    // Prisma calls searchPosts with page=0 initially; Wallhaven returns 500 if page=0 is sent.
    final targetPage = page <= 0 ? 1 : page + 1;

    final queryParams = <String, dynamic>{
      'page': targetPage,
      'categories': categories,
      'purity': apiKey != null && apiKey!.isNotEmpty ? '111' : '100',
    };

    if (apiKey != null && apiKey!.isNotEmpty) {
      queryParams['apikey'] = apiKey;
    }

    if (tags.isNotEmpty) {
      queryParams['q'] = tags.join(' ');
    }

    switch (topPeriod) {
      case TopPeriodFilter.day:
        queryParams['sorting'] = 'toplist';
        queryParams['topRange'] = '1d';
        break;
      case TopPeriodFilter.week:
        queryParams['sorting'] = 'toplist';
        queryParams['topRange'] = '1w';
        break;
      case TopPeriodFilter.month:
        queryParams['sorting'] = 'toplist';
        queryParams['topRange'] = '1M';
        break;
      case TopPeriodFilter.year:
        queryParams['sorting'] = 'toplist';
        queryParams['topRange'] = '1y';
        break;
      case TopPeriodFilter.allTime:
        queryParams['sorting'] = 'toplist';
        queryParams['topRange'] = '1y';
        break;
      case TopPeriodFilter.none:
        if (tags.isEmpty) {
          queryParams['sorting'] = 'toplist';
        }
        break;
    }

    try {
      final response = await dioClient.dio.get<Map<String, dynamic>>(
        '/api/v1/search',
        queryParameters: queryParams,
        cancelToken: cancelToken,
      );

      final data = response.data;
      if (data == null || data['data'] is! List) return [];

      final items = data['data'] as List;
      final posts = <Post>[];
      for (final item in items) {
        if (item is! Map<String, dynamic>) continue;
        final post = _mapToPost(item);
        if (post != null) posts.add(post);
      }
      return posts;
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout) {
        throw const RequestTimeoutException('Wallhaven timeout');
      }
      final status = e.response?.statusCode;
      final msg = e.response?.data is Map && e.response?.data['error'] != null
          ? e.response?.data['error'].toString()
          : (e.message ?? e.error?.toString() ?? 'HTTP $status');
      throw NetworkException('Wallhaven error: $msg');
    }
  }

  @override
  Future<Post?> getPost(String id) async {
    try {
      final queryParams = <String, dynamic>{};
      if (apiKey != null && apiKey!.isNotEmpty) {
        queryParams['apikey'] = apiKey;
      }
      final response = await dioClient.dio.get<Map<String, dynamic>>(
        '/api/v1/w/$id',
        queryParameters: queryParams,
      );
      final data = response.data?['data'];
      if (data is! Map<String, dynamic>) return null;
      return _mapToPost(data);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout) {
        throw RequestTimeoutException('Wallhaven timeout: ${e.message}');
      }
      throw NetworkException('Wallhaven network error: ${e.message}');
    }
  }

  @visibleForTesting
  Post? mapToPost(Map<String, dynamic> item) => _mapToPost(item);

  Post? _mapToPost(Map<String, dynamic> item) {
    final idStr = item['id']?.toString();
    if (idStr == null || idStr.isEmpty) return null;

    final thumbs = item['thumbs'] as Map<String, dynamic>?;
    final path = item['path'] as String? ?? '';
    final thumbLarge = thumbs?['large'] as String? ?? '';
    final thumbSmall = thumbs?['small'] as String? ?? '';
    final preview = thumbLarge.isNotEmpty ? thumbLarge : thumbSmall;
    final fileUrl = path.isNotEmpty ? path : preview;

    final tags = <String>[];
    if (item['tags'] is List) {
      for (final t in item['tags'] as List) {
        if (t is Map<String, dynamic> && t['name'] != null) {
          tags.add(t['name'].toString().toLowerCase().replaceAll(' ', '_'));
        }
      }
    }
    final category = item['category']?.toString();
    if (category != null && category.isNotEmpty) {
      tags.add(category.toLowerCase());
    }

    final purity = item['purity']?.toString().toLowerCase();
    final rating = purity == 'nsfw' ? 'e' : (purity == 'sketchy' ? 'q' : 's');

    final width = (item['dimension_x'] as num?)?.toInt() ?? 0;
    final height = (item['dimension_y'] as num?)?.toInt() ?? 0;
    final favs = (item['favorites'] as num?)?.toInt() ?? 0;

    DateTime? createdAt;
    final rawDate = item['created_at'] as String?;
    if (rawDate != null) {
      createdAt = DateTime.tryParse(rawDate);
    }

    final fileType = fileUrl.toLowerCase().endsWith('.png') ? 'png' : 'jpg';

    return Post(
      id: idStr,
      providerId: id,
      providerName: name,
      previewUrl: preview,
      sampleUrl: fileUrl,
      fileUrl: fileUrl,
      width: width,
      height: height,
      score: favs,
      rating: rating,
      tags: tags,
      createdAt: createdAt ?? DateTime.now(),
      fileType: fileType,
      source: item['url'] as String?,
      tagGroups: {
        if (item['resolution'] != null)
          'resolution': [item['resolution'].toString()],
      },
    );
  }

  @override
  Future<List<TagSuggestion>> suggestTags(String query,
      {int limit = 20}) async {
    final trimmed = query.trim().toLowerCase();
    if (trimmed.isEmpty) return [];
    const candidates = [
      'anime',
      'cyberpunk',
      'nature',
      'landscape',
      'artwork',
      'digital_art',
      'fantasy',
      'science_fiction',
      'space',
      'minimalism',
      'city',
      'night',
      'dark',
      'neon',
      'cars',
      'girl',
      'vehicle',
      'abstract',
      'architecture'
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
        '/api/v1/search',
        queryParameters: {'page': 1, 'categories': '100', 'purity': '100'},
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
        apiVersion: 'wallhaven-v1',
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
