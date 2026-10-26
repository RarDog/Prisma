import 'package:flutter_test/flutter_test.dart';
import 'package:gel_rule_app/core/http/dio_client.dart';
import 'package:gel_rule_app/core/models/top_period_filter.dart';
import 'package:gel_rule_app/sources/booru/wallhaven_provider.dart';
import 'package:gel_rule_app/sources/booru/arena_provider.dart';
import 'package:gel_rule_app/sources/provider_factory.dart';
import 'package:gel_rule_app/features/providers/models/content_provider_config.dart';

void main() {
  group('WallhavenProvider Unit Tests', () {
    late WallhavenProvider provider;
    late DioClient client;

    setUp(() {
      client = DioClient(baseUrl: 'https://wallhaven.cc');
      provider = WallhavenProvider(
        id: 'wallhaven',
        name: 'Wallhaven',
        baseUrl: 'https://wallhaven.cc',
        dioClient: client,
      );
    });

    tearDown(() {
      client.close();
    });

    test('verifies provider metadata and top period capabilities', () {
      expect(provider.id, equals('wallhaven'));
      expect(provider.name, equals('Wallhaven'));
      expect(provider.baseUrl, equals('https://wallhaven.cc'));
      expect(provider.supportedTopPeriods, contains(TopPeriodFilter.allTime));
      expect(provider.supportedTopPeriods, contains(TopPeriodFilter.week));
      expect(provider.supportedTopPeriods, contains(TopPeriodFilter.day));
    });

    test('suggestTags returns filtered creative suggestions', () async {
      final suggestions = await provider.suggestTags('cyber');
      expect(suggestions, isNotEmpty);
      expect(suggestions.any((s) => s.name.contains('cyberpunk')), isTrue);
    });

    test(
        'maps 4K wallpaper item with sampleUrl and fileUrl pointing to full path',
        () {
      final rawItem = {
        'id': 'jel1jq',
        'url': 'https://wallhaven.cc/w/jel1jq',
        'dimension_x': 3840,
        'dimension_y': 2160,
        'resolution': '3840x2160',
        'purity': 'sfw',
        'category': 'anime',
        'favorites': 1500,
        'path': 'https://w.wallhaven.cc/full/je/wallhaven-jel1jq.jpg',
        'thumbs': {
          'large': 'https://th.wallhaven.cc/lg/je/jel1jq.jpg',
          'original': 'https://th.wallhaven.cc/orig/je/jel1jq.jpg',
          'small': 'https://th.wallhaven.cc/small/je/jel1jq.jpg',
        },
        'tags': [
          {'name': 'landscape'},
          {'name': 'mountains'},
        ],
      };

      final post = provider.mapToPost(rawItem);
      expect(post, isNotNull);
      expect(post!.id, equals('jel1jq'));
      expect(post.width, equals(3840));
      expect(post.height, equals(2160));
      expect(
          post.previewUrl, equals('https://th.wallhaven.cc/lg/je/jel1jq.jpg'));
      // sampleUrl MUST be the full 4K path, not the 432x243 thumbnail
      expect(post.sampleUrl,
          equals('https://w.wallhaven.cc/full/je/wallhaven-jel1jq.jpg'));
      expect(post.fileUrl,
          equals('https://w.wallhaven.cc/full/je/wallhaven-jel1jq.jpg'));
      expect(post.tags, contains('landscape'));
      expect(post.tags, contains('mountains'));
      expect(post.tags, contains('anime'));
    });
  });

  group('ArenaProvider Unit Tests', () {
    late ArenaProvider provider;
    late DioClient client;

    setUp(() {
      client = DioClient(baseUrl: 'https://api.are.na/v2');
      provider = ArenaProvider(
        id: 'arena',
        name: 'Are.na',
        baseUrl: 'https://api.are.na/v2',
        dioClient: client,
      );
    });

    tearDown(() {
      client.close();
    });

    test('verifies provider metadata and capabilities', () {
      expect(provider.id, equals('arena'));
      expect(provider.name, equals('Are.na'));
      expect(provider.baseUrl, equals('https://api.are.na/v2'));
      expect(provider.supportedTopPeriods, contains(TopPeriodFilter.none));
    });

    test('suggestTags returns design and moodboard suggestions', () async {
      final suggestions = await provider.suggestTags('mood');
      expect(suggestions, isNotEmpty);
      expect(suggestions.any((s) => s.name == 'moodboard'), isTrue);
    });
  });

  group('ProviderFactory Integration Tests', () {
    final factory = ProviderFactory();

    test('creates WallhavenProvider from ContentProviderConfig', () {
      final config = ContentProviderConfig(
        id: 'wallhaven',
        name: 'Wallhaven',
        baseUrl: 'https://wallhaven.cc',
        apiType: 'wallhaven',
        enabled: true,
        priority: 13,
        timeoutSeconds: 20,
        customHeaders: {'api_key': 'test_key'},
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final instance = factory.create(config);
      expect(instance, isA<WallhavenProvider>());
      final wh = instance as WallhavenProvider;
      expect(wh.apiKey, equals('test_key'));
    });

    test('creates ArenaProvider from ContentProviderConfig', () {
      final config = ContentProviderConfig(
        id: 'arena',
        name: 'Are.na',
        baseUrl: 'https://api.are.na/v2',
        apiType: 'arena',
        enabled: true,
        priority: 14,
        timeoutSeconds: 25,
        customHeaders: {'token': 'test_token'},
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final instance = factory.create(config);
      expect(instance, isA<ArenaProvider>());
      final ar = instance as ArenaProvider;
      expect(ar.token, equals('test_token'));
    });
  });
}
