import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shimmer/shimmer.dart';

import 'package:gel_rule_app/core/models/post.dart';
import 'package:gel_rule_app/features/post/presentation/widgets/post_media_viewer.dart';

class MangaCard extends StatefulWidget {
  const MangaCard({
    required this.post,
    required this.onTap,
    super.key,
  });

  final Post post;
  final VoidCallback onTap;

  @override
  State<MangaCard> createState() => _MangaCardState();
}

class _MangaCardState extends State<MangaCard> {
  bool _isHovered = false;
  bool _isPressed = false;
  int _urlIndex = 0;

  @override
  void didUpdateWidget(covariant MangaCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.post.id != widget.post.id) {
      _urlIndex = 0;
    }
  }

  List<String> get _candidateUrls {
    final list = <String>[];
    if (widget.post.sampleUrl.isNotEmpty) list.add(widget.post.sampleUrl);
    if (widget.post.previewUrl.isNotEmpty) list.add(widget.post.previewUrl);
    if (widget.post.fileUrl.isNotEmpty) list.add(widget.post.fileUrl);
    return list.toSet().toList();
  }

  Widget _buildPlaceholder(bool isDark) {
    return Container(
      color: isDark ? const Color(0xFF1C1E24) : const Color(0xFFEDEDED),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.menu_book_rounded,
              size: 32,
              color: isDark ? Colors.white38 : Colors.black26,
            ),
            const SizedBox(height: 4),
            Text(
              'Manga',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white30 : Colors.black26,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCoverImage(bool isDark, Map<String, String> headers) {
    final candidates = _candidateUrls;
    if (candidates.isEmpty) {
      return _buildPlaceholder(isDark);
    }

    final currentUrl =
        _urlIndex < candidates.length ? candidates[_urlIndex] : candidates.first;

    return CachedNetworkImage(
      imageUrl: currentUrl,
      cacheKey: 'v3_${widget.post.id}_$currentUrl',
      httpHeaders: headers,
      fit: BoxFit.cover,
      placeholder: (_, __) => Shimmer.fromColors(
        baseColor:
            isDark ? const Color(0xFF1E2128) : const Color(0xFFE5E7EB),
        highlightColor:
            isDark ? const Color(0xFF2E333D) : const Color(0xFFF3F4F6),
        child: Container(
          color: isDark ? const Color(0xFF1E2128) : const Color(0xFFE5E7EB),
        ),
      ),
      errorWidget: (_, __, ___) {
        if (_urlIndex + 1 < candidates.length) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) setState(() => _urlIndex++);
          });
          return Shimmer.fromColors(
            baseColor:
                isDark ? const Color(0xFF1E2128) : const Color(0xFFE5E7EB),
            highlightColor:
                isDark ? const Color(0xFF2E333D) : const Color(0xFFF3F4F6),
            child: Container(
              color:
                  isDark ? const Color(0xFF1E2128) : const Color(0xFFE5E7EB),
            ),
          );
        }
        return Image.network(
          candidates.first,
          headers: headers,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _buildPlaceholder(isDark),
        );
      },
    );
  }

  Color _ratingColor(String? rating) {
    return switch (rating?.toLowerCase()) {
      'safe' => const Color(0xFF10B981),
      'suggestive' => const Color(0xFFF59E0B),
      'erotica' => const Color(0xFFFF7043),
      'pornographic' => const Color(0xFFEF4444),
      _ => const Color(0xFFFF6740),
    };
  }

  String _ratingLabel(String? rating) {
    return switch (rating?.toLowerCase()) {
      'safe' => 'Safe',
      'suggestive' => '12+',
      'erotica' => '16+',
      'pornographic' => '18+',
      _ => '',
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final headers = getPostMediaHeaders(widget.post);

    final title = widget.post.title ?? widget.post.tags.take(3).join(', ');
    final artist = widget.post.tagGroups['artist']?.firstOrNull ??
        widget.post.tagGroups['author']?.firstOrNull;
    final pageCount = widget.post.tagGroups['page_count']?.firstOrNull ??
        (widget.post.childrenIds.isNotEmpty
            ? '${widget.post.childrenIds.length}'
            : null);
    final language = widget.post.tagGroups['language']?.firstOrNull;
    final rating = widget.post.tagGroups['content_rating']?.firstOrNull;
    final hasWarningRating =
        rating != null && rating.toLowerCase() != 'safe';

    final scale = _isPressed ? 0.96 : (_isHovered ? 1.03 : 1.0);

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) => setState(() => _isPressed = false),
        onTapCancel: () => setState(() => _isPressed = false),
        onTap: () {
          HapticFeedback.lightImpact();
          widget.onTap();
        },
        child: AnimatedScale(
          scale: scale,
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOutCubic,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(8),
                bottomLeft: Radius.circular(8),
                topRight: Radius.circular(16),
                bottomRight: Radius.circular(16),
              ),
              border: Border.all(
                color: _isHovered
                    ? const Color(0xFFFF6740).withValues(alpha: 0.6)
                    : (isDark
                        ? Colors.white.withValues(alpha: 0.12)
                        : Colors.black.withValues(alpha: 0.08)),
                width: _isHovered ? 1.4 : 0.8,
              ),
              color: isDark
                  ? const Color(0xFF16181D)
                  : Colors.white,
              boxShadow: [
                BoxShadow(
                  color: _isHovered
                      ? const Color(0xFFFF6740).withValues(alpha: isDark ? 0.35 : 0.20)
                      : Colors.black.withValues(alpha: isDark ? 0.35 : 0.08),
                  blurRadius: _isHovered ? 18 : 10,
                  offset: Offset(0, _isHovered ? 8 : 4),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Cover Image with 3D spine and top badges
                Expanded(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      _buildCoverImage(isDark, headers),

                      // Elegant 3D Book Spine Shadow on left
                      Positioned(
                        left: 0,
                        top: 0,
                        bottom: 0,
                        width: 12,
                        child: IgnorePointer(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                                colors: [
                                  Colors.black.withValues(alpha: 0.45),
                                  Colors.white.withValues(alpha: 0.10),
                                  Colors.transparent,
                                ],
                                stops: const [0.0, 0.35, 1.0],
                              ),
                            ),
                          ),
                        ),
                      ),

                      // Soft Bottom Scrim Gradient
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        height: 44,
                        child: IgnorePointer(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.bottomCenter,
                                end: Alignment.topCenter,
                                colors: [
                                  Colors.black.withValues(alpha: 0.65),
                                  Colors.transparent,
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),

                      // Badges overlay
                      Positioned(
                        top: 8,
                        left: 8,
                        right: 8,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            if (pageCount != null)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 7,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.68),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.15),
                                    width: 0.6,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.layers_rounded,
                                      color: Colors.white,
                                      size: 11,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${pageCount}P',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            else if (hasWarningRating)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 7,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: _ratingColor(rating).withValues(alpha: 0.88),
                                  borderRadius: BorderRadius.circular(8),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.3),
                                      blurRadius: 4,
                                    ),
                                  ],
                                ),
                                child: Text(
                                  _ratingLabel(rating),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.2,
                                  ),
                                ),
                              )
                            else
                              const SizedBox.shrink(),

                            if (language != null)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2.5,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFED2553).withValues(alpha: 0.85),
                                  borderRadius: BorderRadius.circular(7),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.2),
                                    width: 0.6,
                                  ),
                                ),
                                child: Text(
                                  language.toUpperCase(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Title & Author details
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          height: 1.25,
                        ),
                      ),
                      if (artist != null && artist.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          artist,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
