import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:gel_rule_app/backend/backend.dart';
import 'package:gel_rule_app/core/utils/result.dart';

class ArtistPostsArgs {
  const ArtistPostsArgs({
    required this.providerId,
    required this.artistName,
    required this.queryTag,
  });

  final String providerId;
  final String artistName;
  final String queryTag;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ArtistPostsArgs &&
          runtimeType == other.runtimeType &&
          providerId == other.providerId &&
          artistName == other.artistName &&
          queryTag == other.queryTag;

  @override
  int get hashCode => Object.hash(providerId, artistName, queryTag);
}

/// Fetches up to 6 recent posts from the same artist.
final artistPostsProvider = FutureProvider.autoDispose
    .family<List<Post>, ArtistPostsArgs>((ref, args) async {
  if (args.queryTag.isEmpty && args.artistName.isEmpty) return const [];
  final result = await ref.watch(feedServiceProvider).refresh(
    tags: [args.queryTag],
    providerId: args.providerId,
    limit: 12,
  );
  if (result is! Success<List<Post>>) {
    // If querying with 'artist:xyz' failed on another provider, try plain name fallback
    if (args.artistName.isNotEmpty && args.queryTag != args.artistName) {
      final fallback = await ref.watch(feedServiceProvider).refresh(
        tags: [args.artistName],
        providerId: args.providerId,
        limit: 12,
      );
      if (fallback is Success<List<Post>>) {
        return fallback.data;
      }
    }
    return const [];
  }
  return result.data;
});

class ArtistPostsCard extends ConsumerWidget {
  const ArtistPostsCard({
    required this.post,
    this.onOpenPost,
    super.key,
  });

  final Post post;
  final void Function(Post post, List<Post> contextList)? onOpenPost;

  static ({String name, String queryTag})? extractArtist(Post post) {
    final rawArtists = post.tagGroups['artist'] ??
        post.tags
            .where((t) => t.startsWith('artist:') || t.startsWith('creator:'))
            .map((t) =>
                t.replaceFirst('artist:', '').replaceFirst('creator:', ''))
            .toList();
    if (rawArtists.isEmpty) return null;

    const nonArtistTags = {
      'conditional_dnp',
      'avoid_posting',
      'soundless',
      'third_party_edit',
      'unknown_artist',
      'anonymous_artist',
    };

    final realArtists = rawArtists
        .where((a) => !nonArtistTags.contains(a.toLowerCase()))
        .toList();
    final artistName =
        realArtists.isNotEmpty ? realArtists.first : rawArtists.first;
    if (nonArtistTags.contains(artistName.toLowerCase())) return null;

    final isE621 = post.providerId == 'e621' || post.providerId == 'e926';
    final queryTag = isE621 ? artistName : 'artist:$artistName';
    return (name: artistName, queryTag: queryTag);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final artistInfo = extractArtist(post);
    if (artistInfo == null) return const SizedBox.shrink();

    final artistPosts = ref.watch(
      artistPostsProvider(
        ArtistPostsArgs(
          providerId: post.providerId,
          artistName: artistInfo.name,
          queryTag: artistInfo.queryTag,
        ),
      ),
    );
    final isRu = Localizations.maybeLocaleOf(context)?.languageCode == 'ru';
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final artistName = artistInfo.name;

    return artistPosts.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (posts) {
        if (posts.isEmpty) return const SizedBox.shrink();
        // exclude the current post, keep matching provider, take up to 6 photos
        final filtered = posts
            .where((p) => p.id != post.id && p.providerId == post.providerId)
            .take(6)
            .toList();
        if (filtered.isEmpty) return const SizedBox.shrink();

        return Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Container(
            decoration: BoxDecoration(
              color: isDark
                  ? scheme.surfaceContainerHigh.withValues(alpha: 0.70)
                  : scheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.12)
                    : scheme.outlineVariant.withValues(alpha: 0.40),
                width: 1.1,
              ),
            ),
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.palette_rounded,
                        size: 18, color: scheme.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        isRu ? 'Ещё от $artistName' : 'More by $artistName',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    InkWell(
                      onTap: () => context.push(
                        '/search?q=${Uri.encodeComponent(artistInfo.queryTag)}',
                      ),
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              isRu ? 'Все' : 'See all',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: scheme.primary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 3),
                            Icon(Icons.arrow_forward_ios_rounded,
                                size: 11, color: scheme.primary),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 110,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final p = filtered[index];
                      final isVideo = p.fileType.toLowerCase() == 'video' ||
                          p.fileUrl.endsWith('.mp4') ||
                          p.fileUrl.endsWith('.webm');
                      return InkWell(
                        onTap: () {
                          if (onOpenPost != null) {
                            onOpenPost!(p, filtered);
                          }
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: CachedNetworkImage(
                                imageUrl: p.previewUrl.isNotEmpty
                                    ? p.previewUrl
                                    : p.sampleUrl,
                                width: 110,
                                height: 110,
                                fit: BoxFit.cover,
                                memCacheWidth: 220,
                                memCacheHeight: 220,
                                errorWidget: (_, __, ___) => Container(
                                  width: 110,
                                  height: 110,
                                  color: scheme.surfaceContainerHigh,
                                  child: Icon(Icons.broken_image_rounded,
                                      color: scheme.onSurfaceVariant),
                                ),
                              ),
                            ),
                            if (isVideo)
                              Positioned(
                                right: 6,
                                bottom: 6,
                                child: Container(
                                  padding: const EdgeInsets.all(3),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.65),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Icon(
                                    Icons.play_arrow_rounded,
                                    size: 14,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
