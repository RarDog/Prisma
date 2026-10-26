import 'dart:async';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import 'package:gel_rule_app/app/responsive.dart';
import 'package:gel_rule_app/backend/backend.dart';
import 'package:gel_rule_app/core/performance/performance_monitor.dart';
import 'package:gel_rule_app/features/feed/presentation/feed_controller.dart';
import 'media_viewer_shortcuts.dart';
import 'post_media_viewer.dart';
import 'post_notes_overlay.dart';
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

  static List<String> _urlsForPost(
    Post post,
    MediaQualityMode qualityMode, {
    String? localFilePath,
  }) {
    if (localFilePath != null &&
        localFilePath.isNotEmpty &&
        File(localFilePath).existsSync()) {
      return [localFilePath];
    }
    final isGif = MediaUrlSelector.isGif(post) ||
        post.fileUrl.toLowerCase().contains('.gif') ||
        post.fileType.toLowerCase() == 'gif';
    if (isGif) {
      final result = <String>[];
      if (post.fileUrl.isNotEmpty) result.add(post.fileUrl);
      if (post.sampleUrl.isNotEmpty && !result.contains(post.sampleUrl)) {
        result.add(post.sampleUrl);
      }
      if (post.previewUrl.isNotEmpty && !result.contains(post.previewUrl)) {
        result.add(post.previewUrl);
      }
      return result;
    }
    final detailsUrls = MediaUrlSelector.details(post, mode: qualityMode);
    if (detailsUrls.isNotEmpty) {
      return detailsUrls;
    }
    final result = <String>[];
    if (post.sampleUrl.isNotEmpty) result.add(post.sampleUrl);
    if (post.fileUrl.isNotEmpty && !result.contains(post.fileUrl)) {
      result.add(post.fileUrl);
    }
    if (post.previewUrl.isNotEmpty && !result.contains(post.previewUrl)) {
      result.add(post.previewUrl);
    }
    return result;
  }

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
                            final isVideo =
                                MediaUrlSelector.isVideo(currentPost) ||
                                    MediaUrlSelector.isAudio(currentPost) ||
                                    currentPost.cloudLinks
                                        .any((l) => l.isStreamable);

                            if (isVideo) {
                              return _FullscreenVideoItem(
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
                            return _InteractiveFullscreenImageItem(
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

class _FullscreenVideoItem extends StatefulWidget {
  const _FullscreenVideoItem({
    required this.post,
    required this.isActive,
    required this.headers,
    this.initialPosition = Duration.zero,
    this.localFilePath,
    required this.onTap,
    super.key,
  });

  final Post post;
  final bool isActive;
  final Map<String, String> headers;
  final Duration initialPosition;
  final String? localFilePath;
  final VoidCallback onTap;

  @override
  State<_FullscreenVideoItem> createState() => _FullscreenVideoItemState();
}

class _FullscreenVideoItemState extends State<_FullscreenVideoItem> {
  Player? _player;
  VideoController? _controller;
  bool _initialized = false;
  bool _controlsVisible = true;
  Timer? _hideTimer;
  bool _muted = false;
  bool _loopVideo = true;
  bool _coverVideo = false;
  bool _halfVolume = false;
  double _volume = 100.0;
  bool _isLandscape = false;
  bool _isSoftwareDecoding = false;
  String? _errorMessage;
  int _networkRetryCount = 0;
  StreamSubscription<String>? _errorSub;
  StreamSubscription<Duration>? _posSub;

  void _cancelSubscriptions() {
    _errorSub?.cancel();
    _errorSub = null;
    _posSub?.cancel();
    _posSub = null;
  }

  @override
  void initState() {
    super.initState();
    if (widget.isActive) {
      _initPlayer();
    }
  }

  @override
  void didUpdateWidget(_FullscreenVideoItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) {
      if (_player == null) {
        _networkRetryCount = 0;
        _initPlayer();
      }
    } else if (!widget.isActive && oldWidget.isActive) {
      _player?.pause();
    }
  }

  void _initPlayer() {
    _cancelSubscriptions();
    MediaKit.ensureInitialized();

    final remembered = playbackMemory[widget.post.cacheKey];
    if (remembered != null) {
      _muted = remembered.muted;
      _halfVolume = remembered.halfVolume;
      _loopVideo = remembered.loopVideo;
      _coverVideo = remembered.coverVideo;
      _volume = remembered.volume;
    }

    final isMobile = Platform.isAndroid || Platform.isIOS;
    final p = Player(
      configuration: PlayerConfiguration(
        bufferSize: isMobile ? 32 * 1024 * 1024 : 64 * 1024 * 1024,
      ),
    );
    final enableHw = !_isSoftwareDecoding;
    final c = VideoController(
      p,
      configuration: VideoControllerConfiguration(
        enableHardwareAcceleration: enableHw,
        hwdec: enableHw ? (Platform.isAndroid ? 'auto-safe' : 'auto') : 'no',
      ),
    );
    _player = p;
    _controller = c;
    _applyVolume();
    p.setPlaylistMode(_loopVideo ? PlaylistMode.single : PlaylistMode.none);

    _errorSub = p.stream.error.listen((message) {
      if (!mounted) return;
      if (_networkRetryCount < 2) {
        _networkRetryCount++;
        _cancelSubscriptions();
        try {
          p.pause();
          p.stop();
          p.dispose();
        } catch (_) {}
        Future.delayed(Duration(milliseconds: 400 * _networkRetryCount), () {
          if (mounted) {
            _initialized = false;
            _initPlayer();
          }
        });
        return;
      }
      setState(() => _errorMessage = message);
    });

    _posSub = p.stream.position.listen((pos) {
      if (!mounted) return;
      if (pos > Duration.zero) {
        _networkRetryCount = 0;
      }
      playbackMemory[widget.post.cacheKey] = VideoPlaybackSnapshot(
        position: pos,
        playing: p.state.playing,
        muted: _muted,
        halfVolume: _halfVolume,
        loopVideo: _loopVideo,
        coverVideo: _coverVideo,
        volume: _volume,
      );
    });

    final videoUrls = _buildVideoUrls();
    if (videoUrls.isNotEmpty) {
      final src = videoUrls.first;
      final isLocal = src.startsWith('/') || src.startsWith('file://');
      final shouldPlay = widget.isActive && (remembered?.playing ?? true);
      final seekTo = widget.initialPosition > Duration.zero
          ? widget.initialPosition
          : (remembered?.position ?? Duration.zero);

      p
          .open(
        Media(src, httpHeaders: isLocal ? null : widget.headers),
        play: shouldPlay,
      )
          .then((_) async {
        if (seekTo > Duration.zero) {
          await p.seek(seekTo);
        }
        if (shouldPlay && !p.state.playing) {
          await p.play();
        }
      }).catchError((err) {
        if (!mounted) return;
        if (_networkRetryCount < 2) {
          _networkRetryCount++;
          _cancelSubscriptions();
          try {
            p.pause();
            p.stop();
            p.dispose();
          } catch (_) {}
          Future.delayed(Duration(milliseconds: 400 * _networkRetryCount), () {
            if (mounted) {
              _initialized = false;
              _initPlayer();
            }
          });
          return;
        }
        setState(() => _errorMessage = err.toString());
      });
    }

    if (mounted) {
      setState(() => _initialized = true);
    }
    _scheduleControlsHide();
  }

  List<String> _buildVideoUrls() {
    final local = widget.localFilePath;
    if (local != null && local.isNotEmpty && File(local).existsSync()) {
      return [local];
    }
    final list = MediaUrlSelector.isVideo(widget.post)
        ? List<String>.from(MediaUrlSelector.video(widget.post))
        : List<String>.from(MediaUrlSelector.audio(widget.post));
    final cloudStreams = widget.post.cloudLinks
        .where((l) => l.isStreamable && l.directStreamUrl != null)
        .map((l) => l.directStreamUrl!);
    for (final stream in cloudStreams) {
      if (!list.contains(stream)) list.add(stream);
    }
    if (list.isEmpty) {
      if (widget.post.fileUrl.isNotEmpty) list.add(widget.post.fileUrl);
      if (widget.post.sampleUrl.isNotEmpty) list.add(widget.post.sampleUrl);
    }
    return list;
  }

  void _applyVolume() {
    _player?.setVolume(_muted
        ? 0.0
        : _halfVolume
            ? 50.0
            : _volume);
  }

  void _scheduleControlsHide() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && _errorMessage == null) {
        setState(() => _controlsVisible = false);
      }
    });
  }

  void _toggleControls() {
    if (!mounted) return;
    if (_controlsVisible) {
      _hideTimer?.cancel();
      setState(() => _controlsVisible = false);
    } else {
      setState(() => _controlsVisible = true);
      _scheduleControlsHide();
    }
    widget.onTap();
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _cancelSubscriptions();
    if (_player != null) {
      final pos = _player!.state.position;
      final isPlaying = _player!.state.playing;
      playbackMemory[widget.post.cacheKey] = VideoPlaybackSnapshot(
        position: pos,
        playing: isPlaying,
        muted: _muted,
        halfVolume: _halfVolume,
        loopVideo: _loopVideo,
        coverVideo: _coverVideo,
        volume: _volume,
      );
    }
    _player?.pause();
    _player?.stop();
    _player?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized || _player == null || _controller == null) {
      return Stack(
        fit: StackFit.expand,
        children: [
          if (widget.post.previewUrl.isNotEmpty)
            CachedNetworkImage(
              imageUrl: widget.post.previewUrl,
              httpHeaders: widget.headers,
              fit: BoxFit.contain,
              errorWidget: (_, __, ___) => const SizedBox.shrink(),
            ),
          const Center(
            child:
                CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
          ),
        ],
      );
    }

    final double aspect = (widget.post.width > 0 && widget.post.height > 0)
        ? (widget.post.width / widget.post.height).clamp(0.4, 2.5)
        : 16 / 9;

    final topOffset = MediaQuery.of(context).padding.top + 50.0;

    return VideoSurface(
      player: _player!,
      controller: _controller!,
      aspectRatio: aspect,
      isSoftwareDecoding: _isSoftwareDecoding,
      topOffset: topOffset,
      inGallery: true,
      onToggleDecoder: () {
        setState(() => _isSoftwareDecoding = !_isSoftwareDecoding);
        _player?.dispose();
        _initialized = false;
        _initPlayer();
      },
      controlsVisible: _controlsVisible,
      coverVideo: _coverVideo,
      muted: _muted,
      loopVideo: _loopVideo,
      halfVolume: _halfVolume,
      initialVolume: _volume,
      onVolumeChanged: (v) {
        _volume = v;
        _applyVolume();
      },
      fullscreen: true,
      errorMessage: _errorMessage,
      onTapSurface: _toggleControls,
      onInteract: () {
        setState(() => _controlsVisible = true);
        _scheduleControlsHide();
      },
      isLandscape: _isLandscape,
      onToggleOrientation: () {
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
      },
      onRetry: () {
        _networkRetryCount = 0;
        setState(() => _errorMessage = null);
        _player?.dispose();
        _initialized = false;
        _initPlayer();
      },
      onToggleFit: () => setState(() => _coverVideo = !_coverVideo),
      onToggleMute: () {
        setState(() => _muted = !_muted);
        _applyVolume();
      },
      onToggleHalfVolume: () {
        setState(() => _halfVolume = !_halfVolume);
        _applyVolume();
      },
      onToggleLoop: () {
        setState(() => _loopVideo = !_loopVideo);
        _player?.setPlaylistMode(
          _loopVideo ? PlaylistMode.single : PlaylistMode.none,
        );
      },
      onFullscreen: () => Navigator.of(context, rootNavigator: true).maybePop(),
    );
  }
}

