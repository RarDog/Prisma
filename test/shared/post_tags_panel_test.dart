import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gel_rule_app/core/models/post.dart';
import 'package:gel_rule_app/features/post/presentation/widgets/post_tags_panel.dart';
import 'package:go_router/go_router.dart';

void main() {
  testWidgets('post tags panel renders category blocks with wrapping chips',
      (tester) async {
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, __) => Scaffold(
            body: PostTagsPanel(
              post: _post(
                tagGroups: {
                  'artist': ['artist_name'],
                  'character': ['hero'],
                  'general': List.generate(30, (index) => 'tag_$index'),
                },
              ),
            ),
          ),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp.router(routerConfig: router),
      ),
    );

    expect(find.text('Artist / Creator'), findsOneWidget);
    expect(find.text('Characters'), findsOneWidget);
    expect(find.text('General'), findsOneWidget);
    expect(find.text('artist_name'), findsOneWidget);
    expect(find.text('hero'), findsOneWidget);
    expect(find.text('tag_0'), findsOneWidget);
    expect(find.text('+'), findsNothing);
  });

  testWidgets(
      'post tags panel orders artist -> copyright -> character -> general and deduplicates',
      (tester) async {
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, __) => Scaffold(
            body: SingleChildScrollView(
              child: PostTagsPanel(
                post: _post(
                  tagGroups: {
                    'character': ['hero_char'],
                    'artist': ['cool_artist'],
                    'copyright': ['cool_fandom'],
                    // Simulate uncleaned general containing duplicates
                    'general': [
                      'cool_artist',
                      'cool_fandom',
                      'hero_char',
                      'solo',
                    ],
                  },
                ),
              ),
            ),
          ),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp.router(routerConfig: router),
      ),
    );

    final artistPos = tester.getTopLeft(find.text('Artist / Creator'));
    final copyrightPos = tester.getTopLeft(find.text('Copyright / Fandom'));
    final characterPos = tester.getTopLeft(find.text('Characters'));
    final generalPos = tester.getTopLeft(find.text('General'));

    expect(artistPos.dy, lessThan(copyrightPos.dy));
    expect(copyrightPos.dy, lessThan(characterPos.dy));
    expect(characterPos.dy, lessThan(generalPos.dy));

    // Each tag appears only once (not duplicated into General)
    expect(find.text('cool_artist'), findsOneWidget);
    expect(find.text('cool_fandom'), findsOneWidget);
    expect(find.text('hero_char'), findsOneWidget);
    expect(find.text('solo'), findsOneWidget);
  });
}

Post _post({required Map<String, List<String>> tagGroups}) {
  return Post(
    id: '1',
    providerId: 'test',
    providerName: 'Test',
    previewUrl: 'https://example.test/preview.jpg',
    sampleUrl: 'https://example.test/sample.jpg',
    fileUrl: 'https://example.test/file.jpg',
    tags: const [],
    rating: 'general',
    width: 100,
    height: 100,
    createdAt: DateTime(2026),
    fileType: 'photo',
    score: 1,
    tagGroups: tagGroups,
  );
}
