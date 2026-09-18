import 'package:flutter_test/flutter_test.dart';
import 'package:gel_rule_app/backend/models/content_provider_config.dart';
import 'package:gel_rule_app/backend/models/post.dart';
import 'package:gel_rule_app/backend/providers/content_provider.dart';
import 'package:gel_rule_app/backend/providers/provider_factory.dart';
import 'package:gel_rule_app/backend/providers/safebooru_provider.dart';
import 'package:gel_rule_app/core/http/dio_client.dart';

void main() {
  group('SafebooruProvider Tests', () {
    test('ProviderFactory creates SafebooruProvider from config', () {
      final factory = ProviderFactory();
      final config = ContentProviderConfig(
        id: 'safebooru',
        name: 'Safebooru',
        baseUrl: 'https://safebooru.org',
        apiType: 'safebooru',
        enabled: true,
        priority: 10,
        timeoutSeconds: 20,
        customHeaders: const {},
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      );

      final provider = factory.create(config);
      expect(provider, isA<SafebooruProvider>());
      expect(provider.id, equals('safebooru'));
      expect(provider.name, equals('Safebooru'));
      expect(provider.baseUrl, equals('https://safebooru.org'));
      expect(provider, isA<TagSuggestionProvider>());
      expect(provider, isA<CommentProvider>());
      expect(provider, isA<MediaHeadersProvider>());
      expect(provider, isA<PostPageProvider>());
    });

    test('SafebooruProvider URLs and headers', () {
      final client = DioClient(baseUrl: 'https://safebooru.org');
      final provider = SafebooruProvider(
        id: 'safebooru',
        name: 'Safebooru',
        baseUrl: 'https://safebooru.org',
        dioClient: client,
      );

      final dummyPost = Post(
        id: '500123',
        providerId: 'safebooru',
        providerName: 'Safebooru',
        previewUrl: 'https://safebooru.org/thumbnails/1/thumbnail_test.jpg',
        sampleUrl: 'https://safebooru.org/samples/1/sample_test.jpg',
        fileUrl: 'https://safebooru.org/images/1/test.jpg',
        tags: const ['hatsune_miku'],
        rating: 'safe',
        width: 1200,
        height: 800,
        createdAt: DateTime.now(),
        fileType: 'jpeg',
        score: 42,
      );

      expect(
        provider.postPageUrl(dummyPost),
        equals('https://safebooru.org/index.php?page=post&s=view&id=500123'),
      );

      final headers = provider.mediaHeaders(dummyPost);
      expect(headers['Referer'], equals('https://safebooru.org/'));
      expect(headers['User-Agent'], contains('Prisma'));
    });
  });
}
