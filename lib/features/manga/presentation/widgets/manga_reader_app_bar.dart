import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:gel_rule_app/sources/booru/mangadex_provider.dart';
import 'manga_reader_types.dart';

class MangaReaderAppBar extends StatelessWidget implements PreferredSizeWidget {
  const MangaReaderAppBar({
    super.key,
    required this.title,
    this.currentChapter,
    required this.currentPage,
    required this.totalPages,
    required this.readerMode,
    required this.availableLanguagesCount,
    this.selectedLanguage,
    required this.chaptersCount,
    required this.onBack,
    required this.onOpenLanguagePicker,
    required this.onOpenChapterPicker,
    required this.onToggleDirection,
    required this.onOpenSettings,
    required this.onToggleFullscreen,
  });

  final String title;
  final MangaDexChapter? currentChapter;
  final int currentPage;
  final int totalPages;
  final MangaReaderMode readerMode;
  final int availableLanguagesCount;
  final String? selectedLanguage;
  final int chaptersCount;
  final VoidCallback onBack;
  final VoidCallback onOpenLanguagePicker;
  final VoidCallback onOpenChapterPicker;
  final VoidCallback onToggleDirection;
  final VoidCallback onOpenSettings;
  final VoidCallback onToggleFullscreen;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final isRu = Localizations.maybeLocaleOf(context)?.languageCode == 'ru';

    return AppBar(
      backgroundColor: Colors.transparent,
      flexibleSpace: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            color: Colors.black.withValues(alpha: 0.65),
          ),
        ),
      ),
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded,
            color: Colors.white, size: 20),
        onPressed: onBack,
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            currentChapter != null
                ? '${isRu ? 'Гл.' : 'Ch.'} ${currentChapter!.chapterNumber} • ${currentPage + 1} / $totalPages'
                : '${currentPage + 1} / $totalPages',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.70),
              fontSize: 12,
            ),
          ),
        ],
      ),
      actions: [
        // Language selector button
        if (availableLanguagesCount > 1)
          IconButton(
            tooltip:
                isRu ? 'Сменить язык перевода' : 'Change translation language',
            icon: Text(
              MangaLanguageHelper.flag(selectedLanguage ?? 'ru'),
              style: const TextStyle(fontSize: 18),
            ),
            onPressed: onOpenLanguagePicker,
          ),

        // Chapter selector button
        if (chaptersCount > 1)
          TextButton.icon(
            style: TextButton.styleFrom(
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              backgroundColor: Colors.white.withValues(alpha: 0.12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
            ),
            icon: const Icon(Icons.format_list_bulleted_rounded, size: 16),
            label: Text(
              '${isRu ? 'Гл.' : 'Ch.'} ${currentChapter?.chapterNumber ?? '1'}',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
            onPressed: onOpenChapterPicker,
          ),

        // Direction toggle (RTL vs LTR)
        IconButton(
          tooltip: readerMode == MangaReaderMode.pagedRtl
              ? (isRu
                  ? 'Чтение: Справа-налево (Манга)'
                  : 'Reading: Right to Left (Manga)')
              : (isRu
                  ? 'Чтение: Слева-направо (Комиксы)'
                  : 'Reading: Left to Right (Comics)'),
          icon: Icon(
            readerMode == MangaReaderMode.pagedRtl
                ? Icons.format_textdirection_r_to_l_rounded
                : Icons.format_textdirection_l_to_r_rounded,
            color: Colors.white,
            size: 20,
          ),
          onPressed: onToggleDirection,
        ),

        // Reader Settings Sheet (mode, theme, etc.)
        IconButton(
          tooltip: isRu ? 'Настройки чтения' : 'Reader Settings',
          icon: const Icon(Icons.tune_rounded, color: Colors.white, size: 20),
          onPressed: onOpenSettings,
        ),

        // Fullscreen toggle button
        IconButton(
          tooltip: isRu ? 'Во весь экран' : 'Fullscreen',
          icon: const Icon(Icons.fullscreen_rounded,
              color: Colors.white, size: 24),
          onPressed: onToggleFullscreen,
        ),
      ],
    );
  }
}
