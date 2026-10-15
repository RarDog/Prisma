import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gel_rule_app/backend/backend.dart';
import 'package:gel_rule_app/core/cache/cache_service.dart';
import 'package:gel_rule_app/core/utils/result.dart';
import 'package:gel_rule_app/features/post/presentation/post_details_controller.dart';

Post _post(String id, {String providerId = 'gelbooru'}) => Post(
      id: id,
      providerId: providerId,
      providerName: providerId,
      previewUrl: 'https://example.com/$id-preview.jpg',
      sampleUrl: 'https://example.com/$id-sample.jpg',
      fileUrl: 'https://example.com/$id-file.jpg',
      tags: const ['solo'],
      rating: 'general',
      width: 0,
      height: 0,
      createdAt: DateTime(2026, 1, 1),
      fileType: 'image',
      score: 0,
    );

class _FakePostRepository extends Fake implements PostRepository {
  _FakePostRepository({this.cached});

  final Post? cached;

  @override
  Future<Result<Post?>> getCachedPost(String postId, String providerId) async {
    if (cached == null) return const Success(null);
    final matches = cached!.id == postId && cached!.providerId == providerId;
    return Success(matches ? cached : null);
  }
}

class _FakeProviderManager extends Fake implements ProviderManager {
  _FakeProviderManager({this.remote});

  final Post? remote;

  @override
  Future<Result<Post?>> getPost(String providerId, String postId) async =>
      Success(remote);

  @override
  Future<Result<Post>> enrichPostTags(Post post) async {
    if (post.tagGroups.isNotEmpty) return Success(post);
    return Success(Post(
      id: post.id,
      providerId: post.providerId,
      providerName: post.providerName,
      previewUrl: post.previewUrl,
      sampleUrl: post.sampleUrl,
      fileUrl: post.fileUrl,
      tags: post.tags,
      rating: post.rating,
      width: post.width,
      height: post.height,
      createdAt: post.createdAt,
      fileType: post.fileType,
      score: post.score,
      tagGroups: const {
        'general': ['solo']
      },
    ));
  }
}

class _FakeCacheService extends Fake implements CacheService {
  final List<Post> cached = [];

  @override
  Future<Result<void>> cachePosts(
    List<Post> posts, {
    int? maxItems = 500,
  }) async {
    cached.addAll(posts);
    return const Success(null);
  }
}

/// Reads the last emission of a provider-scoped stream, which is what the
/// post-details screen actually renders.
Future<Post?> _settle(ProviderContainer container, PostDetailsArgs args) async {
  await container.read(postDetailsControllerProvider(args).future);
  await pumpEventQueue();
  return container.read(postDetailsControllerProvider(args)).valueOrNull;
}

void main() {
  test('falls back to the provider and enriches it when there is no cache',
      () async {
    final cache = _FakeCacheService();
    final container = ProviderContainer(
      overrides: [
        postRepositoryProvider.overrideWithValue(
            _FakePostRepository(cached: _post('cached', providerId: 'other'))),
        providerManagerProvider
            .overrideWithValue(_FakeProviderManager(remote: _post('remote'))),
        cacheServiceProvider.overrideWithValue(cache),
      ],
    );
    addTearDown(container.dispose);

    const args = PostDetailsArgs(
      providerId: 'gelbooru',
      postId: 'remote',
    );
    final first =
        await container.read(postDetailsControllerProvider(args).future);

    expect(first?.id, 'remote');
    await pumpEventQueue();
    // The cache is re-populated with the enriched post so the next open is fast.
    expect(cache.cached.map((p) => p.id), contains('remote'));
  });

  test('prefers the initial post handed down by the navigation', () async {
    final container = ProviderContainer(
      overrides: [
        postRepositoryProvider.overrideWithValue(_FakePostRepository()),
        providerManagerProvider.overrideWithValue(_FakeProviderManager()),
        cacheServiceProvider.overrideWithValue(_FakeCacheService()),
      ],
    );
    addTearDown(container.dispose);

    final initial = _post('initial');
    final args = PostDetailsArgs(
      providerId: 'gelbooru',
      postId: 'initial',
      initialPost: initial,
    );
    final post = await _settle(container, args);
    expect(post, isNotNull);
    expect(post!.id, 'initial');
  });

  test('yields null when nothing is known about the post', () async {
    final container = ProviderContainer(
      overrides: [
        postRepositoryProvider.overrideWithValue(_FakePostRepository()),
        providerManagerProvider
            .overrideWithValue(_FakeProviderManager(remote: null)),
        cacheServiceProvider.overrideWithValue(_FakeCacheService()),
      ],
    );
    addTearDown(container.dispose);

    const args = PostDetailsArgs(
      providerId: 'gelbooru',
      postId: 'missing',
    );
    final post = await _settle(container, args);
    expect(post, isNull);
  });
}
