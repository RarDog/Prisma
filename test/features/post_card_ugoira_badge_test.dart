import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gel_rule_app/core/models/post.dart';
import 'package:gel_rule_app/core/utils/media_quality.dart';
import 'package:gel_rule_app/shared/widgets/post_card.dart';

void main() {
  group('PostCard UGOIRA Badge', () {
    testWidgets('displays UGOIRA badge on Ugoira posts', (tester) async {
      final post = Post(
        id: '123456',
        providerId: 'pixiv',
        providerName: 'Pixiv',
        previewUrl: 'https://example.com/p.jpg',
        sampleUrl: 'https://example.com/s.jpg',
        fileUrl: 'https://example.com/f.jpg',
        tags: const ['ugoira', 'animated'],
        rating: 's',
        width: 1920,
        height: 1080,
        source: '',
        createdAt: DateTime.now(),
        fileType: 'ugoira',
        score: 100,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 300,
              height: 400,
              child: PostCard(
                post: post,
                blurExplicit: false,
                showBadges: true,
                isFavorite: false,
                isViewed: false,
                isDownloaded: false,
                mediaQualityMode: MediaQualityMode.auto,
                onOpen: () {},
                onFavorite: () {},
              ),
            ),
          ),
        ),
      );

      await tester.pump();

      // Check for UGOIRA text badge
      expect(find.text('UGOIRA'), findsOneWidget);
      expect(find.byIcon(Icons.motion_photos_on_rounded), findsOneWidget);
    });
  });
}
