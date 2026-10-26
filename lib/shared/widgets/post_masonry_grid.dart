import 'dart:async';
import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';

import 'package:prisma_app/app/responsive.dart';
import 'package:prisma_app/backend/backend.dart';
import 'package:prisma_app/features/post/presentation/widgets/post_media_viewer.dart';
import 'loading_skeleton.dart';
import 'post_card.dart';

class PostMasonryGrid extends StatelessWidget {
  const PostMasonryGrid({
    required this.posts,
    required this.columns,
    required this.blurExplicit,
    required this.showBadges,
    required this.nsfwEnabled,
    required this.mediaQualityMode,
    required this.onOpen,
    required this.onFavorite,
    this.onAddToCollection,
    this.onPreview,
    this.onHide,
    this.onToggleSelected,
    this.selectionMode = false,
    this.selectedKeys = const {},
    this.favoriteKeys = const {},
    this.viewedKeys = const {},
    this.downloadedKeys = const {},
    this.loading = false,
    this.controller,
    this.gridMode = 'masonry',
    this.padding,
    super.key,
  });

  final List<Post> posts;
  final int columns;
  final bool blurExplicit;
  final bool showBadges;
  final bool nsfwEnabled;
  final MediaQualityMode mediaQualityMode;
  final ValueChanged<Post> onOpen;
  final ValueChanged<Post> onFavorite;
  final ValueChanged<Post>? onAddToCollection;
  final ValueChanged<Post>? onPreview;
  final ValueChanged<Post>? onHide;
  final ValueChanged<Post>? onToggleSelected;
  final bool selectionMode;
  final Set<String> selectedKeys;
  final Set<String> favoriteKeys;
  final Set<String> viewedKeys;
  final Set<String> downloadedKeys;
  final bool loading;
  final ScrollController? controller;
  final String gridMode;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final mobile = Responsive.isMobile(context);
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final pad = padding ??
        EdgeInsets.fromLTRB(
          mobile ? 8 : 16,
          mobile ? 8 : 16,
          mobile ? 8 : 16,
          (mobile ? 8 : 16) + (mobile ? (120.0 + bottomInset) : 0.0),
        );
    final spacing = mobile ? 8.0 : 12.0;

    Widget buildCard(Post post, {bool forceSquare = false}) {
      return RepaintBoundary(
        child: PostCard(
          post: post,
          blurExplicit: blurExplicit && !nsfwEnabled,
          showBadges: showBadges,
          isFavorite: favoriteKeys.contains(post.cacheKey),
          isViewed: viewedKeys.contains(post.cacheKey),
          isDownloaded: downloadedKeys.contains(post.cacheKey),
          mediaQualityMode: mediaQualityMode,
          onOpen: () => onOpen(post),
          onFavorite: () => onFavorite(post),
          onPreview: onPreview == null ? null : () => onPreview!(post),
          onHide: onHide == null ? null : () => onHide!(post),
          selectionMode: selectionMode,
          selected: selectedKeys.contains(post.cacheKey),
          forceSquare: forceSquare,
          onToggleSelected:
              onToggleSelected == null ? null : () => onToggleSelected!(post),
          onAddToCollection:
              onAddToCollection == null ? null : () => onAddToCollection!(post),
        ),
      );
    }

    if (gridMode == 'grid') {
      // Uniform square grid
      return GridView.builder(
        controller: controller,
        padding: pad,
        // ignore: deprecated_member_use
        cacheExtent: 800.0,
        addAutomaticKeepAlives: false,
        addRepaintBoundaries: true,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: columns,
          mainAxisSpacing: spacing,
          crossAxisSpacing: spacing,
          childAspectRatio: 1.0,
        ),
        itemCount: posts.length + (loading ? columns : 0),
        itemBuilder: (context, index) {
          if (index >= posts.length) return const LoadingSkeleton();
          _maybePrecacheAhead(context, index, mobile);
          return buildCard(posts[index], forceSquare: true);
        },
      );
    }

    if (gridMode == 'list') {
      // Vertical list with larger cards
      return ListView.separated(
        controller: controller,
        padding: pad,
        // ignore: deprecated_member_use
        cacheExtent: 800.0,
        addAutomaticKeepAlives: false,
        addRepaintBoundaries: true,
        separatorBuilder: (_, __) => SizedBox(height: spacing),
        itemCount: posts.length + (loading ? 3 : 0),
        itemBuilder: (context, index) {
          if (index >= posts.length) return const LoadingSkeleton();
          _maybePrecacheAhead(context, index, mobile);
          return buildCard(posts[index]);
        },
      );
    }

    // Default: masonry
    return MasonryGridView.count(
      controller: controller,
      padding: pad,
      cacheExtent: 800.0,
      addAutomaticKeepAlives: false,
      addRepaintBoundaries: true,
      crossAxisCount: columns,
      mainAxisSpacing: spacing,
      crossAxisSpacing: spacing,
      itemCount: posts.length + (loading ? columns : 0),
      itemBuilder: (context, index) {
        if (index >= posts.length) return const LoadingSkeleton();
        _maybePrecacheAhead(context, index, mobile);
        return buildCard(posts[index]);
      },
    );
  }

  static final Set<String> _precachedUrls = {};

  void _maybePrecacheAhead(
    BuildContext context,
    int currentIndex,
    bool mobile,
  ) {
    if (posts.isEmpty) return;
    const lookahead = 4;
    final maxIdx = math.min(currentIndex + lookahead, posts.length - 1);
    for (int i = currentIndex + 1; i <= maxIdx; i++) {
      final post = posts[i];
      if (post.fileType == 'text' || post.fileType == 'audio') continue;
      final urls = MediaUrlSelector.feed(
        post,
        mode: mediaQualityMode,
        mobile: mobile,
      );
      final url = urls.firstOrNull;
      if (url == null || url.trim().isEmpty) continue;
      if (_precachedUrls.contains(url)) continue;
      if (_precachedUrls.length >= 600) {
        _precachedUrls.remove(_precachedUrls.first);
      }
      _precachedUrls.add(url);
      final headers = getPostMediaHeaders(post);
      final provider = CachedNetworkImageProvider(url, headers: headers);
      unawaited(
        precacheImage(
          provider,
          context,
          onError: (_, __) {},
        ),
      );
    }
  }
}
