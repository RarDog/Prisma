import 'package:dio/dio.dart';

import 'package:gel_rule_app/core/errors/app_exception.dart';
import 'package:gel_rule_app/core/http/dio_client.dart';
import 'package:gel_rule_app/core/models/post.dart';
import 'package:gel_rule_app/core/models/post_comment.dart';
import 'package:gel_rule_app/core/models/provider_health.dart';
import 'package:gel_rule_app/core/models/tag_suggestion.dart';
import 'package:gel_rule_app/core/models/top_period_filter.dart';
import 'package:gel_rule_app/sources/interfaces/content_provider.dart';
import 'package:gel_rule_app/sources/mappers/pixiv_mapper.dart';

class PixivProvider
    implements
        ContentProvider,
        PostPageProvider,
        MediaHeadersProvider,
        TagSuggestionProvider,
        CommentProvider {
  PixivProvider({
    required this.id,
    required this.name,
    required this.baseUrl,
    required DioClient dioClient,
    Map<String, String> queryParameters = const {},
    // PHPSESSID / cookie for auth (item 3)
    String? phpsessid,
  })  : _queryParameters = queryParameters,
        _dio = dioClient.dio,
        _phpsessid = phpsessid;

  @override
  final String id;
  @override
  final String name;
  @override
  final String baseUrl;
  final Dio _dio;
  final Map<String, String> _queryParameters;
  // Auth: PHPSESSID cookie value (optional)
  final String? _phpsessid;

  Dio get dio => _dio;
  Map<String, String> get queryParameters => _queryParameters;

  bool get isAuthenticated => _phpsessid != null && _phpsessid.isNotEmpty;

  // Build cookie header if phpsessid is set
  Options? get _authOptions => isAuthenticated
      ? Options(headers: {'Cookie': 'PHPSESSID=$_phpsessid'})
      : null;

  @override
  String postPageUrl(Post post) {
    final baseId = post.id.split('_p').first;
    return '$baseUrl/artworks/$baseId';
  }

  @override
  Map<String, String> mediaHeaders(Post post) {
    return const {
      'User-Agent':
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/125.0.0.0 Safari/537.36',
      'Referer': 'https://www.pixiv.net/',
      'Accept': '*/*',
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
    final cleanedTags = tags
        .map((t) => t.trim())
        .where((t) => t.isNotEmpty && !t.startsWith('rating:'))
        .toList();

    final isExplicit = rating == 'e' ||
        rating == 'explicit' ||
        rating == 'r18' ||
        tags.any((t) => t == 'rating:explicit' || t == 'rating:e');

    final targetPage = page + 1; // Pixiv API pages are 1-based (p=1, 2, 3...)

    try {
      if (cleanedTags.isEmpty) {
        // If authenticated — use following feed, otherwise public ranking
        if (isAuthenticated) {
          return await _fetchFollowFeed(page: targetPage);
        }

        String mode;
        if (isExplicit) {
          mode = switch (topPeriod) {
            TopPeriodFilter.week => 'weekly_r18',
            _ => 'daily_r18',
          };
        } else {
          mode = switch (topPeriod) {
            TopPeriodFilter.week => 'weekly',
            TopPeriodFilter.month => 'monthly',
            _ => 'daily',
          };
        }

        final response = await _dio.get<dynamic>(
          '/ranking.php',
          queryParameters: {
            'format': 'json',
            'mode': mode,
            'p': targetPage,
            ..._queryParameters,
          },
          options: _authOptions,
        );
        _checkResponse(response);
        return PixivMapper.postsFromRankingResponse(
          response.data,
          providerId: id,
          providerName: name,
        );
      }

      String mode = 'all';
      if (isExplicit) {
        mode = 'r18';
      } else if (rating == 's' ||
          rating == 'safe' ||
          rating == 'general' ||
          tags.any((t) => t == 'rating:safe' || t == 'rating:s')) {
        mode = 'safe';
      }

      final query = cleanedTags.join(' ');
      final response = await _dio.get<dynamic>(
        '/ajax/search/artworks/${Uri.encodeComponent(query)}',
        queryParameters: {
          'p': targetPage,
          'mode': mode,
          's_mode': 's_tag',
          'order': 'date_d',
          'lang': 'en',
          ..._queryParameters,
        },
        options: _authOptions,
      );
      _checkResponse(response);
      return PixivMapper.postsFromSearchResponse(
        response.data,
        providerId: id,
        providerName: name,
      );
    } on DioException catch (e) {
      _handleDioError(e);
    }
  }

  /// Fetches "Following" feed for authenticated users
  /// GET /ajax/follow_latest/illust?mode=all&p={page}
  Future<List<Post>> _fetchFollowFeed({required int page}) async {
    try {
      final response = await _dio.get<dynamic>(
        '/ajax/follow_latest/illust',
        queryParameters: {
          'mode': 'all',
          'p': page,
          'lang': 'en',
          ..._queryParameters,
        },
        options: _authOptions,
      );
      _checkResponse(response);
      // Follow feed uses body.thumbnails.illust[] structure (different from search)
      return PixivMapper.postsFromFollowFeedResponse(
        response.data,
        providerId: id,
        providerName: name,
      );
    } catch (_) {
      // Fallback to ranking if follow feed fails (e.g. bad session)
      final response = await _dio.get<dynamic>(
        '/ranking.php',
        queryParameters: {
          'format': 'json',
          'mode': 'daily',
          'p': page,
          ..._queryParameters,
        },
        options: _authOptions,
      );
      _checkResponse(response);
      return PixivMapper.postsFromRankingResponse(
        response.data,
        providerId: id,
        providerName: name,
      );
    }
  }

  @override
  Future<Post?> getPost(String id) async {
    try {
      if (id.contains('_p')) {
        final parts = id.split('_p');
        final baseId = parts.first;
        final pageIndex = int.tryParse(parts.last) ?? 0;
        final parent = await getPost(baseId);
        if (parent == null) return null;

        try {
          final pagesResponse = await _dio.get<dynamic>(
            '/ajax/illust/$baseId/pages',
            queryParameters: {'lang': 'en', ..._queryParameters},
            options: _authOptions,
          );
          if (pagesResponse.data is Map &&
              pagesResponse.data['body'] is List) {
            final pages = pagesResponse.data['body'] as List;
            if (pageIndex < pages.length) {
              final child = PixivMapper.postFromPageResponse(
                pageData: pages[pageIndex],
                parentPost: parent,
                pageIndex: pageIndex,
              );
              if (child != null) return child;
            }
          }
        } catch (_) {}
        return parent;
      }

      final response = await _dio.get<dynamic>(
        '/ajax/illust/$id',
        queryParameters: {'lang': 'en', ..._queryParameters},
        options: _authOptions,
      );
      _checkResponse(response);
      return PixivMapper.postFromIllustResponse(
        response.data,
        providerId: this.id,
        providerName: name,
      );
    } on DioException catch (e) {
      _handleDioError(e);
    }
  }

  @override
  Future<List<TagSuggestion>> suggestTags(String query,
      {int limit = 20}) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return const [];
    try {
      final response = await _dio.get<dynamic>(
        '/rpc/cps.php',
        queryParameters: {'keyword': trimmed},
        options: _authOptions,
      );
      if (response.data is Map && response.data['candidates'] is List) {
        final candidates = response.data['candidates'] as List;
        final results = <TagSuggestion>[];
        for (final c in candidates) {
          if (c is Map && c['tag_name'] != null) {
            results.add(TagSuggestion(
              name: c['tag_name'].toString(),
              category: TagCategory.general,
              postCount: int.tryParse('${c['access_count'] ?? 0}') ?? 0,
              providerId: id,
            ));
          }
        }
        return results.take(limit).toList();
      }
    } catch (_) {}
    return const [];
  }

  // --- CommentProvider implementation (item 6) ---
  // GET /ajax/illusts/comments/roots?illust_id={postId}&offset=0&limit=50
  @override
  Future<List<PostComment>> getComments(String postId) async {
    // Strip page suffix e.g. "12345678_p0" → "12345678"
    final illustId = postId.split('_p').first;
    try {
      final response = await _dio.get<dynamic>(
        '/ajax/illusts/comments/roots',
        queryParameters: {
          'illust_id': illustId,
          'offset': 0,
          'limit': 50,
        },
        options: _authOptions,
      );

      if (response.data is! Map) return const [];
      final body = response.data['body'];
      if (body is! Map) return const [];
      final commentsList = body['comments'];
      if (commentsList is! List) return const [];

      final result = <PostComment>[];
      for (final c in commentsList) {
        if (c is! Map) continue;
        final commentId = c['id']?.toString() ?? '';
        final authorName = c['userName']?.toString() ?? 'Anonymous';
        final rawBody = c['comment']?.toString() ?? '';
        final stampId = c['stampId']?.toString();
        final dateStr = c['commentDate']?.toString() ?? '';

        // Build body text: if it's a stamp and no text, show stamp indicator
        final bodyText = rawBody.isNotEmpty
            ? rawBody
            : (stampId != null ? '🖼 Stamp #$stampId' : '');

        if (commentId.isEmpty) continue;

        DateTime createdAt;
        try {
          // Format: "2024-03-06 18:32"
          createdAt = DateTime.parse(dateStr.replaceFirst(' ', 'T'));
        } catch (_) {
          createdAt = DateTime.now();
        }

        result.add(PostComment(
          id: commentId,
          postId: postId,
          providerId: id,
          authorName: authorName,
          body: bodyText,
          createdAt: createdAt,
        ));
      }
      return result;
    } catch (_) {
      return const [];
    }
  }

  @override
  Future<ProviderHealth> checkHealth() async {
    final startedAt = DateTime.now();
    try {
      await _dio.get<dynamic>(
        '/ranking.php',
        queryParameters: {
          'format': 'json',
          'mode': 'daily',
          'p': 1,
          ..._queryParameters,
        },
        options: _authOptions,
      );
      return ProviderHealth(
        providerId: id,
        status: ProviderStatus.online,
        pingMs: DateTime.now().difference(startedAt).inMilliseconds,
        lastCheckedAt: DateTime.now(),
        apiVersion: isAuthenticated ? 'pixiv-web-ajax-auth' : 'pixiv-web-ajax',
      );
    } catch (error) {
      return ProviderHealth(
        providerId: id,
        status: ProviderStatus.offline,
        pingMs: DateTime.now().difference(startedAt).inMilliseconds,
        lastCheckedAt: DateTime.now(),
        errorMessage: error.toString(),
        apiVersion: 'pixiv-web-ajax',
      );
    }
  }

  void _checkResponse(Response<dynamic> response) {
    if (response.statusCode != null && response.statusCode! >= 400) {
      throw BadResponseException(
        'Pixiv returned HTTP ${response.statusCode}',
        details: response.data,
      );
    }
    if (response.data is Map && response.data['error'] == true) {
      throw BadResponseException(
        response.data['message']?.toString() ?? 'Pixiv API error',
        details: response.data,
      );
    }
  }

  Never _handleDioError(DioException error) {
    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.sendTimeout) {
      throw RequestTimeoutException(
        'Request timeout to Pixiv',
        details: error.message,
      );
    }
    if (error.type == DioExceptionType.badResponse) {
      throw BadResponseException(
        'Pixiv returned HTTP ${error.response?.statusCode}',
        details: error.response?.data,
      );
    }
    throw NetworkException(
      'Network failure with Pixiv',
      details: error.message,
    );
  }
}
