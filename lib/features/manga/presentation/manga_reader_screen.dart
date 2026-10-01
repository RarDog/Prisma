import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:gel_rule_app/backend/backend.dart';
import 'package:gel_rule_app/features/post/presentation/widgets/post_media_viewer.dart';
import 'package:gel_rule_app/features/settings/presentation/settings_controller.dart';
import 'package:gel_rule_app/shared/widgets/app_shell.dart';
import 'package:gel_rule_app/sources/booru/mangadex_provider.dart';
import '../domain/manga_library_providers.dart';
import 'widgets/page_flip_3d.dart';

enum MangaReaderMode {
  pagedRtl,
  pagedLtr,
  webtoon,
}

enum MangaReaderTheme {
  black(Color(0xFF000000), 'OLED Чёрный', 'OLED Black'),
  dark(Color(0xFF141418), 'Тёмный', 'Dark Gray'),
  sepia(Color(0xFF2B241E), 'Сепия', 'Sepia'),
  white(Color(0xFFF4F3ED), 'Светлый', 'Light Paper');

  const MangaReaderTheme(this.backgroundColor, this.labelRu, this.labelEn);
  final Color backgroundColor;
  final String labelRu;
  final String labelEn;
}

class MangaReaderScreen extends ConsumerStatefulWidget {
  const MangaReaderScreen({
    required this.post,
    this.initialChapters,
    this.initialChapterIndex,
    this.initialLanguage,
    this.initialPage,
    this.allChapters,
    this.isRtl,
    super.key,
  });

  final Post post;
  final List<MangaDexChapter>? initialChapters;
  final int? initialChapterIndex;
  final String? initialLanguage;
  final int? initialPage;
  final List<MangaDexChapter>? allChapters;
  final bool? isRtl;

  @override
  ConsumerState<MangaReaderScreen> createState() => _MangaReaderScreenState();
}

