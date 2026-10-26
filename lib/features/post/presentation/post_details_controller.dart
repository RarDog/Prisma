import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:prisma_app/backend/backend.dart';
import 'package:prisma_app/core/utils/result.dart';

// Stream the fastest available post version first, then enrich it.
final postDetailsControllerProvider =
    StreamProvider.family<Post?, PostDetailsArgs>((ref, args) async* {
  final providerManager = ref.watch(providerManagerProvider);
  final cacheService = ref.watch(cacheServiceProvider);
  final postRepository = ref.watch(postRepositoryProvider);

  bool needsRealbooruDetails(Post post) {
    if (post.providerId != 'realbooru' && post.providerId != 'rule34_us') {
      return false;
    }
    if (post.tagGroups.containsKey('is_detailed')) return false;
    final hasCategorizedGroups = post.tagGroups.entries.any(
      (entry) => entry.key != 'general' && entry.value.isNotEmpty,
    );
    return post.fileUrl.isEmpty ||
        post.fileUrl == post.previewUrl ||
        post.tagGroups.isEmpty ||
        !hasCategorizedGroups;
  }

  bool needsPixivEnrichment(Post post) {
    if (post.providerId != 'pixiv') return false;
    if (post.fileType == 'ugoira') return false;
    return !post.fileUrl.contains('img-original') ||
        post.fileUrl.contains('img-master') ||
        post.fileUrl.contains('square1200');
  }

  bool needsXVideosDetails(Post post) {
    if (post.providerId != 'xvideos') return false;
    if (post.tagGroups.containsKey('is_detailed')) return false;
    return post.fileUrl.isEmpty ||
        post.fileUrl == post.previewUrl ||
        !post.fileUrl.contains('.mp4');
  }

  Future<Post?> enrich(Post? post) async {
    if (post == null) return null;
    if (needsRealbooruDetails(post) ||
        needsPixivEnrichment(post) ||
        needsXVideosDetails(post)) {
      final remote = await providerManager.getPost(post.providerId, post.id);
      if (remote is Success<Post?> && remote.data != null) {
        await cacheService.cachePosts([remote.data!]);
        return remote.data!;
      }
    }
    final shouldEnrich = post.tagGroups.isEmpty ||
        (post.tagGroups.length == 1 && post.tagGroups.containsKey('general'));
    if (!shouldEnrich) return post;

    final enriched = await providerManager.enrichPostTags(post);
    if (enriched is Success<Post>) {
      await cacheService.cachePosts([enriched.data]);
      return enriched.data;
    }
    return post;
  }

  // Scenario 1: feed navigation already passed the post.
  if (args.initialPost != null) {
    yield args.initialPost;
    final enriched = await enrich(args.initialPost);
    yield enriched;
    return;
  }

  // Scenario 2: direct navigation can use the local cache first.
  final cached =
      await postRepository.getCachedPost(args.postId, args.providerId);
  if (cached is Success<Post?> && cached.data != null) {
    yield cached.data;
    final enriched = await enrich(cached.data);
    yield enriched;
    return;
  }

  // Scenario 3: fall back to the provider when nothing local is available.
  final remote = await providerManager.getPost(args.providerId, args.postId);
  if (remote is Success<Post?> && remote.data != null) {
    yield remote.data;
    final enriched = await enrich(remote.data);
    yield enriched;
  } else {
    yield null;
  }
});

class PostDetailsArgs {
  const PostDetailsArgs({
    required this.providerId,
    required this.postId,
    this.initialPost,
  });

  final String providerId;
  final String postId;
  final Post? initialPost;

  @override
  bool operator ==(Object other) {
    return other is PostDetailsArgs &&
        other.providerId == providerId &&
        other.postId == postId &&
        other.initialPost == initialPost;
  }

  @override
  int get hashCode => Object.hash(providerId, postId, initialPost);
}
