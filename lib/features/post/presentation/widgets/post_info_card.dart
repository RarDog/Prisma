import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:gel_rule_app/app/app_strings.dart';
import 'package:gel_rule_app/backend/backend.dart';
import 'package:gel_rule_app/shared/widgets/rating_badge.dart';
import 'package:gel_rule_app/sources/booru/e621_provider.dart';

class PostInfoCard extends StatefulWidget {
  const PostInfoCard({
    super.key,
    required this.post,
    required this.strings,
    this.localMedia,
    this.fileSizeBytes,
    this.e621Provider,
  });

  final Post post;
  final AppStrings strings;
  final DownloadedMedia? localMedia;
  final int? fileSizeBytes;
  final E621Provider? e621Provider;

  @override
  State<PostInfoCard> createState() => _PostInfoCardState();
}

class _PostInfoCardState extends State<PostInfoCard> {
  // Lazily resolved dimensions (used when post.width/height == 0).
  int? _resolvedWidth;
  int? _resolvedHeight;
  bool _resolvingDimensions = false;
  int? _votedScore;
  bool _isVoting = false;

  static final _dimensionCache = <String, (int, int)>{};

  static bool _isImageType(String fileType) {
    const imageTypes = {'image', 'jpeg', 'jpg', 'png', 'gif', 'webp', 'avif'};
    return imageTypes.contains(fileType.toLowerCase());
  }

