import 'dart:async';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:gel_rule_app/app/motion.dart';
import 'package:gel_rule_app/app/responsive.dart';
import 'package:gel_rule_app/backend/backend.dart';
import 'package:gel_rule_app/features/feed/presentation/feed_controller.dart';
import 'package:gel_rule_app/shared/widgets/formatted_content_text.dart';

final Map<String, VideoPlaybackSnapshot> _playbackMemory =
    <String, VideoPlaybackSnapshot>{};

final isFullscreenViewerActiveProvider = StateProvider<bool>((ref) => false);

Map<String, String> getPostMediaHeaders(Post post, [Map<String, String>? extraHeaders]) {
  String? defaultReferer;
  final pid = post.providerId.toLowerCase();
  if (pid.contains('gelbooru')) {
    defaultReferer = 'https://gelbooru.com/';
  } else if (pid.contains('safebooru')) {
    defaultReferer = 'https://safebooru.org/';
  } else if (pid.contains('rule34')) {
    defaultReferer = 'https://rule34.xxx/';
  } else if (pid.contains('realbooru')) {
    defaultReferer = 'https://realbooru.com/';
  } else if (pid.contains('danbooru')) {
    defaultReferer = 'https://danbooru.donmai.us/';
  } else if (pid.contains('e621') || pid.contains('e926')) {
    defaultReferer = 'https://e621.net/';
  } else {
    final uri = Uri.tryParse(post.fileUrl);
    if (uri != null && uri.hasScheme && uri.host.isNotEmpty) {
      defaultReferer = '${uri.scheme}://${uri.host}/';
    }
  }

  return {
    'User-Agent': 'Prisma/2.0.1 Flutter local booru browser',
    'Accept': '*/*',
    if (defaultReferer != null) 'Referer': defaultReferer,
    if (extraHeaders != null) ...extraHeaders,
  };
}

Duration getPostVideoPlaybackPosition(String cacheKey) {
  return _playbackMemory[cacheKey]?.position ?? Duration.zero;
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
  ValueChanged<int>? onPostChanged,
  VoidCallback? onLoadMore,
}) async {
  final initPos = initialVideoPosition ??
      getPostVideoPlaybackPosition(post.cacheKey);
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
        pageBuilder: (_, __, ___) => _FullscreenImageViewerPage(
          posts: posts,
          initialIndex: initialIndex,
          qualityMode: qualityMode,
          notes: notes,
          showNotes: showNotes,
          headersBuilder: (p) => getPostMediaHeaders(p),
          localFilePath: localFilePath,
          initialVideoPosition: initPos,
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
    super.key,
  });

  final Post post;
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
  final bool isActive;

  @override
  ConsumerState<PostMediaViewer> createState() => _PostMediaViewerState();
}

