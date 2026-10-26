import 'dart:async';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:url_launcher/url_launcher.dart';

import 'audio_player_surface.dart';
import 'fullscreen_image_viewer_page.dart';
import 'media_viewer_shortcuts.dart';
import 'post_content_heroes.dart';
import 'post_notes_overlay.dart';
import 'ugoira_player.dart';
import 'video_surface.dart';
import 'zoomable_image.dart';

export 'post_content_heroes.dart';
export 'video_player_controls.dart';
export 'video_surface.dart';
export 'zoomable_image.dart';

import 'package:prisma_app/backend/backend.dart';
import 'package:prisma_app/core/http/app_headers.dart';

final Map<String, VideoPlaybackSnapshot> playbackMemory =
    <String, VideoPlaybackSnapshot>{};

final isFullscreenViewerActiveProvider = StateProvider<bool>((ref) => false);

final postMediaDimensionsProvider =
    StateProvider.autoDispose.family<Size?, String>((ref, cacheKey) => null);

/// Decides which list a fullscreen gallery should page through.
///
/// The gallery owns its list ([posts]); the only reason to prefer the live
/// feed is that the gallery was opened from the feed, where `onLoadMore`
/// appends to it. Everything else — Artists, Favorites, collections, search —
/// must keep its own list, otherwise the gallery silently shows whatever the
/// global feed happens to hold.
///
/// [useLiveFeed] is the caller's explicit statement of origin, so it never
/// has to be inferred from list sizes: an unrelated feed that is merely
/// larger than the given one must never win.
List<Post> resolveFullscreenPosts({
  required List<Post> posts,
  required List<Post>? liveFeed,
  required int currentIndex,
  required bool useLiveFeed,
}) {
  if (!useLiveFeed) return posts;
  if (liveFeed == null || liveFeed.isEmpty) return posts;
  if (currentIndex < 0 || currentIndex >= posts.length) return posts;
  // Still on a post that belongs to the live feed, so swapping the list in
  // keeps `onLoadMore` appending instead of resetting the gallery.
  final current = posts[currentIndex];
  return liveFeed.any((p) => p.cacheKey == current.cacheKey) ? liveFeed : posts;
}

Map<String, String> getMediaUrlHeaders({
  String? providerId,
  String? url,
  Map<String, String>? extraHeaders,
  bool isVideo = false,
}) {
  String? defaultReferer;
  final pid = (providerId ?? '').toLowerCase();
  final u = (url ?? '').toLowerCase();

  if (pid.contains('gelbooru') || u.contains('gelbooru.com')) {
    defaultReferer = 'https://gelbooru.com/';
  } else if (pid.contains('tbib') || u.contains('tbib.org')) {
    defaultReferer = 'https://tbib.org/';
  } else if (pid.contains('safebooru') || u.contains('safebooru.org')) {
    defaultReferer = 'https://safebooru.org/';
  } else if (pid.contains('rule34_us') || u.contains('rule34.us')) {
    defaultReferer = 'https://rule34.us/';
  } else if (pid.contains('rule34') || u.contains('rule34.xxx')) {
    defaultReferer = 'https://rule34.xxx/';
  } else if (pid.contains('realbooru') || u.contains('realbooru.com')) {
    defaultReferer = 'https://realbooru.com/';
  } else if (pid.contains('wallhaven') || u.contains('wallhaven.cc')) {
    defaultReferer = 'https://wallhaven.cc/';
  } else if (pid.contains('arena') || u.contains('are.na')) {
    defaultReferer = 'https://www.are.na/';
  } else if (pid.contains('danbooru') || u.contains('donmai.us')) {
    defaultReferer = 'https://danbooru.donmai.us/';
  } else if (pid.contains('yande.re') || u.contains('yande.re')) {
    defaultReferer = 'https://yande.re/';
  } else if (pid.contains('konachan') || u.contains('konachan')) {
    defaultReferer = 'https://konachan.net/';
  } else if (pid.contains('e621') ||
      pid.contains('e926') ||
      u.contains('e621.net')) {
    defaultReferer = 'https://e621.net/';
  } else if (pid.contains('pixiv') || u.contains('pximg.net')) {
    defaultReferer = 'https://www.pixiv.net/';
  } else if (pid.contains('nhentai') || u.contains('nhentai.net')) {
    defaultReferer = 'https://nhentai.net/';
  } else if (pid.contains('mangadex') ||
      u.contains('mangadex.org') ||
      u.contains('mangadex.network')) {
    defaultReferer = 'https://mangadex.org/';
  } else if (pid.contains('mangalib') ||
      u.contains('mangalib.me') ||
      u.contains('imglib.info')) {
    defaultReferer = 'https://mangalib.me/';
  } else if (pid.contains('ranobelib') || u.contains('ranobelib.me')) {
    defaultReferer = 'https://ranobelib.me/';
  } else if (pid.contains('hitomi') ||
      u.contains('hitomi.la') ||
      u.contains('gold-usergeneratedcontent.net')) {
    defaultReferer = 'https://hitomi.la/';
  } else if (pid.contains('ehentai') ||
      u.contains('e-hentai.org') ||
      u.contains('ehgt.org')) {
    defaultReferer = 'https://e-hentai.org/';
  } else if (pid.contains('mangaupdates') || u.contains('mangaupdates.com')) {
    defaultReferer = 'https://www.mangaupdates.com/';
  } else if (url != null && url.isNotEmpty) {
    final uri = Uri.tryParse(url);
    if (uri != null && uri.hasScheme && uri.host.isNotEmpty) {
      defaultReferer = '${uri.scheme}://${uri.host}/';
    }
  }

  final isDanbooru = pid.contains('danbooru') || u.contains('donmai.us');
  final userAgent = isDanbooru
      ? AppHeaders.defaultUserAgent
      : AppHeaders.desktopChromeUserAgent;

  return {
    'User-Agent': userAgent,
    'Accept': isVideo
        ? 'video/webm,video/mp4,video/*;q=0.9,*/*;q=0.8'
        : 'image/avif,image/webp,image/apng,image/*,*/*;q=0.8',
    if (defaultReferer != null) 'Referer': defaultReferer,
    if (extraHeaders != null) ...extraHeaders,
  };
}

