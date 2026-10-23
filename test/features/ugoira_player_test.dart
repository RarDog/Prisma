import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gel_rule_app/core/models/post.dart';
import 'package:gel_rule_app/features/post/presentation/widgets/ugoira_player.dart';
import 'package:gel_rule_app/features/post/services/ugoira_service.dart';
import 'package:gel_rule_app/sources/models/ugoira_metadata.dart';

class _FakeUgoiraService extends UgoiraService {
  _FakeUgoiraService(this.mockFrames);
  final List<UgoiraFrame> mockFrames;

  @override
  Future<List<UgoiraFrame>> loadUgoiraFrames(
    UgoiraMetadata meta, {
    Map<String, String>? headers,
    void Function(double progress)? onProgress,
    dynamic cancelToken,
  }) async {
    onProgress?.call(1.0);
    return mockFrames;
  }
}

void main() {
  group('UgoiraPlayer widget', () {
    testWidgets('renders placeholder then loads frames and controls work', (tester) async {
      final post = Post(
        id: '12345',
        providerId: 'pixiv',
        providerName: 'Pixiv',
        previewUrl: 'https://example.com/p.jpg',
        sampleUrl: 'https://example.com/s.jpg',
        fileUrl: 'https://example.com/f.jpg',
        tags: const ['ugoira'],
        rating: 's',
        width: 200,
        height: 200,
        source: '',
        createdAt: DateTime.now(),
        fileType: 'ugoira',
        score: 10,
      );

      final dummyBytes1 = Uint8List.fromList([
        // 1x1 transparent png
        0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D,
        0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
        0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
        0x0A, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
        0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49,
        0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
      ]);

      final mockFrames = [
        UgoiraFrame(file: '000000.jpg', delayMs: 100, bytes: dummyBytes1),
        UgoiraFrame(file: '000001.jpg', delayMs: 100, bytes: dummyBytes1),
      ];

      final meta = UgoiraMetadata(
        zipUrl: 'https://example.com/test.zip',
        originalZipUrl: 'https://example.com/test.zip',
        mimeType: 'image/vnd.pixiv.ugoira+zip',
        frames: mockFrames,
      );

      final service = _FakeUgoiraService(mockFrames);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: UgoiraPlayer(
              post: post,
              ugoiraMetadata: meta,
              ugoiraService: service,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Tap to toggle overlay controls
      await tester.tap(find.byType(UgoiraPlayer));
      await tester.pumpAndSettle();

      // Verify play/pause icon exists
      expect(find.byIcon(Icons.pause_rounded), findsOneWidget);

      // Tap pause
      await tester.tap(find.byIcon(Icons.pause_rounded));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);

      // Verify frame counter text (1 / 2 or 2 / 2)
      expect(find.textContaining('/ 2'), findsOneWidget);
    });
  });
}
