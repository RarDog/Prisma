import 'dart:async';
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:cached_network_image/cached_network_image.dart';

import 'package:prisma_app/backend/backend.dart';

class AudioSurface extends StatefulWidget {
  const AudioSurface({
    super.key,
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
  State<AudioSurface> createState() => AudioSurfaceState();
}

class AudioSurfaceState extends State<AudioSurface>
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
    final artistName = widget.post.tagGroups['artist']?.firstOrNull ??
        widget.post.providerName;
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
            border: Border.all(
                color: theme.colorScheme.error.withValues(alpha: 0.4)),
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
    final currentMs =
        (_isDragging ? _dragValue : _position.inMilliseconds.toDouble())
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
                        color:
                            theme.colorScheme.primary.withValues(alpha: 0.35),
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
                  widget.loopAudio
                      ? Icons.repeat_one_rounded
                      : Icons.repeat_rounded,
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
                  widget.muted
                      ? Icons.volume_off_rounded
                      : Icons.volume_up_rounded,
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
