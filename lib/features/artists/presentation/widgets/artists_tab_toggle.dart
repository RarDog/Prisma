import 'package:flutter/material.dart';

import 'artist_service_utils.dart';

/// Segmented Catalog / Favorites selector for the artists header.
class ArtistsTabToggle extends StatelessWidget {
  const ArtistsTabToggle({
    super.key,
    required this.currentTab,
    required this.onTabChanged,
    required this.favoritesCount,
    required this.isRu,
  });

  final ArtistsTab currentTab;
  final ValueChanged<ArtistsTab> onTabChanged;
  final int favoritesCount;
  final bool isRu;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      height: 42,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.black.withValues(alpha: 0.35)
            : Colors.black.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.10)
              : Colors.black.withValues(alpha: 0.06),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: _Segment(
              selected: currentTab == ArtistsTab.all,
              selectedColor: isDark
                  ? theme.colorScheme.primary.withValues(alpha: 0.28)
                  : Colors.white,
              selectedForeground:
                  isDark ? Colors.white : theme.colorScheme.primary,
              unselectedForeground:
                  isDark ? Colors.white70 : const Color(0xFF475569),
              onTap: () => onTabChanged(ArtistsTab.all),
              label: isRu ? 'Каталог' : 'Catalog',
              child: Icon(
                Icons.explore_rounded,
                size: 16,
                color: currentTab == ArtistsTab.all
                    ? (isDark ? Colors.white : theme.colorScheme.primary)
                    : (isDark ? Colors.white60 : const Color(0xFF64748B)),
              ),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: _Segment(
              selected: currentTab == ArtistsTab.favorites,
              selectedColor: isDark
                  ? Colors.amber.withValues(alpha: 0.25)
                  : Colors.white,
              selectedForeground:
                  isDark ? Colors.amber.shade300 : const Color(0xFFB45309),
              unselectedForeground:
                  isDark ? Colors.white70 : const Color(0xFF475569),
              onTap: () => onTabChanged(ArtistsTab.favorites),
              label: isRu ? 'Любимые' : 'Favorites',
              badge: favoritesCount > 0
                  ? Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: currentTab == ArtistsTab.favorites
                            ? Colors.amber.withValues(alpha: 0.3)
                            : (isDark
                                ? Colors.white.withValues(alpha: 0.12)
                                : Colors.black.withValues(alpha: 0.08)),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$favoritesCount',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: currentTab == ArtistsTab.favorites
                              ? (isDark
                                  ? Colors.amber.shade200
                                  : const Color(0xFF92400E))
                              : (isDark
                                  ? Colors.white70
                                  : const Color(0xFF475569)),
                        ),
                      ),
                    )
                  : null,
              child: Icon(
                Icons.star_rounded,
                size: 16,
                color: currentTab == ArtistsTab.favorites
                    ? Colors.amber
                    : (isDark ? Colors.white60 : const Color(0xFF64748B)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({
    required this.selected,
    required this.selectedColor,
    required this.selectedForeground,
    required this.unselectedForeground,
    required this.onTap,
    required this.child,
    required this.label,
    this.badge,
  });

  final bool selected;
  final Color selectedColor;
  final Color selectedForeground;
  final Color unselectedForeground;
  final VoidCallback onTap;
  final Widget child;
  final String label;
  final Widget? badge;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(11),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: selected ? selectedColor : Colors.transparent,
          borderRadius: BorderRadius.circular(11),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: Colors.black
                        .withValues(alpha: Theme.of(context).brightness ==
                                Brightness.dark
                            ? 0.25
                            : 0.08),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              child,
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected ? selectedForeground : unselectedForeground,
                ),
              ),
              if (badge != null) ...[
                const SizedBox(width: 5),
                badge!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}
