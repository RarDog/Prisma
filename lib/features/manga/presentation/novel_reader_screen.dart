import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gel_rule_app/core/http/app_headers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:gel_rule_app/backend/backend.dart';
import 'package:gel_rule_app/sources/booru/mangadex_provider.dart';
import '../domain/manga_library_providers.dart';
import '../domain/reader_navigation_helper.dart';
import 'mixins/reader_fullscreen_mixin.dart';

enum NovelReaderTheme {
  light,
  sepia,
  dark,
  oled,
}

class NovelReaderScreen extends ConsumerStatefulWidget {
  const NovelReaderScreen({
    required this.mangaId,
    required this.chapter,
    required this.allChapters,
    required this.title,
    required this.providerId,
    super.key,
  });

  final String mangaId;
  final MangaDexChapter chapter;
  final List<MangaDexChapter> allChapters;
  final String title;
  final String providerId;

  @override
  ConsumerState<NovelReaderScreen> createState() => _NovelReaderScreenState();
}

class _NovelReaderScreenState extends ConsumerState<NovelReaderScreen>
    with ReaderFullscreenMixin<NovelReaderScreen> {
  final ScrollController _scrollController = ScrollController();

  late MangaDexChapter _currentChapter;
  late int _currentChapterIndex;

  String _content = '';
  bool _loading = true;
  String? _error;
  bool get _showControls => !isReaderFullscreen;

  // Typography settings
  double _fontSize = 17.0;
  double _lineHeight = 1.6;
  final String _fontFamily = 'Sans';
  NovelReaderTheme _theme = NovelReaderTheme.dark;

  @override
  void initState() {
    super.initState();
    initReaderFullscreen();
    _currentChapter = widget.chapter;
    _currentChapterIndex = widget.allChapters.indexWhere((c) => c.id == widget.chapter.id);
    if (_currentChapterIndex == -1) _currentChapterIndex = 0;

    _loadContent();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    disposeReaderFullscreen();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.hasClients && _scrollController.position.maxScrollExtent > 0) {
      final progress = (_scrollController.position.pixels / _scrollController.position.maxScrollExtent).clamp(0.0, 1.0);
      if (progress >= 0.85) {
        _markRead();
      }
    }
  }

  Future<void> _markRead() async {
    try {
      final lib = ref.read(mangaLibraryServiceProvider);
      await lib.saveProgress(
        mangaId: widget.mangaId,
        providerId: widget.providerId,
        title: widget.title,
        coverUrl: '',
        chapterId: _currentChapter.id,
        chapterNumber: _currentChapter.chapterNumber,
        pageIndex: 1,
        totalPages: 1,
        markChapterComplete: true,
      );
    } catch (_) {}
  }

  Future<void> _loadContent() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      // 1. If chapter already has content attached
      if (_currentChapter.textContent != null && _currentChapter.textContent!.isNotEmpty) {
        if (mounted) {
          setState(() {
            _content = _currentChapter.textContent!;
            _loading = false;
          });
          _markRead();
        }
        return;
      }

      // 2. Check offline storage
      final offlineService = ref.read(mangaOfflineServiceProvider);
      final offlineText = await offlineService.getDownloadedNovelContent(widget.mangaId, _currentChapter.id);
      if (offlineText != null && offlineText.isNotEmpty) {
        if (mounted) {
          setState(() {
            _content = offlineText;
            _loading = false;
          });
          _markRead();
        }
        return;
      }

      // 3. Fetch from provider
      final providerManager = ref.read(providerManagerProvider);
      final p = await providerManager.getProviderInstance(widget.providerId);
      final NovelChapterProvider? novelProv =
          p is NovelChapterProvider ? (p as NovelChapterProvider) : null;
      if (novelProv != null) {
        final text = await novelProv.fetchChapterContent(_currentChapter.id);
        if (text.isNotEmpty) {
          if (mounted) {
            setState(() {
              _content = text;
              _loading = false;
            });
            _markRead();
          }
          return;
        }
      }

      if (mounted) {
        setState(() {
          _error = 'Не удалось загрузить текст главы';
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  void _switchChapter(int newIndex) {
    if (newIndex < 0 || newIndex >= widget.allChapters.length) return;
    HapticFeedback.selectionClick();
    setState(() {
      _currentChapterIndex = newIndex;
      _currentChapter = widget.allChapters[newIndex];
    });
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(0);
    }
    _loadContent();
  }

  Color get _backgroundColor => switch (_theme) {
        NovelReaderTheme.light => const Color(0xFFFFFFFF),
        NovelReaderTheme.sepia => const Color(0xFFFBF0D9),
        NovelReaderTheme.dark => const Color(0xFF1E1E1E),
        NovelReaderTheme.oled => const Color(0xFF000000),
      };

  Color get _textColor => switch (_theme) {
        NovelReaderTheme.light => const Color(0xFF1A1A1A),
        NovelReaderTheme.sepia => const Color(0xFF43301F),
        NovelReaderTheme.dark => const Color(0xFFE2E2E2),
        NovelReaderTheme.oled => const Color(0xFFD4D4D4),
      };

  Color get _barColor => switch (_theme) {
        NovelReaderTheme.light => const Color(0xFFEEEEEE),
        NovelReaderTheme.sepia => const Color(0xFFEFE2C6),
        NovelReaderTheme.dark => const Color(0xFF282828),
        NovelReaderTheme.oled => const Color(0xFF121212),
      };

  TextStyle? get _effectiveFont => switch (_fontFamily) {
        'Serif' => TextStyle(fontFamily: 'serif', fontSize: _fontSize, height: _lineHeight, color: _textColor),
        'Mono' => TextStyle(fontFamily: 'monospace', fontSize: _fontSize, height: _lineHeight, color: _textColor),
        _ => TextStyle(fontSize: _fontSize, height: _lineHeight, color: _textColor),
      };

  List<Widget> _buildContentWidgets() {
    if (_content.isEmpty) return const [];

    final regex = RegExp(r'!\[.*?\]\((https?://[^\s\)]+)\)');
    final matches = regex.allMatches(_content);

    if (matches.isEmpty) {
      return [
        SelectableText(
          _content,
          style: _effectiveFont,
        ),
      ];
    }

    final widgets = <Widget>[];
    int lastEnd = 0;

    for (final match in matches) {
      if (match.start > lastEnd) {
        final text = _content.substring(lastEnd, match.start).trim();
        if (text.isNotEmpty) {
          widgets.add(
            SelectableText(
              text,
              style: _effectiveFont,
            ),
          );
          widgets.add(const SizedBox(height: 16));
        }
      }

      final imageUrl = match.group(1);
      if (imageUrl != null && imageUrl.isNotEmpty) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: CachedNetworkImage(
                  imageUrl: imageUrl,
                  httpHeaders: AppHeaders.browserHeaders(
                    referer: 'https://ranobelib.me/',
                  ),
                  fit: BoxFit.contain,
                  placeholder: (_, __) => Container(
                    height: 250,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Center(
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                  errorWidget: (_, __, ___) => const SizedBox.shrink(),
                ),
              ),
            ),
          ),
        );
      }

      lastEnd = match.end;
    }

    if (lastEnd < _content.length) {
      final text = _content.substring(lastEnd).trim();
      if (text.isNotEmpty) {
        widgets.add(
          SelectableText(
            text,
            style: _effectiveFont,
          ),
        );
      }
    }

    return widgets;
  }

  @override
  Widget build(BuildContext context) {
    final hasPrev = ReaderNavigationHelper.hasPrevious(
      currentIndex: _currentChapterIndex,
      totalCount: widget.allChapters.length,
    );
    final hasNext = ReaderNavigationHelper.hasNext(
      currentIndex: _currentChapterIndex,
      totalCount: widget.allChapters.length,
    );

    return Scaffold(
      backgroundColor: _backgroundColor,
      body: Stack(
        children: [
          // Content
          GestureDetector(
            onTap: toggleReaderFullscreen,
            child: SafeArea(
              child: _loading
                  ? Center(child: CircularProgressIndicator(color: _textColor))
                  : _error != null
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.error_outline, size: 48, color: Colors.redAccent.withValues(alpha: 0.8)),
                              const SizedBox(height: 12),
                              Text(_error!, style: TextStyle(color: _textColor)),
                              const SizedBox(height: 12),
                              ElevatedButton(
                                onPressed: _loadContent,
                                child: const Text('Повторить'),
                              ),
                            ],
                          ),
                        )
                      : Scrollbar(
                          controller: _scrollController,
                          child: SingleChildScrollView(
                            controller: _scrollController,
                            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 32),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _currentChapter.title.isNotEmpty
                                      ? _currentChapter.title
                                      : 'Глава ${_currentChapter.chapterNumber}',
                                  style: TextStyle(
                                    fontSize: _fontSize + 6,
                                    fontWeight: FontWeight.bold,
                                    color: _textColor,
                                  ),
                                ),
                                const SizedBox(height: 24),
                                ..._buildContentWidgets(),
                                const SizedBox(height: 48),
                                // Bottom chapter nav buttons
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    ElevatedButton.icon(
                                      onPressed: hasPrev ? () => _switchChapter(_currentChapterIndex - 1) : null,
                                      icon: const Icon(Icons.arrow_back),
                                      label: const Text('Пред. глава'),
                                    ),
                                    ElevatedButton.icon(
                                      onPressed: hasNext ? () => _switchChapter(_currentChapterIndex + 1) : null,
                                      icon: const Icon(Icons.arrow_forward),
                                      label: const Text('След. глава'),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 60),
                              ],
                            ),
                          ),
                        ),
            ),
          ),

          // Top Bar
          if (_showControls)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                color: _barColor.withValues(alpha: 0.95),
                child: SafeArea(
                  bottom: false,
                  child: Row(
                    children: [
                      IconButton(
                        icon: Icon(Icons.arrow_back, color: _textColor),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              widget.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: _textColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                            Text(
                              'Глава ${_currentChapter.chapterNumber}',
                              style: TextStyle(
                                color: _textColor.withValues(alpha: 0.7),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.format_size, color: _textColor),
                        onPressed: _showSettingsSheet,
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // Bottom Bar
          if (_showControls)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                color: _barColor.withValues(alpha: 0.95),
                child: SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          icon: Icon(Icons.skip_previous, color: hasPrev ? _textColor : _textColor.withValues(alpha: 0.3)),
                          onPressed: hasPrev ? () => _switchChapter(_currentChapterIndex - 1) : null,
                        ),
                        Text(
                          ReaderNavigationHelper.formatChapterProgress(
                            currentIndex: _currentChapterIndex,
                            totalCount: widget.allChapters.length,
                          ),
                          style: TextStyle(color: _textColor.withValues(alpha: 0.7), fontSize: 13),
                        ),
                        IconButton(
                          icon: Icon(Icons.skip_next, color: hasNext ? _textColor : _textColor.withValues(alpha: 0.3)),
                          onPressed: hasNext ? () => _switchChapter(_currentChapterIndex + 1) : null,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _showSettingsSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: _barColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Настройки чтения',
                    style: TextStyle(color: _textColor, fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 16),
                  // Font size slider
                  Row(
                    children: [
                      Icon(Icons.text_fields, color: _textColor, size: 18),
                      const SizedBox(width: 8),
                      Text('Размер: ${_fontSize.round()}', style: TextStyle(color: _textColor)),
                      Expanded(
                        child: Slider(
                          value: _fontSize,
                          min: 12,
                          max: 30,
                          divisions: 18,
                          onChanged: (val) {
                            setSheetState(() => _fontSize = val);
                            setState(() => _fontSize = val);
                          },
                        ),
                      ),
                    ],
                  ),
                  // Line height slider
                  Row(
                    children: [
                      Icon(Icons.format_line_spacing, color: _textColor, size: 18),
                      const SizedBox(width: 8),
                      Text('Интервал: ${_lineHeight.toStringAsFixed(1)}', style: TextStyle(color: _textColor)),
                      Expanded(
                        child: Slider(
                          value: _lineHeight,
                          min: 1.2,
                          max: 2.4,
                          divisions: 12,
                          onChanged: (val) {
                            setSheetState(() => _lineHeight = val);
                            setState(() => _lineHeight = val);
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Theme buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: NovelReaderTheme.values.map((t) {
                      final isSel = _theme == t;
                      final label = switch (t) {
                        NovelReaderTheme.light => 'Светлая',
                        NovelReaderTheme.sepia => 'Сепия',
                        NovelReaderTheme.dark => 'Тёмная',
                        NovelReaderTheme.oled => 'OLED',
                      };
                      return ChoiceChip(
                        label: Text(label),
                        selected: isSel,
                        onSelected: (_) {
                          setSheetState(() => _theme = t);
                          setState(() => _theme = t);
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
