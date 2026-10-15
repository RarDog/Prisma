import 'package:dio/dio.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'media_viewer_shortcuts.dart';

class DioImageFallback extends StatefulWidget {
  const DioImageFallback({
    super.key,
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
  State<DioImageFallback> createState() => DioImageFallbackState();
}

class DioImageFallbackState extends State<DioImageFallback> {
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
          return const ImageLoadError();
        }
        return Image.memory(
          bytes,
          fit: widget.fit,
          gaplessPlayback: true,
          errorBuilder: (context, error, stackTrace) {
            _reportFailure();
            return const ImageLoadError();
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

class ImageLoadError extends StatelessWidget {
  const ImageLoadError({super.key});

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

class ZoomableImage extends StatefulWidget {
  const ZoomableImage({
    required this.child,
    this.onGestureLockChanged,
    this.onTap,
    super.key,
  });

  final Widget child;
  final ValueChanged<bool>? onGestureLockChanged;
  final VoidCallback? onTap;

  @override
  State<ZoomableImage> createState() => ZoomableImageState();
}

class ZoomableImageState extends State<ZoomableImage> {
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
    _controller.value = Matrix4.identity()
      ..scaleByDouble(newScale, newScale, 1, 1);
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
      _controller.value = Matrix4.identity()
        ..scaleByDouble(newScale, newScale, 1, 1);
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
        LogicalKeySet(LogicalKeyboardKey.equal): const ZoomInIntent(),
        LogicalKeySet(LogicalKeyboardKey.add): const ZoomInIntent(),
        LogicalKeySet(LogicalKeyboardKey.numpadAdd): const ZoomInIntent(),
        LogicalKeySet(LogicalKeyboardKey.minus): const ZoomOutIntent(),
        LogicalKeySet(LogicalKeyboardKey.numpadSubtract): const ZoomOutIntent(),
        LogicalKeySet(LogicalKeyboardKey.digit0): const ResetZoomIntent(),
        LogicalKeySet(LogicalKeyboardKey.numpad0): const ResetZoomIntent(),
        LogicalKeySet(LogicalKeyboardKey.escape): const ResetZoomIntent(),
      },
      child: Actions(
        actions: {
          ZoomInIntent: CallbackAction<ZoomInIntent>(
            onInvoke: (_) {
              _zoomIn();
              return null;
            },
          ),
          ZoomOutIntent: CallbackAction<ZoomOutIntent>(
            onInvoke: (_) {
              _zoomOut();
              return null;
            },
          ),
          ResetZoomIntent: CallbackAction<ResetZoomIntent>(
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
                            if (scrollable != null &&
                                scrollable.position.hasPixels) {
                              final pos = scrollable.position;
                              final target = (pos.pixels + event.scrollDelta.dy)
                                  .clamp(
                                      pos.minScrollExtent, pos.maxScrollExtent);
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
