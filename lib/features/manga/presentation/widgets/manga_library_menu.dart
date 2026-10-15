import 'package:flutter/material.dart';
import '../../domain/manga_library_service.dart';

String mangaStatusLabel(String status, bool isRu) {
  return switch (status) {
    'reading' => isRu ? 'Читаю' : 'Reading',
    'plan_to_read' => isRu ? 'В планах' : 'Plan to read',
    'completed' => isRu ? 'Прочитано' : 'Completed',
    'dropped' => isRu ? 'Брошено' : 'Dropped',
    _ => isRu ? 'В библиотеке' : 'In Library',
  };
}

Color mangaStatusColor(String status) {
  return switch (status) {
    'reading' => const Color(0xFFFF6740),
    'plan_to_read' => const Color(0xFF3B82F6),
    'completed' => const Color(0xFF10B981),
    'dropped' => const Color(0xFFEF4444),
    _ => const Color(0xFFFF6740),
  };
}

class MangaLibraryStatusMenu extends StatelessWidget {
  const MangaLibraryStatusMenu({
    super.key,
    required this.libraryEntry,
    required this.onSelected,
  });

  final MangaLibraryEntry? libraryEntry;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) {
    final isRu = Localizations.maybeLocaleOf(context)?.languageCode == 'ru';

    return PopupMenuButton<String?>(
      tooltip: isRu ? 'Статус в библиотеке' : 'Library Status',
      icon: libraryEntry != null
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: mangaStatusColor(libraryEntry!.status)
                    .withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
                border:
                    Border.all(color: mangaStatusColor(libraryEntry!.status)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.bookmark_rounded,
                      size: 14, color: mangaStatusColor(libraryEntry!.status)),
                  const SizedBox(width: 4),
                  Text(
                    mangaStatusLabel(libraryEntry!.status, isRu),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: mangaStatusColor(libraryEntry!.status),
                    ),
                  ),
                ],
              ),
            )
          : const Icon(Icons.bookmark_border_rounded, size: 22),
      onSelected: onSelected,
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 'reading',
          child: Row(
            children: [
              const Icon(Icons.auto_stories_rounded,
                  color: Color(0xFFFF6740), size: 18),
              const SizedBox(width: 10),
              Text(isRu ? 'Читаю' : 'Reading'),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'plan_to_read',
          child: Row(
            children: [
              const Icon(Icons.bookmark_added_rounded,
                  color: Color(0xFF3B82F6), size: 18),
              const SizedBox(width: 10),
              Text(isRu ? 'В планах' : 'Plan to read'),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'completed',
          child: Row(
            children: [
              const Icon(Icons.check_circle_outline_rounded,
                  color: Color(0xFF10B981), size: 18),
              const SizedBox(width: 10),
              Text(isRu ? 'Прочитано' : 'Completed'),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'dropped',
          child: Row(
            children: [
              const Icon(Icons.cancel_outlined,
                  color: Color(0xFFEF4444), size: 18),
              const SizedBox(width: 10),
              Text(isRu ? 'Брошено' : 'Dropped'),
            ],
          ),
        ),
        if (libraryEntry != null) ...[
          const PopupMenuDivider(),
          PopupMenuItem(
            value: 'remove',
            child: Row(
              children: [
                const Icon(Icons.delete_outline_rounded,
                    color: Color(0xFFEF4444), size: 18),
                const SizedBox(width: 10),
                Text(
                  isRu ? 'Удалить из библиотеки' : 'Remove from library',
                  style: const TextStyle(color: Color(0xFFEF4444)),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
