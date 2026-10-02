import 'package:dio/dio.dart';
import 'package:gel_rule_app/core/http/app_headers.dart';

import 'package:gel_rule_app/core/errors/app_exception.dart';
import 'package:gel_rule_app/core/http/dio_client.dart';
import 'package:gel_rule_app/core/models/post.dart';
import 'package:gel_rule_app/core/models/provider_health.dart';
import 'package:gel_rule_app/core/models/tag_suggestion.dart';
import 'package:gel_rule_app/core/models/top_period_filter.dart';
import 'package:gel_rule_app/core/utils/logger.dart';
import 'package:gel_rule_app/sources/booru/mangadex_provider.dart';
import 'package:gel_rule_app/sources/interfaces/content_provider.dart';

class MangaLibProvider
    implements
        ContentProvider,
        PostPageProvider,
        MediaHeadersProvider,
        TagSuggestionProvider,
        MangaChapterProvider {
  MangaLibProvider({
    required this.id,
    required this.name,
    required this.baseUrl,
    required DioClient dioClient,
    Map<String, String> queryParameters = const {},
  })  : _queryParameters = queryParameters,
        _dio = dioClient.dio;

  @override
  final String id;
  @override
  final String name;
  @override
  final String baseUrl;
  final Dio _dio;
  final Map<String, String> _queryParameters;

  Dio get dio => _dio;
  Map<String, String> get queryParameters => _queryParameters;
  String get _apiBase {
    if (baseUrl.contains('cdnlibs.org')) {
      return baseUrl.endsWith('/api') ? baseUrl : '$baseUrl/api';
    }
    return 'https://api.cdnlibs.org/api';
  }

  Map<String, String> get _headers => AppHeaders.browserHeaders(
        siteId: '1',
        referer: 'https://mangalib.me/',
        origin: 'https://mangalib.me',
      );

  @override
  String postPageUrl(Post post) {
    return 'https://mangalib.me/ru/${post.id}';
  }

  @override
  Map<String, String> mediaHeaders(Post post) {
    return AppHeaders.mediaHeaders(
      referer: 'https://mangalib.me/',
      userAgent: AppHeaders.desktopChromeUserAgent,
      accept: 'image/avif,image/webp,image/apng,image/*,*/*;q=0.8',
    );
  }

  @override
  Future<List<Post>> searchPosts({
    required List<String> tags,
    required int page,
    int limit = 24,
    String? rating,
    TopPeriodFilter topPeriod = TopPeriodFilter.none,
  }) async {
    final targetPage = page + 1; // 1-indexed
    final queryText = tags
        .where((t) => !t.startsWith('rating:') && !t.startsWith('lang:'))
        .join(' ')
        .trim();

    try {
      final queryParams = <String, dynamic>{
        'page': targetPage,
        'site_id[]': 1, // 1 = mangalib
      };

      if (queryText.isNotEmpty) {
        queryParams['q'] = queryText;
      }

      if (topPeriod == TopPeriodFilter.day || topPeriod == TopPeriodFilter.week) {
        queryParams['sort_by'] = 'views';
        queryParams['sort_type'] = 'desc';
      } else {
        queryParams['sort_by'] = 'views';
        queryParams['sort_type'] = 'desc';
      }

      final uri = '$_apiBase/manga';
      final response = await _dio.get(
        uri,
        queryParameters: queryParams,
        options: Options(
          headers: _headers,
        ),
      );

      final data = response.data;
      if (data == null) return [];

      final items = data is Map ? (data['data'] as List<dynamic>? ?? []) : (data is List ? data : []);
      final posts = <Post>[];

      for (final raw in items) {
        if (raw is! Map) continue;
        final map = Map<String, dynamic>.from(raw);
        final slug = map['slug']?.toString() ?? map['id']?.toString() ?? '';
        final slugUrl = map['slug_url']?.toString() ?? slug;
        if (slugUrl.isEmpty) continue;

        final rusName = map['rus_name']?.toString() ?? '';
        final engName = map['eng_name']?.toString() ?? map['name']?.toString() ?? '';
        final title = rusName.isNotEmpty ? rusName : engName;

        final coverMap = map['cover'] is Map ? Map<String, dynamic>.from(map['cover'] as Map) : null;
        final coverUrl = coverMap?['default']?.toString() ??
            coverMap?['thumbnail']?.toString() ??
            'https://cover.cdnlibs.org/uploads/cover/$slug/cover/cover.jpg';

        final genres = <String>[];
        if (map['genres'] is List) {
          for (final g in map['genres'] as List) {
            if (g is Map && g['name'] != null) {
              genres.add(g['name'].toString().toLowerCase().replaceAll(' ', '_'));
            }
          }
        }

        posts.add(
          Post(
            id: slugUrl,
            providerId: id,
            providerName: name,
            fileType: 'jpg',
            previewUrl: coverUrl,
            sampleUrl: coverUrl,
            fileUrl: coverUrl,
            width: 400,
            height: 600,
            tags: [
              ...genres,
              if (rusName.isNotEmpty) rusName.toLowerCase().replaceAll(' ', '_'),
              if (engName.isNotEmpty) engName.toLowerCase().replaceAll(' ', '_'),
            ],
            rating: 's',
            score: (double.tryParse(map['rating']?['average']?.toString() ?? '0') ?? 0).round(),
            source: 'https://mangalib.me/ru/$slugUrl',
            createdAt: DateTime.now(),
            tagGroups: {
              'general': genres,
              'title': [title],
              if (rusName.isNotEmpty) 'rus_title': [rusName],
              if (engName.isNotEmpty) 'eng_title': [engName],
              if (map['summary'] != null) 'description': [map['summary'].toString()],
            },
          ),
        );
      }

      return posts;
    } on DioException catch (e) {
      throw BadResponseException(e.message ?? 'MangaLib API error', details: e.toString());
    }
  }

  @override
  Future<Post?> getPost(String postId) async {
    try {
      final response = await _dio.get(
        '$_apiBase/manga/$postId',
        queryParameters: {
          'fields[]': ['summary', 'genres', 'authors'],
        },
        options: Options(
          headers: _headers,
        ),
      );
      final data = response.data;
      if (data == null || data is! Map) return null;
      final map = Map<String, dynamic>.from(data['data'] is Map ? data['data'] as Map : data);

      final slug = map['slug']?.toString() ?? postId;
      final slugUrl = map['slug_url']?.toString() ?? slug;
      final rusName = map['rus_name']?.toString() ?? '';
      final engName = map['eng_name']?.toString() ?? map['name']?.toString() ?? '';
      final title = rusName.isNotEmpty ? rusName : engName;

      final coverMap = map['cover'] is Map ? Map<String, dynamic>.from(map['cover'] as Map) : null;
      final coverUrl = coverMap?['default']?.toString() ??
          coverMap?['thumbnail']?.toString() ??
          'https://cover.cdnlibs.org/uploads/cover/$slug/cover/cover.jpg';

      final genres = <String>[];
      if (map['genres'] is List) {
        for (final g in map['genres'] as List) {
          if (g is Map && g['name'] != null) {
            genres.add(g['name'].toString().toLowerCase().replaceAll(' ', '_'));
          }
        }
      }

      final summary = map['summary']?.toString() ?? '';

      return Post(
        id: slugUrl,
        providerId: id,
        providerName: name,
        fileType: 'jpg',
        previewUrl: coverUrl,
        sampleUrl: coverUrl,
        fileUrl: coverUrl,
        width: 400,
        height: 600,
        tags: genres,
        rating: 's',
        score: (double.tryParse(map['rating']?['average']?.toString() ?? '0') ?? 0).round(),
        source: 'https://mangalib.me/ru/$slugUrl',
        createdAt: DateTime.now(),
        tagGroups: {
          'general': genres,
          'title': [title],
          if (rusName.isNotEmpty) 'rus_title': [rusName],
          if (engName.isNotEmpty) 'eng_title': [engName],
          if (summary.isNotEmpty) 'description': [summary],
        },
      );
    } catch (e, st) {
      AppLogger.log('MangaLibProvider._parseMangaItem error', e, st);
      return null;
    }
  }

  @override
  Future<List<MangaDexChapter>> fetchChapters(String mangaId) async {
    try {
      final response = await _dio.get(
        '$_apiBase/manga/$mangaId/chapters',
        options: Options(
          headers: _headers,
        ),
      );

      final data = response.data;
      if (data == null) return [];
      final list = data is Map ? (data['data'] as List<dynamic>? ?? []) : (data is List ? data : []);

      final chapters = <MangaDexChapter>[];
      for (final raw in list) {
        if (raw is! Map) continue;
        final map = Map<String, dynamic>.from(raw);
        final chNumber = map['number']?.toString() ?? '1';
        final volume = map['volume']?.toString() ?? '1';
        final rawTitle = map['name']?.toString() ?? '';
        final title = rawTitle.isNotEmpty ? rawTitle : 'Глава $chNumber';
        final chId = '$mangaId:$volume:$chNumber';

        chapters.add(
          MangaDexChapter(
            id: chId,
            chapterNumber: chNumber,
            title: title,
            language: 'ru',
            pageCount: (map['pages_count'] as num?)?.toInt() ?? 0,
            volumeNumber: volume,
          ),
        );
      }

      return chapters;
    } catch (e, st) {
      AppLogger.log('MangaLibProvider.fetchChapters error for $mangaId', e, st);
      return [];
    }
  }

  @override
  Future<List<String>> fetchChapterPages(String chapterId) async {
    try {
      final parts = chapterId.split(':');
      final mangaSlug = parts[0];
      final volume = parts.length > 1 ? parts[1] : '1';
      final number = parts.length > 2 ? parts[2] : '1';

      final response = await _dio.get(
        '$_apiBase/manga/$mangaSlug/chapter',
        queryParameters: {
          'volume': volume,
          'number': number,
        },
        options: Options(
          headers: _headers,
        ),
      );

      final data = response.data;
      if (data == null || data is! Map) return [];
      final chapterData = data['data'] is Map ? data['data'] as Map : data;
      final pagesList = chapterData['pages'] as List<dynamic>? ?? [];
      final urls = <String>[];

      for (final p in pagesList) {
        if (p is Map && p['url'] != null) {
          final raw = p['url'].toString();
          if (raw.startsWith('http://') || raw.startsWith('https://')) {
            urls.add(raw);
          } else {
            // Raw format is usually //manga/slug/chapters/... or /manga/...
            final clean = raw.replaceFirst(RegExp(r'^/+'), '');
            urls.add('https://img3.cdnlibs.org/$clean');
          }
        }
      }
      return urls;
    } catch (e, st) {
      AppLogger.log('MangaLibProvider.fetchChapterPages error for $chapterId', e, st);
      return [];
    }
  }

  @override
  Future<List<TagSuggestion>> suggestTags(String query, {int limit = 20}) async {
    if (query.trim().isEmpty) return [];
    try {
      final posts = await searchPosts(tags: [query], page: 0, limit: limit);
      return posts.map((p) {
        final title = p.tagGroups['title']?.firstOrNull ?? p.id;
        return TagSuggestion(
          name: title,
          category: TagCategory.copyright,
          postCount: p.score,
          providerId: id,
        );
      }).toList();
    } catch (_) {
      return [];
    }
  }

  @override
  Future<ProviderHealth> checkHealth() async {
    final startedAt = DateTime.now();
    try {
      final res = await _dio.get<dynamic>(
        '$baseUrl/api/manga?page=1&limit=1',
        options: Options(
          headers: AppHeaders.browserHeaders(
            referer: 'https://mangalib.me/',
          ),
        ),
      );
      final ok = res.statusCode == 200;
      return ProviderHealth(
        providerId: id,
        status: ok ? ProviderStatus.online : ProviderStatus.offline,
        pingMs: DateTime.now().difference(startedAt).inMilliseconds,
        lastCheckedAt: DateTime.now(),
      );
    } catch (e) {
      return ProviderHealth(
        providerId: id,
        status: ProviderStatus.offline,
        pingMs: DateTime.now().difference(startedAt).inMilliseconds,
        lastCheckedAt: DateTime.now(),
        errorMessage: e.toString(),
      );
    }
  }
}
