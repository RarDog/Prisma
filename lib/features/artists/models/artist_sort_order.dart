import 'package:flutter/material.dart';

enum ArtistSortOrder {
  popularityDesc,
  recentPosts,
  postsAsc,
  postsDesc,
  oldestPosts,
  nameAsc,
  topFollowers,
  trending,
  dailyRanking;

  static List<ArtistSortOrder> supportedFor(String? providerId) {
    if (providerId == 'fapello') {
      return const [
        ArtistSortOrder.popularityDesc,
        ArtistSortOrder.topFollowers,
        ArtistSortOrder.trending,
        ArtistSortOrder.dailyRanking,
      ];
    }
    return const [
      ArtistSortOrder.popularityDesc,
      ArtistSortOrder.recentPosts,
      ArtistSortOrder.postsDesc,
      ArtistSortOrder.postsAsc,
      ArtistSortOrder.oldestPosts,
      ArtistSortOrder.nameAsc,
    ];
  }

  String label(bool isRu, {String? providerId}) {
    if (providerId == 'fapello') {
      return switch (this) {
        ArtistSortOrder.popularityDesc => isRu ? 'Топ по лайкам' : 'Top Likes',
        ArtistSortOrder.topFollowers =>
          isRu ? 'Топ по подписчикам' : 'Top Followers',
        ArtistSortOrder.trending => isRu ? 'В тренде' : 'Trending',
        ArtistSortOrder.dailyRanking => isRu ? 'Топ за день' : 'Daily Top',
        _ => label(isRu),
      };
    }
    return switch (this) {
      ArtistSortOrder.popularityDesc => isRu ? 'По популярности' : 'Popularity',
      ArtistSortOrder.recentPosts => isRu ? 'Свежие посты' : 'Recent posts',
      ArtistSortOrder.postsAsc => isRu ? 'Меньше постов' : 'Least posts',
      ArtistSortOrder.postsDesc => isRu ? 'Больше постов' : 'Most posts',
      ArtistSortOrder.oldestPosts =>
        isRu ? 'Давно не обновлялись' : 'Oldest updates',
      ArtistSortOrder.nameAsc => isRu ? 'По имени' : 'By name',
      ArtistSortOrder.topFollowers =>
        isRu ? 'Топ по подписчикам' : 'Top Followers',
      ArtistSortOrder.trending => isRu ? 'В тренде' : 'Trending',
      ArtistSortOrder.dailyRanking => isRu ? 'Топ за день' : 'Daily Top',
    };
  }

  IconData iconFor(String? providerId) {
    if (providerId == 'fapello' && this == ArtistSortOrder.popularityDesc) {
      return Icons.favorite_rounded;
    }
    return icon;
  }

  IconData get icon => switch (this) {
        ArtistSortOrder.popularityDesc => Icons.trending_up_rounded,
        ArtistSortOrder.recentPosts => Icons.schedule_rounded,
        ArtistSortOrder.postsAsc => Icons.arrow_upward_rounded,
        ArtistSortOrder.postsDesc => Icons.arrow_downward_rounded,
        ArtistSortOrder.oldestPosts => Icons.history_rounded,
        ArtistSortOrder.nameAsc => Icons.sort_by_alpha_rounded,
        ArtistSortOrder.topFollowers => Icons.people_alt_rounded,
        ArtistSortOrder.trending => Icons.local_fire_department_rounded,
        ArtistSortOrder.dailyRanking => Icons.today_rounded,
      };
}
