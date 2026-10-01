import 'dart:ffi' show Abi;
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gel_rule_app/core/database/app_database.dart';
import 'package:gel_rule_app/core/database/database_service.dart';
import 'package:gel_rule_app/features/manga/domain/manga_library_service.dart';
import 'package:isar/isar.dart';

void main() {
  late Directory directory;
  late AppDatabase database;
  late DatabaseService databaseService;
  late MangaLibraryService libraryService;

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
    directory = await Directory.systemTemp.createTemp('manga_lib_test_');
    database = await AppDatabase.open(directory: directory.path);
    databaseService = DatabaseService(database);
    libraryService = MangaLibraryService(databaseService);
  });

  tearDown(() async {
    await database.close();
    if (directory.existsSync()) {
      await directory.delete(recursive: true);
    }
  });

  group('MangaLibraryService Tests', () {
    test('saveProgress and getProgress roundtrip works correctly', () async {
      await libraryService.saveProgress(
        mangaId: 'manga-123',
        providerId: 'mangadex',
        title: 'Chainsaw Man',
        coverUrl: 'https://example.com/cover.jpg',
        chapterId: 'chap-1',
        chapterNumber: '1',
        pageIndex: 15,
        totalPages: 24,
      );

      final progress = await libraryService.getProgress('manga-123');
      expect(progress, isNotNull);
      expect(progress!.mangaId, equals('manga-123'));
      expect(progress.title, equals('Chainsaw Man'));
      expect(progress.chapterId, equals('chap-1'));
      expect(progress.chapterNumber, equals('1'));
      expect(progress.pageIndex, equals(15));
      expect(progress.totalPages, equals(24));
    });

    test('toggleChapterRead marks chapters and updates status', () async {
      await libraryService.toggleChapterRead(
        mangaId: 'manga-456',
        chapterId: 'chap-10',
        isRead: true,
      );

      expect(await libraryService.isChapterRead('manga-456', 'chap-10'), isTrue);
      expect(await libraryService.isChapterRead('manga-456', 'chap-11'), isFalse);

      await libraryService.toggleChapterRead(
        mangaId: 'manga-456',
        chapterId: 'chap-10',
        isRead: false,
      );

      expect(await libraryService.isChapterRead('manga-456', 'chap-10'), isFalse);
    });

    test('setLibraryStatus saves entry and filters work correctly', () async {
      await libraryService.setLibraryStatus(
        mangaId: 'manga-1',
        providerId: 'mangadex',
        title: 'Frieren',
        coverUrl: 'https://example.com/frieren.jpg',
        status: 'reading',
      );

      await libraryService.setLibraryStatus(
        mangaId: 'manga-2',
        providerId: 'mangadex',
        title: 'Dungeon Meshi',
        coverUrl: 'https://example.com/dungeon.jpg',
        status: 'completed',
      );

      final all = await libraryService.getLibraryEntries();
      expect(all.length, equals(2));

      final reading = await libraryService.getLibraryEntries(statusFilter: 'reading');
      expect(reading.length, equals(1));
      expect(reading.first.title, equals('Frieren'));

      final completed = await libraryService.getLibraryEntries(statusFilter: 'completed');
      expect(completed.length, equals(1));
      expect(completed.first.title, equals('Dungeon Meshi'));

      // Remove from library
      await libraryService.setLibraryStatus(
        mangaId: 'manga-1',
        providerId: 'mangadex',
        title: 'Frieren',
        coverUrl: '',
        status: null,
      );

      final remaining = await libraryService.getLibraryEntries();
      expect(remaining.length, equals(1));
      expect(remaining.first.title, equals('Dungeon Meshi'));
    });

    test('reading history returns entries sorted by last read date', () async {
      await libraryService.saveProgress(
        mangaId: 'manga-a',
        providerId: 'mangadex',
        title: 'Manga A',
        coverUrl: 'url-a',
        chapterId: 'c1',
        chapterNumber: '1',
        pageIndex: 2,
        totalPages: 20,
      );

      await Future<void>.delayed(const Duration(milliseconds: 20));

      await libraryService.saveProgress(
        mangaId: 'manga-b',
        providerId: 'mangadex',
        title: 'Manga B',
        coverUrl: 'url-b',
        chapterId: 'c2',
        chapterNumber: '2',
        pageIndex: 5,
        totalPages: 30,
      );

      final history = await libraryService.getReadingHistory();
      expect(history.length, equals(2));
      expect(history.first.mangaId, equals('manga-b'));
      expect(history.last.mangaId, equals('manga-a'));
    });

    test('removeLibraryEntry removes entry cleanly', () async {
      await libraryService.setLibraryStatus(
        mangaId: 'manga-99',
        providerId: 'mangalib',
        title: 'Solo Leveling',
        coverUrl: 'https://example.com/solo.jpg',
        status: 'reading',
      );

      expect(await libraryService.getLibraryEntry('manga-99'), isNotNull);

      await libraryService.removeLibraryEntry('manga-99');

      expect(await libraryService.getLibraryEntry('manga-99'), isNull);
      final entries = await libraryService.getLibraryEntries();
      expect(entries.where((e) => e.mangaId == 'manga-99').isEmpty, isTrue);
    });
  });
}
