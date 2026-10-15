import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:gel_rule_app/app/motion.dart';
import 'package:gel_rule_app/backend/backend.dart';
import 'package:gel_rule_app/core/performance/performance_monitor.dart';
import 'package:gel_rule_app/features/post/presentation/post_details_controller.dart';
import 'package:gel_rule_app/features/post/presentation/post_details_providers.dart';
import 'package:gel_rule_app/features/settings/presentation/settings_controller.dart';
import 'post_media_viewer.dart';

double calculateMediaHeight({
  required Post post,
  required double availableWidth,
  required double screenHeight,
  Size? dynamicDimensions,
}) {
  if (MediaUrlSelector.isAudio(post)) return 340.0;

  final isVideo = MediaUrlSelector.isVideo(post);
  const minHeight = 160.0;
  final maxHeight = screenHeight * 0.72;

  double? width = post.width > 0 ? post.width.toDouble() : null;
  double? height = post.height > 0 ? post.height.toDouble() : null;

  if (width == null || height == null) {
    if (dynamicDimensions != null &&
        dynamicDimensions.width > 0 &&
        dynamicDimensions.height > 0) {
      width = dynamicDimensions.width;
      height = dynamicDimensions.height;
    }
  }

  if (width != null && height != null && height > 0) {
    final aspect = width / height;
    final calculated = availableWidth / aspect;
    return calculated.clamp(minHeight, maxHeight);
  }

  return isVideo ? screenHeight * 0.70 : screenHeight * 0.62;
}

class MobileMediaCarousel extends ConsumerStatefulWidget {
  const MobileMediaCarousel({
    required this.posts,
    required this.initialIndex,
    required this.activePost,
    required this.settings,
    required this.favoriteKeys,
    required this.qualityMode,
    required this.onPageChanged,
    this.useLiveFeed = false,
    this.onLoadMore,
    this.onMediaGestureLockChanged,
    this.onToggleFavorite,
    this.onShowQuickActions,
    this.onSaveVideoSnapshot,
    this.onSaveVideoPreferences,
    super.key,
  });

  final List<Post> posts;
  final int initialIndex;
  final Post activePost;
  final AppSettings settings;
  final Set<String> favoriteKeys;
  final MediaQualityMode qualityMode;
  final ValueChanged<int> onPageChanged;

  /// True when this carousel belongs to the feed, so its fullscreen gallery
  /// tracks the live feed list while `onLoadMore` keeps appending.
  final bool useLiveFeed;
  final VoidCallback? onLoadMore;
  final ValueChanged<bool>? onMediaGestureLockChanged;
  final void Function(WidgetRef ref, Post post)? onToggleFavorite;
  final void Function(BuildContext context, WidgetRef ref, Post post)?
      onShowQuickActions;
  final void Function(WidgetRef ref, Post post, VideoPlaybackSnapshot snapshot)?
      onSaveVideoSnapshot;
  final void Function(WidgetRef ref, VideoPlaybackSnapshot snapshot)?
      onSaveVideoPreferences;

  @override
  ConsumerState<MobileMediaCarousel> createState() =>
      _MobileMediaCarouselState();
}

