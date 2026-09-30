import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Interactive 3D page flip widget that gives a realistic book page turn effect.
/// Uses Matrix4 perspective transformations with dynamic lighting and shadows.
class PageFlip3D extends StatefulWidget {
  const PageFlip3D({
    required this.itemCount,
    required this.itemBuilder,
    this.initialIndex = 0,
    this.onPageChanged,
    this.onEndReached,
    this.onStartReached,
    this.isRtl = false,
    super.key,
  });

  final int itemCount;
  final Widget Function(BuildContext context, int index) itemBuilder;
  final int initialIndex;
  final ValueChanged<int>? onPageChanged;
  final VoidCallback? onEndReached;
  final VoidCallback? onStartReached;
  final bool isRtl;

  @override
  State<PageFlip3D> createState() => PageFlip3DState();
}

class PageFlip3DState extends State<PageFlip3D> with SingleTickerProviderStateMixin {
  late int _currentIndex;
  late AnimationController _controller;
  double _dragOffset = 0.0;
  bool _isDragging = false;
  int _targetIndex = 0;

  int get currentIndex => _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex.clamp(0, math.max(0, widget.itemCount - 1));
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    )..addListener(() {
        setState(() {});
      })..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          setState(() {
            _currentIndex = _targetIndex;
            _dragOffset = 0.0;
            _isDragging = false;
          });
          widget.onPageChanged?.call(_currentIndex);
        } else if (status == AnimationStatus.dismissed) {
          setState(() {
            _dragOffset = 0.0;
            _isDragging = false;
          });
        }
      });
  }

  @override
  void didUpdateWidget(covariant PageFlip3D oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.itemCount != oldWidget.itemCount) {
      if (_currentIndex >= widget.itemCount) {
        _currentIndex = math.max(0, widget.itemCount - 1);
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void nextPage() {
    if (_controller.isAnimating) return;
    if (_currentIndex + 1 >= widget.itemCount) {
      widget.onEndReached?.call();
      return;
    }
    _turnTo(_currentIndex + 1);
  }

  void previousPage() {
    if (_controller.isAnimating) return;
    if (_currentIndex - 1 < 0) {
      widget.onStartReached?.call();
      return;
    }
    _turnTo(_currentIndex - 1);
  }

  void jumpToPage(int index) {
    if (index == _currentIndex || index < 0 || index >= widget.itemCount) return;
    setState(() {
      _currentIndex = index;
      _dragOffset = 0.0;
    });
    widget.onPageChanged?.call(_currentIndex);
  }

  void _turnTo(int target) {
    if (target < 0 || target >= widget.itemCount) return;
    _targetIndex = target;
    _isDragging = false;
    _dragOffset = target > _currentIndex
        ? (widget.isRtl ? 1.0 : -1.0)
        : (widget.isRtl ? -1.0 : 1.0);
    _controller.forward(from: 0.0);
  }

  void _onHorizontalDragStart(DragStartDetails details) {
    if (_controller.isAnimating) return;
    _isDragging = true;
    _dragOffset = 0.0;
  }

  void _onHorizontalDragUpdate(DragUpdateDetails details, double width) {
    if (!_isDragging || _controller.isAnimating) return;
    setState(() {
      _dragOffset += details.primaryDelta! / width;
      _dragOffset = _dragOffset.clamp(-1.0, 1.0);
    });
  }

  void _onHorizontalDragEnd(DragEndDetails details, double width) {
    if (!_isDragging || _controller.isAnimating) return;

    final velocity = details.primaryVelocity ?? 0.0;
    final bool shouldFlip = _dragOffset.abs() > 0.18 || velocity.abs() > 300;

    if (shouldFlip) {
      final bool movingForward = widget.isRtl ? _dragOffset > 0 : _dragOffset < 0;
      final int step = movingForward ? 1 : -1;
      final candidate = _currentIndex + step;

      if (candidate >= 0 && candidate < widget.itemCount) {
        _targetIndex = candidate;
        final startProgress = _dragOffset.abs();
        _controller.forward(from: startProgress);
        return;
      } else if (candidate >= widget.itemCount && movingForward) {
        widget.onEndReached?.call();
      } else if (candidate < 0 && !movingForward) {
        widget.onStartReached?.call();
      }
    }

    // Cancel flip
    _targetIndex = _currentIndex;
    _controller.reverse(from: _dragOffset.abs());
  }

  @override
  Widget build(BuildContext context) {
    if (widget.itemCount <= 0) {
      return const SizedBox.shrink();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;

        double progress;
        int nextIndex;
        bool isForward;

        if (_controller.isAnimating) {
          progress = _controller.value;
          isForward = _targetIndex > _currentIndex;
          nextIndex = _targetIndex;
        } else if (_isDragging) {
          progress = _dragOffset.abs();
          isForward = widget.isRtl ? _dragOffset > 0 : _dragOffset < 0;
          nextIndex = isForward ? _currentIndex + 1 : _currentIndex - 1;
        } else {
          progress = 0.0;
          isForward = true;
          nextIndex = _currentIndex;
        }

        final bool hasNext = nextIndex >= 0 && nextIndex < widget.itemCount && nextIndex != _currentIndex;

        // Angle in radians: from 0 to pi/2 (90 deg)
        final angle = progress * (math.pi / 2);

        return GestureDetector(
          onHorizontalDragStart: _onHorizontalDragStart,
          onHorizontalDragUpdate: (details) => _onHorizontalDragUpdate(details, width),
          onHorizontalDragEnd: (details) => _onHorizontalDragEnd(details, width),
          behavior: HitTestBehavior.opaque,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Bottom page (the one being revealed)
              if (hasNext && progress > 0)
                Positioned.fill(
                  child: widget.itemBuilder(context, nextIndex),
                ),

              // Top page (the one being flipped away)
              Positioned.fill(
                child: Transform(
                  alignment: isForward ? Alignment.centerLeft : Alignment.centerRight,
                  transform: Matrix4.identity()
                    ..setEntry(3, 2, 0.0012) // Perspective depth
                    ..rotateY(isForward ? -angle : angle),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      widget.itemBuilder(context, _currentIndex),
                      // 3D Shadow layer
                      if (progress > 0)
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: isForward ? Alignment.centerRight : Alignment.centerLeft,
                              end: isForward ? Alignment.centerLeft : Alignment.centerRight,
                              colors: [
                                Colors.black.withValues(alpha: (progress * 0.55).clamp(0.0, 0.55)),
                                Colors.transparent,
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
