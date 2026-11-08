import 'dart:async';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:gel_rule_app/app/responsive.dart';
import 'package:gel_rule_app/backend/backend.dart';
import 'package:gel_rule_app/core/performance/performance_monitor.dart';
import 'package:gel_rule_app/features/feed/presentation/feed_controller.dart';
import 'fullscreen/fullscreen_media_helpers.dart';
import 'fullscreen/fullscreen_video_item.dart';
import 'fullscreen/interactive_fullscreen_image_item.dart';
import 'media_viewer_shortcuts.dart';
import 'ugoira_player.dart';

class FullscreenImageViewerPage extends ConsumerStatefulWidget {
  const FullscreenImageViewerPage({
    super.key,
    required this.posts,
    required this.initialIndex,
    required this.qualityMode,
    required this.notes,
    required this.showNotes,
    required this.headersBuilder,
    this.localFilePath,
    this.initialVideoPosition = Duration.zero,
    this.useLiveFeed = false,
    this.onPostChanged,
    this.onLoadMore,
  });

  final List<Post> posts;
  final int initialIndex;
  final MediaQualityMode qualityMode;
  final List<PostNote> notes;
  final bool showNotes;
  final Map<String, String> Function(Post post) headersBuilder;
  final String? localFilePath;
  final Duration initialVideoPosition;

  /// True when the gallery was opened from the feed, so it should track the
  /// live feed list while `onLoadMore` keeps appending to it.
  final bool useLiveFeed;
  final ValueChanged<int>? onPostChanged;
  final VoidCallback? onLoadMore;

  static bool _isDirectVideoUrl(String url) =>
      FullscreenMediaHelpers.isDirectVideoUrl(url);

  static List<String> _urlsForPost(
    Post post,
    MediaQualityMode qualityMode, {
    String? localFilePath,
  }) =>
      FullscreenMediaHelpers.urlsForPost(
        post,
        qualityMode,
        localFilePath: localFilePath,
      );

  @override
  ConsumerState<FullscreenImageViewerPage> createState() =>
      FullscreenImageViewerPageState();
}