class _MangaReaderScreenState extends ConsumerState<MangaReaderScreen>
    with WidgetsBindingObserver {
  static const MethodChannel _volumeChannel =
      MethodChannel('rulegel/volume_keys');
  final GlobalKey<PageFlip3DState> _flipKey = GlobalKey<PageFlip3DState>();
  final ScrollController _webtoonScrollController = ScrollController();

  bool _isFullscreen = false;
  MangaReaderMode _readerMode = MangaReaderMode.pagedRtl;
  MangaReaderTheme _readerTheme = MangaReaderTheme.black;

  bool _volumeNavigationEnabled = true;
  bool _invertVolumeKeys = false;

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
  String? _prefetchedChapterId;

  Timer? _progressDebounce;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    try {
      _bottomBarNotifier = ref.read(shellHideBottomBarProvider.notifier);
      _bottomBarNotifier?.pushHide();
    } catch (_) {}

    try {
      final settings =
          ref.read(settingsControllerProvider).value ?? AppSettings.defaults;
      _volumeNavigationEnabled = settings.mangaVolumeNavigation;
      _invertVolumeKeys = settings.mangaInvertVolumeKeys;
    } catch (_) {}

    if (_volumeNavigationEnabled) {
      _enableVolumeNavigation();
    }
    _volumeChannel.setMethodCallHandler(_handleVolumeMethodCall);
    HardwareKeyboard.instance.addHandler(_handleKeyEvent);

    // Auto-detect webtoon format for manhwa/long strip
    _autoDetectReaderMode();

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

    _currentPage = widget.initialPage ?? 0;

    _webtoonScrollController.addListener(_onWebtoonScroll);

    _loadPages(initialPage: widget.initialPage);
  }

  void _autoDetectReaderMode() {
    final tags = widget.post.tags.map((t) => t.toLowerCase()).toSet();
    final formats = (widget.post.tagGroups['format'] ?? []).map((t) => t.toLowerCase()).toSet();
    final isLongStrip = tags.contains('long strip') ||
        tags.contains('web comic') ||
        tags.contains('webtoon') ||
        formats.contains('long strip') ||
        formats.contains('web comic');

    if (isLongStrip) {
      _readerMode = MangaReaderMode.webtoon;
    } else {
      try {
        final settings = ref.read(settingsControllerProvider).value ?? AppSettings.defaults;
        final bool effectiveRtl = widget.isRtl ?? settings.mangaReaderRtl;
        if (settings.mangaReadingMode == 'pagedLtr' || !effectiveRtl) {
          _readerMode = MangaReaderMode.pagedLtr;
        } else {
          _readerMode = MangaReaderMode.pagedRtl;
        }
      } catch (_) {
        _readerMode = (widget.isRtl == false) ? MangaReaderMode.pagedLtr : MangaReaderMode.pagedRtl;
      }
    }
  }

  void _onWebtoonScroll() {
    if (_pageUrls.isEmpty || !_webtoonScrollController.hasClients) return;
    final maxScroll = _webtoonScrollController.position.maxScrollExtent;
    if (maxScroll <= 0) return;

    final currentOffset = _webtoonScrollController.offset;
    final pageFraction = (currentOffset / maxScroll).clamp(0.0, 1.0);
    final calculatedPage = (pageFraction * (_pageUrls.length - 1)).round();

    if (calculatedPage != _currentPage) {
      setState(() {
        _currentPage = calculatedPage;
      });
      _scheduleSaveProgress();
      _precacheAdjacentPages(calculatedPage);
    }
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

  Future<void> _loadPages({bool startAtEnd = false, int? initialPage}) async {
    setState(() {
      _loadingPages = true;
      _errorMessage = null;
    });

    final post = widget.post;
    final List<String> urls = [];

    try {
      final offlineService = ref.read(mangaOfflineServiceProvider);
      if (_chapters.isNotEmpty) {
        if (_currentChapterIndex >= _chapters.length) {
          _currentChapterIndex = 0;
        }
        final chapter = _chapters[_currentChapterIndex];
        final offlinePages = await offlineService.getDownloadedPages(post.id, chapter.id);
        if (offlinePages.isNotEmpty) {
          urls.addAll(offlinePages);
        }
      }

      if (urls.isEmpty) {
        final providerManager = ref.read(providerManagerProvider);
        final p = await providerManager.getProviderInstance(post.providerId);
        final MangaChapterProvider? mangaChapterProv =
            p is MangaChapterProvider ? (p as MangaChapterProvider) : null;
        if (mangaChapterProv != null) {
          if (_allChapters.isEmpty) {
            final fetched = await mangaChapterProv.fetchChapters(post.id);
            if (fetched is List<MangaDexChapter>) _allChapters = fetched;
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
            final chapterPages = await mangaChapterProv.fetchChapterPages(chapter.id);
            if (chapterPages.isNotEmpty) {
              urls.addAll(chapterPages);
              _chapters[_currentChapterIndex] = chapter.copyWith(pageCount: chapterPages.length);
            }
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
        int targetPage = 0;
        if (startAtEnd && urls.isNotEmpty) {
          targetPage = urls.length - 1;
        } else if (initialPage != null && initialPage < urls.length) {
          targetPage = initialPage;
        }

        setState(() {
          _pageUrls = urls;
          _currentPage = targetPage;
          _loadingPages = false;
        });

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_readerMode != MangaReaderMode.webtoon) {
            _flipKey.currentState?.jumpToPage(targetPage);
          } else if (_webtoonScrollController.hasClients && targetPage > 0 && urls.isNotEmpty) {
            final maxScroll = _webtoonScrollController.position.maxScrollExtent;
            _webtoonScrollController.jumpTo((targetPage / (urls.length - 1)) * maxScroll);
          }
          _precacheAdjacentPages(targetPage);
          _scheduleSaveProgress();
        });
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

  int? get _targetMemCacheWidth {
    if (!mounted) return null;
    final size = MediaQuery.maybeSizeOf(context);
    final ratio = MediaQuery.maybeDevicePixelRatioOf(context) ?? 2.0;
    if (size == null) return 1080;
    return (size.width * ratio).round().clamp(1080, 1920);
  }

  void _precacheAdjacentPages(int index) {
    if (!mounted || _pageUrls.isEmpty) return;
    final headers = getPostMediaHeaders(widget.post);
    final memWidth = _targetMemCacheWidth;

    // Precache next 3 pages
    for (int offset = 1; offset <= 3; offset++) {
      final nextIdx = index + offset;
      if (nextIdx < _pageUrls.length) {
        final url = _pageUrls[nextIdx];
        if (url.isNotEmpty && url.startsWith('http')) {
          precacheImage(
            CachedNetworkImageProvider(url, headers: headers, maxWidth: memWidth),
            context,
          );
        }
      }
    }

    // Precache previous page
    final prevIdx = index - 1;
    if (prevIdx >= 0 && prevIdx < _pageUrls.length) {
      final url = _pageUrls[prevIdx];
      if (url.isNotEmpty && url.startsWith('http')) {
        precacheImage(
          CachedNetworkImageProvider(url, headers: headers, maxWidth: memWidth),
          context,
        );
      }
    }

    // Smart prefetch next chapter if approaching end (last 2 pages)
    if (index >= _pageUrls.length - 2 &&
        _currentChapterIndex + 1 < _chapters.length &&
        widget.post.providerId == 'mangadex') {
      _prefetchNextChapterPages();
    }
  }

  Future<void> _prefetchNextChapterPages() async {
    final nextIdx = _currentChapterIndex + 1;
    if (nextIdx >= _chapters.length) return;
    final nextChapter = _chapters[nextIdx];
    if (_prefetchedChapterId == nextChapter.id) return;
    _prefetchedChapterId = nextChapter.id;

    try {
      final providerManager = ref.read(providerManagerProvider);
      final provider = await providerManager.getProviderInstance(widget.post.providerId);
      final MangaChapterProvider? mangaChapterProv =
          provider is MangaChapterProvider ? (provider as MangaChapterProvider) : null;
      if (mangaChapterProv != null) {
        final pages = await mangaChapterProv.fetchChapterPages(nextChapter.id);
        if (pages.isNotEmpty && mounted) {
          final headers = getPostMediaHeaders(widget.post);
          final memWidth = _targetMemCacheWidth;
          for (final pageUrl in pages.take(3)) {
            precacheImage(
              CachedNetworkImageProvider(pageUrl, headers: headers, maxWidth: memWidth),
              context,
            );
          }
        }
      }
    } catch (_) {}
  }

  void _scheduleSaveProgress() {
    _progressDebounce?.cancel();
    _progressDebounce = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      _saveCurrentProgress();
    });
  }

  void _saveCurrentProgress() {
    try {
      final currentChapter = _chapters.isNotEmpty && _currentChapterIndex < _chapters.length
          ? _chapters[_currentChapterIndex]
          : null;
      ref.read(mangaLibraryServiceProvider).saveProgress(
            mangaId: widget.post.id,
            providerId: widget.post.providerId,
            title: widget.post.title ?? widget.post.tags.take(3).join(', '),
            coverUrl: widget.post.previewUrl,
            chapterId: currentChapter?.id ?? '',
            chapterNumber: currentChapter?.chapterNumber ?? '1',
            pageIndex: _currentPage,
            totalPages: _pageUrls.length,
            markChapterComplete: _pageUrls.isNotEmpty && _currentPage >= _pageUrls.length - 1,
          );
    } catch (_) {}
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
                ? 'Глава ${_chapters[_currentChapterIndex].chapterNumber} прочитана! Переход к гл. ${nextChapter.chapterNumber}...'
                : 'Chapter finished. Next: Chapter ${nextChapter.chapterNumber}...',
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
            isRu ? 'Вы дочитали последнюю доступную главу тайтла!' : 'You have reached the last chapter!',
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
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (_volumeNavigationEnabled) {
        _enableVolumeNavigation();
      }
    } else {
      _disableVolumeNavigation();
    }
  }

  Future<void> _enableVolumeNavigation() async {
    try {
      await _volumeChannel.invokeMethod('enableVolumeNavigation');
    } catch (_) {}
  }

  Future<void> _disableVolumeNavigation() async {
    try {
      await _volumeChannel.invokeMethod('disableVolumeNavigation');
    } catch (_) {}
  }

  Future<dynamic> _handleVolumeMethodCall(MethodCall call) async {
    if (call.method == 'onVolumeKeyDown') {
      final direction = call.arguments as String?;
      if (direction == 'up') {
        _handleVolumeKey(isUp: true);
      } else if (direction == 'down') {
        _handleVolumeKey(isUp: false);
      }
    }
    return null;
  }

  bool _handleKeyEvent(KeyEvent event) {
    if (!_volumeNavigationEnabled) return false;
    if (event is! KeyDownEvent) return false;
    if (event.logicalKey == LogicalKeyboardKey.audioVolumeUp) {
      _handleVolumeKey(isUp: true);
      return true;
    } else if (event.logicalKey == LogicalKeyboardKey.audioVolumeDown) {
      _handleVolumeKey(isUp: false);
      return true;
    }
    return false;
  }

  void _handleVolumeKey({required bool isUp}) {
    if (!_volumeNavigationEnabled || !mounted) return;

    // Normal behavior:
    // Volume Down -> Next page / scroll down
    // Volume Up -> Previous page / scroll up
    // Inverted:
    // Volume Down -> Previous page / scroll up
    // Volume Up -> Next page / scroll down
    final bool goNext = _invertVolumeKeys ? isUp : !isUp;

    HapticFeedback.selectionClick();

    if (_readerMode == MangaReaderMode.webtoon) {
      if (_webtoonScrollController.hasClients) {
        final currentOffset = _webtoonScrollController.offset;
        final delta = goNext ? 480.0 : -480.0;
        final targetOffset = (currentOffset + delta).clamp(
          0.0,
          _webtoonScrollController.position.maxScrollExtent,
        );
        _webtoonScrollController.animateTo(
          targetOffset,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
        );
      }
    } else {
      // Paged 3D mode
      if (goNext) {
        _flipKey.currentState?.nextPage();
      } else {
        _flipKey.currentState?.previousPage();
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _disableVolumeNavigation();
    _volumeChannel.setMethodCallHandler(null);
    HardwareKeyboard.instance.removeHandler(_handleKeyEvent);
    _progressDebounce?.cancel();
    _saveCurrentProgress();
    _webtoonScrollController.dispose();
    _releaseHide();
    if (_isFullscreen) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
    super.dispose();
  }

  void _openReaderSettingsSheet() {
    final isRu = Localizations.maybeLocaleOf(context)?.languageCode == 'ru';
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF1E1E24),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.tune_rounded, color: Color(0xFFFF6740), size: 22),
                        const SizedBox(width: 10),
                        Text(
                          isRu ? 'Настройки чтения' : 'Reader Settings',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Reading Mode Segmented
                    Text(
                      isRu ? 'Режим чтения' : 'Reading Mode',
                      style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    SegmentedButton<MangaReaderMode>(
                      segments: [
                        ButtonSegment(
                          value: MangaReaderMode.pagedRtl,
                          label: Text(isRu ? 'Манга (RTL)' : 'RTL Manga'),
                          icon: const Icon(Icons.format_textdirection_r_to_l_rounded, size: 16),
                        ),
                        ButtonSegment(
                          value: MangaReaderMode.pagedLtr,
                          label: Text(isRu ? 'Комиксы' : 'LTR Comic'),
                          icon: const Icon(Icons.format_textdirection_l_to_r_rounded, size: 16),
                        ),
                        ButtonSegment(
                          value: MangaReaderMode.webtoon,
                          label: Text(isRu ? 'Webtoon' : 'Webtoon'),
                          icon: const Icon(Icons.view_headline_rounded, size: 16),
                        ),
                      ],
                      selected: {_readerMode},
                      onSelectionChanged: (newVal) {
                        final mode = newVal.first;
                        setState(() => _readerMode = mode);
                        setSheetState(() {});
                        try {
                          ref.read(settingsControllerProvider.notifier).saveMangaReaderSettings(
                                readingMode: mode.name,
                                isRtl: mode != MangaReaderMode.pagedLtr,
                              );
                        } catch (_) {}
                      },
                      style: ButtonStyle(
                        foregroundColor: WidgetStateProperty.resolveWith(
                          (states) => states.contains(WidgetState.selected)
                              ? Colors.black
                              : Colors.white70,
                        ),
                        backgroundColor: WidgetStateProperty.resolveWith(
                          (states) => states.contains(WidgetState.selected)
                              ? const Color(0xFFFF6740)
                              : Colors.white10,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Background Theme
                    Text(
                      isRu ? 'Цвет фона' : 'Background Theme',
                      style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: MangaReaderTheme.values.map((theme) {
                        final isSelected = _readerTheme == theme;
                        return Expanded(
                          child: GestureDetector(
                            onTap: () {
                              setState(() => _readerTheme = theme);
                              setSheetState(() {});
                            },
                            child: Container(
                              margin: const EdgeInsets.symmetric(horizontal: 4),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: theme.backgroundColor,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: isSelected ? const Color(0xFFFF6740) : Colors.white24,
                                  width: isSelected ? 2 : 1,
                                ),
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (isSelected)
                                    const Icon(Icons.check_circle_rounded, color: Color(0xFFFF6740), size: 16)
                                  else
                                    const SizedBox(height: 16),
                                  const SizedBox(height: 4),
                                  Text(
                                    isRu ? theme.labelRu : theme.labelEn,
                                    style: TextStyle(
                                      color: theme == MangaReaderTheme.white ? Colors.black87 : Colors.white70,
                                      fontSize: 11,
                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),

                    // Volume Navigation Options
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: Column(
                        children: [
                          SwitchListTile.adaptive(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                            dense: true,
                            activeTrackColor: const Color(0xFFFF6740),
                            secondary: const Icon(Icons.volume_up_rounded, color: Color(0xFFFF6740), size: 22),
                            title: Text(
                              isRu ? 'Кнопки громкости' : 'Volume key navigation',
                              style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                            ),
                            subtitle: Text(
                              isRu
                                  ? (_invertVolumeKeys
                                      ? 'Вверх — след., Вниз — пред.'
                                      : 'Вниз — след., Вверх — пред.')
                                  : (_invertVolumeKeys
                                      ? 'Up = next, Down = prev'
                                      : 'Down = next, Up = prev'),
                              style: const TextStyle(color: Colors.white54, fontSize: 11),
                            ),
                            value: _volumeNavigationEnabled,
                            onChanged: (val) {
                              setState(() => _volumeNavigationEnabled = val);
                              setSheetState(() {});
                              if (val) {
                                _enableVolumeNavigation();
                              } else {
                                _disableVolumeNavigation();
                              }
                              try {
                                ref.read(settingsControllerProvider.notifier).saveMangaVolumeNavigation(
                                      enabled: val,
                                      invert: _invertVolumeKeys,
                                    );
                              } catch (_) {}
                            },
                          ),
                          if (_volumeNavigationEnabled) ...[
                            const Divider(height: 1, indent: 48, color: Colors.white10),
                            SwitchListTile.adaptive(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                              dense: true,
                              activeTrackColor: const Color(0xFFFF6740),
                              secondary: const Icon(Icons.swap_vert_rounded, color: Colors.white70, size: 20),
                              title: Text(
                                isRu ? 'Инвертировать кнопки' : 'Invert volume buttons',
                                style: const TextStyle(color: Colors.white70, fontSize: 13),
                              ),
                              value: _invertVolumeKeys,
                              onChanged: (val) {
                                setState(() => _invertVolumeKeys = val);
                                setSheetState(() {});
                                try {
                                  ref.read(settingsControllerProvider.notifier).saveMangaVolumeNavigation(
                                        enabled: _volumeNavigationEnabled,
                                        invert: val,
                                      );
                                } catch (_) {}
                              },
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Quick Chapter Switch Button
                    if (_chapters.isNotEmpty)
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Colors.white24),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: const Icon(Icons.format_list_bulleted_rounded, size: 18),
                        label: Text(
                          isRu ? 'Выбрать другую главу' : 'Switch Chapter',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        onPressed: () {
                          Navigator.of(context).pop();
                          _openChapterPicker();
                        },
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
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
                    isRu ? 'Выберите перевод для чтения' : 'Choose language for reading',
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
                          if (ch.pageCount > 1)
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

  void _handlePagedTap(TapUpDetails details) {
    final width = MediaQuery.of(context).size.width;
    final dx = details.localPosition.dx;
    final isRtl = _readerMode == MangaReaderMode.pagedRtl;

    if (dx < width * 0.28) {
      // Left 28%
      if (isRtl) {
        _flipKey.currentState?.nextPage();
      } else {
        _flipKey.currentState?.previousPage();
      }
    } else if (dx > width * 0.72) {
      // Right 28%
      if (isRtl) {
        _flipKey.currentState?.previousPage();
      } else {
        _flipKey.currentState?.nextPage();
      }
    } else {
      // Center zone (28% - 72%)
      _toggleFullscreen();
    }
  }

  void _handleWebtoonTap(TapUpDetails details) {
    final height = MediaQuery.of(context).size.height;
    final dy = details.localPosition.dy;

    if (dy < height * 0.20 && _webtoonScrollController.hasClients) {
      // Top 20%: scroll up
      _webtoonScrollController.animateTo(
        (_webtoonScrollController.offset - 450).clamp(0.0, _webtoonScrollController.position.maxScrollExtent),
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
      );
    } else if (dy > height * 0.80 && _webtoonScrollController.hasClients) {
      // Bottom 20%: scroll down
      _webtoonScrollController.animateTo(
        (_webtoonScrollController.offset + 450).clamp(0.0, _webtoonScrollController.position.maxScrollExtent),
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
      );
    } else {
      // Center zone: toggle controls
      _toggleFullscreen();
    }
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
          _saveCurrentProgress();
        }
      },
      child: Scaffold(
        backgroundColor: _readerTheme.backgroundColor,
        extendBodyBehindAppBar: true,
        appBar: _isFullscreen
            ? null
            : AppBar(
                backgroundColor: Colors.black.withValues(alpha: 0.72),
                surfaceTintColor: Colors.transparent,
                elevation: 0,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
                  onPressed: () {
                    _saveCurrentProgress();
                    Navigator.of(context).pop();
                  },
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
                  // Language selector button
                  if (_availableLanguages.length > 1)
                    IconButton(
                      tooltip: isRu ? 'Сменить язык перевода' : 'Change translation language',
                      icon: Text(
                        MangaLanguageHelper.flag(_selectedLanguage ?? 'ru'),
                        style: const TextStyle(fontSize: 18),
                      ),
                      onPressed: _openLanguagePicker,
                    ),

                  // Chapter selector button
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
                    tooltip: _readerMode == MangaReaderMode.pagedRtl
                        ? (isRu ? 'Чтение: Справа-налево (Манга)' : 'Reading: Right to Left (Manga)')
                        : (isRu ? 'Чтение: Слева-направо (Комиксы)' : 'Reading: Left to Right (Comics)'),
                    icon: Icon(
                      _readerMode == MangaReaderMode.pagedRtl
                          ? Icons.format_textdirection_r_to_l_rounded
                          : Icons.format_textdirection_l_to_r_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                    onPressed: () {
                      HapticFeedback.selectionClick();
                      final newMode = _readerMode == MangaReaderMode.pagedRtl
                          ? MangaReaderMode.pagedLtr
                          : MangaReaderMode.pagedRtl;
                      setState(() => _readerMode = newMode);
                      try {
                        ref.read(settingsControllerProvider.notifier).saveMangaReaderSettings(
                              readingMode: newMode.name,
                              isRtl: newMode == MangaReaderMode.pagedRtl,
                            );
                      } catch (_) {}
                    },
                  ),

                  // Reader Settings Sheet (mode, theme, etc.)
                  IconButton(
                    tooltip: isRu ? 'Настройки чтения' : 'Reader Settings',
                    icon: const Icon(Icons.tune_rounded, color: Colors.white, size: 20),
                    onPressed: _openReaderSettingsSheet,
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
            // Content View
            if (_loadingPages)
              const Center(
                child: CircularProgressIndicator(color: Color(0xFFFF6740)),
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
            else if (_readerMode == MangaReaderMode.webtoon)
              // Seamless Webtoon vertical continuous scroll mode
              Positioned.fill(
                child: GestureDetector(
                  onTapUp: _handleWebtoonTap,
                  child: ListView.builder(
                    controller: _webtoonScrollController,
                    physics: const BouncingScrollPhysics(),
                    padding: EdgeInsets.zero,
                    itemCount: _pageUrls.length + 1, // +1 for chapter transition footer
                    itemBuilder: (context, index) {
                      if (index == _pageUrls.length) {
                        // Webtoon Chapter End footer
                        return Container(
                          padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
                          color: _readerTheme.backgroundColor,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                isRu
                                    ? 'Глава ${currentChapter?.chapterNumber ?? '1'} завершена'
                                    : 'End of Chapter ${currentChapter?.chapterNumber ?? '1'}',
                                style: TextStyle(
                                  color: _readerTheme == MangaReaderTheme.white
                                      ? Colors.black87
                                      : Colors.white70,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 16),
                              if (_currentChapterIndex + 1 < _chapters.length)
                                FilledButton.icon(
                                  style: FilledButton.styleFrom(
                                    backgroundColor: const Color(0xFFFF6740),
                                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                  ),
                                  icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                                  label: Text(
                                    isRu
                                        ? 'Следующая глава: ${_chapters[_currentChapterIndex + 1].chapterNumber}'
                                        : 'Next Chapter: ${_chapters[_currentChapterIndex + 1].chapterNumber}',
                                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                                  ),
                                  onPressed: _onNextChapter,
                                )
                              else
                                Text(
                                  isRu ? '🎉 Вы прочитали все главы!' : '🎉 All chapters completed!',
                                  style: const TextStyle(color: Colors.greenAccent, fontSize: 15),
                                ),
                              const SizedBox(height: 30),
                            ],
                          ),
                        );
                      }

                      final url = _pageUrls[index];
                      return _buildPageImage(url, headers, BoxFit.fitWidth, memWidth: _targetMemCacheWidth);
                    },
                  ),
                ),
              )
            else
              // Paged 3D Flip Mode (RTL or LTR)
              Positioned.fill(
                child: GestureDetector(
                  onTapUp: _handlePagedTap,
                  child: PageFlip3D(
                    key: _flipKey,
                    itemCount: totalPages,
                    isRtl: _readerMode == MangaReaderMode.pagedRtl,
                    initialIndex: _currentPage,
                    onPageChanged: (index) {
                      setState(() => _currentPage = index);
                      _scheduleSaveProgress();
                      _precacheAdjacentPages(index);
                    },
                    onEndReached: _onNextChapter,
                    onStartReached: _onPreviousChapter,
                    itemBuilder: (context, index) {
                      final url = _pageUrls[index];
                      return Container(
                        color: _readerTheme.backgroundColor,
                        child: InteractiveViewer(
                          minScale: 1.0,
                          maxScale: 4.0,
                          child: Center(
                            child: _buildPageImage(url, headers, BoxFit.contain, memWidth: _targetMemCacheWidth),
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
                    color: Colors.black.withValues(alpha: 0.80),
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
                              if (_readerMode == MangaReaderMode.webtoon) {
                                if (_webtoonScrollController.hasClients) {
                                  final maxScroll = _webtoonScrollController.position.maxScrollExtent;
                                  _webtoonScrollController.jumpTo((page / (totalPages - 1)) * maxScroll);
                                }
                              } else {
                                _flipKey.currentState?.jumpToPage(page);
                              }
                              setState(() => _currentPage = page);
                              _scheduleSaveProgress();
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

  Widget _buildPageImage(String url, Map<String, String>? headers, BoxFit fit, {int? memWidth}) {
    if (url.startsWith('/') || url.startsWith('file:')) {
      final cleanPath = url.replaceFirst('file://', '');
      return Image.file(
        File(cleanPath),
        fit: fit,
        width: fit == BoxFit.fitWidth ? double.infinity : null,
        alignment: Alignment.topCenter,
        errorBuilder: (_, __, ___) => const Center(
          child: Icon(Icons.broken_image_rounded, color: Colors.white38, size: 48),
        ),
      );
    }
    return CachedNetworkImage(
      imageUrl: url,
      httpHeaders: headers,
      fit: fit,
      width: fit == BoxFit.fitWidth ? double.infinity : null,
      alignment: Alignment.topCenter,
      memCacheWidth: memWidth,
      placeholder: (_, __) => AspectRatio(
        aspectRatio: 0.7,
        child: Container(
          color: _readerTheme.backgroundColor,
          child: const Center(
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Color(0xFFFF6740),
            ),
          ),
        ),
      ),
      errorWidget: (_, __, ___) => Container(
        height: 300,
        color: Colors.black26,
        child: const Center(
          child: Icon(Icons.broken_image_rounded, color: Colors.white38, size: 48),
        ),
      ),
    );
  }
}