class _InteractiveFullscreenImageItem extends StatefulWidget {
  const _InteractiveFullscreenImageItem({
    required this.urls,
    required this.headers,
    required this.post,
    required this.notes,
    required this.showNotes,
    required this.onZoomChanged,
    required this.onTap,
    super.key,
  });

  final List<String> urls;
  final Map<String, String> headers;
  final Post post;
  final List<PostNote> notes;
  final bool showNotes;
  final ValueChanged<bool> onZoomChanged;
  final VoidCallback onTap;

  @override
  State<_InteractiveFullscreenImageItem> createState() =>
      _InteractiveFullscreenImageItemState();
}

class _InteractiveFullscreenImageItemState
    extends State<_InteractiveFullscreenImageItem> {
  final _controller = TransformationController();
  TapDownDetails? _doubleTapDetails;
  bool _zoomed = false;
  int _pointerCount = 0;
  int _urlIndex = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _zoomIn([Offset? targetOffset]) {
    final currentScale = _controller.value.getMaxScaleOnAxis();
    final newScale = (currentScale * 1.4).clamp(1.0, 10.0);
    final target = targetOffset ??
        Offset(
          MediaQuery.of(context).size.width / 2,
          MediaQuery.of(context).size.height / 2,
        );
    _controller.value = Matrix4.identity()
      ..translateByDouble(
          -target.dx * (newScale - 1), -target.dy * (newScale - 1), 0, 1)
      ..scaleByDouble(newScale, newScale, 1, 1);
    final nextZoomed = newScale > 1.02;
    if (mounted) setState(() => _zoomed = nextZoomed);
    widget.onZoomChanged(nextZoomed);
  }

  void _zoomOut([Offset? targetOffset]) {
    final currentScale = _controller.value.getMaxScaleOnAxis();
    final newScale = (currentScale / 1.4).clamp(1.0, 10.0);
    if (newScale <= 1.02) {
      _controller.value = Matrix4.identity();
      if (mounted) setState(() => _zoomed = false);
      widget.onZoomChanged(false);
    } else {
      final target = targetOffset ??
          Offset(
            MediaQuery.of(context).size.width / 2,
            MediaQuery.of(context).size.height / 2,
          );
      _controller.value = Matrix4.identity()
        ..translateByDouble(
            -target.dx * (newScale - 1), -target.dy * (newScale - 1), 0, 1)
        ..scaleByDouble(newScale, newScale, 1, 1);
      if (mounted) setState(() => _zoomed = true);
      widget.onZoomChanged(true);
    }
  }

  void _toggleZoom() {
    final tap = _doubleTapDetails?.localPosition ?? Offset.zero;
    if (_zoomed) {
      _controller.value = Matrix4.identity();
      if (mounted) setState(() => _zoomed = false);
      widget.onZoomChanged(false);
      return;
    }
    const scale = 2.8;
    _controller.value = Matrix4.identity()
      ..translateByDouble(-tap.dx * (scale - 1), -tap.dy * (scale - 1), 0, 1)
      ..scaleByDouble(scale, scale, 1, 1);
    if (mounted) setState(() => _zoomed = true);
    widget.onZoomChanged(true);
  }

  void _advanceFallback() {
    if (_urlIndex < widget.urls.length - 1) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _urlIndex++);
      });
    }
  }

  Widget _buildPlaceholder() {
    final cachedThumb = widget.post.sampleUrl.isNotEmpty
        ? widget.post.sampleUrl
        : widget.post.previewUrl;
    if (cachedThumb.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: cachedThumb,
        httpHeaders: widget.headers,
        fit: BoxFit.contain,
        placeholder: (_, __) => const Center(
          child:
              CircularProgressIndicator(strokeWidth: 2, color: Colors.white54),
        ),
        errorWidget: (_, __, ___) => const Center(
          child:
              CircularProgressIndicator(strokeWidth: 2, color: Colors.white54),
        ),
      );
    }
    return const Center(
      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white54),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUrl = widget.urls.isNotEmpty && _urlIndex < widget.urls.length
        ? widget.urls[_urlIndex]
        : widget.post.fileUrl;
    final isLocal =
        currentUrl.startsWith('/') || currentUrl.startsWith('file://');
    final Widget imageWidget;
    if (isLocal) {
      final cleanPath = currentUrl.startsWith('file://')
          ? currentUrl.replaceFirst('file://', '')
          : currentUrl;
      imageWidget = Image.file(
        File(cleanPath),
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => const Center(
          child:
              Icon(Icons.broken_image_rounded, size: 64, color: Colors.white54),
        ),
      );
    } else {
      final mq = MediaQuery.maybeOf(context);
      final dpr = mq?.devicePixelRatio ?? 1.5;
      final screenWidth = mq?.size.width ?? 1080;
      final maxCacheWidth = (screenWidth * dpr * 2.0).round().clamp(1440, 4096);
      final isGif = MediaUrlSelector.isGif(widget.post) ||
          currentUrl.toLowerCase().contains('.gif') ||
          widget.post.fileType.toLowerCase() == 'gif';
      final isHighRes = widget.post.width >= 2000;

      imageWidget = CachedNetworkImage(
        key: ValueKey(currentUrl),
        imageUrl: currentUrl,
        httpHeaders: widget.headers,
        memCacheWidth: (isGif || isHighRes) ? null : maxCacheWidth,
        fit: BoxFit.contain,
        placeholder: (context, url) => _buildPlaceholder(),
        errorWidget: (context, url, error) {
          if (_urlIndex < widget.urls.length - 1) {
            _advanceFallback();
            return _buildPlaceholder();
          }
          return DioImageFallback(
            imageUrl: url,
            headers: widget.headers,
            fit: BoxFit.contain,
            onFailed: () {},
          );
        },
      );
    }

    final content = Stack(
      fit: StackFit.expand,
      children: [
        imageWidget,
        if (widget.showNotes && widget.notes.isNotEmpty)
          PostNotesOverlay(
            post: widget.post,
            notes: widget.notes,
          ),
      ],
    );

    return Listener(
      onPointerDown: (_) => _pointerCount++,
      onPointerUp: (_) {
        if (_pointerCount > 0) _pointerCount--;
      },
      onPointerCancel: (_) {
        if (_pointerCount > 0) _pointerCount--;
      },
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          if (!_zoomed) {
            widget.onTap();
          }
        },
        onDoubleTapDown: (details) => _doubleTapDetails = details,
        onDoubleTap: _toggleZoom,
        child: InteractiveViewer(
          transformationController: _controller,
          minScale: 1.0,
          maxScale: 10.0,
          boundaryMargin: const EdgeInsets.all(200),
          panEnabled: _zoomed,
          scaleEnabled: _zoomed || _pointerCount >= 2,
          clipBehavior: Clip.none,
          onInteractionEnd: (_) {
            final scale = _controller.value.getMaxScaleOnAxis();
            final nextZoomed = scale > 1.03;
            if (!nextZoomed) {
              _controller.value = Matrix4.identity();
            }
            if (mounted) setState(() => _zoomed = nextZoomed);
            widget.onZoomChanged(nextZoomed);
          },
          child: Listener(
            onPointerSignal: (event) {
              if (event is PointerScrollEvent) {
                GestureBinding.instance.pointerSignalResolver.register(event,
                    (_) {
                  if (event.scrollDelta.dy < 0) {
                    _zoomIn(event.localPosition);
                  } else if (event.scrollDelta.dy > 0) {
                    _zoomOut(event.localPosition);
                  }
                });
              }
            },
            child: Center(
              child: content,
            ),
          ),
        ),
      ),
    );
  }
}
