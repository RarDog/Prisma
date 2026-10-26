import 'package:flutter/material.dart';

/// Empty state for the Favorites tab: differentiates "nothing saved yet"
/// from "filters matched nothing" and offers the matching recovery action.
class ArtistsFavoritesEmpty extends StatelessWidget {
  const ArtistsFavoritesEmpty({
    super.key,
    required this.hasAnyFavorites,
    required this.hasActiveFilters,
    required this.isRu,
    required this.onBrowseCatalog,
    required this.onResetFilters,
  });

  final bool hasAnyFavorites;
  final bool hasActiveFilters;
  final bool isRu;
  final VoidCallback onBrowseCatalog;
  final VoidCallback onResetFilters;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              hasAnyFavorites
                  ? Icons.person_search_outlined
                  : Icons.star_border_rounded,
              size: 52,
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 14),
            Text(
              hasAnyFavorites
                  ? (isRu
                      ? 'Ничего не найдено в избранном'
                      : 'No favorites matching filter')
                  : (isRu
                      ? 'Список любимых авторов пуст'
                      : 'No favorite artists yet'),
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                hasAnyFavorites
                    ? (isRu
                        ? 'Попробуйте изменить поисковый запрос или сбросить фильтры по платформам.'
                        : 'Try clearing the search query or platform filters.')
                    : (isRu
                        ? 'Нажмите на звёздочку ★ на карточке любого автора в каталоге, чтобы быстро возвращаться к его работам.'
                        : 'Tap the star ★ icon on any artist in the catalog to add them to your favorites.'),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontSize: 13,
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (!hasAnyFavorites)
              FilledButton.tonalIcon(
                icon: const Icon(Icons.explore_rounded, size: 18),
                label: Text(isRu ? 'Перейти в каталог' : 'Browse catalog'),
                onPressed: onBrowseCatalog,
              )
            else if (hasActiveFilters)
              FilledButton.tonal(
                onPressed: onResetFilters,
                child: Text(isRu ? 'Сбросить фильтры' : 'Reset filters'),
              ),
          ],
        ),
      ),
    );
  }
}
