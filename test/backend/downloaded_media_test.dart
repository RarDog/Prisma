import 'dart:ffi' show Abi;
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:isar/isar.dart' hide Collection;
import 'package:gel_rule_app/core/database/app_database.dart';
import 'package:gel_rule_app/core/database/database_service.dart';
import 'package:gel_rule_app/core/models/post.dart';
import 'package:gel_rule_app/core/utils/result.dart';
import 'package:gel_rule_app/features/downloads/data/downloaded_media_repository.dart';
import 'package:gel_rule_app/features/downloads/models/downloaded_media.dart';
import 'package:gel_rule_app/features/downloads/domain/downloaded_media_service.dart';

Post post(String id) => Post(
      id: id,
      providerId: 'danbooru',
      providerName: 'Danbooru',
      previewUrl: 'https://example.com/$id.jpg',
      sampleUrl: 'https://example.com/$id.jpg',
      fileUrl: 'https://example.com/$id.jpg',
      tags: const [],
      rating: 's',
      width: 800,
      height: 600,
      createdAt: DateTime.now(),
      fileType: 'jpg',
      score: 0,
    );

void main() {
  late Directory directory;
  late AppDatabase database;
  late DownloadedMediaService service;

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
    directory = await Directory.systemTemp.createTemp('prisma_dl_test_');
    database = await AppDatabase.open(directory: directory.path);
    service = DownloadedMediaService(
      DownloadedMediaRepository(DatabaseService(database)),
    );
  });

  tearDown(() async {
    await database.close();
    if (directory.existsSync()) {
      await directory.delete(recursive: true);
    }
  });

  test('markDownloaded writes the row, bumps the notifier and is readable',
      () async {
    var notified = 0;
    service.changeNotifier.addListener(() => notified++);

    final result = await service.markDownloaded(
      post('123'),
      savedPath: '/tmp/123.jpg',
      fileName: '123.jpg',
    );
    expect(result, isA<Success<void>>());
    expect(notified, 1, reason: 'listeners must be notified after the write');

    final read = await service.allByKeys([post('123').cacheKey]);
    expect(read, isA<Success<Map<String, DownloadedMedia>>>());
    final map = (read as Success<Map<String, DownloadedMedia>>).data;
    expect(map, contains(post('123').cacheKey),
        reason: 'the offline tab resolves by post.cacheKey');
    expect(map[post('123').cacheKey]!.savedPath, '/tmp/123.jpg');
  });

  test('deleteLocalFile removes the row and notifies', () async {
    await service.markDownloaded(
      post('123'),
      savedPath: '/tmp/does-not-exist.jpg',
      fileName: '123.jpg',
    );
    var notified = 0;
    service.changeNotifier.addListener(() => notified++);

    final result = await service.deleteLocalFile(post('123').cacheKey);
    expect(result, isA<Success<void>>());
    expect(notified, 1);

    final read = await service.allByKeys([post('123').cacheKey]);
    expect((read as Success<Map<String, DownloadedMedia>>).data, isEmpty);
  });
}
