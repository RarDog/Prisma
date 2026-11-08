import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'package:gel_rule_app/core/models/post.dart';
import 'package:gel_rule_app/core/models/post_note.dart';
import 'package:gel_rule_app/core/utils/media_quality.dart';
import '../post_notes_overlay.dart';
import '../zoomable_image.dart';

class InteractiveFullscreenImageItem extends StatefulWidget {
  const InteractiveFullscreenImageItem({
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
  State<InteractiveFullscreenImageItem> createState() =>
      _InteractiveFullscreenImageItemState();
}

class _InteractiveFullscreenImageItemState
    extends State<InteractiveFullscreenImageItem> {
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
    final mq = MediaQuery.maybeOf(context);
    final dpr = mq?.devicePixelRatio ?? 1.5;
    final screenWidth = mq?.size.width ?? 1080;
    final maxCacheWidth = (screenWidth * dpr * 2.0).round().clamp(1440, 4096);
    final Widget imageWidget;
    if (isLocal) {
      final cleanPath = currentUrl.startsWith('file://')
          ? currentUrl.replaceFirst('file://', '')
          : currentUrl;
      imageWidget = Image.file(
        File(cleanPath),
        fit: BoxFit.contain,
        // Match the network path's decode cap (4096) instead of decoding the
        // saved original at full resolution.
        cacheWidth: maxCacheWidth,
        errorBuilder: (_, __, ___) => const Center(
          child:
              Icon(Icons.broken_image_rounded, size: 64, color: Colors.white54),
        ),
      );
    } else {
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
