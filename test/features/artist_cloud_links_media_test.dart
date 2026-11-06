import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gel_rule_app/core/models/cloud_media_link.dart';
import 'package:gel_rule_app/core/models/post.dart';
import 'package:gel_rule_app/core/utils/media_quality.dart';
import 'package:gel_rule_app/features/post/presentation/widgets/fullscreen_image_viewer_page.dart';
import 'package:gel_rule_app/features/post/presentation/widgets/post_media_viewer.dart';

void main() {
  group('Artist posts with cloud links (Google Drive, MEGA) in description', () {
    testWidgets(
        'photo post with Google Drive link in description is displayed as image and not video',
        (tester) async {
      const gdriveLink = CloudMediaLink(
        url: 'https://drive.google.com/file/d/1AbC-DeFgHiJkLmNoPqRsTuVwXyZ123/view',
        service: CloudServiceType.googleDrive,
        title: 'Google Drive File',
        directStreamUrl:
            'https://drive.google.com/uc?export=download&id=1AbC-DeFgHiJkLmNoPqRsTuVwXyZ123',
        isStreamable: true,
      );

      final photoPost = Post(
        id: 'patreon:123:456:0',
        providerId: 'pawchive',
        providerName: 'Pawchive',
        previewUrl: 'https://img.pawchive.pw/thumbnail/data/c3/06/art.png',
        sampleUrl: 'https://img.pawchive.pw/thumbnail/data/c3/06/art.png',
        fileUrl: 'https://file.pawchive.pw/data/c3/06/art.png',
        tags: const ['patreon', 'artist'],
        rating: 'unknown',
        width: 1200,
        height: 1600,
        createdAt: DateTime(2026, 1, 1),
        fileType: 'photo',
        score: 0,
        tagGroups: {
          'cloud_links': [gdriveLink.encode()],
          'description': [
            'Full pack on Google Drive: https://drive.google.com/file/d/1AbC-DeFgHiJkLmNoPqRsTuVwXyZ123/view'
          ],
        },
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 600,
                height: 800,
                child: PostMediaViewer(
                  post: photoPost,
                  fullscreen: false,
                ),
              ),
            ),
          ),
        ),
      );

      // Must NOT render video surface or video player for a photo post
      expect(find.byType(VideoSurface), findsNothing);
      expect(find.byType(CloudMediaHero), findsNothing);
      expect(find.byType(PostMediaViewer), findsOneWidget);
    });

    testWidgets(
        'link-only post with MEGA link displays CloudMediaHero',
        (tester) async {
      const megaLink = CloudMediaLink(
        url: 'https://mega.nz/file/xyz123#abcdefg',
        service: CloudServiceType.mega,
        title: 'MEGA Archive',
        isFolder: false,
        isStreamable: false,
      );

      final linkPost = Post(
        id: 'patreon:123:789:0',
        providerId: 'pawchive',
        providerName: 'Pawchive',
        previewUrl: '',
        sampleUrl: '',
        fileUrl: '',
        tags: const ['patreon', 'artist', 'cloud_mirror'],
        rating: 'unknown',
        width: 0,
        height: 0,
        createdAt: DateTime(2026, 1, 1),
        fileType: 'link',
        score: 0,
        tagGroups: {
          'cloud_links': [megaLink.encode()],
          'description': ['Download from Mega: https://mega.nz/file/xyz123#abcdefg'],
        },
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 600,
                height: 800,
                child: PostMediaViewer(
                  post: linkPost,
                  fullscreen: false,
                ),
              ),
            ),
          ),
        ),
      );

      // Link-only post must render CloudMediaHero with open button
      expect(find.byType(CloudMediaHero), findsOneWidget);
      expect(find.byType(VideoSurface), findsNothing);
    });

    testWidgets(
        'link-only post with Google Drive archive displays CloudMediaHero instead of video player',
        (tester) async {
      const gdriveLink = CloudMediaLink(
        url: 'https://drive.google.com/file/d/abc987/view',
        service: CloudServiceType.googleDrive,
        title: 'Google Drive File',
        directStreamUrl:
            'https://drive.google.com/uc?export=download&id=abc987',
        isStreamable: true,
      );

      final linkPost = Post(
        id: 'fanbox:999:111:0',
        providerId: 'pawchive',
        providerName: 'Pawchive',
        previewUrl: '',
        sampleUrl: '',
        fileUrl: '',
        tags: const ['fanbox', 'artist', 'cloud_mirror'],
        rating: 'unknown',
        width: 0,
        height: 0,
        createdAt: DateTime(2026, 1, 1),
        fileType: 'link',
        score: 0,
        tagGroups: {
          'cloud_links': [gdriveLink.encode()],
          'description': ['Archive on Google Drive: https://drive.google.com/file/d/abc987/view'],
        },
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 600,
                height: 800,
                child: PostMediaViewer(
                  post: linkPost,
                  fullscreen: false,
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.byType(CloudMediaHero), findsOneWidget);
      expect(find.byType(VideoSurface), findsNothing);
    });

    testWidgets(
        'fullscreen viewer treats photo post with Google Drive link as image and not video',
        (tester) async {
      const gdriveLink = CloudMediaLink(
        url: 'https://drive.google.com/file/d/1AbC-DeFgHiJkLmNoPqRsTuVwXyZ123/view',
        service: CloudServiceType.googleDrive,
        title: 'Google Drive File',
        directStreamUrl:
            'https://drive.google.com/uc?export=download&id=1AbC-DeFgHiJkLmNoPqRsTuVwXyZ123',
        isStreamable: true,
      );

      final photoPost = Post(
        id: 'patreon:123:456:0',
        providerId: 'pawchive',
        providerName: 'Pawchive',
        previewUrl: 'https://img.pawchive.pw/thumbnail/data/c3/06/art.png',
        sampleUrl: 'https://img.pawchive.pw/thumbnail/data/c3/06/art.png',
        fileUrl: 'https://file.pawchive.pw/data/c3/06/art.png',
        tags: const ['patreon', 'artist'],
        rating: 'unknown',
        width: 1200,
        height: 1600,
        createdAt: DateTime(2026, 1, 1),
        fileType: 'photo',
        score: 0,
        tagGroups: {
          'cloud_links': [gdriveLink.encode()],
          'description': [
            'Full pack on Google Drive: https://drive.google.com/file/d/1AbC-DeFgHiJkLmNoPqRsTuVwXyZ123/view'
          ],
        },
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: FullscreenImageViewerPage(
              posts: [photoPost],
              initialIndex: 0,
              qualityMode: MediaQualityMode.auto,
              notes: const [],
              showNotes: false,
              headersBuilder: (_) => const {},
            ),
          ),
        ),
      );

      // Must render InteractiveViewer/image and not video player
      expect(find.byType(InteractiveViewer), findsOneWidget);
    });

    test('MediaUrlSelector returns empty details and preview for link and text posts', () {
      final textPost = Post(
        id: 'patreon:123:000:0',
        providerId: 'pawchive',
        providerName: 'Pawchive',
        previewUrl: 'https://some-web-url.com/landing',
        sampleUrl: '',
        fileUrl: 'https://mega.nz/file/xyz',
        tags: const ['text_post'],
        rating: 'unknown',
        width: 0,
        height: 0,
        createdAt: DateTime(2026, 1, 1),
        fileType: 'link',
        score: 0,
      );

      expect(MediaUrlSelector.details(textPost), isEmpty);
      expect(MediaUrlSelector.preview(textPost), isEmpty);
      expect(MediaUrlSelector.isVideo(textPost), isFalse);
    });
  });
}
