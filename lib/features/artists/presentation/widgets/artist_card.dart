import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:gel_rule_app/backend/backend.dart';

import 'artist_service_utils.dart';
import 'artists_liquid_card.dart';

class ArtistCard extends StatelessWidget {
  const ArtistCard({
    super.key,
    required this.artist,
    required this.onTap,
    required this.isFavorite,
    required this.onToggleFavorite,
  });

  final ArtistProfile artist;
  final VoidCallback onTap;
  final bool isFavorite;
  final VoidCallback onToggleFavorite;

  @override
  Widget build(BuildContext context) {
    final isRu = Localizations.maybeLocaleOf(context)?.languageCode == 'ru';
    final badges = <Widget>[
      LiquidMiniBadge(
        label: artist.service.isEmpty ? 'Artist' : artist.service,
        color: artistServiceColor(artist.service),
        hasDot: true,
      ),
      if (artist.postCount != null)
        LiquidMiniBadge(
          label: '${artist.postCount} ${isRu ? 'постов' : 'posts'}',
          color: Theme.of(context).brightness == Brightness.dark
              ? Colors.white70
              : const Color(0xFF64748B),
        ),
    ];

    return _ArtistHeroCard(
      service: artist.service,
      name: artist.name,
      avatarUrl: artist.avatarUrl,
      badges: badges,
      updatedAt: artist.updatedAt,
      isRu: isRu,
      onTap: onTap,
      trailing: _FavoriteStarButton(
        active: isFavorite,
        onTap: onToggleFavorite,
      ),
    );
  }
}

class FavoriteArtistCard extends StatelessWidget {
  const FavoriteArtistCard({
    super.key,
    required this.item,
    required this.onTap,
    required this.onRemove,
  });

  final FavoriteArtistItem item;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final isRu = Localizations.maybeLocaleOf(context)?.languageCode == 'ru';
    final badges = <Widget>[
      LiquidMiniBadge(
        label: item.service.isEmpty
            ? 'Artist'
            : formatArtistServiceName(item.service),
        color: artistServiceColor(item.service),
        hasDot: true,
      ),
      LiquidMiniBadge(
        label: isRu ? 'В избранном' : 'Favorited',
        color: Colors.amber,
        hasDot: false,
      ),
    ];

    return _ArtistHeroCard(
      service: item.service,
      name: item.name,
      avatarUrl: item.avatarUrl,
      badges: badges,
      updatedAt: null,
      isRu: isRu,
      onTap: onTap,
      trailing: _FavoriteStarButton(
        active: true,
        onTap: onRemove,
      ),
    );
  }
}

/// Shared hero layout for catalog and favorite artist cards: large
/// service-tinted avatar, bold name, badge row and a floating star toggle
/// pinned to the top-right corner.
class _ArtistHeroCard extends StatelessWidget {
  const _ArtistHeroCard({
    required this.service,
    required this.name,
    required this.avatarUrl,
    required this.badges,
    required this.updatedAt,
    required this.isRu,
    required this.onTap,
    required this.trailing,
  });

  final String service;
  final String name;
  final String? avatarUrl;
  final List<Widget> badges;
  final DateTime? updatedAt;
  final bool isRu;
  final VoidCallback onTap;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final sColor = artistServiceColor(service);

    return ArtistsLiquidCard(
      glowColor: sColor.withValues(alpha: 0.40),
      padding: EdgeInsets.zero,
      onTap: onTap,
      child: Stack(
        children: [
          // Service-colored gradient wash behind the content
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    sColor.withValues(alpha: isDark ? 0.14 : 0.08),
                    sColor.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),
          // Right padding keeps the text clear of the floating star
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 52, 12),
            child: Row(
              children: [
                _HeroAvatar(
                  name: name,
                  avatarUrl: avatarUrl,
                  accent: sColor,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          fontSize: 15.5,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: badges,
                      ),
                      if (updatedAt != null) ...[
                        const SizedBox(height: 5),
                        _UpdatedLine(
                          updatedAt: updatedAt!,
                          accent: sColor,
                          isRu: isRu,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.chevron_right_rounded,
                  color: theme.colorScheme.onSurfaceVariant
                      .withValues(alpha: 0.6),
                  size: 22,
                ),
              ],
            ),
          ),
          Positioned(top: 6, right: 6, child: trailing),
        ],
      ),
    );
  }
}

