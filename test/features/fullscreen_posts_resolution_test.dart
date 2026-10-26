import 'package:flutter_test/flutter_test.dart';
import 'package:prisma_app/core/models/post.dart';
import 'package:prisma_app/features/post/presentation/widgets/post_media_viewer.dart';

Post _post(String id, {String providerId = 'fapello'}) => Post(
      id: id,
      providerId: providerId,
      providerName: providerId,
      previewUrl: 'https://example.com/$id-preview.jpg',
      sampleUrl: 'https://example.com/$id-sample.jpg',
      fileUrl: 'https://example.com/$id-file.jpg',
      tags: const [],
      rating: 'explicit',
      width: 0,
      height: 0,
      createdAt: DateTime.utc(2026),
      fileType: 'image',
      score: 0,
    );

/// The feed, as it holds After the Posts tab has been visited. It is a global
/// provider that never auto-disposes, so it survives the whole navigation.
final List<Post> _liveFeed = [
  _post('feed-1', providerId: 'gelbooru'),
  _post('feed-2', providerId: 'gelbooru'),
  _post('feed-3', providerId: 'gelbooru'),
];

final List<Post> _artistPosts = [
  _post('artist-1'),
  _post('artist-2'),
];

void main() {
  group('resolveFullscreenPosts', () {
    test('a gallery opened outside the feed keeps its own list', () {
      // The bug: the feed was longer than the artist list, so the gallery
      // swapped in the feed and showed the wrong posts.
      final resolved = resolveFullscreenPosts(
        posts: _artistPosts,
        liveFeed: _liveFeed,
        currentIndex: 0,
        useLiveFeed: false,
      );

      expect(resolved, same(_artistPosts));
      expect(resolved.map((p) => p.id), ['artist-1', 'artist-2']);
    });

    test('a gallery opened from the feed tracks the live feed', () {
      final resolved = resolveFullscreenPosts(
        posts: [..._liveFeed, _post('feed-4', providerId: 'gelbooru')],
        liveFeed: _liveFeed,
        currentIndex: 0,
        useLiveFeed: true,
      );

      expect(resolved, same(_liveFeed));
    });

    test('it falls back to its own list when the post left the feed', () {
      // The user paged away from the feed's own posts; resetting to the feed
      // now would jump them somewhere unrelated.
      final resolved = resolveFullscreenPosts(
        posts: _artistPosts,
        liveFeed: _liveFeed,
        currentIndex: 1,
        useLiveFeed: true,
      );

      expect(resolved, same(_artistPosts));
    });

    test('an unset live feed never replaces the given list', () {
      expect(
        resolveFullscreenPosts(
          posts: _artistPosts,
          liveFeed: null,
          currentIndex: 0,
          useLiveFeed: true,
        ),
        same(_artistPosts),
      );
      expect(
        resolveFullscreenPosts(
          posts: _artistPosts,
          liveFeed: const [],
          currentIndex: 0,
          useLiveFeed: true,
        ),
        same(_artistPosts),
      );
    });

    test('an out-of-range index falls back instead of throwing', () {
      expect(
        resolveFullscreenPosts(
          posts: _artistPosts,
          liveFeed: _liveFeed,
          currentIndex: 99,
          useLiveFeed: true,
        ),
        same(_artistPosts),
      );
    });

    test('a feed that merely outgrew the list cannot win', () {
      // Regression guard for the old `feedPosts.length >= posts.length` clause.
      expect(_liveFeed.length, greaterThan(_artistPosts.length));
      final resolved = resolveFullscreenPosts(
        posts: _artistPosts,
        liveFeed: _liveFeed,
        currentIndex: 0,
        useLiveFeed: false,
      );
      expect(resolved, same(_artistPosts));
    });
  });
}
