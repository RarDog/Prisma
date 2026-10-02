import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
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
import 'widgets/page_flip_3d.dart';
import 'widgets/manga_horizontal_list.dart';
import 'widgets/tag_category_section.dart';

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
  bool _descriptionExpanded = false;

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
      final p = await providerManager.getProviderInstance(widget.post.providerId);
      final NovelChapterProvider? novelProv = p is NovelChapterProvider ? (p as NovelChapterProvider) : null;
      final MangaChapterProvider? mangaProv = p is MangaChapterProvider ? (p as MangaChapterProvider) : null;

      if (chapter.isNovel || widget.post.providerId == 'ranobelib' || novelProv != null) {
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
            content: Text(isRu ? 'Глава ${chapter.chapterNumber} скачана для офлайн чтения' : 'Chapter ${chapter.chapterNumber} downloaded offline'),
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
      final MangaChapterProvider? mangaProv = p is MangaChapterProvider ? (p as MangaChapterProvider) : null;
      final NovelChapterProvider? novelProv = p is NovelChapterProvider ? (p as NovelChapterProvider) : null;

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
            ? _allChapters.where((c) => c.language == _selectedLanguage).toList()
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
          final offlinePages = await offlineService.getDownloadedPages(post.id, targetChapter.id);
          if (offlinePages.isNotEmpty) {
            urls.addAll(offlinePages);
            _chapters[_selectedChapterIndex] = targetChapter.copyWith(pageCount: offlinePages.length);
          } else if (mangaProv != null) {
            final pages = await mangaProv.fetchChapterPages(targetChapter.id);
            urls.addAll(pages);
            if (pages.isNotEmpty) {
              _chapters[_selectedChapterIndex] = targetChapter.copyWith(pageCount: pages.length);
            }
          }
        }
      }

      if (urls.isEmpty) {
        final fallback = post.sampleUrl.isNotEmpty ? post.sampleUrl : post.previewUrl;
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
          final fallback = post.sampleUrl.isNotEmpty ? post.sampleUrl : post.previewUrl;
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
    if (index == _selectedChapterIndex || index < 0 || index >= _chapters.length) return;
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
            isRu ? 'Вы дочитали последнюю главу тайтла!' : 'You have reached the last chapter!',
          ),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _showLanguagePicker({required void Function(String language) onSelected}) {
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
                      const Icon(Icons.translate_rounded, color: Color(0xFFFF6740), size: 22),
                      const SizedBox(width: 10),
                      Text(
                        isRu ? 'Выберите язык для чтения' : 'Select Reading Language',
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
                      final count = _allChapters.where((c) => c.language == lang).length;
                      return ListTile(
                        leading: Text(
                          MangaLanguageHelper.flag(lang),
                          style: const TextStyle(fontSize: 24),
                        ),
                        title: Text(
                          MangaLanguageHelper.name(lang),
                          style: TextStyle(
                            color: isSelected ? const Color(0xFFFF6740) : Colors.white,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                        subtitle: Text(
                          '$count ${isRu ? 'глав' : 'chapters'}',
                          style: const TextStyle(color: Colors.white54, fontSize: 12),
                        ),
                        trailing: isSelected
                            ? const Icon(Icons.check_circle_rounded, color: Color(0xFFFF6740), size: 22)
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
      final foundIdx = _chapters.indexWhere((c) => c.id == prog.chapterId || c.chapterNumber == prog.chapterNumber);
      if (foundIdx != -1) {
        targetIndex = foundIdx;
      }
    }

    _openFullscreenReader(
      initialChapterIndex: targetIndex,
      initialPage: prog.pageIndex,
    );
  }

  void _openFullscreenReader({String? language, int? initialChapterIndex, int? initialPage}) {
    HapticFeedback.mediumImpact();
    final lang = language ?? _selectedLanguage;
    final currentLangChapters = lang != null
        ? _allChapters.where((c) => c.language == lang).toList()
        : _chapters;

    final targetChapter = _chapters.isNotEmpty
        ? _chapters[(initialChapterIndex ?? _selectedChapterIndex).clamp(0, _chapters.length - 1)]
        : null;

    if (targetChapter != null &&
        (targetChapter.isNovel || widget.post.providerId == 'ranobelib')) {
      final title = widget.post.title ?? widget.post.tagGroups['title']?.firstOrNull ?? widget.post.tags.take(3).join(', ');
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (context) => NovelReaderScreen(
            mangaId: widget.post.id,
            chapter: targetChapter,
            allChapters: currentLangChapters.isNotEmpty ? currentLangChapters : _chapters,
            title: title,
            providerId: widget.post.providerId,
          ),
        ),
      ).then((_) {
        _loadProgressAndLibrary();
      });
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => MangaReaderScreen(
          post: widget.post,
          initialChapters: currentLangChapters.isNotEmpty ? currentLangChapters : _chapters,
          initialChapterIndex: initialChapterIndex ?? _selectedChapterIndex,
          initialLanguage: lang,
          initialPage: initialPage,
          allChapters: _allChapters,
          isRtl: _isRtl,
        ),
      ),
    ).then((_) {
      _loadProgressAndLibrary();
    });
  }

  Future<void> _setLibraryStatus(String? status) async {
    HapticFeedback.selectionClick();
    final isRu = Localizations.maybeLocaleOf(context)?.languageCode == 'ru';
    await ref.read(mangaLibraryServiceProvider).setLibraryStatus(
          mangaId: widget.post.id,
          providerId: widget.post.providerId,
          title: widget.post.title ?? widget.post.tags.take(3).join(', '),
          coverUrl: widget.post.previewUrl,
          status: status,
        );
    await _loadProgressAndLibrary();

    if (mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            status != null
                ? (isRu ? 'Статус обновлен: ${_statusLabel(status, isRu)}' : 'Status updated: ${_statusLabel(status, isRu)}')
                : (isRu ? 'Удалено из библиотеки' : 'Removed from library'),
          ),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _toggleChapterRead(MangaDexChapter chapter) async {
    HapticFeedback.selectionClick();
    final isRead = _readingProgress?.readChapterIds.contains(chapter.id) ?? false;
    await ref.read(mangaLibraryServiceProvider).toggleChapterRead(
          mangaId: widget.post.id,
          chapterId: chapter.id,
          isRead: !isRead,
          title: widget.post.title,
          coverUrl: widget.post.previewUrl,
          providerId: widget.post.providerId,
        );
    await _loadProgressAndLibrary();
  }

  String _statusLabel(String status, bool isRu) {
    return switch (status) {
      'reading' => isRu ? 'Читаю' : 'Reading',
      'plan_to_read' => isRu ? 'В планах' : 'Plan to read',
      'completed' => isRu ? 'Прочитано' : 'Completed',
      'dropped' => isRu ? 'Брошено' : 'Dropped',
      _ => isRu ? 'В библиотеке' : 'In Library',
    };
  }

  Color _statusColor(String status) {
    return switch (status) {
      'reading' => const Color(0xFFFF6740),
      'plan_to_read' => const Color(0xFF3B82F6),
      'completed' => const Color(0xFF10B981),
      'dropped' => const Color(0xFFEF4444),
      _ => const Color(0xFFFF6740),
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
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
            // Library status dropdown / bookmark button
            PopupMenuButton<String?>(
              tooltip: isRu ? 'Статус в библиотеке' : 'Library Status',
              icon: _libraryEntry != null
                  ? Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _statusColor(_libraryEntry!.status).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _statusColor(_libraryEntry!.status)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.bookmark_rounded, size: 14, color: _statusColor(_libraryEntry!.status)),
                          const SizedBox(width: 4),
                          Text(
                            _statusLabel(_libraryEntry!.status, isRu),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: _statusColor(_libraryEntry!.status),
                            ),
                          ),
                        ],
                      ),
                    )
                  : const Icon(Icons.bookmark_border_rounded, size: 22),
              onSelected: (val) {
                if (val == 'remove') {
                  _setLibraryStatus(null);
                } else {
                  _setLibraryStatus(val);
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'reading',
                  child: Row(
                    children: [
                      const Icon(Icons.auto_stories_rounded, color: Color(0xFFFF6740), size: 18),
                      const SizedBox(width: 10),
                      Text(isRu ? 'Читаю' : 'Reading'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'plan_to_read',
                  child: Row(
                    children: [
                      const Icon(Icons.bookmark_added_rounded, color: Color(0xFF3B82F6), size: 18),
                      const SizedBox(width: 10),
                      Text(isRu ? 'В планах' : 'Plan to read'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'completed',
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle_outline_rounded, color: Color(0xFF10B981), size: 18),
                      const SizedBox(width: 10),
                      Text(isRu ? 'Прочитано' : 'Completed'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'dropped',
                  child: Row(
                    children: [
                      const Icon(Icons.cancel_outlined, color: Color(0xFFEF4444), size: 18),
                      const SizedBox(width: 10),
                      Text(isRu ? 'Брошено' : 'Dropped'),
                    ],
                  ),
                ),
                if (_libraryEntry != null) ...[
                  const PopupMenuDivider(),
                  PopupMenuItem(
                    value: 'remove',
                    child: Row(
                      children: [
                        const Icon(Icons.delete_outline_rounded, color: Color(0xFFEF4444), size: 18),
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
            ),

            IconButton(
              icon: const Icon(Icons.share_rounded, size: 20),
              tooltip: isRu ? 'Поделиться' : 'Share',
              onPressed: () {
                final url = post.source ?? 'https://mangadex.org/title/${post.id}';
                Share.share('$title\n$url');
              },
            ),
            IconButton(
              icon: const Icon(Icons.open_in_browser_rounded, size: 20),
              tooltip: isRu ? 'Открыть в браузере' : 'Open in browser',
              onPressed: () {
                final url = post.source ?? 'https://mangadex.org/title/${post.id}';
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
              ClipRect(
                child: Container(
                  height: 440,
                  color: Colors.black,
                  child: Stack(
                    children: [
                      if (_loadingPages)
                        const Center(child: CircularProgressIndicator(color: Color(0xFFFF6740)))
                      else
                        Positioned.fill(
                          child: PageFlip3D(
                            key: _flipKey,
                            itemCount: totalPages,
                            isRtl: _isRtl,
                            initialIndex: _currentPage,
                            onPageChanged: (index) {
                              setState(() => _currentPage = index);
                            },
                            onEndReached: _onNextChapter,
                            itemBuilder: (context, index) {
                              final url = _pageUrls.isNotEmpty && index < _pageUrls.length
                                  ? _pageUrls[index]
                                  : (post.sampleUrl.isNotEmpty ? post.sampleUrl : post.previewUrl);
                              return Center(
                              child: CachedNetworkImage(
                                imageUrl: url,
                                httpHeaders: headers,
                                fit: BoxFit.contain,
                                placeholder: (_, __) => const Center(
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white24),
                                ),
                                errorWidget: (_, __, ___) => const Center(
                                  child: Icon(Icons.broken_image_rounded, color: Colors.white38, size: 48),
                                ),
                              ),
                            );
                          },
                        ),
                      ),

                    // Top controls overlay: Page count & Fullscreen toggle
                    Positioned(
                      top: 12,
                      left: 12,
                      right: 12,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.70),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: Colors.white12),
                            ),
                            child: Text(
                              '${_currentPage + 1} / $totalPages',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          Row(
                            children: [
                              GestureDetector(
                                onTap: () {
                                  HapticFeedback.selectionClick();
                                  final newRtl = !_isRtl;
                                  setState(() => _isRtl = newRtl);
                                  try {
                                    ref.read(settingsControllerProvider.notifier).saveMangaReaderSettings(
                                          readingMode: newRtl ? 'pagedRtl' : 'pagedLtr',
                                          isRtl: newRtl,
                                        );
                                  } catch (_) {}
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.70),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: Colors.white12),
                                  ),
                                  child: Icon(
                                    _isRtl
                                        ? Icons.format_textdirection_r_to_l_rounded
                                        : Icons.format_textdirection_l_to_r_rounded,
                                    color: Colors.white,
                                    size: 18,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              GestureDetector(
                                onTap: _onReadFullscreenPressed,
                                child: Container(
                                  padding: const EdgeInsets.all(7),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFF6740).withValues(alpha: 0.85),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(Icons.fullscreen_rounded, color: Colors.white, size: 18),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Tap helpers (invisible left & right tap zones)
                    Positioned(
                      left: 0,
                      top: 50,
                      bottom: 0,
                      width: 70,
                      child: GestureDetector(
                        behavior: HitTestBehavior.translucent,
                        onTap: () => _flipKey.currentState?.previousPage(),
                      ),
                    ),
                    Positioned(
                      right: 0,
                      top: 50,
                      bottom: 0,
                      width: 70,
                      child: GestureDetector(
                        behavior: HitTestBehavior.translucent,
                        onTap: () => _flipKey.currentState?.nextPage(),
                      ),
                    ),
                  ],
                ),
              ),
            ),

              // 2. BOTTOM DETAILS
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Primary Title
                    Text(
                      title,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Badges row: Author, Artist, Rating, Status
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        if (author != null)
                          ActionChip(
                            avatar: const Icon(Icons.person_outline_rounded, size: 16),
                            label: Text(author),
                            visualDensity: VisualDensity.compact,
                            padding: EdgeInsets.zero,
                            onPressed: () {
                              HapticFeedback.lightImpact();
                              Navigator.of(context).pop('author:$author');
                            },
                          ),
                        if (artist != null && artist != author)
                          ActionChip(
                            avatar: const Icon(Icons.brush_rounded, size: 16),
                            label: Text(artist),
                            visualDensity: VisualDensity.compact,
                            padding: EdgeInsets.zero,
                            onPressed: () {
                              HapticFeedback.lightImpact();
                              Navigator.of(context).pop('artist:$artist');
                            },
                          ),
                        if (rating != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.redAccent.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.redAccent.withValues(alpha: 0.4)),
                            ),
                            child: Text(
                              rating.toUpperCase(),
                              style: const TextStyle(
                                color: Colors.redAccent,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        if (status != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.green.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.green.withValues(alpha: 0.4)),
                            ),
                            child: Text(
                              status.toUpperCase(),
                              style: const TextStyle(
                                color: Colors.green,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Reading Progress & Action Buttons
                    if (_readingProgress != null) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF6740).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFFF6740).withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.history_rounded, color: Color(0xFFFF6740), size: 20),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    isRu
                                        ? 'Вы остановились на: Глава ${_readingProgress!.chapterNumber}, стр. ${_readingProgress!.pageIndex + 1}'
                                        : 'Last read: Chapter ${_readingProgress!.chapterNumber}, page ${_readingProgress!.pageIndex + 1}',
                                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                                  ),
                                  if (_readingProgress!.totalPages > 1) ...[
                                    const SizedBox(height: 6),
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(4),
                                      child: LinearProgressIndicator(
                                        value: ((_readingProgress!.pageIndex + 1) / _readingProgress!.totalPages).clamp(0.0, 1.0),
                                        minHeight: 4,
                                        backgroundColor: Colors.white10,
                                        valueColor: const AlwaysStoppedAnimation(Color(0xFFFF6740)),
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
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              ),
                              icon: const Icon(Icons.play_arrow_rounded, size: 22),
                              label: Text(
                                isRu ? 'Продолжить чтение' : 'Continue Reading',
                                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                              ),
                              onPressed: _onContinueReadingPressed,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            flex: 2,
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              ),
                              onPressed: _onReadFullscreenPressed,
                              child: Text(
                                isRu ? 'С начала' : 'From start',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ] else
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFFFF6740),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          icon: const Icon(Icons.menu_book_rounded, size: 20),
                          label: Text(
                            isRu ? 'Читать на весь экран (3D / Webtoon)' : 'Read Fullscreen',
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                          ),
                          onPressed: _onReadFullscreenPressed,
                        ),
                      ),
                    const SizedBox(height: 20),

                    // Description / Synopsis
                    if (description != null && description.isNotEmpty) ...[
                      Text(
                        isRu ? 'Описание' : 'Synopsis',
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        description,
                        maxLines: _descriptionExpanded ? null : 3,
                        overflow: _descriptionExpanded ? TextOverflow.visible : TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          height: 1.4,
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.85),
                        ),
                      ),
                      if (description.length > 150)
                        GestureDetector(
                          onTap: () => setState(() => _descriptionExpanded = !_descriptionExpanded),
                          child: Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              _descriptionExpanded
                                  ? (isRu ? 'Свернуть' : 'Show less')
                                  : (isRu ? 'Развернуть...' : 'Read more...'),
                              style: const TextStyle(color: Color(0xFFFF6740), fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      const SizedBox(height: 20),
                    ],

                    // Chapters Section (for MangaDex)
                    if (_chapters.isNotEmpty) ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            isRu ? 'Главы' : 'Chapters',
                            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            '${_chapters.length} ${isRu ? 'глав' : 'chapters'}',
                            style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 13),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      if (_availableLanguages.length > 1) ...[
                        SizedBox(
                          height: 32,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: _availableLanguages.length,
                            separatorBuilder: (_, __) => const SizedBox(width: 6),
                            itemBuilder: (context, index) {
                              final lang = _availableLanguages[index];
                              final isSelected = lang == _selectedLanguage;
                              final count = _allChapters.where((c) => c.language == lang).length;
                              return InkWell(
                                onTap: () => _switchLanguage(lang),
                                borderRadius: BorderRadius.circular(16),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
                                      Text(MangaLanguageHelper.flag(lang), style: const TextStyle(fontSize: 13)),
                                      const SizedBox(width: 5),
                                      Text(
                                        '${MangaLanguageHelper.name(lang)} ($count)',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
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
                          color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.03),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
                        ),
                        child: ListView.separated(
                          shrinkWrap: true,
                          itemCount: _chapters.length,
                          separatorBuilder: (_, __) => Divider(
                            height: 1,
                            thickness: 1,
                            color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.06),
                          ),
                          itemBuilder: (context, index) {
                            final ch = _chapters[index];
                            final isSelected = index == _selectedChapterIndex;
                            final isRead = _readingProgress?.readChapterIds.contains(ch.id) ?? false;

                            return Material(
                              color: isSelected
                                  ? const Color(0xFFFF6740).withValues(alpha: 0.14)
                                  : Colors.transparent,
                              child: InkWell(
                                onTap: () {
                                  if (widget.post.providerId == 'ranobelib' || ch.isNovel) {
                                    _openFullscreenReader(initialChapterIndex: index);
                                  } else {
                                    _switchChapter(index);
                                  }
                                },
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                  child: Row(
                                    children: [
                                      // Toggle read checkmark button
                                      IconButton(
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                        icon: Icon(
                                          isRead ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                                          color: isRead
                                              ? const Color(0xFF10B981)
                                              : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                                          size: 18,
                                        ),
                                        tooltip: isRu
                                            ? (isRead ? 'Отметить как непрочитанную' : 'Отметить как прочитанную')
                                            : (isRead ? 'Mark as unread' : 'Mark as read'),
                                        onPressed: () => _toggleChapterRead(ch),
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
                                                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                                color: isSelected
                                                    ? const Color(0xFFFF6740)
                                                    : (isRead ? theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6) : null),
                                              ),
                                            ),
                                            const SizedBox(height: 3),
                                            Row(
                                              children: [
                                                if (ch.language.isNotEmpty)
                                                  Container(
                                                    margin: const EdgeInsets.only(right: 6),
                                                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                                    decoration: BoxDecoration(
                                                      color: isDark ? Colors.white12 : Colors.black12,
                                                      borderRadius: BorderRadius.circular(4),
                                                    ),
                                                    child: Text(
                                                      ch.language.toUpperCase(),
                                                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                                                    ),
                                                  ),
                                                if (ch.pageCount > 1)
                                                  Text(
                                                    '${ch.pageCount} ${isRu ? 'стр.' : 'p.'}',
                                                    style: TextStyle(
                                                      color: theme.colorScheme.onSurfaceVariant,
                                                      fontSize: 11,
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                      // Offline download button
                                      if (_downloadingChapterIds.contains(ch.id))
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
                                            _downloadedChapterIds.contains(ch.id)
                                                ? Icons.download_done_rounded
                                                : Icons.download_for_offline_outlined,
                                            color: _downloadedChapterIds.contains(ch.id)
                                                ? const Color(0xFF10B981)
                                                : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                                            size: 20,
                                          ),
                                          tooltip: isRu
                                              ? (_downloadedChapterIds.contains(ch.id)
                                                  ? 'Скачано (доступно офлайн)'
                                                  : 'Скачать главу офлайн')
                                              : (_downloadedChapterIds.contains(ch.id)
                                                  ? 'Downloaded offline'
                                                  : 'Download offline'),
                                          onPressed: () => _downloadChapter(ch),
                                        ),
                                      const SizedBox(width: 8),
                                      Icon(
                                        isSelected ? Icons.play_circle_filled_rounded : Icons.play_arrow_rounded,
                                        color: isSelected
                                            ? const Color(0xFFFF6740)
                                            : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
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
                        title: isRu ? 'Похожая манга и рекомендации' : 'Recommendations & Similar',
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
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.03),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isRu ? 'Информация о тайтле' : 'Manga Info',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          const SizedBox(height: 8),
                          _infoRow(isRu ? 'Источник' : 'Source', post.providerName),
                          if (post.id.isNotEmpty) _infoRow('ID', post.id),
                          if (author != null) _infoRow(isRu ? 'Автор' : 'Author', author),
                          if (artist != null && artist != author) _infoRow(isRu ? 'Художник' : 'Artist', artist),
                          _infoRow(isRu ? 'Страниц' : 'Pages', '$totalPages'),
                          if (_chapters.isNotEmpty) _infoRow(isRu ? 'Всего глав' : 'Total chapters', '${_chapters.length}'),
                          if (rating != null) _infoRow(isRu ? 'Рейтинг' : 'Rating', rating.toUpperCase()),
                          if (status != null) _infoRow(isRu ? 'Статус' : 'Status', status.toUpperCase()),
                        ],
                      ),
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

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        ],
      ),
    );
  }
}

