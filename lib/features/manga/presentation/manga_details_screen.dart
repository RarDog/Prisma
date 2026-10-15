import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:gel_rule_app/backend/backend.dart';
import 'package:gel_rule_app/features/post/presentation/widgets/post_media_viewer.dart';
import 'package:gel_rule_app/features/settings/presentation/settings_controller.dart';
import 'package:gel_rule_app/shared/widgets/app_shell.dart';
import 'package:gel_rule_app/sources/booru/mangadex_provider.dart';
import '../domain/manga_library_service.dart';
import '../domain/manga_library_providers.dart';
import 'manga_reader_screen.dart';
import 'novel_reader_screen.dart';
import 'widgets/manga_chapters_list.dart';
import 'widgets/manga_details_header_badges.dart';
import 'widgets/manga_details_info_card.dart';
import 'widgets/manga_details_viewer.dart';
import 'widgets/manga_horizontal_list.dart';
import 'widgets/manga_library_menu.dart';
import 'widgets/manga_reading_action_bar.dart';
import 'widgets/page_flip_3d.dart';
import 'widgets/tag_category_section.dart';

export 'widgets/manga_chapters_list.dart';
export 'widgets/manga_details_header_badges.dart';
export 'widgets/manga_details_info_card.dart';
export 'widgets/manga_details_viewer.dart';
export 'widgets/manga_horizontal_list.dart';
export 'widgets/manga_library_menu.dart';
export 'widgets/manga_reading_action_bar.dart';

class MangaDetailsScreen extends ConsumerStatefulWidget {
  const MangaDetailsScreen({
    required this.post,
    super.key,
  });

  final Post post;

  @override
  ConsumerState<MangaDetailsScreen> createState() => _MangaDetailsScreenState();
}

class _MangaDetailsScreenState extends ConsumerState<MangaDetailsScreen> {
  final GlobalKey<PageFlip3DState> _flipKey = GlobalKey<PageFlip3DState>();

  bool _isRtl = true;
  int _currentPage = 0;
  List<String> _pageUrls = [];
  bool _loadingPages = true;

  List<MangaDexChapter> _allChapters = [];
  List<MangaDexChapter> _chapters = [];
  List<String> _availableLanguages = [];
  String? _selectedLanguage;
  int _selectedChapterIndex = 0;
  ShellBottomBarVisibilityNotifier? _bottomBarNotifier;
  bool _hasReleasedHide = false;

  MangaReadingProgress? _readingProgress;
  MangaLibraryEntry? _libraryEntry;

  List<Post> _relatedManga = [];
  List<Post> _recommendations = [];

  Set<String> _downloadedChapterIds = {};
  final Set<String> _downloadingChapterIds = {};

  @override
  void initState() {
    super.initState();
    try {
      _bottomBarNotifier = ref.read(shellHideBottomBarProvider.notifier);
      _bottomBarNotifier?.pushHide();
    } catch (_) {}
    try {
      final settings = ref.read(settingsControllerProvider).value;
      if (settings != null) {
        _isRtl = settings.mangaReaderRtl;
      }
    } catch (_) {}
    _checkDownloadedChapters();
    _loadMangaData();
    _loadProgressAndLibrary();
    _loadRelatedAndRecommendations();
  }

  Future<void> _checkDownloadedChapters() async {
    try {
      final offlineService = ref.read(mangaOfflineServiceProvider);
      final ids = await offlineService.getDownloadedChapterIds(widget.post.id);
      if (mounted) {
        setState(() => _downloadedChapterIds = ids.toSet());
      }
    } catch (_) {}
  }

