import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

enum MangaTab {
  catalog,
  library,
}

class MangaScreenAppBar extends StatelessWidget implements PreferredSizeWidget {
  const MangaScreenAppBar({
    super.key,
    required this.selectedTab,
    required this.onTabChanged,
    required this.selectedRating,
    required this.onToggleRating,
    required this.onRefreshCatalog,
  });

  final MangaTab selectedTab;
  final ValueChanged<MangaTab> onTabChanged;
  final String selectedRating;
  final VoidCallback onToggleRating;
  final VoidCallback onRefreshCatalog;

  @override
  Size get preferredSize => const Size.fromHeight(60);

  Color _ratingColor(String rating, ThemeData theme) {
    return switch (rating.toLowerCase()) {
      'safe' => const Color(0xFF10B981),
      'suggestive' => const Color(0xFFF59E0B),
      'erotica' => const Color(0xFFFF7043),
      'pornographic' => const Color(0xFFEF4444),
      _ => theme.colorScheme.primary,
    };
  }

  IconData _ratingIcon(String rating) {
    return switch (rating.toLowerCase()) {
      'safe' => Icons.shield_rounded,
      'suggestive' => Icons.visibility_rounded,
      'erotica' => Icons.explicit_rounded,
      'pornographic' => Icons.eighteen_up_rating_rounded,
      _ => Icons.tune_rounded,
    };
  }

  String _ratingLabel(String rating, bool isRu) {
    return switch (rating.toLowerCase()) {
      'safe' => 'Safe',
      'suggestive' => '12+',
      'erotica' => '16+',
      'pornographic' => '18+',
      _ => isRu ? 'Все' : 'All',
    };
  }

  Widget _tabButton({
    required String title,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          gradient: isSelected
              ? const LinearGradient(
                  colors: [Color(0xFFFF6740), Color(0xFFFF5252)],
                )
              : null,
          borderRadius: BorderRadius.circular(18),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFFFF6740).withValues(alpha: 0.35),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 15,
              color: isSelected
                  ? Colors.white
                  : (isDark ? Colors.white60 : Colors.black54),
            ),
            const SizedBox(width: 6),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                color: isSelected
                    ? Colors.white
                    : (isDark ? Colors.white70 : Colors.black87),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isRu = Localizations.maybeLocaleOf(context)?.languageCode == 'ru';
    final rColor = _ratingColor(selectedRating, theme);

    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: AppBar(
          backgroundColor: isDark
              ? Colors.black.withValues(alpha: 0.65)
              : Colors.white.withValues(alpha: 0.75),
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          titleSpacing: 16,
          title: Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.black.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.12)
                    : Colors.black.withValues(alpha: 0.08),
                width: 0.8,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _tabButton(
                  title: isRu ? 'Каталог' : 'Catalog',
                  icon: Icons.explore_rounded,
                  isSelected: selectedTab == MangaTab.catalog,
                  isDark: isDark,
                  onTap: () {
                    HapticFeedback.lightImpact();
                    onTabChanged(MangaTab.catalog);
                  },
                ),
                _tabButton(
                  title: isRu ? 'Библиотека' : 'Library',
                  icon: Icons.bookmarks_rounded,
                  isSelected: selectedTab == MangaTab.library,
                  isDark: isDark,
                  onTap: () {
                    HapticFeedback.lightImpact();
                    onTabChanged(MangaTab.library);
                  },
                ),
              ],
            ),
          ),
          actions: [
            if (selectedTab == MangaTab.catalog) ...[
              Center(
                child: InkWell(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    onToggleRating();
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: rColor.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: selectedRating.toLowerCase() == 'all'
                            ? (isDark ? Colors.white24 : Colors.black12)
                            : rColor.withValues(alpha: 0.75),
                        width: 1.0,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _ratingIcon(selectedRating),
                          size: 13,
                          color: rColor,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _ratingLabel(selectedRating, isRu),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: rColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              IconButton(
                icon: const Icon(Icons.refresh_rounded, size: 20),
                tooltip: isRu ? 'Обновить' : 'Refresh',
                onPressed: () {
                  HapticFeedback.lightImpact();
                  onRefreshCatalog();
                },
              ),
            ],
            const SizedBox(width: 6),
          ],
        ),
      ),
    );
  }
}
