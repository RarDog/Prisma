import 'dart:ffi' show Abi;
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar/isar.dart' hide Collection;
import 'package:gel_rule_app/core/database/app_database.dart';
import 'package:gel_rule_app/core/database/database_service.dart';
import 'package:gel_rule_app/core/models/post.dart';
import 'package:gel_rule_app/core/utils/result.dart';
import 'package:gel_rule_app/features/downloads/data/downloaded_media_repository.dart';
import 'package:gel_rule_app/features/downloads/domain/download_manager_service.dart';
import 'package:gel_rule_app/features/downloads/domain/download_service.dart';
import 'package:gel_rule_app/features/downloads/domain/downloaded_media_service.dart';
import 'package:gel_rule_app/features/downloads/models/downloaded_media.dart';
import 'package:gel_rule_app/features/downloads/models/download_task.dart';
import 'package:gel_rule_app/features/settings/domain/settings_service.dart';

class _FakeDownloadService implements DownloadService {
  @override
  Future<String?> downloadPost(
    Post post, {
    String? folderTemplate,
    String? customSavePath,
    CancelToken? cancelToken,
    void Function(int received, int total)? onProgress,
  }) async {
    onProgress?.call(50, 100);
    return '/tmp/rule34/${post.id}.mp4';
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeSettingsService extends Fake implements SettingsService {
  @override
  Future<Result<AppSettings>> getSettings() async =>
      Success(AppSettings.defaults);
}

Post post(String id) => const Post(
      id: id,
      providerId: 'rule34',
      providerName: 'Rule34',
      previewUrl: 'https://example.com/$id.jpg',
      sampleUrl: 'https://example.com/$id.jpg',
      fileUrl: 'https://example.com/$id.mp4',
      tags: const [],
      rating: 'explicit',
      width: 800,
      height: 600,
      createdAt: DateTime.now(),
      fileType: 'mp4',
      score: 0,
    );

void main() {
  late Directory directory;
  late AppDatabase database;
  late DownloadedMediaService downloadedMediaService;
  late DownloadManagerService manager;

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
    directory = await Directory.systemTemp.createTemp('prisma_dm_e2e_');
    database = await AppDatabase.open(directory: directory.path);
    downloadedMediaService = DownloadedMediaService(
      DownloadedMediaRepository(DatabaseService(database)),
    );
    manager = DownloadManagerService(
      _FakeDownloadService(),
      downloadedMediaService: downloadedMediaService,
      settingsService: _FakeSettingsService(),
    );
  });

  tearDown(() async {
    await database.close();
    if (directory.existsSync()) {
      await directory.delete(recursive: true);
    }
  });

  test('a completed download is marked in the downloaded-media table',
      () async {
    final p = post('42');
    await manager.start(p);

    // Wait for the task to complete (fake download is instant).
    DownloadTask? task;
    for (var i = 0; i < 50; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
      task = manager.tasks.isEmpty ? null : manager.tasks.first;
      if (task?.status == DownloadTaskStatus.completed) break;
    }
    expect(task?.status, DownloadTaskStatus.completed,
        reason: 'the fake download completes instantly');

    final read = await downloadedMediaService.allByKeys([p.cacheKey]);
    final map = (read as Success<Map<String, DownloadedMedia>>).data;
    expect(map, contains(p.cacheKey),
        reason:
            'the offline tab resolves downloaded state by post.cacheKey — '
            'the row must exist right after completion');
  });
}
