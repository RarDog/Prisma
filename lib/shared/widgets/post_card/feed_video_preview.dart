import 'dart:async';
import 'dart:collection';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import 'package:gel_rule_app/app/motion.dart';
import '../loading_skeleton.dart';

class FeedVideoPreview extends StatefulWidget {
  const FeedVideoPreview({
    super.key,
    required this.videoUrl,
    required this.headers,
    required this.fallbackImageUrl,
    required this.cacheWidth,
  });

  final String videoUrl;
  final Map<String, String> headers;
  final String fallbackImageUrl;
  final int cacheWidth;

  @override
  State<FeedVideoPreview> createState() => _FeedVideoPreviewState();
}

class _FeedVideoPreviewState extends State<FeedVideoPreview> {
  Player? _player;
  VideoController? _controller;
  StreamSubscription<String>? _errorSubscription;
  bool _failed = false;
  bool _ready = false;
  int _requestId = 0;

  @override
  void initState() {
    super.initState();
    _open();
  }

  @override
  void didUpdateWidget(covariant FeedVideoPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.videoUrl != widget.videoUrl) {
      _open();
    }
  }

  @override
  void dispose() {
    _errorSubscription?.cancel();
    _player?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fallback = CachedNetworkImage(
      imageUrl: widget.fallbackImageUrl,
      httpHeaders: widget.headers,
      memCacheWidth: widget.cacheWidth,
      maxWidthDiskCache: widget.cacheWidth,
      fit: BoxFit.cover,
      placeholder: (context, url) => const LoadingSkeleton(),
      errorWidget: (context, url, error) => ColoredBox(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: const Center(child: Icon(Icons.videocam_off_rounded)),
      ),
    );
    final controller = _controller;
    if (_failed || controller == null) return fallback;
    return Stack(
      fit: StackFit.expand,
      children: [
        fallback,
        AnimatedOpacity(
          opacity: _ready ? 1 : 0,
          duration: AppMotion.duration(context, 180),
          child: ColoredBox(
            color: Colors.black,
            child: Video(
              controller: controller,
              fit: BoxFit.cover,
              controls: null,
              pauseUponEnteringBackgroundMode: false,
              resumeUponEnteringForegroundMode: false,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _open() async {
    final requestId = ++_requestId;
    if (mounted) {
      setState(() {
        _failed = false;
        _ready = false;
      });
    }
    try {
      await VideoPreviewOpenQueue.run(() async {
        if (!mounted || requestId != _requestId) return;
        MediaKit.ensureInitialized();
        var player = _player;
        if (player == null) {
          player = Player(
            configuration: const PlayerConfiguration(
              bufferSize: 16 * 1024 * 1024,
            ),
          );
          _player = player;
          final isDesktop =
              Platform.isLinux || Platform.isWindows || Platform.isMacOS;
          _controller = VideoController(
            player,
            configuration: VideoControllerConfiguration(
              enableHardwareAcceleration: !isDesktop,
              hwdec: isDesktop ? 'no' : 'auto-safe',
            ),
          );
          _errorSubscription = player.stream.error.listen((_) {
            unawaited(player?.pause());
            unawaited(player?.stop());
            if (mounted) setState(() => _failed = true);
          });
        }
        await player.stop();
        await player.setVolume(0);
        await player.setPlaylistMode(PlaylistMode.loop);
        await player
            .open(
              Media(widget.videoUrl, httpHeaders: widget.headers),
              play: true,
            )
            .timeout(const Duration(seconds: 15));
      });
      if (!mounted || requestId != _requestId) return;
      setState(() => _ready = true);
    } catch (_) {
      if (mounted && requestId == _requestId) {
        setState(() => _failed = true);
      }
    }
  }
}

class VideoPreviewOpenQueue {
  static const int _maxConcurrent = 2;
  static final Queue<Future<void> Function()> _pending = Queue();
  static int _active = 0;

  static Future<void> run(Future<void> Function() task) {
    final completer = Completer<void>();
    _pending.add(() async {
      try {
        await task();
        if (!completer.isCompleted) completer.complete();
      } catch (error, stackTrace) {
        if (!completer.isCompleted) {
          completer.completeError(error, stackTrace);
        }
      }
    });
    _pump();
    return completer.future;
  }

  static void _pump() {
    while (_active < _maxConcurrent && _pending.isNotEmpty) {
      final job = _pending.removeFirst();
      _active++;
      unawaited(
        job().whenComplete(() {
          _active--;
          _pump();
        }),
      );
    }
  }
}


