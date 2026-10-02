import 'package:flutter/material.dart';

/// A container for [StatefulShellRoute] branch navigators that provides
/// a smooth Material 3 Fade-Through transition when switching tabs while
/// keeping all branches permanently in the widget tree so their scroll offsets,
/// input controllers, and navigation history are completely preserved.
class AnimatedBranchContainer extends StatefulWidget {
  const AnimatedBranchContainer({
    super.key,
    required this.currentIndex,
    required this.children,
    this.duration = const Duration(milliseconds: 240),
  });

  final int currentIndex;
  final List<Widget> children;
  final Duration duration;

  @override
  State<AnimatedBranchContainer> createState() => _AnimatedBranchContainerState();
}

class _AnimatedBranchContainerState extends State<AnimatedBranchContainer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _entryFade;
  late final Animation<double> _entryScale;
  late final Animation<double> _exitFade;

  int _currentIndex = 0;
  int? _previousIndex;
  double _slideDirection = 0.0;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.currentIndex;
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          if (mounted) {
            setState(() {
              _previousIndex = null;
            });
          }
        }
      });

    _entryFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.15, 1.0, curve: Curves.easeOutCubic),
      ),
    );

    _entryScale = Tween<double>(begin: 0.985, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 1.0, curve: Curves.easeOutCubic),
      ),
    );

    _exitFade = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.40, curve: Curves.easeInCubic),
      ),
    );
  }

  Animation<Offset> get _effectiveEntrySlide => _controller.drive(
        Tween<Offset>(
          begin: Offset(0.035 * _slideDirection, 0.0),
          end: Offset.zero,
        ).chain(
          CurveTween(
            curve: const Interval(0.10, 1.0, curve: Curves.easeOutCubic),
          ),
        ),
      );

  Animation<Offset> get _effectiveExitSlide => _controller.drive(
        Tween<Offset>(
          begin: Offset.zero,
          end: Offset(-0.025 * _slideDirection, 0.0),
        ).chain(
          CurveTween(
            curve: const Interval(0.0, 0.38, curve: Curves.easeInCubic),
          ),
        ),
      );

  @override
  void didUpdateWidget(covariant AnimatedBranchContainer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.currentIndex != oldWidget.currentIndex) {
      final direction =
          widget.currentIndex > oldWidget.currentIndex ? 1.0 : -1.0;
      setState(() {
        _slideDirection = direction;
        _previousIndex = oldWidget.currentIndex;
        _currentIndex = widget.currentIndex;
      });
      _controller.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasActiveTransition =
        _previousIndex != null && _controller.isAnimating;

    return Stack(
      fit: StackFit.expand,
      children: List.generate(widget.children.length, (index) {
        final child = widget.children[index];
        final isCurrent = index == _currentIndex;
        final isPrevious = index == _previousIndex;

        final bool offstage;
        final bool tickerEnabled;
        final bool ignoring;
        final Animation<double> opacity;
        final Animation<double> scale;
        final Animation<Offset> slide;

        if (isCurrent && !hasActiveTransition) {
          // Resting active state
          offstage = false;
          tickerEnabled = true;
          ignoring = false;
          opacity = kAlwaysCompleteAnimation;
          scale = kAlwaysCompleteAnimation;
          slide = const AlwaysStoppedAnimation(Offset.zero);
        } else if (isCurrent) {
          // Entering active state during transition
          offstage = false;
          tickerEnabled = true;
          ignoring = false;
          opacity = _entryFade;
          scale = _entryScale;
          slide = _effectiveEntrySlide;
        } else if (isPrevious && hasActiveTransition) {
          // Exiting previous state during transition
          offstage = false;
          tickerEnabled = false;
          ignoring = true;
          opacity = _exitFade;
          scale = kAlwaysCompleteAnimation;
          slide = _effectiveExitSlide;
        } else {
          // Inactive state
          offstage = true;
          tickerEnabled = false;
          ignoring = true;
          opacity = kAlwaysDismissedAnimation;
          scale = kAlwaysCompleteAnimation;
          slide = const AlwaysStoppedAnimation(Offset.zero);
        }

        return Offstage(
          offstage: offstage,
          child: TickerMode(
            enabled: tickerEnabled,
            child: IgnorePointer(
              ignoring: ignoring,
              child: SlideTransition(
                position: slide,
                child: FadeTransition(
                  opacity: opacity,
                  child: ScaleTransition(
                    scale: scale,
                    child: child,
                  ),
                ),
              ),
            ),
          ),
        );
      }),
    );
  }
}
