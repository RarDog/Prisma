import 'package:dio/dio.dart';

import 'package:gel_rule_app/core/errors/app_exception.dart';
import 'package:gel_rule_app/core/http/dio_client.dart';
import 'package:gel_rule_app/core/models/post.dart';
import 'package:gel_rule_app/core/models/provider_health.dart';
import 'package:gel_rule_app/core/models/tag_suggestion.dart';
import 'package:gel_rule_app/core/models/top_period_filter.dart';
import 'package:gel_rule_app/sources/interfaces/content_provider.dart';
import 'package:gel_rule_app/sources/mappers/nhentai_mapper.dart';

class NHentaiProvider
    implements
        ContentProvider,
        PostPageProvider,
        MediaHeadersProvider,
        TagSuggestionProvider {
  NHentaiProvider({
    required this.id,
    required this.name,
    required this.baseUrl,
    required DioClient dioClient,
    Map<String, String> queryParameters = const {},
    String imagesHost = 'i.nhentai.net',
    String thumbsHost = 't.nhentai.net',
  })  : _queryParameters = queryParameters,
        _dio = dioClient.dio,
        _imagesHost = imagesHost,
        _thumbsHost = thumbsHost;

  @override
  final String id;
  @override
  final String name;
  @override
  final String baseUrl;
  final Dio _dio;
  final Map<String, String> _queryParameters;
  final String _imagesHost;
  final String _thumbsHost;

  Dio get dio => _dio;
  Map<String, String> get queryParameters => _queryParameters;

  @override
  String postPageUrl(Post post) {
    final baseId = post.id.split('_p').first;
    return 'https://nhentai.net/g/$baseId/';
  }

  @override
  Map<String, String> mediaHeaders(Post post) {
    return const {
      'User-Agent':
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/129.0.0.0 Safari/537.36',
      'Referer': 'https://nhentai.net/',
      'Accept': 'image/avif,image/webp,image/apng,image/*,*/*;q=0.8',
    };
  }

  @override
  Future<List<Post>> searchPosts({
    required List<String> tags,
    required int page,
    int limit = 25,
    String? rating,
    TopPeriodFilter topPeriod = TopPeriodFilter.none,
  }) async {
    final targetPage = page + 1; // nhentai is 1-indexed

    final cleanedTags = tags
        .map((t) => t.trim())
        .where((t) => t.isNotEmpty && !t.startsWith('rating:'))
        .toList();

    String sortParam = '';
    if (topPeriod == TopPeriodFilter.day) {
      sortParam = 'popular-today';
    } else if (topPeriod == TopPeriodFilter.week) {
      sortParam = 'popular-week';
    } else if (topPeriod == TopPeriodFilter.month) {
      sortParam = 'popular-month';
    } else if (topPeriod == TopPeriodFilter.allTime) {
      sortParam = 'popular';
    }

    try {
      Response<dynamic> response;
      if (cleanedTags.isEmpty) {
        if (sortParam.isNotEmpty) {
          // Popular endpoint via search query
          response = await _dio.get<dynamic>(
            '/api/galleries/search',
            queryParameters: {
              'query': '""',
              'page': targetPage,
              'sort': sortParam,
              ..._queryParameters,
            },
          );
        } else {
          // Recent feed
          response = await _dio.get<dynamic>(
            '/api/galleries/all',
            queryParameters: {
              'page': targetPage,
              ..._queryParameters,
            },
          );
        }
      } else {
        // Tag / text search
        final query = cleanedTags.join(' ');
        final queryParams = <String, dynamic>{
          'query': query,
          'page': targetPage,
          if (sortParam.isNotEmpty) 'sort': sortParam,
          ..._queryParameters,
        };

        response = await _dio.get<dynamic>(
          '/api/galleries/search',
          queryParameters: queryParams,
        );
      }

      _checkResponse(response);
      return NHentaiMapper.postsFromSearchResponse(
        response.data,
        providerId: id,
        providerName: name,
        imagesHost: _imagesHost,
        thumbsHost: _thumbsHost,
      );
    } on DioException catch (e) {
      _handleDioError(e);
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

        // Fetch gallery details to get the exact page object
        final response = await _dio.get<dynamic>(
          '/api/gallery/$baseId',
          queryParameters: _queryParameters,
        );
        _checkResponse(response);

        if (response.data is Map &&
            response.data['images'] is Map &&
            response.data['images']['pages'] is List) {
          final pages = response.data['images']['pages'] as List;
          if (pageIndex < pages.length) {
            final pagePost = NHentaiMapper.postFromPageData(
              pageItem: pages[pageIndex],
              parentPost: parent,
              pageIndex: pageIndex,
              imagesHost: _imagesHost,
              thumbsHost: _thumbsHost,
            );
            if (pagePost != null) return pagePost;
          }
        }
        return parent;
      }

      final response = await _dio.get<dynamic>(
        '/api/gallery/$id',
        queryParameters: _queryParameters,
      );
      _checkResponse(response);

      return NHentaiMapper.postFromGalleryJson(
        response.data,
        providerId: this.id,
        providerName: name,
        imagesHost: _imagesHost,
        thumbsHost: _thumbsHost,
      );
    } on DioException catch (e) {
      _handleDioError(e);
    }
  }

  @override
  Future<List<TagSuggestion>> suggestTags(String query, {int limit = 20}) async {
    // nhentai tags are typically queried through search
    return const [];
  }

  @override
  Future<ProviderHealth> checkHealth() async {
    final startedAt = DateTime.now();
    try {
      await _dio.get<dynamic>(
        '/api/galleries/all',
        queryParameters: {
          'page': 1,
          ..._queryParameters,
        },
      );
      return ProviderHealth(
        providerId: id,
        status: ProviderStatus.online,
        pingMs: DateTime.now().difference(startedAt).inMilliseconds,
        lastCheckedAt: DateTime.now(),
        apiVersion: 'nhentai-api-v2',
      );
    } catch (error) {
      return ProviderHealth(
        providerId: id,
        status: ProviderStatus.offline,
        pingMs: DateTime.now().difference(startedAt).inMilliseconds,
        lastCheckedAt: DateTime.now(),
        errorMessage: error.toString(),
        apiVersion: 'nhentai-api-v2',
      );
    }
  }

  void _checkResponse(Response<dynamic> response) {
    if (response.statusCode != null && response.statusCode! >= 400) {
      throw BadResponseException(
        'nhentai returned HTTP ${response.statusCode}',
        details: response.data,
      );
    }
    if (response.data is Map && response.data['error'] != null) {
      throw BadResponseException(
        response.data['error'].toString(),
        details: response.data,
      );
    }
  }

  Never _handleDioError(DioException error) {
    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.sendTimeout) {
      throw RequestTimeoutException(
        'Request timeout to nhentai',
        details: error.message,
      );
    }
    if (error.type == DioExceptionType.badResponse) {
      throw BadResponseException(
        'nhentai returned HTTP ${error.response?.statusCode}',
        details: error.response?.data,
      );
    }
    throw NetworkException(
      'Network failure with nhentai',
      details: error.message,
    );
  }
}