class FullscreenImageViewerPageState
    extends ConsumerState<FullscreenImageViewerPage>
    with SingleTickerProviderStateMixin {
  late int _currentIndex;
  late PageController _pageController;
  bool _controlsVisible = true;
  Timer? _hideTimer;
  double _dragOffsetY = 0.0;
  bool _isCurrentZoomed = false;
  late bool _showNotes;
  bool _isLandscape = false;
  late AnimationController _animController;
  Animation<double>? _dragAnimation;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex.clamp(0, widget.posts.length - 1);
    _pageController = PageController(initialPage: _currentIndex);
    _pageController.addListener(_handlePageScroll);
    _showNotes = widget.showNotes;
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    )..addListener(() {
        if (_dragAnimation != null) {
          setState(() => _dragOffsetY = _dragAnimation!.value);
        }
      });
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _scheduleControlsHide();
    if (_currentIndex >= widget.posts.length - 3) {
      widget.onLoadMore?.call();
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _prefetchAround(_currentIndex, widget.posts);
    });
  }

  void _handlePageScroll() {
    if (!_pageController.hasClients || _pageController.page == null) return;
    final page = _pageController.page!;
    final rounded = page.round();
    if ((page - _currentIndex).abs() > 0.35 && rounded != _currentIndex) {
      if (mounted) {
        setState(() {
          _currentIndex = rounded;
        });
      }
    }
  }

  void _prefetchAround(int index, List<Post> posts) {
    if (!mounted) return;
    for (final targetIndex in [index + 1, index - 1, index + 2]) {
      if (targetIndex >= 0 && targetIndex < posts.length) {
        final p = posts[targetIndex];
        if (!MediaUrlSelector.isVideo(p) && !MediaUrlSelector.isAudio(p)) {
          final isGif = MediaUrlSelector.isGif(p) ||
              p.fileUrl.toLowerCase().contains('.gif') ||
              p.fileType.toLowerCase() == 'gif';
          final url = isGif
              ? (p.fileUrl.isNotEmpty ? p.fileUrl : p.sampleUrl)
              : (p.sampleUrl.isNotEmpty ? p.sampleUrl : p.fileUrl);
          if (url.isNotEmpty &&
              !url.startsWith('/') &&
              !url.startsWith('file://')) {
            precacheImage(
              CachedNetworkImageProvider(url,
                  headers: widget.headersBuilder(p)),
              context,
            );
          }
        }
      }
    }
  }

  void _scheduleControlsHide() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 4), () {
      if (mounted && _controlsVisible && !_isCurrentZoomed) {
        setState(() => _controlsVisible = false);
      }
    });
  }

  void _showControls() {
    if (!mounted) return;
    setState(() => _controlsVisible = true);
    _scheduleControlsHide();
  }

  void _toggleControls() {
    if (!mounted) return;
    if (_controlsVisible) {
      _hideTimer?.cancel();
      setState(() => _controlsVisible = false);
    } else {
      _showControls();
    }
  }

  void _toggleOrientation() {
    setState(() => _isLandscape = !_isLandscape);
    if (_isLandscape) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    } else {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);
    }
    _showControls();
  }

  void _close() {
    Navigator.of(context, rootNavigator: true).pop(_currentIndex);
  }

  void _onPageChanged(int idx, List<Post> posts) {
    setState(() {
      _currentIndex = idx;
      _isCurrentZoomed = false;
    });
    widget.onPostChanged?.call(idx);
    _showControls();
    _prefetchAround(idx, posts);
    // Evict distant posts (>= 3 posts away) from RAM
    for (int i = 0; i < posts.length; i++) {
      if ((i - idx).abs() >= 3) {
        final p = posts[i];
        SmartMemoryManager.evictImageUrl(p.fileUrl);
        SmartMemoryManager.evictImageUrl(p.sampleUrl);
      }
    }
    PaintingBinding.instance.imageCache.clearLiveImages();
    if (idx >= posts.length - 3) {
      widget.onLoadMore?.call();
    }
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _animController.dispose();
    _pageController.removeListener(_handlePageScroll);
    _pageController.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      SystemChrome.setPreferredOrientations(const []);
    } else {
      SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isRu = Localizations.maybeLocaleOf(context)?.languageCode == 'ru';
    final backdropAlpha = (1.0 - (_dragOffsetY.abs() / 320.0)).clamp(0.0, 1.0);

    final feedPosts = widget.useLiveFeed
        ? ref.watch(feedControllerProvider).value?.posts
        : null;
    final resolvedPosts = resolveFullscreenPosts(
      posts: widget.posts,
      liveFeed: feedPosts,
      currentIndex: _currentIndex,
      useLiveFeed: widget.useLiveFeed,
    );

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _close();
      },
      child: Scaffold(
        backgroundColor: Colors.black.withValues(alpha: backdropAlpha),
        body: Shortcuts(
          shortcuts: {
            LogicalKeySet(LogicalKeyboardKey.escape):
                const CloseFullscreenIntent(),
            LogicalKeySet(LogicalKeyboardKey.keyF):
                const CloseFullscreenIntent(),
            LogicalKeySet(LogicalKeyboardKey.space):
                const ToggleControlsIntent(),
            LogicalKeySet(LogicalKeyboardKey.arrowLeft):
                const PrevFullscreenImageIntent(),
            LogicalKeySet(LogicalKeyboardKey.keyA):
                const PrevFullscreenImageIntent(),
            LogicalKeySet(LogicalKeyboardKey.arrowRight):
                const NextFullscreenImageIntent(),
            LogicalKeySet(LogicalKeyboardKey.keyD):
                const NextFullscreenImageIntent(),
          },
          child: Actions(
            actions: {
              CloseFullscreenIntent: CallbackAction<CloseFullscreenIntent>(
                onInvoke: (_) {
                  _close();
                  return null;
                },
              ),
              ToggleControlsIntent: CallbackAction<ToggleControlsIntent>(
                onInvoke: (_) {
                  _toggleControls();
                  return null;
                },
              ),
              PrevFullscreenImageIntent:
                  CallbackAction<PrevFullscreenImageIntent>(
                onInvoke: (_) {
                  if (_currentIndex > 0) {
                    _pageController.previousPage(
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeOutCubic,
                    );
                    _showControls();
                  }
                  return null;
                },
              ),
              NextFullscreenImageIntent:
                  CallbackAction<NextFullscreenImageIntent>(
                onInvoke: (_) {
                  if (_currentIndex < resolvedPosts.length - 1) {
                    _pageController.nextPage(
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeOutCubic,
                    );
                    _showControls();
                  }
                  return null;
                },
              ),
            },
            child: Focus(
              autofocus: true,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  GestureDetector(
                    onVerticalDragStart: (details) {
                      if (_isCurrentZoomed) return;
                      _animController.stop();
                    },
                    onVerticalDragUpdate: (details) {
                      if (_isCurrentZoomed) return;
                      setState(() {
                        _dragOffsetY += details.delta.dy;
                      });
                    },
                    onVerticalDragEnd: (details) {
                      if (_isCurrentZoomed) return;
                      final velocity = details.primaryVelocity ?? 0.0;
                      if (_dragOffsetY.abs() > 100 || velocity.abs() > 500) {
                        _close();
                      } else {
                        _dragAnimation = Tween<double>(
                          begin: _dragOffsetY,
                          end: 0.0,
                        ).animate(
                          CurvedAnimation(
                            parent: _animController,
                            curve: Curves.easeOutCubic,
                          ),
                        );
                        _animController.forward(from: 0.0);
                      }
                    },
                    child: Transform.translate(
                      offset: Offset(0, _dragOffsetY),
                      child: Transform.scale(
                        scale: (1.0 - (_dragOffsetY.abs() / 1500.0))
                            .clamp(0.82, 1.0),
                        child: PageView.builder(
                          controller: _pageController,
                          itemCount: resolvedPosts.length,
                          physics: _isCurrentZoomed
                              ? const NeverScrollableScrollPhysics()
                              : const BouncingScrollPhysics(),
                          onPageChanged: (idx) =>
                              _onPageChanged(idx, resolvedPosts),
                          itemBuilder: (context, index) {
                            final currentPost = resolvedPosts[index];
                            final isInitial = index == widget.initialIndex;
                            final localPath =
                                isInitial ? widget.localFilePath : null;
                            final hasImages =
                                FullscreenImageViewerPage._urlsForPost(
                              currentPost,
                              widget.qualityMode,
                              localFilePath: localPath,
                            ).isNotEmpty;
                            final isVideo =
                                MediaUrlSelector.isVideo(currentPost) ||
                                    MediaUrlSelector.isAudio(currentPost) ||
                                    (!hasImages &&
                                        currentPost.cloudLinks.any((l) =>
                                            l.service ==
                                                CloudServiceType.genericVideo ||
                                            (l.isStreamable &&
                                                (FullscreenImageViewerPage
                                                        ._isDirectVideoUrl(
                                                            l.url) ||
                                                    FullscreenImageViewerPage
                                                        ._isDirectVideoUrl(
                                                            l.title)))));

                            if (isVideo) {
                              return FullscreenVideoItem(
                                key: ValueKey('fs_vid_${currentPost.cacheKey}'),
                                post: currentPost,
                                isActive: index == _currentIndex,
                                headers: widget.headersBuilder(currentPost),
                                initialPosition: isInitial
                                    ? widget.initialVideoPosition
                                    : Duration.zero,
                                localFilePath: localPath,
                                onTap: _toggleControls,
                              );
                            }

                            if (currentPost.isUgoira) {
                              return UgoiraPlayer(
                                key: ValueKey('fs_ugoira_${currentPost.cacheKey}'),
                                post: currentPost,
                                mediaHeaders: widget.headersBuilder(currentPost),
                                fullscreen: true,
                                onTap: _toggleControls,
                              );
                            }

                            final urls = FullscreenImageViewerPage._urlsForPost(
                              currentPost,
                              widget.qualityMode,
                              localFilePath: localPath,
                            );
                            return InteractiveFullscreenImageItem(
                              key: ValueKey('fs_img_${currentPost.cacheKey}'),
                              urls: urls,
                              headers: widget.headersBuilder(currentPost),
                              post: currentPost,
                              notes: isInitial ? widget.notes : const [],
                              showNotes: _showNotes,
                              onZoomChanged: (zoomed) {
                                if (index == _currentIndex &&
                                    _isCurrentZoomed != zoomed) {
                                  setState(() => _isCurrentZoomed = zoomed);
                                }
                              },
                              onTap: _toggleControls,
                            );
                          },
                        ),
                      ),
                    ),
                  ),

                  // Top controls overlay
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: AnimatedOpacity(
                      opacity: _controlsVisible ? 1.0 : 0.0,
                      duration: const Duration(milliseconds: 200),
                      child: IgnorePointer(
                        ignoring: !_controlsVisible,
                        child: Container(
                          padding: EdgeInsets.only(
                            top: MediaQuery.of(context).padding.top + 6,
                            left: 12,
                            right: 12,
                            bottom: 16,
                          ),
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [Colors.black87, Colors.transparent],
                            ),
                          ),
                          child: Row(
                            children: [
                              IconButton(
                                tooltip: isRu ? 'Закрыть (Esc)' : 'Close (Esc)',
                                icon: const Icon(
                                  Icons.close_rounded,
                                  color: Colors.white,
                                  size: 26,
                                ),
                                onPressed: _close,
                              ),
                              const SizedBox(width: 8),
                              if (resolvedPosts.length > 1)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.black45,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: Colors.white24,
                                      width: 0.8,
                                    ),
                                  ),
                                  child: Text(
                                    '${_currentIndex + 1} / ${resolvedPosts.length}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              const Spacer(),
                              if (Responsive.isMobile(context))
                                IconButton(
                                  tooltip: isRu
                                      ? 'Повернуть экран'
                                      : 'Rotate screen',
                                  icon: Icon(
                                    _isLandscape
                                        ? Icons.screen_lock_landscape_rounded
                                        : Icons.screen_lock_portrait_rounded,
                                    color: Colors.white,
                                  ),
                                  onPressed: _toggleOrientation,
                                ),
                              if (widget.notes.isNotEmpty)
                                IconButton(
                                  tooltip: isRu
                                      ? 'Заметки / перевод'
                                      : 'Notes / translation',
                                  icon: Icon(
                                    _showNotes
                                        ? Icons.subtitles_rounded
                                        : Icons.subtitles_off_rounded,
                                    color: _showNotes
                                        ? Colors.amber
                                        : Colors.white70,
                                  ),
                                  onPressed: () {
                                    setState(() => _showNotes = !_showNotes);
                                    _showControls();
                                  },
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Desktop chevrons
                  if (resolvedPosts.length > 1 &&
                      !Responsive.isMobile(context)) ...[
                    if (_currentIndex > 0)
                      Positioned(
                        left: 16,
                        top: 0,
                        bottom: 0,
                        child: Center(
                          child: AnimatedOpacity(
                            opacity: _controlsVisible ? 1.0 : 0.0,
                            duration: const Duration(milliseconds: 200),
                            child: IgnorePointer(
                              ignoring: !_controlsVisible,
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: () {
                                    _pageController.previousPage(
                                      duration:
                                          const Duration(milliseconds: 250),
                                      curve: Curves.easeOutCubic,
                                    );
                                    _showControls();
                                  },
                                  borderRadius: BorderRadius.circular(24),
                                  child: Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.black45,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Colors.white24,
                                        width: 0.8,
                                      ),
                                    ),
                                    child: const Icon(
                                      Icons.chevron_left_rounded,
                                      color: Colors.white,
                                      size: 28,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    if (_currentIndex < resolvedPosts.length - 1)
                      Positioned(
                        right: 16,
                        top: 0,
                        bottom: 0,
                        child: Center(
                          child: AnimatedOpacity(
                            opacity: _controlsVisible ? 1.0 : 0.0,
                            duration: const Duration(milliseconds: 200),
                            child: IgnorePointer(
                              ignoring: !_controlsVisible,
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: () {
                                    _pageController.nextPage(
                                      duration:
                                          const Duration(milliseconds: 250),
                                      curve: Curves.easeOutCubic,
                                    );
                                    _showControls();
                                  },
                                  borderRadius: BorderRadius.circular(24),
                                  child: Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.black45,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Colors.white24,
                                        width: 0.8,
                                      ),
                                    ),
                                    child: const Icon(
                                      Icons.chevron_right_rounded,
                                      color: Colors.white,
                                      size: 28,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
