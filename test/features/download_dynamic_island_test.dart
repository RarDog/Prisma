import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gel_rule_app/app/app.dart';
import 'package:gel_rule_app/app/app_strings.dart';
import 'package:gel_rule_app/backend/backend.dart';
import 'package:gel_rule_app/features/downloads/presentation/widgets/download_dynamic_island.dart';

class _FakeDownloadManagerService extends DownloadManagerService {
  _FakeDownloadManagerService()
      : super(
          DownloadService(),
        );

  bool pauseCalled = false;
  bool resumeCalled = false;
  String? canceledId;

  @override
  bool get queuePaused => false;

  @override
  void pauseQueue() {
    pauseCalled = true;
  }

  @override
  void resumeQueue() {
    resumeCalled = true;
  }

  @override
  void cancel(String taskId) {
    canceledId = taskId;
  }
}

void main() {
  testWidgets('DownloadDynamicIsland renders collapsed pill and expands on tap',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final task = DownloadTask(
      id: 'task-1',
      fileName: 'art_sample_123.jpg',
      progress: 0.65,
      status: DownloadTaskStatus.running,
      post: Post(
        id: '123',
        providerId: 'gelbooru',
        providerName: 'Gelbooru',
        rating: 'general',
        fileUrl: 'https://example.com/art.jpg',
        previewUrl: 'https://example.com/art_thumb.jpg',
        sampleUrl: 'https://example.com/art_sample.jpg',
        width: 1000,
        height: 1000,
        tags: const ['miku', 'solo'],
        createdAt: DateTime(2026, 1, 1),
        fileType: 'jpg',
        score: 100,
      ),
    );

    final fakeManager = _FakeDownloadManagerService();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appStringsProvider.overrideWithValue(const AppStrings('ru')),
          downloadManagerServiceProvider.overrideWithValue(fakeManager),
          downloadTasksProvider.overrideWith((ref) => Stream.value([task])),
        ],
        child: const MaterialApp(
          locale: Locale('ru'),
          home: Scaffold(
            body: DownloadDynamicIslandOverlay(
              child: Center(child: Text('Main Screen')),
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify main screen and collapsed Dynamic Island presence
    expect(find.text('Main Screen'), findsOneWidget);
    expect(find.textContaining('65%'), findsOneWidget);

    // Tap to expand Dynamic Island
    await tester.tap(find.byType(DownloadDynamicIsland));
    await tester.pumpAndSettle();

    // Verify detailed queue card elements
    expect(find.textContaining('art_sample_123.jpg'), findsOneWidget);
    expect(find.byIcon(Icons.pause_rounded), findsOneWidget);

    // Tap pause button
    await tester.tap(find.byIcon(Icons.pause_rounded));
    await tester.pumpAndSettle();
    expect(fakeManager.pauseCalled, isTrue);

    // Tap cancel button for task
    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pumpAndSettle();
    expect(fakeManager.canceledId, equals('task-1'));
  });

  testWidgets('DownloadDynamicIsland renders completed task state',
      (tester) async {
    final task = DownloadTask(
      id: 'task-completed',
      fileName: 'completed_art.png',
      progress: 1.0,
      status: DownloadTaskStatus.completed,
    );

    final fakeManager = _FakeDownloadManagerService();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appStringsProvider.overrideWithValue(const AppStrings('ru')),
          downloadManagerServiceProvider.overrideWithValue(fakeManager),
          downloadTasksProvider.overrideWith((ref) => Stream.value([task])),
        ],
        child: const MaterialApp(
          locale: Locale('ru'),
          home: Scaffold(
            body: DownloadDynamicIslandOverlay(
              child: Center(child: Text('Main Screen')),
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.textContaining('Скачано'), findsOneWidget);
  });
}
