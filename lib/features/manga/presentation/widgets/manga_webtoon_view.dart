import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:prisma_app/sources/manga/mangadex_provider.dart';
import '../../domain/reader_navigation_helper.dart';
import 'manga_reader_page_image.dart';
import 'manga_reader_types.dart';

class MangaWebtoonView extends StatelessWidget {
  const MangaWebtoonView({
    super.key,
    required this.scrollController,
    required this.pageUrls,
    this.headers,
    required this.readerTheme,
    this.currentChapter,
    required this.currentChapterIndex,
    required this.chaptersCount,
    this.nextChapterNumber,
    this.targetMemCacheWidth,
    required this.onTapUp,
    required this.onNextChapter,
  });

  final ScrollController scrollController;
  final List<String> pageUrls;
  final Map<String, String>? headers;
  final MangaReaderTheme readerTheme;
  final MangaDexChapter? currentChapter;
  final int currentChapterIndex;
  final int chaptersCount;
  final String? nextChapterNumber;
  final int? targetMemCacheWidth;
  final GestureTapUpCallback onTapUp;
  final VoidCallback onNextChapter;

  @override
  Widget build(BuildContext context) {
    final isRu = Localizations.maybeLocaleOf(context)?.languageCode == 'ru';

    return GestureDetector(
      onTapUp: onTapUp,
      child: ListView.builder(
        controller: scrollController,
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.zero,
        scrollCacheExtent: const ScrollCacheExtent.pixels(600),
        addAutomaticKeepAlives: false,
        addRepaintBoundaries: true,
        itemCount: pageUrls.length + 1, // +1 for chapter transition footer
        itemBuilder: (context, index) {
          if (index == pageUrls.length) {
            // Webtoon Chapter End footer
            final nextLabel =
                nextChapterNumber != null ? ': $nextChapterNumber' : '';
            return Container(
              padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
              color: readerTheme.backgroundColor,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    isRu
                        ? 'Глава ${currentChapter?.chapterNumber ?? '1'} завершена'
                        : 'End of Chapter ${currentChapter?.chapterNumber ?? '1'}',
                    style: TextStyle(
                      color: readerTheme == MangaReaderTheme.white
                          ? Colors.black87
                          : Colors.white70,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (ReaderNavigationHelper.hasNext(
                      currentIndex: currentChapterIndex,
                      totalCount: chaptersCount))
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFFF6740),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                      ),
                      icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                      label: Text(
                        isRu
                            ? 'Следующая глава$nextLabel'
                            : 'Next Chapter$nextLabel',
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                      onPressed: onNextChapter,
                    )
                  else
                    Text(
                      isRu
                          ? '🎉 Вы прочитали все главы!'
                          : '🎉 All chapters completed!',
                      style: const TextStyle(
                          color: Colors.greenAccent, fontSize: 15),
                    ),
                  const SizedBox(height: 30),
                ],
              ),
            );
          }

          final url = pageUrls[index];
          return MangaReaderPageImage(
            url: url,
            headers: headers,
            fit: BoxFit.fitWidth,
            memWidth: targetMemCacheWidth,
            backgroundColor: readerTheme.backgroundColor,
          );
        },
      ),
    );
  }
}
