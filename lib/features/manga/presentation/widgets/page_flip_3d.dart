import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Interactive realistic 3D book/manga page curl & flip widget.
///
/// Simulates physical paper deformation with:
/// - Outward 3D perspective projection (arches toward reader in foreground, not into screen)
/// - Flexible sheet curvature along top and bottom edges (изгиб листа бумаги)
/// - Authentic cylinder lighting: specular reflection highlight along the curve apex and crease shadow
/// - Dynamic cast drop shadow on the revealed page underneath
/// - Full fidelity rendering of manga artwork without white rectangles or obscuring masks
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

class PageFlip3DState extends State<PageFlip3D>
    with SingleTickerProviderStateMixin {
  late int _currentIndex;
  late AnimationController _controller;
  double _dragOffset = 0.0;
  bool _isDragging = false;
  int _targetIndex = 0;
  bool _isForward = true;

  int get currentIndex => _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex =
        widget.initialIndex.clamp(0, math.max(0, widget.itemCount - 1));
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
      _isDragging = false;
    });
    widget.onPageChanged?.call(_currentIndex);
  }

  void _turnTo(int target) {
    if (target < 0 || target >= widget.itemCount || target == _currentIndex) return;
    _targetIndex = target;
    _isForward = target > _currentIndex;
    _isDragging = false;
    _dragOffset = _isForward ? -1.0 : 1.0;
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
    final bool shouldFlip = _dragOffset.abs() > 0.16 || velocity.abs() > 280;

    if (shouldFlip) {
      // Swiping left (_dragOffset < 0) advances forward to next page.
      // Swiping right (_dragOffset > 0) goes back to previous page.
      final bool movingForward = _dragOffset < 0;
      final int step = movingForward ? 1 : -1;
      final candidate = _currentIndex + step;

      if (candidate >= 0 && candidate < widget.itemCount) {
        _targetIndex = candidate;
        _isForward = movingForward;
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
        bool isForward;
        int targetIndex;

        if (_controller.isAnimating) {
          progress = _controller.value;
          isForward = _isForward;
          targetIndex = _targetIndex;
        } else if (_isDragging) {
          progress = _dragOffset.abs();
          isForward = _dragOffset < 0;
          targetIndex = isForward ? _currentIndex + 1 : _currentIndex - 1;
        } else {
          progress = 0.0;
          isForward = true;
          targetIndex = _currentIndex;
        }

        final bool hasTarget = targetIndex >= 0 &&
            targetIndex < widget.itemCount &&
            targetIndex != _currentIndex;

        // When flipping forward: page curls towards the left.
        // When flipping backward: page curls towards the right.
        final bool toLeft = isForward;

        return GestureDetector(
          onHorizontalDragStart: _onHorizontalDragStart,
          onHorizontalDragUpdate: (details) =>
              _onHorizontalDragUpdate(details, width),
          onHorizontalDragEnd: (details) => _onHorizontalDragEnd(details, width),
          behavior: HitTestBehavior.opaque,
          child: ClipRect(
            child: Stack(
              fit: StackFit.expand,
              clipBehavior: Clip.hardEdge,
              children: [
                if (!hasTarget || progress <= 0.0)
                  // Resting flat page
                  Positioned.fill(
                    child: widget.itemBuilder(context, _currentIndex),
                  )
                else if (isForward) ...[
                  // Case 1: Forward turn (_currentIndex -> targetIndex)
                  // 1a. Stationary bottom page: targetIndex revealed underneath
                  Positioned.fill(
                    child: widget.itemBuilder(context, targetIndex),
                  ),

                  // 1b. Soft drop shadow cast onto revealed page below
                  Positioned.fill(
                    child: _UnderneathCastShadow(
                      progress: progress,
                      toLeft: toLeft,
                    ),
                  ),

                  // 1c. Moving top page: _currentIndex curling outward into spine
                  Positioned.fill(
                    child: _buildTurningPage(
                      context: context,
                      pageIndex: _currentIndex,
                      // Angle rotates 0 -> 90 degrees (pi / 2) as it folds away
                      angle: progress * (math.pi / 2.0),
                      // Negative Z lifts the page outward towards the reader
                      outwardZ: -math.sin(progress * math.pi) * 120.0,
                      progress: progress,
                      toLeft: toLeft,
                    ),
                  ),
                ] else ...[
                  // Case 2: Backward turn (_currentIndex -> targetIndex = _currentIndex - 1)
                  // 2a. Stationary bottom page: _currentIndex stays underneath
                  Positioned.fill(
                    child: widget.itemBuilder(context, _currentIndex),
                  ),

                  // 2b. Soft drop shadow cast onto bottom page
                  Positioned.fill(
                    child: _UnderneathCastShadow(
                      progress: 1.0 - progress,
                      toLeft: !toLeft,
                    ),
                  ),

                  // 2c. Moving top page: targetIndex unfolding from spine onto screen
                  Positioned.fill(
                    child: _buildTurningPage(
                      context: context,
                      pageIndex: targetIndex,
                      // Angle unrolls from 90 degrees (pi / 2) down to 0 degrees
                      angle: (1.0 - progress) * (math.pi / 2.0),
                      outwardZ: -math.sin(progress * math.pi) * 120.0,
                      progress: 1.0 - progress,
                      toLeft: !toLeft,
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTurningPage({
    required BuildContext context,
    required int pageIndex,
    required double angle,
    required double outwardZ,
    required double progress,
    required bool toLeft,
  }) {
    return Transform(
      alignment: toLeft ? Alignment.centerLeft : Alignment.centerRight,
      transform: Matrix4.identity()
        ..setEntry(3, 2, 0.0010) // Perspective depth
        ..setTranslationRaw(0.0, 0.0, outwardZ) // Arches outward toward reader
        ..rotateY(toLeft ? angle : -angle), // Folds outward towards viewer
      child: ClipPath(
        clipper: _PageCurlClipper(
          progress: progress,
          toLeft: toLeft,
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Authentic manga artwork (always visible, never masked out!)
            widget.itemBuilder(context, pageIndex),

            // Dynamic paper fold lighting (subtle specular ridge sheen & crease shadow)
            Positioned.fill(
              child: _PageCurlLighting(
                progress: progress,
                toLeft: toLeft,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Clips the top and bottom of the page along a smooth cubic cylinder curve (изгиб листа бумаги).
class _PageCurlClipper extends CustomClipper<Path> {
  final double progress;
  final bool toLeft;

  const _PageCurlClipper({required this.progress, required this.toLeft});

  @override
  Path getClip(Size size) {
    if (progress <= 0.005 || progress >= 0.995) {
      return Path()..addRect(Offset.zero & size);
    }

    final path = Path();
    final w = size.width;
    final h = size.height;

    // Peak arch height: maximum at progress = 0.5
    final arch = math.sin(progress * math.pi) * 22.0;

    final spineX = toLeft ? 0.0 : w;
    final movingX = toLeft ? w : 0.0;
    final midX = (spineX + movingX) / 2.0;

    path.moveTo(spineX, 0);

    // Top edge curve: gentle cubic cylinder arch simulating curved paper edge
    path.cubicTo(
      toLeft ? spineX + w * 0.3 : spineX - w * 0.3,
      arch * 0.35,
      midX,
      arch * 0.55,
      movingX,
      0,
    );

    // Outer moving edge
    path.lineTo(movingX, h);

    // Bottom edge curve: symmetric cylinder arch
    path.cubicTo(
      midX,
      h - arch * 0.55,
      toLeft ? spineX + w * 0.3 : spineX - w * 0.3,
      h - arch * 0.35,
      spineX,
      h,
    );

    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant _PageCurlClipper oldClipper) =>
      oldClipper.progress != progress || oldClipper.toLeft != toLeft;
}

/// Realistic paper lighting: subtle specular highlight on the curve crest and ambient fold shading.
/// Uses transparent gradients so the artwork is never covered with a white square!
class _PageCurlLighting extends StatelessWidget {
  final double progress;
  final bool toLeft;

  const _PageCurlLighting({
    required this.progress,
    required this.toLeft,
  });

  @override
  Widget build(BuildContext context) {
    if (progress <= 0.01 || progress >= 0.99) {
      return const SizedBox.shrink();
    }

    final sinP = math.sin(progress * math.pi);
    final apexFraction = toLeft ? (1.0 - progress) : progress;

    return IgnorePointer(
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Crease shadow: ambient darkening where the paper folds near the spine
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: toLeft ? Alignment.centerLeft : Alignment.centerRight,
                  end: toLeft ? Alignment.centerRight : Alignment.centerLeft,
                  colors: [
                    Colors.black.withValues(alpha: 0.32 * sinP),
                    Colors.black.withValues(alpha: 0.08 * sinP),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.28, 1.0],
                ),
              ),
            ),
          ),

          // Specular highlight band: subtle light sheen along the curved paper apex
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    Colors.transparent,
                    Colors.white.withValues(alpha: 0.18 * sinP),
                    Colors.transparent,
                  ],
                  stops: [
                    (apexFraction - 0.14).clamp(0.0, 1.0),
                    apexFraction.clamp(0.0, 1.0),
                    (apexFraction + 0.14).clamp(0.0, 1.0),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Soft drop shadow cast on the underneath page by the elevated curl above.
class _UnderneathCastShadow extends StatelessWidget {
  final double progress;
  final bool toLeft;

  const _UnderneathCastShadow({
    required this.progress,
    required this.toLeft,
  });

  @override
  Widget build(BuildContext context) {
    if (progress <= 0.01 || progress >= 0.99) {
      return const SizedBox.shrink();
    }

    final sinP = math.sin(progress * math.pi);

    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: toLeft ? Alignment.centerLeft : Alignment.centerRight,
            end: toLeft ? Alignment.centerRight : Alignment.centerLeft,
            colors: [
              Colors.black.withValues(alpha: 0.38 * sinP),
              Colors.black.withValues(alpha: 0.12 * sinP),
              Colors.transparent,
            ],
            stops: const [0.0, 0.25, 0.65],
          ),
        ),
      ),
    );
  }
}
