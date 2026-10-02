import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gel_rule_app/core/errors/app_exception.dart';
import 'package:gel_rule_app/core/http/dio_client.dart';
import 'package:gel_rule_app/core/models/post.dart';
import 'package:gel_rule_app/core/models/provider_health.dart';
import 'package:gel_rule_app/core/models/tag_suggestion.dart';
import 'package:gel_rule_app/features/providers/models/content_provider_config.dart';
import 'package:gel_rule_app/sources/booru/mangalib_provider.dart';
import 'package:gel_rule_app/sources/provider_factory.dart';

void main() {
  group('MangaLibProvider Tests', () {
    test('ProviderFactory creates MangaLibProvider from config', () {
      final factory = ProviderFactory();
      final config = ContentProviderConfig(
        id: 'mangalib',
        name: 'MangaLib',
        baseUrl: 'https://api.cdnlibs.org/api',
        apiType: 'mangalib',
        enabled: true,
        priority: 10,
        timeoutSeconds: 20,
        customHeaders: const {},
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      );

      final provider = factory.create(config);
      expect(provider, isA<MangaLibProvider>());
      expect(provider.id, equals('mangalib'));
      expect(provider.name, equals('MangaLib'));
      expect(provider.baseUrl, equals('https://api.cdnlibs.org/api'));
    });

    test('postPageUrl and mediaHeaders return valid Mangalib metadata', () {
      final dio = Dio();
      final client = DioClient(dio: dio);
      final provider = MangaLibProvider(
        id: 'mangalib',
        name: 'MangaLib',
        baseUrl: 'https://api.cdnlibs.org/api',
        dioClient: client,
      );

      final dummyPost = Post(
        id: '12345--berserk',
        providerId: 'mangalib',
        providerName: 'MangaLib',
        previewUrl: 'https://cover.cdnlibs.org/cover.jpg',
        sampleUrl: 'https://cover.cdnlibs.org/cover.jpg',
        fileUrl: 'https://cover.cdnlibs.org/cover.jpg',
        tags: const ['action', 'dark_fantasy'],
        rating: 's',
        width: 400,
        height: 600,
        createdAt: DateTime.now(),
        fileType: 'jpg',
        score: 10,
      );

      expect(provider.postPageUrl(dummyPost), equals('https://mangalib.me/ru/12345--berserk'));
      final headers = provider.mediaHeaders(dummyPost);
      expect(headers['Referer'], equals('https://mangalib.me/'));
      expect(headers['User-Agent'], isNotEmpty);
      expect(headers['Accept'], contains('image/'));
    });

    test('searchPosts parses catalog items with Russian name, genres, and covers', () async {
      final dio = Dio();
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            expect(options.path, contains('/manga'));
            expect(options.queryParameters['page'], equals(1));
            expect(options.queryParameters['site_id[]'], equals(1));
            expect(options.queryParameters['q'], equals('берсерк'));

            return handler.resolve(
              Response(
                requestOptions: options,
                statusCode: 200,
                data: {
                  'data': [
                    {
                      'id': 101,
                      'slug': 'berserk',
                      'slug_url': '101--berserk',
                      'rus_name': 'Берсерк',
                      'eng_name': 'Berserk',
                      'cover': {
                        'default': 'https://cover.cdnlibs.org/covers/berserk.jpg',
                        'thumbnail': 'https://cover.cdnlibs.org/covers/thumb_berserk.jpg',
                      },
                      'genres': [
                        {'id': 1, 'name': 'Action'},
                        {'id': 2, 'name': 'Dark Fantasy'},
                      ],
                      'rating': {'average': '9.8'},
                      'summary': 'Легендарная манга о Гатсе.',
                    },
                  ],
                },
              ),
            );
          },
        ),
      );

      final client = DioClient(dio: dio);
      final provider = MangaLibProvider(
        id: 'mangalib',
        name: 'MangaLib',
        baseUrl: 'https://api.cdnlibs.org/api',
        dioClient: client,
      );

      final posts = await provider.searchPosts(tags: ['берсерк'], page: 0);
      expect(posts, hasLength(1));
      final post = posts.first;
      expect(post.id, equals('101--berserk'));
      expect(post.providerId, equals('mangalib'));
      expect(post.fileUrl, equals('https://cover.cdnlibs.org/covers/berserk.jpg'));
      expect(post.previewUrl, equals('https://cover.cdnlibs.org/covers/berserk.jpg'));
      expect(post.score, equals(10));
      expect(post.tags, containsAll(['action', 'dark_fantasy', 'берсерк', 'berserk']));
      expect(post.tagGroups['title'], equals(['Берсерк']));
      expect(post.tagGroups['rus_title'], equals(['Берсерк']));
      expect(post.tagGroups['eng_title'], equals(['Berserk']));
      expect(post.tagGroups['description'], equals(['Легендарная манга о Гатсе.']));
    });

    test('searchPosts throws BadResponseException when request fails', () async {
      final dio = Dio();
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            return handler.reject(
              DioException(
                requestOptions: options,
                error: 'Server error',
                type: DioExceptionType.badResponse,
                response: Response(
                  requestOptions: options,
                  statusCode: 500,
                ),
              ),
            );
          },
        ),
      );

      final client = DioClient(dio: dio);
      final provider = MangaLibProvider(
        id: 'mangalib',
        name: 'MangaLib',
        baseUrl: 'https://api.cdnlibs.org/api',
        dioClient: client,
      );

      expect(
        () => provider.searchPosts(tags: ['error'], page: 0),
        throwsA(isA<BadResponseException>()),
      );
    });

    test('getPost retrieves single manga details correctly', () async {
      final dio = Dio();
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            expect(options.path, contains('/manga/101--berserk'));
            return handler.resolve(
              Response(
                requestOptions: options,
                statusCode: 200,
                data: {
                  'data': {
                    'id': 101,
                    'slug': 'berserk',
                    'slug_url': '101--berserk',
                    'rus_name': 'Берсерк',
                    'eng_name': 'Berserk',
                    'cover': {
                      'default': 'https://cover.cdnlibs.org/covers/berserk.jpg',
                    },
                    'genres': [
                      {'name': 'Horror'},
                    ],
                    'rating': {'average': '9.6'},
                    'summary': 'Подробное описание манги Берсерк.',
                  },
                },
              ),
            );
          },
        ),
      );

      final client = DioClient(dio: dio);
      final provider = MangaLibProvider(
        id: 'mangalib',
        name: 'MangaLib',
        baseUrl: 'https://api.cdnlibs.org/api',
        dioClient: client,
      );

      final post = await provider.getPost('101--berserk');
      expect(post, isNotNull);
      expect(post!.id, equals('101--berserk'));
      expect(post.tagGroups['title'], equals(['Берсерк']));
      expect(post.tagGroups['description'], equals(['Подробное описание манги Берсерк.']));
      expect(post.tags, contains('horror'));
    });

    test('fetchChapters parses chapter list correctly', () async {
      final dio = Dio();
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            expect(options.path, contains('/manga/test-manga/chapters'));
            return handler.resolve(
              Response(
                requestOptions: options,
                statusCode: 200,
                data: {
                  'data': [
                    {
                      'number': '1',
                      'volume': '1',
                      'name': 'Черный мечник',
                      'pages_count': 42,
                    },
                    {
                      'number': '2',
                      'volume': '1',
                      'name': '',
                      'pages_count': 38,
                    },
                  ],
                },
              ),
            );
          },
        ),
      );

      final client = DioClient(dio: dio);
      final provider = MangaLibProvider(
        id: 'mangalib',
        name: 'MangaLib',
        baseUrl: 'https://api.cdnlibs.org/api',
        dioClient: client,
      );

      final chapters = await provider.fetchChapters('test-manga');
      expect(chapters, hasLength(2));

      final ch1 = chapters[0];
      expect(ch1.id, equals('test-manga:1:1'));
      expect(ch1.chapterNumber, equals('1'));
      expect(ch1.volumeNumber, equals('1'));
      expect(ch1.title, equals('Черный мечник'));
      expect(ch1.pageCount, equals(42));
      expect(ch1.language, equals('ru'));

      final ch2 = chapters[1];
      expect(ch2.id, equals('test-manga:1:2'));
      expect(ch2.chapterNumber, equals('2'));
      expect(ch2.title, equals('Глава 2'));
      expect(ch2.pageCount, equals(38));
    });

    test('fetchChapterPages formats absolute and relative image URLs', () async {
      final dio = Dio();
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            expect(options.path, contains('/manga/test-manga/chapter'));
            expect(options.queryParameters['volume'], equals('1'));
            expect(options.queryParameters['number'], equals('1'));
            return handler.resolve(
              Response(
                requestOptions: options,
                statusCode: 200,
                data: {
                  'data': {
                    'pages': [
                      {
                        'url': 'https://cdn.example.com/page1.jpg',
                      },
                      {
                        'url': '//manga/test-manga/chapters/1-1/page2.jpg',
                      },
                      {
                        'url': '/manga/test-manga/chapters/1-1/page3.jpg',
                      },
                    ],
                  },
                },
              ),
            );
          },
        ),
      );

      final client = DioClient(dio: dio);
      final provider = MangaLibProvider(
        id: 'mangalib',
        name: 'MangaLib',
        baseUrl: 'https://api.cdnlibs.org/api',
        dioClient: client,
      );

      final pages = await provider.fetchChapterPages('test-manga:1:1');
      expect(pages, hasLength(3));
      expect(pages[0], equals('https://cdn.example.com/page1.jpg'));
      expect(pages[1], equals('https://img3.cdnlibs.org/manga/test-manga/chapters/1-1/page2.jpg'));
      expect(pages[2], equals('https://img3.cdnlibs.org/manga/test-manga/chapters/1-1/page3.jpg'));
    });

    test('suggestTags returns TagSuggestion list based on search', () async {
      final dio = Dio();
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            return handler.resolve(
              Response(
                requestOptions: options,
                statusCode: 200,
                data: {
                  'data': [
                    {
                      'id': 1,
                      'slug_url': 'naruto',
                      'rus_name': 'Наруто',
                      'eng_name': 'Naruto',
                      'rating': {'average': '9.0'},
                    },
                  ],
                },
              ),
            );
          },
        ),
      );

      final client = DioClient(dio: dio);
      final provider = MangaLibProvider(
        id: 'mangalib',
        name: 'MangaLib',
        baseUrl: 'https://api.cdnlibs.org/api',
        dioClient: client,
      );

      final suggestions = await provider.suggestTags('naruto');
      expect(suggestions, hasLength(1));
      expect(suggestions.first.name, equals('Наруто'));
      expect(suggestions.first.category, equals(TagCategory.copyright));
      expect(suggestions.first.providerId, equals('mangalib'));

      final empty = await provider.suggestTags('  ');
      expect(empty, isEmpty);
    });

    test('checkHealth returns online on 200 and offline on network failure', () async {
      bool fail = false;
      final dio = Dio();
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            if (fail) {
              return handler.reject(
                DioException(
                  requestOptions: options,
                  error: 'Connection timed out',
                  type: DioExceptionType.connectionTimeout,
                ),
              );
            }
            return handler.resolve(
              Response(
                requestOptions: options,
                statusCode: 200,
                data: {'ok': true},
              ),
            );
          },
        ),
      );

      final client = DioClient(dio: dio);
      final provider = MangaLibProvider(
        id: 'mangalib',
        name: 'MangaLib',
        baseUrl: 'https://api.cdnlibs.org/api',
        dioClient: client,
      );

      final healthOnline = await provider.checkHealth();
      expect(healthOnline.status, equals(ProviderStatus.online));

      fail = true;
      final healthOffline = await provider.checkHealth();
      expect(healthOffline.status, equals(ProviderStatus.offline));
      expect(healthOffline.errorMessage, isNotNull);
    });
  });
}
