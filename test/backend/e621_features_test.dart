import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gel_rule_app/backend/providers/e621_provider.dart';
import 'package:gel_rule_app/core/http/dio_client.dart';

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

    test('fetchAccountBlacklist fetches and splits newline-separated tags', () async {
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
  });
}
