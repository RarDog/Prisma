import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gel_rule_app/features/manga/domain/reader_navigation_helper.dart';
import 'package:gel_rule_app/features/manga/presentation/novel_reader_screen.dart';
import 'package:gel_rule_app/sources/booru/mangadex_provider.dart';

void main() {
  group('ReaderNavigationHelper Tests', () {
    test('hasPrevious and hasNext handle boundary conditions correctly', () {
      expect(ReaderNavigationHelper.hasPrevious(currentIndex: 0, totalCount: 5), isFalse);
      expect(ReaderNavigationHelper.hasPrevious(currentIndex: 1, totalCount: 5), isTrue);
      expect(ReaderNavigationHelper.hasPrevious(currentIndex: 4, totalCount: 5), isTrue);
      expect(ReaderNavigationHelper.hasPrevious(currentIndex: -1, totalCount: 5), isFalse);
      expect(ReaderNavigationHelper.hasPrevious(currentIndex: 1, totalCount: 0), isFalse);

      expect(ReaderNavigationHelper.hasNext(currentIndex: 0, totalCount: 5), isTrue);
      expect(ReaderNavigationHelper.hasNext(currentIndex: 3, totalCount: 5), isTrue);
      expect(ReaderNavigationHelper.hasNext(currentIndex: 4, totalCount: 5), isFalse);
      expect(ReaderNavigationHelper.hasNext(currentIndex: 5, totalCount: 5), isFalse);
      expect(ReaderNavigationHelper.hasNext(currentIndex: 0, totalCount: 0), isFalse);
    });

    test('previousIndex and nextIndex return proper next/prev or null', () {
      expect(ReaderNavigationHelper.previousIndex(currentIndex: 0, totalCount: 3), isNull);
      expect(ReaderNavigationHelper.previousIndex(currentIndex: 2, totalCount: 3), equals(1));

      expect(ReaderNavigationHelper.nextIndex(currentIndex: 0, totalCount: 3), equals(1));
      expect(ReaderNavigationHelper.nextIndex(currentIndex: 2, totalCount: 3), isNull);
    });

    test('formatChapterProgress formats labels accurately', () {
      expect(ReaderNavigationHelper.formatChapterProgress(currentIndex: 0, totalCount: 10), equals('1 / 10'));
      expect(ReaderNavigationHelper.formatChapterProgress(currentIndex: 9, totalCount: 10), equals('10 / 10'));
      expect(ReaderNavigationHelper.formatChapterProgress(currentIndex: 0, totalCount: 0), equals('0 / 0'));
    });
  });

  group('NovelReaderScreen & ReaderFullscreenMixin Tests', () {
    testWidgets('NovelReaderScreen initializes controls, displays content and toggles fullscreen', (tester) async {
      final chapters = [
        const MangaDexChapter(
          id: 'ch1',
          chapterNumber: '1',
          title: 'Пролог',
          language: 'ru',
          pageCount: 1,
          textContent: 'Это первая строка новеллы. Приключения начинаются.',
        ),
        const MangaDexChapter(
          id: 'ch2',
          chapterNumber: '2',
          title: 'Глава 2: Путь',
          language: 'ru',
          pageCount: 1,
          textContent: 'Вторая глава новеллы.',
        ),
      ];

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: NovelReaderScreen(
              mangaId: 'novel-1',
              chapter: chapters[0],
              allChapters: chapters,
              title: 'Тестовая Новелла',
              providerId: 'ranobelib',
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Check title and content
      expect(find.text('Тестовая Новелла'), findsOneWidget);
      expect(find.text('Пролог'), findsOneWidget);
      expect(find.text('Это первая строка новеллы. Приключения начинаются.'), findsOneWidget);
      expect(find.text('1 / 2'), findsOneWidget);

      // Previous button should be disabled for chapter 0, Next should be enabled
      final prevBtn = tester.widget<IconButton>(find.widgetWithIcon(IconButton, Icons.skip_previous));
      final nextBtn = tester.widget<IconButton>(find.widgetWithIcon(IconButton, Icons.skip_next));
      expect(prevBtn.onPressed, isNull);
      expect(nextBtn.onPressed, isNotNull);

      // Tap content to toggle controls (enter fullscreen)
      await tester.tap(find.text('Пролог'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Controls should hide in fullscreen mode
      expect(find.text('Тестовая Новелла'), findsNothing);
      expect(find.text('1 / 2'), findsNothing);

      // Tap again to show controls (exit fullscreen)
      await tester.tap(find.text('Пролог'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Тестовая Новелла'), findsOneWidget);
      expect(find.text('1 / 2'), findsOneWidget);
    });
  });
}
