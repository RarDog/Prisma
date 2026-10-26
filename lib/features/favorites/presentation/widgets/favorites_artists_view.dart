import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import 'package:prisma_app/backend/backend.dart';
import 'favorites_liquid_card.dart';
import 'favorites_posts_grid.dart';

Map<String, List<Post>> favoriteArtistAlbums(List<Post> posts) {
  final groups = <String, List<Post>>{};
  for (final post in posts) {
    final artists = post.tagGroups['artist'] ??
        post.tags.where((tag) => tag.startsWith('artist:')).toList();
    final names = artists.isEmpty
        ? const ['Unknown artist']
        : artists.map((tag) => tag.replaceFirst('artist:', '')).toList();
    for (final name in names) {
      groups.putIfAbsent(name, () => []).add(post);
    }
  }
  return Map.fromEntries(
    groups.entries.toList()
      ..sort((a, b) => a.key.toLowerCase().compareTo(b.key.toLowerCase())),
  );
}

class FavoritesArtistsView extends StatefulWidget {
  const FavoritesArtistsView({
    super.key,
    required this.posts,
    required this.settings,
    required this.downloadedKeys,
    required this.isRu,
    required this.searchQuery,
    required this.filterPosts,
    this.selectedArtist,
    this.onArtistSelected,
  });

  final List<Post> posts;
  final AppSettings settings;
  final Set<String> downloadedKeys;
  final bool isRu;
  final String searchQuery;
  final List<Post> Function(List<Post> posts) filterPosts;
  final String? selectedArtist;
  final ValueChanged<String?>? onArtistSelected;

  @override
  State<FavoritesArtistsView> createState() => _FavoritesArtistsViewState();
}

class _FavoritesArtistsViewState extends State<FavoritesArtistsView> {
  String? _internalSelectedArtist;

  String? get _selectedArtist =>
      widget.selectedArtist ?? _internalSelectedArtist;

  void _selectArtist(String? artist) {
    setState(() => _internalSelectedArtist = artist);
    widget.onArtistSelected?.call(artist);
  }

  @override
  Widget build(BuildContext context) {
    final posts = widget.posts;
    final settings = widget.settings;
    final downloadedKeys = widget.downloadedKeys;
    final isRu = widget.isRu;

    final groups = favoriteArtistAlbums(posts);
    final selected = _selectedArtist;

    if (selected != null) {
      final artistPosts = groups[selected] ?? const [];
      final filtered = widget.filterPosts(artistPosts);

      return Column(
        children: [
          // Artist Header Banner (Liquid Glass)
          FavoritesLiquidCard(
            margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                IconButton(
                  onPressed: () {
                    HapticFeedback.selectionClick();
                    _selectArtist(null);
                  },
                  icon: const Icon(Icons.arrow_back_rounded),
                  tooltip: isRu ? 'Все авторы' : 'All artists',
                ),
                const SizedBox(width: 8),
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Theme.of(context).colorScheme.primary,
                        Theme.of(context).colorScheme.tertiary,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Theme.of(context)
                            .colorScheme
                            .primary
                            .withValues(alpha: 0.35),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      selected.isNotEmpty ? selected[0].toUpperCase() : '?',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        selected,
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: -0.2,
                                  ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        '${artistPosts.length} ${isRu ? 'работ' : 'posts'}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                      ),
                    ],
                  ),
                ),
                FilledButton.tonalIcon(
                  style: FilledButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                  ),
                  onPressed: () {
                    HapticFeedback.selectionClick();
                    context.push(
                        '/search?q=${Uri.encodeComponent('artist:$selected')}');
                  },
                  icon: const Icon(Icons.search_rounded, size: 16),
                  label: Text(isRu ? 'В сети' : 'Search'),
                ),
              ],
            ),
          ),
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Text(isRu ? 'Ничего не найдено' : 'No posts found'),
                  )
                : FavoritesPostsGrid(
                    posts: filtered,
                    settings: settings,
                    downloadedKeys: downloadedKeys,
                  ),
          ),
        ],
      );
    }

    final query = widget.searchQuery.toLowerCase();
    final entries = groups.entries.where((e) {
      if (query.isEmpty) return true;
      return e.key.toLowerCase().contains(query);
    }).toList();

    if (entries.isEmpty) {
      return Center(
        child: Text(isRu ? 'Авторы не найдены' : 'No artists found'),
      );
    }

    return ListView.separated(
      // ignore: deprecated_member_use
      cacheExtent: 140.0,
      addAutomaticKeepAlives: false,
      addRepaintBoundaries: true,
      // Extended bottom padding so the last artist cards scroll comfortably above the floating dock
      padding: EdgeInsets.fromLTRB(
          16, 8, 16, 140 + MediaQuery.paddingOf(context).bottom),
      itemCount: entries.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final entry = entries[index];
        final artistPosts = entry.value;
        final previewUrls = artistPosts
            .map((p) => MediaUrlSelector.preview(p).firstOrNull)
            .whereType<String>()
            .take(3)
            .toList();

        return RepaintBoundary(
          child: ArtistCard(
            artistName: entry.key,
            postsCount: artistPosts.length,
            previewUrls: previewUrls,
            isRu: isRu,
            onTap: () => _selectArtist(entry.key),
          ),
        );
      },
    );
  }
}

