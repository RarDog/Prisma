import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gel_rule_app/sources/booru/e621_provider.dart';
import 'package:gel_rule_app/sources/mappers/e621_mapper.dart';
import 'package:gel_rule_app/core/http/dio_client.dart';
import 'package:gel_rule_app/core/models/tag_suggestion.dart';

class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.handler);
  final Future<ResponseBody> Function(RequestOptions options) handler;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<dynamic>? requestStream,
    Future<void>? cancelFuture,
  ) {
    return handler(options);
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  group('E621Provider Features Tests', () {
    late Dio dio;
    late DioClient dioClient;

    setUp(() {
      dio = Dio();
      dioClient = DioClient(dio: dio);
    });

    test('getPopularPosts parses posts from /popular.json', () async {
      dio.httpClientAdapter = _FakeAdapter((options) async {
        expect(options.path, equals('/popular.json'));
        expect(options.queryParameters['scale'], equals('day'));

        final responseJson = {
          'posts': [
            {
              'id': 9999,
              'file': {
                'url': 'https://static1.e621.net/data/sample.jpg',
                'ext': 'jpg',
                'width': 1200,
                'height': 900,
              },
              'preview': {
                'url': 'https://static1.e621.net/data/preview.jpg',
                'width': 300,
                'height': 200,
              },
              'sample': {
                'url': 'https://static1.e621.net/data/sample.jpg',
                'has': true,
              },
              'tags': {
                'general': ['fur', 'tail'],
                'artist': ['cool_artist'],
              },
              'score': {'total': 150},
              'rating': 's',
              'created_at': '2026-09-10T12:00:00.000Z',
            }
          ]
        };

        return ResponseBody.fromString(
          jsonEncode(responseJson),
          200,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        );
      });

      final provider = E621Provider(
        id: 'e621',
        name: 'e621',
        baseUrl: 'https://e621.net',
        dioClient: dioClient,
        queryParameters: const {
          'login': 'testuser',
          'api_key': 'testkey123',
        },
      );

      final posts = await provider.getPopularPosts(scale: 'day');

      expect(posts.length, equals(1));
      expect(posts.first.id, equals('9999'));
      expect(posts.first.score, equals(150));
      expect(posts.first.providerId, equals('e621'));
      expect(posts.first.tags, contains('cool_artist'));
    });

    test('fetchAccountBlacklist fetches and splits newline-separated tags',
        () async {
      dio.httpClientAdapter = _FakeAdapter((options) async {
        expect(options.path, equals('/users.json'));
        expect(options.queryParameters['search[name]'], equals('testuser'));

        final responseJson = [
          {
            'id': 42,
            'name': 'testuser',
            'blacklisted_tags': 'scat\nwatersports\nrating:e gore\n\n',
          }
        ];

        return ResponseBody.fromString(
          jsonEncode(responseJson),
          200,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        );
      });

      final provider = E621Provider(
        id: 'e621',
        name: 'e621',
        baseUrl: 'https://e621.net',
        dioClient: dioClient,
        queryParameters: const {
          'login': 'testuser',
          'api_key': 'testkey123',
        },
      );

      final tags = await provider.fetchAccountBlacklist();

      expect(tags, equals(['scat', 'watersports', 'rating:e gore']));
    });

    test('createComment posts to /comments.json with payload', () async {
      dio.httpClientAdapter = _FakeAdapter((options) async {
        expect(options.path, equals('/comments.json'));
        expect(options.method, equals('POST'));

        final data = options.data as Map<String, dynamic>;
        expect(data['comment']['post_id'], equals(12345));
        expect(data['comment']['body'], equals('Awesome artwork!'));

        final responseJson = {
          'id': 555,
          'post_id': 12345,
          'creator_name': 'testuser',
          'body': 'Awesome artwork!',
          'created_at': '2026-09-11T10:00:00.000Z',
        };

        return ResponseBody.fromString(
          jsonEncode(responseJson),
          201,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        );
      });

      final provider = E621Provider(
        id: 'e621',
        name: 'e621',
        baseUrl: 'https://e621.net',
        dioClient: dioClient,
        queryParameters: const {
          'login': 'testuser',
          'api_key': 'testkey123',
        },
      );

      final comment = await provider.createComment(
        postId: '12345',
        body: 'Awesome artwork!',
      );

      expect(comment, isNotNull);
      expect(comment!.id, equals('555'));
      expect(comment.authorName, equals('testuser'));
      expect(comment.body, equals('Awesome artwork!'));
    });

    test('getNotes fetches and parses notes from /notes.json', () async {
      dio.httpClientAdapter = _FakeAdapter((options) async {
        expect(options.path, equals('/notes.json'));
        expect(options.queryParameters['search[post_id]'], equals('12345'));

        final responseJson = [
          {
            'id': 101,
            'post_id': 12345,
            'x': 50,
            'y': 60,
            'width': 200,
            'height': 80,
            'body': '[b]Hello[/b] world &amp; comic',
            'creator_name': 'translator_cat',
            'is_active': true,
          },
          {
            'id': 102,
            'post_id': 12345,
            'x': 10,
            'y': 20,
            'width': 100,
            'height': 50,
            'body': 'Inactive note',
            'is_active': false,
          }
        ];

        return ResponseBody.fromString(
          jsonEncode(responseJson),
          200,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        );
      });

      final provider = E621Provider(
        id: 'e621',
        name: 'e621',
        baseUrl: 'https://e621.net',
        dioClient: dioClient,
      );

      final notes = await provider.getNotes('12345');
      expect(notes.length, equals(1));
      expect(notes[0].id, equals('101'));
      expect(notes[0].postId, equals('12345'));
      expect(notes[0].x, equals(50));
      expect(notes[0].y, equals(60));
      expect(notes[0].width, equals(200));
      expect(notes[0].height, equals(80));
      expect(notes[0].body, equals('[b]Hello[/b] world &amp; comic'));
      expect(notes[0].authorName, equals('translator_cat'));
      expect(notes[0].isActive, isTrue);
    });

    test('categorizeTags maps e621 categories to tag groups', () async {
      E621Mapper.tagCategoryCache.clear();
      dio.httpClientAdapter = _FakeAdapter((options) async {
        expect(options.path, equals('/tags.json'));
        final names = options.queryParameters['search[name]'] as String;
        expect(names, contains('jacky-arts'));

        final responseJson = [
          {'name': 'jacky-arts', 'category': 1},
          {'name': 'cate_meowdy', 'category': 4},
          {'name': 'fortnite', 'category': 3},
          {'name': 'feline', 'category': 5},
          {'name': 'hi_res', 'category': 7},
          {'name': 'lore_tag', 'category': 8},
          {'name': 'solo', 'category': 0},
        ];

        return ResponseBody.fromString(
          jsonEncode(responseJson),
          200,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        );
      });

      final provider = E621Provider(
        id: 'e621',
        name: 'e621',
        baseUrl: 'https://e621.net',
        dioClient: dioClient,
      );

      final groups = await provider.categorizeTags([
        'jacky-arts',
        'cate_meowdy',
        'fortnite',
        'feline',
        'hi_res',
        'lore_tag',
        'solo',
      ]);

      expect(groups['artist'], equals(['jacky-arts']));
      expect(groups['character'], equals(['cate_meowdy']));
      expect(groups['copyright'], equals(['fortnite']));
      expect(groups['species'], equals(['feline']));
      expect(groups['meta'], equals(['hi_res']));
      expect(groups['lore'], equals(['lore_tag']));
      expect(groups['general'], equals(['solo']));
    });

    test('getPost categorizes flat tags list from e621', () async {
      E621Mapper.tagCategoryCache.clear();
      dio.httpClientAdapter = _FakeAdapter((options) async {
        if (options.path == '/posts/6875208.json') {
          final responseJson = {
            'post': {
              'id': 6875208,
              'files': {
                'original': {
                  'width': 1000,
                  'height': 800,
                  'url': 'https://static1.e621.net/data/orig.jpg',
                },
                'preview': {
                  'url': 'https://static1.e621.net/data/preview.jpg',
                },
                'sample': {
                  'url': 'https://static1.e621.net/data/sample.jpg',
                },
                'meta': {'ext': 'jpg'},
              },
              'rating': 'q',
              'stats': {'score': {'total': 5}},
              'tags': ['jacky-arts', 'canine', 'anthro'],
            }
          };
          return ResponseBody.fromString(
            jsonEncode(responseJson),
            200,
            headers: {
              Headers.contentTypeHeader: [Headers.jsonContentType],
            },
          );
        } else if (options.path == '/tags.json') {
          final responseJson = [
            {'name': 'jacky-arts', 'category': 1},
            {'name': 'canine', 'category': 5},
            {'name': 'anthro', 'category': 0},
          ];
          return ResponseBody.fromString(
            jsonEncode(responseJson),
            200,
            headers: {
              Headers.contentTypeHeader: [Headers.jsonContentType],
            },
          );
        }
        throw UnimplementedError(options.path);
      });

      final provider = E621Provider(
        id: 'e621',
        name: 'e621',
        baseUrl: 'https://e621.net',
        dioClient: dioClient,
      );

      final post = await provider.getPost('6875208');
      expect(post, isNotNull);
      expect(post!.tagGroups['artist'], equals(['jacky-arts']));
      expect(post.tagGroups['species'], equals(['canine']));
      expect(post.tagGroups['general'], equals(['anthro']));
      expect(post.hasCategorizedTagGroups, isTrue);
    });

    test('suggestTags correctly maps e621 species and meta categories', () async {
      dio.httpClientAdapter = _FakeAdapter((options) async {
        expect(options.path, equals('/tags.json'));
        final responseJson = [
          {'name': 'canine', 'category': 5, 'post_count': 100},
          {'name': 'hi_res', 'category': 7, 'post_count': 200},
          {'name': 'jacky-arts', 'category': 1, 'post_count': 50},
        ];
        return ResponseBody.fromString(
          jsonEncode(responseJson),
          200,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
          },
        );
      });

      final provider = E621Provider(
        id: 'e621',
        name: 'e621',
        baseUrl: 'https://e621.net',
        dioClient: dioClient,
      );

      final suggestions = await provider.suggestTags('can');
      expect(suggestions.length, equals(3));
      expect(suggestions[0].category, equals(TagCategory.species));
      expect(suggestions[1].category, equals(TagCategory.meta));
      expect(suggestions[2].category, equals(TagCategory.artist));
    });
  });
}
