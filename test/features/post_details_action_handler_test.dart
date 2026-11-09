import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:gel_rule_app/app/app_strings.dart';
import 'package:gel_rule_app/backend/backend.dart';
import 'package:gel_rule_app/features/post/presentation/post_details_screen.dart';

void main() {
  group('PostDetailsActionHandler tests', () {
    test('buildActionLabels generates expected bilingual labels', () {
      const stringsEn = AppStrings('en');
      final labelsEn = PostDetailsActionHandler.buildActionLabels(stringsEn);
      expect(labelsEn.favorite, stringsEn.favorite);
      expect(labelsEn.saveAs, 'Save as...');
      expect(labelsEn.copyLink, 'Copy link');
      expect(labelsEn.share, 'Share');

      const stringsRu = AppStrings('ru');
      final labelsRu = PostDetailsActionHandler.buildActionLabels(stringsRu);
      expect(labelsRu.favorite, stringsRu.favorite);
      expect(labelsRu.saveAs, 'Сохранить как...');
      expect(labelsRu.copyLink, 'Копировать ссылку');
      expect(labelsRu.share, 'Поделиться');
    });
  });

  group('PostDetailsQuickActionsSheet tests', () {
    final testPost = Post(
      id: '123',
      providerId: 'gelbooru',
      providerName: 'Gelbooru',
      previewUrl: 'https://example.com/p.jpg',
      sampleUrl: 'https://example.com/s.jpg',
      fileUrl: 'https://example.com/f.jpg',
      tags: const ['cat'],
      rating: 'general',
      width: 100,
      height: 100,
      createdAt: DateTime(2026, 1, 1),
      fileType: 'jpg',
      score: 10,
    );

    testWidgets('renders all quick action items', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: PostDetailsQuickActionsSheet(
                post: testPost,
                favoriteKeys: const {},
              ),
            ),
          ),
        ),
      );

      expect(find.text('Favorite'), findsOneWidget);
      expect(find.text('Add to collection'), findsOneWidget);
      expect(find.text('Copy link'), findsOneWidget);
      expect(find.text('Download'), findsOneWidget);
    });

    testWidgets('fires onToggleFavorite callback on tap', (tester) async {
      bool toggleFavCalled = false;

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: PostDetailsQuickActionsSheet(
                post: testPost,
                favoriteKeys: const {},
                onToggleFavorite: () => toggleFavCalled = true,
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Favorite'));
      await tester.pump();
      expect(toggleFavCalled, isTrue);
    });

    testWidgets('fires onAddToCollection callback on tap', (tester) async {
      bool addToCollectionCalled = false;

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: PostDetailsQuickActionsSheet(
                post: testPost,
                favoriteKeys: const {},
                onAddToCollection: () => addToCollectionCalled = true,
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Add to collection'));
      await tester.pump();
      expect(addToCollectionCalled, isTrue);
    });

    testWidgets('fires onDownload callback on tap', (tester) async {
      bool downloadCalled = false;

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: PostDetailsQuickActionsSheet(
                post: testPost,
                favoriteKeys: const {},
                onDownload: () => downloadCalled = true,
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Download'));
      await tester.pump();
      expect(downloadCalled, isTrue);
    });

    testWidgets('renders Remove favorite when post is already favorited',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: PostDetailsQuickActionsSheet(
                post: testPost,
                favoriteKeys: {testPost.cacheKey},
              ),
            ),
          ),
        ),
      );

      expect(find.text('Remove favorite'), findsOneWidget);
      expect(find.text('Favorite'), findsNothing);
    });

    testWidgets('renders Download all pages when multiple pages exist',
        (tester) async {
      bool downloadAllCalled = false;
      final multiPost = testPost.copyWith(
        id: '456',
        tagGroups: {
          'page_count': ['3'],
        },
      );
      final page2 = testPost.copyWith(id: '456_p1');
      final page3 = testPost.copyWith(id: '456_p2');

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            postPagesProvider(PostPagesArgs(multiPost)).overrideWith(
              (ref) async => [multiPost, page2, page3],
            ),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: PostDetailsQuickActionsSheet(
                post: multiPost,
                favoriteKeys: const {},
                onDownloadAllPages: (_) => downloadAllCalled = true,
              ),
            ),
          ),
        ),
      );

      // Pump to resolve future provider
      await tester.pumpAndSettle();

      expect(find.text('Download all pages (3)'), findsOneWidget);
      await tester.tap(find.text('Download all pages (3)'));
      await tester.pump();
      expect(downloadAllCalled, isTrue);
    });

    testWidgets('PostDetailsQuickActionsSheet.show displays bottom sheet modal',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: Consumer(
                builder: (context, ref, _) => ElevatedButton(
                  onPressed: () => PostDetailsQuickActionsSheet.show(
                    context: context,
                    ref: ref,
                    post: testPost,
                    favoriteKeys: const {},
                  ),
                  child: const Text('Open Sheet'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Sheet'));
      await tester.pumpAndSettle();

      expect(find.text('Favorite'), findsOneWidget);
      expect(find.text('Add to collection'), findsOneWidget);
      expect(find.text('Copy link'), findsOneWidget);
      expect(find.text('Download'), findsOneWidget);
    });
  });
}

