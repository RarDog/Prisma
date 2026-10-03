import 'package:flutter_test/flutter_test.dart';
import 'package:gel_rule_app/backend/backend.dart';

void main() {
  group('Provider Top Period Filtering Tests', () {
    ContentProviderConfig makeConfig(String id, String apiType) {
      final now = DateTime.now();
      return ContentProviderConfig(
        id: id,
        name: id,
        baseUrl: 'https://example.test/$id',
        apiType: apiType,
        enabled: true,
        priority: 1,
        timeoutSeconds: 20,
        customHeaders: const {},
        createdAt: now,
        updatedAt: now,
      );
    }

    test('Gelbooru and Rule34 support only none and allTime', () {
      final gelbooru = makeConfig('gelbooru', 'gelbooru');
      final rule34 = makeConfig('rule34', 'rule34');
      final safebooru = makeConfig('safebooru', 'safebooru');
      final realbooru = makeConfig('realbooru', 'realbooru_html');
      final moebooru = makeConfig('moebooru', 'moebooru');

      expect(gelbooru.supportedTopPeriods, {
        TopPeriodFilter.none,
        TopPeriodFilter.allTime,
      });
      expect(rule34.supportedTopPeriods, {
        TopPeriodFilter.none,
        TopPeriodFilter.allTime,
      });
      expect(safebooru.supportedTopPeriods, {
        TopPeriodFilter.none,
        TopPeriodFilter.allTime,
      });
      expect(realbooru.supportedTopPeriods, {
        TopPeriodFilter.none,
        TopPeriodFilter.allTime,
      });
      expect(moebooru.supportedTopPeriods, {
        TopPeriodFilter.none,
        TopPeriodFilter.allTime,
      });
    });

    test('Danbooru, e621 and MangaDex support all periods', () {
      final danbooru = makeConfig('danbooru', 'danbooru');
      final e621 = makeConfig('e621', 'e621');
      final mangadex = makeConfig('mangadex', 'mangadex');

      final allPeriods = {
        TopPeriodFilter.none,
        TopPeriodFilter.day,
        TopPeriodFilter.week,
        TopPeriodFilter.month,
        TopPeriodFilter.year,
        TopPeriodFilter.allTime,
      };

      expect(danbooru.supportedTopPeriods, allPeriods);
      expect(e621.supportedTopPeriods, allPeriods);
      expect(mangadex.supportedTopPeriods, allPeriods);
    });

    test('Pixiv supports ranking periods (none, day, week, month)', () {
      final pixiv = makeConfig('pixiv', 'pixiv');
      expect(pixiv.supportedTopPeriods, {
        TopPeriodFilter.none,
        TopPeriodFilter.day,
        TopPeriodFilter.week,
        TopPeriodFilter.month,
      });
    });

    test('Paheal and Pawchive support only none', () {
      final paheal = makeConfig('paheal', 'rule34_paheal');
      final pawchive = makeConfig('pawchive', 'pawchive');
      expect(paheal.supportedTopPeriods, {TopPeriodFilter.none});
      expect(pawchive.supportedTopPeriods, {TopPeriodFilter.none});
    });

    test('resolveSupportedTopPeriods intersects when mixed', () {
      final danbooru = makeConfig('danbooru', 'danbooru');
      final gelbooru = makeConfig('gelbooru', 'gelbooru');
      final e621 = makeConfig('e621', 'e621');

      // Single Danbooru -> all periods
      expect(
        resolveSupportedTopPeriods([danbooru]),
        {
          TopPeriodFilter.none,
          TopPeriodFilter.day,
          TopPeriodFilter.week,
          TopPeriodFilter.month,
          TopPeriodFilter.year,
          TopPeriodFilter.allTime,
        },
      );

      // Single Gelbooru -> only none and allTime
      expect(
        resolveSupportedTopPeriods([gelbooru]),
        {
          TopPeriodFilter.none,
          TopPeriodFilter.allTime,
        },
      );

      // Danbooru + e621 -> all periods
      expect(
        resolveSupportedTopPeriods([danbooru, e621]),
        {
          TopPeriodFilter.none,
          TopPeriodFilter.day,
          TopPeriodFilter.week,
          TopPeriodFilter.month,
          TopPeriodFilter.year,
          TopPeriodFilter.allTime,
        },
      );

      // Danbooru + Gelbooru -> falls back to none and allTime
      expect(
        resolveSupportedTopPeriods([danbooru, gelbooru]),
        {
          TopPeriodFilter.none,
          TopPeriodFilter.allTime,
        },
      );
    });
  });
}
