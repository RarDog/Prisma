import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_destination.dart';

class LiquidGlassBottomBar extends StatefulWidget {
  const LiquidGlassBottomBar({super.key, 
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.items,
    required this.ru,
  });

  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final List<AppDestination> items;
  final bool ru;

  @override
  State<LiquidGlassBottomBar> createState() => LiquidGlassBottomBarState();
}

class LiquidGlassBottomBarState extends State<LiquidGlassBottomBar>
    with SingleTickerProviderStateMixin {
  int? _pressedIndex;
  late final AnimationController _pillController;
  late Animation<double> _leadAnimation;
  late Animation<double> _trailAnimation;

  int _fromIndex = 0;
  int _toIndex = 0;

  @override
  void initState() {
    super.initState();
    _fromIndex = widget.selectedIndex;
    _toIndex = widget.selectedIndex;
    _pillController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
    _leadAnimation = CurvedAnimation(
      parent: _pillController,
      curve: Curves.easeOutCubic,
    );
    _trailAnimation = CurvedAnimation(
      parent: _pillController,
      curve: const Interval(0.14, 1.0, curve: Curves.easeOutBack),
    );
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final scheme = theme.colorScheme;
    final count = widget.items.length;
    if (count == 0) return const SizedBox.shrink();

    return SafeArea(
      top: false,
      left: false,
      right: false,
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
                    color: Colors.black.withValues(alpha: isDark ? 0.38 : 0.09),
                    blurRadius: 22,
                    offset: const Offset(0, 8),
                    spreadRadius: -2,
                  ),
                  if (isDark)
                    BoxShadow(
                      color: scheme.primary.withValues(alpha: 0.07),
                      blurRadius: 18,
                      offset: const Offset(0, 2),
                    ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(28),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: isDark
                            ? [
                                scheme.surfaceContainerHigh
                                    .withValues(alpha: 0.70),
                                scheme.surface.withValues(alpha: 0.82),
                              ]
                            : [
                                Colors.white.withValues(alpha: 0.84),
                                Colors.white.withValues(alpha: 0.68),
                              ],
                      ),
                      border: Border.all(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.16)
                            : Colors.white.withValues(alpha: 0.75),
                        width: 1.2,
                      ),
                    ),
                    child: Stack(
                      alignment: Alignment.centerLeft,
                      children: [
                        // Animated liquid-stretching pill indicator
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
                              width = (right - left).clamp(pillWidth, barWidth);
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
                              width = (right - left).clamp(pillWidth, barWidth);
                            }

                            return Positioned(
                              left: left,
                              top: 6.5,
                              child: Container(
                                width: width,
                                height: 33,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(16.5),
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: isDark
                                        ? [
                                            scheme.primary
                                                .withValues(alpha: 0.36),
                                            scheme.primaryContainer
                                                .withValues(alpha: 0.72),
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
                                        ? Colors.white.withValues(alpha: 0.30)
                                        : scheme.primary
                                            .withValues(alpha: 0.26),
                                    width: 1.1,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: scheme.primary.withValues(
                                        alpha: isDark ? 0.30 : 0.16,
                                      ),
                                      blurRadius: 12,
                                      offset: const Offset(0, 3),
                                      spreadRadius: -1,
                                    ),
                                    if (isDark)
                                      BoxShadow(
                                        color: scheme.primary
                                            .withValues(alpha: 0.14),
                                        blurRadius: 18,
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
                                                    alpha:
                                                        isDark ? 0.20 : 0.38),
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

                        // Navigation item buttons
                        Row(
                          children: [
                            for (var i = 0; i < count; i++)
                              Expanded(
                                child: _LiquidNavItem(
                                  destination: widget.items[i],
                                  label:
                                      widget.items[i].mobileLabelFor(widget.ru),
                                  isSelected: widget.selectedIndex == i,
                                  isPressed: _pressedIndex == i,
                                  onTapDown: () =>
                                      setState(() => _pressedIndex = i),
                                  onTapUp: () =>
                                      setState(() => _pressedIndex = null),
                                  onTapCancel: () =>
                                      setState(() => _pressedIndex = null),
                                  onTap: () {
                                    HapticFeedback.lightImpact();
                                    widget.onDestinationSelected(i);
                                  },
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
    );
  }
}

class _LiquidNavItem extends StatelessWidget {
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
  final VoidCallback onTapDown;
  final VoidCallback onTapUp;
  final VoidCallback onTapCancel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final targetScale = isPressed ? 0.88 : (isSelected ? 1.04 : 1.0);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => onTapDown(),
      onTapUp: (_) => onTapUp(),
      onTapCancel: onTapCancel,
      onTap: onTap,
      child: Center(
        child: AnimatedScale(
          scale: targetScale,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutBack,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                height: 31,
                child: Center(
                  child: AnimatedSlide(
                    offset: isSelected ? const Offset(0, -0.04) : Offset.zero,
                    duration: const Duration(milliseconds: 240),
                    curve: Curves.easeOutCubic,
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 220),
                      switchInCurve: Curves.easeOutBack,
                      switchOutCurve: Curves.easeInCubic,
                      transitionBuilder: (child, anim) => FadeTransition(
                        opacity: anim,
                        child: ScaleTransition(
                          scale: Tween<double>(begin: 0.82, end: 1.0)
                              .animate(anim),
                          child: child,
                        ),
                      ),
                      child: Icon(
                        isSelected
                            ? destination.effectiveSelectedIcon
                            : destination.icon,
                        key: ValueKey('${destination.id}_$isSelected'),
                        size: isSelected ? 21.5 : 19.5,
                        color: isSelected
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
              const SizedBox(height: 1),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected
                      ? (isDark ? scheme.primary : scheme.onSurface)
                      : scheme.onSurfaceVariant.withValues(alpha: 0.72),
                  letterSpacing: isSelected ? -0.1 : -0.3,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                child: Text(label),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class LiquidGlassSettingsButton extends StatefulWidget {
  const LiquidGlassSettingsButton({super.key, 
    required this.ru,
    required this.onTap,
  });

  final bool ru;
  final VoidCallback onTap;

  @override
  State<LiquidGlassSettingsButton> createState() =>
      _LiquidGlassSettingsButtonState();
}

class _LiquidGlassSettingsButtonState
    extends State<LiquidGlassSettingsButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final scheme = theme.colorScheme;

    return Tooltip(
      message: widget.ru ? 'Настройки' : 'Settings',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        onTap: () {
          HapticFeedback.mediumImpact();
          widget.onTap();
        },
        child: AnimatedScale(
          scale: _pressed ? 0.88 : 1.0,
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOutCubic,
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.38 : 0.12),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                  spreadRadius: -1,
                ),
                BoxShadow(
                  color: scheme.primary.withValues(alpha: isDark ? 0.20 : 0.12),
                  blurRadius: 12,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ClipOval(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      center: const Alignment(-0.3, -0.4),
                      radius: 1.1,
                      colors: isDark
                          ? [
                              scheme.surfaceContainerHigh
                                  .withValues(alpha: 0.85),
                              scheme.surface.withValues(alpha: 0.75),
                            ]
                          : [
                              Colors.white.withValues(alpha: 0.92),
                              Colors.white.withValues(alpha: 0.70),
                            ],
                    ),
                    border: Border.all(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.24)
                          : Colors.white.withValues(alpha: 0.85),
                      width: 1.4,
                    ),
                  ),
                  child: Center(
                    child: AnimatedRotation(
                      turns: _pressed ? 0.125 : 0.0,
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeOutBack,
                      child: Icon(
                        Icons.settings_rounded,
                        size: 23,
                        color: scheme.primary,
                      ),
                    ),
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

