import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import 'package:prisma_app/features/manga/domain/manga_library_service.dart';
import 'package:prisma_app/features/post/presentation/widgets/post_media_viewer.dart';

class MangaLibraryCard extends StatelessWidget {
  const MangaLibraryCard({
    required this.entry,
    required this.onTap,
    this.onLongPress,
    super.key,
  });

  final MangaLibraryEntry entry;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isRu = Localizations.maybeLocaleOf(context)?.languageCode == 'ru';
    final prog = entry.progress;
    final headers = getMediaUrlHeaders(
      providerId: entry.providerId,
      url: entry.coverUrl,
    );

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(6),
            bottomLeft: Radius.circular(6),
            topRight: Radius.circular(16),
            bottomRight: Radius.circular(16),
          ),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.10)
                : Colors.black.withValues(alpha: 0.08),
            width: 0.8,
          ),
          color: isDark
              ? Colors.white.withValues(alpha: 0.05)
              : Colors.black.withValues(alpha: 0.03),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.30 : 0.09),
              blurRadius: 12,
              offset: const Offset(0, 5),
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
                  entry.coverUrl.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: entry.coverUrl,
                          httpHeaders: headers,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => Container(
                            color: isDark ? Colors.grey[900] : Colors.grey[200],
                            child: const Center(
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Color(0xFFFF6740),
                              ),
                            ),
                          ),
                          errorWidget: (_, __, ___) => Container(
                            color: isDark ? Colors.grey[900] : Colors.grey[200],
                            child: const Icon(
                              Icons.broken_image_rounded,
                              color: Colors.white38,
                            ),
                          ),
                        )
                      : Container(
                          color: isDark ? Colors.grey[900] : Colors.grey[200],
                          child: const Icon(
                            Icons.auto_stories_rounded,
                            color: Colors.white38,
                          ),
                        ),

                  // 3D Book Spine Shadow & Fold Highlight
                  Positioned(
                    left: 0,
                    top: 0,
                    bottom: 0,
                    width: 14,
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                            colors: [
                              Colors.black.withValues(alpha: 0.50),
                              Colors.white.withValues(alpha: 0.15),
                              Colors.transparent,
                            ],
                            stops: const [0.0, 0.28, 1.0],
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
                        horizontal: 8,
                        vertical: 3.5,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.72),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color:
                              _statusColor(entry.status).withValues(alpha: 0.5),
                          width: 0.8,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: _statusColor(entry.status)
                                .withValues(alpha: 0.2),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _statusColor(entry.status),
                              boxShadow: [
                                BoxShadow(
                                  color: _statusColor(entry.status),
                                  blurRadius: 4,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            _statusLabel(entry.status, isRu),
                            style: TextStyle(
                              color: _statusColor(entry.status),
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // New chapters badge at top left
                  if (entry.newChaptersCount > 0)
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
                              size: 12,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '+${entry.newChaptersCount} ${isRu ? 'новых' : 'new'}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
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
                        minHeight: 4,
                        backgroundColor: Colors.black45,
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
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 4),
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
                      switch (entry.providerId) {
                        'mangadex' => 'MangaDex',
                        'mangalib' => 'MangaLib',
                        'ranobelib' => 'RanobeLib',
                        _ => entry.providerId,
                      },
                      style: TextStyle(
                        fontSize: 10,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
