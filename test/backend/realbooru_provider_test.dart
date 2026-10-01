import 'package:flutter_test/flutter_test.dart';
import 'package:gel_rule_app/core/models/post.dart';
import 'package:gel_rule_app/features/providers/models/content_provider_config.dart';
import 'package:gel_rule_app/sources/interfaces/content_provider.dart';
import 'package:gel_rule_app/sources/provider_factory.dart';
import 'package:gel_rule_app/sources/booru/realbooru_html_provider.dart';
import 'package:gel_rule_app/core/http/dio_client.dart';

void main() {
  group('RealbooruProvider Tests', () {
    test('ProviderFactory creates RealbooruHtmlProvider from both realbooru and realbooru_html', () {
      final factory = ProviderFactory();
      for (final apiType in ['realbooru', 'realbooru_html']) {
        final config = ContentProviderConfig(
          id: 'realbooru',
          name: 'Realbooru',
          baseUrl: 'https://realbooru.com',
          apiType: apiType,
          enabled: true,
          priority: 3,
          timeoutSeconds: 20,
          customHeaders: const {},
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
        );

        final provider = factory.create(config);
        expect(provider, isA<RealbooruHtmlProvider>());
        expect(provider.id, equals('realbooru'));
        expect(provider.name, equals('Realbooru'));
        expect(provider.baseUrl, equals('https://realbooru.com'));
        expect(provider, isA<TagSuggestionProvider>());
        expect(provider, isA<CommentProvider>());
        expect(provider, isA<MediaHeadersProvider>());
        expect(provider, isA<PostPageProvider>());
      }
    });

    test('RealbooruProvider URLs and headers', () {
      final client = DioClient(baseUrl: 'https://realbooru.com');
      final provider = RealbooruHtmlProvider(
        id: 'realbooru',
        name: 'Realbooru',
        baseUrl: 'https://realbooru.com',
        dioClient: client,
      );

      final dummyPost = Post(
        id: '100123',
        providerId: 'realbooru',
        providerName: 'Realbooru',
        previewUrl: 'https://realbooru.com/thumbnails/ed/29/thumbnail_test.jpg',
        sampleUrl: 'https://realbooru.com/images/ed/29/test.jpeg',
        fileUrl: 'https://realbooru.com/images/ed/29/test.jpeg',
        tags: const ['blonde', 'bikini'],
        rating: 'explicit',
        width: 1200,
        height: 800,
        createdAt: DateTime.now(),
        fileType: 'jpeg',
        score: 10,
      );

      expect(
        provider.postPageUrl(dummyPost),
        equals('https://realbooru.com/index.php?page=post&s=view&id=100123'),
      );

      final headers = provider.mediaHeaders(dummyPost);
      expect(headers['Referer'], equals('https://realbooru.com/'));
      expect(headers['User-Agent'], isNotEmpty);
    });
  });
}
