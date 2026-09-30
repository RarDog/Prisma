import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gel_rule_app/core/models/post.dart';
import 'package:gel_rule_app/features/manga/presentation/widgets/page_flip_3d.dart';
import 'package:gel_rule_app/features/manga/presentation/manga_reader_screen.dart';
import 'package:gel_rule_app/shared/widgets/app_shell.dart';
import 'package:gel_rule_app/sources/booru/mangadex_provider.dart';

void main() {
  group('Manga & 3D Reader Tests', () {
    testWidgets('PageFlip3D renders initial page and handles flip', (tester) async {
      int changedPage = -1;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PageFlip3D(
              itemCount: 5,
              initialIndex: 0,
              onPageChanged: (idx) => changedPage = idx,
              itemBuilder: (context, index) => Container(
                key: ValueKey('page_$index'),
                child: Text('Page $index'),
              ),
            ),
          ),
        ),
      );

      expect(find.text('Page 0'), findsOneWidget);

      // Perform a drag to flip to next page
      await tester.drag(find.text('Page 0'), const Offset(-400, 0));
      await tester.pumpAndSettle();

      // Should flip to page 1
      expect(changedPage, equals(1));
      expect(find.text('Page 1'), findsOneWidget);
    });

    testWidgets('MangaReaderScreen renders title, direction and fullscreen buttons', (tester) async {
      final post = Post(
        id: '999999',
        providerId: 'nhentai',
        providerName: 'nHentai',
        previewUrl: 'https://t.nhentai.net/galleries/999999/cover.jpg',
        sampleUrl: 'https://i.nhentai.net/galleries/999999/1.jpg',
        fileUrl: 'https://i.nhentai.net/galleries/999999/1.jpg',
        tags: const ['manga', 'doujinshi'],
        rating: 'e',
        width: 1200,
        height: 1800,
        createdAt: DateTime.now(),
        fileType: 'jpg',
        score: 500,
        tagGroups: const {
          'copyright': ['Epic Manga Title'],
          'children': ['999999_p0', '999999_p1'],
        },
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: MangaReaderScreen(post: post),
          ),
        ),
      );

      expect(find.text('Epic Manga Title'), findsOneWidget);
      expect(find.byIcon(Icons.fullscreen_rounded), findsOneWidget);
      expect(find.byIcon(Icons.format_textdirection_r_to_l_rounded), findsOneWidget);

      // Tap direction button to toggle to LTR
      await tester.tap(find.byIcon(Icons.format_textdirection_r_to_l_rounded));
      await tester.pump();
      expect(find.byIcon(Icons.format_textdirection_l_to_r_rounded), findsOneWidget);

      // Tap fullscreen button to toggle fullscreen
      await tester.tap(find.byIcon(Icons.fullscreen_rounded));
      await tester.pump();
      // AppBar should hide in fullscreen
      expect(find.text('Epic Manga Title'), findsNothing);
    });

    testWidgets('PageFlip3D triggers onEndReached at last page', (tester) async {
      bool endReached = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PageFlip3D(
              itemCount: 2,
              initialIndex: 1, // On last page
              onEndReached: () => endReached = true,
              itemBuilder: (context, index) => Text('Page $index'),
            ),
          ),
        ),
      );

      expect(find.text('Page 1'), findsOneWidget);

      // Drag left to advance past last page (LTR mode default)
      await tester.drag(find.text('Page 1'), const Offset(-400, 0));
      await tester.pumpAndSettle();

      expect(endReached, isTrue);
    });

    testWidgets('MangaReaderScreen displays chapters and language switcher', (tester) async {
      final post = Post(
        id: 'md_manga_1',
        providerId: 'mangadex',
        providerName: 'MangaDex',
        previewUrl: 'https://uploads.mangadex.org/covers/md_manga_1/cover.jpg.256.jpg',
        sampleUrl: 'https://uploads.mangadex.org/covers/md_manga_1/cover.jpg.512.jpg',
        fileUrl: 'https://uploads.mangadex.org/covers/md_manga_1/cover.jpg',
        tags: const ['Manga', 'Action'],
        rating: 's',
        width: 800,
        height: 1200,
        createdAt: DateTime.now(),
        fileType: 'jpg',
        score: 100,
        tagGroups: const {
          'copyright': ['Solo Leveling'],
        },
      );

      final ch1Ru = MangaDexChapter(
        id: 'ch1',
        chapterNumber: '1',
        title: 'Начало',
        language: 'ru',
        pageCount: 15,
      );
      final ch2Ru = MangaDexChapter(
        id: 'ch2',
        chapterNumber: '2',
        title: 'Второе подземелье',
        language: 'ru',
        pageCount: 18,
      );
      final ch1En = MangaDexChapter(
        id: 'ch1_en',
        chapterNumber: '1',
        title: 'The Beginning',
        language: 'en',
        pageCount: 15,
      );

      final allCh = [ch1Ru, ch2Ru, ch1En];
      final ruCh = [ch1Ru, ch2Ru];

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: MangaReaderScreen(
              post: post,
              initialChapters: ruCh,
              initialChapterIndex: 0,
              initialLanguage: 'ru',
              allChapters: allCh,
            ),
          ),
        ),
      );

      // Title should be visible
      expect(find.text('Solo Leveling'), findsOneWidget);

      // Chapter button should show Ch. 1
      expect(find.textContaining('1'), findsWidgets);

      // Flag for Russian language should be displayed
      expect(find.text('🇷🇺'), findsOneWidget);
    });

    test('ShellBottomBarVisibilityNotifier manages pushHide and popHide', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(shellHideBottomBarProvider), isFalse);

      final notifier = container.read(shellHideBottomBarProvider.notifier);
      notifier.pushHide();
      expect(container.read(shellHideBottomBarProvider), isTrue);

      // Second push (e.g. details -> reader)
      notifier.pushHide();
      expect(container.read(shellHideBottomBarProvider), isTrue);

      // Pop reader -> still hidden because details is active
      notifier.popHide();
      expect(container.read(shellHideBottomBarProvider), isTrue);

      // Pop details -> now shown!
      notifier.popHide();
      expect(container.read(shellHideBottomBarProvider), isFalse);
    });
  });
}
