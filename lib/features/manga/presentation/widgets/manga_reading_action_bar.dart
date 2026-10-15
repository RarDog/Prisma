import 'package:flutter/material.dart';
import '../../domain/manga_library_service.dart';

class MangaReadingActionBar extends StatelessWidget {
  const MangaReadingActionBar({
    super.key,
    this.readingProgress,
    required this.onContinueReading,
    required this.onReadFullscreen,
    required this.onReadFromStart,
  });

  final MangaReadingProgress? readingProgress;
  final VoidCallback onContinueReading;
  final VoidCallback onReadFullscreen;
  final VoidCallback onReadFromStart;

  @override
  Widget build(BuildContext context) {
    final isRu = Localizations.maybeLocaleOf(context)?.languageCode == 'ru';

    if (readingProgress != null) {
      final prog = readingProgress!;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFFF6740).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color: const Color(0xFFFF6740).withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.history_rounded,
                    color: Color(0xFFFF6740), size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isRu
                            ? 'Вы остановились на: Глава ${prog.chapterNumber}, стр. ${prog.pageIndex + 1}'
                            : 'Last read: Chapter ${prog.chapterNumber}, page ${prog.pageIndex + 1}',
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                      if (prog.totalPages > 1) ...[
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: ((prog.pageIndex + 1) / prog.totalPages)
                                .clamp(0.0, 1.0),
                            minHeight: 4,
                            backgroundColor: Colors.white10,
                            valueColor:
                                const AlwaysStoppedAnimation(Color(0xFFFF6740)),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          Row(
            children: [
              Expanded(
                flex: 3,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFFF6740),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                  icon: const Icon(Icons.play_arrow_rounded, size: 22),
                  label: Text(
                    isRu ? 'Продолжить чтение' : 'Continue Reading',
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                  onPressed: onContinueReading,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: onReadFromStart,
                  child: Text(
                    isRu ? 'С начала' : 'From start',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ],
      );
    }

    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        style: FilledButton.styleFrom(
          backgroundColor: const Color(0xFFFF6740),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        icon: const Icon(Icons.menu_book_rounded, size: 20),
        label: Text(
          isRu ? 'Читать на весь экран (3D / Webtoon)' : 'Read Fullscreen',
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
        ),
        onPressed: onReadFullscreen,
      ),
    );
  }
}
