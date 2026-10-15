import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// Smooth, momentum-based mouse wheel scrolling binding for desktop platforms.
/// Converts discrete, abrupt mouse wheel notches into silky frame-by-frame
/// interpolated gestures without breaking scroll controllers or drag gestures.
class DesktopSmoothScrollBinding extends WidgetsFlutterBinding {
  static DesktopSmoothScrollBinding? _instance;

  static WidgetsBinding ensureInitialized() {
    return _instance ??= DesktopSmoothScrollBinding();
  }

  bool _isSynthesizing = false;
  Offset _accumulatedDelta = Offset.zero;
  int? _activeFrameCallbackId;
  Duration? _lastFrameTimestamp;

  PointerScrollEvent? _lastScrollEvent;
  Offset _currentPointerPosition = Offset.zero;

  // Smoothing constant: larger = faster arrival, smaller = smoother gliding.
  // 14.0 provides instant responsiveness with zero input lag and graceful ease-out.
  static const double _kSmoothingDecay = 14.0;
  static const double _kMinDeltaThreshold = 0.3;

  @override
  void handlePointerEvent(PointerEvent event) {
    if (_isSynthesizing) {
      super.handlePointerEvent(event);
      return;
    }

    // Keep pointer position updated on mouse moves/hovers so continuous
    // scrolls hit-test whichever view is currently hovered.
    if (event.kind == PointerDeviceKind.mouse) {
      _currentPointerPosition = event.position;
    }

    // Only intercept discrete mouse wheel scrolls on desktop platforms.
    final isDesktop =
        Platform.isLinux || Platform.isWindows || Platform.isMacOS;
    if (isDesktop &&
        event is PointerScrollEvent &&
        event.kind == PointerDeviceKind.mouse) {
      _lastScrollEvent = event;
      _accumulatedDelta += event.scrollDelta;

      _startFramePumpIfNeeded();
      return;
    }

    // Any pointer down immediately halts residual smooth momentum
    if (event is PointerDownEvent) {
      _stopFramePump();
    }

    super.handlePointerEvent(event);
  }

  void _startFramePumpIfNeeded() {
    if (_activeFrameCallbackId != null) return;
    _lastFrameTimestamp = null;
    _activeFrameCallbackId = scheduleFrameCallback(_onAnimationFrame);
  }

  void _stopFramePump() {
    if (_activeFrameCallbackId != null) {
      cancelFrameCallbackWithId(_activeFrameCallbackId!);
      _activeFrameCallbackId = null;
    }
    _accumulatedDelta = Offset.zero;
    _lastFrameTimestamp = null;
  }

  void _onAnimationFrame(Duration timeStamp) {
    _activeFrameCallbackId = null;

    final lastTime = _lastFrameTimestamp;
    _lastFrameTimestamp = timeStamp;

    if (lastTime == null) {
      // First frame since pump started: schedule next frame to compute dt
      _activeFrameCallbackId = scheduleFrameCallback(_onAnimationFrame);
      return;
    }

    final double dt =
        ((timeStamp - lastTime).inMicroseconds / Duration.microsecondsPerSecond)
            .clamp(0.001, 0.05);

    final event = _lastScrollEvent;
    if (event == null || _accumulatedDelta.distance < _kMinDeltaThreshold) {
      // Finish remaining tail
      if (event != null && _accumulatedDelta != Offset.zero) {
        _dispatchSynthesized(event, _accumulatedDelta);
      }
      _stopFramePump();
      return;
    }

    // Exponential ease-out interpolation
    final double fraction = 1.0 - math.exp(-_kSmoothingDecay * dt);
    final Offset stepDelta = _accumulatedDelta * fraction;
    _accumulatedDelta -= stepDelta;

    _dispatchSynthesized(event, stepDelta);

    if (_accumulatedDelta.distance >= _kMinDeltaThreshold) {
      _activeFrameCallbackId = scheduleFrameCallback(_onAnimationFrame);
    } else {
      if (_accumulatedDelta != Offset.zero) {
        _dispatchSynthesized(event, _accumulatedDelta);
      }
      _stopFramePump();
    }
  }

  void _dispatchSynthesized(PointerScrollEvent origin, Offset stepDelta) {
    if (stepDelta == Offset.zero) return;
    _isSynthesizing = true;
    try {
      super.handlePointerEvent(
        PointerScrollEvent(
          viewId: origin.viewId,
          timeStamp:
              Duration(microseconds: DateTime.now().microsecondsSinceEpoch),
          kind: PointerDeviceKind.mouse,
          device: origin.device,
          position: _currentPointerPosition,
          scrollDelta: stepDelta,
        ),
      );
    } finally {
      _isSynthesizing = false;
    }
  }
}

/// App-wide desktop scroll behavior providing elastic overscroll physics
/// and pointer device drag support for silky interactions.
class DesktopSmoothScrollBehavior extends MaterialScrollBehavior {
  const DesktopSmoothScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
        PointerDeviceKind.stylus,
      };

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    final isDesktop =
        Platform.isLinux || Platform.isWindows || Platform.isMacOS;
    if (isDesktop) {
      return const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      );
    }
    return super.getScrollPhysics(context);
  }
}
