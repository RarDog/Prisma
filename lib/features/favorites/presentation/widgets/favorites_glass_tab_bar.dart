import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class FavoritesGlassTabBar extends StatelessWidget {
  const FavoritesGlassTabBar({
    super.key,
    required this.selectedIndex,
    required this.allCount,
    required this.artistsCount,
    required this.isRu,
    required this.onTabSelected,
  });

  final int selectedIndex;
  final int allCount;
  final int artistsCount;
  final bool isRu;
  final ValueChanged<int> onTabSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(
                alpha: isDark ? 0.22 : 0.04,
              ),
              blurRadius: 12,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                color: isDark
                    ? theme.colorScheme.surfaceContainerHigh
                        .withValues(alpha: 0.50)
                    : Colors.white.withValues(alpha: 0.76),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.12)
                      : Colors.white.withValues(alpha: 0.85),
                  width: 1.1,
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: FavoritesTabPill(
                      index: 0,
                      icon: Icons.favorite_rounded,
                      label: '${isRu ? 'Все' : 'All'} ($allCount)',
                      isSelected: selectedIndex == 0,
                      onTap: () => onTabSelected(0),
                    ),
                  ),
                  const SizedBox(width: 3),
                  Expanded(
                    child: FavoritesTabPill(
                      index: 1,
                      icon: Icons.groups_rounded,
                      label: '${isRu ? 'Авторы' : 'Artists'} ($artistsCount)',
                      isSelected: selectedIndex == 1,
                      onTap: () => onTabSelected(1),
                    ),
                  ),
                  const SizedBox(width: 3),
                  Expanded(
                    child: FavoritesTabPill(
                      index: 2,
                      icon: Icons.hub_rounded,
                      iconColor: const Color(0xFF0077EE),
                      label: 'e621',
                      isSelected: selectedIndex == 2,
                      onTap: () => onTabSelected(2),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class FavoritesTabPill extends StatelessWidget {
  const FavoritesTabPill({
    super.key,
    required this.index,
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.iconColor,
  });

  final int index;
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: isSelected
            ? LinearGradient(
                colors: [
                  scheme.primary,
                  scheme.primary.withValues(alpha: 0.88),
                ],
              )
            : null,
        color: isSelected ? null : Colors.transparent,
        boxShadow: isSelected
            ? [
                BoxShadow(
                  color: scheme.primary.withValues(alpha: 0.32),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            HapticFeedback.selectionClick();
            onTap();
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 15,
                  color: isSelected
                      ? Colors.white
                      : (iconColor ?? scheme.onSurfaceVariant),
                ),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.w600,
                      color:
                          isSelected ? Colors.white : scheme.onSurfaceVariant,
                      letterSpacing: -0.2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
