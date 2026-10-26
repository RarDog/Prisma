import 'package:flutter/material.dart';
import 'package:prisma_app/sources/manga/mangadex_provider.dart';

Future<void> showMangaLanguagePicker({
  required BuildContext context,
  required List<String> availableLanguages,
  required String? selectedLanguage,
  required List<MangaDexChapter> allChapters,
  required ValueChanged<String> onLanguageSelected,
}) async {
  if (availableLanguages.length <= 1) return;
  final isRu = Localizations.maybeLocaleOf(context)?.languageCode == 'ru';

  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: const Color(0xFF1E1E24),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    const Icon(Icons.translate_rounded,
                        color: Color(0xFFFF6740), size: 22),
                    const SizedBox(width: 10),
                    Text(
                      isRu ? 'Язык перевода' : 'Translation Language',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                child: Text(
                  isRu
                      ? 'Выберите перевод для чтения'
                      : 'Choose language for reading',
                  style: const TextStyle(color: Colors.white54, fontSize: 13),
                ),
              ),
              const Divider(color: Colors.white12, height: 1),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: availableLanguages.length,
                  itemBuilder: (context, index) {
                    final lang = availableLanguages[index];
                    final isSelected = lang == selectedLanguage;
                    final count =
                        allChapters.where((c) => c.language == lang).length;
                    return ListTile(
                      leading: Text(
                        MangaLanguageHelper.flag(lang),
                        style: const TextStyle(fontSize: 24),
                      ),
                      title: Text(
                        MangaLanguageHelper.name(lang),
                        style: TextStyle(
                          color: isSelected
                              ? const Color(0xFFFF6740)
                              : Colors.white,
                          fontWeight:
                              isSelected ? FontWeight.bold : FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                      subtitle: Text(
                        '$count ${isRu ? 'глав' : 'chapters'}',
                        style: const TextStyle(
                            color: Colors.white54, fontSize: 12),
                      ),
                      trailing: isSelected
                          ? const Icon(Icons.check_circle_rounded,
                              color: Color(0xFFFF6740), size: 22)
                          : null,
                      onTap: () {
                        Navigator.of(context).pop();
                        onLanguageSelected(lang);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

Future<void> showMangaChapterPicker({
  required BuildContext context,
  required List<MangaDexChapter> chapters,
  required int currentChapterIndex,
  required ValueChanged<int> onChapterSelected,
}) async {
  if (chapters.isEmpty) return;
  final isRu = Localizations.maybeLocaleOf(context)?.languageCode == 'ru';

  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: const Color(0xFF1E1E24),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) {
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    isRu ? 'Список глав' : 'Chapters',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '${chapters.length} ${isRu ? 'глав' : 'chapters'}',
                    style: const TextStyle(color: Colors.white54, fontSize: 13),
                  ),
                ],
              ),
            ),
            const Divider(color: Colors.white12, height: 1),
            Expanded(
              child: ListView.builder(
                itemCount: chapters.length,
                itemBuilder: (context, index) {
                  final ch = chapters[index];
                  final isSelected = index == currentChapterIndex;
                  return ListTile(
                    selected: isSelected,
                    selectedTileColor:
                        const Color(0xFFFF6740).withValues(alpha: 0.15),
                    title: Text(
                      '${isRu ? 'Глава' : 'Chapter'} ${ch.chapterNumber}${ch.title.isNotEmpty ? ' - ${ch.title}' : ''}',
                      style: TextStyle(
                        color:
                            isSelected ? const Color(0xFFFF6740) : Colors.white,
                        fontWeight:
                            isSelected ? FontWeight.bold : FontWeight.w500,
                        fontSize: 14,
                      ),
                    ),
                    subtitle: Row(
                      children: [
                        if (ch.language.isNotEmpty)
                          Container(
                            margin: const EdgeInsets.only(right: 6, top: 2),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: Colors.white10,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              ch.language.toUpperCase(),
                              style: const TextStyle(
                                  color: Colors.white70, fontSize: 10),
                            ),
                          ),
                        if (ch.pageCount > 1)
                          Text(
                            '${ch.pageCount} ${isRu ? 'стр.' : 'pages'}',
                            style: const TextStyle(
                                color: Colors.white38, fontSize: 12),
                          ),
                      ],
                    ),
                    trailing: isSelected
                        ? const Icon(Icons.check_rounded,
                            color: Color(0xFFFF6740), size: 20)
                        : null,
                    onTap: () {
                      Navigator.of(context).pop();
                      onChapterSelected(index);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      );
    },
  );
}
