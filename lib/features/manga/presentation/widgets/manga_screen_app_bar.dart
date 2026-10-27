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
      'erotica' => const Color(0xFFEF4444),
      'pornographic' => const Color(0xFFDC2626),
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

  Widget _tabButton({
    required String title,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFFF6740) : Colors.transparent,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 15,
              color: isSelected ? Colors.white : Colors.white70,
            ),
            const SizedBox(width: 6),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                color: isSelected ? Colors.white : Colors.white70,
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

    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: AppBar(
          backgroundColor: isDark
              ? theme.colorScheme.surface.withValues(alpha: 0.75)
              : Colors.white.withValues(alpha: 0.85),
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white10
                      : Colors.black.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _tabButton(
                      title: isRu ? 'Каталог' : 'Catalog',
                      icon: Icons.explore_rounded,
                      isSelected: selectedTab == MangaTab.catalog,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        onTabChanged(MangaTab.catalog);
                      },
                    ),
                    _tabButton(
                      title: isRu ? 'Библиотека' : 'Library',
                      icon: Icons.bookmarks_rounded,
                      isSelected: selectedTab == MangaTab.library,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        onTabChanged(MangaTab.library);
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            if (selectedTab == MangaTab.catalog) ...[
              Center(
                child: InkWell(
                  onTap: onToggleRating,
                  borderRadius: BorderRadius.circular(16),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                    decoration: BoxDecoration(
                      color: _ratingColor(selectedRating, theme)
                          .withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: selectedRating == 'All'
                            ? (isDark ? Colors.white24 : Colors.black12)
                            : _ratingColor(selectedRating, theme)
                                .withValues(alpha: 0.8),
                        width: 1.2,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _ratingIcon(selectedRating),
                          size: 13,
                          color: _ratingColor(selectedRating, theme),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          selectedRating == 'All'
                              ? (isRu ? 'Все' : 'All')
                              : selectedRating,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: selectedRating == 'All'
                                ? theme.colorScheme.onSurfaceVariant
                                : _ratingColor(selectedRating, theme),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.refresh_rounded, size: 20),
                tooltip: isRu ? 'Обновить' : 'Refresh',
                onPressed: onRefreshCatalog,
              ),
            ],
            const SizedBox(width: 4),
          ],
        ),
      ),
    );
  }
}
