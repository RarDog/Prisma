import 'package:flutter_test/flutter_test.dart';
import 'package:gel_rule_app/features/post/presentation/widgets/post_media_viewer.dart';
import 'package:gel_rule_app/features/providers/models/content_provider_config.dart';
import 'package:gel_rule_app/core/models/post.dart';
import 'package:gel_rule_app/sources/interfaces/content_provider.dart';
import 'package:gel_rule_app/sources/provider_factory.dart';
import 'package:gel_rule_app/sources/booru/pixiv_provider.dart';
import 'package:gel_rule_app/sources/mappers/pixiv_mapper.dart';
import 'package:gel_rule_app/core/http/dio_client.dart';

void main() {
  group('PixivProvider Tests', () {
    test('ProviderFactory creates PixivProvider from config', () {
      final factory = ProviderFactory();
      final config = ContentProviderConfig(
        id: 'pixiv',
        name: 'Pixiv',
        baseUrl: 'https://www.pixiv.net',
        apiType: 'pixiv',
        enabled: true,
        priority: 7,
        timeoutSeconds: 25,
        customHeaders: const {},
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      );

      final provider = factory.create(config);
      expect(provider, isA<PixivProvider>());
      expect(provider.id, equals('pixiv'));
      expect(provider.name, equals('Pixiv'));
      expect(provider.baseUrl, equals('https://www.pixiv.net'));
      expect(provider, isA<TagSuggestionProvider>());
      expect(provider, isA<MediaHeadersProvider>());
      expect(provider, isA<PostPageProvider>());
    });

    test('PixivMapper.toMasterUrl transforms thumbnails to master image URLs',
        () {
      const thumb =
          'https://i.pximg.net/c/250x250_80_a2/img-master/img/2026/09/22/23/23/46/149987432_p0_square1200.jpg';
      final master = PixivMapper.toMasterUrl(thumb);
      expect(
        master,
        equals(
          'https://i.pximg.net/img-master/img/2026/09/22/23/23/46/149987432_p0_master1200.jpg',
        ),
      );

      const rankingThumb =
          'https://i.pximg.net/c/480x960/img-master/img/2026/09/20/21/57/09/149899308_p0_master1200.jpg';
      final rankingMaster = PixivMapper.toMasterUrl(rankingThumb);
      expect(
        rankingMaster,
        equals(
          'https://i.pximg.net/img-master/img/2026/09/20/21/57/09/149899308_p0_master1200.jpg',
        ),
      );
    });

    test('PixivMapper.postsFromRankingResponse parses ranking JSON', () {
      final json = {
        'contents': [
          {
            'illust_id': 149899308,
            'title': 'Test Artwork',
            'tags': ['Original', 'Manga'],
            'url':
                'https://i.pximg.net/c/480x960/img-master/img/2026/09/20/21/57/09/149899308_p0_master1200.jpg',
            'illust_type': '1',
            'illust_page_count': '3',
            'user_name': 'TestArtist',
            'width': 874,
            'height': 1240,
            'rating_count': 1886,
            'view_count': 49910,
            'illust_upload_timestamp': 1789909029,
            'illust_content_type': {'sexual': 0},
          }
        ]
      };

      final posts = PixivMapper.postsFromRankingResponse(
        json,
        providerId: 'pixiv',
        providerName: 'Pixiv',
      );

      expect(posts.length, equals(1));
      final post = posts.first;
      expect(post.id, equals('149899308'));
      expect(post.providerId, equals('pixiv'));
      expect(post.rating, equals('s'));
      expect(post.tags, contains('Original'));
      expect(post.tagGroups['artist'], equals(['TestArtist']));
      expect(post.tagGroups['copyright'], equals(['Test Artwork']));
      expect(post.pageCount, equals(3));
      expect(post.isMultiPage, isTrue);
      expect(post.fileUrl, contains('/img-master/'));
      expect(post.fileUrl, isNot(contains('/c/')));
    });

    test('PixivMapper.postsFromSearchResponse parses search JSON', () {
      final json = {
        'body': {
          'illustManga': {
            'data': [
              {
                'id': '149987432',
                'title': 'Hatsune Miku Art',
                'url':
                    'https://i.pximg.net/c/250x250_80_a2/img-master/img/2026/09/22/23/23/46/149987432_p0_square1200.jpg',
                'tags': ['HatsuneMiku', 'VOCALOID'],
                'userName': '車輌',
                'width': 1024,
                'height': 1536,
                'pageCount': 1,
                'bookmarkCount': 500,
                'likeCount': 1000,
                'xRestrict': 0,
                'createDate': '2026-09-22T23:23:46+09:00',
              }
            ]
          }
        }
      };

      final posts = PixivMapper.postsFromSearchResponse(
        json,
        providerId: 'pixiv',
        providerName: 'Pixiv',
      );

      expect(posts.length, equals(1));
      final post = posts.first;
      expect(post.id, equals('149987432'));
      expect(post.tags, contains('HatsuneMiku'));
      expect(post.score, equals(1000));
      expect(post.rating, equals('s'));
      expect(post.tagGroups['artist'], equals(['車輌']));
    });

    test('PixivMapper.postFromIllustResponse parses detail JSON', () {
      final json = {
        'body': {
          'id': '123456',
          'title': 'Detailed Illust',
          'description': 'A nice drawing',
          'urls': {
            'regular':
                'https://i.pximg.net/img-master/img/2026/01/01/123456_p0_master1200.jpg',
            'original':
                'https://i.pximg.net/img-original/img/2026/01/01/123456_p0.png',
            'small':
                'https://i.pximg.net/c/540x540_70/img-master/img/2026/01/01/123456_p0_master1200.jpg',
          },
          'tags': {
            'tags': [
              {
                'tag': '初音ミク',
                'translation': {'en': 'Hatsune Miku'}
              }
            ]
          },
          'userName': 'MikuArtist',
          'width': 2000,
          'height': 3000,
          'pageCount': 1,
          'xRestrict': 1,
          'likeCount': 2500,
          'createDate': '2026-01-01T00:00:00+00:00',
        }
      };

      final post = PixivMapper.postFromIllustResponse(
        json,
        providerId: 'pixiv',
        providerName: 'Pixiv',
      );

      expect(post, isNotNull);
      expect(post!.id, equals('123456'));
      expect(post.fileUrl, endsWith('.png'));
      expect(post.rating, equals('e'));
      expect(post.tags, contains('初音ミク'));
      expect(post.tags, contains('Hatsune Miku'));
      expect(post.score, equals(2500));
    });

    test('PixivProvider URLs and headers contain Referer', () {
      final client = DioClient(baseUrl: 'https://www.pixiv.net');
      final provider = PixivProvider(
        id: 'pixiv',
        name: 'Pixiv',
        baseUrl: 'https://www.pixiv.net',
        dioClient: client,
      );

      final dummyPost = Post(
        id: '149899308',
        providerId: 'pixiv',
        providerName: 'Pixiv',
        previewUrl: 'https://i.pximg.net/c/480x960/img-master/test.jpg',
        sampleUrl: 'https://i.pximg.net/img-master/test.jpg',
        fileUrl: 'https://i.pximg.net/img-original/test.jpg',
        tags: const ['original'],
        rating: 's',
        width: 1200,
        height: 800,
        createdAt: DateTime.now(),
        fileType: 'jpg',
        score: 100,
      );

      expect(
        provider.postPageUrl(dummyPost),
        equals('https://www.pixiv.net/artworks/149899308'),
      );
      final headers = provider.mediaHeaders(dummyPost);
      expect(headers['Referer'], equals('https://www.pixiv.net/'));

      final globalHeaders = getPostMediaHeaders(dummyPost);
      expect(globalHeaders['Referer'], equals('https://www.pixiv.net/'));
    });

    test('PixivProvider implements CommentProvider interface', () {
      final client = DioClient(baseUrl: 'https://www.pixiv.net');
      final provider = PixivProvider(
        id: 'pixiv',
        name: 'Pixiv',
        baseUrl: 'https://www.pixiv.net',
        dioClient: client,
      );
      // Verify it implements CommentProvider
      expect(provider, isA<CommentProvider>());
      // Without auth, isAuthenticated should be false
      expect(provider.isAuthenticated, isFalse);
    });

    test('PixivProvider isAuthenticated true when PHPSESSID provided', () {
      final client = DioClient(baseUrl: 'https://www.pixiv.net');
      final providerNoAuth = PixivProvider(
        id: 'pixiv',
        name: 'Pixiv',
        baseUrl: 'https://www.pixiv.net',
        dioClient: client,
      );
      expect(providerNoAuth.isAuthenticated, isFalse);

      final providerAuth = PixivProvider(
        id: 'pixiv',
        name: 'Pixiv',
        baseUrl: 'https://www.pixiv.net',
        dioClient: client,
        phpsessid: 'abc123sessionid',
      );
      expect(providerAuth.isAuthenticated, isTrue);

      // Empty phpsessid should also be unauthenticated
      final providerEmptyAuth = PixivProvider(
        id: 'pixiv',
        name: 'Pixiv',
        baseUrl: 'https://www.pixiv.net',
        dioClient: client,
        phpsessid: '',
      );
      expect(providerEmptyAuth.isAuthenticated, isFalse);
    });

    test('ProviderFactory passes PHPSESSID to PixivProvider', () {
      final factory = ProviderFactory();
      final config = ContentProviderConfig(
        id: 'pixiv',
        name: 'Pixiv',
        baseUrl: 'https://www.pixiv.net',
        apiType: 'pixiv',
        enabled: true,
        priority: 7,
        timeoutSeconds: 25,
        customHeaders: const {'phpsessid': 'testsessiontoken123'},
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      );
      final provider = factory.create(config) as PixivProvider;
      expect(provider.isAuthenticated, isTrue);
    });

    test('PixivProvider implements MultiPageProvider', () {
      final client = DioClient(baseUrl: 'https://www.pixiv.net');
      final provider = PixivProvider(
        id: 'pixiv',
        name: 'Pixiv',
        baseUrl: 'https://www.pixiv.net',
        dioClient: client,
      );
      expect(provider, isA<MultiPageProvider>());
    });

    test('PixivMapper.postFromPageResponse builds child posts with original quality', () {
      final parentPost = Post(
        id: '999888',
        providerId: 'pixiv',
        providerName: 'Pixiv',
        previewUrl: 'https://i.pximg.net/thumb.jpg',
        sampleUrl: 'https://i.pximg.net/master.jpg',
        fileUrl: 'https://i.pximg.net/master.jpg',
        tags: const ['scenery', 'night'],
        rating: 's',
        width: 1920,
        height: 1080,
        createdAt: DateTime(2026, 1, 1),
        fileType: 'jpg',
        score: 50,
        tagGroups: {
          'general': ['scenery', 'night'],
          'artist': ['SkyPainter'],
          'page_count': ['3'],
          'children': ['999888_p1', '999888_p2'],
        },
      );

      final pageData0 = {
        'urls': {
          'original': 'https://i.pximg.net/img-original/img/2026/999888_p0.png',
          'regular': 'https://i.pximg.net/img-master/img/2026/999888_p0_master1200.jpg',
          'small': 'https://i.pximg.net/img-master/img/2026/999888_p0_small.jpg',
        },
        'width': 3840,
        'height': 2160,
      };

      final page0 = PixivMapper.postFromPageResponse(
        pageData: pageData0,
        parentPost: parentPost,
        pageIndex: 0,
      );

      expect(page0, isNotNull);
      expect(page0!.id, equals('999888'));
      expect(page0.fileUrl, equals('https://i.pximg.net/img-original/img/2026/999888_p0.png'));
      expect(page0.fileType, equals('png'));
      expect(page0.tagGroups['page_index'], equals(['0']));

      final pageData1 = {
        'urls': {
          'original': 'https://i.pximg.net/img-original/img/2026/999888_p1.jpg',
          'regular': 'https://i.pximg.net/img-master/img/2026/999888_p1_master1200.jpg',
        },
        'width': 1920,
        'height': 1080,
      };

      final page1 = PixivMapper.postFromPageResponse(
        pageData: pageData1,
        parentPost: parentPost,
        pageIndex: 1,
      );

      expect(page1, isNotNull);
      expect(page1!.id, equals('999888_p1'));
      expect(page1.fileUrl, equals('https://i.pximg.net/img-original/img/2026/999888_p1.jpg'));
      expect(page1.tagGroups['page_index'], equals(['1']));
    });

    test('PixivMapper parses pageCount with fallback keys (page_count, illust_page_count)', () {
      final searchJson = {
        'body': {
          'illustManga': {
            'data': [
              {
                'id': '111222',
                'title': 'Multi-page artwork',
                'url': 'https://i.pximg.net/thumb.jpg',
                'illust_page_count': 5,
              }
            ]
          }
        }
      };

      final searchPosts = PixivMapper.postsFromSearchResponse(
        searchJson,
        providerId: 'pixiv',
        providerName: 'Pixiv',
      );
      expect(searchPosts.first.pageCount, equals(5));
      expect(searchPosts.first.isMultiPage, isTrue);

      final detailJson = {
        'body': {
          'id': '333444',
          'title': 'Detail multi artwork',
          'page_count': 7,
          'urls': {'original': 'https://i.pximg.net/orig.jpg'},
        }
      };
      final detailPost = PixivMapper.postFromIllustResponse(
        detailJson,
        providerId: 'pixiv',
        providerName: 'Pixiv',
      );
      expect(detailPost, isNotNull);
      expect(detailPost!.pageCount, equals(7));
      expect(detailPost.isMultiPage, isTrue);
    });
  });
}
