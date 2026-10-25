import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:gel_rule_app/app/app_strings.dart';
import 'package:gel_rule_app/backend/backend.dart';
import 'package:gel_rule_app/features/feed/presentation/feed_controller.dart';
import 'package:gel_rule_app/shared/widgets/keyboard_shortcut_utils.dart';
import 'package:gel_rule_app/sources/booru/e621_provider.dart';
import 'post_action_bar.dart';
import 'post_details_intents.dart';
import 'post_details_metadata_section.dart';
import 'post_media_carousel.dart';
import 'post_media_viewer.dart';
import 'post_multi_page_strip.dart';
import 'post_translate_button.dart';

class PostDetailsDesktopLayout extends ConsumerWidget {
  const PostDetailsDesktopLayout({
    super.key,
    required this.post,
    required this.targetPost,
    required this.previous,
    required this.next,
    required this.pages,
    required this.isMultiPage,
    required this.currentPostIndex,
    required this.feedPosts,
    required this.settings,
    required this.strings,
    required this.labels,
    required this.favoriteKeys,
    required this.localMedia,
    required this.fileSizeBytes,
    required this.isDownloading,
    required this.qualityMode,
    required this.notes,
    required this.notesAsync,
    required this.showNotes,
    required this.e621Provider,
    required this.shouldShowCloudCard,
    required this.isTextOnly,
    required this.fromFeed,
    required this.onOpenPost,
    required this.onToggleFavorite,
    required this.onAddToCollection,
    required this.onClose,
    this.onDownload,
    this.onSaveAs,
    required this.onDeleteLocalFile,
    required this.onShare,
    required this.onOpenSource,
    required this.onOpenSimilar,
    required this.onHidePost,
    required this.onPageSelected,
    this.onDownloadAllPages,
    required this.onOpenArtistPost,
    required this.onOpenPostId,
    required this.onOpenComic,
    required this.onPlayStream,
    this.onDownloadStream,
    required this.onToggleNotes,
    required this.onVolumeChanged,
    required this.onPlaybackSnapshot,
    required this.onPlaybackPreferencesChanged,
    this.onLoadMore,
  });

  final Post post;
  final Post targetPost;
  final Post? previous;
  final Post? next;
  final List<Post> pages;
  final bool isMultiPage;
  final int currentPostIndex;
  final List<Post> feedPosts;
  final AppSettings settings;
  final AppStrings strings;
  final PostActionLabels labels;
  final Set<String> favoriteKeys;
  final DownloadedMedia? localMedia;
  final int? fileSizeBytes;
  final bool isDownloading;
  final MediaQualityMode qualityMode;
  final List<PostNote> notes;
  final AsyncValue<List<PostNote>> notesAsync;
  final bool showNotes;
  final E621Provider? e621Provider;
  final bool shouldShowCloudCard;
  final bool isTextOnly;
  final bool fromFeed;

  final void Function(Post post) onOpenPost;
  final VoidCallback onToggleFavorite;
  final VoidCallback onAddToCollection;
  final VoidCallback onClose;
  final VoidCallback? onDownload;
  final VoidCallback? onSaveAs;
  final VoidCallback onDeleteLocalFile;
  final VoidCallback onShare;
  final VoidCallback onOpenSource;
  final VoidCallback onOpenSimilar;
  final VoidCallback onHidePost;
  final ValueChanged<int> onPageSelected;
  final VoidCallback? onDownloadAllPages;
  final void Function(Post post, List<Post> filtered) onOpenArtistPost;
  final void Function(String targetId) onOpenPostId;
  final void Function(String poolId, Post currentPost, [String? targetId])
      onOpenComic;
  final void Function(String streamUrl) onPlayStream;
  final void Function(String streamUrl)? onDownloadStream;
  final VoidCallback onToggleNotes;
  final ValueChanged<double> onVolumeChanged;
  final void Function(VideoPlaybackSnapshot snapshot) onPlaybackSnapshot;
  final void Function(VideoPlaybackSnapshot snapshot)
      onPlaybackPreferencesChanged;
  final VoidCallback? onLoadMore;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final basePostId = post.id.split('_p').first;
    final currentIndex = feedPosts.indexWhere(
      (item) =>
          item.providerId == post.providerId &&
          (item.id == post.id || item.id == basePostId),
    );

