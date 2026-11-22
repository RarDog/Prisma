import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shimmer/shimmer.dart';

import 'package:gel_rule_app/features/manga/domain/manga_library_service.dart';
import 'package:gel_rule_app/features/post/presentation/widgets/post_media_viewer.dart';

class MangaLibraryCard extends StatefulWidget {
  const MangaLibraryCard({
    required this.entry,
    required this.onTap,
    this.onLongPress,
    super.key,
  });

  final MangaLibraryEntry entry;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  @override
  State<MangaLibraryCard> createState() => _MangaLibraryCardState();
}

class _MangaLibraryCardState extends State<MangaLibraryCard> {
  bool _isHovered = false;
  bool _isPressed = false;

  Color _statusColor(String status) {
    return switch (status) {
      'reading' => const Color(0xFFFF6740),
      'plan_to_read' => const Color(0xFF3B82F6),
      'completed' => const Color(0xFF10B981),
      'dropped' => const Color(0xFFEF4444),
      _ => const Color(0xFFFF6740),
    };
  }

  String _statusLabel(String status, bool isRu) {
    return switch (status) {
      'reading' => isRu ? 'Читаю' : 'Reading',
      'plan_to_read' => isRu ? 'В планах' : 'Plan',
      'completed' => isRu ? 'Прочитано' : 'Done',
      'dropped' => isRu ? 'Брошено' : 'Dropped',
      _ => '',
    };
  }

  Widget _buildPlaceholder(bool isDark) {
    return Container(
      color: isDark ? const Color(0xFF1C1E24) : const Color(0xFFEDEDED),
      child: Center(
        child: Icon(
          Icons.auto_stories_rounded,
          size: 32,
          color: isDark ? Colors.white30 : Colors.black26,
        ),
      ),
    );
  }

  Widget _buildCoverImage(bool isDark, Map<String, String> headers) {
    if (widget.entry.coverUrl.isEmpty) {
      return _buildPlaceholder(isDark);
    }
    return CachedNetworkImage(
      imageUrl: widget.entry.coverUrl,
      cacheKey: 'v3_${widget.entry.mangaId}_${widget.entry.coverUrl}',
      httpHeaders: headers,
      fit: BoxFit.cover,
      placeholder: (_, __) => Shimmer.fromColors(
        baseColor: isDark ? const Color(0xFF1E2128) : const Color(0xFFE5E7EB),
        highlightColor:
            isDark ? const Color(0xFF2E333D) : const Color(0xFFF3F4F6),
        child: Container(
          color: isDark ? const Color(0xFF1E2128) : const Color(0xFFE5E7EB),
        ),
      ),
      errorWidget: (_, __, ___) => Image.network(
        widget.entry.coverUrl,
        headers: headers,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _buildPlaceholder(isDark),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isRu = Localizations.maybeLocaleOf(context)?.languageCode == 'ru';
    final prog = widget.entry.progress;
    final headers = getMediaUrlHeaders(
      providerId: widget.entry.providerId,
      url: widget.entry.coverUrl,
    );

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
        onLongPress: () {
          HapticFeedback.mediumImpact();
          widget.onLongPress?.call();
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
              color: isDark ? const Color(0xFF16181D) : Colors.white,
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
                // Cover
                Expanded(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      _buildCoverImage(isDark, headers),

                      // 3D Book Spine Shadow on left
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

                      // Status badge at top right
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.72),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: _statusColor(widget.entry.status)
                                  .withValues(alpha: 0.5),
                              width: 0.8,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: _statusColor(widget.entry.status),
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                _statusLabel(widget.entry.status, isRu),
                                style: TextStyle(
                                  color: _statusColor(widget.entry.status),
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // New chapters badge at top left
                      if (widget.entry.newChaptersCount > 0)
                        Positioned(
                          top: 8,
                          left: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF10B981),
                              borderRadius: BorderRadius.circular(8),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.35),
                                  blurRadius: 4,
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.new_releases_rounded,
                                  size: 11,
                                  color: Colors.white,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '+${widget.entry.newChaptersCount} ${isRu ? 'новых' : 'new'}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                      // Reading progress bar at bottom of cover
                      if (prog != null && prog.totalPages > 1)
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 0,
                          child: LinearProgressIndicator(
                            value: ((prog.pageIndex + 1) / prog.totalPages)
                                .clamp(0.0, 1.0),
                            minHeight: 3.5,
                            backgroundColor: Colors.black54,
                            valueColor: const AlwaysStoppedAnimation(
                              Color(0xFFFF6740),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                // Title & Progress details
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        widget.entry.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          height: 1.25,
                        ),
                      ),
                      const SizedBox(height: 3),
                      if (prog != null)
                        Text(
                          '${isRu ? 'Гл.' : 'Ch.'} ${prog.chapterNumber} • ${isRu ? 'стр.' : 'p.'} ${prog.pageIndex + 1}/${prog.totalPages}',
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFFFF6740),
                          ),
                        )
                      else
                        Text(
                          switch (widget.entry.providerId) {
                            'mangadex' => 'MangaDex',
                            'mangalib' => 'MangaLib',
                            'ranobelib' => 'RanobeLib',
                            _ => widget.entry.providerId,
                          },
                          style: TextStyle(
                            fontSize: 10,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
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
