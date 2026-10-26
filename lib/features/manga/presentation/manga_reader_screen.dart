import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:prisma_app/backend/backend.dart';
import 'package:prisma_app/features/post/presentation/widgets/post_media_viewer.dart';
import 'package:prisma_app/features/settings/presentation/settings_controller.dart';
import 'package:prisma_app/sources/manga/mangadex_provider.dart';
import '../domain/manga_library_providers.dart';
import '../domain/reader_navigation_helper.dart';
import 'mixins/reader_fullscreen_mixin.dart';
import 'widgets/manga_reader_app_bar.dart';
import 'widgets/manga_reader_page_image.dart';
import 'widgets/manga_reader_pickers.dart';
import 'widgets/manga_reader_settings_sheet.dart';
import 'widgets/manga_reader_slider_bar.dart';
import 'widgets/manga_reader_types.dart';
import 'widgets/manga_webtoon_view.dart';
import 'widgets/page_flip_3d.dart';

export 'widgets/manga_reader_app_bar.dart';
export 'widgets/manga_reader_page_image.dart';
export 'widgets/manga_reader_pickers.dart';
export 'widgets/manga_reader_settings_sheet.dart';
export 'widgets/manga_reader_slider_bar.dart';
export 'widgets/manga_reader_types.dart';
export 'widgets/manga_webtoon_view.dart';

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
    with WidgetsBindingObserver, ReaderFullscreenMixin<MangaReaderScreen> {
  static const MethodChannel _volumeChannel =
      MethodChannel('rulegel/volume_keys');
  final GlobalKey<PageFlip3DState> _flipKey = GlobalKey<PageFlip3DState>();
  final ScrollController _webtoonScrollController = ScrollController();

  bool get _isFullscreen => isReaderFullscreen;
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
  String? _prefetchedChapterId;

  Timer? _progressDebounce;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    initReaderFullscreen();

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
    final formats = (widget.post.tagGroups['format'] ?? [])
        .map((t) => t.toLowerCase())
        .toSet();
    final isLongStrip = tags.contains('long strip') ||
        tags.contains('web comic') ||
        tags.contains('webtoon') ||
        formats.contains('long strip') ||
        formats.contains('web comic');

    if (isLongStrip) {
      _readerMode = MangaReaderMode.webtoon;
    } else {
      try {
        final settings =
            ref.read(settingsControllerProvider).value ?? AppSettings.defaults;
        final bool effectiveRtl = widget.isRtl ?? settings.mangaReaderRtl;
        if (settings.mangaReadingMode == 'pagedLtr' || !effectiveRtl) {
          _readerMode = MangaReaderMode.pagedLtr;
        } else {
          _readerMode = MangaReaderMode.pagedRtl;
        }
      } catch (_) {
        _readerMode = (widget.isRtl == false)
            ? MangaReaderMode.pagedLtr
            : MangaReaderMode.pagedRtl;
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
        final offlinePages =
            await offlineService.getDownloadedPages(post.id, chapter.id);
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
              _chapters = _allChapters
                  .where((c) => c.language == _selectedLanguage)
                  .toList();
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
            final chapterPages =
                await mangaChapterProv.fetchChapterPages(chapter.id);
            if (chapterPages.isNotEmpty) {
              urls.addAll(chapterPages);
              _chapters[_currentChapterIndex] =
                  chapter.copyWith(pageCount: chapterPages.length);
            }
          }
        }
      } else if (post.childrenIds.isNotEmpty) {
        for (final childId in post.childrenIds) {
          urls.add(childId);
        }
      }

      if (urls.isEmpty) {
        final fallback =
            post.fileUrl.isNotEmpty ? post.fileUrl : post.sampleUrl;
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
          } else if (_webtoonScrollController.hasClients &&
              targetPage > 0 &&
              urls.isNotEmpty) {
            final maxScroll = _webtoonScrollController.position.maxScrollExtent;
            _webtoonScrollController
                .jumpTo((targetPage / (urls.length - 1)) * maxScroll);
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
            CachedNetworkImageProvider(url,
                headers: headers, maxWidth: memWidth),
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
        ReaderNavigationHelper.hasNext(
            currentIndex: _currentChapterIndex, totalCount: _chapters.length) &&
        widget.post.providerId == 'mangadex') {
      _prefetchNextChapterPages();
    }
  }

  Future<void> _prefetchNextChapterPages() async {
    final nextIdx = ReaderNavigationHelper.nextIndex(
      currentIndex: _currentChapterIndex,
      totalCount: _chapters.length,
    );
    if (nextIdx == null) return;
    final nextChapter = _chapters[nextIdx];
    if (_prefetchedChapterId == nextChapter.id) return;
    _prefetchedChapterId = nextChapter.id;

    try {
      final providerManager = ref.read(providerManagerProvider);
      final provider =
          await providerManager.getProviderInstance(widget.post.providerId);
      final MangaChapterProvider? mangaChapterProv =
          provider is MangaChapterProvider
              ? (provider as MangaChapterProvider)
              : null;
      if (mangaChapterProv != null) {
        final pages = await mangaChapterProv.fetchChapterPages(nextChapter.id);
        if (pages.isNotEmpty && mounted) {
          final headers = getPostMediaHeaders(widget.post);
          final memWidth = _targetMemCacheWidth;
          for (final pageUrl in pages.take(3)) {
            unawaited(precacheImage(
              CachedNetworkImageProvider(pageUrl,
                  headers: headers, maxWidth: memWidth),
              context,
            ));
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
      final currentChapter =
          _chapters.isNotEmpty && _currentChapterIndex < _chapters.length
              ? _chapters[_currentChapterIndex]
              : null;
      final coverUrl = widget.post.sampleUrl.isNotEmpty
          ? widget.post.sampleUrl
          : widget.post.previewUrl;
      ref.read(mangaLibraryServiceProvider).saveProgress(
            mangaId: widget.post.id,
            providerId: widget.post.providerId,
            title: widget.post.title ?? widget.post.tags.take(3).join(', '),
            coverUrl: coverUrl,
            chapterId: currentChapter?.id ?? '',
            chapterNumber: currentChapter?.chapterNumber ?? '1',
            pageIndex: _currentPage,
            totalPages: _pageUrls.length,
            markChapterComplete:
                _pageUrls.isNotEmpty && _currentPage >= _pageUrls.length - 1,
          );
    } catch (_) {}
  }

  void _switchChapter(int index, {bool startAtEnd = false}) {
    if (index == _currentChapterIndex ||
        index < 0 ||
        index >= _chapters.length) {
      return;
    }
    setState(() {
      _currentChapterIndex = index;
    });
    _loadPages(startAtEnd: startAtEnd);
  }

  void _onNextChapter() {
    final isRu = Localizations.maybeLocaleOf(context)?.languageCode == 'ru';
    if (ReaderNavigationHelper.hasNext(
        currentIndex: _currentChapterIndex, totalCount: _chapters.length)) {
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
            isRu
                ? 'Вы дочитали последнюю доступную главу тайтла!'
                : 'You have reached the last chapter!',
          ),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _onPreviousChapter() {
    if (ReaderNavigationHelper.hasPrevious(
        currentIndex: _currentChapterIndex, totalCount: _chapters.length)) {
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
    toggleReaderFullscreen();
  }

  void _releaseHide() {
    disposeReaderFullscreen();
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
    disposeReaderFullscreen();
    super.dispose();
  }

  void _openReaderSettingsSheet() {
    showMangaReaderSettingsSheet(
      context: context,
      currentMode: _readerMode,
      onModeChanged: (mode) {
        setState(() => _readerMode = mode);
        try {
          ref.read(settingsControllerProvider.notifier).saveMangaReaderSettings(
                readingMode: mode.name,
                isRtl: mode != MangaReaderMode.pagedLtr,
              );
        } catch (_) {}
      },
      currentTheme: _readerTheme,
      onThemeChanged: (theme) {
        setState(() => _readerTheme = theme);
      },
      volumeNavigationEnabled: _volumeNavigationEnabled,
      onVolumeNavigationChanged: (val) {
        setState(() => _volumeNavigationEnabled = val);
        if (val) {
          _enableVolumeNavigation();
        } else {
          _disableVolumeNavigation();
        }
        try {
          ref
              .read(settingsControllerProvider.notifier)
              .saveMangaVolumeNavigation(
                enabled: val,
                invert: _invertVolumeKeys,
              );
        } catch (_) {}
      },
      invertVolumeKeys: _invertVolumeKeys,
      onInvertVolumeKeysChanged: (val) {
        setState(() => _invertVolumeKeys = val);
        try {
          ref
              .read(settingsControllerProvider.notifier)
              .saveMangaVolumeNavigation(
                enabled: _volumeNavigationEnabled,
                invert: val,
              );
        } catch (_) {}
      },
      hasChapters: _chapters.isNotEmpty,
      onOpenChapterPicker: _openChapterPicker,
    );
  }

  void _openLanguagePicker() {
    showMangaLanguagePicker(
      context: context,
      availableLanguages: _availableLanguages,
      selectedLanguage: _selectedLanguage,
      allChapters: _allChapters,
      onLanguageSelected: (lang) {
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
  }

  void _openChapterPicker() {
    showMangaChapterPicker(
      context: context,
      chapters: _chapters,
      currentChapterIndex: _currentChapterIndex,
      onChapterSelected: (index) {
        _switchChapter(index);
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
        (_webtoonScrollController.offset - 450)
            .clamp(0.0, _webtoonScrollController.position.maxScrollExtent),
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
      );
    } else if (dy > height * 0.80 && _webtoonScrollController.hasClients) {
      // Bottom 20%: scroll down
      _webtoonScrollController.animateTo(
        (_webtoonScrollController.offset + 450)
            .clamp(0.0, _webtoonScrollController.position.maxScrollExtent),
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
    final currentChapter =
        _chapters.isNotEmpty ? _chapters[_currentChapterIndex] : null;

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
            : MangaReaderAppBar(
                title: widget.post.title ?? widget.post.tags.take(3).join(', '),
                currentChapter: currentChapter,
                currentPage: _currentPage,
                totalPages: totalPages,
                readerMode: _readerMode,
                availableLanguagesCount: _availableLanguages.length,
                selectedLanguage: _selectedLanguage,
                chaptersCount: _chapters.length,
                onBack: () {
                  _saveCurrentProgress();
                  Navigator.of(context).pop();
                },
                onOpenLanguagePicker: _openLanguagePicker,
                onOpenChapterPicker: _openChapterPicker,
                onToggleDirection: () {
                  HapticFeedback.selectionClick();
                  final newMode = _readerMode == MangaReaderMode.pagedRtl
                      ? MangaReaderMode.pagedLtr
                      : MangaReaderMode.pagedRtl;
                  setState(() => _readerMode = newMode);
                  try {
                    ref
                        .read(settingsControllerProvider.notifier)
                        .saveMangaReaderSettings(
                          readingMode: newMode.name,
                          isRtl: newMode == MangaReaderMode.pagedRtl,
                        );
                  } catch (_) {}
                },
                onOpenSettings: _openReaderSettingsSheet,
                onToggleFullscreen: _toggleFullscreen,
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
                      const Icon(Icons.error_outline_rounded,
                          color: Colors.redAccent, size: 48),
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
              Positioned.fill(
                child: MangaWebtoonView(
                  scrollController: _webtoonScrollController,
                  pageUrls: _pageUrls,
                  headers: headers,
                  readerTheme: _readerTheme,
                  currentChapter: currentChapter,
                  currentChapterIndex: _currentChapterIndex,
                  chaptersCount: _chapters.length,
                  nextChapterNumber: ReaderNavigationHelper.hasNext(
                          currentIndex: _currentChapterIndex,
                          totalCount: _chapters.length)
                      ? _chapters[_currentChapterIndex + 1].chapterNumber
                      : null,
                  targetMemCacheWidth: _targetMemCacheWidth,
                  onTapUp: _handleWebtoonTap,
                  onNextChapter: _onNextChapter,
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
                            child: MangaReaderPageImage(
                              url: url,
                              headers: headers,
                              fit: BoxFit.contain,
                              memWidth: _targetMemCacheWidth,
                              backgroundColor: _readerTheme.backgroundColor,
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
              MangaReaderSliderBar(
                currentPage: _currentPage,
                totalPages: totalPages,
                onPageChanged: (page) {
                  if (_readerMode == MangaReaderMode.webtoon) {
                    if (_webtoonScrollController.hasClients) {
                      final maxScroll =
                          _webtoonScrollController.position.maxScrollExtent;
                      _webtoonScrollController
                          .jumpTo((page / (totalPages - 1)) * maxScroll);
                    }
                  } else {
                    _flipKey.currentState?.jumpToPage(page);
                  }
                  setState(() => _currentPage = page);
                  _scheduleSaveProgress();
                },
              ),
          ],
        ),
      ),
    );
  }
}