    return Shortcuts(
      shortcuts: {
        LogicalKeySet(LogicalKeyboardKey.arrowLeft): const PreviousPostIntent(),
        LogicalKeySet(LogicalKeyboardKey.keyA): const PreviousPostIntent(),
        LogicalKeySet(LogicalKeyboardKey.arrowRight): const NextPostIntent(),
        LogicalKeySet(LogicalKeyboardKey.keyD): const NextPostIntent(),
        LogicalKeySet(LogicalKeyboardKey.keyF): const ToggleFavoriteIntent(),
        LogicalKeySet(LogicalKeyboardKey.keyC): const AddCollectionIntent(),
        LogicalKeySet(LogicalKeyboardKey.keyS): const DownloadIntent(),
        LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyS):
            const DownloadIntent(),
        LogicalKeySet(LogicalKeyboardKey.escape): const CloseIntent(),
      },
      child: Actions(
        actions: {
          PreviousPostIntent: NonTextInputAction<PreviousPostIntent>(
            onInvoke: (_) {
              if (previous != null) onOpenPost(previous!);
              return null;
            },
          ),
          NextPostIntent: NonTextInputAction<NextPostIntent>(
            onInvoke: (_) {
              if (next != null) onOpenPost(next!);
              return null;
            },
          ),
          ToggleFavoriteIntent: NonTextInputAction<ToggleFavoriteIntent>(
            onInvoke: (_) {
              onToggleFavorite();
              return null;
            },
          ),
          AddCollectionIntent: NonTextInputAction<AddCollectionIntent>(
            onInvoke: (_) {
              onAddToCollection();
              return null;
            },
          ),
          CloseIntent: NonTextInputAction<CloseIntent>(
            onInvoke: (_) {
              onClose();
              return null;
            },
          ),
          DownloadIntent: NonTextInputAction<DownloadIntent>(
            onInvoke: (_) {
              if (settings.allowDownloads) {
                onDownload?.call();
              }
              return null;
            },
          ),
        },
        child: Focus(
          autofocus: true,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  IconButton.filledTonal(
                    tooltip: strings.ru ? 'Предыдущий' : 'Previous',
                    onPressed:
                        previous == null ? null : () => onOpenPost(previous!),
                    icon: const Icon(Icons.chevron_left_rounded),
                  ),
                  Expanded(
                    child: Center(
                      child: (MediaUrlSelector.isVideo(targetPost) ||
                              MediaUrlSelector.isAudio(targetPost))
                          ? ConstrainedBox(
                              constraints: BoxConstraints(
                                maxHeight: MediaUrlSelector.isAudio(targetPost)
                                    ? 360
                                    : 760,
                                maxWidth: MediaUrlSelector.isAudio(targetPost)
                                    ? 620
                                    : double.infinity,
                              ),
                              child: AspectRatio(
                                aspectRatio: MediaUrlSelector.isAudio(targetPost)
                                    ? 1.4
                                    : ((targetPost.width > 0 &&
                                            targetPost.height > 0)
                                        ? (targetPost.width / targetPost.height)
                                            .clamp(0.45, 2.4)
                                        : (16 / 9)),
                                child: PostMediaViewer(
                                  key: ValueKey(
                                      '${targetPost.cacheKey}_$currentPostIndex'),
                                  post: targetPost,
                                  pageIndex:
                                      isMultiPage ? currentPostIndex : null,
                                  pageCount: isMultiPage ? pages.length : null,
                                  onPageChanged: isMultiPage
                                      ? (newIdx) => onPageSelected(newIdx)
                                      : null,
                                  useLiveFeed:
                                      isMultiPage ? false : fromFeed,
                                  postsList: isMultiPage ? pages : feedPosts,
                                  onLoadMore: onLoadMore,
                                  onPostIndexChanged: (index) {
                                    if (isMultiPage) {
                                      if (index >= 0 && index < pages.length) {
                                        onPageSelected(index);
                                      }
                                      return;
                                    }
                                    final currentPosts = fromFeed
                                        ? (ref
                                                .read(feedControllerProvider)
                                                .value
                                                ?.posts ??
                                            feedPosts)
                                        : feedPosts;
                                    if (index >= 0 &&
                                        index < currentPosts.length) {
                                      final target = currentPosts[index];
                                      if (target.cacheKey != post.cacheKey) {
                                        onOpenPost(target);
                                      }
                                    }
                                  },
                                  localFilePath: localMedia?.savedPath,
                                  qualityMode: qualityMode,
                                  notes: notes,
                                  showNotes: showNotes,
                                  mediaHeaders: ref
                                          .watch(postMediaHeadersProvider(
                                              targetPost))
                                          .value ??
                                      const {},
                                  initialPosition: Duration(
                                    milliseconds: settings
                                            .videoPlaybackPositions[
                                        targetPost.cacheKey] ??
                                        0,
                                  ),
                                  initialLoop: settings.videoPlayerLoop,
                                  initialMuted: settings.videoPlayerMuted,
                                  initialCoverVideo: settings.videoPlayerCover,
                                  initialHalfVolume:
                                      settings.videoPlayerHalfVolume,
                                  initialVolume: settings.videoPlayerVolume,
                                  onVolumeChanged: onVolumeChanged,
                                  onPlaybackSnapshot: onPlaybackSnapshot,
                                  onPlaybackPreferencesChanged:
                                      onPlaybackPreferencesChanged,
                                ),
                              ),
                            )
                          : ConstrainedBox(
                              constraints: const BoxConstraints(
                                maxHeight: 760,
                              ),
                              child: AspectRatio(
                                aspectRatio: (targetPost.width > 0 &&
                                        targetPost.height > 0)
                                    ? (targetPost.width / targetPost.height)
                                        .clamp(0.2, 5.0)
                                    : (ref.watch(postMediaDimensionsProvider(
                                                    targetPost.cacheKey)) !=
                                                null &&
                                            ref
                                                    .watch(
                                                        postMediaDimensionsProvider(
                                                            targetPost.cacheKey))!
                                                    .height >
                                                0
                                        ? (ref
                                                .watch(
                                                    postMediaDimensionsProvider(
                                                        targetPost.cacheKey))!
                                                .width /
                                            ref
                                                .watch(
                                                    postMediaDimensionsProvider(
                                                        targetPost.cacheKey))!
                                                .height)
                                            .clamp(0.2, 5.0)
                                        : (16 / 9)),
                                child: PostMediaViewer(
                                  key: ValueKey(
                                      '${targetPost.cacheKey}_$currentPostIndex'),
                                  post: targetPost,
                                  pageIndex:
                                      isMultiPage ? currentPostIndex : null,
                                  pageCount: isMultiPage ? pages.length : null,
                                  onPageChanged: isMultiPage
                                      ? (newIdx) => onPageSelected(newIdx)
                                      : null,
                                  useLiveFeed:
                                      isMultiPage ? false : fromFeed,
                                  postsList: isMultiPage ? pages : feedPosts,
                                  onLoadMore: onLoadMore,
                                  onPostIndexChanged: (index) {
                                    if (isMultiPage) {
                                      if (index >= 0 && index < pages.length) {
                                        onPageSelected(index);
                                      }
                                      return;
                                    }
                                    final currentPosts = fromFeed
                                        ? (ref
                                                .read(feedControllerProvider)
                                                .value
                                                ?.posts ??
                                            feedPosts)
                                        : feedPosts;
                                    if (index >= 0 &&
                                        index < currentPosts.length) {
                                      final target = currentPosts[index];
                                      if (target.cacheKey != post.cacheKey) {
                                        onOpenPost(target);
                                      }
                                    }
                                  },
                                  localFilePath: localMedia?.savedPath,
                                  qualityMode: qualityMode,
                                  notes: notes,
                                  showNotes: showNotes,
                                  mediaHeaders: ref
                                          .watch(postMediaHeadersProvider(
                                              targetPost))
                                          .value ??
                                      const {},
                                  initialPosition: Duration(
                                    milliseconds: settings
                                            .videoPlaybackPositions[
                                        targetPost.cacheKey] ??
                                        0,
                                  ),
                                  initialLoop: settings.videoPlayerLoop,
                                  initialMuted: settings.videoPlayerMuted,
                                  initialCoverVideo: settings.videoPlayerCover,
                                  initialHalfVolume:
                                      settings.videoPlayerHalfVolume,
                                  initialVolume: settings.videoPlayerVolume,
                                  onVolumeChanged: onVolumeChanged,
                                  onPlaybackSnapshot: onPlaybackSnapshot,
                                  onPlaybackPreferencesChanged:
                                      onPlaybackPreferencesChanged,
                                ),
                              ),
                            ),
                    ),
                  ),
                  IconButton.filledTonal(
                    tooltip: strings.ru ? 'Следующий' : 'Next',
                    onPressed: next == null ? null : () => onOpenPost(next!),
                    icon: const Icon(Icons.chevron_right_rounded),
                  ),
                ],
              ),
              if (!MediaUrlSelector.isVideo(post) &&
                  !MediaUrlSelector.isAudio(post) &&
                  (post.providerId.toLowerCase().contains('e621') ||
                      post.providerId.toLowerCase().contains('e926') ||
                      post.hasNotes)) ...[
                const SizedBox(height: 10),
                Center(
                  child: GoogleTranslateButton(
                    hasNotes: notes.isNotEmpty,
                    isLoading: notesAsync.isLoading,
                    showNotes: showNotes,
                    notesCount: notes.length,
                    isRu: strings.ru,
                    onToggle: onToggleNotes,
                  ),
                ),
              ],
              if (pages.length > 1) ...[
                const SizedBox(height: 10),
                PostMultiPageStrip(
                  pages: pages,
                  currentIndex: currentPostIndex,
                  onPageSelected: onPageSelected,
                  onDownloadAll: settings.allowDownloads
                      ? onDownloadAllPages
                      : null,
                ),
              ],
              if (currentIndex >= 0) ...[
                const SizedBox(height: 10),
                NeighborStrip(
                  posts: feedPosts,
                  currentIndex: currentIndex,
                  onOpen: onOpenPost,
                ),
              ],
              const SizedBox(height: 16),
              PostDetailsMetadataSection(
                post: post,
                targetPost: targetPost,
                settings: settings,
                strings: strings,
                labels: labels,
                isFavorite: favoriteKeys.contains(post.cacheKey),
                downloaded: localMedia != null,
                isDownloading: isDownloading,
                localMedia: localMedia,
                fileSizeBytes: fileSizeBytes,
                e621Provider: e621Provider,
                shouldShowCloudCard: shouldShowCloudCard,
                isTextOnly: isTextOnly,
                isMobile: false,
                onFavorite: onToggleFavorite,
                onCollection: onAddToCollection,
                onOpen: () => onOpenSource(),
                onOpenSource: onOpenSource,
                onCopy: () => Clipboard.setData(
                    ClipboardData(text: targetPost.fileUrl)),
                onSimilar: onOpenSimilar,
                onHide: onHidePost,
                onDownload: onDownload,
                onSaveAs: onSaveAs,
                onDeleteLocalFile: onDeleteLocalFile,
                onShare: onShare,
                onOpenArtistPost: onOpenArtistPost,
                onOpenPostId: onOpenPostId,
                onOpenComic: onOpenComic,
                onPlayStream: onPlayStream,
                onDownloadStream: onDownloadStream,
              ),
              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
    );
  }
}
