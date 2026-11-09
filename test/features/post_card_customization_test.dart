import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gel_rule_app/core/models/post.dart';
import 'package:gel_rule_app/core/utils/media_quality.dart';
import 'package:gel_rule_app/features/settings/models/post_card_badge_config.dart';
import 'package:gel_rule_app/features/settings/presentation/widgets/card_badges_customizer_sheet.dart';
import 'package:gel_rule_app/shared/widgets/post_card.dart';
import 'package:gel_rule_app/shared/widgets/rating_badge.dart';

void main() {
  group('PostCardBadgeConfig Model', () {
    test('default values are set correctly', () {
      const config = PostCardBadgeConfig();
      expect(config.showProvider, isTrue);
      expect(config.showMediaType, isTrue);
      expect(config.showRating, isTrue);
      expect(config.showStatus, isTrue);
      expect(config.showFavorite, isTrue);
      expect(config.providerPosition, equals('topLeft'));
      expect(config.mediaTypePosition, equals('topRight'));
      expect(config.ratingPosition, equals('bottomLeft'));
      expect(config.statusPosition, equals('bottomLeft'));
      expect(config.favoritePosition, equals('bottomRight'));
    });

    test('roundtrip JSON serialization preserves all fields', () {
      const config = PostCardBadgeConfig(
        showProvider: false,
        showMediaType: true,
        showRating: false,
        showStatus: true,
        showFavorite: false,
        providerPosition: 'bottomRight',
        mediaTypePosition: 'topLeft',
        ratingPosition: 'topRight',
        statusPosition: 'topRight',
        favoritePosition: 'topLeft',
      );

      final json = config.toJson();
      final restored = PostCardBadgeConfig.fromJson(json);

      expect(restored, equals(config));
      expect(restored.showProvider, isFalse);
      expect(restored.showMediaType, isTrue);
      expect(restored.providerPosition, equals('bottomRight'));
      expect(restored.mediaTypePosition, equals('topLeft'));
      expect(restored.ratingPosition, equals('topRight'));
    });

    test('copyWith updates properties properly', () {
      const config = PostCardBadgeConfig();
      final updated = config.copyWith(
        showProvider: false,
        providerPosition: 'bottomRight',
      );

      expect(updated.showProvider, isFalse);
      expect(updated.providerPosition, equals('bottomRight'));
      expect(updated.showRating, isTrue);
      expect(updated.ratingPosition, equals('bottomLeft'));
    });
  });

  group('PostCard dynamic corner placement', () {
    final samplePost = Post(
      id: 'test_card_1',
      providerId: 'safebooru',
      providerName: 'Safebooru',
      previewUrl: 'https://example.com/safebooru.jpg',
      sampleUrl: 'https://example.com/safebooru.jpg',
      fileUrl: 'https://example.com/safebooru.jpg',
      tags: const ['tag1', 'tag2'],
      rating: 'general',
      width: 400,
      height: 600,
      createdAt: DateTime.now(),
      fileType: 'video',
      score: 10,
    );

    testWidgets('renders badges in default corners', (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 300,
                height: 400,
                child: PostCard(
                  post: samplePost,
                  blurExplicit: false,
                  showBadges: true,
                  badgeConfig: const PostCardBadgeConfig(),
                  isFavorite: false,
                  isViewed: true,
                  isDownloaded: true,
                  mediaQualityMode: MediaQualityMode.auto,
                  onOpen: () {},
                  onFavorite: () {},
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pump();

      // Check default elements exist by widget type
      expect(find.byType(ProviderBadge), findsOneWidget);
      expect(find.byType(MediaBadge), findsOneWidget);
      expect(find.byType(RatingBadge), findsOneWidget);
      expect(find.byType(SeenBadge), findsOneWidget);
      expect(find.byType(FavoriteButton), findsOneWidget);
    });

    testWidgets('hides elements when disabled in badgeConfig', (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      const customConfig = PostCardBadgeConfig(
        showProvider: false,
        showMediaType: false,
        showRating: false,
        showStatus: false,
        showFavorite: false,
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 300,
                height: 400,
                child: PostCard(
                  post: samplePost,
                  blurExplicit: false,
                  showBadges: true,
                  badgeConfig: customConfig,
                  isFavorite: false,
                  isViewed: true,
                  isDownloaded: true,
                  mediaQualityMode: MediaQualityMode.auto,
                  onOpen: () {},
                  onFavorite: () {},
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pump();

      // Everything should be hidden
      expect(find.byType(ProviderBadge), findsNothing);
      expect(find.byType(MediaBadge), findsNothing);
      expect(find.byType(RatingBadge), findsNothing);
      expect(find.byType(SeenBadge), findsNothing);
      expect(find.byType(FavoriteButton), findsNothing);
    });
  });

  group('CardBadgesCustomizerSheet', () {
    testWidgets('renders live preview and configuration controls',
        (tester) async {
      tester.view.physicalSize = const Size(500, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      tester.view.physicalSize = const Size(800, 1200);
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () => CardBadgesCustomizerSheet.show(context),
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Header title and reset button
      expect(find.byIcon(Icons.dashboard_customize_rounded), findsOneWidget);
      expect(find.byIcon(Icons.restart_alt_rounded), findsOneWidget);

      // Section switches exist
      expect(find.byType(Switch), findsNWidgets(5));

      // SegmentedButtons for corner placement exist
      expect(find.byType(SegmentedButton<String>), findsNWidgets(5));
    });
  });
}
