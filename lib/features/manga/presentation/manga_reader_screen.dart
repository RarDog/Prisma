import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:gel_rule_app/backend/backend.dart';
import 'package:gel_rule_app/features/post/presentation/widgets/post_media_viewer.dart';
import 'package:gel_rule_app/features/settings/presentation/settings_controller.dart';
import 'package:gel_rule_app/shared/widgets/app_shell.dart';
import 'package:gel_rule_app/sources/booru/mangadex_provider.dart';
import 'widgets/page_flip_3d.dart';

class MangaReaderScreen extends ConsumerStatefulWidget {
  const MangaReaderScreen({
    required this.post,
    this.initialChapters,
    this.initialChapterIndex,
    this.initialLanguage,
    this.allChapters,
    super.key,
  });

  final Post post;
  final List<MangaDexChapter>? initialChapters;
  final int? initialChapterIndex;
  final String? initialLanguage;
  final List<MangaDexChapter>? allChapters;

  @override
  ConsumerState<MangaReaderScreen> createState() => _MangaReaderScreenState();
}

class _MangaReaderScreenState extends ConsumerState<MangaReaderScreen> {
  final GlobalKey<PageFlip3DState> _flipKey = GlobalKey<PageFlip3DState>();
  bool _isFullscreen = false;
  bool _isRtl = true; // Manga default: Right to Left
  int _currentPage = 0;
  List<String> _pageUrls = [];
  bool _loadingPages = true;
  String? _errorMessage;

  List<MangaDexChapter> _chapters = [];
  List<MangaDexChapter> _allChapters = [];
  List<String> _availableLanguages = [];
  String? _selectedLanguage;
  int _currentChapterIndex = 0;
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

    if (widget.allChapters != null && widget.allChapters!.isNotEmpty) {
      _allChapters = List.from(widget.allChapters!);
      _updateAvailableLanguages();
    }

    _selectedLanguage = widget.initialLanguage;

    if (widget.initialChapters != null && widget.initialChapters!.isNotEmpty) {
      _chapters = List.from(widget.initialChapters!);
      _currentChapterIndex = widget.initialChapterIndex ?? 0;
      if (_currentChapterIndex >= _chapters.length) {
        _currentChapterIndex = 0;
      }
    }

