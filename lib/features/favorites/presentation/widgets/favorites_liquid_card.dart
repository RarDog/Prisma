import 'dart:ui';
import 'package:flutter/material.dart';

class FavoritesLiquidCard extends StatelessWidget {
  const FavoritesLiquidCard({
    super.key,
    required this.child,
    this.padding,
    this.glowColor,
    this.margin,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final Color? glowColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final accent = glowColor ?? theme.colorScheme.primary;

    return Container(
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.30)
                : accent.withValues(alpha: 0.07),
            blurRadius: 16,
            offset: const Offset(0, 5),
            spreadRadius: -2,
          ),
          BoxShadow(
            color: accent.withValues(alpha: isDark ? 0.05 : 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            padding: padding ?? const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isDark
                    ? [
                        theme.colorScheme.surfaceContainerHigh
                            .withValues(alpha: 0.60),
                        theme.colorScheme.surfaceContainerLow
                            .withValues(alpha: 0.38),
                      ]
                    : [
                        Colors.white.withValues(alpha: 0.88),
                        Colors.white.withValues(alpha: 0.72),
                      ],
              ),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.14)
                    : Colors.white.withValues(alpha: 0.85),
                width: 1.2,
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
