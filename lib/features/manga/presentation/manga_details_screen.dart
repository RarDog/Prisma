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
import 'manga_reader_screen.dart';
import 'widgets/page_flip_3d.dart';

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
    _loadMangaData();
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

  Future<void> _loadMangaData() async {
    setState(() => _loadingPages = true);
    final post = widget.post;
    final List<String> urls = [];

    try {
      if (post.providerId == 'mangadex') {
        final providerManager = ref.read(providerManagerProvider);
        final provider = await providerManager.getProviderInstance('mangadex');
        if (provider is MangaDexProvider) {
          if (_allChapters.isEmpty) {
            final fetched = await provider.fetchChapters(post.id);
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
            final pages = await provider.fetchChapterPages(targetChapter.id);
            urls.addAll(pages);
          }
        }
      } else if (post.providerId == 'nhentai') {
        if (post.childrenIds.isNotEmpty) {
          final mediaId = post.tagGroups['media_id']?.firstOrNull ?? post.id;
          final pageCount = post.childrenIds.length;
          for (int i = 1; i <= pageCount; i++) {
            urls.add('https://i.nhentai.net/galleries/$mediaId/$i.jpg');
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

  void _openFullscreenReader({String? language}) {
    HapticFeedback.mediumImpact();
    final lang = language ?? _selectedLanguage;
    final currentLangChapters = lang != null
        ? _allChapters.where((c) => c.language == lang).toList()
        : _chapters;

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => MangaReaderScreen(
          post: widget.post,
          initialChapters: currentLangChapters.isNotEmpty ? currentLangChapters : _chapters,
          initialChapterIndex: _selectedChapterIndex,
          initialLanguage: lang,
          allChapters: _allChapters,
        ),
      ),
    );
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
    final description = post.tagGroups['description']?.firstOrNull;
    final rating = post.tagGroups['content_rating']?.firstOrNull;
    final status = post.tagGroups['status']?.firstOrNull;

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
        title: Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_rounded, size: 20),
            tooltip: isRu ? 'Поделиться' : 'Share',
            onPressed: () {
              final url = post.source ?? 'https://mangadex.org/title/${post.id}';
              Share.share(url, subject: title);
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
            // Only this box flips when sliding; the rest of the interface stays fixed!
            Container(
              height: 440,
              color: Colors.black,
              child: Stack(
                children: [
                  if (_loadingPages)
                    const Center(child: CircularProgressIndicator(color: Colors.white))
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
                          final url = _pageUrls[index];
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
                            // Direction toggle (RTL / LTR)
                            GestureDetector(
                              onTap: () {
                                HapticFeedback.selectionClick();
                                final newRtl = !_isRtl;
                                setState(() => _isRtl = newRtl);
                                try {
                                  final settings = ref.read(settingsControllerProvider).value;
                                  if (settings != null) {
                                    ref.read(settingsControllerProvider.notifier).saveSettings(
                                      settings.copyWith(mangaReaderRtl: newRtl),
                                    );
                                  }
                                } catch (_) {}
                              },
                              child: Container(
                                padding: const EdgeInsets.all(7),
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
                            // Fullscreen icon
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

                  // Bottom tap turn helpers (invisible left & right tap zones)
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

            // 2. BOTTOM DETAILS (JUST LIKE RULE 34 / GELBOORU)
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

                  // Fullscreen Read Button
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
                        isRu ? 'Читать на весь экран (3D)' : 'Read Fullscreen (3D)',
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

                    // Language filter pills if multiple languages available
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
                      constraints: const BoxConstraints(maxHeight: 220),
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
                          return Material(
                            color: isSelected
                                ? const Color(0xFFFF6740).withValues(alpha: 0.14)
                                : Colors.transparent,
                            child: InkWell(
                              onTap: () => _switchChapter(index),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            '${isRu ? 'Глава' : 'Ch.'} ${ch.chapterNumber}${ch.title.isNotEmpty ? ' - ${ch.title}' : ''}',
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                              color: isSelected ? const Color(0xFFFF6740) : null,
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
                                              if (ch.pageCount > 0)
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
                                    Icon(
                                      isSelected
                                          ? Icons.play_circle_filled_rounded
                                          : Icons.play_arrow_rounded,
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

                  // 3. TAGS SECTIONS (CATEGORIZED LIKE RULE 34 / GELBOORU)
                  if (genreTags.isNotEmpty) ...[
                    _TagCategorySection(
                      title: isRu ? 'Жанры' : 'Genres',
                      color: const Color(0xFF6366F1),
                      tags: genreTags,
                      onTagTap: (tag) => Navigator.of(context).pop(tag),
                    ),
                    const SizedBox(height: 16),
                  ],

                  if (themeTags.isNotEmpty) ...[
                    _TagCategorySection(
                      title: isRu ? 'Темы' : 'Themes',
                      color: const Color(0xFF10B981),
                      tags: themeTags,
                      onTagTap: (tag) => Navigator.of(context).pop(tag),
                    ),
                    const SizedBox(height: 16),
                  ],

                  if (formatTags.isNotEmpty) ...[
                    _TagCategorySection(
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
                    _TagCategorySection(
                      title: isRu ? 'Теги' : 'Tags',
                      color: const Color(0xFFEC4899),
                      tags: generalTags,
                      onTagTap: (tag) => Navigator.of(context).pop(tag),
                    ),
                    const SizedBox(height: 16),
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

class _TagCategorySection extends StatelessWidget {
  const _TagCategorySection({
    required this.title,
    required this.color,
    required this.tags,
    this.onTagTap,
  });

  final String title;
  final Color color;
  final List<String> tags;
  final ValueChanged<String>? onTagTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 8,
              height: 8,
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(color: color.withValues(alpha: 0.6), blurRadius: 4, spreadRadius: 1),
                ],
              ),
            ),
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            const SizedBox(width: 8),
            Text(
              '${tags.length}',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final tag in tags)
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: onTagTap != null
                      ? () {
                          HapticFeedback.lightImpact();
                          onTagTap!(tag);
                        }
                      : null,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: color.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.tag_rounded, size: 13, color: color),
                        const SizedBox(width: 4),
                        Text(
                          tag,
                          style: TextStyle(
                            color: color,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
