import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:prisma_app/app/app_navigator.dart';
import 'package:prisma_app/app/responsive.dart';
import 'package:prisma_app/backend/backend.dart';
import 'package:prisma_app/shared/widgets/empty_view.dart';
import 'package:prisma_app/shared/widgets/post_masonry_grid.dart';
import '../favorites_controller.dart';

class FavoritesPostsGrid extends ConsumerWidget {
  const FavoritesPostsGrid({
    super.key,
    required this.posts,
    required this.settings,
    required this.downloadedKeys,
  });

  final List<Post> posts;
  final AppSettings settings;
  final Set<String> downloadedKeys;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (posts.isEmpty) return const EmptyView(title: 'Nothing here yet');
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return PostMasonryGrid(
      posts: posts,
      padding: EdgeInsets.fromLTRB(
        Responsive.isMobile(context) ? 8 : 16,
        Responsive.isMobile(context) ? 8 : 16,
        Responsive.isMobile(context) ? 8 : 16,
        150.0 + bottomInset,
      ),
      columns: Responsive.columnsFor(
        context,
        mobileColumns: settings.mobileColumns,
        desktopColumns: settings.desktopColumns,
      ),
      blurExplicit: settings.blurExplicitContent,
      showBadges: settings.showPostBadges,
      nsfwEnabled: settings.nsfwEnabled,
      mediaQualityMode: MediaQualityMode.fromName(settings.mediaQualityMode),
      favoriteKeys: posts.map((post) => post.cacheKey).toSet(),
      downloadedKeys: downloadedKeys,
      onOpen: (post) => AppNavigator.openPost(
        context,
        post: post,
        postsList: posts,
      ),
      onFavorite: (post) =>
          ref.read(favoritesControllerProvider.notifier).remove(post),
    );
  }
}
