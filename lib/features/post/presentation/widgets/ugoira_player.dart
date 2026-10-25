import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gel_rule_app/backend/di/backend_providers.dart';
import 'package:gel_rule_app/core/models/post.dart';
import 'package:gel_rule_app/features/post/services/ugoira_service.dart';
import 'package:gel_rule_app/sources/artist/pixiv_provider.dart';
import 'package:gel_rule_app/sources/models/ugoira_metadata.dart';

final ugoiraServiceProvider = Provider<UgoiraService>((ref) {
  return UgoiraService();
});

class UgoiraPlayer extends ConsumerStatefulWidget {
  const UgoiraPlayer({
    super.key,
    required this.post,
    this.mediaHeaders,
    this.fullscreen = false,
    this.onOpenFullscreen,
    this.onTap,
    this.ugoiraMetadata,
    this.ugoiraService,
  });

  final Post post;
  final Map<String, String>? mediaHeaders;
  final bool fullscreen;
  final VoidCallback? onOpenFullscreen;
  final VoidCallback? onTap;
  final UgoiraMetadata? ugoiraMetadata;
  final UgoiraService? ugoiraService;

  @override
  ConsumerState<UgoiraPlayer> createState() => _UgoiraPlayerState();
}

class _UgoiraPlayerState extends ConsumerState<UgoiraPlayer> {
  List<UgoiraFrame> _frames = const [];
  int _currentFrameIndex = 0;
  bool _isPlaying = true;
  double _playbackSpeed = 1.0;
  double _downloadProgress = 0.0;
  bool _isLoading = true;
  String? _errorMessage;
  bool _controlsVisible = false;

  Timer? _frameTimer;
  Timer? _hideControlsTimer;
  CancelToken? _cancelToken;

  UgoiraService get _service =>
      widget.ugoiraService ?? ref.read(ugoiraServiceProvider);

  @override
  void initState() {
    super.initState();
    _loadUgoira();
  }

