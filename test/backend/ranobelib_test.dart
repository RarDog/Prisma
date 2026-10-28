import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gel_rule_app/core/errors/app_exception.dart';
import 'package:gel_rule_app/core/http/dio_client.dart';
import 'package:gel_rule_app/sources/manga/ranobelib_provider.dart';

/// RanobeLib parsing is exercised against a stubbed HTTP adapter rather than
/// the live API. The upstream catalog is edited by users all the time — a
/// removed novel or an empty chapter list used to fail this suite for reasons
/// unrelated to the code under test. Live reachability is covered separately
/// by `ranobelib_live_test.dart`, which is tagged `network`.
RanobeLibProvider _providerWith(
  void Function(RequestOptions options, RequestInterceptorHandler handler)
      onRequest,
) {
  final dio = Dio();
  dio.interceptors.add(InterceptorsWrapper(onRequest: onRequest));
  return RanobeLibProvider(
    id: 'ranobelib',
    name: 'RanobeLib',
    baseUrl: 'https://api.cdnlibs.org/api',
    dioClient: DioClient(dio: dio),
  );
}

void main() {
  group('RanobeLibProvider.fetchChapters', () {
    test('parses chapter number, volume, title and branch id', () async {
      final provider = _providerWith((options, handler) {
        expect(options.path, endsWith('/manga/novel-1/chapters'));
        handler.resolve(
          Response<dynamic>(
            requestOptions: options,
            statusCode: 200,
            data: {
              'data': [
                {
                  'number': '1',
                  'volume': '2',
                  'name': 'Пролог',
                  'branches': [
                    {'branch_id': 77},
                  ],
                },
                {
                  'number': '3',
                  'volume': '2',
                  'name': '',
                  'branches': const [],
                },
              ],
            },
          ),
        );
      });

      final chapters = await provider.fetchChapters('novel-1');

      expect(chapters, hasLength(2));
      expect(chapters[0].id, 'novel-1:2:1:77');
      expect(chapters[0].chapterNumber, '1');
      expect(chapters[0].volumeNumber, '2');
      expect(chapters[0].title, 'Пролог');
      expect(chapters[0].language, 'ru');
      // No branch: the id keeps the three-part shape and the title falls back.
      expect(chapters[1].id, 'novel-1:2:3');
      expect(chapters[1].title, 'Глава 3');
    });

    test('accepts a bare list payload and skips non-map entries', () async {
      final provider = _providerWith((options, handler) {
        handler.resolve(
          Response<dynamic>(
            requestOptions: options,
            statusCode: 200,
            data: [
              'garbage',
              {'number': '5', 'volume': '1', 'name': 'Финал'},
            ],
          ),
        );
      });

      final chapters = await provider.fetchChapters('novel-2');

      expect(chapters, hasLength(1));
      expect(chapters.single.id, 'novel-2:1:5');
      expect(chapters.single.title, 'Финал');
    });

    test('returns an empty list instead of throwing on transport failure',
        () async {
      final provider = _providerWith((options, handler) {
        // 404 is deterministic: the retry interceptor stays out of the way.
        handler.reject(
          DioException(
            requestOptions: options,
            type: DioExceptionType.badResponse,
            response: Response<dynamic>(
              requestOptions: options,
              statusCode: 404,
            ),
          ),
        );
      });

      expect(await provider.fetchChapters('novel-3'), isEmpty);
    });
  });

  group('RanobeLibProvider.fetchChapterContent', () {
    test('renders a ProseMirror document into plain text', () async {
      final provider = _providerWith((options, handler) {
        expect(options.path, endsWith('/manga/novel-1/chapter'));
        expect(options.queryParameters['volume'], '2');
        expect(options.queryParameters['number'], '1');
        handler.resolve(
          Response<dynamic>(
            requestOptions: options,
            statusCode: 200,
            data: {
              'data': {
                'content': {
                  'type': 'doc',
                  'content': [
                    {
                      'type': 'paragraph',
                      'content': [
                        {'type': 'text', 'text': 'Первый абзац.'},
                      ],
                    },
                    {
                      'type': 'paragraph',
                      'content': [
                        {'type': 'text', 'text': 'Второй абзац.'},
                      ],
                    },
                  ],
                },
              },
            },
          ),
        );
      });

      final content = await provider.fetchChapterContent('novel-1:2:1');

      expect(content, contains('Первый абзац.'));
      expect(content, contains('Второй абзац.'));
      // Paragraph boundaries become blank lines, never a triple newline.
      expect(content, isNot(contains('\n\n\n')));
    });

    test('converts legacy HTML markup and inline images', () async {
      final provider = _providerWith((options, handler) {
        handler.resolve(
          Response<dynamic>(
            requestOptions: options,
            statusCode: 200,
            data: {
              'data': {
                'content':
                    '<p>Привет&nbsp;мир &laquo;тест&raquo;</p><br>'
                        '<img src="https://img.example/a.png">',
              },
            },
          ),
        );
      });

      final content = await provider.fetchChapterContent('novel-1:1:1');

      expect(content, contains('Привет мир «тест»'));
      expect(content, contains('![illustration](https://img.example/a.png)'));
      expect(content, isNot(contains('<p>')));
      expect(content, isNot(contains('&nbsp;')));
    });

    test('retries without branch_id when the branch request fails', () async {
      var calls = 0;
      final provider = _providerWith((options, handler) {
        calls++;
        if (options.queryParameters.containsKey('branch_id')) {
          // 404 is deterministic, so the retry interceptor does not loop.
          handler.reject(
            DioException(
              requestOptions: options,
              type: DioExceptionType.badResponse,
              response: Response<dynamic>(
                requestOptions: options,
                statusCode: 404,
              ),
            ),
          );
          return;
        }
        expect(options.queryParameters.containsKey('branch_id'), isFalse);
        handler.resolve(
          Response<dynamic>(
            requestOptions: options,
            statusCode: 200,
            data: {
              'data': {'content': 'Текст без ветки'},
            },
          ),
        );
      });

      final content =
          await provider.fetchChapterContent('novel-1:1:1:77');

      expect(calls, 2);
      expect(content, 'Текст без ветки');
    });

    test('falls back to attachment illustrations for image-only chapters',
        () async {
      final provider = _providerWith((options, handler) {
        handler.resolve(
          Response<dynamic>(
            requestOptions: options,
            statusCode: 200,
            data: {
              'data': {
                'content': '',
                'attachments': [
                  {'url': '/uploads/illustration/1.png'},
                  {'url': 'https://cdn.example/2.png'},
                ],
              },
            },
          ),
        );
      });

      final content = await provider.fetchChapterContent('novel-1:1:1');

      expect(
        content,
        contains('![illustration](https://ranobelib.me/uploads/illustration/1.png)'),
      );
      expect(content, contains('![illustration](https://cdn.example/2.png)'));
    });

    test('returns an empty string when the payload has no text', () async {
      final provider = _providerWith((options, handler) {
        handler.resolve(
          Response<dynamic>(
            requestOptions: options,
            statusCode: 200,
            data: {'data': <String, dynamic>{}},
          ),
        );
      });

      expect(await provider.fetchChapterContent('novel-1:1:1'), '');
    });
  });

  group('RanobeLibProvider.searchPosts', () {
    test('maps catalog items into posts with covers, genres and titles',
        () async {
      final provider = _providerWith((options, handler) {
        expect(options.path, endsWith('/manga'));
        expect(options.queryParameters['site_id[]'], 3);
        expect(options.queryParameters['page'], 2);
        expect(options.queryParameters['limit'], 24);
        expect(options.queryParameters['q'], 'рыцарь');
        handler.resolve(
          Response<dynamic>(
            requestOptions: options,
            statusCode: 200,
            data: {
              'data': [
                {
                  'slug': 'knight',
                  'slug_url': '42--knight',
                  'rus_name': 'Рыцарь',
                  'eng_name': 'The Knight',
                  'cover': {'default': 'https://cover.example/knight.jpg'},
                  'genres': [
                    {'name': 'Dark Fantasy'},
                  ],
                  'rating': {'average': '8.6'},
                  'summary': 'Краткое описание.',
                },
              ],
            },
          ),
        );
      });

      final posts = await provider.searchPosts(tags: ['рыцарь'], page: 1);

      expect(posts, hasLength(1));
      final post = posts.single;
      expect(post.id, '42--knight');
      expect(post.providerId, 'ranobelib');
      expect(post.fileType, 'txt');
      expect(post.fileUrl, 'https://cover.example/knight.jpg');
      expect(post.score, 9);
      expect(post.tags, containsAll(['ranobe', 'novel', 'dark_fantasy']));
      expect(post.tagGroups['title'], ['Рыцарь']);
      expect(post.tagGroups['description'], ['Краткое описание.']);
      expect(post.source, 'https://ranobelib.me/ru/42--knight');
    });

    test('wraps a bad response into BadResponseException', () async {
      final provider = _providerWith((options, handler) {
        handler.reject(
          DioException(
            requestOptions: options,
            type: DioExceptionType.badResponse,
            response: Response<dynamic>(
              requestOptions: options,
              statusCode: 400,
              data: {'message': 'bad request'},
            ),
          ),
        );
      });

      await expectLater(
        provider.searchPosts(tags: const [], page: 0),
        throwsA(isA<BadResponseException>()),
      );
    });
  });
}
