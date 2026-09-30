import 'package:flutter_test/flutter_test.dart';
import 'package:gel_rule_app/core/http/dio_client.dart';
import 'package:gel_rule_app/core/models/post.dart';
import 'package:gel_rule_app/features/post/presentation/widgets/post_media_viewer.dart';
import 'package:gel_rule_app/features/providers/models/content_provider_config.dart';
import 'package:gel_rule_app/sources/booru/mangadex_provider.dart';
import 'package:gel_rule_app/sources/mappers/mangadex_mapper.dart';
import 'package:gel_rule_app/sources/provider_factory.dart';

void main() {
  group('MangaDexProvider & MangaDexMapper Tests', () {
    test('ProviderFactory creates MangaDexProvider from config', () {
      final factory = ProviderFactory();
      final config = ContentProviderConfig(
        id: 'mangadex',
        name: 'MangaDex',
        baseUrl: 'https://api.mangadex.org',
        apiType: 'mangadex',
        enabled: true,
        priority: 9,
        timeoutSeconds: 25,
        customHeaders: const {},
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      );

      final provider = factory.create(config);
      expect(provider, isA<MangaDexProvider>());
      expect(provider.id, equals('mangadex'));
      expect(provider.name, equals('MangaDex'));
      expect(provider.baseUrl, equals('https://api.mangadex.org'));
    });

    test('MangaDexMapper parses manga JSON correctly', () {
      final mangaJson = {
        'id': '1d35f256-be1e-4873-93c0-03bf25db5edd',
        'type': 'manga',
        'attributes': {
          'title': {'en': 'Test Manga Title', 'ja': 'テスト'},
          'altTitles': [
            {'ru': 'Тестовая Манга'},
          ],
          'description': {'en': 'Awesome manga description', 'ru': 'Описание манги'},
          'contentRating': 'suggestive',
          'tags': [
            {
              'id': 't1',
              'type': 'tag',
              'attributes': {
                'name': {'en': 'Action'},
              },
            },
            {
              'id': 't2',
              'type': 'tag',
              'attributes': {
                'name': {'en': 'Romance'},
              },
            },
          ],
        },
        'relationships': [
          {
            'id': 'a1',
            'type': 'author',
            'attributes': {'name': 'Author Sensei'},
          },
          {
            'id': 'ar1',
            'type': 'artist',
            'attributes': {'name': 'Artist Master'},
          },
          {
            'id': 'c1',
            'type': 'cover_art',
            'attributes': {'fileName': 'cover123.jpg'},
          },
        ],
      };

      final post = MangaDexMapper.postFromMangaJson(
        mangaJson,
        providerId: 'mangadex',
        providerName: 'MangaDex',
      );

      expect(post, isNotNull);
      expect(post!.id, equals('1d35f256-be1e-4873-93c0-03bf25db5edd'));
      expect(post.providerId, equals('mangadex'));
      // Russian title preferred if available, or English
      expect(post.title, equals('Test Manga Title'));
      expect(post.previewUrl, equals('https://uploads.mangadex.org/covers/1d35f256-be1e-4873-93c0-03bf25db5edd/cover123.jpg.256.jpg'));
      expect(post.sampleUrl, equals('https://uploads.mangadex.org/covers/1d35f256-be1e-4873-93c0-03bf25db5edd/cover123.jpg.512.jpg'));
      expect(post.fileUrl, equals('https://uploads.mangadex.org/covers/1d35f256-be1e-4873-93c0-03bf25db5edd/cover123.jpg'));
      expect(post.tags, containsAll(['Action', 'Romance']));
      expect(post.tagGroups['artist'], equals(['Artist Master']));
      expect(post.tagGroups['author'], equals(['Author Sensei']));
      expect(post.tagGroups['media_type'], equals(['manga']));
      expect(post.tagGroups['content_rating'], equals(['suggestive']));
    });

    test('MangaDex media headers contain User-Agent and Referer', () {
      final client = DioClient(baseUrl: 'https://api.mangadex.org');
      final provider = MangaDexProvider(
        id: 'mangadex',
        name: 'MangaDex',
        baseUrl: 'https://api.mangadex.org',
        dioClient: client,
      );

      final post = Post(
        id: 'm123',
        providerId: 'mangadex',
        providerName: 'MangaDex',
        previewUrl: 'https://uploads.mangadex.org/covers/m123/cover.jpg.256.jpg',
        sampleUrl: 'https://uploads.mangadex.org/covers/m123/cover.jpg.512.jpg',
        fileUrl: 'https://uploads.mangadex.org/covers/m123/cover.jpg',
        tags: const ['Manga'],
        rating: 's',
        width: 700,
        height: 1000,
        createdAt: DateTime.now(),
        fileType: 'jpg',
        score: 0,
      );

      final headers = provider.mediaHeaders(post);
      expect(headers['Referer'], equals('https://mangadex.org/'));
      expect(headers['User-Agent'], contains('MangaDex'));

      final globalHeaders = getPostMediaHeaders(post);
      expect(globalHeaders['Referer'], equals('https://mangadex.org/'));
    });

    test('MangaLanguageHelper provides flags and Russian names', () {
      expect(MangaLanguageHelper.flag('ru'), equals('🇷🇺'));
      expect(MangaLanguageHelper.flag('en'), equals('🇬🇧'));
      expect(MangaLanguageHelper.flag('ja'), equals('🇯🇵'));
      expect(MangaLanguageHelper.name('ru'), equals('Русский'));
      expect(MangaLanguageHelper.name('en'), equals('English'));
      expect(MangaLanguageHelper.name('ja'), equals('日本語'));
    });

    test('MangaDexProvider suggestTags matches official tags', () async {
      final client = DioClient(baseUrl: 'https://api.mangadex.org');
      final provider = MangaDexProvider(
        id: 'mangadex',
        name: 'MangaDex',
        baseUrl: 'https://api.mangadex.org',
        dioClient: client,
      );

      final suggestions = await provider.suggestTags('romance');
      expect(suggestions.any((s) => s.name == 'Romance'), isTrue);
      final romance = suggestions.firstWhere((s) => s.name == 'Romance');
      expect(romance.providerId, equals('mangadex'));

      final isekaiSuggestions = await provider.suggestTags('isekai');
      expect(isekaiSuggestions.any((s) => s.name == 'Isekai'), isTrue);
    });
  });
}
