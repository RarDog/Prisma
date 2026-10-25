import 'package:flutter/material.dart';
import 'package:gel_rule_app/sources/manga/mangadex_provider.dart';
import '../../domain/manga_library_service.dart';

class MangaChaptersList extends StatelessWidget {
  const MangaChaptersList({
    super.key,
    required this.chapters,
    required this.allChapters,
    required this.availableLanguages,
    this.selectedLanguage,
    required this.selectedChapterIndex,
    this.readingProgress,
    required this.downloadedChapterIds,
    required this.downloadingChapterIds,
    required this.onSwitchLanguage,
    required this.onSelectChapter,
    required this.onToggleChapterRead,
    required this.onDownloadChapter,
  });

  final List<MangaDexChapter> chapters;
  final List<MangaDexChapter> allChapters;
  final List<String> availableLanguages;
  final String? selectedLanguage;
  final int selectedChapterIndex;
  final MangaReadingProgress? readingProgress;
  final Set<String> downloadedChapterIds;
  final Set<String> downloadingChapterIds;
  final ValueChanged<String> onSwitchLanguage;
  final ValueChanged<int> onSelectChapter;
  final ValueChanged<MangaDexChapter> onToggleChapterRead;
  final ValueChanged<MangaDexChapter> onDownloadChapter;

  @override
  Widget build(BuildContext context) {
    if (chapters.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isRu = Localizations.maybeLocaleOf(context)?.languageCode == 'ru';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              isRu ? 'Главы' : 'Chapters',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            Text(
              '${chapters.length} ${isRu ? 'глав' : 'chapters'}',
              style: TextStyle(
                color: theme.colorScheme.onSurfaceVariant,
                fontSize: 13,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (availableLanguages.length > 1) ...[
          SizedBox(
            height: 32,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: availableLanguages.length,
              separatorBuilder: (_, __) => const SizedBox(width: 6),
              itemBuilder: (context, index) {
                final lang = availableLanguages[index];
                final isSelected = lang == selectedLanguage;
                final count =
                    allChapters.where((c) => c.language == lang).length;
                return InkWell(
                  onTap: () => onSwitchLanguage(lang),
                  borderRadius: BorderRadius.circular(16),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFFFF6740).withValues(alpha: 0.18)
                          : (isDark
                              ? Colors.white.withValues(alpha: 0.05)
                              : Colors.black.withValues(alpha: 0.04)),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected
                            ? const Color(0xFFFF6740).withValues(alpha: 0.8)
                            : Colors.transparent,
                        width: 1.2,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(MangaLanguageHelper.flag(lang),
                            style: const TextStyle(fontSize: 13)),
                        const SizedBox(width: 5),
                        Text(
                          '${MangaLanguageHelper.name(lang)} ($count)',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight:
                                isSelected ? FontWeight.bold : FontWeight.w500,
                            color: isSelected
                                ? (isDark ? Colors.white : Colors.black87)
                                : theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 10),
        ],
        Container(
          constraints: const BoxConstraints(maxHeight: 230),
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withValues(alpha: 0.04)
                : Colors.black.withValues(alpha: 0.03),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
          ),
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: chapters.length,
            separatorBuilder: (_, __) => Divider(
              height: 1,
              thickness: 1,
              color: isDark
                  ? Colors.white.withValues(alpha: 0.06)
                  : Colors.black.withValues(alpha: 0.06),
            ),
            itemBuilder: (context, index) {
              final ch = chapters[index];
              final isSelected = index == selectedChapterIndex;
              final isRead =
                  readingProgress?.readChapterIds.contains(ch.id) ?? false;

              return Material(
                color: isSelected
                    ? const Color(0xFFFF6740).withValues(alpha: 0.14)
                    : Colors.transparent,
                child: InkWell(
                  onTap: () => onSelectChapter(index),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    child: Row(
                      children: [
                        // Toggle read checkmark button
                        IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          icon: Icon(
                            isRead
                                ? Icons.check_circle_rounded
                                : Icons.radio_button_unchecked_rounded,
                            color: isRead
                                ? const Color(0xFF10B981)
                                : theme.colorScheme.onSurfaceVariant
                                    .withValues(alpha: 0.4),
                            size: 18,
                          ),
                          tooltip: isRu
                              ? (isRead
                                  ? 'Отметить как непрочитанную'
                                  : 'Отметить как прочитанную')
                              : (isRead ? 'Mark as unread' : 'Mark as read'),
                          onPressed: () => onToggleChapterRead(ch),
                        ),
                        const SizedBox(width: 8),

                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${isRu ? 'Глава' : 'Ch.'} ${ch.chapterNumber}${ch.title.isNotEmpty ? ' - ${ch.title}' : ''}',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: isSelected
                                      ? FontWeight.bold
                                      : FontWeight.w500,
                                  color: isSelected
                                      ? const Color(0xFFFF6740)
                                      : (isRead
                                          ? theme.colorScheme.onSurfaceVariant
                                              .withValues(alpha: 0.6)
                                          : null),
                                ),
                              ),
                              const SizedBox(height: 3),
                              Row(
                                children: [
                                  if (ch.language.isNotEmpty)
                                    Container(
                                      margin: const EdgeInsets.only(right: 6),
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 4, vertical: 1),
                                      decoration: BoxDecoration(
                                        color: isDark
                                            ? Colors.white12
                                            : Colors.black12,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        ch.language.toUpperCase(),
                                        style: const TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  if (ch.isExternal)
                                    Container(
                                      margin: const EdgeInsets.only(right: 6),
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 5, vertical: 1),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF3B82F6)
                                            .withValues(alpha: 0.18),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.open_in_new_rounded,
                                              size: 10,
                                              color: Color(0xFF3B82F6)),
                                          const SizedBox(width: 3),
                                          Text(
                                            isRu ? 'Внешняя' : 'External',
                                            style: const TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                                color: Color(0xFF3B82F6)),
                                          ),
                                        ],
                                      ),
                                    ),
                                  if (ch.pageCount > 0)
                                    Text(
                                      '${ch.pageCount} ${isRu ? 'стр.' : 'p.'}',
                                      style: TextStyle(
                                        color:
                                            theme.colorScheme.onSurfaceVariant,
                                        fontSize: 11,
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        // Offline download button
                        if (downloadingChapterIds.contains(ch.id))
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 6),
                            child: SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Color(0xFFFF6740),
                              ),
                            ),
                          )
                        else
                          IconButton(
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            icon: Icon(
                              downloadedChapterIds.contains(ch.id)
                                  ? Icons.download_done_rounded
                                  : Icons.download_for_offline_outlined,
                              color: downloadedChapterIds.contains(ch.id)
                                  ? const Color(0xFF10B981)
                                  : theme.colorScheme.onSurfaceVariant
                                      .withValues(alpha: 0.4),
                              size: 20,
                            ),
                            tooltip: isRu
                                ? (downloadedChapterIds.contains(ch.id)
                                    ? 'Скачано (доступно офлайн)'
                                    : 'Скачать главу офлайн')
                                : (downloadedChapterIds.contains(ch.id)
                                    ? 'Downloaded offline'
                                    : 'Download offline'),
                            onPressed: () => onDownloadChapter(ch),
                          ),
                        const SizedBox(width: 8),
                        Icon(
                          isSelected
                              ? Icons.play_circle_filled_rounded
                              : Icons.play_arrow_rounded,
                          color: isSelected
                              ? const Color(0xFFFF6740)
                              : theme.colorScheme.onSurfaceVariant
                                  .withValues(alpha: 0.4),
                          size: 20,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}
