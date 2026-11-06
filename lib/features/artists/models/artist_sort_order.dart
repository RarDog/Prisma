import 'package:flutter/material.dart';

enum ArtistSortOrder {
  popularityDesc,
  recentPosts,
  postsAsc,
  postsDesc,
  oldestPosts,
  nameAsc;

  String label(bool isRu) => switch (this) {
        ArtistSortOrder.popularityDesc => isRu ? 'По популярности' : 'Popularity',
        ArtistSortOrder.recentPosts => isRu ? 'Свежие посты' : 'Recent posts',
        ArtistSortOrder.postsAsc => isRu ? 'Меньше постов' : 'Least posts',
        ArtistSortOrder.postsDesc => isRu ? 'Больше постов' : 'Most posts',
        ArtistSortOrder.oldestPosts =>
          isRu ? 'Давно не обновлялись' : 'Oldest updates',
        ArtistSortOrder.nameAsc => isRu ? 'По имени' : 'By name',
      };

  IconData get icon => switch (this) {
        ArtistSortOrder.popularityDesc => Icons.trending_up_rounded,
        ArtistSortOrder.recentPosts => Icons.schedule_rounded,
        ArtistSortOrder.postsAsc => Icons.arrow_upward_rounded,
        ArtistSortOrder.postsDesc => Icons.arrow_downward_rounded,
        ArtistSortOrder.oldestPosts => Icons.history_rounded,
        ArtistSortOrder.nameAsc => Icons.sort_by_alpha_rounded,
      };
}