Map<String, String> getPostMediaHeaders(Post post,
    [Map<String, String>? extraHeaders]) {
  final url = post.fileUrl.isNotEmpty
      ? post.fileUrl
      : (post.sampleUrl.isNotEmpty ? post.sampleUrl : post.previewUrl);
  final isVideo = post.fileType.toLowerCase() == 'mp4' ||
      post.fileType.toLowerCase() == 'webm' ||
      post.fileUrl.endsWith('.mp4') ||
      post.fileUrl.endsWith('.webm') ||
      post.sampleUrl.endsWith('.mp4') ||
      post.sampleUrl.endsWith('.webm');
  return getMediaUrlHeaders(
    providerId: post.providerId,
    url: url,
    extraHeaders: extraHeaders,
    isVideo: isVideo,
  );
}

Duration getPostVideoPlaybackPosition(String cacheKey) {
  return playbackMemory[cacheKey]?.position ?? Duration.zero;
}

Future<void> openPostFullscreenGallery({
  required BuildContext context,
  required WidgetRef ref,
  required Post post,
  List<Post>? postsList,
  MediaQualityMode qualityMode = MediaQualityMode.auto,
  List<PostNote> notes = const [],
  bool showNotes = false,
  String? localFilePath,
  Duration? initialVideoPosition,
  bool useLiveFeed = false,
  ValueChanged<int>? onPostChanged,
  VoidCallback? onLoadMore,
}) async {
  final initPos =
      initialVideoPosition ?? getPostVideoPlaybackPosition(post.cacheKey);
  ref.read(isFullscreenViewerActiveProvider.notifier).state = true;
  final posts =
      (postsList != null && postsList.isNotEmpty) ? postsList : [post];
  final postIndex = posts.indexWhere((p) => p.cacheKey == post.cacheKey);
  final initialIndex = postIndex >= 0 ? postIndex : 0;

  int? nextIndex;
  try {
    nextIndex = await Navigator.of(context, rootNavigator: true).push<int>(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black,
        pageBuilder: (_, __, ___) => FullscreenImageViewerPage(
          posts: posts,
          initialIndex: initialIndex,
          qualityMode: qualityMode,
          notes: notes,
          showNotes: showNotes,
          headersBuilder: (p) => getPostMediaHeaders(p),
          localFilePath: localFilePath,
          initialVideoPosition: initPos,
          useLiveFeed: useLiveFeed,
          onPostChanged: onPostChanged,
          onLoadMore: onLoadMore,
        ),
      ),
    );
  } finally {
    ref.read(isFullscreenViewerActiveProvider.notifier).state = false;
  }
  if (nextIndex != null && nextIndex != initialIndex) {
    onPostChanged?.call(nextIndex);
  }
}

class PostMediaViewer extends ConsumerStatefulWidget {
  const PostMediaViewer({
    required this.post,
    this.localFilePath,
    this.fullscreen = false,
    this.useLiveFeed = false,
    this.notes = const [],
    this.showNotes = true,
    this.initialPosition = Duration.zero,
    this.autoplay = false,
    this.initialLoop = false,
    this.initialMuted = false,
    this.initialCoverVideo = false,
    this.initialHalfVolume = false,
    this.initialVolume = 100.0,
    this.qualityMode = MediaQualityMode.auto,
    this.mediaHeaders = const {},
    this.onPlaybackSnapshot,
    this.onPlaybackPreferencesChanged,
    this.onVolumeChanged,
    this.onMediaGestureLockChanged,
    this.postsList,
    this.onPostIndexChanged,
    this.onLoadMore,
    this.isActive = true,
    this.pageIndex,
    this.pageCount,
    this.onPageChanged,
    super.key,
  });

