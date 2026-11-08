import 'dart:async';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import 'package:gel_rule_app/core/models/cloud_media_link.dart';
import 'package:gel_rule_app/core/models/post.dart';
import 'package:gel_rule_app/core/utils/media_quality.dart';
import '../post_media_viewer.dart';
import 'fullscreen_media_helpers.dart';

class FullscreenVideoItem extends StatefulWidget {
  const FullscreenVideoItem({
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
  State<FullscreenVideoItem> createState() => _FullscreenVideoItemState();
}

class _FullscreenVideoItemState extends State<FullscreenVideoItem> {
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
  void didUpdateWidget(FullscreenVideoItem oldWidget) {
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
      rememberPlayback(
        widget.post.cacheKey,
        VideoPlaybackSnapshot(
          position: pos,
          playing: p.state.playing,
          muted: _muted,
          halfVolume: _halfVolume,
          loopVideo: _loopVideo,
          coverVideo: _coverVideo,
          volume: _volume,
        ),
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
    final hasImages = FullscreenMediaHelpers.urlsForPost(
      widget.post,
      MediaQualityMode.auto,
    ).isNotEmpty;
    final cloudStreams = (!hasImages || MediaUrlSelector.isVideo(widget.post))
        ? widget.post.cloudLinks
            .where((l) =>
                (l.service == CloudServiceType.genericVideo ||
                    FullscreenMediaHelpers.isDirectVideoUrl(l.url) ||
                    FullscreenMediaHelpers.isDirectVideoUrl(l.title)) &&
                l.directStreamUrl != null)
            .map((l) => l.directStreamUrl!)
        : const Iterable<String>.empty();
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
      rememberPlayback(
        widget.post.cacheKey,
        VideoPlaybackSnapshot(
          position: pos,
          playing: isPlaying,
          muted: _muted,
          halfVolume: _halfVolume,
          loopVideo: _loopVideo,
          coverVideo: _coverVideo,
          volume: _volume,
        ),
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
