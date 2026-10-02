import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import 'package:gel_rule_app/features/manga/domain/manga_library_service.dart';

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

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: isDark
              ? Colors.white.withValues(alpha: 0.05)
              : Colors.black.withValues(alpha: 0.03),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.08),
              blurRadius: 10,
              offset: const Offset(0, 4),
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
                          fit: BoxFit.cover,
                          placeholder: (_, __) =>
                              Container(color: Colors.white10),
                          errorWidget: (_, __, ___) => Container(
                            color: Colors.white10,
                            child: const Icon(
                              Icons.broken_image_rounded,
                              color: Colors.white38,
                            ),
                          ),
                        )
                      : Container(
                          color: Colors.white10,
                          child: const Icon(
                            Icons.auto_stories_rounded,
                            color: Colors.white38,
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
                        color:
                            _statusColor(entry.status).withValues(alpha: 0.90),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _statusLabel(entry.status, isRu),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
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
                        color:
                            Theme.of(context).colorScheme.onSurfaceVariant,
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
