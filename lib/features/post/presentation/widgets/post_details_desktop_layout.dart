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

class PostDetailsDesktopLayout extends ConsumerStatefulWidget {
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
  ConsumerState<PostDetailsDesktopLayout> createState() =>
      _PostDetailsDesktopLayoutState();
}

class _PostDetailsDesktopLayoutState
    extends ConsumerState<PostDetailsDesktopLayout> {
  int _direction = 1;

  @override
  void didUpdateWidget(covariant PostDetailsDesktopLayout oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldKey =
        '${oldWidget.targetPost.cacheKey}_${oldWidget.currentPostIndex}';
    final newKey =
        '${widget.targetPost.cacheKey}_${widget.currentPostIndex}';
    if (oldKey != newKey) {
      if (oldWidget.targetPost.cacheKey == widget.targetPost.cacheKey) {
        _direction =
            widget.currentPostIndex >= oldWidget.currentPostIndex ? 1 : -1;
      } else {
        final oldIdx = widget.feedPosts
            .indexWhere((p) => p.cacheKey == oldWidget.targetPost.cacheKey);
        final newIdx = widget.feedPosts
            .indexWhere((p) => p.cacheKey == widget.targetPost.cacheKey);
        if (oldIdx >= 0 && newIdx >= 0) {
          _direction = newIdx >= oldIdx ? 1 : -1;
        }
      }
    }
  }

  void _goToPrevious() {
    setState(() => _direction = -1);
    if (widget.isMultiPage && widget.currentPostIndex > 0) {
      widget.onPageSelected(widget.currentPostIndex - 1);
    } else if (widget.previous != null) {
      widget.onOpenPost(widget.previous!);
    }
  }

  void _goToNext() {
    setState(() => _direction = 1);
    if (widget.isMultiPage && widget.currentPostIndex < widget.pages.length - 1) {
      widget.onPageSelected(widget.currentPostIndex + 1);
    } else if (widget.next != null) {
      widget.onOpenPost(widget.next!);
    }
  }

  Widget _buildAnimatedMedia({
    required Widget child,
    required String targetKey,
  }) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 280),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      layoutBuilder: (currentChild, previousChildren) {
        return Stack(
          alignment: Alignment.center,
          children: [
            ...previousChildren,
            if (currentChild != null) currentChild,
          ],
        );
      },
      transitionBuilder: (child, animation) {
        final isIncoming = (child.key as ValueKey?)?.value == targetKey;
        final offsetTween = Tween<Offset>(
          begin: Offset(
            isIncoming ? (_direction * 0.12) : (-_direction * 0.12),
            0,
          ),
          end: Offset.zero,
        );
        return FadeTransition(
          opacity: CurvedAnimation(
            parent: animation,
            curve: Curves.easeInOutCubic,
          ),
          child: SlideTransition(
            position: offsetTween.animate(CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
            )),
            child: child,
          ),
        );
      },
      child: KeyedSubtree(
        key: ValueKey(targetKey),
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final basePostId = widget.post.id.split('_p').first;
    var currentIndex = widget.feedPosts.indexWhere(
      (item) =>
          item.providerId == widget.post.providerId &&
          (item.id == widget.post.id || item.id == basePostId),
    );
    if (currentIndex < 0) {
      currentIndex = widget.feedPosts.indexWhere(
        (item) => item.id == widget.post.id || item.id == basePostId,
      );
    }

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
              _goToPrevious();
              return null;
            },
          ),
          NextPostIntent: NonTextInputAction<NextPostIntent>(
            onInvoke: (_) {
              _goToNext();
              return null;
            },
          ),
          ToggleFavoriteIntent: NonTextInputAction<ToggleFavoriteIntent>(
            onInvoke: (_) {
              widget.onToggleFavorite();
              return null;
            },
          ),
          AddCollectionIntent: NonTextInputAction<AddCollectionIntent>(
            onInvoke: (_) {
              widget.onAddToCollection();
              return null;
            },
          ),
          CloseIntent: NonTextInputAction<CloseIntent>(
            onInvoke: (_) {
              widget.onClose();
              return null;
            },
          ),
          DownloadIntent: NonTextInputAction<DownloadIntent>(
            onInvoke: (_) {
              if (widget.settings.allowDownloads) {
                widget.onDownload?.call();
              }
              return null;
            },
          ),
        },
        child: Focus(
          autofocus: true,
          child: widget.settings.desktopPostSplitView
              ? _buildSplitLayout(context, currentIndex)
              : _buildClassicLayout(context, currentIndex),
        ),
      ),
    );
  }

  Widget _buildClassicLayout(
    BuildContext context,
    int currentIndex,
  ) {
    final hasPrevious = (widget.isMultiPage && widget.currentPostIndex > 0) ||
        widget.previous != null;
    final hasNext = (widget.isMultiPage &&
            widget.currentPostIndex < widget.pages.length - 1) ||
        widget.next != null;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            IconButton.filledTonal(
              tooltip: widget.strings.ru ? 'Предыдущий (←)' : 'Previous (←)',
              onPressed: hasPrevious ? _goToPrevious : null,
              icon: const Icon(Icons.chevron_left_rounded),
            ),
            Expanded(
              child: Center(
                child: _buildAnimatedMedia(
                  targetKey:
                      '${widget.targetPost.cacheKey}_${widget.currentPostIndex}',
                  child: _buildMediaViewer(context, fitAvailable: false),
                ),
              ),
            ),
            IconButton.filledTonal(
              tooltip: widget.strings.ru ? 'Следующий (→)' : 'Next (→)',
              onPressed: hasNext ? _goToNext : null,
              icon: const Icon(Icons.chevron_right_rounded),
            ),
          ],
        ),
        if (!MediaUrlSelector.isVideo(widget.post) &&
            !MediaUrlSelector.isAudio(widget.post) &&
            (widget.post.providerId.toLowerCase().contains('e621') ||
                widget.post.providerId.toLowerCase().contains('e926') ||
                widget.post.hasNotes)) ...[
          const SizedBox(height: 10),
          Center(
            child: GoogleTranslateButton(
              hasNotes: widget.notes.isNotEmpty,
              isLoading: widget.notesAsync.isLoading,
              showNotes: widget.showNotes,
              notesCount: widget.notes.length,
              isRu: widget.strings.ru,
              onToggle: widget.onToggleNotes,
            ),
          ),
        ],
        if (widget.pages.length > 1) ...[
          const SizedBox(height: 10),
          PostMultiPageStrip(
            pages: widget.pages,
            currentIndex: widget.currentPostIndex,
            onPageSelected: widget.onPageSelected,
            onDownloadAll: widget.settings.allowDownloads
                ? widget.onDownloadAllPages
                : null,
          ),
        ],
        if (currentIndex >= 0) ...[
          const SizedBox(height: 10),
          NeighborStrip(
            posts: widget.feedPosts,
            currentIndex: currentIndex,
            onOpen: widget.onOpenPost,
          ),
        ],
        const SizedBox(height: 16),
        _buildMetadataSection(),
        const SizedBox(height: 80),
      ],
    );
  }

  Widget _buildMediaViewer(
    BuildContext context, {
    required bool fitAvailable,
  }) {
    final targetPost = widget.targetPost;
    final isVideo = MediaUrlSelector.isVideo(targetPost);
    final isAudio = MediaUrlSelector.isAudio(targetPost);

    final mediaWidget = PostMediaViewer(
      key: ValueKey('${targetPost.cacheKey}_${widget.currentPostIndex}'),
      post: targetPost,
      pageIndex: widget.isMultiPage ? widget.currentPostIndex : null,
      pageCount: widget.isMultiPage ? widget.pages.length : null,
      onPageChanged: widget.isMultiPage ? (newIdx) => widget.onPageSelected(newIdx) : null,
      useLiveFeed: widget.isMultiPage ? false : widget.fromFeed,
      postsList: widget.isMultiPage ? widget.pages : widget.feedPosts,
      onLoadMore: widget.onLoadMore,
      onPostIndexChanged: (index) {
        if (widget.isMultiPage) {
          if (index >= 0 && index < widget.pages.length) {
            widget.onPageSelected(index);
          }
          return;
        }
        final currentPosts = widget.fromFeed
            ? (ref.read(feedControllerProvider).value?.posts ?? widget.feedPosts)
            : widget.feedPosts;
        if (index >= 0 && index < currentPosts.length) {
          final target = currentPosts[index];
          if (target.cacheKey != widget.post.cacheKey) {
            widget.onOpenPost(target);
          }
        }
      },
      localFilePath: widget.localMedia?.savedPath,
      qualityMode: widget.qualityMode,
      notes: widget.notes,
      showNotes: widget.showNotes,
      mediaHeaders:
          ref.watch(postMediaHeadersProvider(targetPost)).value ?? const {},
      initialPosition: Duration(
        milliseconds:
            widget.settings.videoPlaybackPositions[targetPost.cacheKey] ?? 0,
      ),
      initialLoop: widget.settings.videoPlayerLoop,
      initialMuted: widget.settings.videoPlayerMuted,
      initialCoverVideo: widget.settings.videoPlayerCover,
      initialHalfVolume: widget.settings.videoPlayerHalfVolume,
      initialVolume: widget.settings.videoPlayerVolume,
      onVolumeChanged: widget.onVolumeChanged,
      onPlaybackSnapshot: widget.onPlaybackSnapshot,
      onPlaybackPreferencesChanged: widget.onPlaybackPreferencesChanged,
    );

    if (fitAvailable) {
      if (isAudio) {
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 360, maxWidth: 620),
            child: mediaWidget,
          ),
        );
      }
      return mediaWidget;
    }

    if (isVideo || isAudio) {
      return ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: isAudio ? 360 : 760,
          maxWidth: isAudio ? 620 : double.infinity,
        ),
        child: AspectRatio(
          aspectRatio: isAudio
              ? 1.4
              : ((targetPost.width > 0 && targetPost.height > 0)
                  ? (targetPost.width / targetPost.height).clamp(0.45, 2.4)
                  : (16 / 9)),
          child: mediaWidget,
        ),
      );
    }

    final double aspect = (targetPost.width > 0 && targetPost.height > 0)
        ? (targetPost.width / targetPost.height).clamp(0.2, 5.0)
        : (ref.watch(postMediaDimensionsProvider(targetPost.cacheKey)) != null &&
                ref.watch(postMediaDimensionsProvider(targetPost.cacheKey))!.height > 0
            ? (ref.watch(postMediaDimensionsProvider(targetPost.cacheKey))!.width /
                    ref.watch(postMediaDimensionsProvider(targetPost.cacheKey))!.height)
                .clamp(0.2, 5.0)
            : (16 / 9));

    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 760),
      child: AspectRatio(
        aspectRatio: aspect,
        child: mediaWidget,
      ),
    );
  }

  Widget _buildSplitLayout(
    BuildContext context,
    int currentIndex,
  ) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final screenWidth = MediaQuery.sizeOf(context).width;
    final sidebarWidth = (screenWidth * 0.28).clamp(360.0, 450.0);
    final hasPrevious = (widget.isMultiPage && widget.currentPostIndex > 0) ||
        widget.previous != null;
    final hasNext = (widget.isMultiPage &&
            widget.currentPostIndex < widget.pages.length - 1) ||
        widget.next != null;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Левая колонка: Просмотрщик медиа
        Expanded(
          child: Container(
            color: isDark ? Colors.black : theme.colorScheme.surfaceContainerLowest,
            child: Column(
              children: [
                Expanded(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 52, vertical: 8),
                          child: _buildAnimatedMedia(
                            targetKey:
                                '${widget.targetPost.cacheKey}_${widget.currentPostIndex}',
                            child: _buildMediaViewer(context, fitAvailable: true),
                          ),
                        ),
                      ),
                      if (hasPrevious)
                        Positioned(
                          left: 10,
                          top: 0,
                          bottom: 0,
                          child: Center(
                            child: IconButton.filledTonal(
                              tooltip: widget.strings.ru ? 'Предыдущий (←)' : 'Previous (←)',
                              onPressed: _goToPrevious,
                              icon: const Icon(Icons.chevron_left_rounded, size: 28),
                            ),
                          ),
                        ),
                      if (hasNext)
                        Positioned(
                          right: 10,
                          top: 0,
                          bottom: 0,
                          child: Center(
                            child: IconButton.filledTonal(
                              tooltip: widget.strings.ru ? 'Следующий (→)' : 'Next (→)',
                              onPressed: _goToNext,
                              icon: const Icon(Icons.chevron_right_rounded, size: 28),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                if (widget.pages.length > 1 || (currentIndex >= 0 && widget.pages.length <= 1))
                  Padding(
                    padding: const EdgeInsets.fromLTRB(52, 0, 52, 10),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (widget.pages.length > 1)
                          PostMultiPageStrip(
                            pages: widget.pages,
                            currentIndex: widget.currentPostIndex,
                            onPageSelected: widget.onPageSelected,
                            onDownloadAll: widget.settings.allowDownloads
                                ? widget.onDownloadAllPages
                                : null,
                          ),
                        if (currentIndex >= 0 && widget.pages.length <= 1)
                          NeighborStrip(
                            posts: widget.feedPosts,
                            currentIndex: currentIndex,
                            onOpen: widget.onOpenPost,
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
        // Разделитель колонок
        VerticalDivider(
          width: 1,
          thickness: 1,
          color: theme.dividerColor.withValues(alpha: 0.12),
        ),
        // Правая колонка: Инспектор метаданных, тегов и действий
        SizedBox(
          width: sidebarWidth,
          child: Container(
            color: theme.colorScheme.surface,
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              children: [
                if (!MediaUrlSelector.isVideo(widget.post) &&
                    !MediaUrlSelector.isAudio(widget.post) &&
                    (widget.post.providerId.toLowerCase().contains('e621') ||
                        widget.post.providerId.toLowerCase().contains('e926') ||
                        widget.post.hasNotes)) ...[
                  GoogleTranslateButton(
                    hasNotes: widget.notes.isNotEmpty,
                    isLoading: widget.notesAsync.isLoading,
                    showNotes: widget.showNotes,
                    notesCount: widget.notes.length,
                    isRu: widget.strings.ru,
                    onToggle: widget.onToggleNotes,
                  ),
                  const SizedBox(height: 12),
                ],
                _buildMetadataSection(),
                const SizedBox(height: 48),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMetadataSection() {
    return PostDetailsMetadataSection(
      post: widget.post,
      targetPost: widget.targetPost,
      settings: widget.settings,
      strings: widget.strings,
      labels: widget.labels,
      isFavorite: widget.favoriteKeys.contains(widget.post.cacheKey),
      downloaded: widget.localMedia != null,
      isDownloading: widget.isDownloading,
      localMedia: widget.localMedia,
      fileSizeBytes: widget.fileSizeBytes,
      e621Provider: widget.e621Provider,
      shouldShowCloudCard: widget.shouldShowCloudCard,
      isTextOnly: widget.isTextOnly,
      isMobile: false,
      onFavorite: widget.onToggleFavorite,
      onCollection: widget.onAddToCollection,
      onOpen: () => widget.onOpenSource(),
      onOpenSource: widget.onOpenSource,
      onCopy: () => Clipboard.setData(
          ClipboardData(text: widget.targetPost.fileUrl)),
      onSimilar: widget.onOpenSimilar,
      onHide: widget.onHidePost,
      onDownload: widget.onDownload,
      onSaveAs: widget.onSaveAs,
      onDeleteLocalFile: widget.onDeleteLocalFile,
      onShare: widget.onShare,
      onOpenArtistPost: widget.onOpenArtistPost,
      onOpenPostId: widget.onOpenPostId,
      onOpenComic: widget.onOpenComic,
      onPlayStream: widget.onPlayStream,
      onDownloadStream: widget.onDownloadStream,
    );
  }
}