class _MobileMediaCarouselState extends ConsumerState<MobileMediaCarousel>
    with AutomaticKeepAliveClientMixin {
  late final PageController _controller;
  late int _currentPage;
  bool _mediaGestureLocked = false;
  bool _isUserScrolling = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _currentPage = widget.posts.isEmpty
        ? 0
        : widget.initialIndex.clamp(0, widget.posts.length - 1);
    _controller = PageController(initialPage: _currentPage);
    _controller.addListener(_handleScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _prefetchAround(_currentPage);
        if (widget.onLoadMore != null &&
            _currentPage >= widget.posts.length - 8) {
          widget.onLoadMore!();
        }
      }
    });
  }

  void _handleScroll() {
    if (!mounted) return;
    setState(() {});
  }

  @override
  void didUpdateWidget(covariant MobileMediaCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialIndex != _currentPage &&
        widget.initialIndex >= 0 &&
        widget.initialIndex < widget.posts.length) {
      _currentPage = widget.initialIndex;
      if (!_isUserScrolling &&
          _controller.hasClients &&
          _controller.page?.round() != widget.initialIndex) {
        _controller.jumpToPage(widget.initialIndex);
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _prefetchAround(widget.initialIndex);
        }
      });
    }
    if (widget.posts.length != oldWidget.posts.length) {
      if (widget.onLoadMore != null &&
          _currentPage >= widget.posts.length - 8) {
        widget.onLoadMore!();
      }
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_handleScroll);
    _controller.dispose();
    super.dispose();
  }

  void _setMediaGestureLocked(bool locked) {
    if (_mediaGestureLocked == locked) return;
    setState(() => _mediaGestureLocked = locked);
    widget.onMediaGestureLockChanged?.call(locked);
  }

  void _prefetchAround(int index) {
    for (final offset in [-1, 1]) {
      final target = index + offset;
      if (target < 0 || target >= widget.posts.length) continue;
      final post = widget.posts[target];
      final url = post.sampleUrl.isNotEmpty ? post.sampleUrl : post.previewUrl;
      if (url.trim().isNotEmpty) {
        precacheImage(
          CachedNetworkImageProvider(url, headers: getPostMediaHeaders(post)),
          context,
        );
      }
    }
  }

  void _evictDistantPosts(int currentIndex) {
    for (int i = 0; i < widget.posts.length; i++) {
      if ((i - currentIndex).abs() >= 3) {
        final p = widget.posts[i];
        SmartMemoryManager.evictImageUrl(p.fileUrl);
        SmartMemoryManager.evictImageUrl(p.sampleUrl);
      }
    }
    PaintingBinding.instance.imageCache.clearLiveImages();
  }

  double _getHeightForIndex(
    int index,
    double availableWidth,
    double screenHeight,
  ) {
    if (index < 0 || index >= widget.posts.length) {
      return screenHeight * 0.62;
    }
    final post = (index == _currentPage &&
            widget.posts[index].id == widget.activePost.id)
        ? widget.activePost
        : widget.posts[index];
    final dynamicDim = ref.watch(postMediaDimensionsProvider(post.cacheKey));
    return calculateMediaHeight(
      post: post,
      availableWidth: availableWidth,
      screenHeight: screenHeight,
      dynamicDimensions: dynamicDim,
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final screenWidth = MediaQuery.sizeOf(context).width;
    final screenHeight = MediaQuery.sizeOf(context).height;
    final availableWidth = (screenWidth - 16).clamp(100.0, double.infinity);

    final double page =
        (_controller.hasClients && _controller.position.haveDimensions)
            ? (_controller.page ?? _currentPage.toDouble())
            : _currentPage.toDouble();

    final clampedPage = widget.posts.isEmpty
        ? 0.0
        : page.clamp(0.0, (widget.posts.length - 1).toDouble());
    final floorIndex = clampedPage.floor();
    final ceilIndex = clampedPage.ceil();
    final t = clampedPage - floorIndex;

    final hFloor = _getHeightForIndex(floorIndex, availableWidth, screenHeight);
    final hCeil = floorIndex == ceilIndex
        ? hFloor
        : _getHeightForIndex(ceilIndex, availableWidth, screenHeight);

    final carouselHeight =
        floorIndex == ceilIndex ? hFloor : (hFloor + (hCeil - hFloor) * t);

    return AnimatedContainer(
      duration:
          _isUserScrolling ? Duration.zero : const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      height: carouselHeight,
      width: double.infinity,
      child: ScrollConfiguration(
        behavior: ScrollConfiguration.of(context).copyWith(
          dragDevices: {
            PointerDeviceKind.touch,
            PointerDeviceKind.mouse,
            PointerDeviceKind.trackpad,
            PointerDeviceKind.stylus,
          },
        ),
        child: NotificationListener<ScrollNotification>(
          onNotification: (notification) {
            if (notification.metrics.axis == Axis.horizontal) {
              if (notification is ScrollStartNotification) {
                _isUserScrolling = true;
              } else if (notification is ScrollEndNotification) {
                _isUserScrolling = false;
                if (mounted) setState(() {});
              }
            }
            return false;
          },
          child: PageView.builder(
            controller: _controller,
            physics: _mediaGestureLocked
                ? const NeverScrollableScrollPhysics()
                : const PageScrollPhysics(),
            itemCount: widget.posts.length,
            onPageChanged: (index) {
              setState(() {
                _currentPage = index;
              });
              widget.onPageChanged(index);
              _prefetchAround(index);
              _evictDistantPosts(index);
              if (widget.onLoadMore != null &&
                  index >= widget.posts.length - 8) {
                widget.onLoadMore!();
              }
            },
            itemBuilder: (context, index) {
              final postItem = widget.posts[index];
              final distance = (index - _currentPage).abs();

              // If post is 3 or more pages away from current view, render a tiny lightweight placeholder
              // to prevent loading and decoding 30-40 MB full images in the background.
              if (distance >= 3) {
                return Center(
                  child: postItem.previewUrl.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: postItem.previewUrl,
                          httpHeaders: getPostMediaHeaders(postItem),
                          memCacheWidth: 240,
                          fit: BoxFit.contain,
                          placeholder: (_, __) => const SizedBox.shrink(),
                          errorWidget: (_, __, ___) => const SizedBox.shrink(),
                        )
                      : const SizedBox.shrink(),
                );
              }

              final isActivePage = index == _currentPage;
              final targetPost =
                  (isActivePage && postItem.id == widget.activePost.id)
                      ? widget.activePost
                      : postItem;

              return KeepAlivePostPage(
                key: ValueKey(postItem.cacheKey),
                keepAlive: distance <= 1,
                child: Consumer(
                  builder: (context, ref, _) {
                    final notesAsync =
                        ref.watch(postNotesProvider(PostDetailsArgs(
                      providerId: targetPost.providerId,
                      postId: targetPost.id,
                    )));
                    final notes = notesAsync.value ?? const [];
                    final showNotes =
                        ref.watch(showPostNotesProvider(targetPost.cacheKey));
                    final localMedia = ref
                        .watch(
                            downloadedMediaByKeyProvider(targetPost.cacheKey))
                        .value;
                    final mediaHeaders =
                        ref.watch(postMediaHeadersProvider(targetPost)).value ??
                            const {};
                    final itemIsVideo = MediaUrlSelector.isVideo(targetPost);
                    final itemIsAudio = MediaUrlSelector.isAudio(targetPost);

                    final mediaViewer = PostMediaViewer(
                      key: ValueKey(targetPost.cacheKey),
                      post: targetPost,
                      useLiveFeed: widget.useLiveFeed,
                      isActive: isActivePage,
                      postsList: widget.posts,
                      onLoadMore: widget.onLoadMore,
                      onPostIndexChanged: (newIdx) {
                        widget.onPageChanged(newIdx);
                      },
                      localFilePath: localMedia?.savedPath,
                      qualityMode: widget.qualityMode,
                      notes: notes,
                      showNotes: showNotes,
                      mediaHeaders: mediaHeaders,
                      initialPosition: Duration(
                        milliseconds: widget.settings
                                .videoPlaybackPositions[targetPost.cacheKey] ??
                            0,
                      ),
                      initialLoop: widget.settings.videoPlayerLoop,
                      initialMuted: widget.settings.videoPlayerMuted,
                      initialCoverVideo: widget.settings.videoPlayerCover,
                      initialHalfVolume: widget.settings.videoPlayerHalfVolume,
                      initialVolume: widget.settings.videoPlayerVolume,
                      onVolumeChanged: (vol) => ref
                          .read(settingsControllerProvider.notifier)
                          .setVideoPlayerVolume(vol),
                      onPlaybackSnapshot: (snapshot) => widget
                          .onSaveVideoSnapshot
                          ?.call(ref, targetPost, snapshot),
                      onPlaybackPreferencesChanged: (snapshot) =>
                          widget.onSaveVideoPreferences?.call(ref, snapshot),
                      onMediaGestureLockChanged: (locked) =>
                          _setMediaGestureLocked(locked),
                    );

                    final itemDim = ref.watch(
                        postMediaDimensionsProvider(targetPost.cacheKey));
                    final itemAspect =
                        targetPost.width > 0 && targetPost.height > 0
                            ? targetPost.width / targetPost.height
                            : (itemDim != null && itemDim.height > 0
                                ? itemDim.width / itemDim.height
                                : (16 / 9));

                    return GestureDetector(
                      behavior: HitTestBehavior.deferToChild,
                      onDoubleTap: itemIsVideo
                          ? null
                          : () =>
                              widget.onToggleFavorite?.call(ref, targetPost),
                      onLongPress: itemIsVideo
                          ? null
                          : () => widget.onShowQuickActions
                              ?.call(context, ref, targetPost),
                      child: (itemIsVideo || itemIsAudio)
                          ? Center(
                              child: AspectRatio(
                                aspectRatio: itemIsAudio
                                    ? 1.3
                                    : itemAspect.clamp(0.2, 5.0),
                                child: mediaViewer,
                              ),
                            )
                          : SizedBox.expand(
                              child: mediaViewer,
                            ),
                    );
                  },
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class KeepAlivePostPage extends StatefulWidget {
  const KeepAlivePostPage({
    required this.child,
    this.keepAlive = true,
    super.key,
  });

  final Widget child;
  final bool keepAlive;

  @override
  State<KeepAlivePostPage> createState() => _KeepAlivePostPageState();
}

class _KeepAlivePostPageState extends State<KeepAlivePostPage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => widget.keepAlive;

  @override
  void didUpdateWidget(covariant KeepAlivePostPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.keepAlive != widget.keepAlive) {
      updateKeepAlive();
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}

class NeighborStrip extends StatelessWidget {
  const NeighborStrip({
    required this.posts,
    required this.currentIndex,
    required this.onOpen,
    super.key,
  });

  final List<Post> posts;
  final int currentIndex;
  final ValueChanged<Post> onOpen;

  @override
  Widget build(BuildContext context) {
    final start = (currentIndex - 3).clamp(0, posts.length);
    final end = (currentIndex + 4).clamp(0, posts.length);
    final visible = posts.sublist(start, end);
    return SizedBox(
      height: 72,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: visible.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final post = visible[index];
          final selected = post.cacheKey == posts[currentIndex].cacheKey;
          return InkWell(
            onTap: () => onOpen(post),
            borderRadius: BorderRadius.circular(8),
            child: AnimatedContainer(
              duration: AppMotion.duration(context, 140),
              width: 72,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: selected
                      ? Theme.of(context).colorScheme.primary
                      : Colors.transparent,
                  width: 2,
                ),
              ),
              clipBehavior: Clip.antiAlias,
              child: CachedNetworkImage(
                imageUrl: post.previewUrl.isNotEmpty
                    ? post.previewUrl
                    : post.sampleUrl,
                httpHeaders: getPostMediaHeaders(post),
                memCacheWidth: 160,
                memCacheHeight: 160,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) =>
                    const Center(child: Icon(Icons.broken_image_rounded)),
              ),
            ),
          );
        },
      ),
    );
  }
}
