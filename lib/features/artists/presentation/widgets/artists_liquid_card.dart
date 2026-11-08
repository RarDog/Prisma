import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

class ArtistsLiquidCard extends StatelessWidget {
  const ArtistsLiquidCard({
    super.key,
    required this.child,
    this.padding,
    this.glowColor,
    this.onTap,
    this.backgroundImageUrl,
    this.backgroundHeaders,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final Color? glowColor;
  final VoidCallback? onTap;
  final String? backgroundImageUrl;
  final Map<String, String>? backgroundHeaders;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final accent = glowColor ?? theme.colorScheme.primary;
    final r = BorderRadius.circular(22);
    final hasBackground =
        backgroundImageUrl != null && backgroundImageUrl!.trim().isNotEmpty;

    final cardContent = Container(
      padding: padding ?? const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: r,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? (hasBackground
                  ? [
                      Colors.black.withValues(alpha: 0.52),
                      Colors.black.withValues(alpha: 0.78),
                    ]
                  : [
                      theme.colorScheme.surfaceContainerHigh
                          .withValues(alpha: 0.62),
                      theme.colorScheme.surfaceContainerLow
                          .withValues(alpha: 0.40),
                    ])
              : (hasBackground
                  ? [
                      Colors.white.withValues(alpha: 0.76),
                      Colors.white.withValues(alpha: 0.88),
                    ]
                  : [
                      Colors.white.withValues(alpha: 0.88),
                      Colors.white.withValues(alpha: 0.72),
                    ]),
        ),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: hasBackground ? 0.20 : 0.14)
              : Colors.white.withValues(alpha: 0.85),
          width: 1.2,
        ),
      ),
      child: child,
    );

    return RepaintBoundary(
      child: Container(
        decoration: BoxDecoration(
          borderRadius: r,
          boxShadow: [
            BoxShadow(
              color: isDark
                  ? Colors.black.withValues(alpha: 0.28)
                  : accent.withValues(alpha: 0.06),
              blurRadius: 10,
              offset: const Offset(0, 3),
              spreadRadius: -1,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: r,
          child: Stack(
            fit: StackFit.passthrough,
            children: [
              if (hasBackground)
                Positioned.fill(
                  child: CachedNetworkImage(
                    imageUrl: backgroundImageUrl!,
                    httpHeaders: backgroundHeaders,
                    memCacheWidth: 480,
                    fit: BoxFit.cover,
                    fadeInDuration: const Duration(milliseconds: 200),
                    fadeOutDuration: const Duration(milliseconds: 150),
                    placeholder: (_, __) => const SizedBox.shrink(),
                    errorWidget: (_, __, ___) => const SizedBox.shrink(),
                  ),
                ),
              if (onTap != null)
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: r,
                    onTap: onTap,
                    child: cardContent,
                  ),
                )
              else
                cardContent,
            ],
          ),
        ),
      ),
    );
  }
}

class LiquidMiniBadge extends StatelessWidget {
  const LiquidMiniBadge({
    super.key,
    required this.label,
    required this.color,
    this.hasDot = false,
  });

  final String label;
  final Color color;
  final bool hasDot;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final displayLabel =
        label.isEmpty ? '' : label[0].toUpperCase() + label.substring(1);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.18 : 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withValues(alpha: isDark ? 0.35 : 0.25),
          width: 1.0,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (hasDot) ...[
            Container(
              width: 5,
              height: 5,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 5),
          ],
          Text(
            displayLabel,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
