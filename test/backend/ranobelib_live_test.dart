@Tags(['network'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:gel_rule_app/core/http/dio_client.dart';
import 'package:gel_rule_app/sources/manga/ranobelib_provider.dart';

/// Live smoke test against the real RanobeLib API.
///
/// Tagged `network`, so a plain `flutter test` run skips it (see
/// `dart_test.yaml`): upstream outages and catalog edits must not turn a
/// local or CI run red. Run it on demand with:
///
/// ```bash
/// flutter test --tags network --run-skipped
/// ```
///
/// Parsing rules are covered deterministically by `ranobelib_test.dart`.
void main() {
  final client = DioClient();
  final provider = RanobeLibProvider(
    id: 'ranobelib',
    name: 'RanobeLib',
    baseUrl: 'https://api.cdnlibs.org/api',
    dioClient: client,
  );
  tearDownAll(client.close);

  test('catalog is reachable and yields novels', () async {
    final posts = await provider.searchPosts(tags: const [], page: 0);

    expect(
      posts,
      isNotEmpty,
      reason: 'RanobeLib catalog returned no novels — upstream may be down or '
          'the API shape changed.',
    );
    final post = posts.first;
    expect(post.providerId, 'ranobelib');
    expect(post.id, isNotEmpty);
    expect(post.previewUrl, isNotEmpty);
    expect(post.tagGroups['title']?.firstOrNull, isNotEmpty);
  });

  test('a novel exposes chapters and readable chapter text', () async {
    final posts = await provider.searchPosts(tags: const [], page: 0);
    expect(posts, isNotEmpty, reason: 'No novels to inspect.');

    final novel = posts.first;
    final chapters = await provider.fetchChapters(novel.id);

    expect(
      chapters,
      isNotEmpty,
      reason: 'Novel ${novel.id} returned no chapters — upstream may have '
          'moved or dropped it.',
    );

    final content = await provider.fetchChapterContent(chapters.first.id);
    expect(
      content.trim(),
      isNotEmpty,
      reason: 'Chapter ${chapters.first.id} returned empty text.',
    );
  });
}
