import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:gel_rule_app/app/app_strings.dart';
import 'package:gel_rule_app/backend/backend.dart';
import 'package:gel_rule_app/features/settings/presentation/settings_controller.dart';
import 'package:gel_rule_app/sources/booru/e621_provider.dart';
import '../post_details_providers.dart';
import 'post_action_bar.dart';
import 'post_details_metadata_section.dart';
import 'post_media_carousel.dart';
import 'post_media_viewer.dart';
import 'post_multi_page_strip.dart';
import 'post_translate_button.dart';

class PostDetailsMobileLayout extends ConsumerWidget {
  const PostDetailsMobileLayout({
    super.key,
    required this.post,
    required this.targetPost,
    required this.pages,
    required this.currentPageIndex,
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
    required this.mediaGestureLocked,
    required this.isActive,
    required this.onClose,
    this.onMediaGestureLockChanged,
    this.onPostIndexChanged,
    required this.onToggleFavorite,
    required this.onShowQuickActions,
    required this.onSaveVideoSnapshot,
    required this.onSaveVideoPreferences,
    required this.onPageSelected,
    this.onDownloadAllPages,
    required this.onAddToCollection,
    required this.onOpenSource,
    required this.onOpenSimilar,
    required this.onHidePost,
    this.onDownload,
    this.onSaveAs,
    required this.onDeleteLocalFile,
    required this.onShare,
    required this.onOpenArtistPost,
    required this.onOpenPostId,
    required this.onOpenComic,
    required this.onPlayStream,
    this.onDownloadStream,
    this.onLoadMore,
  });

  final Post post;
  final Post targetPost;
  final List<Post>? pages;
  final int currentPageIndex;
  final List<Post>? feedPosts;
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
  final bool mediaGestureLocked;
  final bool isActive;

  final VoidCallback onClose;
  final ValueChanged<bool>? onMediaGestureLockChanged;
  final ValueChanged<int>? onPostIndexChanged;
  final void Function(WidgetRef ref, Post post, Set<String> favoriteKeys)
      onToggleFavorite;
  final void Function(
    BuildContext context,
    WidgetRef ref,
    Post post,
    Set<String> favoriteKeys,
  ) onShowQuickActions;
  final void Function(WidgetRef ref, Post post, VideoPlaybackSnapshot snapshot)
      onSaveVideoSnapshot;
  final void Function(WidgetRef ref, VideoPlaybackSnapshot snapshot)
      onSaveVideoPreferences;
  final ValueChanged<int> onPageSelected;
  final VoidCallback? onDownloadAllPages;
  final VoidCallback onAddToCollection;
  final VoidCallback onOpenSource;
  final VoidCallback onOpenSimilar;
  final VoidCallback onHidePost;
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
  final VoidCallback? onLoadMore;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isVideo = MediaUrlSelector.isVideo(post);
    final isAudio = MediaUrlSelector.isAudio(post);

    final localPages = pages;
    final hasMultiplePages = localPages != null && localPages.length > 1;
    final posts = feedPosts;
    final hasMultiplePosts = posts != null && posts.length > 1;
    final basePostId = post.id.split('_p').first;
    final currentIndex = (posts != null && hasMultiplePosts)
        ? posts.indexWhere(
            (item) =>
                item.providerId == post.providerId &&
                (item.id == post.id || item.id == basePostId),
          )
        : 0;

