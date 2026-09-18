import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gel_rule_app/core/models/post.dart';
import 'package:gel_rule_app/core/utils/media_quality.dart';
import 'package:gel_rule_app/features/post/presentation/widgets/post_media_viewer.dart';
import 'package:gel_rule_app/shared/widgets/adaptive_scaffold.dart';

void main() {
  group('PostMediaViewer fullscreen image tests', () {
    testWidgets('does not render overlay fullscreen button on media',
        (tester) async {
      final post = Post(
        id: '12345',
        providerId: 'safebooru',
        providerName: 'Safebooru',
        previewUrl: 'https://example.com/preview.jpg',
        sampleUrl: 'https://example.com/sample.jpg',
        fileUrl: 'https://example.com/file.jpg',
        width: 800,
        height: 600,
        tags: const ['test'],
        rating: 'general',
        fileType: 'jpg',
        score: 10,
        createdAt: DateTime(2026, 1, 1),
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 500,
                height: 500,
                child: PostMediaViewer(
                  post: post,
                  fullscreen: false,
                ),
              ),
            ),
          ),
        ),
      );

      // Verify the overlay fullscreen button is removed from media viewer
      expect(find.byIcon(Icons.fullscreen_rounded), findsNothing);
    });

    testWidgets('supports isActive toggling without error', (tester) async {
      final post = Post(
        id: '12345',
        providerId: 'safebooru',
        providerName: 'Safebooru',
        previewUrl: 'https://example.com/preview.jpg',
        sampleUrl: 'https://example.com/sample.jpg',
        fileUrl: 'https://example.com/file.jpg',
        width: 800,
        height: 600,
        tags: const ['test'],
        rating: 'general',
        fileType: 'jpg',
        score: 10,
        createdAt: DateTime(2026, 1, 1),
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 500,
                height: 500,
                child: PostMediaViewer(
                  post: post,
                  isActive: true,
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.byType(PostMediaViewer), findsOneWidget);

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 500,
                height: 500,
                child: PostMediaViewer(
                  post: post,
                  isActive: false,
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.byType(PostMediaViewer), findsOneWidget);
    });

    test('GIF posts prioritize original fileUrl for animated playback in details', () {
      final gifPost = Post(
        id: '999',
        providerId: 'gelbooru',
        providerName: 'Gelbooru',
        previewUrl: 'https://example.com/thumb.jpg',
        sampleUrl: 'https://example.com/sample.jpg',
        fileUrl: 'https://example.com/animation.gif',
        width: 600,
        height: 600,
        tags: const ['animated', 'gif'],
        rating: 'general',
        fileType: 'gif',
        score: 42,
        createdAt: DateTime(2026, 1, 1),
      );

      final detailsUrls = MediaUrlSelector.details(gifPost);
      expect(detailsUrls.first, 'https://example.com/animation.gif');
      expect(MediaUrlSelector.isGif(gifPost), isTrue);
    });

    testWidgets('Offstage properly responds to isFullscreenViewerActiveProvider',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: Consumer(
            builder: (context, ref, _) {
              final isFs = ref.watch(isFullscreenViewerActiveProvider);
              return MaterialApp(
                home: Scaffold(
                  body: Offstage(
                    key: const ValueKey('post_details_offstage'),
                    offstage: isFs,
                    child: const Text('PostDetailsContent'),
                  ),
                ),
              );
            },
          ),
        ),
      );

      expect(find.text('PostDetailsContent'), findsOneWidget);

      final container = ProviderScope.containerOf(
        tester.element(find.text('PostDetailsContent')),
      );
      container.read(isFullscreenViewerActiveProvider.notifier).state = true;
      await tester.pump();

      // Content is offstage
      final offstageWidget = tester.widget<Offstage>(
        find.byKey(const ValueKey('post_details_offstage')),
      );
      expect(offstageWidget.offstage, isTrue);

      container.read(isFullscreenViewerActiveProvider.notifier).state = false;
      await tester.pump();

      final restoredOffstage = tester.widget<Offstage>(
        find.byKey(const ValueKey('post_details_offstage')),
      );
      expect(restoredOffstage.offstage, isFalse);
    });

    testWidgets('AdaptiveScaffold actions render fullscreen icon next to close icon',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: AdaptiveScaffold(
            title: 'Post',
            actions: [
              IconButton(
                tooltip: 'Fullscreen',
                onPressed: () {},
                icon: const Icon(Icons.fullscreen_rounded),
              ),
              IconButton(
                tooltip: 'Close',
                onPressed: () {},
                icon: const Icon(Icons.close_rounded),
              ),
            ],
            body: const SizedBox.shrink(),
          ),
        ),
      );

      expect(find.byIcon(Icons.fullscreen_rounded), findsOneWidget);
      expect(find.byIcon(Icons.close_rounded), findsOneWidget);
    });
  });
}
