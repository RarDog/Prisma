import 'package:flutter_test/flutter_test.dart';
import 'package:prisma_app/core/models/post.dart';
import 'package:prisma_app/sources/mappers/pixiv_mapper.dart';

void main() {
  group('Pixiv Ugoira support', () {
    test('Post.isUgoira detects ugoira fileType and media_type tag group', () {
      final post1 = Post(
        id: '123',
        providerId: 'pixiv',
        providerName: 'Pixiv',
        previewUrl: 'https://example.com/p.jpg',
        sampleUrl: 'https://example.com/s.jpg',
        fileUrl: 'https://example.com/f.jpg',
        tags: const ['animated'],
        rating: 's',
        width: 100,
        height: 100,
        source: '',
        createdAt: DateTime.now(),
        fileType: 'ugoira',
        score: 0,
      );
      expect(post1.isUgoira, isTrue);

      final post2 = Post(
        id: '124',
        providerId: 'pixiv',
        providerName: 'Pixiv',
        previewUrl: 'https://example.com/p.jpg',
        sampleUrl: 'https://example.com/s.jpg',
        fileUrl: 'https://example.com/f.jpg',
        tags: const ['animated'],
        rating: 's',
        width: 100,
        height: 100,
        source: '',
        createdAt: DateTime.now(),
        fileType: 'jpg',
        score: 0,
        tagGroups: const {
          'media_type': ['ugoira'],
        },
      );
      expect(post2.isUgoira, isTrue);

      final normalPost = Post(
        id: '125',
        providerId: 'pixiv',
        providerName: 'Pixiv',
        previewUrl: 'https://example.com/p.jpg',
        sampleUrl: 'https://example.com/s.jpg',
        fileUrl: 'https://example.com/f.jpg',
        tags: const ['art'],
        rating: 's',
        width: 100,
        height: 100,
        source: '',
        createdAt: DateTime.now(),
        fileType: 'jpg',
        score: 0,
      );
      expect(normalPost.isUgoira, isFalse);
    });

    test('PixivMapper parses search response with illustType == 2 as ugoira', () {
      final jsonResponse = {
        'error': false,
        'body': {
          'illustManga': {
            'data': [
              {
                'id': '99901',
                'title': 'Animated loop',
                'illustType': 2,
                'url': 'https://i.pximg.net/c/250x250_80_a2/img-master/img/2021/01/01/00/00/00/99901_p0_square1200.jpg',
                'tags': ['original', 'ugoira'],
                'userName': 'ArtistOne',
                'pageCount': 1,
                'width': 1920,
                'height': 1080,
              },
              {
                'id': '99902',
                'title': 'Static illust',
                'illustType': 0,
                'url': 'https://i.pximg.net/c/250x250_80_a2/img-master/img/2021/01/01/00/00/00/99902_p0_square1200.jpg',
                'tags': ['original'],
                'userName': 'ArtistTwo',
                'pageCount': 1,
                'width': 1200,
                'height': 800,
              }
            ]
          }
        }
      };

      final posts = PixivMapper.postsFromSearchResponse(
        jsonResponse,
        providerId: 'pixiv',
        providerName: 'Pixiv',
      );

      expect(posts.length, equals(2));
      expect(posts[0].id, equals('99901'));
      expect(posts[0].fileType, equals('ugoira'));
      expect(posts[0].isUgoira, isTrue);
      expect(posts[0].tagGroups['media_type'], contains('ugoira'));

      expect(posts[1].id, equals('99902'));
      expect(posts[1].fileType, equals('jpg'));
      expect(posts[1].isUgoira, isFalse);
    });

    test('PixivMapper parses ugoiraMetaFromResponse correctly', () {
      final jsonResponse = {
        'error': false,
        'message': '',
        'body': {
          'src': 'https://i.pximg.net/img-zip-ugoira/img/2021/01/01/00/00/00/99901_ugoira1920x1080.zip',
          'originalSrc': 'https://i.pximg.net/img-zip-ugoira/img/2021/01/01/00/00/00/99901_ugoira0.zip',
          'mime_type': 'image/vnd.pixiv.ugoira+zip',
          'frames': [
            {'file': '000000.jpg', 'delay': 125},
            {'file': '000001.jpg', 'delay': 125},
            {'file': '000002.jpg', 'delay': 250},
          ]
        }
      };

      final meta = PixivMapper.ugoiraMetaFromResponse(jsonResponse);
      expect(meta, isNotNull);
      expect(meta!.zipUrl, equals('https://i.pximg.net/img-zip-ugoira/img/2021/01/01/00/00/00/99901_ugoira1920x1080.zip'));
      expect(meta.originalZipUrl, equals('https://i.pximg.net/img-zip-ugoira/img/2021/01/01/00/00/00/99901_ugoira0.zip'));
      expect(meta.mimeType, equals('image/vnd.pixiv.ugoira+zip'));
      expect(meta.frames.length, equals(3));
      expect(meta.frames[0].file, equals('000000.jpg'));
      expect(meta.frames[0].delayMs, equals(125));
      expect(meta.frames[2].delayMs, equals(250));
      expect(meta.totalDurationMs, equals(500));
    });
  });
}