  final Post post;
  final int? pageIndex;
  final int? pageCount;
  final ValueChanged<int>? onPageChanged;
  final String? localFilePath;
  final bool fullscreen;
  final List<PostNote> notes;
  final bool showNotes;
  final Duration initialPosition;
  final bool autoplay;
  final bool initialLoop;
  final bool initialMuted;
  final bool initialCoverVideo;
  final bool initialHalfVolume;
  final double initialVolume;
  final MediaQualityMode qualityMode;
  final Map<String, String> mediaHeaders;
  final ValueChanged<VideoPlaybackSnapshot>? onPlaybackSnapshot;
  final ValueChanged<VideoPlaybackSnapshot>? onPlaybackPreferencesChanged;
  final ValueChanged<double>? onVolumeChanged;
  final ValueChanged<bool>? onMediaGestureLockChanged;
  final List<Post>? postsList;
  final ValueChanged<int>? onPostIndexChanged;
  final VoidCallback? onLoadMore;

  /// True when this viewer is part of the feed, so its fullscreen gallery
  /// should track the live feed list while `onLoadMore` keeps appending.
  final bool useLiveFeed;
  final bool isActive;

  @override
  ConsumerState<PostMediaViewer> createState() => _PostMediaViewerState();
}

class _PostMediaViewerState extends ConsumerState<PostMediaViewer> {
  Player? _player;
  VideoController? _controller;
  late List<String> _imageUrls;
  late List<String> _videoUrls;
  int _imageIndex = 0;
  int _videoIndex = 0;
  bool _controlsVisible = true;
  bool _inFullscreen = false;
  late bool _coverVideo;
  late bool _muted;
  late bool _loopVideo;
  late bool _halfVolume;
  late double _currentVolume;
  String? _videoError;
  int _networkRetryCount = 0;
  bool _retriedFormatError = false;
  bool _softwareDecodingFallback = false;
  late bool _useSoftwareDecoding =
      Platform.isLinux || Platform.isWindows || Platform.isMacOS;
  Timer? _hideTimer;
  StreamSubscription<String>? _errorSubscription;
  StreamSubscription<Duration>? _positionSubscription;
  StreamSubscription<bool>? _playingSubscription;
  StreamSubscription<VideoParams>? _videoParamsSubscription;
  DateTime? _lastSnapshotEmitAt;

  @override
  void initState() {
    super.initState();
    _coverVideo = widget.initialCoverVideo;
    _muted = widget.initialMuted;
    _loopVideo = widget.initialLoop;
    _halfVolume = widget.initialHalfVolume;
    _currentVolume = widget.initialVolume;
    _imageUrls = _buildImageUrls(widget.post);
    _videoUrls = _buildVideoUrls(widget.post);
    if (_isPlayableMedia(widget.post) && _videoUrls.isNotEmpty) {
      _initializeVideo();
    } else {
      _resolveImageDimensions();
    }
  }

