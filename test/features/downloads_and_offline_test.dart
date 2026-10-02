// ignore_for_file: depend_on_referenced_packages

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gel_rule_app/core/models/post.dart';
import 'package:gel_rule_app/features/downloads/domain/download_manager_service.dart';
import 'package:gel_rule_app/features/downloads/domain/download_service.dart';
import 'package:gel_rule_app/features/downloads/models/download_task.dart';
import 'package:gel_rule_app/features/manga/domain/manga_offline_service.dart';
import 'package:gel_rule_app/sources/booru/mangadex_provider.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class FakePathProviderPlatform extends PathProviderPlatform
    with MockPlatformInterfaceMixin {
  final String path;
  FakePathProviderPlatform(this.path);

  @override
  Future<String?> getTemporaryPath() async => path;

  @override
  Future<String?> getApplicationDocumentsPath() async => path;

  @override
  Future<String?> getDownloadsPath() async => path;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tempDir;

  setUpAll(() {
    tempDir = Directory.systemTemp.createTempSync('downloads_test_');
    PathProviderPlatform.instance = FakePathProviderPlatform(tempDir.path);
  });

  tearDownAll(() {
    try {
      tempDir.deleteSync(recursive: true);
    } catch (_) {}
  });

  group('DownloadManagerService & CancelToken Tests', () {
    test('CancelToken is triggered when cancelling an active task', () async {
      final requestStarted = Completer<void>();
      CancelToken? capturedToken;
      final dio = Dio();
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) async {
            capturedToken = options.cancelToken;
            if (!requestStarted.isCompleted) {
              requestStarted.complete();
            }
            // Wait until cancelled
            try {
              while (capturedToken != null && !capturedToken!.isCancelled) {
                await Future.delayed(const Duration(milliseconds: 20));
              }
            } catch (_) {}
            return handler.reject(
              DioException(
                requestOptions: options,
                type: DioExceptionType.cancel,
                error: 'User canceled download',
              ),
            );
          },
        ),
      );

      final downloadService = DownloadService(dio: dio);
      final manager = DownloadManagerService(downloadService);

      final post = Post(
        id: '12345',
        providerId: 'safebooru',
        providerName: 'Safebooru',
        previewUrl: 'https://example.com/preview.jpg',
        sampleUrl: 'https://example.com/sample.jpg',
        fileUrl: 'https://example.com/file.jpg',
        tags: const ['tag1'],
        rating: 's',
        width: 100,
        height: 100,
        createdAt: DateTime.now(),
        fileType: 'jpg',
        score: 0,
      );

      final task = await manager.start(post);
      expect(task.status, equals(DownloadTaskStatus.queued));

      // Wait until Dio request is actively running with the cancel token
      await requestStarted.future;
      expect(capturedToken, isNotNull);

      manager.cancel(task.id);

      final updatedTask = manager.tasks.firstWhere((t) => t.id == task.id);
      expect(updatedTask.status, equals(DownloadTaskStatus.canceled));
      expect(capturedToken?.isCancelled, isTrue);
    });
  });

  group('MangaOfflineService Tests', () {
    test('downloadMangaChapter throws on empty pageUrls', () async {
      final dio = Dio();
      final offlineService = MangaOfflineService(dio: dio);
      const chapter = MangaDexChapter(
        id: 'c1',
        chapterNumber: '1',
        title: 'Глава 1',
        language: 'ru',
        pageCount: 0,
      );

      expect(
        () => offlineService.downloadMangaChapter(
          mangaId: 'manga-1',
          chapter: chapter,
          pageUrls: [],
          providerId: 'mangalib',
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('downloadMangaChapter downloads pages and notifies progress', () async {
      final dio = Dio();
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            return handler.resolve(
              Response(
                requestOptions: options,
                statusCode: 200,
                data: ResponseBody.fromBytes(
                  utf8.encode('dummy-image-data'),
                  200,
                ),
              ),
            );
          },
        ),
      );

      final mangaTempDir = Directory.systemTemp.createTempSync('manga_test_');
      final offlineService = MangaOfflineService(dio: dio, baseDir: mangaTempDir.path);
      const chapter = MangaDexChapter(
        id: 'ch-test-101',
        chapterNumber: '10',
        title: 'Глава 10',
        language: 'ru',
        pageCount: 3,
      );

      final progressCalls = <int>[];
      await offlineService.downloadMangaChapter(
        mangaId: 'manga-test-101',
        chapter: chapter,
        pageUrls: [
          'https://example.com/p0.jpg',
          'https://example.com/p1.jpg',
          'https://example.com/p2.jpg',
        ],
        providerId: 'mangalib',
        onProgress: (current, total) {
          progressCalls.add(current);
        },
      );

      expect(progressCalls, isNotEmpty);
      expect(progressCalls.last, equals(3));

      final isDownloaded = await offlineService.isChapterDownloaded('manga-test-101', 'ch-test-101');
      expect(isDownloaded, isTrue);

      final downloadedPages = await offlineService.getDownloadedPages('manga-test-101', 'ch-test-101');
      expect(downloadedPages.length, equals(3));

      try {
        await offlineService.deleteDownloadedChapter('manga-test-101', 'ch-test-101');
        final isDeleted = await offlineService.isChapterDownloaded('manga-test-101', 'ch-test-101');
        expect(isDeleted, isFalse);
      } finally {
        try {
          mangaTempDir.deleteSync(recursive: true);
        } catch (_) {}
      }
    });
  });
}
