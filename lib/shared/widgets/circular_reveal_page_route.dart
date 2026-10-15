import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';

/// A custom page route that expands from a circular origin (e.g. a floating button)
/// to reveal the new screen, and shrinks back into the origin when popped.
class CircularRevealPageRoute<T> extends PageRoute<T> {
  CircularRevealPageRoute({
    required this.builder,
    required this.centerOffset,
    this.initialRadius = 26.0,
    Duration? transitionDuration,
    Duration? reverseTransitionDuration,
    super.settings,
  })  : transitionDuration =
            transitionDuration ?? const Duration(milliseconds: 650),
        reverseTransitionDuration =
            reverseTransitionDuration ?? const Duration(milliseconds: 500);

  final WidgetBuilder builder;
  final Offset centerOffset;
  final double initialRadius;

  @override
  final Duration transitionDuration;

  @override
  final Duration reverseTransitionDuration;

  @override
  bool get opaque => false;

  @override
  bool get barrierDismissible => false;

  @override
  Color? get barrierColor => null;

  @override
  String? get barrierLabel => null;

  @override
  bool get maintainState => true;

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    return builder(context);
  }

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final curvedAnimation = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInOutCubic,
    );

    return AnimatedBuilder(
      animation: curvedAnimation,
      builder: (context, child) {
        final progress = curvedAnimation.value;
        return ClipPath(
          clipper: _CircularRevealClipper(
            fraction: progress,
            center: centerOffset,
            initialRadius: initialRadius,
          ),
          child: FadeTransition(
            opacity: Tween<double>(begin: 0.0, end: 1.0).animate(
              CurvedAnimation(
                parent: animation,
                curve: const Interval(0.0, 0.40, curve: Curves.easeOut),
                reverseCurve: const Interval(0.60, 1.0, curve: Curves.easeIn),
              ),
            ),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}

class _CircularRevealClipper extends CustomClipper<Path> {
  _CircularRevealClipper({
    required this.fraction,
    required this.center,
    required this.initialRadius,
  });

  final double fraction;
  final Offset center;
  final double initialRadius;

  @override
  Path getClip(Size size) {
    if (fraction >= 1.0) {
      return Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    }
    if (fraction <= 0.0) {
      return Path()
        ..addOval(Rect.fromCircle(center: center, radius: initialRadius));
    }

    final maxDx = max(center.dx, size.width - center.dx);
    final maxDy = max(center.dy, size.height - center.dy);
    final maxRadius = sqrt(maxDx * maxDx + maxDy * maxDy);

    final currentRadius =
        lerpDouble(initialRadius, maxRadius, fraction) ?? maxRadius * fraction;

    return Path()
      ..addOval(Rect.fromCircle(center: center, radius: currentRadius));
  }

  @override
  bool shouldReclip(_CircularRevealClipper oldClipper) =>
      oldClipper.fraction != fraction ||
      oldClipper.center != center ||
      oldClipper.initialRadius != initialRadius;
}