    final screenWidth = MediaQuery.sizeOf(context).width;
    final screenHeight = MediaQuery.sizeOf(context).height;
    final availableWidth = (screenWidth - 16).clamp(100.0, double.infinity);
    final singleDynamicDim =
        ref.watch(postMediaDimensionsProvider(post.cacheKey));
    final singleMediaHeight = calculateMediaHeight(
      post: post,
      availableWidth: availableWidth,
      screenHeight: screenHeight,
      dynamicDimensions: singleDynamicDim,
    );
    final singleMediaAspect = post.width > 0 && post.height > 0
        ? post.width / post.height
        : (singleDynamicDim != null && singleDynamicDim.height > 0
            ? singleDynamicDim.width / singleDynamicDim.height
            : 16 / 9);

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onVerticalDragEnd: (details) {
        if (mediaGestureLocked) return;
        if ((details.primaryVelocity ?? 0) > 900) onClose();
      },
      child: ListView(
        padding: EdgeInsets.fromLTRB(
          8,
          8,
          8,
          120 + MediaQuery.paddingOf(context).bottom,
        ),
        children: [
          if (posts != null && posts.length > 1)
            MobileMediaCarousel(
              key: const ValueKey('mobile_media_carousel'),
              posts: posts,
              initialIndex: currentIndex >= 0 ? currentIndex : 0,
              activePost: post,
              settings: settings,
              favoriteKeys: favoriteKeys,
              qualityMode: qualityMode,
              onPageChanged: (newIndex) => onPostIndexChanged?.call(newIndex),
              useLiveFeed: fromFeed,
              onLoadMore: onLoadMore,
              onMediaGestureLockChanged: onMediaGestureLockChanged,
              onToggleFavorite: (r, p) => onToggleFavorite(r, p, favoriteKeys),
              onShowQuickActions: (ctx, r, p) =>
                  onShowQuickActions(ctx, r, p, favoriteKeys),
              onSaveVideoSnapshot: (r, p, s) => onSaveVideoSnapshot(r, p, s),
              onSaveVideoPreferences: (r, s) => onSaveVideoPreferences(r, s),
              pages: pages,
              pageIndex: currentPageIndex,
              onSetPageChanged: (idx) => onPageSelected(idx),
            )
          else
            GestureDetector(
              behavior: HitTestBehavior.deferToChild,
              onDoubleTap: isVideo
                  ? null
                  : () => onToggleFavorite(ref, post, favoriteKeys),
              onLongPress: isVideo
                  ? null
                  : () =>
                      onShowQuickActions(context, ref, post, favoriteKeys),
              child: (isVideo || isAudio)
                  ? Center(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxHeight: isAudio ? 340 : singleMediaHeight,
                        ),
                        child: AspectRatio(
                          aspectRatio:
                              isAudio ? 1.3 : singleMediaAspect.clamp(0.2, 5.0),
                          child: PostMediaViewer(
                            key: ValueKey('${post.cacheKey}_$currentPageIndex'),
                            post: post,
                            pageIndex: (hasMultiplePages || post.pageCount > 1)
                                ? currentPageIndex
                                : null,
                            pageCount: (hasMultiplePages || post.pageCount > 1)
                                ? (hasMultiplePages
                                    ? localPages.length
                                    : post.pageCount)
                                : null,
                            onPageChanged:
                                (hasMultiplePages || post.pageCount > 1)
                                    ? (idx) => onPageSelected(idx)
                                    : null,
                            useLiveFeed:
                                hasMultiplePages ? false : fromFeed,
                            isActive: isActive,
                            postsList: hasMultiplePages
                                ? localPages
                                : feedPosts,
                            onLoadMore: onLoadMore,
                            onPostIndexChanged: onPostIndexChanged,
                            localFilePath: localMedia?.savedPath,
                            qualityMode: qualityMode,
                            notes: notes,
                            showNotes: showNotes,
                            mediaHeaders: ref
                                    .watch(postMediaHeadersProvider(post))
                                    .value ??
                                const {},
                            initialPosition: Duration(
                              milliseconds: settings.videoPlaybackPositions[
                                      post.cacheKey] ??
                                  0,
                            ),
                            initialLoop: settings.videoPlayerLoop,
                            initialMuted: settings.videoPlayerMuted,
                            initialCoverVideo: settings.videoPlayerCover,
                            initialHalfVolume: settings.videoPlayerHalfVolume,
                            initialVolume: settings.videoPlayerVolume,
                            onVolumeChanged: (vol) => ref
                                .read(settingsControllerProvider.notifier)
                                .setVideoPlayerVolume(vol),
                            onPlaybackSnapshot: (snapshot) =>
                                onSaveVideoSnapshot(ref, post, snapshot),
                            onPlaybackPreferencesChanged: (snapshot) =>
                                onSaveVideoPreferences(ref, snapshot),
                            onMediaGestureLockChanged: (locked) {
                              onMediaGestureLockChanged?.call(locked);
                            },
                          ),
                        ),
                      ),
                    )
                  : SizedBox(
                      width: double.infinity,
                      height: singleMediaHeight,
                      child: PostMediaViewer(
                        key: ValueKey('${post.cacheKey}_$currentPageIndex'),
                        post: post,
                        pageIndex: (hasMultiplePages || post.pageCount > 1)
                            ? currentPageIndex
                            : null,
                        pageCount: (hasMultiplePages || post.pageCount > 1)
                            ? (hasMultiplePages
                                ? localPages.length
                                : post.pageCount)
                            : null,
                        onPageChanged: (hasMultiplePages || post.pageCount > 1)
                            ? (idx) => onPageSelected(idx)
                            : null,
                        useLiveFeed: hasMultiplePages ? false : fromFeed,
                        isActive: isActive,
                        postsList:
                            hasMultiplePages ? localPages : feedPosts,
                        onLoadMore: onLoadMore,
                        onPostIndexChanged: onPostIndexChanged,
                        localFilePath: localMedia?.savedPath,
                        qualityMode: qualityMode,
                        notes: notes,
                        showNotes: showNotes,
                        mediaHeaders: ref
                                .watch(postMediaHeadersProvider(post))
                                .value ??
                            const {},
                        initialPosition: Duration(
                          milliseconds:
                              settings.videoPlaybackPositions[post.cacheKey] ??
                                  0,
                        ),
                        initialLoop: settings.videoPlayerLoop,
                        initialMuted: settings.videoPlayerMuted,
                        initialCoverVideo: settings.videoPlayerCover,
                        initialHalfVolume: settings.videoPlayerHalfVolume,
                        initialVolume: settings.videoPlayerVolume,
                        onVolumeChanged: (vol) => ref
                            .read(settingsControllerProvider.notifier)
                            .setVideoPlayerVolume(vol),
                        onPlaybackSnapshot: (snapshot) =>
                            onSaveVideoSnapshot(ref, post, snapshot),
                        onPlaybackPreferencesChanged: (snapshot) =>
                            onSaveVideoPreferences(ref, snapshot),
                        onMediaGestureLockChanged: (locked) {
                          onMediaGestureLockChanged?.call(locked);
                        },
                      ),
                    ),
            ),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            switchInCurve: Curves.easeOut,
            switchOutCurve: Curves.easeIn,
            child: KeyedSubtree(
              key: ValueKey(post.cacheKey),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (!MediaUrlSelector.isVideo(post) &&
                      !MediaUrlSelector.isAudio(post) &&
                      (post.providerId.toLowerCase().contains('e621') ||
                          post.providerId.toLowerCase().contains('e926') ||
                          post.hasNotes)) ...[
                    const SizedBox(height: 8),
                    Center(
                      child: GoogleTranslateButton(
                        hasNotes: notes.isNotEmpty,
                        isLoading: notesAsync.isLoading,
                        showNotes: showNotes,
                        notesCount: notes.length,
                        isRu: strings.ru,
                        onToggle: () {
                          ref
                              .read(
                                  showPostNotesProvider(post.cacheKey).notifier)
                              .state = !showNotes;
                        },
                      ),
                    ),
                  ],
                  if (hasMultiplePages) ...[
                    PostMultiPageStrip(
                      pages: localPages,
                      currentIndex: currentPageIndex,
                      onPageSelected: onPageSelected,
                      onDownloadAll: settings.allowDownloads
                          ? onDownloadAllPages
                          : null,
                    ),
                    const SizedBox(height: 8),
                  ],
                  const SizedBox(height: 12),
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
                    isMobile: true,
                    onFavorite: () =>
                        onToggleFavorite(ref, post, favoriteKeys),
                    onCollection: onAddToCollection,
                    onOpen: () => launchUrl(Uri.parse(post.fileUrl)),
                    onOpenSource: onOpenSource,
                    onCopy: () =>
                        Clipboard.setData(ClipboardData(text: post.fileUrl)),
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
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