    _loadPages();
  }

  void _updateAvailableLanguages() {
    final langCounts = <String, int>{};
    for (final ch in _allChapters) {
      final lang = ch.language.trim();
      if (lang.isNotEmpty) {
        langCounts[lang] = (langCounts[lang] ?? 0) + 1;
      }
    }
    final sortedLangs = langCounts.keys.toList()
      ..sort((a, b) {
        if (a == 'ru') return -1;
        if (b == 'ru') return 1;
        if (a == 'en') return -1;
        if (b == 'en') return 1;
        return (langCounts[b] ?? 0).compareTo(langCounts[a] ?? 0);
      });
    _availableLanguages = sortedLangs;
    if (_selectedLanguage == null && sortedLangs.isNotEmpty) {
      _selectedLanguage = sortedLangs.contains('ru') ? 'ru' : sortedLangs.first;
    }
  }

  Future<void> _loadPages({bool startAtEnd = false}) async {
    setState(() {
      _loadingPages = true;
      _errorMessage = null;
    });

    final post = widget.post;
    final List<String> urls = [];

    try {
      if (post.providerId == 'mangadex') {
        final providerManager = ref.read(providerManagerProvider);
        final provider = await providerManager.getProviderInstance('mangadex');
        if (provider is MangaDexProvider) {
          if (_allChapters.isEmpty) {
            _allChapters = await provider.fetchChapters(post.id);
            _updateAvailableLanguages();
          }

          if (_chapters.isEmpty) {
            if (_selectedLanguage != null) {
              _chapters = _allChapters.where((c) => c.language == _selectedLanguage).toList();
            }
            if (_chapters.isEmpty) {
              _chapters = List.from(_allChapters);
            }
          }

          if (_chapters.isNotEmpty) {
            if (_currentChapterIndex >= _chapters.length) {
              _currentChapterIndex = 0;
            }
            final chapter = _chapters[_currentChapterIndex];
            final chapterPages = await provider.fetchChapterPages(chapter.id);
            if (chapterPages.isNotEmpty) {
              urls.addAll(chapterPages);
            }
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
      } else if (post.childrenIds.isNotEmpty) {
        for (final childId in post.childrenIds) {
          urls.add(childId);
        }
      }

      if (urls.isEmpty) {
        final fallback = post.fileUrl.isNotEmpty ? post.fileUrl : post.sampleUrl;
        if (fallback.isNotEmpty) {
          urls.add(fallback);
        }
      }

      if (mounted) {
        final targetPage = startAtEnd && urls.isNotEmpty ? urls.length - 1 : 0;
        setState(() {
          _pageUrls = urls;
          _currentPage = targetPage;
          _loadingPages = false;
        });
        if (startAtEnd && urls.isNotEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _flipKey.currentState?.jumpToPage(targetPage);
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loadingPages = false;
          _errorMessage = e.toString();
        });
      }
    }
  }

  void _switchChapter(int index, {bool startAtEnd = false}) {
    if (index == _currentChapterIndex || index < 0 || index >= _chapters.length) return;
    setState(() {
      _currentChapterIndex = index;
    });
    _loadPages(startAtEnd: startAtEnd);
  }

  void _onNextChapter() {
    final isRu = Localizations.maybeLocaleOf(context)?.languageCode == 'ru';
    if (_currentChapterIndex + 1 < _chapters.length) {
      final nextChapter = _chapters[_currentChapterIndex + 1];
      HapticFeedback.mediumImpact();
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isRu
                ? 'Глава ${_chapters[_currentChapterIndex].chapterNumber} завершена. Переход к главе ${nextChapter.chapterNumber}...'
                : 'Chapter completed. Next: Chapter ${nextChapter.chapterNumber}...',
          ),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
      _switchChapter(_currentChapterIndex + 1);
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

  void _onPreviousChapter() {
    if (_currentChapterIndex > 0) {
      final prevChapter = _chapters[_currentChapterIndex - 1];
      final isRu = Localizations.maybeLocaleOf(context)?.languageCode == 'ru';
      HapticFeedback.selectionClick();
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isRu
                ? 'Переход к предыдущей главе ${prevChapter.chapterNumber}'
                : 'Previous chapter: ${prevChapter.chapterNumber}',
          ),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
      _switchChapter(_currentChapterIndex - 1, startAtEnd: true);
    }
  }

  void _openLanguagePicker() {
    if (_availableLanguages.length <= 1) return;
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
                          if (lang != _selectedLanguage) {
                            setState(() {
                              _selectedLanguage = lang;
                              _chapters = _allChapters.where((c) => c.language == lang).toList();
                              _currentChapterIndex = 0;
                            });
                            _loadPages();
                          }
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

  void _openChapterPicker() {
    if (_chapters.isEmpty) return;
    final isRu = Localizations.maybeLocaleOf(context)?.languageCode == 'ru';

    showModalBottomSheet<void>(
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
                      '${_chapters.length} ${isRu ? 'глав' : 'chapters'}',
                      style: const TextStyle(color: Colors.white54, fontSize: 13),
                    ),
                  ],
                ),
              ),
              const Divider(color: Colors.white12, height: 1),
              Expanded(
                child: ListView.builder(
                  itemCount: _chapters.length,
                  itemBuilder: (context, index) {
                    final ch = _chapters[index];
                    final isSelected = index == _currentChapterIndex;
                    return ListTile(
                      selected: isSelected,
                      selectedTileColor: const Color(0xFFFF6740).withValues(alpha: 0.15),
                      title: Text(
                        '${isRu ? 'Глава' : 'Chapter'} ${ch.chapterNumber}${ch.title.isNotEmpty ? ' - ${ch.title}' : ''}',
                        style: TextStyle(
                          color: isSelected ? const Color(0xFFFF6740) : Colors.white,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                          fontSize: 14,
                        ),
                      ),
                      subtitle: Row(
                        children: [
                          if (ch.language.isNotEmpty)
                            Container(
                              margin: const EdgeInsets.only(right: 6, top: 2),
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                              decoration: BoxDecoration(
                                color: Colors.white10,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                ch.language.toUpperCase(),
                                style: const TextStyle(color: Colors.white70, fontSize: 10),
                              ),
                            ),
                          if (ch.pageCount > 0)
                            Text(
                              '${ch.pageCount} ${isRu ? 'стр.' : 'pages'}',
                              style: const TextStyle(color: Colors.white38, fontSize: 12),
                            ),
                        ],
                      ),
                      trailing: isSelected
                          ? const Icon(Icons.check_rounded, color: Color(0xFFFF6740), size: 20)
                          : null,
                      onTap: () {
                        Navigator.of(context).pop();
                        _switchChapter(index);
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

  void _toggleFullscreen() {
    setState(() {
      _isFullscreen = !_isFullscreen;
    });
    if (_isFullscreen) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    } else {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
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
    if (_isFullscreen) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isRu = Localizations.maybeLocaleOf(context)?.languageCode == 'ru';
    final totalPages = _pageUrls.isEmpty ? 1 : _pageUrls.length;
    final headers = getPostMediaHeaders(widget.post);

    final currentChapter = _chapters.isNotEmpty ? _chapters[_currentChapterIndex] : null;

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) {
          _releaseHide();
        }
      },
      child: Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: _isFullscreen
          ? null
          : AppBar(
              backgroundColor: Colors.black.withValues(alpha: 0.65),
              surfaceTintColor: Colors.transparent,
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
                onPressed: () => Navigator.of(context).pop(),
              ),
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.post.title ?? widget.post.tags.take(3).join(', '),
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
                        ? '${isRu ? 'Гл.' : 'Ch.'} ${currentChapter.chapterNumber} • ${_currentPage + 1} / $totalPages'
                        : '${_currentPage + 1} / $totalPages',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.70),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              actions: [
                // Language selector button if multiple languages exist
                if (_availableLanguages.length > 1)
                  IconButton(
                    tooltip: isRu ? 'Сменить язык перевода' : 'Change translation language',
                    icon: Text(
                      MangaLanguageHelper.flag(_selectedLanguage ?? 'ru'),
                      style: const TextStyle(fontSize: 18),
                    ),
                    onPressed: _openLanguagePicker,
                  ),
                // Chapter selector button if available
                if (_chapters.length > 1)
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      backgroundColor: Colors.white.withValues(alpha: 0.12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    icon: const Icon(Icons.format_list_bulleted_rounded, size: 16),
                    label: Text(
                      '${isRu ? 'Гл.' : 'Ch.'} ${currentChapter?.chapterNumber ?? '1'}',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    onPressed: _openChapterPicker,
                  ),
                // Direction toggle (RTL vs LTR)
                IconButton(
                  tooltip: _isRtl
                      ? (isRu ? 'Чтение: Справа-налево (Манга)' : 'Reading: Right to Left (Manga)')
                      : (isRu ? 'Чтение: Слева-направо (Комиксы)' : 'Reading: Left to Right (Comics)'),
                  icon: Icon(
                    _isRtl ? Icons.format_textdirection_r_to_l_rounded : Icons.format_textdirection_l_to_r_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                  onPressed: () {
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
                ),
                // Fullscreen toggle button
                IconButton(
                  tooltip: isRu ? 'Во весь экран' : 'Fullscreen',
                  icon: const Icon(Icons.fullscreen_rounded, color: Colors.white, size: 24),
                  onPressed: _toggleFullscreen,
                ),
              ],
            ),
      body: Stack(
        children: [
          // 3D Page flip view
          if (_loadingPages)
            const Center(
              child: CircularProgressIndicator(color: Colors.white),
            )
          else if (_errorMessage != null)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 48),
                    const SizedBox(height: 12),
                    Text(
                      _errorMessage!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white70),
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: _loadPages,
                      child: Text(isRu ? 'Повторить' : 'Retry'),
                    ),
                  ],
                ),
              ),
            )
          else
            Positioned.fill(
              child: GestureDetector(
                onTap: () {
                  // Single tap toggles controls / fullscreen
                  _toggleFullscreen();
                },
                child: PageFlip3D(
                  key: _flipKey,
                  itemCount: totalPages,
                  isRtl: _isRtl,
                  initialIndex: _currentPage,
                  onPageChanged: (index) {
                    setState(() => _currentPage = index);
                  },
                  onEndReached: _onNextChapter,
                  onStartReached: _onPreviousChapter,
                  itemBuilder: (context, index) {
                    final url = _pageUrls[index];
                    return Container(
                      color: Colors.black,
                      child: InteractiveViewer(
                        minScale: 1.0,
                        maxScale: 4.0,
                        child: Center(
                          child: CachedNetworkImage(
                            imageUrl: url,
                            httpHeaders: headers,
                            fit: BoxFit.contain,
                            placeholder: (_, __) => const Center(
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white38,
                              ),
                            ),
                            errorWidget: (_, __, ___) => const Center(
                              child: Icon(Icons.broken_image_rounded, color: Colors.white38, size: 48),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),

          // Bottom floating slider bar when NOT fullscreen
          if (!_isFullscreen && totalPages > 1 && !_loadingPages)
            Positioned(
              left: 16,
              right: 16,
              bottom: MediaQuery.paddingOf(context).bottom + 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.75),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                ),
                child: Row(
                  children: [
                    Text(
                      '${_currentPage + 1}',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                    Expanded(
                      child: SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          activeTrackColor: const Color(0xFFFF6740),
                          thumbColor: const Color(0xFFFF6740),
                          inactiveTrackColor: Colors.white24,
                          trackHeight: 3,
                          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                        ),
                        child: Slider(
                          value: _currentPage.toDouble().clamp(0, (totalPages - 1).toDouble()),
                          min: 0,
                          max: (totalPages - 1).toDouble(),
                          onChanged: (val) {
                            final page = val.round();
                            _flipKey.currentState?.jumpToPage(page);
                            setState(() => _currentPage = page);
                          },
                        ),
                      ),
                    ),
                    Text(
                      '$totalPages',
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    ),
  );
}
}
