import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import 'package:gel_rule_app/app/motion.dart';
import 'media_viewer_shortcuts.dart';
import 'video_player_controls.dart';

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
    final isRu = Localizations.maybeLocaleOf(context)?.languageCode == 'ru';
    return ColoredBox(
      color: Colors.black,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: Colors.redAccent.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.redAccent.withValues(alpha: 0.35),
                  ),
                ),
                child: const Icon(
                  Icons.error_outline_rounded,
                  color: Colors.redAccent,
                  size: 36,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                isRu ? 'Ошибка воспроизведения' : 'Playback error',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12.5,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: Text(
                  isRu ? 'Повторить' : 'Retry',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SpeedBoostOverlayBadge extends StatelessWidget {
  const SpeedBoostOverlayBadge({super.key});

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
            border:
                Border.all(color: Colors.amberAccent.withValues(alpha: 0.7)),
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
              const Icon(Icons.bolt_rounded,
                  color: Colors.amberAccent, size: 18),
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

class VolumeGestureBadge extends StatelessWidget {
  const VolumeGestureBadge({required this.volume, super.key});

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

class BrightnessGestureBadge extends StatelessWidget {
  const BrightnessGestureBadge({required this.brightness, super.key});

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

class DoubleTapSeekRipple extends StatelessWidget {
  const DoubleTapSeekRipple({
    required this.isLeft,
    required this.visible,
    super.key,
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

class VideoSurface extends StatefulWidget {
  const VideoSurface({
    super.key,
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
  State<VideoSurface> createState() => VideoSurfaceState();
}

class VideoSurfaceState extends State<VideoSurface> {
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
  void didUpdateWidget(covariant VideoSurface oldWidget) {
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
            DoubleTapSeekRipple(isLeft: true, visible: _showLeftSeek),
            DoubleTapSeekRipple(isLeft: false, visible: _showRightSeek),
            if (_showVolumeIndicator)
              VolumeGestureBadge(volume: _currentVolume),
            if (_showBrightnessIndicator)
              BrightnessGestureBadge(brightness: _currentBrightness),
            if (_isSpeedBoosted) const SpeedBoostOverlayBadge(),
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
                child: VideoControls(
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
        LogicalKeySet(LogicalKeyboardKey.space): const TogglePlayIntent(),
        LogicalKeySet(LogicalKeyboardKey.keyK): const TogglePlayIntent(),
        LogicalKeySet(LogicalKeyboardKey.arrowLeft): const SeekVideoIntent(-5),
        LogicalKeySet(LogicalKeyboardKey.keyJ): const SeekVideoIntent(-5),
        LogicalKeySet(LogicalKeyboardKey.arrowRight): const SeekVideoIntent(5),
        LogicalKeySet(LogicalKeyboardKey.keyL): const SeekVideoIntent(5),
        LogicalKeySet(LogicalKeyboardKey.shift, LogicalKeyboardKey.arrowLeft):
            const SeekVideoIntent(-15),
        LogicalKeySet(LogicalKeyboardKey.shift, LogicalKeyboardKey.arrowRight):
            const SeekVideoIntent(15),
        LogicalKeySet(LogicalKeyboardKey.arrowUp): const VolumeVideoIntent(-10),
        LogicalKeySet(LogicalKeyboardKey.arrowDown):
            const VolumeVideoIntent(10),
        LogicalKeySet(LogicalKeyboardKey.keyM): const MuteVideoIntent(),
        LogicalKeySet(LogicalKeyboardKey.keyF): const FullscreenVideoIntent(),
        LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyL):
            const LoopVideoIntent(),
      },
      child: Actions(
        actions: {
          TogglePlayIntent: CallbackAction<TogglePlayIntent>(
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
          SeekVideoIntent: CallbackAction<SeekVideoIntent>(
            onInvoke: (intent) {
              _seekBy(Duration(seconds: intent.seconds));
              return null;
            },
          ),
          VolumeVideoIntent: CallbackAction<VolumeVideoIntent>(
            onInvoke: (intent) {
              _adjustVolume(intent.deltaY);
              return null;
            },
          ),
          MuteVideoIntent: CallbackAction<MuteVideoIntent>(
            onInvoke: (_) {
              widget.onToggleMute();
              return null;
            },
          ),
          FullscreenVideoIntent: CallbackAction<FullscreenVideoIntent>(
            onInvoke: (_) {
              widget.onFullscreen();
              return null;
            },
          ),
          LoopVideoIntent: CallbackAction<LoopVideoIntent>(
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
                        aspectRatio: widget.aspectRatio.clamp(0.2, 5.0),
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