class _PostMediaViewerState extends ConsumerState<PostMediaViewer>
    with AutomaticKeepAliveClientMixin {
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
  bool _retriedFormatError = false;
  bool _softwareDecodingFallback = false;
  late bool _useSoftwareDecoding =
      Platform.isLinux || Platform.isWindows || Platform.isMacOS;
  Timer? _hideTimer;
  StreamSubscription<String>? _errorSubscription;
  StreamSubscription<Duration>? _positionSubscription;
  StreamSubscription<bool>? _playingSubscription;
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
    }
  }

  @override
  void didUpdateWidget(covariant PostMediaViewer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.post.cacheKey != widget.post.cacheKey) {
      _disposeVideo();
      _imageIndex = 0;
      _videoIndex = 0;
      _videoError = null;
      _retriedFormatError = false;
      _softwareDecodingFallback = false;
      _useSoftwareDecoding =
          Platform.isLinux || Platform.isWindows || Platform.isMacOS;
      _imageUrls = _buildImageUrls(widget.post);
      _videoUrls = _buildVideoUrls(widget.post);
      if (_isPlayableMedia(widget.post) && _videoUrls.isNotEmpty) {
        _initializeVideo();
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
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    ref.listen<bool>(isFullscreenViewerActiveProvider, (previous, next) {
      if (next && !widget.fullscreen) {
        _player?.pause();
      }
    });
    if (_isSwf(widget.post)) {
      return const _UnsupportedSwfPanel();
    }

    if (_controller != null || _player != null) {
      if (_isAudio(widget.post) && _player != null) {
        return _AudioSurface(
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
          LogicalKeySet(LogicalKeyboardKey.space): const _TogglePlayIntent(),
        },
        child: Actions(
          actions: {
            _TogglePlayIntent: CallbackAction<_TogglePlayIntent>(
              onInvoke: (_) {
                _togglePlay();
                return null;
              },
            ),
          },
          child: Focus(
            autofocus: true,
            child: _VideoSurface(
              player: _player!,
              controller: _controller!,
              aspectRatio: widget.post.width > 0 && widget.post.height > 0
                  ? widget.post.width / widget.post.height
                  : 16 / 9,
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
        return _CloudMediaHero(
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
      return _TextArticleHero(post: widget.post);
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
        errorBuilder: (context, error, stackTrace) => _DioImageFallback(
          imageUrl: _imageUrls.length > 1 ? _imageUrls[1] : '',
          headers: headers,
          fit: BoxFit.contain,
          onFailed: _advanceImageFallback,
        ),
      );
    } else {
      final mq = MediaQuery.maybeOf(context);
      final dpr = mq?.devicePixelRatio ?? 1.5;
      final screenWidth = mq?.size.width ?? 1280;
      final maxCacheWidth =
          (screenWidth * dpr * 1.5).round().clamp(1080, 2560);
      final isGif = MediaUrlSelector.isGif(widget.post) ||
          url.toLowerCase().contains('.gif') ||
          widget.post.fileType.toLowerCase() == 'gif';
      image = CachedNetworkImage(
        key: ValueKey(url),
        imageUrl: url,
        httpHeaders: headers,
        memCacheWidth: isGif ? null : maxCacheWidth,
        fit: BoxFit.contain,
        placeholder: (context, url) =>
            const Center(child: CircularProgressIndicator()),
        errorWidget: (context, url, error) {
          return _DioImageFallback(
            imageUrl: url,
            headers: headers,
            fit: BoxFit.contain,
            onFailed: _advanceImageFallback,
          );
        },
      );
    }
    final child = Stack(
      alignment: Alignment.center,
      children: [
        _ZoomableImage(
          onGestureLockChanged: widget.onMediaGestureLockChanged,
          onTap: widget.fullscreen ? null : () => _openFullscreenImage(context),
          child: Stack(
            fit: StackFit.expand,
            children: [
              image,
              if (widget.showNotes && widget.notes.isNotEmpty)
                _PostNotesOverlay(
                  post: widget.post,
                  notes: widget.notes,
                ),
            ],
          ),
        ),
        if (_imageUrls.length > 1)
          Positioned(
            bottom: 14,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.65),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white24, width: 0.8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_imageIndex > 0)
                    GestureDetector(
                      onTap: () => setState(() => _imageIndex--),
                      child: const Icon(Icons.chevron_left_rounded,
                          size: 20, color: Colors.white),
                    ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text(
                      '${_imageIndex + 1} / ${_imageUrls.length}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (_imageIndex < _imageUrls.length - 1)
                    GestureDetector(
                      onTap: () => setState(() => _imageIndex++),
                      child: const Icon(Icons.chevron_right_rounded,
                          size: 20, color: Colors.white),
                    ),
                ],
              ),
            ),
          ),
      ],
    );

    final shortcutsMap = <ShortcutActivator, Intent>{
      LogicalKeySet(LogicalKeyboardKey.keyF): const _FullscreenImageIntent(),
    };
    if (_imageUrls.length > 1) {
      shortcutsMap[LogicalKeySet(LogicalKeyboardKey.arrowLeft)] =
          const _PrevImageIntent();
      shortcutsMap[LogicalKeySet(LogicalKeyboardKey.keyA)] =
          const _PrevImageIntent();
      shortcutsMap[LogicalKeySet(LogicalKeyboardKey.arrowRight)] =
          const _NextImageIntent();
      shortcutsMap[LogicalKeySet(LogicalKeyboardKey.keyD)] =
          const _NextImageIntent();
    }

    final actionsMap = <Type, Action<Intent>>{
      _FullscreenImageIntent: CallbackAction<_FullscreenImageIntent>(
        onInvoke: (_) {
          if (!widget.fullscreen) _openFullscreenImage(context);
          return null;
        },
      ),
    };
    if (_imageUrls.length > 1) {
      actionsMap[_PrevImageIntent] = CallbackAction<_PrevImageIntent>(
        onInvoke: (_) {
          if (_imageIndex > 0) {
            setState(() => _imageIndex--);
          }
          return null;
        },
      );
      actionsMap[_NextImageIntent] = CallbackAction<_NextImageIntent>(
        onInvoke: (_) {
          if (_imageIndex < _imageUrls.length - 1) {
            setState(() => _imageIndex++);
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
    _player = Player();
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
      unawaited(_handleVideoError(message));
    });
    _positionSubscription = _player!.stream.position.listen((_) {
      final snapshot = _snapshot();
      _playbackMemory[widget.post.cacheKey] = snapshot;
      _emitPlaybackSnapshotThrottled(snapshot);
    });
    _playingSubscription = _player!.stream.playing.listen((_) {
      final snapshot = _snapshot();
      _playbackMemory[widget.post.cacheKey] = snapshot;
      widget.onPlaybackSnapshot?.call(snapshot);
    });
    _openVideo(play: widget.autoplay);
    _scheduleControlsHide();
  }

  Future<void> _openVideo({required bool play}) async {
    final player = _player;
    if (player == null || _videoUrls.isEmpty) return;
    final remembered = _playbackMemory[widget.post.cacheKey];
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
        play: false,
      );
      await _applyVolume();
      if (initialPosition > Duration.zero) {
        await player.seek(initialPosition);
      }
      if (shouldPlay) await player.play();
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
    if (mounted) {
      setState(() => _videoError = message);
    }
  }

  Future<void> _retryVideo() async {
    _videoIndex = 0;
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
    final snapshot = _snapshot();
    _playbackMemory[widget.post.cacheKey] = snapshot;
    widget.onPlaybackSnapshot?.call(snapshot);
    _player?.pause();
    _player?.stop();
    _player?.dispose();
    _player = null;
    _controller = null;
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
          pageBuilder: (_, __, ___) => _FullscreenImageViewerPage(
            posts: posts,
            initialIndex: initialIndex,
            qualityMode: widget.qualityMode,
            notes: widget.notes,
            showNotes: widget.showNotes,
            headersBuilder: (p) => _headersFor(p),
            localFilePath: widget.localFilePath,
            initialVideoPosition: initialVideoPos,
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
    final memory = _playbackMemory[widget.post.cacheKey];
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
    _playbackMemory[widget.post.cacheKey] = snapshot;
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

class _TogglePlayIntent extends Intent {
  const _TogglePlayIntent();
}

class _SeekVideoIntent extends Intent {
  const _SeekVideoIntent(this.seconds);
  final int seconds;
}

class _VolumeVideoIntent extends Intent {
  const _VolumeVideoIntent(this.deltaY);
  final double deltaY;
}

class _MuteVideoIntent extends Intent {
  const _MuteVideoIntent();
}

class _FullscreenVideoIntent extends Intent {
  const _FullscreenVideoIntent();
}

class _LoopVideoIntent extends Intent {
  const _LoopVideoIntent();
}

class _ZoomInIntent extends Intent {
  const _ZoomInIntent();
}

class _ZoomOutIntent extends Intent {
  const _ZoomOutIntent();
}

class _ResetZoomIntent extends Intent {
  const _ResetZoomIntent();
}

class _PrevImageIntent extends Intent {
  const _PrevImageIntent();
}

class _NextImageIntent extends Intent {
  const _NextImageIntent();
}

class _FullscreenImageIntent extends Intent {
  const _FullscreenImageIntent();
}

class _CloseFullscreenIntent extends Intent {
  const _CloseFullscreenIntent();
}

class _ToggleControlsIntent extends Intent {
  const _ToggleControlsIntent();
}

class _PrevFullscreenImageIntent extends Intent {
  const _PrevFullscreenImageIntent();
}

class _NextFullscreenImageIntent extends Intent {
  const _NextFullscreenImageIntent();
}

class _UnsupportedSwfPanel extends StatelessWidget {
  const _UnsupportedSwfPanel();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: Colors.black,
      child: Center(
        child: Padding(
          padding: EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.extension_off_rounded, color: Colors.white, size: 48),
              SizedBox(height: 12),
              Text(
                'SWF / Flash is not supported in this build',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class VideoPlaybackSnapshot {
  const VideoPlaybackSnapshot({
    required this.position,
    required this.playing,
    required this.muted,
    required this.halfVolume,
    required this.loopVideo,
    required this.coverVideo,
    this.volume = 100.0,
  });

  final Duration position;
  final bool playing;
  final bool muted;
  final bool halfVolume;
  final bool loopVideo;
  final bool coverVideo;
  final double volume;
}

class _FullscreenImageViewerPage extends ConsumerStatefulWidget {
  const _FullscreenImageViewerPage({
    required this.posts,
    required this.initialIndex,
    required this.qualityMode,
    required this.notes,
    required this.showNotes,
    required this.headersBuilder,
    this.localFilePath,
    this.initialVideoPosition = Duration.zero,
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
  ConsumerState<_FullscreenImageViewerPage> createState() =>
      _FullscreenImageViewerPageState();
}

class _FullscreenImageViewerPageState
    extends ConsumerState<_FullscreenImageViewerPage>
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
              CachedNetworkImageProvider(url, headers: widget.headersBuilder(p)),
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
      SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
      Future.delayed(const Duration(milliseconds: 300), () {
        SystemChrome.setPreferredOrientations([]);
      });
    } else {
      SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isRu = Localizations.maybeLocaleOf(context)?.languageCode == 'ru';
    final backdropAlpha = (1.0 - (_dragOffsetY.abs() / 320.0)).clamp(0.0, 1.0);

    final feedPosts = ref.watch(feedControllerProvider).value?.posts;
    final List<Post> resolvedPosts;
    if (feedPosts != null && feedPosts.isNotEmpty) {
      final hasCurrent = _currentIndex < widget.posts.length &&
          feedPosts.any((p) => p.cacheKey == widget.posts[_currentIndex].cacheKey);
      if (hasCurrent || feedPosts.length >= widget.posts.length) {
        resolvedPosts = feedPosts;
      } else {
        resolvedPosts = widget.posts;
      }
    } else {
      resolvedPosts = widget.posts;
    }

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
            LogicalKeySet(LogicalKeyboardKey.escape): const _CloseFullscreenIntent(),
            LogicalKeySet(LogicalKeyboardKey.keyF): const _CloseFullscreenIntent(),
            LogicalKeySet(LogicalKeyboardKey.space): const _ToggleControlsIntent(),
            LogicalKeySet(LogicalKeyboardKey.arrowLeft): const _PrevFullscreenImageIntent(),
            LogicalKeySet(LogicalKeyboardKey.keyA): const _PrevFullscreenImageIntent(),
            LogicalKeySet(LogicalKeyboardKey.arrowRight): const _NextFullscreenImageIntent(),
            LogicalKeySet(LogicalKeyboardKey.keyD): const _NextFullscreenImageIntent(),
          },
          child: Actions(
            actions: {
              _CloseFullscreenIntent: CallbackAction<_CloseFullscreenIntent>(
                onInvoke: (_) {
                  _close();
                  return null;
                },
              ),
              _ToggleControlsIntent: CallbackAction<_ToggleControlsIntent>(
                onInvoke: (_) {
                  _toggleControls();
                  return null;
                },
              ),
              _PrevFullscreenImageIntent: CallbackAction<_PrevFullscreenImageIntent>(
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
              _NextFullscreenImageIntent: CallbackAction<_NextFullscreenImageIntent>(
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
                        scale: (1.0 - (_dragOffsetY.abs() / 1500.0)).clamp(0.82, 1.0),
                        child: PageView.builder(
                          controller: _pageController,
                          itemCount: resolvedPosts.length,
                          physics: _isCurrentZoomed
                              ? const NeverScrollableScrollPhysics()
                              : const BouncingScrollPhysics(),
                          onPageChanged: (idx) => _onPageChanged(idx, resolvedPosts),
                          itemBuilder: (context, index) {
                            final currentPost = resolvedPosts[index];
                            final isInitial = index == widget.initialIndex;
                            final localPath = isInitial ? widget.localFilePath : null;
                            final isVideo = MediaUrlSelector.isVideo(currentPost) ||
                                MediaUrlSelector.isAudio(currentPost) ||
                                currentPost.cloudLinks.any((l) => l.isStreamable);

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

                            final urls = _FullscreenImageViewerPage._urlsForPost(
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
        _initPlayer();
      }
    } else if (!widget.isActive && oldWidget.isActive) {
      _player?.pause();
    }
  }

  void _initPlayer() {
    MediaKit.ensureInitialized();
    final p = Player();
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

    p.stream.error.listen((message) {
      if (mounted) setState(() => _errorMessage = message);
    });

    p.stream.position.listen((pos) {
      if (!mounted) return;
      _playbackMemory[widget.post.cacheKey] = VideoPlaybackSnapshot(
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
      p.open(
        Media(src, httpHeaders: isLocal ? null : widget.headers),
        play: false,
      ).then((_) {
        if (widget.initialPosition > Duration.zero) {
          p.seek(widget.initialPosition);
        }
      }).catchError((err) {
        if (mounted) setState(() => _errorMessage = err.toString());
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
    _player?.setVolume(_muted ? 0.0 : _halfVolume ? 50.0 : _volume);
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
    if (_player != null) {
      final pos = _player!.state.position;
      final isPlaying = _player!.state.playing;
      _playbackMemory[widget.post.cacheKey] = VideoPlaybackSnapshot(
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
            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
          ),
        ],
      );
    }

    final double aspect = (widget.post.width > 0 && widget.post.height > 0)
        ? (widget.post.width / widget.post.height).clamp(0.4, 2.5)
        : 16 / 9;

    final topOffset = MediaQuery.of(context).padding.top + 50.0;

    return _VideoSurface(
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
    if (widget.post.previewUrl.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: widget.post.previewUrl,
        httpHeaders: widget.headers,
        fit: BoxFit.contain,
        errorWidget: (_, __, ___) => const Center(
          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white54),
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
          child: Icon(Icons.broken_image_rounded, size: 64, color: Colors.white54),
        ),
      );
    } else {
      final mq = MediaQuery.maybeOf(context);
      final dpr = mq?.devicePixelRatio ?? 1.5;
      final screenWidth = mq?.size.width ?? 1080;
      final maxCacheWidth = (screenWidth * dpr).round().clamp(720, 2048);
      final isGif = MediaUrlSelector.isGif(widget.post) ||
          currentUrl.toLowerCase().contains('.gif') ||
          widget.post.fileType.toLowerCase() == 'gif';

      imageWidget = CachedNetworkImage(
        key: ValueKey(currentUrl),
        imageUrl: currentUrl,
        httpHeaders: widget.headers,
        memCacheWidth: isGif ? null : maxCacheWidth,
        fit: BoxFit.contain,
        placeholder: (context, url) => _buildPlaceholder(),
        errorWidget: (context, url, error) {
          if (_urlIndex < widget.urls.length - 1) {
            _advanceFallback();
            return _buildPlaceholder();
          }
          return _DioImageFallback(
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
          _PostNotesOverlay(
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
                GestureBinding.instance.pointerSignalResolver
                    .register(event, (_) {
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

class _AudioSurface extends StatefulWidget {
  const _AudioSurface({
    required this.player,
    required this.post,
    required this.muted,
    required this.loopAudio,
    this.initialVolume = 100.0,
    this.onVolumeChanged,
    required this.fullscreen,
    required this.errorMessage,
    required this.onRetry,
    required this.onToggleMute,
    required this.onToggleLoop,
  });

  final Player player;
  final Post post;
  final bool muted;
  final bool loopAudio;
  final double initialVolume;
  final ValueChanged<double>? onVolumeChanged;
  final bool fullscreen;
  final String? errorMessage;
  final VoidCallback onRetry;
  final VoidCallback onToggleMute;
  final VoidCallback onToggleLoop;

  @override
  State<_AudioSurface> createState() => _AudioSurfaceState();
}

class _AudioSurfaceState extends State<_AudioSurface>
    with SingleTickerProviderStateMixin {
  late final AnimationController _rotationController;
  StreamSubscription<Duration>? _posSub;
  StreamSubscription<Duration>? _durSub;
  StreamSubscription<bool>? _playSub;
  StreamSubscription<bool>? _buffSub;

  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  bool _playing = false;
  bool _buffering = false;
  bool _isDragging = false;
  double _dragValue = 0.0;

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 14),
    );
    _position = widget.player.state.position;
    _duration = widget.player.state.duration;
    _playing = widget.player.state.playing;
    _buffering = widget.player.state.buffering;
    if (_playing) _rotationController.repeat();

    _posSub = widget.player.stream.position.listen((pos) {
      if (mounted && !_isDragging) {
        setState(() => _position = pos);
      }
    });
    _durSub = widget.player.stream.duration.listen((dur) {
      if (mounted) setState(() => _duration = dur);
    });
    _playSub = widget.player.stream.playing.listen((playing) {
      if (mounted) {
        setState(() => _playing = playing);
        if (playing) {
          _rotationController.repeat();
        } else {
          _rotationController.stop();
        }
      }
    });
    _buffSub = widget.player.stream.buffering.listen((buffering) {
      if (mounted) setState(() => _buffering = buffering);
    });
  }

  @override
  void dispose() {
    _rotationController.dispose();
    _posSub?.cancel();
    _durSub?.cancel();
    _playSub?.cancel();
    _buffSub?.cancel();
    super.dispose();
  }

  String _formatTime(Duration d) {
    final minutes = d.inMinutes;
    final seconds = d.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  String _deriveTitle() {
    final title = (widget.post.title ?? '').trim();
    if (title.isNotEmpty) return title;
    final uri = Uri.tryParse(widget.post.fileUrl);
    if (uri != null) {
      final q = uri.queryParameters['f'];
      if (q != null && q.trim().isNotEmpty) return q.trim();
      final seg = uri.pathSegments.lastOrNull;
      if (seg != null && seg.isNotEmpty) return seg;
    }
    final isRu = Localizations.maybeLocaleOf(context)?.languageCode == 'ru';
    return isRu ? 'Аудиозапись' : 'Audio track';
  }

  void _seekRelative(int seconds) {
    final target = _position + Duration(seconds: seconds);
    final maxDur = _duration > Duration.zero ? _duration : target;
    final clamped = Duration(
      milliseconds: target.inMilliseconds.clamp(0, maxDur.inMilliseconds),
    );
    widget.player.seek(clamped);
  }

  @override
  Widget build(BuildContext context) {
    final isRu = Localizations.maybeLocaleOf(context)?.languageCode == 'ru';
    final theme = Theme.of(context);
    final title = _deriveTitle();
    final artistName =
        widget.post.tagGroups['artist']?.firstOrNull ?? widget.post.providerName;
    final hasCover = widget.post.previewUrl.isNotEmpty &&
        widget.post.previewUrl.startsWith('http');

    if (widget.errorMessage != null) {
      return Center(
        child: Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: theme.colorScheme.error.withValues(alpha: 0.4)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline_rounded,
                  size: 40, color: theme.colorScheme.error),
              const SizedBox(height: 12),
              Text(
                isRu
                    ? 'Не удалось воспроизвести аудио'
                    : 'Could not play audio',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                widget.errorMessage!,
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: widget.onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: Text(isRu ? 'Повторить попытку' : 'Retry'),
              ),
            ],
          ),
        ),
      );
    }

    final maxMs = _duration.inMilliseconds > 0
        ? _duration.inMilliseconds.toDouble()
        : 1.0;
    final currentMs = (_isDragging ? _dragValue : _position.inMilliseconds.toDouble())
        .clamp(0.0, maxMs);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            theme.colorScheme.surfaceContainerHighest,
            theme.colorScheme.surfaceContainer,
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.35),
          width: 0.8,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Top Row: Vinyl / Album Art + Title + Artist
          Row(
            children: [
              // Rotating Album Art / Vinyl
              RotationTransition(
                turns: _rotationController,
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        theme.colorScheme.primary.withValues(alpha: 0.9),
                        Colors.black87,
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: theme.colorScheme.primary.withValues(alpha: 0.35),
                        blurRadius: 12,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Center(
                    child: hasCover
                        ? ClipOval(
                            child: CachedNetworkImage(
                              imageUrl: widget.post.previewUrl,
                              width: 44,
                              height: 44,
                              fit: BoxFit.cover,
                              errorWidget: (_, __, ___) => Icon(
                                Icons.audiotrack_rounded,
                                color: theme.colorScheme.onPrimary,
                                size: 26,
                              ),
                            ),
                          )
                        : Container(
                            width: 26,
                            height: 26,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: theme.colorScheme.surface,
                            ),
                            child: Icon(
                              Icons.audiotrack_rounded,
                              size: 16,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              // Track & Artist Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.2,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.person_outline_rounded,
                          size: 14,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            artistName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Timeline Slider
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 4.5,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6.5),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
              activeTrackColor: theme.colorScheme.primary,
              inactiveTrackColor:
                  theme.colorScheme.onSurface.withValues(alpha: 0.15),
              thumbColor: theme.colorScheme.primary,
            ),
            child: Slider(
              value: currentMs,
              min: 0.0,
              max: maxMs,
              onChanged: (val) {
                setState(() {
                  _isDragging = true;
                  _dragValue = val;
                });
              },
              onChangeEnd: (val) {
                _isDragging = false;
                widget.player.seek(Duration(milliseconds: val.toInt()));
              },
            ),
          ),

          // Time numbers: elapsed & total
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _formatTime(_position),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontSize: 11,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                if (_buffering)
                  SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                Text(
                  _formatTime(_duration),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontSize: 11,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Controls Row: Loop, -10s, Play/Pause, +10s, Mute
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              IconButton(
                tooltip: widget.loopAudio
                    ? (isRu ? 'Повтор: включен' : 'Repeat: on')
                    : (isRu ? 'Повтор: выключен' : 'Repeat: off'),
                icon: Icon(
                  widget.loopAudio ? Icons.repeat_one_rounded : Icons.repeat_rounded,
                  color: widget.loopAudio
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurfaceVariant,
                  size: 22,
                ),
                onPressed: widget.onToggleLoop,
              ),
              IconButton(
                tooltip: isRu ? 'Назад на 10 сек' : 'Rewind 10 sec',
                icon: const Icon(Icons.replay_10_rounded, size: 26),
                color: theme.colorScheme.onSurface,
                onPressed: () => _seekRelative(-10),
              ),
              // Big Play / Pause Button
              GestureDetector(
                onTap: () {
                  if (_playing) {
                    widget.player.pause();
                  } else {
                    widget.player.play();
                  }
                },
                child: Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: theme.colorScheme.primary.withValues(alpha: 0.4),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Icon(
                    _playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    color: theme.colorScheme.onPrimary,
                    size: 30,
                  ),
                ),
              ),
              IconButton(
                tooltip: isRu ? 'Вперед на 10 сек' : 'Forward 10 sec',
                icon: const Icon(Icons.forward_10_rounded, size: 26),
                color: theme.colorScheme.onSurface,
                onPressed: () => _seekRelative(10),
              ),
              IconButton(
                tooltip: widget.muted
                    ? (isRu ? 'Включить звук' : 'Unmute')
                    : (isRu ? 'Выключить звук' : 'Mute'),
                icon: Icon(
                  widget.muted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                  color: widget.muted
                      ? theme.colorScheme.error
                      : theme.colorScheme.onSurfaceVariant,
                  size: 22,
                ),
                onPressed: widget.onToggleMute,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _VideoSurface extends StatefulWidget {
  const _VideoSurface({
    required this.player,
    required this.controller,
    required this.aspectRatio,
    required this.isSoftwareDecoding,
    required this.onToggleDecoder,
    required this.controlsVisible,
    required this.coverVideo,
    required this.muted,
    required this.halfVolume,
    required this.loopVideo,
    this.initialVolume = 100.0,
    this.onVolumeChanged,
    required this.fullscreen,
    required this.errorMessage,
    this.onTapSurface,
    required this.onInteract,
    required this.onRetry,
    required this.onToggleFit,
    required this.onToggleMute,
    required this.onToggleHalfVolume,
    required this.onToggleLoop,
    required this.onFullscreen,
    this.isLandscape,
    this.onToggleOrientation,
    this.topOffset = 0.0,
    this.inGallery = false,
  });

  final Player player;
  final VideoController controller;
  final double aspectRatio;
  final bool isSoftwareDecoding;
  final VoidCallback onToggleDecoder;
  final bool controlsVisible;
  final bool coverVideo;
  final bool muted;
  final bool halfVolume;
  final bool loopVideo;
  final double initialVolume;
  final ValueChanged<double>? onVolumeChanged;
  final bool fullscreen;
  final String? errorMessage;
  final VoidCallback? onTapSurface;
  final VoidCallback onInteract;
  final VoidCallback onRetry;
  final VoidCallback onToggleFit;
  final VoidCallback onToggleMute;
  final VoidCallback onToggleHalfVolume;
  final VoidCallback onToggleLoop;
  final VoidCallback onFullscreen;
  final bool? isLandscape;
  final VoidCallback? onToggleOrientation;
  final double topOffset;
  final bool inGallery;

  @override
  State<_VideoSurface> createState() => _VideoSurfaceState();
}

class _VideoSurfaceState extends State<_VideoSurface> {
  bool _isLocked = false;
  bool _showLeftSeek = false;
  bool _showRightSeek = false;
  Timer? _seekLeftTimer;
  Timer? _seekRightTimer;

  bool _isSpeedBoosted = false;
  double _savedRate = 1.0;

  bool _showVolumeIndicator = false;
  double _currentVolume = 100;
  Timer? _volumeTimer;

  bool _showBrightnessIndicator = false;
  double _currentBrightness = 1.0;
  Timer? _brightnessTimer;

  @override
  void initState() {
    super.initState();
    _currentVolume = widget.initialVolume;
    widget.player.setVolume(_currentVolume);
  }

  @override
  void didUpdateWidget(covariant _VideoSurface oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialVolume != widget.initialVolume) {
      _currentVolume = widget.initialVolume;
      widget.player.setVolume(_currentVolume);
    }
  }

  @override
  void dispose() {
    _seekLeftTimer?.cancel();
    _seekRightTimer?.cancel();
    _volumeTimer?.cancel();
    _brightnessTimer?.cancel();
    super.dispose();
  }

  void _seekBy(Duration delta) {
    final pos = widget.player.state.position;
    final dur = widget.player.state.duration;
    var target = pos + delta;
    if (target < Duration.zero) target = Duration.zero;
    if (dur > Duration.zero && target > dur) target = dur;
    widget.player.seek(target);
    widget.onInteract();
    if (delta.inSeconds < 0) {
      setState(() => _showLeftSeek = true);
      _seekLeftTimer?.cancel();
      _seekLeftTimer = Timer(const Duration(milliseconds: 650), () {
        if (mounted) setState(() => _showLeftSeek = false);
      });
    } else if (delta.inSeconds > 0) {
      setState(() => _showRightSeek = true);
      _seekRightTimer?.cancel();
      _seekRightTimer = Timer(const Duration(milliseconds: 650), () {
        if (mounted) setState(() => _showRightSeek = false);
      });
    }
  }

  void _onDoubleTapAt(Offset localPosition, double width) {
    if (_isLocked) return;
    if (localPosition.dx < width * 0.4) {
      _seekBy(const Duration(seconds: -10));
    } else if (localPosition.dx > width * 0.6) {
      _seekBy(const Duration(seconds: 10));
    } else {
      if (widget.player.state.playing) {
        widget.player.pause();
      } else {
        if (widget.player.state.completed) {
          widget.player.seek(Duration.zero);
        }
        widget.player.play();
      }
      widget.onInteract();
    }
  }

  void _startSpeedBoost() {
    if (_isLocked) return;
    _savedRate = widget.player.state.rate;
    widget.player.setRate(2.0);
    setState(() => _isSpeedBoosted = true);
  }

  void _stopSpeedBoost() {
    if (!_isSpeedBoosted) return;
    widget.player.setRate(_savedRate);
    setState(() => _isSpeedBoosted = false);
  }

  void _adjustVolume(double deltaY) {
    if (_isLocked) return;
    final newVol = (_currentVolume - deltaY * 0.5).clamp(0.0, 100.0);
    _currentVolume = newVol;
    widget.player.setVolume(newVol);
    widget.onVolumeChanged?.call(newVol);
    setState(() => _showVolumeIndicator = true);
    _volumeTimer?.cancel();
    _volumeTimer = Timer(const Duration(milliseconds: 1100), () {
      if (mounted) setState(() => _showVolumeIndicator = false);
    });
  }

  void _adjustBrightness(double deltaY) {
    if (_isLocked) return;
    final newB = (_currentBrightness - deltaY * 0.004).clamp(0.08, 1.0);
    setState(() {
      _currentBrightness = newB;
      _showBrightnessIndicator = true;
    });
    _brightnessTimer?.cancel();
    _brightnessTimer = Timer(const Duration(milliseconds: 1100), () {
      if (mounted) setState(() => _showBrightnessIndicator = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final player = widget.player;
    Offset? lastTapDown;

    final child = LayoutBuilder(
      builder: (context, constraints) {
        return Stack(
          fit: StackFit.expand,
          children: [
            ColoredBox(
              color: Colors.black,
              child: Video(
                controller: widget.controller,
                fit: widget.coverVideo ? BoxFit.cover : BoxFit.contain,
                controls: null,
                pauseUponEnteringBackgroundMode: false,
                resumeUponEnteringForegroundMode: false,
              ),
            ),
            if (_currentBrightness < 0.99)
              Positioned.fill(
                child: IgnorePointer(
                  child: ColoredBox(
                    color: Colors.black.withValues(
                      alpha: (1.0 - _currentBrightness).clamp(0.0, 0.92),
                    ),
                  ),
                ),
              ),
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapDown: (details) => lastTapDown = details.localPosition,
                onTap: widget.onTapSurface ?? widget.onInteract,
                onDoubleTap: () {
                  if (lastTapDown != null) {
                    _onDoubleTapAt(
                      lastTapDown!,
                      MediaQuery.sizeOf(context).width,
                    );
                  }
                },
                onLongPressStart: (_) => _startSpeedBoost(),
                onLongPressEnd: (_) => _stopSpeedBoost(),
                onVerticalDragUpdate: widget.fullscreen
                    ? (details) {
                        final x = details.localPosition.dx;
                        final width = MediaQuery.sizeOf(context).width;
                        if (x < width * 0.45) {
                          _adjustBrightness(details.primaryDelta ?? 0.0);
                        } else if (x > width * 0.55) {
                          _adjustVolume(details.primaryDelta ?? 0.0);
                        }
                      }
                    : null,
              ),
            ),
            StreamBuilder<bool>(
              stream: player.stream.buffering,
              initialData: player.state.buffering,
              builder: (context, snapshot) {
                if (snapshot.data != true || widget.errorMessage != null) {
                  return const SizedBox.shrink();
                }
                return const Center(child: CircularProgressIndicator());
              },
            ),
            _DoubleTapSeekRipple(isLeft: true, visible: _showLeftSeek),
            _DoubleTapSeekRipple(isLeft: false, visible: _showRightSeek),
            if (_showVolumeIndicator)
              _VolumeGestureBadge(volume: _currentVolume),
            if (_showBrightnessIndicator)
              _BrightnessGestureBadge(brightness: _currentBrightness),
            if (_isSpeedBoosted)
              const _SpeedBoostOverlayBadge(),
            if (widget.errorMessage != null)
              VideoErrorOverlay(
                message: widget.errorMessage!,
                onRetry: widget.onRetry,
              ),
            IgnorePointer(
              ignoring: (!widget.controlsVisible && !_isLocked) ||
                  widget.errorMessage != null,
              child: AnimatedOpacity(
                opacity: (widget.controlsVisible || _isLocked) &&
                        widget.errorMessage == null
                    ? 1
                    : 0,
                duration: AppMotion.duration(context, 180),
                child: _VideoControls(
                  player: player,
                  muted: widget.muted,
                  halfVolume: widget.halfVolume,
                  loopVideo: widget.loopVideo,
                  coverVideo: widget.coverVideo,
                  fullscreen: widget.fullscreen,
                  topOffset: widget.topOffset,
                  inGallery: widget.inGallery,
                  isLocked: _isLocked,
                  isLandscape: widget.isLandscape,
                  isSoftwareDecoding: widget.isSoftwareDecoding,
                  onToggleDecoder: widget.onToggleDecoder,
                  onToggleOrientation: widget.onToggleOrientation,
                  onToggleLock: () => setState(() => _isLocked = !_isLocked),
                  onToggleFit: widget.onToggleFit,
                  onToggleMute: widget.onToggleMute,
                  onToggleHalfVolume: widget.onToggleHalfVolume,
                  onToggleLoop: widget.onToggleLoop,
                  onFullscreen: widget.onFullscreen,
                  onSeekBy: _seekBy,
                  onInteract: widget.onInteract,
                ),
              ),
            ),
          ],
        );
      },
    );

    return Shortcuts(
      shortcuts: {
        LogicalKeySet(LogicalKeyboardKey.space): const _TogglePlayIntent(),
        LogicalKeySet(LogicalKeyboardKey.keyK): const _TogglePlayIntent(),
        LogicalKeySet(LogicalKeyboardKey.arrowLeft): const _SeekVideoIntent(-5),
        LogicalKeySet(LogicalKeyboardKey.keyJ): const _SeekVideoIntent(-5),
        LogicalKeySet(LogicalKeyboardKey.arrowRight): const _SeekVideoIntent(5),
        LogicalKeySet(LogicalKeyboardKey.keyL): const _SeekVideoIntent(5),
        LogicalKeySet(LogicalKeyboardKey.shift, LogicalKeyboardKey.arrowLeft):
            const _SeekVideoIntent(-15),
        LogicalKeySet(LogicalKeyboardKey.shift, LogicalKeyboardKey.arrowRight):
            const _SeekVideoIntent(15),
        LogicalKeySet(LogicalKeyboardKey.arrowUp): const _VolumeVideoIntent(-10),
        LogicalKeySet(LogicalKeyboardKey.arrowDown): const _VolumeVideoIntent(10),
        LogicalKeySet(LogicalKeyboardKey.keyM): const _MuteVideoIntent(),
        LogicalKeySet(LogicalKeyboardKey.keyF): const _FullscreenVideoIntent(),
        LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyL):
            const _LoopVideoIntent(),
      },
      child: Actions(
        actions: {
          _TogglePlayIntent: CallbackAction<_TogglePlayIntent>(
            onInvoke: (_) {
              if (widget.player.state.playing) {
                widget.player.pause();
              } else {
                if (widget.player.state.completed) {
                  widget.player.seek(Duration.zero);
                }
                widget.player.play();
              }
              widget.onInteract();
              return null;
            },
          ),
          _SeekVideoIntent: CallbackAction<_SeekVideoIntent>(
            onInvoke: (intent) {
              _seekBy(Duration(seconds: intent.seconds));
              return null;
            },
          ),
          _VolumeVideoIntent: CallbackAction<_VolumeVideoIntent>(
            onInvoke: (intent) {
              _adjustVolume(intent.deltaY);
              return null;
            },
          ),
          _MuteVideoIntent: CallbackAction<_MuteVideoIntent>(
            onInvoke: (_) {
              widget.onToggleMute();
              return null;
            },
          ),
          _FullscreenVideoIntent: CallbackAction<_FullscreenVideoIntent>(
            onInvoke: (_) {
              widget.onFullscreen();
              return null;
            },
          ),
          _LoopVideoIntent: CallbackAction<_LoopVideoIntent>(
            onInvoke: (_) {
              widget.onToggleLoop();
              return null;
            },
          ),
        },
        child: Focus(
          autofocus: true,
          child: Listener(
            onPointerSignal: (event) {
              if (event is PointerScrollEvent && !widget.fullscreen) {
                final scrollable = Scrollable.maybeOf(context);
                if (scrollable != null && scrollable.position.hasPixels) {
                  final pos = scrollable.position;
                  final target = (pos.pixels + event.scrollDelta.dy)
                      .clamp(pos.minScrollExtent, pos.maxScrollExtent);
                  pos.jumpTo(target);
                }
              }
            },
            child: MouseRegion(
              onHover: (_) => widget.onInteract(),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(widget.fullscreen ? 0 : 10),
                child: widget.fullscreen
                    ? SizedBox.expand(child: child)
                    : AspectRatio(
                        aspectRatio: widget.aspectRatio.clamp(0.35, 2.4),
                        child: child,
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class VideoErrorOverlay extends StatelessWidget {
  const VideoErrorOverlay({
    required this.message,
    required this.onRetry,
    super.key,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black.withValues(alpha: 0.62),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded,
                  color: Colors.white, size: 42),
              const SizedBox(height: 10),
              Text(
                'Could not load video',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(color: Colors.white),
              ),
              const SizedBox(height: 6),
              Text(
                message,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DioImageFallback extends StatefulWidget {
  const _DioImageFallback({
    required this.imageUrl,
    required this.headers,
    required this.fit,
    required this.onFailed,
  });

  final String imageUrl;
  final Map<String, String> headers;
  final BoxFit fit;
  final VoidCallback onFailed;

  @override
  State<_DioImageFallback> createState() => _DioImageFallbackState();
}

class _DioImageFallbackState extends State<_DioImageFallback> {
  late final Future<Uint8List> _bytes = _load();
  bool _reportedFailure = false;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List>(
      future: _bytes,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        final bytes = snapshot.data;
        if (snapshot.hasError || bytes == null || bytes.isEmpty) {
          _reportFailure();
          return const _ImageLoadError();
        }
        return Image.memory(
          bytes,
          fit: widget.fit,
          gaplessPlayback: true,
          errorBuilder: (context, error, stackTrace) {
            _reportFailure();
            return const _ImageLoadError();
          },
        );
      },
    );
  }

  Future<Uint8List> _load() async {
    final response = await Dio().get<List<int>>(
      widget.imageUrl,
      options: Options(
        responseType: ResponseType.bytes,
        headers: widget.headers,
        followRedirects: true,
        receiveTimeout: const Duration(seconds: 20),
        sendTimeout: const Duration(seconds: 10),
      ),
    );
    final data = response.data;
    if (response.statusCode == null ||
        response.statusCode! < 200 ||
        response.statusCode! >= 300 ||
        data == null ||
        data.isEmpty) {
      throw StateError('Could not load image');
    }
    return Uint8List.fromList(data);
  }

  void _reportFailure() {
    if (_reportedFailure) return;
    _reportedFailure = true;
    widget.onFailed();
  }
}

class _ImageLoadError extends StatelessWidget {
  const _ImageLoadError();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.broken_image_rounded, size: 48),
          SizedBox(height: 8),
          Text('Could not load image'),
        ],
      ),
    );
  }
}

class _ZoomableImage extends StatefulWidget {
  const _ZoomableImage({
    required this.child,
    this.onGestureLockChanged,
    this.onTap,
  });

  final Widget child;
  final ValueChanged<bool>? onGestureLockChanged;
  final VoidCallback? onTap;

  @override
  State<_ZoomableImage> createState() => _ZoomableImageState();
}

class _ZoomableImageState extends State<_ZoomableImage> {
  final _controller = TransformationController();
  TapDownDetails? _doubleTapDetails;
  bool _zoomed = false;
  int _pointerCount = 0;
  bool _locked = false;

  @override
  void dispose() {
    _setLocked(false);
    _controller.dispose();
    super.dispose();
  }

  void _zoomIn() {
    final currentScale = _controller.value.getMaxScaleOnAxis();
    final newScale = (currentScale * 1.35).clamp(1.0, 6.0);
    _controller.value = Matrix4.identity()..scaleByDouble(newScale, newScale, 1, 1);
    if (mounted) setState(() => _zoomed = newScale > 1.02);
    _setLocked(_zoomed);
  }

  void _zoomOut() {
    final currentScale = _controller.value.getMaxScaleOnAxis();
    final newScale = (currentScale / 1.35).clamp(1.0, 6.0);
    if (newScale <= 1.02) {
      _controller.value = Matrix4.identity();
      if (mounted) setState(() => _zoomed = false);
      _setLocked(false);
    } else {
      _controller.value = Matrix4.identity()..scaleByDouble(newScale, newScale, 1, 1);
      if (mounted) setState(() => _zoomed = true);
      _setLocked(true);
    }
  }

  void _resetZoom() {
    _controller.value = Matrix4.identity();
    if (mounted) setState(() => _zoomed = false);
    _setLocked(false);
  }

  @override
  Widget build(BuildContext context) {
    return Shortcuts(
      shortcuts: {
        LogicalKeySet(LogicalKeyboardKey.equal): const _ZoomInIntent(),
        LogicalKeySet(LogicalKeyboardKey.add): const _ZoomInIntent(),
        LogicalKeySet(LogicalKeyboardKey.numpadAdd): const _ZoomInIntent(),
        LogicalKeySet(LogicalKeyboardKey.minus): const _ZoomOutIntent(),
        LogicalKeySet(LogicalKeyboardKey.numpadSubtract): const _ZoomOutIntent(),
        LogicalKeySet(LogicalKeyboardKey.digit0): const _ResetZoomIntent(),
        LogicalKeySet(LogicalKeyboardKey.numpad0): const _ResetZoomIntent(),
        LogicalKeySet(LogicalKeyboardKey.escape): const _ResetZoomIntent(),
      },
      child: Actions(
        actions: {
          _ZoomInIntent: CallbackAction<_ZoomInIntent>(
            onInvoke: (_) {
              _zoomIn();
              return null;
            },
          ),
          _ZoomOutIntent: CallbackAction<_ZoomOutIntent>(
            onInvoke: (_) {
              _zoomOut();
              return null;
            },
          ),
          _ResetZoomIntent: CallbackAction<_ResetZoomIntent>(
            onInvoke: (_) {
              if (_zoomed) {
                _resetZoom();
              }
              return null;
            },
          ),
        },
        child: Focus(
          autofocus: true,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final hasFrame =
                  constraints.hasBoundedWidth && constraints.hasBoundedHeight;
              final child = hasFrame
                  ? SizedBox(
                      width: constraints.maxWidth,
                      height: constraints.maxHeight,
                      child: widget.child,
                    )
                  : widget.child;
              return Listener(
                onPointerDown: (_) {
                  _pointerCount++;
                  if (_pointerCount >= 2 || _zoomed) {
                    _setLocked(true);
                  }
                },
                onPointerUp: (_) => _releasePointer(),
                onPointerCancel: (_) => _releasePointer(),
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    if (!_zoomed) {
                      widget.onTap?.call();
                    }
                  },
                  onDoubleTapDown: (details) => _doubleTapDetails = details,
                  onDoubleTap: _toggleZoom,
                  child: InteractiveViewer(
                    transformationController: _controller,
                    minScale: 1,
                    maxScale: 6,
                    scaleFactor: 1000000.0,
                    boundaryMargin: const EdgeInsets.all(160),
                    panEnabled: _zoomed,
                    scaleEnabled: _zoomed || _pointerCount >= 2,
                    clipBehavior: Clip.none,
                    onInteractionStart: (_) {
                      if (_pointerCount >= 2 || _zoomed) _setLocked(true);
                    },
                    onInteractionEnd: (_) {
                      final scale = _controller.value.getMaxScaleOnAxis();
                      final nextZoomed = scale > 1.03;
                      if (!nextZoomed) {
                        _controller.value = Matrix4.identity();
                      }
                      if (mounted) setState(() => _zoomed = nextZoomed);
                      _setLocked(nextZoomed || _pointerCount >= 2);
                    },
                    child: Listener(
                      onPointerSignal: (event) {
                        if (event is PointerScrollEvent) {
                          final isZoomKey =
                              HardwareKeyboard.instance.isControlPressed ||
                                  HardwareKeyboard.instance.isMetaPressed;
                          if (isZoomKey) {
                            GestureBinding.instance.pointerSignalResolver
                                .register(event, (_) {
                              if (event.scrollDelta.dy < 0) {
                                _zoomIn();
                              } else if (event.scrollDelta.dy > 0) {
                                _zoomOut();
                              }
                            });
                          } else {
                            final scrollable = Scrollable.maybeOf(context);
                            if (scrollable != null && scrollable.position.hasPixels) {
                              final pos = scrollable.position;
                              final target = (pos.pixels + event.scrollDelta.dy)
                                  .clamp(pos.minScrollExtent, pos.maxScrollExtent);
                              pos.jumpTo(target);
                            }
                          }
                        }
                      },
                      child: child,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  void _toggleZoom() {
    final tap = _doubleTapDetails?.localPosition ?? Offset.zero;
    if (_zoomed) {
      _controller.value = Matrix4.identity();
      setState(() => _zoomed = false);
      _setLocked(false);
      return;
    }
    const scale = 2.5;
    _controller.value = Matrix4.identity()
      ..translateByDouble(-tap.dx * (scale - 1), -tap.dy * (scale - 1), 0, 1)
      ..scaleByDouble(scale, scale, 1, 1);
    setState(() => _zoomed = true);
    _setLocked(true);
  }

  void _releasePointer() {
    if (_pointerCount > 0) _pointerCount--;
    if (_pointerCount == 0 && !_zoomed) _setLocked(false);
  }

  void _setLocked(bool value) {
    if (_locked == value) return;
    _locked = value;
    widget.onGestureLockChanged?.call(value);
  }
}

class _RoundControlButton extends StatelessWidget {
  const _RoundControlButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    this.emphasized = false,
    this.selected = false,
    this.size = 36,
    this.iconSize = 20,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;
  final bool emphasized;
  final bool selected;
  final double size;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final background = emphasized
        ? scheme.primary
        : selected
            ? scheme.primaryContainer.withValues(alpha: 0.95)
            : Colors.black.withValues(alpha: 0.44);
    final foreground = emphasized
        ? scheme.onPrimary
        : selected
            ? scheme.onPrimaryContainer
            : Colors.white;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        child: InkResponse(
          containedInkWell: true,
          highlightShape: BoxShape.circle,
          onTap: onPressed,
          child: AnimatedContainer(
            duration: AppMotion.duration(context, 140),
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: background,
              shape: BoxShape.circle,
              border: Border.all(
                color: selected
                    ? scheme.primary.withValues(alpha: 0.4)
                    : Colors.white.withValues(alpha: 0.14),
              ),
              boxShadow: [
                if (emphasized)
                  BoxShadow(
                    color: scheme.primary.withValues(alpha: 0.45),
                    blurRadius: 28,
                    spreadRadius: 2,
                  ),
              ],
            ),
            child: Center(
              child: Icon(icon, color: foreground, size: iconSize),
            ),
          ),
        ),
      ),
    );
  }
}

class _SpeedBadgeButton extends StatelessWidget {
  const _SpeedBadgeButton({
    required this.currentRate,
    required this.onSelected,
  });

  final double currentRate;
  final ValueChanged<double> onSelected;

  @override
  Widget build(BuildContext context) {
    final isRu = Localizations.maybeLocaleOf(context)?.languageCode == 'ru';
    final scheme = Theme.of(context).colorScheme;
    return PopupMenuButton<double>(
      initialValue: currentRate,
      tooltip: isRu ? 'Скорость воспроизведения' : 'Playback speed',
      onSelected: onSelected,
      color: const Color(0xFF1E1E24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
      ),
      itemBuilder: (context) => [
        for (final rate in [0.5, 0.75, 1.0, 1.25, 1.5, 2.0])
          PopupMenuItem<double>(
            value: rate,
            child: Row(
              children: [
                if ((rate - currentRate).abs() < 0.05)
                  Icon(Icons.check_rounded, size: 18, color: scheme.primary)
                else
                  const SizedBox(width: 18),
                const SizedBox(width: 8),
                Text(
                  '${rate}x',
                  style: TextStyle(
                    color: (rate - currentRate).abs() < 0.05
                        ? scheme.primary
                        : Colors.white,
                    fontWeight: (rate - currentRate).abs() < 0.05
                        ? FontWeight.w900
                        : FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.44),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
        ),
        child: Text(
          '${currentRate}x',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.4,
          ),
        ),
      ),
    );
  }
}

class _SpeedBoostOverlayBadge extends StatelessWidget {
  const _SpeedBoostOverlayBadge();

  @override
  Widget build(BuildContext context) {
    final isRu = Localizations.maybeLocaleOf(context)?.languageCode == 'ru';
    return Positioned(
      top: 32,
      left: 0,
      right: 0,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.78),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.amberAccent.withValues(alpha: 0.7)),
            boxShadow: [
              BoxShadow(
                color: Colors.amberAccent.withValues(alpha: 0.28),
                blurRadius: 18,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.bolt_rounded, color: Colors.amberAccent, size: 18),
              const SizedBox(width: 6),
              Text(
                isRu ? '2X УСКОРЕНИЕ' : '2X SPEED',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 12,
                  letterSpacing: 1.1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VolumeGestureBadge extends StatelessWidget {
  const _VolumeGestureBadge({required this.volume});

  final double volume;

  @override
  Widget build(BuildContext context) {
    final isMuted = volume <= 0.01;
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
          boxShadow: const [
            BoxShadow(color: Colors.black54, blurRadius: 24),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isMuted
                  ? Icons.volume_off_rounded
                  : volume < 50
                      ? Icons.volume_down_rounded
                      : Icons.volume_up_rounded,
              color: Colors.white,
              size: 26,
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 96,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: (volume / 100.0).clamp(0.0, 1.0),
                  minHeight: 6,
                  backgroundColor: Colors.white24,
                  valueColor: const AlwaysStoppedAnimation(Colors.white),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              '${volume.round()}%',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BrightnessGestureBadge extends StatelessWidget {
  const _BrightnessGestureBadge({required this.brightness});

  final double brightness;

  @override
  Widget build(BuildContext context) {
    final pct = (brightness * 100).round().clamp(0, 100);
    final icon = pct < 33
        ? Icons.brightness_low_rounded
        : pct < 66
            ? Icons.brightness_medium_rounded
            : Icons.brightness_high_rounded;

    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
          boxShadow: const [
            BoxShadow(color: Colors.black54, blurRadius: 24),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: Colors.white,
              size: 26,
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 96,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: brightness.clamp(0.0, 1.0),
                  minHeight: 6,
                  backgroundColor: Colors.white24,
                  valueColor: const AlwaysStoppedAnimation(Colors.white),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              '$pct%',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DoubleTapSeekRipple extends StatelessWidget {
  const _DoubleTapSeekRipple({
    required this.isLeft,
    required this.visible,
  });

  final bool isLeft;
  final bool visible;

  @override
  Widget build(BuildContext context) {
    if (!visible) return const SizedBox.shrink();
    final isRu = Localizations.maybeLocaleOf(context)?.languageCode == 'ru';
    return Align(
      alignment: isLeft ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        width: 140,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: isLeft ? Alignment.centerLeft : Alignment.centerRight,
            end: isLeft ? Alignment.centerRight : Alignment.centerLeft,
            colors: [
              Colors.white.withValues(alpha: 0.22),
              Colors.transparent,
            ],
          ),
          borderRadius: BorderRadius.horizontal(
            right: isLeft ? const Radius.circular(90) : Radius.zero,
            left: !isLeft ? const Radius.circular(90) : Radius.zero,
          ),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isLeft ? Icons.fast_rewind_rounded : Icons.fast_forward_rounded,
                color: Colors.white,
                size: 40,
              ),
              const SizedBox(height: 4),
              Text(
                isRu
                    ? (isLeft ? '-10 сек' : '+10 сек')
                    : (isLeft ? '-10 sec' : '+10 sec'),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 13,
                  letterSpacing: 0.5,
                  shadows: [Shadow(color: Colors.black54, blurRadius: 8)],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VideoControls extends StatefulWidget {
  const _VideoControls({
    required this.player,
    required this.muted,
    required this.halfVolume,
    required this.loopVideo,
    required this.coverVideo,
    required this.fullscreen,
    this.topOffset = 0.0,
    this.inGallery = false,
    required this.isLocked,
    this.isLandscape,
    required this.isSoftwareDecoding,
    required this.onToggleDecoder,
    this.onToggleOrientation,
    required this.onToggleLock,
    required this.onToggleFit,
    required this.onToggleMute,
    required this.onToggleHalfVolume,
    required this.onToggleLoop,
    required this.onFullscreen,
    required this.onSeekBy,
    this.onInteract,
  });

  final Player player;
  final bool muted;
  final bool halfVolume;
  final bool loopVideo;
  final bool coverVideo;
  final bool fullscreen;
  final double topOffset;
  final bool inGallery;
  final bool isLocked;
  final bool? isLandscape;
  final bool isSoftwareDecoding;
  final VoidCallback onToggleDecoder;
  final VoidCallback? onToggleOrientation;
  final VoidCallback onToggleLock;
  final VoidCallback onToggleFit;
  final VoidCallback onToggleMute;
  final VoidCallback onToggleHalfVolume;
  final VoidCallback onToggleLoop;
  final VoidCallback onFullscreen;
  final void Function(Duration) onSeekBy;
  final VoidCallback? onInteract;

  @override
  State<_VideoControls> createState() => _VideoControlsState();
}

class _VideoControlsState extends State<_VideoControls> {
  double? _scrubValue;

  @override
  Widget build(BuildContext context) {
    final isRu = Localizations.maybeLocaleOf(context)?.languageCode == 'ru';
    final scheme = Theme.of(context).colorScheme;

    if (widget.isLocked) {
      return Align(
        alignment: Alignment.topLeft,
        child: SafeArea(
          top: widget.fullscreen && widget.topOffset == 0,
          child: Padding(
            padding: EdgeInsets.only(
              top: widget.topOffset > 0 ? widget.topOffset + 8 : 16,
              left: 16,
              right: 16,
              bottom: 16,
            ),
            child: _RoundControlButton(
              tooltip: isRu ? 'Разблокировать экран' : 'Unlock screen',
              icon: Icons.lock_rounded,
              size: 44,
              iconSize: 24,
              emphasized: true,
              onPressed: widget.onToggleLock,
            ),
          ),
        ),
      );
    }

    return StreamBuilder<double>(
      stream: widget.player.stream.rate,
      initialData: widget.player.state.rate,
      builder: (context, rateSnapshot) {
        final currentRate = rateSnapshot.data ?? 1.0;

        return Stack(
          fit: StackFit.expand,
          children: [
            // Top cinematic gradient with control actions
            Positioned(
              top: widget.topOffset,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  gradient: widget.topOffset > 0
                      ? null
                      : const LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.black87, Colors.transparent],
                        ),
                ),
                child: SafeArea(
                  top: widget.fullscreen && widget.topOffset == 0,
                  bottom: false,
                  left: widget.fullscreen,
                  right: widget.fullscreen,
                  child: Row(
                    children: [
                      if (widget.fullscreen && !widget.inGallery) ...[
                        _RoundControlButton(
                          tooltip: isRu ? 'Закрыть' : 'Close',
                          icon: Icons.arrow_back_rounded,
                          onPressed: widget.onFullscreen,
                        ),
                        const SizedBox(width: 8),
                      ],
                      if (widget.fullscreen &&
                          widget.onToggleOrientation != null &&
                          !widget.inGallery) ...[
                        _RoundControlButton(
                          tooltip: (widget.isLandscape ?? false)
                              ? (isRu ? 'Портретная ориентация' : 'Portrait orientation')
                              : (isRu ? 'Альбомная ориентация' : 'Landscape orientation'),
                          icon: (widget.isLandscape ?? false)
                              ? Icons.screen_lock_portrait_rounded
                              : Icons.screen_lock_landscape_rounded,
                          onPressed: () {
                            widget.onToggleOrientation?.call();
                            widget.onInteract?.call();
                          },
                        ),
                        const SizedBox(width: 8),
                      ],
                      _RoundControlButton(
                        tooltip: isRu ? 'Заблокировать экран' : 'Lock screen',
                        icon: Icons.lock_outline_rounded,
                        onPressed: widget.onToggleLock,
                      ),
                      const Spacer(),
                      _RoundControlButton(
                        tooltip: widget.isSoftwareDecoding
                            ? (isRu
                                ? 'Декодер: S/W (программный). Нажмите для переключения на H/W'
                                : 'Decoder: S/W (software). Tap to switch to H/W')
                            : (isRu
                                ? 'Декодер: H/W (аппаратный). Нажмите для переключения на S/W'
                                : 'Decoder: H/W (hardware). Tap to switch to S/W'),
                        selected: !widget.isSoftwareDecoding,
                        icon: widget.isSoftwareDecoding
                            ? Icons.memory_rounded
                            : Icons.speed_rounded,
                        onPressed: widget.onToggleDecoder,
                      ),
                      const SizedBox(width: 8),
                      _SpeedBadgeButton(
                        currentRate: currentRate,
                        onSelected: (newRate) => widget.player.setRate(newRate),
                      ),
                      const SizedBox(width: 8),
                      _RoundControlButton(
                        tooltip: widget.loopVideo
                            ? (isRu ? 'Выключить повтор' : 'Disable repeat')
                            : (isRu ? 'Повтор видео' : 'Repeat video'),
                        selected: widget.loopVideo,
                        icon: widget.loopVideo
                            ? Icons.repeat_one_on_rounded
                            : Icons.repeat_one_rounded,
                        onPressed: widget.onToggleLoop,
                      ),
                      const SizedBox(width: 8),
                      _RoundControlButton(
                        tooltip: widget.coverVideo
                            ? (isRu ? 'Вписать' : 'Fit')
                            : (isRu ? 'Заполнить' : 'Fill'),
                        selected: widget.coverVideo,
                        icon: widget.coverVideo
                            ? Icons.fit_screen_rounded
                            : Icons.crop_free_rounded,
                        onPressed: widget.onToggleFit,
                      ),
                      const SizedBox(width: 8),
                      _RoundControlButton(
                        tooltip: widget.muted
                            ? (isRu ? 'Включить звук' : 'Unmute')
                            : (isRu ? 'Выключить звук' : 'Mute'),
                        selected: !widget.muted,
                        icon: widget.muted
                            ? Icons.volume_off_rounded
                            : Icons.volume_up_rounded,
                        onPressed: widget.onToggleMute,
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Center play/pause with quick 10s buttons
            Center(
              child: StreamBuilder<bool>(
                stream: widget.player.stream.playing,
                initialData: widget.player.state.playing,
                builder: (context, playingSnapshot) {
                  final playing = playingSnapshot.data ?? false;
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _RoundControlButton(
                        tooltip: isRu ? 'Назад на 10с' : 'Back 10s',
                        icon: Icons.replay_10_rounded,
                        size: 46,
                        iconSize: 26,
                        onPressed: () {
                          widget.onSeekBy(const Duration(seconds: -10));
                          widget.onInteract?.call();
                        },
                      ),
                      const SizedBox(width: 32),
                      _RoundControlButton(
                        tooltip: playing
                            ? (isRu ? 'Пауза' : 'Pause')
                            : (isRu ? 'Воспроизведение' : 'Play'),
                        icon: playing
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                        size: 68,
                        iconSize: 42,
                        emphasized: true,
                        onPressed: () async {
                          try {
                            if (widget.player.state.playing) {
                              await widget.player.pause();
                            } else {
                              if (widget.player.state.completed) {
                                await widget.player.seek(Duration.zero);
                              }
                              await widget.player.play();
                            }
                          } catch (_) {
                            try {
                              await widget.player.playOrPause();
                            } catch (_) {}
                          }
                          widget.onInteract?.call();
                        },
                      ),
                      const SizedBox(width: 32),
                      _RoundControlButton(
                        tooltip: isRu ? 'Вперед на 10с' : 'Forward 10s',
                        icon: Icons.forward_10_rounded,
                        size: 46,
                        iconSize: 26,
                        onPressed: () {
                          widget.onSeekBy(const Duration(seconds: 10));
                          widget.onInteract?.call();
                        },
                      ),
                    ],
                  );
                },
              ),
            ),

            // Bottom cinematic gradient with Seekbar and time
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: EdgeInsets.fromLTRB(
                  14,
                  8,
                  14,
                  widget.fullscreen ? 10 : 4,
                ),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [Colors.black87, Colors.transparent],
                  ),
                ),
                child: SafeArea(
                  top: false,
                  bottom: widget.fullscreen,
                  left: widget.fullscreen,
                  right: widget.fullscreen,
                  child: StreamBuilder<Duration>(
                    stream: widget.player.stream.duration,
                    initialData: widget.player.state.duration,
                    builder: (context, durationSnapshot) {
                      final duration = durationSnapshot.data ?? Duration.zero;
                      return StreamBuilder<Duration>(
                        stream: widget.player.stream.position,
                        initialData: widget.player.state.position,
                        builder: (context, positionSnapshot) {
                          final position =
                              positionSnapshot.data ?? Duration.zero;
                          return StreamBuilder<Duration>(
                            stream: widget.player.stream.buffer,
                            initialData: widget.player.state.buffer,
                            builder: (context, bufferSnapshot) {
                              final buffer =
                                  bufferSnapshot.data ?? Duration.zero;
                              final maxMs = duration.inMilliseconds
                                  .clamp(1, 1 << 31)
                                  .toDouble();
                              final valueMs = position.inMilliseconds
                                  .clamp(0, maxMs.toInt())
                                  .toDouble();
                              final bufferMs = buffer.inMilliseconds
                                  .clamp(0, maxMs.toInt())
                                  .toDouble();
                              final displayMs =
                                  (_scrubValue ?? valueMs).clamp(0.0, maxMs);

                              return Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (_scrubValue != null)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 4,
                                      ),
                                      margin: const EdgeInsets.only(bottom: 6),
                                      decoration: BoxDecoration(
                                        color: Colors.black87,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: scheme.primary,
                                        ),
                                      ),
                                      child: Text(
                                        '${_format(Duration(milliseconds: displayMs.round()))} / ${_format(duration)}',
                                        style: TextStyle(
                                          color: scheme.primary,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                      Text(
                                        _format(Duration(
                                            milliseconds: displayMs.round())),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: 0.3,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      Expanded(
                                        child: Stack(
                                          alignment: Alignment.center,
                                          children: [
                                            // Buffer progress track
                                            if (maxMs > 0 && bufferMs > 0)
                                              Positioned(
                                                left: 14,
                                                right: 14,
                                                child: ClipRRect(
                                                  borderRadius:
                                                      BorderRadius.circular(2),
                                                  child:
                                                      LinearProgressIndicator(
                                                    value: (bufferMs / maxMs)
                                                        .clamp(0.0, 1.0),
                                                    minHeight: 3.5,
                                                    backgroundColor:
                                                        Colors.transparent,
                                                    valueColor:
                                                        AlwaysStoppedAnimation(
                                                      Colors.white.withValues(
                                                          alpha: 0.28),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            SliderTheme(
                                              data: SliderTheme.of(context)
                                                  .copyWith(
                                                activeTrackColor:
                                                    scheme.primary,
                                                inactiveTrackColor: Colors.white
                                                    .withValues(alpha: 0.2),
                                                trackHeight: 3.5,
                                                thumbColor: scheme.primary,
                                                overlayColor: scheme.primary
                                                    .withValues(alpha: 0.22),
                                                thumbShape:
                                                    const RoundSliderThumbShape(
                                                  enabledThumbRadius: 6,
                                                ),
                                                overlayShape:
                                                    const RoundSliderOverlayShape(
                                                  overlayRadius: 14,
                                                ),
                                              ),
                                              child: Slider(
                                                value: displayMs,
                                                max: maxMs,
                                                onChangeStart: (value) {
                                                  setState(() =>
                                                      _scrubValue = value);
                                                  widget.onInteract?.call();
                                                },
                                                onChanged: duration ==
                                                        Duration.zero
                                                    ? null
                                                    : (value) {
                                                        setState(() =>
                                                            _scrubValue =
                                                                value);
                                                        widget.onInteract
                                                            ?.call();
                                                      },
                                                onChangeEnd: (value) {
                                                  widget.player.seek(
                                                    Duration(
                                                      milliseconds:
                                                          value.round(),
                                                    ),
                                                  );
                                                  setState(
                                                      () => _scrubValue = null);
                                                  widget.onInteract?.call();
                                                },
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        _format(duration),
                                        style: TextStyle(
                                          color: Colors.white
                                              .withValues(alpha: 0.72),
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: 0.3,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      _RoundControlButton(
                                        tooltip: widget.fullscreen
                                            ? (isRu
                                                ? 'Выйти из полноэкранного режима'
                                                : 'Exit fullscreen')
                                            : (isRu
                                                ? 'Полноэкранный режим'
                                                : 'Fullscreen mode'),
                                        icon: widget.fullscreen
                                            ? Icons.fullscreen_exit_rounded
                                            : Icons.fullscreen_rounded,
                                        onPressed: widget.onFullscreen,
                                      ),
                                    ],
                                  ),
                                ],
                              );
                            },
                          );
                        },
                      );
                    },
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  String _format(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    final hours = duration.inHours;
    if (hours > 0) return '$hours:$minutes:$seconds';
    return '$minutes:$seconds';
  }
}

class _CloudMediaHero extends StatelessWidget {
  const _CloudMediaHero({
    required this.post,
    this.onOpenPrimary,
  });

  final Post post;
  final VoidCallback? onOpenPrimary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isRu = Localizations.maybeLocaleOf(context)?.languageCode == 'ru';
    final links = post.cloudLinks;
    final primaryColor = links.isNotEmpty
        ? links.first.brandColor
        : theme.colorScheme.primary;

    return Center(
      child: Container(
        margin: const EdgeInsets.all(24),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
        constraints: const BoxConstraints(maxWidth: 460),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: primaryColor.withValues(alpha: 0.35),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: primaryColor.withValues(alpha: 0.12),
              blurRadius: 28,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 68,
              height: 68,
              decoration: BoxDecoration(
                color: primaryColor.withValues(alpha: 0.15),
                shape: BoxShape.circle,
                border: Border.all(
                  color: primaryColor.withValues(alpha: 0.4),
                  width: 2,
                ),
              ),
              child: Icon(
                links.isNotEmpty ? links.first.iconData : Icons.cloud_queue_rounded,
                size: 34,
                color: primaryColor,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              isRu
                  ? 'Контент на внешнем диске'
                  : 'Cloud Drive Media',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              links.isNotEmpty
                  ? (isRu
                      ? 'Автор опубликовал медиа на ${links.map((l) => l.serviceName).toSet().join(', ')}.'
                      : 'Author hosted media on ${links.map((l) => l.serviceName).toSet().join(', ')}.')
                  : (isRu
                      ? 'В данном посте нет медиафайла на сервере.'
                      : 'No media file hosted directly on the server.'),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            if (links.isNotEmpty) ...[
              const SizedBox(height: 20),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 22,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                icon: const Icon(Icons.open_in_new_rounded, size: 16),
                label: Text(
                  isRu
                      ? 'Открыть ${links.first.serviceName}'
                      : 'Open ${links.first.serviceName}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                onPressed: onOpenPrimary,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TextArticleHero extends StatelessWidget {
  const _TextArticleHero({required this.post});

  final Post post;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isRu = Localizations.maybeLocaleOf(context)?.languageCode == 'ru';
    final title = (post.title ?? '').trim();
    final cleanContent =
        CloudLinkExtractor.cleanCommentary(post.description ?? '');
    final displayContent = cleanContent.isNotEmpty
        ? cleanContent
        : (title.isNotEmpty
            ? ''
            : (isRu
                ? 'Публикация автора без текста и вложений'
                : 'Author post without text or attachments'));
    final creatorLinks = CreatorLink.extractLinks(post.description ?? '');
    final cleanTags = post.cleanTags;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 680),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 20,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.article_rounded,
                      color: theme.colorScheme.primary,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isRu ? 'Текстовая публикация' : 'Text post',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: theme.colorScheme.primary,
                            letterSpacing: 0.5,
                          ),
                        ),
                        Text(
                          '${post.providerName} • ${post.createdAt.day.toString().padLeft(2, '0')}.${post.createdAt.month.toString().padLeft(2, '0')}.${post.createdAt.year}',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy_rounded, size: 18),
                    tooltip: isRu ? 'Скопировать текст' : 'Copy text',
                    onPressed: () {
                      final textToCopy = [
                        if (title.isNotEmpty) title,
                        if (displayContent.isNotEmpty) displayContent,
                      ].join('\n\n');
                      Clipboard.setData(ClipboardData(text: textToCopy));
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            isRu
                                ? 'Текст скопирован в буфер обмена'
                                : 'Text copied to clipboard',
                          ),
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    },
                  ),
                ],
              ),
              if (title.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  title,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.3,
                  ),
                ),
              ],
              const SizedBox(height: 14),
              Divider(
                height: 1,
                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.35),
              ),
              const SizedBox(height: 16),
              if (displayContent.isNotEmpty)
                FormattedContentText(
                  text: displayContent,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    height: 1.6,
                    letterSpacing: 0.15,
                  ),
                ),
              if (creatorLinks.isNotEmpty) ...[
                const SizedBox(height: 18),
                CreatorLinkChips(
                  links: creatorLinks,
                  title: isRu
                      ? 'Ссылки из публикации'
                      : 'Links from publication',
                ),
              ],
              if (cleanTags.isNotEmpty) ...[
                const SizedBox(height: 18),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: cleanTags.take(8).map((t) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3.5,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '#$t',
                        style: TextStyle(
                          fontSize: 11,
                          color: theme.colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

String _cleanNoteBody(String raw) {
  var text = raw;
  text = text
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'")
      .replaceAll('&apos;', "'")
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>');
  text = text.replaceAll(RegExp(r'\[/?[a-zA-Z0-9_=#]+\]'), '');
  text = text.replaceAll(RegExp(r'</?[a-zA-Z0-9_]+>'), '');
  return text.trim();
}

void _showNoteDialog(BuildContext context, PostNote note) {
  final cleaned = _cleanNoteBody(note.body);
  final isRu = Localizations.maybeLocaleOf(context)?.languageCode == 'ru';
  showDialog<void>(
    context: context,
    builder: (dialogContext) {
      final theme = Theme.of(dialogContext);
      return AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.translate_rounded, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                note.authorName != null && note.authorName!.isNotEmpty
                    ? '${isRu ? "Перевод" : "Translation"} (${note.authorName})'
                    : (isRu ? 'Перевод' : 'Translation'),
                style: const TextStyle(fontSize: 16),
              ),
            ),
          ],
        ),
        content: SelectableText(
          cleaned,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontSize: 15,
            height: 1.4,
          ),
        ),
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.copy_rounded, size: 16),
            label: Text(isRu ? 'Копировать' : 'Copy'),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: cleaned));
              Navigator.of(dialogContext).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    isRu
                        ? 'Текст перевода скопирован'
                        : 'Translation text copied',
                  ),
                  duration: const Duration(seconds: 2),
                ),
              );
            },
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(isRu ? 'Закрыть' : 'Close'),
          ),
        ],
      );
    },
  );
}

class _PostNotesOverlay extends StatelessWidget {
  const _PostNotesOverlay({
    required this.post,
    required this.notes,
  });

  final Post post;
  final List<PostNote> notes;

  @override
  Widget build(BuildContext context) {
    if (notes.isEmpty || post.width <= 0 || post.height <= 0) {
      return const SizedBox.shrink();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        if (!constraints.hasBoundedWidth || !constraints.hasBoundedHeight) {
          return const SizedBox.shrink();
        }
        final containerSize = Size(constraints.maxWidth, constraints.maxHeight);
        final imageSize = Size(post.width.toDouble(), post.height.toDouble());
        final fitted = applyBoxFit(BoxFit.contain, imageSize, containerSize);
        final renderedW = fitted.destination.width;
        final renderedH = fitted.destination.height;
        final dx = (containerSize.width - renderedW) / 2.0;
        final dy = (containerSize.height - renderedH) / 2.0;
        final scaleX = renderedW / post.width;
        final scaleY = renderedH / post.height;

        return Stack(
          children: [
            for (final note in notes)
              if (note.isActive)
                Positioned(
                  left: dx + (note.x * scaleX),
                  top: dy + (note.y * scaleY),
                  width: (note.width * scaleX).clamp(16.0, renderedW),
                  height: (note.height * scaleY).clamp(16.0, renderedH),
                  child: _NoteBox(note: note),
                ),
          ],
        );
      },
    );
  }
}

class _NoteBox extends StatelessWidget {
  const _NoteBox({required this.note});

  final PostNote note;

  @override
  Widget build(BuildContext context) {
    final cleaned = _cleanNoteBody(note.body);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _showNoteDialog(context, note),
      child: Tooltip(
        message: cleaned,
        child: Container(
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: (isDark ? Colors.grey.shade900 : Colors.grey.shade200)
                .withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(3),
            border: Border.all(
              color: isDark ? Colors.white54 : Colors.black45,
              width: 0.75,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.18),
                blurRadius: 2,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Center(
            child: SingleChildScrollView(
              physics: const NeverScrollableScrollPhysics(),
              child: Text(
                cleaned,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black87,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  height: 1.15,
                ),
                softWrap: true,
                overflow: TextOverflow.ellipsis,
                maxLines: 8,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

