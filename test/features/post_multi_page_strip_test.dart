import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gel_rule_app/core/models/post.dart';
import 'package:gel_rule_app/features/post/presentation/widgets/post_multi_page_strip.dart';

void main() {
  testWidgets('PostMultiPageStrip renders pages, counters, and arrows switch pages', (tester) async {
    final page0 = Post(
      id: '100',
      providerId: 'pixiv',
      providerName: 'Pixiv',
      previewUrl: '',
      sampleUrl: '',
      fileUrl: '',
      tags: const [],
      rating: 's',
      width: 100,
      height: 100,
      createdAt: DateTime(2026),
      fileType: 'jpg',
      score: 1,
      tagGroups: const {'page_count': ['3']},
    );
    final page1 = page0.copyWith(id: '100_p1');
    final page2 = page0.copyWith(id: '100_p2');
    final pages = [page0, page1, page2];

    int selectedIdx = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              return PostMultiPageStrip(
                pages: pages,
                currentIndex: selectedIdx,
                onPageSelected: (idx) {
                  setState(() => selectedIdx = idx);
                },
              );
            },
          ),
        ),
      ),
    );

    // Initial state: page 1 of 3
    expect(find.textContaining('1/3'), findsOneWidget);
    expect(find.byIcon(Icons.chevron_left_rounded), findsOneWidget);
    expect(find.byIcon(Icons.chevron_right_rounded), findsOneWidget);

    // Tap right arrow
    await tester.tap(find.byIcon(Icons.chevron_right_rounded));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(selectedIdx, equals(1));
    expect(find.textContaining('2/3'), findsOneWidget);

    // Tap left arrow
    await tester.tap(find.byIcon(Icons.chevron_left_rounded));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(selectedIdx, equals(0));
    expect(find.textContaining('1/3'), findsOneWidget);
  });
}
