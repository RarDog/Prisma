import 'dart:convert';
import 'dart:ffi' show Abi;
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:isar/isar.dart' hide Collection;
import 'package:gel_rule_app/core/database/app_database.dart';
import 'package:gel_rule_app/core/database/database_service.dart';
import 'package:gel_rule_app/core/utils/result.dart';
import 'package:gel_rule_app/features/providers/data/provider_repository.dart';
import 'package:gel_rule_app/features/settings/domain/backup_service.dart';
import 'package:gel_rule_app/features/settings/domain/settings_service.dart';

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

/// Reproduces restoring a backup produced by the RELEASED app (backup
/// 'version': 3 payload shape) into the current build.
void main() {
  late Directory directory;
  late AppDatabase database;
  late DatabaseService databaseService;
  late ProviderRepository providerRepository;
  late BackupService backupService;
  final settingsService = _FakeSettingsService();

  setUpAll(() async {
    if (Platform.isLinux) {
      await Isar.initializeIsarCore(
        libraries: {
          Abi.linuxX64:
              '${Directory.current.path}/third_party/isar_flutter_libs/linux/libisar.so',
        },
      );
    }
  });

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('prisma_restore_test_');
    database = await AppDatabase.open(directory: directory.path);
    databaseService = DatabaseService(database);
    providerRepository = ProviderRepository(databaseService);
    backupService = BackupService(
      settingsService,
      databaseService,
      providerRepository,
    );
  });

  tearDown(() async {
    await database.close();
    if (directory.existsSync()) {
      await directory.delete(recursive: true);
    }
  });

  test('released-app (version 3) backup restores via file content', () async {
    final now = DateTime.now().toIso8601String();
    final backup = <String, dynamic>{
      'version': 3,
      'createdAt': now,
      'settings': AppSettings.defaults.copyWith(themeMode: 'light').toJson(),
      'providers': [
        {
          'id': 'e621',
          'name': 'e621',
          'baseUrl': 'https://e621.net',
          'apiType': 'e621',
          'enabled': true,
          'priority': 3,
          'timeoutSeconds': 14,
          'customHeaders': {
            'query.login': 'myuser',
            'query.api_key': 'secret-key',
          },
          'createdAt': now,
          'updatedAt': now,
        },
        {
          'id': 'danbooru',
          'name': 'Danbooru',
          'baseUrl': 'https://danbooru.donmai.us',
          'apiType': 'danbooru',
          'enabled': true,
          'priority': 1,
          'timeoutSeconds': 14,
          'customHeaders': <String, String>{},
          'createdAt': now,
          'updatedAt': now,
        },
      ],
      'favorites': [
        {
          'id': 'e621:12345',
          'postId': '12345',
          'providerId': 'e621',
          'savedAt': now,
        },
      ],
      'favoritePosts': [
        {
          'id': '12345',
          'providerId': 'e621',
          'providerName': 'e621',
          'previewUrl': 'https://img.example/prev.jpg',
          'sampleUrl': 'https://img.example/sample.jpg',
          'fileUrl': 'https://img.example/file.jpg',
          'tags': ['tag_a', 'tag_b'],
          'rating': 's',
          'width': 800,
          'height': 600,
          'fileType': 'jpg',
          'score': 42,
        },
      ],
      'collections': [
        {
          'id': 'col-1',
          'name': 'My collection',
          'createdAt': now,
          'updatedAt': now,
        },
      ],
      'collectionPosts': [
        {
          'collectionId': 'col-1',
          'postId': '12345',
          'providerId': 'e621',
          'addedAt': now,
        },
      ],
      'searchHistory': [
        {
          'historyId': 'h1',
          'query': 'cat ears',
          'tags': ['cat_ears'],
          'searchedAt': now,
          'resultCount': 12,
          'providerId': 'danbooru',
          'providerName': 'Danbooru',
        },
      ],
      'mangaLibrary': [
        {
          'mangaId': 'a1b2c3',
          'providerId': 'mangadex',
          'title': 'Test manga',
          'coverUrl': 'https://cover.example/512.jpg',
          'status': 'reading',
          'addedAt': now,
          'totalChaptersCount': 42,
          'newChaptersCount': 3,
        },
      ],
      'mangaProgress': [
        {
          'mangaId': 'a1b2c3',
          'providerId': 'mangadex',
          'title': 'Test manga',
          'coverUrl': 'https://cover.example/512.jpg',
          'chapterId': 'ch-9',
          'chapterNumber': '9',
          'pageIndex': 4,
          'totalPages': 20,
          'readChapterIds': ['ch-1', 'ch-2'],
          'updatedAt': now,
        },
      ],
      'viewedHistory': [
        {
          'viewedKey': 'e621:12345',
          'providerId': 'e621',
          'postId': '12345',
          'viewedAt': now,
        },
      ],
    };

    final jsonStr = const JsonEncoder.withIndent('  ').convert(backup);
    final result = await backupService.restoreFromJson(jsonStr);

    if (result is Error<BackupRestoreSummary>) {
      fail('Restore failed: ${result.failure.message}');
    }
    final summary = (result as Success<BackupRestoreSummary>).data;
    expect(summary.providersCount, 2);
    expect(summary.favoritesCount, 1);
    expect(summary.collectionsCount, 1);
    expect(summary.mangaEntriesCount, 1);
    expect(summary.historyCount, 1);
    expect(summary.downloadedMediaCount, 0);

    // Data actually landed in the database
    final favCount = await databaseService.isar.favoriteEntitys.count();
    expect(favCount, 1);

    // Settings applied
    expect(settingsService.current.themeMode, 'light');
  });
}