class _HeroAvatar extends StatelessWidget {
  const _HeroAvatar({
    required this.name,
    required this.avatarUrl,
    required this.accent,
  });

  final String name;
  final String? avatarUrl;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final fallback = DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            accent.withValues(alpha: 0.90),
            theme.colorScheme.tertiaryContainer,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Text(
          name.trim().isEmpty
              ? '?'
              : name.trim().characters.first.toUpperCase(),
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
      ),
    );

    return Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.20)
              : Colors.white.withValues(alpha: 0.90),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.30),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: avatarUrl == null || avatarUrl!.isEmpty
            ? fallback
            : CachedNetworkImage(
                imageUrl: avatarUrl!,
                memCacheWidth: 200,
                memCacheHeight: 200,
                fit: BoxFit.cover,
                placeholder: (_, __) => fallback,
                errorWidget: (_, __, ___) => fallback,
              ),
      ),
    );
  }
}

class _UpdatedLine extends StatelessWidget {
  const _UpdatedLine({
    required this.updatedAt,
    required this.accent,
    required this.isRu,
  });

  final DateTime updatedAt;
  final Color accent;
  final bool isRu;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final local = updatedAt.toLocal();
    final fresh = DateTime.now().difference(local).inDays < 3;
    return Text(
      '${isRu ? 'Обновлено' : 'Updated'}: '
      '${formatArtistRelativeTime(local, isRu)}',
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: theme.textTheme.bodySmall?.copyWith(
        color: fresh
            ? accent.withValues(alpha: 0.95)
            : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
        fontSize: 11,
        fontWeight: fresh ? FontWeight.w600 : FontWeight.w400,
      ),
    );
  }
}

class _FavoriteStarButton extends StatelessWidget {
  const _FavoriteStarButton({
    required this.active,
    required this.onTap,
  });

  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final scheme = theme.colorScheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: active
                ? Colors.amber.withValues(alpha: isDark ? 0.22 : 0.15)
                : (isDark
                    ? Colors.white.withValues(alpha: 0.05)
                    : Colors.black.withValues(alpha: 0.03)),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: active
                  ? Colors.amber.withValues(alpha: 0.6)
                  : (isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : Colors.black.withValues(alpha: 0.06)),
            ),
            boxShadow: active
                ? [
                    BoxShadow(
                      color: Colors.amber.withValues(alpha: 0.35),
                      blurRadius: 10,
                    ),
                  ]
                : null,
          ),
          child: Icon(
            active ? Icons.star_rounded : Icons.star_outline_rounded,
            color: active ? Colors.amber : scheme.onSurfaceVariant,
            size: 22,
          ),
        ),
      ),
    );
  }
}

class ArtistAvatar extends StatelessWidget {
  const ArtistAvatar({
    super.key,
    required this.artist,
  });

  final ArtistProfile artist;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final name = artist.displayName.trim();
    final initials = name.isEmpty ? '?' : name.characters.first.toUpperCase();
    final accent = theme.colorScheme.primary;

    final fallback = DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            accent.withValues(alpha: 0.85),
            theme.colorScheme.tertiaryContainer,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Text(
          initials,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
      ),
    );

    return Container(
      width: 54,
      height: 54,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.20)
              : Colors.white.withValues(alpha: 0.90),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.22),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: artist.avatarUrl == null || artist.avatarUrl!.isEmpty
            ? fallback
            : CachedNetworkImage(
                imageUrl: artist.avatarUrl!,
                memCacheWidth: 140,
                memCacheHeight: 140,
                fit: BoxFit.cover,
                placeholder: (_, __) => fallback,
                errorWidget: (_, __, ___) => fallback,
              ),
      ),
    );
  }
}

class ArtistSkeletonCard extends StatelessWidget {
  const ArtistSkeletonCard({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final blockColor = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.black.withValues(alpha: 0.06);

    return ArtistsLiquidCard(
      padding: const EdgeInsets.fromLTRB(14, 12, 52, 12),
      child: Row(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: blockColor,
              borderRadius: BorderRadius.circular(20),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 150,
                  height: 16,
                  decoration: BoxDecoration(
                    color: blockColor,
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                const SizedBox(height: 9),
                Container(
                  width: 96,
                  height: 12,
                  decoration: BoxDecoration(
                    color: blockColor,
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                const SizedBox(height: 9),
                Container(
                  width: 128,
                  height: 11,
                  decoration: BoxDecoration(
                    color: blockColor,
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
