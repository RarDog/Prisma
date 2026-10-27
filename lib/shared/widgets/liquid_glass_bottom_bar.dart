import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_destination.dart';

class LiquidGlassBottomBar extends StatefulWidget {
  const LiquidGlassBottomBar({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.items,
    required this.ru,
    this.settingsIndex,
    this.onSettingsTap,
  });

  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final List<AppDestination> items;
  final bool ru;

  /// When set, tapping this item triggers [onSettingsTap] (circular reveal)
  /// instead of a branch navigation, and never becomes the selected index.
  final int? settingsIndex;
  final void Function(Offset globalCenter)? onSettingsTap;

  @override
  State<LiquidGlassBottomBar> createState() => LiquidGlassBottomBarState();
}

class LiquidGlassBottomBarState extends State<LiquidGlassBottomBar>
    with TickerProviderStateMixin {
  int? _pressedIndex;
  late final AnimationController _pillController;
  late Animation<double> _leadAnimation;
  late Animation<double> _trailAnimation;

  late final AnimationController _rippleController;
  Offset? _rippleCenter;

  int _fromIndex = 0;
  int _toIndex = 0;

  @override
  void initState() {
    super.initState();
    _fromIndex = widget.selectedIndex;
    _toIndex = widget.selectedIndex;
    _pillController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _leadAnimation = CurvedAnimation(
      parent: _pillController,
      curve: Curves.easeOutCubic,
    );
    _trailAnimation = CurvedAnimation(
      parent: _pillController,
      curve: const Interval(0.12, 1.0, curve: Curves.easeOutBack),
    );
    _rippleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          if (mounted) setState(() => _rippleCenter = null);
        }
      });
  }

  @override
  void didUpdateWidget(covariant LiquidGlassBottomBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedIndex != oldWidget.selectedIndex) {
      _fromIndex = _toIndex;
      _toIndex = widget.selectedIndex;
      _pillController.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _pillController.dispose();
    _rippleController.dispose();
    super.dispose();
  }

  void _spawnRipple(Offset localCenter) {
    setState(() => _rippleCenter = localCenter);
    _rippleController.forward(from: 0.0);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isAmoled = isDark &&
        (theme.scaffoldBackgroundColor == const Color(0xFF000000) ||
            theme.colorScheme.surface == const Color(0xFF000000));
    final scheme = theme.colorScheme;
    final count = widget.items.length;
    if (count == 0) return const SizedBox.shrink();

    final blurSigma = isAmoled ? 24.0 : 20.0;

    return SafeArea(
      top: false,
      left: false,
      right: false,
      child: Align(
        alignment: Alignment.bottomCenter,
        heightFactor: 1.0,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final barWidth = constraints.maxWidth;
                final itemWidth = barWidth / count;
                final pillWidth = (itemWidth - 6).clamp(36.0, 64.0);

                return Container(
                  height: 64,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(
                          alpha: isAmoled ? 0.55 : (isDark ? 0.38 : 0.09),
                        ),
                        blurRadius: isAmoled ? 28 : 22,
                        offset: const Offset(0, 8),
                        spreadRadius: isAmoled ? 0 : -2,
                      ),
                      if (isDark)
                        BoxShadow(
                          color: scheme.primary.withValues(
                            alpha: isAmoled ? 0.12 : 0.07,
                          ),
                          blurRadius: 18,
                          offset: const Offset(0, 2),
                        ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(28),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(
                          sigmaX: blurSigma, sigmaY: blurSigma),
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(28),
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: isAmoled
                                ? [
                                    const Color(0xFF141414)
                                        .withValues(alpha: 0.85),
                                    const Color(0xFF000000)
                                        .withValues(alpha: 0.90),
                                  ]
                                : isDark
                                    ? [
                                        scheme.surfaceContainerHigh
                                            .withValues(alpha: 0.70),
                                        scheme.surface.withValues(alpha: 0.82),
                                      ]
                                    : [
                                        Colors.white.withValues(alpha: 0.86),
                                        Colors.white.withValues(alpha: 0.68),
                                      ],
                          ),
                          border: Border.all(
                            color: isAmoled
                                ? Colors.white.withValues(alpha: 0.20)
                                : isDark
                                    ? Colors.white.withValues(alpha: 0.16)
                                    : Colors.white.withValues(alpha: 0.78),
                            width: 1.2,
                          ),
                        ),
                        child: Stack(
                          alignment: Alignment.centerLeft,
                          children: [
                            // Specular Bevel Highlight on top edge
                            Positioned(
                              top: 0,
                              left: 28,
                              right: 28,
                              height: 1.2,
                              child: IgnorePointer(
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        Colors.white.withValues(alpha: 0.0),
                                        Colors.white.withValues(
                                          alpha: isDark ? 0.42 : 0.85,
                                        ),
                                        Colors.white.withValues(alpha: 0.0),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),

                            // Ambient Glass Underglow behind active tab
                            AnimatedBuilder(
                              animation: _pillController,
                              builder: (context, _) {
                                final safeFrom = _fromIndex.clamp(0, count - 1);
                                final safeTo = _toIndex.clamp(0, count - 1);
                                final currentCenterX = lerpDouble(
                                  safeFrom * itemWidth + itemWidth / 2,
                                  safeTo * itemWidth + itemWidth / 2,
                                  _leadAnimation.value,
                                )!;

                                return Positioned(
                                  left: currentCenterX - itemWidth * 0.6,
                                  top: 2,
                                  width: itemWidth * 1.2,
                                  height: 58,
                                  child: IgnorePointer(
                                    child: DecoratedBox(
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        gradient: RadialGradient(
                                          colors: [
                                            scheme.primary.withValues(
                                              alpha: isDark ? 0.24 : 0.14,
                                            ),
                                            scheme.primary
                                                .withValues(alpha: 0.0),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),

                            // Animated liquid-stretching & squishing pill indicator
                            AnimatedBuilder(
                              animation: _pillController,
                              builder: (context, _) {
                                final safeFrom = _fromIndex.clamp(0, count - 1);
                                final safeTo = _toIndex.clamp(0, count - 1);
                                final xFrom = safeFrom * itemWidth +
                                    (itemWidth - pillWidth) / 2;
                                final xTo = safeTo * itemWidth +
                                    (itemWidth - pillWidth) / 2;

                                double left;
                                double width;

                                if (safeFrom == safeTo ||
                                    !_pillController.isAnimating) {
                                  left = xTo;
                                  width = pillWidth;
                                } else if (xTo >= xFrom) {
                                  // Moving right: right edge leads, left edge trails
                                  final right = lerpDouble(
                                    xFrom + pillWidth,
                                    xTo + pillWidth,
                                    _leadAnimation.value,
                                  )!;
                                  left = lerpDouble(
                                    xFrom,
                                    xTo,
                                    _trailAnimation.value,
                                  )!;
                                  width =
                                      (right - left).clamp(pillWidth, barWidth);
                                } else {
                                  // Moving left: left edge leads, right edge trails
                                  left = lerpDouble(
                                    xFrom,
                                    xTo,
                                    _leadAnimation.value,
                                  )!;
                                  final right = lerpDouble(
                                    xFrom + pillWidth,
                                    xTo + pillWidth,
                                    _trailAnimation.value,
                                  )!;
                                  width =
                                      (right - left).clamp(pillWidth, barWidth);
                                }

                                // Liquid Squish factor (conservation of fluid volume)
                                final progress = _pillController.value;
                                final squish = _pillController.isAnimating
                                    ? math.sin(progress * math.pi) * 2.8
                                    : 0.0;
                                final pillH = 33.0 - squish;
                                final pillTop = 6.5 + (squish / 2);

                                return Positioned(
                                  left: left,
                                  top: pillTop,
                                  child: Container(
                                    width: width,
                                    height: pillH,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(16.5),
                                      gradient: LinearGradient(
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                        colors: isDark
                                            ? [
                                                scheme.primary
                                                    .withValues(alpha: 0.40),
                                                scheme.primaryContainer
                                                    .withValues(alpha: 0.76),
                                              ]
                                            : [
                                                scheme.primaryContainer
                                                    .withValues(alpha: 0.96),
                                                scheme.primaryContainer
                                                    .withValues(alpha: 0.74),
                                              ],
                                      ),
                                      border: Border.all(
                                        color: isDark
                                            ? Colors.white
                                                .withValues(alpha: 0.32)
                                            : scheme.primary
                                                .withValues(alpha: 0.28),
                                        width: 1.1,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: scheme.primary.withValues(
                                            alpha: isDark ? 0.32 : 0.16,
                                          ),
                                          blurRadius: 14,
                                          offset: const Offset(0, 3),
                                          spreadRadius: -1,
                                        ),
                                        if (isDark)
                                          BoxShadow(
                                            color: scheme.primary
                                                .withValues(alpha: 0.16),
                                            blurRadius: 20,
                                            spreadRadius: 1,
                                          ),
                                      ],
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(16.5),
                                      child: Stack(
                                        children: [
                                          Positioned(
                                            top: 0,
                                            left: 0,
                                            right: 0,
                                            height: 12,
                                            child: DecoratedBox(
                                              decoration: BoxDecoration(
                                                gradient: LinearGradient(
                                                  begin: Alignment.topCenter,
                                                  end: Alignment.bottomCenter,
                                                  colors: [
                                                    Colors.white.withValues(
                                                        alpha: isDark
                                                            ? 0.22
                                                            : 0.40),
                                                    Colors.white
                                                        .withValues(alpha: 0.0),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),

                            // Material-3 style ripple expanding from the
                            // tap point across the glass.
                            AnimatedBuilder(
                              animation: _rippleController,
                              builder: (context, _) {
                                final center = _rippleCenter;
                                if (center == null ||
                                    !_rippleController.isAnimating) {
                                  return const SizedBox.shrink();
                                }
                                final radius = lerpDouble(
                                  12.0,
                                  barWidth * 0.75,
                                  Curves.easeOut
                                      .transform(_rippleController.value),
                                )!;
                                final opacity =
                                    (1.0 - _rippleController.value) * 0.16;
                                return Positioned(
                                  left: center.dx - radius,
                                  top: center.dy - radius,
                                  width: radius * 2,
                                  height: radius * 2,
                                  child: IgnorePointer(
                                    child: DecoratedBox(
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        gradient: RadialGradient(
                                          colors: [
                                            Colors.white
                                                .withValues(alpha: opacity),
                                            Colors.white.withValues(alpha: 0.0),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),

                            // Navigation item buttons
                            Row(
                              children: [
                                for (var i = 0; i < count; i++)
                                  Expanded(
                                    child: Builder(
                                      builder: (itemContext) => _LiquidNavItem(
                                        destination: widget.items[i],
                                        label: widget.items[i]
                                            .mobileLabelFor(widget.ru),
                                        isSelected: widget.selectedIndex == i,
                                        isPressed: _pressedIndex == i,
                                        onTapDown: (localCenter) {
                                          setState(() => _pressedIndex = i);
                                          _spawnRipple(localCenter);
                                        },
                                        onTapUp: () => setState(
                                            () => _pressedIndex = null),
                                        onTapCancel: () => setState(
                                            () => _pressedIndex = null),
                                        onTap: () {
                                          HapticFeedback.selectionClick();
                                          if (widget.settingsIndex == i &&
                                              widget.onSettingsTap != null) {
                                            final box =
                                                itemContext.findRenderObject()
                                                    as RenderBox?;
                                            final size = box?.size ?? Size.zero;
                                            final origin = box?.localToGlobal(
                                                    Offset.zero) ??
                                                Offset.zero;
                                            widget.onSettingsTap!(Offset(
                                              origin.dx + size.width / 2,
                                              origin.dy + size.height / 2,
                                            ));
                                            return;
                                          }
                                          widget.onDestinationSelected(i);
                                        },
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _LiquidNavItem extends StatefulWidget {
  const _LiquidNavItem({
    required this.destination,
    required this.label,
    required this.isSelected,
    required this.isPressed,
    required this.onTapDown,
    required this.onTapUp,
    required this.onTapCancel,
    required this.onTap,
  });

  final AppDestination destination;
  final String label;
  final bool isSelected;
  final bool isPressed;
  final ValueChanged<Offset> onTapDown;
  final VoidCallback onTapUp;
  final VoidCallback onTapCancel;
  final VoidCallback onTap;

  @override
  State<_LiquidNavItem> createState() => _LiquidNavItemState();
}

class _LiquidNavItemState extends State<_LiquidNavItem>
    with SingleTickerProviderStateMixin {
  late final AnimationController _wiggleController;

  // Rotation keyframes of the entrance wiggle (radians).
  late final Animation<double> _wiggleAngle = TweenSequence<double>([
    TweenSequenceItem(
      tween: Tween(begin: 0.0, end: -0.16)
          .chain(CurveTween(curve: Curves.easeOut)),
      weight: 30,
    ),
    TweenSequenceItem(
      tween: Tween(begin: -0.16, end: 0.10)
          .chain(CurveTween(curve: Curves.easeInOut)),
      weight: 35,
    ),
    TweenSequenceItem(
      tween:
          Tween(begin: 0.10, end: 0.0).chain(CurveTween(curve: Curves.easeOut)),
      weight: 35,
    ),
  ]).animate(_wiggleController);

  @override
  void initState() {
    super.initState();
    _wiggleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 480),
    );
  }

  @override
  void didUpdateWidget(covariant _LiquidNavItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.isSelected && widget.isSelected) {
      // Entrance flourish: spring wiggle + one-shot glow behind the icon.
      _wiggleController.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _wiggleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final targetScale =
        widget.isPressed ? 0.88 : (widget.isSelected ? 1.08 : 1.0);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (details) {
        final box = context.findRenderObject() as RenderBox?;
        widget.onTapDown(
          box?.globalToLocal(details.globalPosition) ?? Offset.zero,
        );
      },
      onTapUp: (_) => widget.onTapUp(),
      onTapCancel: widget.onTapCancel,
      onTap: widget.onTap,
      child: Center(
        child: AnimatedScale(
          scale: targetScale,
          duration: const Duration(milliseconds: 220),
          curve: Curves.elasticOut,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                height: 31,
                child: Center(
                  child: AnimatedSlide(
                    offset: widget.isSelected
                        ? const Offset(0, -0.06)
                        : Offset.zero,
                    duration: const Duration(milliseconds: 260),
                    curve: Curves.easeOutBack,
                    child: AnimatedBuilder(
                      animation: _wiggleController,
                      builder: (context, child) {
                        final glow =
                            math.sin(_wiggleController.value * math.pi);
                        return Stack(
                          alignment: Alignment.center,
                          clipBehavior: Clip.none,
                          children: [
                            if (glow > 0.01)
                              IgnorePointer(
                                child: Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: scheme.primary
                                            .withValues(alpha: 0.45 * glow),
                                        blurRadius: 18,
                                        spreadRadius: 2,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            Transform.rotate(
                              angle: _wiggleAngle.value,
                              child: child,
                            ),
                          ],
                        );
                      },
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 220),
                        switchInCurve: Curves.easeOutBack,
                        switchOutCurve: Curves.easeInCubic,
                        transitionBuilder: (child, anim) => FadeTransition(
                          opacity: anim,
                          child: ScaleTransition(
                            scale: Tween<double>(begin: 0.80, end: 1.0)
                                .animate(anim),
                            child: child,
                          ),
                        ),
                        child: Icon(
                          widget.isSelected
                              ? widget.destination.effectiveSelectedIcon
                              : widget.destination.icon,
                          key: ValueKey(
                              '${widget.destination.id}_${widget.isSelected}'),
                          size: widget.isSelected ? 22.0 : 19.5,
                          color: widget.isSelected
                              ? scheme.onPrimaryContainer
                              : (isDark
                                  ? scheme.onSurfaceVariant
                                      .withValues(alpha: 0.74)
                                  : scheme.onSurfaceVariant
                                      .withValues(alpha: 0.82)),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 1),
              // The label occupies its slot in every tab (stable layout) but
              // is only visible on the active one.
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                style: TextStyle(
                  fontSize: 9.5,
                  fontWeight:
                      widget.isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: widget.isSelected
                      ? scheme.primary
                      : scheme.primary.withValues(alpha: 0.0),
                  letterSpacing: widget.isSelected ? -0.1 : -0.3,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                child: Text(widget.label),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class LiquidGlassSettingsButton extends StatefulWidget {
  const LiquidGlassSettingsButton({
    super.key,
    required this.ru,
    this.onTap,
    this.onTapWithCenter,
  });

  final bool ru;
  final VoidCallback? onTap;
  final void Function(Offset center)? onTapWithCenter;

  @override
  State<LiquidGlassSettingsButton> createState() =>
      _LiquidGlassSettingsButtonState();
}

class _LiquidGlassSettingsButtonState extends State<LiquidGlassSettingsButton> {
  bool _pressed = false;

  void _handleTap() {
    HapticFeedback.lightImpact();

    final box = context.findRenderObject() as RenderBox?;
    final origin = box?.localToGlobal(Offset.zero) ?? Offset.zero;
    final size = box?.size ?? const Size(52, 52);
    final center =
        Offset(origin.dx + size.width / 2, origin.dy + size.height / 2);

    if (widget.onTapWithCenter != null) {
      widget.onTapWithCenter!(center);
    } else {
      widget.onTap?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isAmoled = isDark &&
        (theme.scaffoldBackgroundColor == const Color(0xFF000000) ||
            theme.colorScheme.surface == const Color(0xFF000000));
    final scheme = theme.colorScheme;
    final blurSigma = isAmoled ? 28.0 : 24.0;

    return Tooltip(
      message: widget.ru ? 'Настройки' : 'Settings',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        onTap: _handleTap,
        child: AnimatedScale(
          scale: _pressed ? 0.88 : 1.0,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutBack,
          child: Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(
                    alpha: isAmoled ? 0.60 : (isDark ? 0.40 : 0.14),
                  ),
                  blurRadius: isAmoled ? 26 : 20,
                  offset: const Offset(0, 7),
                  spreadRadius: isAmoled ? 0 : -1,
                ),
                BoxShadow(
                  color: scheme.primary.withValues(
                    alpha: isDark ? 0.35 : 0.22,
                  ),
                  blurRadius: 16,
                  offset: const Offset(0, 3),
                  spreadRadius: 1,
                ),
              ],
            ),
            child: ClipOval(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
                child: Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      center: const Alignment(-0.3, -0.4),
                      radius: 1.15,
                      colors: isAmoled
                          ? [
                              const Color(0xFF282828).withValues(alpha: 0.96),
                              const Color(0xFF161616).withValues(alpha: 0.92),
                              const Color(0xFF080808).withValues(alpha: 0.88),
                            ]
                          : isDark
                              ? [
                                  scheme.primaryContainer
                                      .withValues(alpha: 0.40),
                                  scheme.surfaceContainerHigh
                                      .withValues(alpha: 0.88),
                                  scheme.surface.withValues(alpha: 0.80),
                                ]
                              : [
                                  Colors.white.withValues(alpha: 0.98),
                                  Colors.white.withValues(alpha: 0.86),
                                  Colors.white.withValues(alpha: 0.72),
                                ],
                      stops: const [0.0, 0.55, 1.0],
                    ),
                    border: Border.all(
                      color: isAmoled
                          ? Colors.white.withValues(alpha: 0.28)
                          : isDark
                              ? scheme.primary.withValues(alpha: 0.38)
                              : Colors.white.withValues(alpha: 0.90),
                      width: 1.5,
                    ),
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Specular top-light crescent
                      Positioned(
                        top: 2.5,
                        left: 9,
                        right: 9,
                        height: 2.0,
                        child: IgnorePointer(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(1.0),
                              gradient: LinearGradient(
                                colors: [
                                  Colors.white.withValues(alpha: 0.0),
                                  Colors.white.withValues(
                                    alpha: isDark ? 0.55 : 0.95,
                                  ),
                                  Colors.white.withValues(alpha: 0.0),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      Center(
                        child: AnimatedRotation(
                          turns: _pressed ? 0.25 : 0.0,
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeOutBack,
                          child: Icon(
                            Icons.settings_rounded,
                            size: 24,
                            color: isDark ? Colors.white : scheme.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