  Future<void> _downloadChapter(MangaDexChapter chapter) async {
    if (_downloadingChapterIds.contains(chapter.id)) return;
    setState(() => _downloadingChapterIds.add(chapter.id));
    final isRu = Localizations.maybeLocaleOf(context)?.languageCode == 'ru';

    try {
      final offlineService = ref.read(mangaOfflineServiceProvider);
      final providerManager = ref.read(providerManagerProvider);
      final p =
          await providerManager.getProviderInstance(widget.post.providerId);
      final NovelChapterProvider? novelProv =
          p is NovelChapterProvider ? (p as NovelChapterProvider) : null;
      final MangaChapterProvider? mangaProv =
          p is MangaChapterProvider ? (p as MangaChapterProvider) : null;

      if (chapter.isNovel ||
          widget.post.providerId == 'ranobelib' ||
          novelProv != null) {
        String content = '';
        if (novelProv != null) {
          content = await novelProv.fetchChapterContent(chapter.id);
        } else if (chapter.textContent != null) {
          content = chapter.textContent!;
        }
        await offlineService.downloadNovelChapter(
          mangaId: widget.post.id,
          chapter: chapter,
          content: content,
          providerId: widget.post.providerId,
        );
      } else if (mangaProv != null) {
        final pages = await mangaProv.fetchChapterPages(chapter.id);
        await offlineService.downloadMangaChapter(
          mangaId: widget.post.id,
          chapter: chapter,
          pageUrls: pages,
          providerId: widget.post.providerId,
        );
      }

      await _checkDownloadedChapters();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isRu
                ? 'Глава ${chapter.chapterNumber} скачана для офлайн чтения'
                : 'Chapter ${chapter.chapterNumber} downloaded offline'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка скачивания: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _downloadingChapterIds.remove(chapter.id));
      }
    }
  }

  void _releaseHide() {
    if (!_hasReleasedHide) {
      _hasReleasedHide = true;
      try {
        _bottomBarNotifier?.popHide();
      } catch (_) {}
    }
  }

  @override
  void dispose() {
    _releaseHide();
    super.dispose();
  }

  Future<void> _loadProgressAndLibrary() async {
    try {
      final libService = ref.read(mangaLibraryServiceProvider);
      await libService.resetNewChapters(widget.post.id);
      final prog = await libService.getProgress(widget.post.id);
      final entry = await libService.getLibraryEntry(widget.post.id);
      if (mounted) {
        setState(() {
          _readingProgress = prog;
          _libraryEntry = entry;
        });
      }
    } catch (_) {}
  }

  Future<void> _loadRelatedAndRecommendations() async {
    final post = widget.post;
    if (post.providerId == 'mangadex') {
      try {
        final providerManager = ref.read(providerManagerProvider);
        final provider = await providerManager.getProviderInstance('mangadex');
        if (provider is MangaDexProvider) {
          final related = await provider.fetchRelatedManga(post.id);
          final recs = await provider.fetchRecommendations(post);
          if (mounted) {
            setState(() {
              _relatedManga = related;
              _recommendations = recs;
            });
          }
        }
      } catch (_) {}
    }
  }

  Future<void> _loadMangaData() async {
    setState(() => _loadingPages = true);
    final post = widget.post;
    final List<String> urls = [];

    try {
      final providerManager = ref.read(providerManagerProvider);
      final p = await providerManager.getProviderInstance(post.providerId);
      final MangaChapterProvider? mangaProv =
          p is MangaChapterProvider ? (p as MangaChapterProvider) : null;
      final NovelChapterProvider? novelProv =
          p is NovelChapterProvider ? (p as NovelChapterProvider) : null;

      if (mangaProv != null || novelProv != null) {
        if (_allChapters.isEmpty) {
          List<MangaDexChapter> fetched = [];
          if (mangaProv != null) {
            final res = await mangaProv.fetchChapters(post.id);
            if (res is List<MangaDexChapter>) fetched = res;
          } else if (novelProv != null) {
            final res = await novelProv.fetchChapters(post.id);
            if (res is List<MangaDexChapter>) fetched = res;
          }

          final langs = <String>{};
          for (final ch in fetched) {
            if (ch.language.isNotEmpty) langs.add(ch.language);
          }
          final availableLanguages = langs.toList();
          availableLanguages.sort((a, b) {
            if (a == 'ru') return -1;
            if (b == 'ru') return 1;
            if (a == 'en') return -1;
            if (b == 'en') return 1;
            final countA = fetched.where((c) => c.language == a).length;
            final countB = fetched.where((c) => c.language == b).length;
            return countB.compareTo(countA);
          });

          String? defaultLang;
          if (availableLanguages.contains('ru')) {
            defaultLang = 'ru';
          } else if (availableLanguages.contains('en')) {
            defaultLang = 'en';
          } else {
            defaultLang = availableLanguages.firstOrNull;
          }

          if (mounted) {
            setState(() {
              _allChapters = fetched;
              _availableLanguages = availableLanguages;
              _selectedLanguage = defaultLang;
            });
          }
        }

        final filtered = _selectedLanguage != null
            ? _allChapters
                .where((c) => c.language == _selectedLanguage)
                .toList()
            : _allChapters;
        final chapters = filtered.isNotEmpty ? filtered : _allChapters;

        if (mounted) {
          setState(() {
            _chapters = chapters;
            if (_selectedChapterIndex >= _chapters.length) {
              _selectedChapterIndex = 0;
            }
          });
        }

        if (chapters.isNotEmpty) {
          final targetChapter = chapters[_selectedChapterIndex];
          // Check offline first
          final offlineService = ref.read(mangaOfflineServiceProvider);
          final offlinePages = await offlineService.getDownloadedPages(
              post.id, targetChapter.id);
          if (offlinePages.isNotEmpty) {
            urls.addAll(offlinePages);
            _chapters[_selectedChapterIndex] =
                targetChapter.copyWith(pageCount: offlinePages.length);
          } else if (mangaProv != null) {
            final pages = await mangaProv.fetchChapterPages(targetChapter.id);
            urls.addAll(pages);
            if (pages.isNotEmpty) {
              _chapters[_selectedChapterIndex] =
                  targetChapter.copyWith(pageCount: pages.length);
            }
          }
        }
      }

      if (urls.isEmpty) {
        final fallback =
            post.sampleUrl.isNotEmpty ? post.sampleUrl : post.previewUrl;
        if (fallback.isNotEmpty) urls.add(fallback);
      }

      if (mounted) {
        setState(() {
          _pageUrls = urls;
          _currentPage = 0;
          _loadingPages = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          final fallback =
              post.sampleUrl.isNotEmpty ? post.sampleUrl : post.previewUrl;
          _pageUrls = fallback.isNotEmpty ? [fallback] : [];
          _loadingPages = false;
        });
      }
    }
  }

  void _switchLanguage(String lang) {
    if (lang == _selectedLanguage) return;
    HapticFeedback.selectionClick();
    setState(() {
      _selectedLanguage = lang;
      final filtered = _allChapters.where((c) => c.language == lang).toList();
      _chapters = filtered.isNotEmpty ? filtered : _allChapters;
      _selectedChapterIndex = 0;
    });
    _loadMangaData();
  }

  void _switchChapter(int index) {
    if (index == _selectedChapterIndex ||
        index < 0 ||
        index >= _chapters.length) {
      return;
    }
    HapticFeedback.selectionClick();
    setState(() {
      _selectedChapterIndex = index;
    });
    _loadMangaData();
  }

  void _onNextChapter() {
    final isRu = Localizations.maybeLocaleOf(context)?.languageCode == 'ru';
    if (_selectedChapterIndex + 1 < _chapters.length) {
      final nextChapter = _chapters[_selectedChapterIndex + 1];
      HapticFeedback.mediumImpact();
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isRu
                ? 'Переход к главе ${nextChapter.chapterNumber}'
                : 'Next chapter: ${nextChapter.chapterNumber}',
          ),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
      _switchChapter(_selectedChapterIndex + 1);
    } else {
      HapticFeedback.lightImpact();
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isRu
                ? 'Вы дочитали последнюю главу тайтла!'
                : 'You have reached the last chapter!',
          ),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _showLanguagePicker(
      {required void Function(String language) onSelected}) {
    final isRu = Localizations.maybeLocaleOf(context)?.languageCode == 'ru';
    showModalBottomSheet<void>(
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
                        isRu
                            ? 'Выберите язык для чтения'
                            : 'Select Reading Language',
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
                        ? 'Выберите перевод для чтения глав этого тайтла'
                        : 'Choose translation language for chapters',
                    style: const TextStyle(color: Colors.white54, fontSize: 13),
                  ),
                ),
                const Divider(color: Colors.white12, height: 1),
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: _availableLanguages.length,
                    itemBuilder: (context, index) {
                      final lang = _availableLanguages[index];
                      final isSelected = lang == _selectedLanguage;
                      final count =
                          _allChapters.where((c) => c.language == lang).length;
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
                          onSelected(lang);
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

  void _onReadFullscreenPressed() {
    if (_availableLanguages.length > 1) {
      _showLanguagePicker(
        onSelected: (lang) {
          if (lang != _selectedLanguage) {
            _switchLanguage(lang);
          }
          _openFullscreenReader(language: lang);
        },
      );
    } else {
      _openFullscreenReader(language: _selectedLanguage);
    }
  }

  void _onContinueReadingPressed() {
    if (_readingProgress == null) {
      _onReadFullscreenPressed();
      return;
    }

    final prog = _readingProgress!;
    int targetIndex = _selectedChapterIndex;
    if (_chapters.isNotEmpty) {
      final foundIdx = _chapters.indexWhere((c) =>
          c.id == prog.chapterId || c.chapterNumber == prog.chapterNumber);
      if (foundIdx != -1) {
        targetIndex = foundIdx;
      }
    }

    _openFullscreenReader(
      initialChapterIndex: targetIndex,
      initialPage: prog.pageIndex,
    );
  }

  void _openFullscreenReader(
      {String? language, int? initialChapterIndex, int? initialPage}) {
    HapticFeedback.mediumImpact();
    final lang = language ?? _selectedLanguage;
    final currentLangChapters = lang != null
        ? _allChapters.where((c) => c.language == lang).toList()
        : _chapters;

    final targetChapter = _chapters.isNotEmpty
        ? _chapters[(initialChapterIndex ?? _selectedChapterIndex)
            .clamp(0, _chapters.length - 1)]
        : null;

    if (targetChapter != null &&
        (targetChapter.isNovel || widget.post.providerId == 'ranobelib')) {
      final title = widget.post.title ??
          widget.post.tagGroups['title']?.firstOrNull ??
          widget.post.tags.take(3).join(', ');
      Navigator.of(context)
          .push(
        MaterialPageRoute<void>(
          builder: (context) => NovelReaderScreen(
            mangaId: widget.post.id,
            chapter: targetChapter,
            allChapters: currentLangChapters.isNotEmpty
                ? currentLangChapters
                : _chapters,
            title: title,
            providerId: widget.post.providerId,
          ),
        ),
      )
          .then((_) {
        _loadProgressAndLibrary();
      });
      return;
    }

    Navigator.of(context)
        .push(
      MaterialPageRoute<void>(
        builder: (context) => MangaReaderScreen(
          post: widget.post,
          initialChapters:
              currentLangChapters.isNotEmpty ? currentLangChapters : _chapters,
          initialChapterIndex: initialChapterIndex ?? _selectedChapterIndex,
          initialLanguage: lang,
          initialPage: initialPage,
          allChapters: _allChapters,
          isRtl: _isRtl,
        ),
      ),
    )
        .then((_) {
      _loadProgressAndLibrary();
    });
  }

  Future<void> _setLibraryStatus(String? status) async {
    unawaited(HapticFeedback.selectionClick());
    final isRu = Localizations.maybeLocaleOf(context)?.languageCode == 'ru';
    final coverUrl = widget.post.sampleUrl.isNotEmpty
        ? widget.post.sampleUrl
        : widget.post.previewUrl;
    await ref.read(mangaLibraryServiceProvider).setLibraryStatus(
          mangaId: widget.post.id,
          providerId: widget.post.providerId,
          title: widget.post.title ?? widget.post.tags.take(3).join(', '),
          coverUrl: coverUrl,
          status: status,
        );
    await _loadProgressAndLibrary();

    if (mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            status != null
                ? (isRu
                    ? 'Статус обновлен: ${_statusLabel(status, isRu)}'
                    : 'Status updated: ${_statusLabel(status, isRu)}')
                : (isRu ? 'Удалено из библиотеки' : 'Removed from library'),
          ),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _toggleChapterRead(MangaDexChapter chapter) async {
    unawaited(HapticFeedback.selectionClick());
    final isRead =
        _readingProgress?.readChapterIds.contains(chapter.id) ?? false;
    final coverUrl = widget.post.sampleUrl.isNotEmpty
        ? widget.post.sampleUrl
        : widget.post.previewUrl;
    await ref.read(mangaLibraryServiceProvider).toggleChapterRead(
          mangaId: widget.post.id,
          chapterId: chapter.id,
          isRead: !isRead,
          title: widget.post.title,
          coverUrl: coverUrl,
          providerId: widget.post.providerId,
        );
    await _loadProgressAndLibrary();
  }

  String _statusLabel(String status, bool isRu) =>
      mangaStatusLabel(status, isRu);

  @override
  Widget build(BuildContext context) {
    final isRu = Localizations.maybeLocaleOf(context)?.languageCode == 'ru';
    final post = widget.post;
    final headers = getPostMediaHeaders(post);

    final title = post.title ?? post.tags.take(3).join(', ');
    final artist = post.tagGroups['artist']?.firstOrNull;
    final author = post.tagGroups['author']?.firstOrNull;
    final rating = post.tagGroups['content_rating']?.firstOrNull ??
        (post.rating.isNotEmpty ? post.rating : null);
    final status = post.tagGroups['status']?.firstOrNull;
    final description = post.tagGroups['description']?.firstOrNull;

    final genreTags = post.tagGroups['genre'] ?? [];
    final themeTags = post.tagGroups['theme'] ?? [];
    final formatTags = post.tagGroups['format'] ?? [];
    final generalTags = post.tagGroups['general'] ?? post.tags;

    final totalPages = _pageUrls.isEmpty ? 1 : _pageUrls.length;

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) {
          _releaseHide();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          actions: [
            MangaLibraryStatusMenu(
              libraryEntry: _libraryEntry,
              onSelected: (val) {
                if (val == 'remove') {
                  _setLibraryStatus(null);
                } else {
                  _setLibraryStatus(val);
                }
              },
            ),
            IconButton(
              icon: const Icon(Icons.share_rounded, size: 20),
              tooltip: isRu ? 'Поделиться' : 'Share',
              onPressed: () {
                final url =
                    post.source ?? 'https://mangadex.org/title/${post.id}';
                Share.share('$title\n$url');
              },
            ),
            IconButton(
              icon: const Icon(Icons.open_in_browser_rounded, size: 20),
              tooltip: isRu ? 'Открыть в браузере' : 'Open in browser',
              onPressed: () {
                final url =
                    post.source ?? 'https://mangadex.org/title/${post.id}';
                launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
              },
            ),
          ],
        ),
        body: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. ISOLATED MANGA VIEWER
              MangaDetailsViewer(
                post: post,
                headers: headers,
                loadingPages: _loadingPages,
                pageUrls: _pageUrls,
                currentPage: _currentPage,
                totalPages: totalPages,
                isRtl: _isRtl,
                flipKey: _flipKey,
                onPageChanged: (index) => setState(() => _currentPage = index),
                onEndReached: _onNextChapter,
                onToggleRtl: () {
                  final newRtl = !_isRtl;
                  setState(() => _isRtl = newRtl);
                  try {
                    ref
                        .read(settingsControllerProvider.notifier)
                        .saveMangaReaderSettings(
                          readingMode: newRtl ? 'pagedRtl' : 'pagedLtr',
                          isRtl: newRtl,
                        );
                  } catch (_) {}
                },
                onReadFullscreen: _onReadFullscreenPressed,
              ),

              // 2. BOTTOM DETAILS
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    MangaDetailsHeaderBadges(
                      title: title,
                      author: author,
                      artist: artist,
                      rating: rating,
                      status: status,
                      description: description,
                      onFilterByTag: (tag) => Navigator.of(context).pop(tag),
                    ),

                    MangaReadingActionBar(
                      readingProgress: _readingProgress,
                      onContinueReading: _onContinueReadingPressed,
                      onReadFullscreen: _onReadFullscreenPressed,
                      onReadFromStart: _onReadFullscreenPressed,
                    ),
                    const SizedBox(height: 20),

                    MangaChaptersList(
                      chapters: _chapters,
                      allChapters: _allChapters,
                      availableLanguages: _availableLanguages,
                      selectedLanguage: _selectedLanguage,
                      selectedChapterIndex: _selectedChapterIndex,
                      readingProgress: _readingProgress,
                      downloadedChapterIds: _downloadedChapterIds,
                      downloadingChapterIds: _downloadingChapterIds,
                      onSwitchLanguage: _switchLanguage,
                      onSelectChapter: (index) {
                        final ch = _chapters[index];
                        if (ch.isExternal &&
                            ch.externalUrl != null &&
                            ch.externalUrl!.isNotEmpty) {
                          launchUrl(Uri.parse(ch.externalUrl!),
                              mode: LaunchMode.externalApplication);
                          return;
                        }
                        if (widget.post.providerId == 'ranobelib' ||
                            ch.isNovel) {
                          _openFullscreenReader(initialChapterIndex: index);
                        } else {
                          _switchChapter(index);
                        }
                      },
                      onToggleChapterRead: _toggleChapterRead,
                      onDownloadChapter: _downloadChapter,
                    ),

                    // 3. TAGS SECTIONS
                    if (genreTags.isNotEmpty) ...[
                      TagCategorySection(
                        title: isRu ? 'Жанры' : 'Genres',
                        color: const Color(0xFF6366F1),
                        tags: genreTags,
                        onTagTap: (tag) => Navigator.of(context).pop(tag),
                      ),
                      const SizedBox(height: 16),
                    ],

                    if (themeTags.isNotEmpty) ...[
                      TagCategorySection(
                        title: isRu ? 'Темы' : 'Themes',
                        color: const Color(0xFF10B981),
                        tags: themeTags,
                        onTagTap: (tag) => Navigator.of(context).pop(tag),
                      ),
                      const SizedBox(height: 16),
                    ],

                    if (formatTags.isNotEmpty) ...[
                      TagCategorySection(
                        title: isRu ? 'Формат' : 'Format',
                        color: const Color(0xFFF59E0B),
                        tags: formatTags,
                        onTagTap: (tag) => Navigator.of(context).pop(tag),
                      ),
                      const SizedBox(height: 16),
                    ],

                    if (generalTags.isNotEmpty &&
                        genreTags.isEmpty &&
                        themeTags.isEmpty &&
                        formatTags.isEmpty) ...[
                      TagCategorySection(
                        title: isRu ? 'Теги' : 'Tags',
                        color: const Color(0xFFEC4899),
                        tags: generalTags,
                        onTagTap: (tag) => Navigator.of(context).pop(tag),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // 4. RELATED MANGA SECTION
                    if (_relatedManga.isNotEmpty) ...[
                      MangaHorizontalList(
                        title: isRu ? 'Связанные тайтлы' : 'Related Manga',
                        icon: Icons.alt_route_rounded,
                        items: _relatedManga,
                        onSelect: (item) {
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => MangaDetailsScreen(post: item),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 20),
                    ],

                    // 5. RECOMMENDATIONS SECTION
                    if (_recommendations.isNotEmpty) ...[
                      MangaHorizontalList(
                        title: isRu
                            ? 'Похожая манга и рекомендации'
                            : 'Recommendations & Similar',
                        icon: Icons.recommend_rounded,
                        items: _recommendations,
                        onSelect: (item) {
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => MangaDetailsScreen(post: item),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 20),
                    ],

                    // Info details card
                    MangaDetailsInfoCard(
                      post: post,
                      author: author,
                      artist: artist,
                      totalPages: totalPages,
                      chaptersCount: _chapters.length,
                      rating: rating,
                      status: status,
                    ),
                    SizedBox(height: MediaQuery.paddingOf(context).bottom + 24),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