  @override
  void didUpdateWidget(covariant UgoiraPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.post.id != widget.post.id) {
      _cancelToken?.cancel();
      _frameTimer?.cancel();
      _hideControlsTimer?.cancel();
      _currentFrameIndex = 0;
      _isLoading = true;
      _errorMessage = null;
      _loadUgoira();
    }
  }

  @override
  void dispose() {
    _cancelToken?.cancel();
    _frameTimer?.cancel();
    _hideControlsTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadUgoira() async {
    final cleanId = widget.post.id.split('_p').first;

    // Instant return if already cached in memory
    final cachedFrames = _service.getCachedByPostId(cleanId);
    if (cachedFrames != null && cachedFrames.isNotEmpty) {
      if (mounted) {
        setState(() {
          _frames = cachedFrames;
          _isLoading = false;
          _errorMessage = null;
          _currentFrameIndex = 0;
          _isPlaying = true;
        });
        _scheduleNextFrame();
      }
      return;
    }

    _cancelToken = CancelToken();
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _downloadProgress = 0.0;
    });

    try {
      UgoiraMetadata? meta =
          widget.ugoiraMetadata ?? _service.getCachedMeta(cleanId);
      if (meta == null) {
        final provider = await ref
            .read(providerManagerProvider)
            .getProviderInstance(widget.post.providerId);
        if (provider is PixivProvider) {
          meta = await provider.getUgoiraMeta(cleanId);
        }
      }

      if (meta != null && meta.frames.isNotEmpty) {
        _service.cacheMeta(cleanId, meta);
      }

      if (meta == null || meta.frames.isEmpty) {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _errorMessage = 'Не удалось загрузить данные анимации Ugoira';
          });
        }
        return;
      }

      final frames = await _service.loadUgoiraFrames(
        meta,
        postId: cleanId,
        headers: widget.mediaHeaders,
        onProgress: (p) {
          if (mounted) setState(() => _downloadProgress = p);
        },
        cancelToken: _cancelToken,
      );

      if (mounted) {
        setState(() {
          _frames = frames;
          _isLoading = false;
          _currentFrameIndex = 0;
          _isPlaying = true;
        });
        _scheduleNextFrame();
      }
    } catch (e) {
      if (mounted && !(_cancelToken?.isCancelled ?? false)) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString();
        });
      }
    }
  }

  void _scheduleNextFrame() {
    _frameTimer?.cancel();
    if (!_isPlaying || _frames.isEmpty) return;

    final currentFrame = _frames[_currentFrameIndex];
    final delay = (currentFrame.delayMs / _playbackSpeed).round().clamp(10, 5000);

    _frameTimer = Timer(Duration(milliseconds: delay), () {
      if (mounted && _isPlaying) {
        setState(() {
          _currentFrameIndex = (_currentFrameIndex + 1) % _frames.length;
        });
        _scheduleNextFrame();
      }
    });
  }

  void _togglePlayPause() {
    setState(() {
      _isPlaying = !_isPlaying;
    });
    if (_isPlaying) {
      _scheduleNextFrame();
    } else {
      _frameTimer?.cancel();
    }
    _showControlsTemporarily();
  }

  void _stepFrame(int delta) {
    if (_frames.isEmpty) return;
    _frameTimer?.cancel();
    setState(() {
      _isPlaying = false;
      _currentFrameIndex = (_currentFrameIndex + delta + _frames.length) % _frames.length;
    });
    _showControlsTemporarily();
  }

  void _cycleSpeed() {
    const speeds = [0.5, 1.0, 1.5, 2.0];
    final nextIdx = (speeds.indexOf(_playbackSpeed) + 1) % speeds.length;
    setState(() {
      _playbackSpeed = speeds[nextIdx];
    });
    if (_isPlaying) {
      _scheduleNextFrame();
    }
    _showControlsTemporarily();
  }

  void _toggleControls() {
    if (widget.onTap != null) widget.onTap!();
    setState(() {
      _controlsVisible = !_controlsVisible;
    });
    if (_controlsVisible) {
      _showControlsTemporarily();
    } else {
      _hideControlsTimer?.cancel();
    }
  }

  void _showControlsTemporarily() {
    _hideControlsTimer?.cancel();
    _hideControlsTimer = Timer(const Duration(seconds: 4), () {
      if (mounted && _isPlaying) {
        setState(() => _controlsVisible = false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final hasFrames = _frames.isNotEmpty && _frames[_currentFrameIndex].bytes != null;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _toggleControls,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Frame or Placeholder view
          Center(
            child: InteractiveViewer(
              minScale: 1.0,
              maxScale: 4.0,
              child: hasFrames
                  ? Image.memory(
                      _frames[_currentFrameIndex].bytes!,
                      gaplessPlayback: true,
                      fit: BoxFit.contain,
                    )
                  : CachedNetworkImage(
                      imageUrl: widget.post.sampleUrl.isNotEmpty
                          ? widget.post.sampleUrl
                          : widget.post.previewUrl,
                      httpHeaders: widget.mediaHeaders,
                      fit: BoxFit.contain,
                    ),
            ),
          ),

          // 2. Loading / Download Progress Indicator
          if (_isLoading)
            Positioned(
              left: 20,
              right: 20,
              bottom: 24,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.75),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white24),
                ),
                child: Row(
                  children: [
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.purpleAccent),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _downloadProgress > 0
                                ? 'Загрузка Ugoira: ${(_downloadProgress * 100).toInt()}%'
                                : 'Подготовка анимации Ugoira...',
                            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 6),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: _downloadProgress > 0 ? _downloadProgress : null,
                              backgroundColor: Colors.white24,
                              valueColor: const AlwaysStoppedAnimation(Colors.purpleAccent),
                              minHeight: 4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // 3. Error Overlay
          if (_errorMessage != null && !_isLoading)
            Center(
              child: Container(
                margin: const EdgeInsets.all(24),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.redAccent.withValues(alpha: 0.5)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 36),
                    const SizedBox(height: 8),
                    Text(
                      _errorMessage!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: _loadUgoira,
                      icon: const Icon(Icons.refresh_rounded, size: 18),
                      label: const Text('Повторить'),
                    ),
                  ],
                ),
              ),
            ),

          // 4. Floating Playback Controls Overlay
          if (hasFrames)
            Positioned(
              left: 12,
              right: 12,
              bottom: 12,
              child: AnimatedOpacity(
                opacity: _controlsVisible ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 200),
                child: IgnorePointer(
                  ignoring: !_controlsVisible,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.82),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Scrubber Slider
                        Row(
                          children: [
                            Text(
                              '${_currentFrameIndex + 1}',
                              style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                            Expanded(
                              child: SliderTheme(
                                data: SliderTheme.of(context).copyWith(
                                  trackHeight: 3,
                                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                                  overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                                  activeTrackColor: Colors.purpleAccent,
                                  inactiveTrackColor: Colors.white24,
                                  thumbColor: Colors.white,
                                ),
                                child: Slider(
                                  value: _currentFrameIndex.toDouble(),
                                  min: 0,
                                  max: (_frames.length - 1).toDouble(),
                                  onChanged: (val) {
                                    _frameTimer?.cancel();
                                    setState(() {
                                      _isPlaying = false;
                                      _currentFrameIndex = val.round();
                                    });
                                    _showControlsTemporarily();
                                  },
                                ),
                              ),
                            ),
                            Text(
                              '/ ${_frames.length}',
                              style: const TextStyle(color: Colors.white70, fontSize: 11),
                            ),
                          ],
                        ),

                        // Control Buttons Bar
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // Play / Pause & Frame Steppers
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.chevron_left_rounded, color: Colors.white, size: 24),
                                  tooltip: 'Предыдущий кадр',
                                  onPressed: () => _stepFrame(-1),
                                ),
                                IconButton(
                                  icon: Icon(
                                    _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                                    color: Colors.white,
                                    size: 28,
                                  ),
                                  tooltip: _isPlaying ? 'Пауза' : 'Воспроизведение',
                                  onPressed: _togglePlayPause,
                                ),
                                IconButton(
                                  icon: const Icon(Icons.chevron_right_rounded, color: Colors.white, size: 24),
                                  tooltip: 'Следующий кадр',
                                  onPressed: () => _stepFrame(1),
                                ),
                              ],
                            ),

                            // Speed & Fullscreen buttons
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                TextButton(
                                  onPressed: _cycleSpeed,
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    minimumSize: Size.zero,
                                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    backgroundColor: Colors.white12,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                  child: Text(
                                    '${_playbackSpeed}x',
                                    style: const TextStyle(color: Colors.purpleAccent, fontSize: 12, fontWeight: FontWeight.bold),
                                  ),
                                ),
                                if (!widget.fullscreen && widget.onOpenFullscreen != null) ...[
                                  const SizedBox(width: 8),
                                  IconButton(
                                    icon: const Icon(Icons.fullscreen_rounded, color: Colors.white, size: 24),
                                    tooltip: 'Полноэкранный режим',
                                    onPressed: widget.onOpenFullscreen,
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
