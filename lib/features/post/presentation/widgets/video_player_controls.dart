import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';

import 'package:gel_rule_app/app/motion.dart';

class RoundControlButton extends StatelessWidget {
  const RoundControlButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    this.emphasized = false,
    this.selected = false,
    this.size = 36,
    this.iconSize = 20,
    super.key,
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

class SpeedBadgeButton extends StatelessWidget {
  const SpeedBadgeButton({
    required this.currentRate,
    required this.onSelected,
    super.key,
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

class VideoControls extends StatefulWidget {
  const VideoControls({
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
    super.key,
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
  State<VideoControls> createState() => _VideoControlsState();
}

class _VideoControlsState extends State<VideoControls> {
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
            child: RoundControlButton(
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
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
                        RoundControlButton(
                          tooltip: isRu ? 'Закрыть' : 'Close',
                          icon: Icons.arrow_back_rounded,
                          onPressed: widget.onFullscreen,
                        ),
                        const SizedBox(width: 8),
                      ],
                      if (widget.fullscreen &&
                          widget.onToggleOrientation != null &&
                          !widget.inGallery) ...[
                        RoundControlButton(
                          tooltip: (widget.isLandscape ?? false)
                              ? (isRu
                                  ? 'Портретная ориентация'
                                  : 'Portrait orientation')
                              : (isRu
                                  ? 'Альбомная ориентация'
                                  : 'Landscape orientation'),
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
                      RoundControlButton(
                        tooltip: isRu ? 'Заблокировать экран' : 'Lock screen',
                        icon: Icons.lock_outline_rounded,
                        onPressed: widget.onToggleLock,
                      ),
                      const Spacer(),
                      RoundControlButton(
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
                      SpeedBadgeButton(
                        currentRate: currentRate,
                        onSelected: (newRate) => widget.player.setRate(newRate),
                      ),
                      const SizedBox(width: 8),
                      RoundControlButton(
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
                      RoundControlButton(
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
                      RoundControlButton(
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
                      RoundControlButton(
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
                      RoundControlButton(
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
                      RoundControlButton(
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
                                                onChanged:
                                                    duration == Duration.zero
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
                                      RoundControlButton(
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
