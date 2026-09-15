import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:gel_rule_app/backend/models/collection.dart';
import 'package:gel_rule_app/backend/models/favorite.dart';
import 'package:gel_rule_app/backend/models/search_history.dart';
import 'package:gel_rule_app/backend/services/backup_service.dart';
import 'package:gel_rule_app/backend/services/settings_service.dart';
import 'package:gel_rule_app/core/utils/result.dart';

class _FakeSettingsService extends Fake implements SettingsService {
  AppSettings current = AppSettings.defaults;

  @override
  Future<Result<AppSettings>> getSettings() async => Success(current);

  @override
  Future<Result<void>> updateSettings(AppSettings settings) async {
    current = settings;
    return const Success(null);
  }
}

void main() {
  group('Persistent Backup Tests', () {
    test('BackupService exports and restores comprehensive user data', () async {
      final fakeSettings = _FakeSettingsService();
      final backupService = BackupService(fakeSettings);

      fakeSettings.current = AppSettings.defaults.copyWith(
        themeMode: 'light',
        languageCode: 'en',
        appSeedColor: 0xFF123456,
        blacklistedTags: ['tag1', 'tag2'],
        whitelistedTags: ['tag3'],
        smartBlacklistRules: ['score:<10', 'rating:explicit'],
      );

      final jsonStr = await backupService.createBackupJson();
      final decoded = jsonDecode(jsonStr) as Map<String, dynamic>;

      expect(decoded['version'], equals(3));
      expect(decoded['settings'], isA<Map>());
      expect(decoded['providers'], isA<List>());
      expect(decoded['favorites'], isA<List>());
      expect(decoded['collections'], isA<List>());

      // Test restoring into modified state
      fakeSettings.current = AppSettings.defaults;
      expect(fakeSettings.current.themeMode, equals('dark'));

      final restoreResult = await backupService.restoreFromJson(jsonStr);
      expect(restoreResult.isSuccess, isTrue);
      expect(fakeSettings.current.themeMode, equals('light'));
      expect(fakeSettings.current.languageCode, equals('en'));
      expect(fakeSettings.current.appSeedColor, equals(0xFF123456));
      expect(fakeSettings.current.blacklistedTags, equals(['tag1', 'tag2']));
    });

    test('Favorite, Collection and SearchHistory JSON serialization', () {
      final now = DateTime.now();

      final fav = Favorite(
        id: 'e621:123',
        postId: '123',
        providerId: 'e621',
        savedAt: now,
      );
      final favJson = fav.toJson();
      final restoredFav = Favorite.fromJson(favJson);
      expect(restoredFav.id, equals(fav.id));
      expect(restoredFav.postId, equals(fav.postId));
      expect(restoredFav.providerId, equals(fav.providerId));

      final col = Collection(
        id: 'col1',
        name: 'My Collection',
        description: 'Test desc',
        coverUrl: 'https://example.com/cover.jpg',
        createdAt: now,
        updatedAt: now,
      );
      final colJson = col.toJson();
      final restoredCol = Collection.fromJson(colJson);
      expect(restoredCol.id, equals(col.id));
      expect(restoredCol.name, equals(col.name));
      expect(restoredCol.description, equals(col.description));

      final sh = SearchHistory(
        id: 'sh1',
        query: 'furry cat',
        tags: ['furry', 'cat'],
        searchedAt: now,
        resultCount: 42,
      );
      final shJson = sh.toJson();
      final restoredSh = SearchHistory.fromJson(shJson);
      expect(restoredSh.id, equals(sh.id));
      expect(restoredSh.query, equals(sh.query));
      expect(restoredSh.tags, equals(['furry', 'cat']));
      expect(restoredSh.resultCount, equals(42));
    });

    test('Candidate backup directories are populated', () async {
      final fakeSettings = _FakeSettingsService();
      final backupService = BackupService(fakeSettings);

      final dirs = await backupService.getCandidateBackupDirectories();
      expect(dirs, isNotEmpty);
      expect(dirs.any((d) => d.contains('Prisma')), isTrue);
    });

    test('createBackupDataMap provides structured snapshot', () async {
      final fakeSettings = _FakeSettingsService();
      final backupService = BackupService(fakeSettings);

      final map = await backupService.createBackupDataMap();
      expect(map.containsKey('settings'), isTrue);
      expect(map.containsKey('providers'), isTrue);
      expect(map.containsKey('favorites'), isTrue);
      expect(map.containsKey('collections'), isTrue);
    });
  });
}
