import 'package:flutter_test/flutter_test.dart';
import 'package:gel_rule_app/core/http/dio_client.dart';
import 'package:gel_rule_app/core/models/post.dart';
import 'package:gel_rule_app/features/post/presentation/widgets/post_media_viewer.dart';
import 'package:gel_rule_app/features/providers/models/content_provider_config.dart';
import 'package:gel_rule_app/sources/booru/nhentai_provider.dart';
import 'package:gel_rule_app/sources/mappers/nhentai_mapper.dart';
import 'package:gel_rule_app/sources/provider_factory.dart';

void main() {
  group('NHentaiProvider & NHentaiMapper Tests', () {
    test('ProviderFactory creates NHentaiProvider from config', () {
      final factory = ProviderFactory();
      final config = ContentProviderConfig(
        id: 'nhentai',
        name: 'nHentai',
        baseUrl: 'https://nhentai.net',
        apiType: 'nhentai',
        enabled: true,
        priority: 8,
        timeoutSeconds: 25,
        customHeaders: const {},
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      );

      final provider = factory.create(config);
      expect(provider, isA<NHentaiProvider>());
      expect(provider.id, equals('nhentai'));
      expect(provider.name, equals('nHentai'));
      expect(provider.baseUrl, equals('https://nhentai.net'));
    });

    test('NHentaiMapper parses gallery details JSON correctly', () {
      final json = {
        'id': 123456,
        'media_id': 654321,
        'title': {
          'english': '[Artist] Test Manga (English)',
          'japanese': '[Artist] テストマンガ',
          'pretty': 'Test Manga',
        },
        'images': {
          'cover': {'t': 'j', 'w': 350, 'h': 500},
          'pages': [
            {'t': 'j', 'w': 1200, 'h': 1800},
            {'t': 'p', 'w': 1200, 'h': 1800},
            {'t': 'w', 'w': 1200, 'h': 1800},
          ],
        },
        'num_pages': 3,
        'num_favorites': 1500,
        'upload_date': 1700000000,
        'tags': [
          {'id': 1, 'type': 'artist', 'name': 'SuperArtist'},
          {'id': 2, 'type': 'parody', 'name': 'Original'},
          {'id': 3, 'type': 'language', 'name': 'english'},
          {'id': 4, 'type': 'tag', 'name': 'full color'},
        ],
      };

      final post = NHentaiMapper.postFromGalleryJson(
        json,
        providerId: 'nhentai',
        providerName: 'nHentai',
      );

      expect(post, isNotNull);
      expect(post!.id, equals('123456'));
      expect(post.providerId, equals('nhentai'));
      expect(post.title, equals('Test Manga'));
      expect(post.previewUrl, equals('https://t.nhentai.net/galleries/654321/cover.jpg'));
      expect(post.fileUrl, equals('https://i.nhentai.net/galleries/654321/1.jpg'));
      expect(post.childrenIds.length, equals(3));
      expect(post.childrenIds, equals(['123456_p0', '123456_p1', '123456_p2']));
      expect(post.tagGroups['artist'], equals(['SuperArtist']));
      expect(post.tagGroups['language'], equals(['english']));
      expect(post.tagGroups['is_comic'], equals(['true']));
      expect(post.score, equals(1500));
    });

    test('NHentaiMapper parses individual page items correctly', () {
      final parentPost = Post(
        id: '123456',
        providerId: 'nhentai',
        providerName: 'nHentai',
        previewUrl: 'https://t.nhentai.net/galleries/654321/cover.jpg',
        sampleUrl: 'https://i.nhentai.net/galleries/654321/1.jpg',
        fileUrl: 'https://i.nhentai.net/galleries/654321/1.jpg',
        tags: const ['full color'],
        rating: 'e',
        width: 1200,
        height: 1800,
        createdAt: DateTime.now(),
        fileType: 'jpg',
        score: 1500,
        tagGroups: const {
          'media_id': ['654321'],
          'artist': ['SuperArtist'],
          'children': ['123456_p0', '123456_p1'],
        },
      );

      final pagePost = NHentaiMapper.postFromPageData(
        pageItem: {'t': 'p', 'w': 1200, 'h': 1800},
        parentPost: parentPost,
        pageIndex: 1, // second page (page 2)
      );

      expect(pagePost, isNotNull);
      expect(pagePost!.id, equals('123456_p1'));
      expect(pagePost.fileUrl, equals('https://i.nhentai.net/galleries/654321/2.png'));
      expect(pagePost.previewUrl, equals('https://t.nhentai.net/galleries/654321/2t.png'));
      expect(pagePost.parentId, equals('123456'));
      expect(pagePost.childrenIds, isEmpty);
    });

    test('NHentai media headers contain Referer', () {
      final client = DioClient(baseUrl: 'https://nhentai.net');
      final provider = NHentaiProvider(
        id: 'nhentai',
        name: 'nHentai',
        baseUrl: 'https://nhentai.net',
        dioClient: client,
      );

      final post = Post(
        id: '123456',
        providerId: 'nhentai',
        providerName: 'nHentai',
        previewUrl: 'https://t.nhentai.net/galleries/654321/cover.jpg',
        sampleUrl: 'https://i.nhentai.net/galleries/654321/1.jpg',
        fileUrl: 'https://i.nhentai.net/galleries/654321/1.jpg',
        tags: const ['full color'],
        rating: 'e',
        width: 1200,
        height: 1800,
        createdAt: DateTime.now(),
        fileType: 'jpg',
        score: 1500,
      );

      final headers = provider.mediaHeaders(post);
      expect(headers['Referer'], equals('https://nhentai.net/'));

      final globalHeaders = getPostMediaHeaders(post);
      expect(globalHeaders['Referer'], equals('https://nhentai.net/'));
    });
  });
}