  Future<void> _handleVote(int score) async {
    final provider = widget.e621Provider;
    if (provider == null) return;
    final isRu = Localizations.maybeLocaleOf(context)?.languageCode == 'ru';
    if (!provider.isAuthorized) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          content: Text(
            isRu
                ? 'Для голосования на e621 настройте API-ключ в Источниках'
                : 'To vote on e621, configure API key in Sources',
          ),
          duration: const Duration(seconds: 3),
        ),
      );
      return;
    }
    if (_isVoting) return;
    setState(() => _isVoting = true);
    final success = await provider.votePost(widget.post.id, score);
    if (mounted) {
      setState(() {
        _isVoting = false;
        if (success) {
          _votedScore = (_votedScore == score) ? 0 : score;
        }
      });
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          content: Text(
            success
                ? (score > 0
                    ? (isRu
                        ? 'Голос ЗА (+1) отправлен на e621!'
                        : 'Upvote (+1) sent to e621!')
                    : (isRu
                        ? 'Голос ПРОТИВ (-1) отправлен на e621!'
                        : 'Downvote (-1) sent to e621!'))
                : (isRu ? 'Не удалось отправить голос' : 'Failed to send vote'),
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    _maybeResolveDimensions();
  }

  @override
  void didUpdateWidget(PostInfoCard old) {
    super.didUpdateWidget(old);
    if (old.post.fileUrl != widget.post.fileUrl) {
      _resolvedWidth = null;
      _resolvedHeight = null;
      _resolvingDimensions = false;
      _maybeResolveDimensions();
    }
  }

  void _maybeResolveDimensions() {
    final post = widget.post;
    if (post.width != 0 || post.height != 0) return;
    if (!_isImageType(post.fileType)) return;
    final url = post.fileUrl.isNotEmpty ? post.fileUrl : post.sampleUrl;
    if (url.isEmpty) return;

    if (_dimensionCache.containsKey(url)) {
      final cached = _dimensionCache[url]!;
      _resolvedWidth = cached.$1;
      _resolvedHeight = cached.$2;
      return;
    }

    if (_resolvingDimensions) return;
    _resolvingDimensions = true;

    final imageProvider = NetworkImage(url);
    final completer = imageProvider.resolve(ImageConfiguration.empty);
    completer.addListener(
      ImageStreamListener(
        (info, _) {
          final w = info.image.width;
          final h = info.image.height;
          _dimensionCache[url] = (w, h);
          if (mounted) {
            setState(() {
              _resolvedWidth = w;
              _resolvedHeight = h;
              _resolvingDimensions = false;
            });
          }
        },
        onError: (_, __) {
          if (mounted) setState(() => _resolvingDimensions = false);
        },
      ),
    );
  }

  static ({String name, String queryTag})? extractArtist(Post post) {
    final rawArtists = post.tagGroups['artist'] ??
        post.tags
            .where((t) => t.startsWith('artist:') || t.startsWith('creator:'))
            .map((t) =>
                t.replaceFirst('artist:', '').replaceFirst('creator:', ''))
            .toList();
    if (rawArtists.isEmpty) return null;

    const nonArtistTags = {
      'conditional_dnp',
      'avoid_posting',
      'soundless',
      'third_party_edit',
      'unknown_artist',
      'anonymous_artist',
    };

    final realArtists = rawArtists
        .where((a) => !nonArtistTags.contains(a.toLowerCase()))
        .toList();
    final artistName =
        realArtists.isNotEmpty ? realArtists.first : rawArtists.first;
    if (nonArtistTags.contains(artistName.toLowerCase())) return null;

    final isE621 = post.providerId == 'e621' || post.providerId == 'e926';
    final queryTag = isE621 ? artistName : 'artist:$artistName';
    return (name: artistName, queryTag: queryTag);
  }

  @override
  Widget build(BuildContext context) {
    final post = widget.post;
    final strings = widget.strings;
    final localMedia = widget.localMedia;
    final fileSizeBytes = widget.fileSizeBytes;

    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final artistInfo = extractArtist(post);
    final displayArtistName = artistInfo?.name ??
        (post.tagGroups['artist']?.firstOrNull ??
            post.tags
                .where(
                    (t) => t.startsWith('artist:') || t.startsWith('creator:'))
                .map((t) =>
                    t.replaceFirst('artist:', '').replaceFirst('creator:', ''))
                .firstOrNull);

    final displayWidth = post.width != 0 ? post.width : _resolvedWidth;
    final displayHeight = post.height != 0 ? post.height : _resolvedHeight;
    final hasDimensions = displayWidth != null && displayHeight != null;
    final dimensionLabel = hasDimensions
        ? '$displayWidth × $displayHeight'
        : (_resolvingDimensions ? '… × …' : null);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.35),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [scheme.primaryContainer, scheme.tertiaryContainer],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Icon(
                    displayArtistName != null
                        ? Icons.palette_rounded
                        : Icons.hub_rounded,
                    size: 18,
                    color: scheme.onPrimaryContainer,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (displayArtistName != null &&
                        displayArtistName.isNotEmpty)
                      InkWell(
                        onTap: () {
                          final queryTag = artistInfo?.queryTag ??
                              ((post.providerId == 'e621' ||
                                      post.providerId == 'e926')
                                  ? displayArtistName
                                  : 'artist:$displayArtistName');
                          context.push(
                            '/search?q=${Uri.encodeComponent(queryTag)}',
                          );
                        },
                        borderRadius: BorderRadius.circular(6),
                        child: Text(
                          displayArtistName,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: scheme.primary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      )
                    else
                      Text(
                        strings.ru ? 'Автор не указан' : 'Unknown Artist',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Text(
                          post.providerName,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          ' • ',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.outline,
                          ),
                        ),
                        Text(
                          _formatPostDate(post.createdAt),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (localMedia != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.offline_pin_rounded,
                        size: 14,
                        color: scheme.onPrimaryContainer,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        fileSizeBytes != null && fileSizeBytes > 0
                            ? DownloadedMediaService.formatBytes(fileSizeBytes)
                            : (strings.ru ? 'Офлайн' : 'Offline'),
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: scheme.onPrimaryContainer,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (dimensionLabel != null)
                SpecBadge(
                  icon: Icons.aspect_ratio_rounded,
                  label: dimensionLabel,
                ),
              if (post.fileType.isNotEmpty)
                SpecBadge(
                  icon: Icons.insert_drive_file_outlined,
                  label: post.fileType.toUpperCase(),
                ),
              RatingBadge(rating: post.rating),
              if (post.score != 0 || widget.e621Provider != null)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SpecBadge(
                      icon: Icons.star_rounded,
                      label: '${post.score + (_votedScore ?? 0)}',
                      iconColor: Colors.amber,
                    ),
                    if (widget.e621Provider != null) ...[
                      const SizedBox(width: 4),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        constraints:
                            const BoxConstraints(minWidth: 28, minHeight: 28),
                        icon: Icon(
                          _votedScore == 1
                              ? Icons.thumb_up_rounded
                              : Icons.thumb_up_alt_outlined,
                          size: 15,
                          color: _votedScore == 1
                              ? const Color(0xFF10B981)
                              : scheme.onSurfaceVariant,
                        ),
                        onPressed: _isVoting ? null : () => _handleVote(1),
                        tooltip: strings.ru ? 'Голос ЗА (+1)' : 'Vote UP (+1)',
                      ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        constraints:
                            const BoxConstraints(minWidth: 28, minHeight: 28),
                        icon: Icon(
                          _votedScore == -1
                              ? Icons.thumb_down_rounded
                              : Icons.thumb_down_alt_outlined,
                          size: 15,
                          color: _votedScore == -1
                              ? const Color(0xFFEF4444)
                              : scheme.onSurfaceVariant,
                        ),
                        onPressed: _isVoting ? null : () => _handleVote(-1),
                        tooltip:
                            strings.ru ? 'Голос ПРОТИВ (-1)' : 'Vote DOWN (-1)',
                      ),
                    ],
                  ],
                ),
              if (post.favCount != null && post.favCount! > 0)
                SpecBadge(
                  icon: Icons.favorite_rounded,
                  label: '${post.favCount}',
                  iconColor: const Color(0xFFEF4444),
                ),
              if (post.source != null && post.source!.isNotEmpty)
                InkWell(
                  onTap: () => launchUrl(Uri.parse(post.source!)),
                  borderRadius: BorderRadius.circular(10),
                  child: SpecBadge(
                    icon: Icons.open_in_new_rounded,
                    label: strings.source,
                    color: scheme.surfaceContainerHigh,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

String _formatPostDate(DateTime date) {
  return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}

class SpecBadge extends StatelessWidget {
  const SpecBadge({
    super.key,
    required this.icon,
    required this.label,
    this.iconColor,
    this.color,
  });

  final IconData icon;
  final String label;
  final Color? iconColor;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color ?? scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: iconColor ?? scheme.onSurfaceVariant),
          const SizedBox(width: 5),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: scheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }
}
