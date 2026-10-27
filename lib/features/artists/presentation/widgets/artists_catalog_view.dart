import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:gel_rule_app/backend/backend.dart';

import 'artist_card.dart';
import 'artist_service_utils.dart';

/// Catalog tab content: artist grid with skeleton placeholders while
/// loading and a "no matches" state offering to clear platform filters.
class ArtistsCatalogView extends StatelessWidget {
  const ArtistsCatalogView({
    super.key,
    required this.artists,
    required this.favoriteKeys,
    required this.loading,
    required this.showFiltersEmptyState,
    required this.scrollController,
    required this.onToggleFavorite,
    required this.onShowAllServices,
  });

  final List<ArtistProfile> artists;
  final Set<String> favoriteKeys;
  final bool loading;
  final bool showFiltersEmptyState;
  final ScrollController scrollController;
  final ValueChanged<ArtistProfile> onToggleFavorite;
  final VoidCallback onShowAllServices;

  @override
  Widget build(BuildContext context) {
    if (showFiltersEmptyState) {
      final isRu =
          Localizations.maybeLocaleOf(context)?.languageCode == 'ru';
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.person_search_outlined, size: 48),
              const SizedBox(height: 12),
              Text(
                isRu
                    ? 'Нет авторов по выбранным фильтрам'
                    : 'No artists matching selected filters',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              FilledButton.tonal(
                onPressed: onShowAllServices,
                child: Text(
                  isRu ? 'Показать все сервисы' : 'Show all services',
                ),
              ),
            ],
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = artistGridColumns(context, constraints);
        return GridView.builder(
          controller: scrollController,
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          // ignore: deprecated_member_use
          cacheExtent: 140.0,
          addAutomaticKeepAlives: false,
          addRepaintBoundaries: true,
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: 12,
            mainAxisSpacing: 10,
            mainAxisExtent: 104,
          ),
          itemCount: artists.length + (loading ? 1 : 0),
          itemBuilder: (context, index) {
            if (index >= artists.length) {
              return const ArtistSkeletonCard();
            }
            final artist = artists[index];
            final isFav = favoriteKeys.contains(
                '${artist.providerId}:${artist.service}:${artist.id}');
            return RepaintBoundary(
              child: ArtistCard(
                artist: artist,
                isFavorite: isFav,
                onToggleFavorite: () => onToggleFavorite(artist),
                onTap: () => context.push(
                  '/artists/${artist.providerId}/${artist.service}/${artist.id}?name=${Uri.encodeComponent(artist.displayName)}',
                ),
              ),
            );
          },
        );
      },
    );
  }
}
