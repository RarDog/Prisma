import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:gel_rule_app/backend/backend.dart';

import 'artist_card.dart';
import 'artist_service_utils.dart';

/// Favorites tab content: responsive grid of favorite artist hero cards.
class ArtistsFavoritesView extends StatelessWidget {
  const ArtistsFavoritesView({
    super.key,
    required this.favorites,
    required this.scrollController,
    required this.onRemove,
  });

  final List<FavoriteArtistItem> favorites;
  final ScrollController scrollController;
  final ValueChanged<FavoriteArtistItem> onRemove;

  @override
  Widget build(BuildContext context) {
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
          // Same compact geometry as the catalog grid (104px cards).
          padding: EdgeInsets.fromLTRB(
            16,
            10,
            16,
            MediaQuery.paddingOf(context).bottom + 24,
          ),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            crossAxisSpacing: 12,
            mainAxisSpacing: 10,
            mainAxisExtent: 104,
          ),
          itemCount: favorites.length,
          itemBuilder: (context, index) {
            final fav = favorites[index];
            return RepaintBoundary(
              child: FavoriteArtistCard(
                item: fav,
                onRemove: () => onRemove(fav),
                onTap: () => context.push(
                  '/artists/${fav.providerId}/${fav.service}/${fav.id}?name=${Uri.encodeComponent(fav.name)}',
                ),
              ),
            );
          },
        );
      },
    );
  }
}
