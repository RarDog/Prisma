import 'package:flutter/material.dart';

import 'package:prisma_app/app/app_strings.dart';
import 'package:prisma_app/backend/backend.dart';
import 'package:prisma_app/sources/booru/e621_provider.dart';
import 'cloud_mirrors_card.dart';
import 'comments_section.dart';
import 'post_action_bar.dart';
import 'post_artist_posts_card.dart';
import 'post_info_card.dart';
import 'post_pools_card.dart';
import 'post_relations_card.dart';
import 'post_tags_panel.dart';

class PostDetailsMetadataSection extends StatelessWidget {
  const PostDetailsMetadataSection({
    super.key,
    required this.post,
    required this.targetPost,
    required this.settings,
    required this.strings,
    required this.labels,
    required this.isFavorite,
    required this.downloaded,
    required this.isDownloading,
    required this.localMedia,
    required this.fileSizeBytes,
    required this.e621Provider,
    required this.shouldShowCloudCard,
    required this.isTextOnly,
    this.isMobile = false,
    required this.onFavorite,
    required this.onCollection,
    required this.onOpen,
    required this.onOpenSource,
    required this.onCopy,
    required this.onSimilar,
    required this.onHide,
    this.onDownload,
    this.onSaveAs,
    required this.onDeleteLocalFile,
    required this.onShare,
    required this.onOpenArtistPost,
    required this.onOpenPostId,
    required this.onOpenComic,
    required this.onPlayStream,
    this.onDownloadStream,
  });

  final Post post;
  final Post targetPost;
  final AppSettings settings;
  final AppStrings strings;
  final PostActionLabels labels;
  final bool isFavorite;
  final bool downloaded;
  final bool isDownloading;
  final DownloadedMedia? localMedia;
  final int? fileSizeBytes;
  final E621Provider? e621Provider;
  final bool shouldShowCloudCard;
  final bool isTextOnly;
  final bool isMobile;

  final VoidCallback onFavorite;
  final VoidCallback onCollection;
  final VoidCallback onOpen;
  final VoidCallback onOpenSource;
  final VoidCallback onCopy;
  final VoidCallback onSimilar;
  final VoidCallback onHide;
  final VoidCallback? onDownload;
  final VoidCallback? onSaveAs;
  final VoidCallback onDeleteLocalFile;
  final VoidCallback onShare;
  final void Function(Post post, List<Post> filtered) onOpenArtistPost;
  final void Function(String targetId) onOpenPostId;
  final void Function(String poolId, Post currentPost, [String? targetId])
      onOpenComic;
  final void Function(String streamUrl) onPlayStream;
  final void Function(String streamUrl)? onDownloadStream;

  @override
  Widget build(BuildContext context) {
    final gap = SizedBox(height: isMobile ? 12 : 16);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PostActionBar(
          isFavorite: isFavorite,
          labels: labels,
          downloaded: downloaded,
          isDownloading: isDownloading,
          onFavorite: onFavorite,
          onCollection: onCollection,
          onOpen: onOpen,
          onOpenSource: onOpenSource,
          onCopy: onCopy,
          onSimilar: onSimilar,
          onHide: onHide,
          onDownload: onDownload,
          onSaveAs: onSaveAs,
          onDeleteLocalFile: onDeleteLocalFile,
          onShare: onShare,
        ),
        gap,
        PostInfoCard(
          post: post,
          strings: strings,
          localMedia: localMedia,
          fileSizeBytes: fileSizeBytes,
          e621Provider: e621Provider,
        ),
        gap,
        ArtistPostsCard(
          post: post,
          onOpenPost: onOpenArtistPost,
        ),
        if (post.hasRelations) ...[
          gap,
          PostRelationsCard(
            post: post,
            onOpenPostId: onOpenPostId,
          ),
        ],
        if (post.hasPools && e621Provider != null) ...[
          gap,
          PostPoolsCard(
            post: post,
            provider: e621Provider!,
            onOpenComic: onOpenComic,
            onOpenPostId: onOpenPostId,
          ),
        ],
        if (shouldShowCloudCard) ...[
          gap,
          CloudMirrorsCard(
            links: post.cloudLinks,
            strings: strings,
            commentary: isTextOnly ? null : post.commentary,
            onPlayStream: onPlayStream,
            onDownloadStream: onDownloadStream,
          ),
        ],
        gap,
        if (isMobile)
          Container(
            decoration: BoxDecoration(
              color: isDark
                  ? theme.colorScheme.surfaceContainerHigh
                      .withValues(alpha: 0.70)
                  : theme.colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.12)
                    : theme.colorScheme.outlineVariant
                        .withValues(alpha: 0.40),
                width: 1.1,
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: ExpansionTile(
              tilePadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
              childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              initiallyExpanded: false,
              shape: const Border(),
              collapsedShape: const Border(),
              leading: Icon(
                Icons.tag_rounded,
                color: theme.colorScheme.primary,
              ),
              title: Text(
                '${strings.tags} (${post.cleanTags.length})',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: PostTagsPanel(post: post),
                ),
              ],
            ),
          )
        else
          Container(
            decoration: BoxDecoration(
              color: isDark
                  ? theme.colorScheme.surfaceContainerHigh
                      .withValues(alpha: 0.70)
                  : theme.colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.12)
                    : theme.colorScheme.outlineVariant
                        .withValues(alpha: 0.40),
                width: 1.1,
              ),
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.tag_rounded,
                      size: 20,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${strings.tags} (${post.cleanTags.length})',
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                PostTagsPanel(post: post),
              ],
            ),
          ),
        gap,
        CommentsSection(post: post),
      ],
    );
  }
}
