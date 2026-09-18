import 'package:flutter_test/flutter_test.dart';
import 'package:gel_rule_app/features/settings/domain/settings_service.dart';

void main() {
  group('Rating persistence tests', () {
    test('copyWith clears defaultRatingFilter and lastFeedRating when flags are true', () {
      final initial = AppSettings.defaults.copyWith(
        defaultRatingFilter: 'safe',
        lastFeedRating: 'safe',
      );

      expect(initial.defaultRatingFilter, 'safe');
      expect(initial.lastFeedRating, 'safe');

      final updated = initial.copyWith(
        clearDefaultRatingFilter: true,
        clearLastFeedRating: true,
      );

      expect(updated.defaultRatingFilter, isNull);
      expect(updated.lastFeedRating, isNull);
    });

    test('copyWith preserves existing rating filter when flags are false and value is omitted', () {
      final initial = AppSettings.defaults.copyWith(
        defaultRatingFilter: 'safe',
        lastFeedRating: 'safe',
      );

      final updated = initial.copyWith(
        languageCode: 'ru',
      );

      expect(updated.defaultRatingFilter, 'safe');
      expect(updated.lastFeedRating, 'safe');
    });

    test('copyWith sets new rating filter when provided', () {
      final initial = AppSettings.defaults.copyWith(
        defaultRatingFilter: 'safe',
        lastFeedRating: 'safe',
      );

      final updated = initial.copyWith(
        defaultRatingFilter: 'questionable',
        lastFeedRating: 'questionable',
      );

      expect(updated.defaultRatingFilter, 'questionable');
      expect(updated.lastFeedRating, 'questionable');
    });
  });
}