class ArtistCard extends StatelessWidget {
  const ArtistCard({
    super.key,
    required this.artistName,
    required this.postsCount,
    required this.previewUrls,
    required this.isRu,
    required this.onTap,
  });

  final String artistName;
  final int postsCount;
  final List<String> previewUrls;
  final bool isRu;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.28)
                : scheme.primary.withValues(alpha: 0.06),
            blurRadius: 14,
            offset: const Offset(0, 4),
            spreadRadius: -2,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(22),
              onTap: () {
                HapticFeedback.selectionClick();
                onTap();
              },
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(22),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: isDark
                        ? [
                            scheme.surfaceContainerHigh.withValues(alpha: 0.58),
                            scheme.surfaceContainerLow.withValues(alpha: 0.36),
                          ]
                        : [
                            Colors.white.withValues(alpha: 0.88),
                            Colors.white.withValues(alpha: 0.72),
                          ],
                  ),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.13)
                        : Colors.white.withValues(alpha: 0.85),
                    width: 1.1,
                  ),
                ),
                child: Row(
                  children: [
                    // Artist Squircle Avatar
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            scheme.primary,
                            scheme.tertiary,
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(15),
                        boxShadow: [
                          BoxShadow(
                            color: scheme.primary.withValues(alpha: 0.35),
                            blurRadius: 8,
                            offset: const Offset(0, 2.5),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          artistName.isNotEmpty
                              ? artistName[0].toUpperCase()
                              : '?',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Artist Name & Count
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            artistName,
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: -0.2,
                                ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 3),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: scheme.primary.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '$postsCount ${isRu ? 'работ' : 'posts'}',
                              style: Theme.of(context)
                                  .textTheme
                                  .labelSmall
                                  ?.copyWith(
                                    color: scheme.primary,
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Thumbnails preview
                    if (previewUrls.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Row(
                        children: [
                          for (final url in previewUrls)
                            Padding(
                              padding: const EdgeInsets.only(left: 5),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color: isDark
                                          ? Colors.white.withValues(alpha: 0.10)
                                          : scheme.outlineVariant
                                              .withValues(alpha: 0.25),
                                    ),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: CachedNetworkImage(
                                    imageUrl: url,
                                    memCacheWidth: 128,
                                    memCacheHeight: 128,
                                    fit: BoxFit.cover,
                                    placeholder: (_, __) => Container(
                                      color: scheme.surfaceContainerHighest,
                                    ),
                                    errorWidget: (_, __, ___) => Container(
                                      color: scheme.surfaceContainerHighest,
                                      child: const Icon(
                                        Icons.image_not_supported_rounded,
                                        size: 16,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                    const SizedBox(width: 4),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 20,
                      color: scheme.onSurfaceVariant.withValues(alpha: 0.5),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