  @override
  void didUpdateWidget(covariant PostMediaViewer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.post.cacheKey != widget.post.cacheKey ||
        oldWidget.pageIndex != widget.pageIndex ||
        oldWidget.post.fileUrl != widget.post.fileUrl ||
        oldWidget.post.sampleUrl != widget.post.sampleUrl) {
      _disposeVideo();
      _imageIndex = 0;
      _videoIndex = 0;
      _videoError = null;
      _networkRetryCount = 0;
      _retriedFormatError = false;
      _softwareDecodingFallback = false;
      _useSoftwareDecoding =
          Platform.isLinux || Platform.isWindows || Platform.isMacOS;
      _imageUrls = _buildImageUrls(widget.post);
      _videoUrls = _buildVideoUrls(widget.post);
      if (_isPlayableMedia(widget.post) && _videoUrls.isNotEmpty) {
        _initializeVideo();
      } else {
        _resolveImageDimensions();
      }
    } else if (oldWidget.mediaHeaders != widget.mediaHeaders) {
      if (_videoError != null && _player != null) {
        unawaited(_retryVideo());
      }
    }
    if (oldWidget.initialVolume != widget.initialVolume) {
      _currentVolume = widget.initialVolume;
      unawaited(_applyVolume());
    }
    if (oldWidget.initialMuted != widget.initialMuted) {
      _muted = widget.initialMuted;
      unawaited(_applyVolume());
    }
    if (oldWidget.initialHalfVolume != widget.initialHalfVolume) {
      _halfVolume = widget.initialHalfVolume;
      unawaited(_applyVolume());
    }
    if (oldWidget.initialLoop != widget.initialLoop) {
      _loopVideo = widget.initialLoop;
      unawaited(_player?.setPlaylistMode(
        _loopVideo ? PlaylistMode.single : PlaylistMode.none,
      ));
    }
    if (oldWidget.initialCoverVideo != widget.initialCoverVideo) {
      _coverVideo = widget.initialCoverVideo;
    }
    if (oldWidget.isActive != widget.isActive && !widget.isActive) {
      _player?.pause();
    }
  }

  @override
  void dispose() {
    _disposeVideo();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<bool>(isFullscreenViewerActiveProvider, (previous, next) {
      if (next && !widget.fullscreen) {
        _player?.pause();
      }
    });
    if (_isSwf(widget.post)) {
      return const UnsupportedSwfPanel();
    }

    if (widget.post.isUgoira) {
      return UgoiraPlayer(
        post: widget.post,
        mediaHeaders: widget.mediaHeaders,
        fullscreen: widget.fullscreen,
        onOpenFullscreen: widget.fullscreen ? null : () => _openFullscreen(context),
      );
    }

    if (_controller != null || _player != null) {
      if (_isAudio(widget.post) && _player != null) {
        return AudioSurface(
          player: _player!,
          post: widget.post,
          muted: _muted,
          loopAudio: _loopVideo,
          initialVolume: _currentVolume,
          onVolumeChanged: (vol) {
            _currentVolume = vol;
            widget.onVolumeChanged?.call(vol);
            _emitPlaybackPreferences();
          },
          fullscreen: widget.fullscreen,
          errorMessage: _videoError,
          onRetry: _retryVideo,
          onToggleMute: () async {
            final nextMuted = !_muted;
            setState(() => _muted = nextMuted);
            await _applyVolume();
            _emitPlaybackPreferences();
          },
          onToggleLoop: () async {
            final nextLoop = !_loopVideo;
            setState(() => _loopVideo = nextLoop);
            await _player!.setPlaylistMode(
              nextLoop ? PlaylistMode.single : PlaylistMode.none,
            );
            _emitPlaybackPreferences();
          },
        );
      }
      if (_inFullscreen) {
        return ColoredBox(
          color: Colors.black,
          child: AspectRatio(
            aspectRatio: widget.post.width > 0 && widget.post.height > 0
                ? (widget.post.width / widget.post.height).clamp(0.35, 2.4)
                : 16 / 9,
            child: const Center(
              child: Icon(Icons.fullscreen_rounded, color: Colors.white38),
            ),
          ),
        );
      }
      return Shortcuts(
        shortcuts: {
          LogicalKeySet(LogicalKeyboardKey.space): const TogglePlayIntent(),
        },
        child: Actions(
          actions: {
            TogglePlayIntent: CallbackAction<TogglePlayIntent>(
              onInvoke: (_) {
                _togglePlay();
                return null;
              },
            ),
          },
          child: Focus(
            autofocus: true,
            child: VideoSurface(
              player: _player!,
              controller: _controller!,
              aspectRatio: widget.post.width > 0 && widget.post.height > 0
                  ? widget.post.width / widget.post.height
                  : (ref.watch(postMediaDimensionsProvider(
                                  widget.post.cacheKey)) !=
                              null &&
                          ref
                                  .watch(postMediaDimensionsProvider(
                                      widget.post.cacheKey))!
                                  .height >
                              0
                      ? ref
                              .watch(postMediaDimensionsProvider(
                                  widget.post.cacheKey))!
                              .width /
                          ref
                              .watch(postMediaDimensionsProvider(
                                  widget.post.cacheKey))!
                              .height
                      : 16 / 9),
              isSoftwareDecoding: _useSoftwareDecoding,
              onToggleDecoder: _toggleDecoderMode,
              controlsVisible: _controlsVisible,
              coverVideo: _coverVideo,
              muted: _muted,
              loopVideo: _loopVideo,
              halfVolume: _halfVolume,
              initialVolume: _currentVolume,
              onVolumeChanged: (vol) {
                _currentVolume = vol;
                widget.onVolumeChanged?.call(vol);
                _emitPlaybackPreferences();
              },
              fullscreen: widget.fullscreen,
              errorMessage: _videoError,
              onTapSurface: _toggleControls,
              onInteract: _showControls,
              onRetry: _retryVideo,
              onToggleFit: () {
                setState(() => _coverVideo = !_coverVideo);
                _emitPlaybackPreferences();
                _showControls();
              },
              onToggleMute: () async {
                final nextMuted = !_muted;
                setState(() => _muted = nextMuted);
                await _applyVolume();
                _emitPlaybackPreferences();
                _showControls();
              },
              onToggleHalfVolume: () async {
                setState(() {
                  _halfVolume = !_halfVolume;
                  if (_halfVolume) _muted = false;
                });
                await _applyVolume();
                _emitPlaybackPreferences();
                _showControls();
              },
              onToggleLoop: () async {
                final nextLoop = !_loopVideo;
                setState(() => _loopVideo = nextLoop);
                await _player!.setPlaylistMode(
                  nextLoop ? PlaylistMode.single : PlaylistMode.none,
                );
                _emitPlaybackPreferences();
                _showControls();
              },
              onFullscreen: widget.fullscreen
                  ? () => Navigator.of(context, rootNavigator: true)
                      .pop(_snapshot())
                  : () => _openFullscreen(context),
            ),
          ),
        ),
      );
    }

    if (_imageUrls.isEmpty) {
      if (widget.post.cloudLinks.isNotEmpty) {
        return CloudMediaHero(
          post: widget.post,
          onOpenPrimary: () {
            final links = widget.post.cloudLinks;
            final first = links.isNotEmpty ? links.first : null;
            if (first != null) {
              launchUrl(Uri.parse(first.url),
                  mode: LaunchMode.externalApplication);
            }
          },
        );
      }
      return TextArticleHero(post: widget.post);
    }

    final url = _imageUrls[_imageIndex];
    final isLocal = url.startsWith('/') || url.startsWith('file://');
    final headers = _headersFor(widget.post);
    final Widget image;
    if (isLocal) {
      final cleanPath =
          url.startsWith('file://') ? url.replaceFirst('file://', '') : url;
      image = Image.file(
        File(cleanPath),
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) => DioImageFallback(
          imageUrl: _imageUrls.length > 1 ? _imageUrls[1] : '',
          headers: headers,
          fit: BoxFit.contain,
          onFailed: _advanceImageFallback,
        ),
      );
    } else {
      final mq = MediaQuery.maybeOf(context);
      final dpr = mq?.devicePixelRatio ?? 1.5;
      final screenWidth = mq?.size.width ?? 1080;
      final maxCacheWidth = (screenWidth * dpr * 1.5).round().clamp(1080, 3840);
      final isGif = MediaUrlSelector.isGif(widget.post) ||
          url.toLowerCase().contains('.gif') ||
          widget.post.fileType.toLowerCase() == 'gif';
      final isHighRes = widget.qualityMode == MediaQualityMode.highQuality ||
          widget.qualityMode == MediaQualityMode.original ||
          widget.post.width >= 2560;
      image = CachedNetworkImage(
        key: ValueKey(url),
        imageUrl: url,
        httpHeaders: headers,
        memCacheWidth: (isGif || isHighRes) ? null : maxCacheWidth,
        fit: BoxFit.contain,
        placeholder: (context, url) =>
            const Center(child: CircularProgressIndicator()),
        errorWidget: (context, url, error) {
          return DioImageFallback(
            imageUrl: url,
            headers: headers,
            fit: BoxFit.contain,
            onFailed: _advanceImageFallback,
          );
        },
      );
    }
    final pageIndex = widget.pageIndex ?? 0;
    final pageCount = widget.pageCount ?? 0;
    final hasMultiPages = pageCount > 1;

    final child = Stack(
      alignment: Alignment.center,
      children: [
        ZoomableImage(
          onGestureLockChanged: widget.onMediaGestureLockChanged,
          onTap: widget.fullscreen ? null : () => _openFullscreenImage(context),
          child: Stack(
            fit: StackFit.expand,
            children: [
              image,
              if (widget.showNotes && widget.notes.isNotEmpty)
                PostNotesOverlay(
                  post: widget.post,
                  notes: widget.notes,
                ),
            ],
          ),
        ),
        if (hasMultiPages)
          Positioned(
            bottom: 14,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.70),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white24, width: 0.8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.35),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: pageIndex > 0
                        ? () => widget.onPageChanged?.call(pageIndex - 1)
                        : null,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: Icon(
                        Icons.chevron_left_rounded,
                        size: 20,
                        color: pageIndex > 0 ? Colors.white : Colors.white38,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text(
                      '${pageIndex + 1} / $pageCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: pageIndex < pageCount - 1
                        ? () => widget.onPageChanged?.call(pageIndex + 1)
                        : null,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: Icon(
                        Icons.chevron_right_rounded,
                        size: 20,
                        color: pageIndex < pageCount - 1
                            ? Colors.white
                            : Colors.white38,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );

    final shortcutsMap = <ShortcutActivator, Intent>{
      LogicalKeySet(LogicalKeyboardKey.keyF): const FullscreenImageIntent(),
    };
    if (hasMultiPages) {
      shortcutsMap[LogicalKeySet(LogicalKeyboardKey.arrowLeft)] =
          const PrevImageIntent();
      shortcutsMap[LogicalKeySet(LogicalKeyboardKey.keyA)] =
          const PrevImageIntent();
      shortcutsMap[LogicalKeySet(LogicalKeyboardKey.arrowRight)] =
          const NextImageIntent();
      shortcutsMap[LogicalKeySet(LogicalKeyboardKey.keyD)] =
          const NextImageIntent();
    }

    final actionsMap = <Type, Action<Intent>>{
      FullscreenImageIntent: CallbackAction<FullscreenImageIntent>(
        onInvoke: (_) {
          if (!widget.fullscreen) _openFullscreenImage(context);
          return null;
        },
      ),
    };
    if (hasMultiPages) {
      actionsMap[PrevImageIntent] = CallbackAction<PrevImageIntent>(
        onInvoke: (_) {
          if (pageIndex > 0) {
            widget.onPageChanged?.call(pageIndex - 1);
          }
          return null;
        },
      );
      actionsMap[NextImageIntent] = CallbackAction<NextImageIntent>(
        onInvoke: (_) {
          if (pageIndex < pageCount - 1) {
            widget.onPageChanged?.call(pageIndex + 1);
          }
          return null;
        },
      );
    }

    final interactiveChild = Shortcuts(
      shortcuts: shortcutsMap,
      child: Actions(
        actions: actionsMap,
        child: Focus(
          autofocus: true,
          child: child,
        ),
      ),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.hasBoundedWidth && constraints.hasBoundedHeight) {
          return SizedBox(
            width: constraints.maxWidth,
            height: constraints.maxHeight,
            child: interactiveChild,
          );
        }
        return interactiveChild;
      },
    );
  }

  void _initializeVideo() {
    MediaKit.ensureInitialized();
    final isMobile = Platform.isAndroid || Platform.isIOS;
    _player = Player(
      configuration: PlayerConfiguration(
        bufferSize: isMobile ? 32 * 1024 * 1024 : 64 * 1024 * 1024,
      ),
    );
    final bool enableHw = !_useSoftwareDecoding && !_softwareDecodingFallback;
    _controller = VideoController(
      _player!,
      configuration: VideoControllerConfiguration(
        enableHardwareAcceleration: enableHw,
        hwdec: enableHw ? (Platform.isAndroid ? 'auto-safe' : 'auto') : 'no',
      ),
    );
    _applyVolume();
    _player!.setPlaylistMode(
      _loopVideo ? PlaylistMode.single : PlaylistMode.none,
    );
    _errorSubscription = _player!.stream.error.listen((message) {
      if (!mounted) return;
      // Stop playback immediately so background playback/audio doesn't continue with error
      unawaited(_player?.pause());
      unawaited(_player?.stop());
      unawaited(_handleVideoError(message));
    });
    _positionSubscription = _player!.stream.position.listen((pos) {
      if (pos > Duration.zero) {
        _networkRetryCount = 0;
      }
      final snapshot = _snapshot();
      playbackMemory[widget.post.cacheKey] = snapshot;
      _emitPlaybackSnapshotThrottled(snapshot);
    });
    _playingSubscription = _player!.stream.playing.listen((_) {
      final snapshot = _snapshot();
      playbackMemory[widget.post.cacheKey] = snapshot;
      widget.onPlaybackSnapshot?.call(snapshot);
    });
    _videoParamsSubscription = _player!.stream.videoParams.listen((params) {
      if (params.w != null &&
          params.h != null &&
          params.w! > 0 &&
          params.h! > 0) {
        final newSize = Size(params.w!.toDouble(), params.h!.toDouble());
        if (ref.read(postMediaDimensionsProvider(widget.post.cacheKey)) !=
            newSize) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              ref
                  .read(postMediaDimensionsProvider(widget.post.cacheKey)
                      .notifier)
                  .state = newSize;
            }
          });
        }
      }
    });
    _openVideo(play: widget.autoplay);
    _scheduleControlsHide();
  }

  Future<void> _openVideo({required bool play}) async {
    final player = _player;
    if (player == null || _videoUrls.isEmpty) return;
    final remembered = playbackMemory[widget.post.cacheKey];
    final initialPosition = widget.initialPosition > Duration.zero
        ? widget.initialPosition
        : remembered?.position ?? Duration.zero;
    final shouldPlay = play || (remembered?.playing ?? false);
    try {
      setState(() => _videoError = null);
      await player.stop();
      final currentSource = _videoUrls[_videoIndex];
      final isLocal =
          currentSource.startsWith('/') || currentSource.startsWith('file://');
      await player.open(
        Media(
          currentSource,
          httpHeaders: isLocal ? null : _headersFor(widget.post),
        ),
        play: initialPosition == Duration.zero && shouldPlay,
      );
      await _applyVolume();
      if (initialPosition > Duration.zero) {
        await player.seek(initialPosition);
        if (shouldPlay) await player.play();
      }
    } catch (error) {
      await _handleVideoError(error.toString(), play: shouldPlay);
    }
  }

  Future<void> _handleVideoError(String message, {bool play = false}) async {
    if (_videoIndex < _videoUrls.length - 1) {
      _videoIndex++;
      await _openVideo(play: play);
      return;
    }
    final lower = message.toLowerCase();
    // If format or codec error occurred (e.g. unsupported hwdec profile), fallback to software decoding and retry once
    if (!_retriedFormatError &&
        (lower.contains('codec') ||
            lower.contains('could not open') ||
            lower.contains('couldnt open') ||
            lower.contains('could not initialize codec') ||
            lower.contains('demuxer error') ||
            lower.contains('format unrecognized') ||
            lower.contains('stream format not recognized') ||
            lower.contains('failed to recognize file format'))) {
      _retriedFormatError = true;
      _softwareDecodingFallback = true;
      _useSoftwareDecoding = true;
      _disposeVideo();
      await Future<void>.delayed(const Duration(milliseconds: 250));
      if (mounted) {
        _videoIndex = 0;
        _initializeVideo();
        return;
      }
    }

    // Automatic transparent retry on transient network, connection or timeout errors (up to 2 retries)
    if (_networkRetryCount < 2) {
      _networkRetryCount++;
      _disposeVideo();
      await Future<void>.delayed(
          Duration(milliseconds: 400 * _networkRetryCount));
      if (mounted) {
        _initializeVideo();
        return;
      }
    }

    // Fully interrupt playback so video/audio never continues playing in background on error
    try {
      await _player?.pause();
      await _player?.stop();
    } catch (_) {}

    if (mounted) {
      setState(() => _videoError = message);
    }
  }

  Future<void> _retryVideo() async {
    _videoIndex = 0;
    _networkRetryCount = 0;
    _retriedFormatError = false;
    _softwareDecodingFallback = true;
    _useSoftwareDecoding = true;
    _disposeVideo();
    await Future<void>.delayed(const Duration(milliseconds: 150));
    if (mounted) {
      _initializeVideo();
    }
  }

  void _toggleDecoderMode() {
    setState(() {
      _useSoftwareDecoding = !_useSoftwareDecoding;
      _softwareDecodingFallback = false;
      _retriedFormatError = false;
    });
    _disposeVideo();
    _initializeVideo();
    final isRu = Localizations.maybeLocaleOf(context)?.languageCode == 'ru';
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(
        content: Text(
          _useSoftwareDecoding
              ? (isRu
                  ? 'Включено программное декодирование (S/W)'
                  : 'Software decoding enabled (S/W)')
              : (isRu
                  ? 'Включено аппаратное декодирование (H/W)'
                  : 'Hardware decoding enabled (H/W)'),
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _disposeVideo() {
    _hideTimer?.cancel();
    _errorSubscription?.cancel();
    _positionSubscription?.cancel();
    _playingSubscription?.cancel();
    _videoParamsSubscription?.cancel();
    final snapshot = _snapshot();
    playbackMemory[widget.post.cacheKey] = snapshot;
    widget.onPlaybackSnapshot?.call(snapshot);
    _player?.pause();
    _player?.stop();
    _player?.dispose();
    _player = null;
    _controller = null;
  }

  void _resolveImageDimensions() {
    if (widget.post.width > 0 && widget.post.height > 0) return;
    final url = _imageUrls.isNotEmpty
        ? _imageUrls.first
        : (widget.post.sampleUrl.isNotEmpty
            ? widget.post.sampleUrl
            : widget.post.previewUrl);
    if (url.trim().isEmpty) return;
    final headers = getPostMediaHeaders(widget.post);
    final provider = CachedNetworkImageProvider(url, headers: headers);
    final stream = provider.resolve(ImageConfiguration.empty);
    late final ImageStreamListener listener;
    listener = ImageStreamListener((ImageInfo info, bool _) {
      final w = info.image.width.toDouble();
      final h = info.image.height.toDouble();
      if (w > 0 && h > 0) {
        final newSize = Size(w, h);
        if (mounted) {
          ref
              .read(postMediaDimensionsProvider(widget.post.cacheKey).notifier)
              .state = newSize;
        }
      }
      stream.removeListener(listener);
    }, onError: (_, __) {
      stream.removeListener(listener);
    });
    stream.addListener(listener);
  }

  List<String> _buildImageUrls(Post post) {
    final list = MediaUrlSelector.details(post, mode: widget.qualityMode);
    final local = widget.localFilePath;
    if (local != null && local.isNotEmpty && File(local).existsSync()) {
      return [local, ...list];
    }
    return list;
  }

  List<String> _buildVideoUrls(Post post) {
    final list = _isAudio(post)
        ? List<String>.from(MediaUrlSelector.audio(post))
        : List<String>.from(MediaUrlSelector.video(post));
    final cloudStreams = post.cloudLinks
        .where((l) => l.isStreamable && l.directStreamUrl != null)
        .map((l) => l.directStreamUrl!);
    for (final stream in cloudStreams) {
      if (!list.contains(stream)) list.add(stream);
    }
    final local = widget.localFilePath;
    if (local != null && local.isNotEmpty && File(local).existsSync()) {
      return [local, ...list];
    }
    return list;
  }

  bool _isAudio(Post post) => MediaUrlSelector.isAudio(post);

  bool _isVideo(Post post) {
    if (_isAudio(post)) return false;
    if (post.cloudLinks.any((l) => l.isStreamable)) return true;
    return MediaUrlSelector.isVideo(post);
  }

  bool _isPlayableMedia(Post post) => _isVideo(post) || _isAudio(post);

  bool _isSwf(Post post) {
    final value =
        '${post.fileType} ${post.fileUrl} ${post.sampleUrl} ${post.source ?? ''}'
            .toLowerCase();
    return value.contains('swf') || value.contains('.swf');
  }

  Map<String, String> _headersFor(Post post) =>
      getPostMediaHeaders(post, widget.mediaHeaders);

  void _advanceImageFallback() {
    if (_imageIndex >= _imageUrls.length - 1) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _imageIndex++);
    });
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

  void _showControls() {
    if (!mounted) return;
    setState(() => _controlsVisible = true);
    _scheduleControlsHide();
  }

  void _scheduleControlsHide() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && _videoError == null) {
        setState(() => _controlsVisible = false);
      }
    });
  }

  Future<void> _openFullscreen(BuildContext context) async {
    final player = _player;
    final currentPos = player?.state.position ?? Duration.zero;
    await _openFullscreenGallery(context, initialVideoPos: currentPos);
  }

  Future<void> _openFullscreenImage(BuildContext context) async {
    await _openFullscreenGallery(context);
  }

  Future<void> _openFullscreenGallery(
    BuildContext context, {
    Duration initialVideoPos = Duration.zero,
  }) async {
    final player = _player;
    final wasPlaying = player?.state.playing ?? false;
    if (player != null && wasPlaying) {
      await player.pause();
    }
    if (!context.mounted) return;
    _inFullscreen = true;
    ref.read(isFullscreenViewerActiveProvider.notifier).state = true;
    final posts = (widget.postsList != null && widget.postsList!.isNotEmpty)
        ? widget.postsList!
        : [widget.post];
    final postIndex =
        posts.indexWhere((p) => p.cacheKey == widget.post.cacheKey);
    final initialIndex = postIndex >= 0 ? postIndex : 0;

    int? nextIndex;
    try {
      nextIndex = await Navigator.of(context, rootNavigator: true).push<int>(
        PageRouteBuilder(
          opaque: false,
          barrierColor: Colors.black,
          pageBuilder: (_, __, ___) => FullscreenImageViewerPage(
            posts: posts,
            initialIndex: initialIndex,
            qualityMode: widget.qualityMode,
            notes: widget.notes,
            showNotes: widget.showNotes,
            headersBuilder: (p) => _headersFor(p),
            localFilePath: widget.localFilePath,
            initialVideoPosition: initialVideoPos,
            useLiveFeed: widget.useLiveFeed,
            onPostChanged: (idx) {
              widget.onPostIndexChanged?.call(idx);
            },
            onLoadMore: widget.onLoadMore,
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _inFullscreen = false);
      }
      ref.read(isFullscreenViewerActiveProvider.notifier).state = false;
    }
    if (mounted && nextIndex != null && nextIndex != initialIndex) {
      widget.onPostIndexChanged?.call(nextIndex);
    }
    final memory = playbackMemory[widget.post.cacheKey];
    if (memory != null && _player != null) {
      await _player!.seek(memory.position);
      if (memory.playing) {
        await _player!.play();
      }
    } else if (mounted && wasPlaying && _player != null) {
      await _player!.play();
    }
  }

  VideoPlaybackSnapshot _snapshot() {
    final player = _player;
    return VideoPlaybackSnapshot(
      position: player?.state.position ?? Duration.zero,
      playing: player?.state.playing ?? false,
      muted: _muted,
      halfVolume: _halfVolume,
      loopVideo: _loopVideo,
      coverVideo: _coverVideo,
      volume: _currentVolume,
    );
  }

  Future<void> _applyVolume() async {
    await _player?.setVolume(_muted
        ? 0.0
        : _halfVolume
            ? 50.0
            : _currentVolume);
  }

  void _emitPlaybackPreferences() {
    final snapshot = _snapshot();
    playbackMemory[widget.post.cacheKey] = snapshot;
    widget.onPlaybackPreferencesChanged?.call(snapshot);
  }

  void _emitPlaybackSnapshotThrottled(VideoPlaybackSnapshot snapshot) {
    final now = DateTime.now();
    final last = _lastSnapshotEmitAt;
    if (last != null && now.difference(last) < const Duration(seconds: 5)) {
      return;
    }
    _lastSnapshotEmitAt = now;
    widget.onPlaybackSnapshot?.call(snapshot);
  }

  Future<void> _togglePlay() async {
    final player = _player;
    if (player == null) return;
    if (player.state.playing) {
      await player.pause();
    } else {
      await player.play();
    }
    _showControls();
  }
}
