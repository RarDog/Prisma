import 'dart:io';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:gel_rule_app/app/app.dart';
import 'package:gel_rule_app/app/app_version.dart';
import 'package:gel_rule_app/app/responsive.dart';
import 'package:gel_rule_app/app/router.dart';
import 'package:gel_rule_app/backend/backend.dart';
import 'package:gel_rule_app/core/utils/result.dart';
import 'package:gel_rule_app/features/feed/presentation/feed_controller.dart';
import 'package:gel_rule_app/features/settings/presentation/settings_controller.dart';
import 'package:gel_rule_app/features/settings/presentation/settings_screen.dart';
import 'app_destination.dart';
import 'circular_reveal_page_route.dart';
import 'liquid_glass_bottom_bar.dart';
import 'desktop_shortcuts_dialog.dart';
import 'keyboard_shortcut_utils.dart';

class AppShell extends ConsumerStatefulWidget {
  const AppShell({
    required this.child,
    this.navigationShell,
    super.key,
  });

  final Widget child;
  final StatefulNavigationShell? navigationShell;

  static const destinations = [
    AppDestination(
      'feed',
      'Feed',
      Icons.dashboard_outlined,
      '/',
      selectedIcon: Icons.dashboard_rounded,
    ),
    AppDestination(
      'search',
      'History',
      Icons.history_rounded,
      '/search',
      selectedIcon: Icons.history_rounded,
      mobileLabel: 'History',
    ),
    AppDestination(
      'favorites',
      'Favorites',
      Icons.favorite_border_rounded,
      '/favorites',
      selectedIcon: Icons.favorite_rounded,
    ),
    AppDestination(
      'viewed',
      'Viewed',
      Icons.history_toggle_off_rounded,
      '/viewed',
      selectedIcon: Icons.history_rounded,
    ),
    AppDestination(
      'collections',
      'Collections',
      Icons.collections_bookmark_outlined,
      '/collections',
      selectedIcon: Icons.collections_bookmark_rounded,
      mobileLabel: 'Boards',
    ),
    AppDestination(
      'artists',
      'Artists',
      Icons.person_search_outlined,
      '/artists',
      selectedIcon: Icons.person_search_rounded,
    ),
    AppDestination(
      'manga',
      'Manga',
      Icons.menu_book_outlined,
      '/manga',
      selectedIcon: Icons.menu_book_rounded,
      mobileLabel: 'Manga',
    ),
    AppDestination(
      'providers',
      'Providers',
      Icons.hub_outlined,
      '/providers',
      selectedIcon: Icons.hub_rounded,
    ),
    AppDestination(
      'settings',
      'Settings',
      Icons.settings_outlined,
      '/settings',
      selectedIcon: Icons.settings_rounded,
    ),
  ];

  static int branchIndexForLocation(String location) {
    if (location.startsWith('/settings')) return 8;
    if (location.startsWith('/providers')) return 7;
    if (location.startsWith('/manga')) return 6;
    if (location.startsWith('/artists')) return 5;
    if (location.startsWith('/collections')) return 4;
    if (location.startsWith('/viewed')) return 3;
    if (location.startsWith('/favorites')) return 2;
    if (location.startsWith('/search')) return 1;
    return 0;
  }

  static String locationForBranchIndex(int index) {
    return switch (index) {
      1 => '/search',
      2 => '/favorites',
      3 => '/viewed',
      4 => '/collections',
      5 => '/artists',
      6 => '/manga',
      7 => '/providers',
      8 => '/settings',
      _ => '/',
    };
  }

  static List<AppDestination> _visibleDestinations(
    AppSettings settings,
    bool hasArtists, {
    bool isDesktop = false,
  }) {
    final isDesktopPlatform =
        !kIsWeb && (Platform.isLinux || Platform.isWindows || Platform.isMacOS);
    return destinations.where((item) {
      if (settings.hiddenTabs.contains(item.id)) return false;
      if (item.id == 'artists' && !hasArtists) return false;
      if (item.id == 'manga' && (isDesktop || isDesktopPlatform)) return false;
      return true;
    }).toList(growable: false);
  }

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  final List<String> _tabHistory = [];
  String? _currentPath;
  bool _isBackNavigating = false;
  bool _restoredTab = false;
  late final AppLifecycleListener _lifecycleListener;

  @override
  void initState() {
    super.initState();
    _lifecycleListener = AppLifecycleListener(
      onStateChange: (state) {
        if (state == AppLifecycleState.paused ||
            state == AppLifecycleState.inactive ||
            state == AppLifecycleState.detached) {
          _saveCurrentLocation();
        }
      },
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final settings = ref.read(appSettingsProvider).value;
      _maybeRestoreLastActiveTab(settings);
    });
  }

  @override
  void dispose() {
    _lifecycleListener.dispose();
    super.dispose();
  }

  void _saveCurrentLocation([String? location]) {
    final loc = location ??
        _currentPath ??
        (widget.navigationShell != null
            ? AppShell.locationForBranchIndex(
                widget.navigationShell!.currentIndex)
            : '/');
    if (loc.startsWith('/settings')) return;
    ref.read(settingsServiceProvider).saveLastActiveLocation(loc);
  }

  void _maybeRestoreLastActiveTab(AppSettings? settings) {
    if (_restoredTab || settings == null) return;
    final lastLocation = settings.lastActiveLocation;
    final isDesktopPlatform =
        !kIsWeb && (Platform.isLinux || Platform.isWindows || Platform.isMacOS);
    if (lastLocation.isNotEmpty &&
        lastLocation != '/' &&
        !lastLocation.startsWith('/settings') &&
        (!isDesktopPlatform || !lastLocation.startsWith('/manga'))) {
      final idx = AppShell.branchIndexForLocation(lastLocation);
      if (idx > 0 && idx < 8 && widget.navigationShell != null) {
        _restoredTab = true;
        widget.navigationShell!.goBranch(idx, initialLocation: false);
      }
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final path = GoRouterState.of(context).uri.path;
    _syncPath(path);
  }

  @override
  void didUpdateWidget(covariant AppShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    final path = GoRouterState.of(context).uri.path;
    _syncPath(path);
  }

  void _syncPath(String path) {
    if (_isBackNavigating) {
      _isBackNavigating = false;
      _currentPath = path;
      return;
    }
    if (_currentPath != null && _currentPath != path) {
      if (path == '/') {
        _tabHistory.clear();
      } else {
        _tabHistory.remove(_currentPath);
        _tabHistory.add(_currentPath!);
        if (_tabHistory.length > 25) {
          _tabHistory.removeAt(0);
        }
      }
    }
    _currentPath = path;
    _saveCurrentLocation(path);
  }

  void _openSettingsWithReveal([Offset? center]) {
    final media = MediaQuery.of(context);
    final fallbackCenter = Offset(
      media.size.width - 42.0,
      media.size.height - media.padding.bottom - 46.0,
    );
    Navigator.of(context, rootNavigator: true).push(
      CircularRevealPageRoute(
        centerOffset: center ?? fallbackCenter,
        builder: (_) => const SettingsScreen(),
      ),
    );
  }

  void _onNavigate(String location) {
    if (location == '/settings') {
      _openSettingsWithReveal();
      return;
    }
    final targetIndex = AppShell.branchIndexForLocation(location);
    if (widget.navigationShell != null) {
      if (widget.navigationShell!.currentIndex == targetIndex) {
        final keys = ref.read(branchNavKeysProvider);
        if (targetIndex < keys.length) {
          keys[targetIndex].currentState?.popUntil((route) => route.isFirst);
        }
      } else {
        widget.navigationShell!.goBranch(
          targetIndex,
          initialLocation: false,
        );
      }
    } else {
      context.go(location);
    }
    _saveCurrentLocation(location);
  }

  bool _handleBack() {
    final shell = widget.navigationShell;
    if (shell != null) {
      final keys = ref.read(branchNavKeysProvider);
      final currentBranchKey =
          shell.currentIndex < keys.length ? keys[shell.currentIndex] : null;
      if (currentBranchKey?.currentState?.canPop() ?? false) {
        currentBranchKey?.currentState?.pop();
        return true;
      }
    } else if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
      return true;
    }

    final currentPath = GoRouterState.of(context).uri.path;
    while (_tabHistory.isNotEmpty && _tabHistory.last == currentPath) {
      _tabHistory.removeLast();
    }

    if (_tabHistory.isNotEmpty) {
      final previous = _tabHistory.removeLast();
      _isBackNavigating = true;
      _onNavigate(previous);
      return true;
    }

    if (currentPath != '/' && (shell == null || shell.currentIndex != 0)) {
      _isBackNavigating = true;
      _onNavigate('/');
      return true;
    }

    return false;
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<AppSettings>>(appSettingsProvider, (prev, next) {
      next.whenData((settings) {
        _maybeRestoreLastActiveTab(settings);
      });
    });

    final settings =
        ref.watch(appSettingsProvider).value ?? AppSettings.defaults;
    final artistConfigs =
        ref.watch(_enabledArtistConfigsProvider).value ?? const [];
    final isDesktop = Responsive.isDesktop(context);
    final destinations = AppShell._visibleDestinations(
      settings,
      artistConfigs.isNotEmpty,
      isDesktop: isDesktop,
    );
    final ru = settings.languageCode == 'ru';

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        final handled = _handleBack();
        if (!handled) {
          SystemNavigator.pop();
        }
      },
      child: Shortcuts(
        shortcuts: {
          LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyF):
              const _NavigateIntent('/search'),
          LogicalKeySet(LogicalKeyboardKey.escape): const _BackIntent(),
          // Ctrl + 1..8
          LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.digit1):
              const _NavigateIntent('/'),
          LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.digit2):
              const _NavigateIntent('/search'),
          LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.digit3):
              const _NavigateIntent('/favorites'),
          LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.digit4):
              const _NavigateIntent('/viewed'),
          LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.digit5):
              const _NavigateIntent('/collections'),
          LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.digit6):
              const _NavigateIntent('/artists'),
          LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.digit7):
              const _NavigateIntent('/providers'),
          LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.digit8):
              const _NavigateIntent('/settings'),
          // Alt + 1..8
          LogicalKeySet(LogicalKeyboardKey.alt, LogicalKeyboardKey.digit1):
              const _NavigateIntent('/'),
          LogicalKeySet(LogicalKeyboardKey.alt, LogicalKeyboardKey.digit2):
              const _NavigateIntent('/search'),
          LogicalKeySet(LogicalKeyboardKey.alt, LogicalKeyboardKey.digit3):
              const _NavigateIntent('/favorites'),
          LogicalKeySet(LogicalKeyboardKey.alt, LogicalKeyboardKey.digit4):
              const _NavigateIntent('/viewed'),
          LogicalKeySet(LogicalKeyboardKey.alt, LogicalKeyboardKey.digit5):
              const _NavigateIntent('/collections'),
          LogicalKeySet(LogicalKeyboardKey.alt, LogicalKeyboardKey.digit6):
              const _NavigateIntent('/artists'),
          LogicalKeySet(LogicalKeyboardKey.alt, LogicalKeyboardKey.digit7):
              const _NavigateIntent('/providers'),
          LogicalKeySet(LogicalKeyboardKey.alt, LogicalKeyboardKey.digit8):
              const _NavigateIntent('/settings'),
          // Tab cycling
          LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.tab):
              const _CycleTabIntent(forward: true),
          LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.shift,
              LogicalKeyboardKey.tab): const _CycleTabIntent(forward: false),
          // Refresh
          LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyR):
              const _RefreshIntent(),
          LogicalKeySet(LogicalKeyboardKey.f5): const _RefreshIntent(),
          // Shortcuts help cheat sheet
          LogicalKeySet(LogicalKeyboardKey.question): const _HelpIntent(),
          LogicalKeySet(LogicalKeyboardKey.f1): const _HelpIntent(),
          LogicalKeySet(LogicalKeyboardKey.shift, LogicalKeyboardKey.slash):
              const _HelpIntent(),
        },
        child: Actions(
          actions: {
            _NavigateIntent: NonTextInputAction<_NavigateIntent>(
              onInvoke: (intent) {
                _onNavigate(intent.location);
                return null;
              },
            ),
            _BackIntent: NonTextInputAction<_BackIntent>(
              onInvoke: (_) {
                _handleBack();
                return null;
              },
            ),
            _CycleTabIntent: NonTextInputAction<_CycleTabIntent>(
              onInvoke: (intent) {
                if (destinations.isEmpty) return null;
                final currentBranch = widget.navigationShell?.currentIndex ?? 0;
                final currentIdx = destinations.indexWhere(
                  (d) =>
                      AppShell.branchIndexForLocation(d.location) ==
                      currentBranch,
                );
                final safeIdx = currentIdx < 0 ? 0 : currentIdx;
                final nextIdx = intent.forward
                    ? ((safeIdx + 1) % destinations.length)
                    : ((safeIdx - 1 + destinations.length) %
                        destinations.length);
                _onNavigate(destinations[nextIdx].location);
                return null;
              },
            ),
            _RefreshIntent: NonTextInputAction<_RefreshIntent>(
              onInvoke: (_) {
                ref.read(feedControllerProvider.notifier).refresh();
                return null;
              },
            ),
            _HelpIntent: NonTextInputAction<_HelpIntent>(
              onInvoke: (_) {
                DesktopShortcutsDialog.show(context);
                return null;
              },
            ),
          },
          child: Focus(
            autofocus: true,
            child: Responsive.isDesktop(context)
                ? _DesktopShell(
                    destinations: destinations,
                    ru: ru,
                    currentBranchIndex: widget.navigationShell?.currentIndex,
                    onNavigate: _onNavigate,
                    child: widget.child,
                  )
                : _MobileShell(
                    destinations: destinations,
                    ru: ru,
                    currentBranchIndex: widget.navigationShell?.currentIndex,
                    onNavigate: _onNavigate,
                    child: widget.child,
                  ),
          ),
        ),
      ),
    );
  }
}

class _DesktopShell extends ConsumerStatefulWidget {
  const _DesktopShell({
    required this.child,
    required this.destinations,
    required this.ru,
    required this.onNavigate,
    this.currentBranchIndex,
  });

  final Widget child;
  final List<AppDestination> destinations;
  final bool ru;
  final ValueChanged<String> onNavigate;
  final int? currentBranchIndex;

  @override
  ConsumerState<_DesktopShell> createState() => _DesktopShellState();
}

class _DesktopShellState extends ConsumerState<_DesktopShell>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;
  bool _hovered = false;
  bool _pinned = false;

  @override
  void initState() {
    super.initState();
    final initialPinned =
        ref.read(appSettingsProvider).valueOrNull?.desktopSidebarPinned ??
            false;
    _pinned = initialPinned;
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
      value: initialPinned ? 1.0 : 0.0,
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleHover(bool hovered) {
    if (_hovered == hovered) return;
    setState(() => _hovered = hovered);
    if (_pinned) return;
    if (hovered) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
  }

  void _togglePinned() {
    final nextPinned = !_pinned;
    setState(() {
      _pinned = nextPinned;
      if (_pinned) {
        _controller.forward();
      } else if (!_hovered) {
        _controller.reverse();
      }
    });

    final currentSettings = ref.read(settingsControllerProvider).valueOrNull ??
        AppSettings.defaults;
    ref.read(settingsControllerProvider.notifier).saveSettings(
          currentSettings.copyWith(desktopSidebarPinned: nextPinned),
        );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final location = GoRouterState.of(context).uri.path;
    final activeBranch =
        widget.currentBranchIndex ?? AppShell.branchIndexForLocation(location);
    final selected = widget.destinations.indexWhere(
      (item) => AppShell.branchIndexForLocation(item.location) == activeBranch,
    );

    return Scaffold(
      body: Row(
        children: [
          MouseRegion(
            onEnter: (_) => _handleHover(true),
            onExit: (_) => _handleHover(false),
            child: AnimatedBuilder(
              animation: _animation,
              builder: (context, _) {
                final progress = _animation.value;
                final width = lerpDouble(74.0, 260.0, progress)!;
                final contentOpacity =
                    (progress - 0.25).clamp(0.0, 0.75) / 0.75;
                final isFullyExpanded = progress > 0.85;

                return Container(
                  width: width,
                  decoration: BoxDecoration(
                    color:
                        isDark ? scheme.surfaceContainerHigh : scheme.surface,
                    border: Border(
                      right: BorderSide(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.1)
                            : scheme.outlineVariant.withValues(alpha: 0.35),
                        width: 1,
                      ),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color:
                            Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
                        blurRadius: 16,
                        offset: const Offset(3, 0),
                      ),
                    ],
                  ),
                  child: ClipRect(
                    child: OverflowBox(
                      minWidth: 260,
                      maxWidth: 260,
                      alignment: Alignment.topLeft,
                      child: SizedBox(
                        width: 260,
                        child: SafeArea(
                          child: Column(
                            children: [
                              // App Brand Header
                              Padding(
                                padding:
                                    const EdgeInsets.fromLTRB(15, 16, 12, 14),
                                child: SizedBox(
                                  height: 44,
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 44,
                                        height: 44,
                                        decoration: BoxDecoration(
                                          borderRadius:
                                              BorderRadius.circular(14),
                                          boxShadow: [
                                            BoxShadow(
                                              color: scheme.primary
                                                  .withValues(alpha: 0.25),
                                              blurRadius: 10,
                                              offset: const Offset(0, 2),
                                            ),
                                          ],
                                        ),
                                        child: ClipRRect(
                                          borderRadius:
                                              BorderRadius.circular(14),
                                          child: Image.asset(
                                            'assets/icon/app_icon_rounded.png',
                                            width: 44,
                                            height: 44,
                                            fit: BoxFit.cover,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Opacity(
                                          opacity: contentOpacity,
                                          child: Row(
                                            children: [
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.center,
                                                  children: [
                                                    Text(
                                                      'Prisma',
                                                      maxLines: 1,
                                                      softWrap: false,
                                                      style: theme
                                                          .textTheme.titleMedium
                                                          ?.copyWith(
                                                        fontWeight:
                                                            FontWeight.w800,
                                                        letterSpacing: 0.2,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 2),
                                                    Container(
                                                      padding: const EdgeInsets
                                                          .symmetric(
                                                        horizontal: 6,
                                                        vertical: 1.5,
                                                      ),
                                                      decoration: BoxDecoration(
                                                        color: scheme.primary
                                                            .withValues(
                                                                alpha: 0.15),
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(6),
                                                        border: Border.all(
                                                          color: scheme.primary
                                                              .withValues(
                                                                  alpha: 0.3),
                                                          width: 0.8,
                                                        ),
                                                      ),
                                                      child: Text(
                                                        'v$appDisplayVersion',
                                                        style: TextStyle(
                                                          fontSize: 10,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          color: scheme.primary,
                                                          letterSpacing: 0.4,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              IconButton(
                                                visualDensity:
                                                    VisualDensity.compact,
                                                tooltip: _pinned
                                                    ? (widget.ru
                                                        ? 'Открепить панель'
                                                        : 'Unpin panel')
                                                    : (widget.ru
                                                        ? 'Закрепить панель'
                                                        : 'Pin panel'),
                                                onPressed: _togglePinned,
                                                icon: Icon(
                                                  _pinned
                                                      ? Icons.push_pin_rounded
                                                      : Icons.push_pin_outlined,
                                                  size: 19,
                                                  color: _pinned
                                                      ? scheme.primary
                                                      : scheme.onSurfaceVariant,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const Divider(height: 1),
                              const SizedBox(height: 8),

                              // Destinations List
                              Expanded(
                                child: ListView(
                                  padding:
                                      const EdgeInsets.symmetric(horizontal: 8),
                                  children: [
                                    for (var index = 0;
                                        index < widget.destinations.length;
                                        index++)
                                      _RailButton(
                                        destination: widget.destinations[index],
                                        ru: widget.ru,
                                        selected:
                                            (selected < 0 ? 0 : selected) ==
                                                index,
                                        contentOpacity: contentOpacity,
                                        isFullyExpanded: isFullyExpanded,
                                        shortcutKey: 'Ctrl+${index + 1}',
                                        onTap: () {
                                          widget.onNavigate(widget
                                              .destinations[index].location);
                                        },
                                      ),
                                  ],
                                ),
                              ),

                              // Bottom Actions
                              const Divider(height: 1),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 8),
                                child: SizedBox(
                                  width: 244,
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Tooltip(
                                          message: isFullyExpanded
                                              ? ''
                                              : (widget.ru
                                                  ? 'Горячие клавиши (F1 / ?)'
                                                  : 'Keyboard Shortcuts (F1 / ?)'),
                                          waitDuration:
                                              const Duration(milliseconds: 350),
                                          child: Material(
                                            color: Colors.transparent,
                                            borderRadius:
                                                BorderRadius.circular(14),
                                            clipBehavior: Clip.antiAlias,
                                            child: InkWell(
                                              onTap: () =>
                                                  DesktopShortcutsDialog.show(
                                                      context),
                                              child: SizedBox(
                                                height: 44,
                                                child: Row(
                                                  children: [
                                                    SizedBox(
                                                      width: 58,
                                                      child: Icon(
                                                        Icons.keyboard_rounded,
                                                        size: 22,
                                                        color: scheme
                                                            .onSurfaceVariant,
                                                      ),
                                                    ),
                                                    Expanded(
                                                      child: Opacity(
                                                        opacity: contentOpacity,
                                                        child: Row(
                                                          children: [
                                                            Expanded(
                                                              child: Text(
                                                                widget.ru
                                                                    ? 'Горячие клавиши'
                                                                    : 'Shortcuts',
                                                                maxLines: 1,
                                                                softWrap: false,
                                                                overflow:
                                                                    TextOverflow
                                                                        .ellipsis,
                                                                style:
                                                                    TextStyle(
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w600,
                                                                  fontSize: 13,
                                                                  color: scheme
                                                                      .onSurface,
                                                                ),
                                                              ),
                                                            ),
                                                            Container(
                                                              padding:
                                                                  const EdgeInsets
                                                                      .symmetric(
                                                                horizontal: 6,
                                                                vertical: 2,
                                                              ),
                                                              decoration:
                                                                  BoxDecoration(
                                                                color: isDark
                                                                    ? Colors
                                                                        .white
                                                                        .withValues(
                                                                            alpha:
                                                                                0.1)
                                                                    : Colors
                                                                        .black
                                                                        .withValues(
                                                                            alpha:
                                                                                0.06),
                                                                borderRadius:
                                                                    BorderRadius
                                                                        .circular(
                                                                            6),
                                                              ),
                                                              child: const Text(
                                                                '?',
                                                                style:
                                                                    TextStyle(
                                                                  fontSize: 11,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .bold,
                                                                  fontFamily:
                                                                      'monospace',
                                                                ),
                                                              ),
                                                            ),
                                                            const SizedBox(
                                                                width: 8),
                                                          ],
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                      if (!_pinned && progress < 0.4)
                                        IconButton(
                                          tooltip: widget.ru
                                              ? 'Закрепить панель'
                                              : 'Pin sidebar',
                                          onPressed: _togglePinned,
                                          icon: const Icon(
                                              Icons.chevron_right_rounded,
                                              size: 20),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          Expanded(child: widget.child),
        ],
      ),
    );
  }
}

class _RailButton extends StatelessWidget {
  const _RailButton({
    required this.destination,
    required this.selected,
    required this.contentOpacity,
    required this.isFullyExpanded,
    required this.ru,
    required this.shortcutKey,
    required this.onTap,
  });

  final AppDestination destination;
  final bool selected;
  final double contentOpacity;
  final bool isFullyExpanded;
  final bool ru;
  final String shortcutKey;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final label = destination.labelFor(ru);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Tooltip(
        message: isFullyExpanded ? '' : '$label ($shortcutKey)',
        waitDuration: const Duration(milliseconds: 350),
        child: Material(
          color: selected
              ? scheme.primary.withValues(alpha: isDark ? 0.22 : 0.12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: SizedBox(
              width: 244,
              height: 46,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: selected
                      ? Border.all(
                          color: scheme.primary
                              .withValues(alpha: isDark ? 0.45 : 0.28),
                          width: 1.1,
                        )
                      : null,
                ),
                child: Row(
                  children: [
                    // Active left indicator bar
                    Container(
                      width: 3.5,
                      height: 22,
                      decoration: BoxDecoration(
                        color: selected ? scheme.primary : Colors.transparent,
                        borderRadius: BorderRadius.circular(2),
                        boxShadow: selected
                            ? [
                                BoxShadow(
                                  color: scheme.primary.withValues(alpha: 0.6),
                                  blurRadius: 6,
                                ),
                              ]
                            : null,
                      ),
                    ),
                    SizedBox(
                      width: 54.5,
                      child: Center(
                        child: Icon(
                          selected
                              ? destination.effectiveSelectedIcon
                              : destination.icon,
                          size: 22,
                          color: selected
                              ? scheme.primary
                              : (isDark
                                  ? scheme.onSurfaceVariant
                                      .withValues(alpha: 0.85)
                                  : scheme.onSurfaceVariant),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Opacity(
                        opacity: contentOpacity,
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                label,
                                maxLines: 1,
                                softWrap: false,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: selected
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                  color: selected
                                      ? scheme.primary
                                      : scheme.onSurface,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 5.5,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? Colors.white.withValues(alpha: 0.08)
                                    : Colors.black.withValues(alpha: 0.05),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: isDark
                                      ? Colors.white.withValues(alpha: 0.12)
                                      : Colors.black.withValues(alpha: 0.08),
                                  width: 0.8,
                                ),
                              ),
                              child: Text(
                                shortcutKey,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'monospace',
                                  color: selected
                                      ? scheme.primary
                                      : scheme.onSurfaceVariant
                                          .withValues(alpha: 0.8),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class ShellBottomBarVisibilityNotifier extends Notifier<bool> {
  int _activeHideCount = 0;

  @override
  bool build() => false;

  void pushHide() {
    _activeHideCount++;
    if (!state) state = true;
  }

  void popHide() {
    if (_activeHideCount > 0) {
      _activeHideCount--;
    }
    final shouldHide = _activeHideCount > 0;
    if (state != shouldHide) {
      state = shouldHide;
    }
  }
}

final shellHideBottomBarProvider =
    NotifierProvider<ShellBottomBarVisibilityNotifier, bool>(
  ShellBottomBarVisibilityNotifier.new,
);

class _MobileShell extends ConsumerStatefulWidget {
  const _MobileShell({
    required this.child,
    required this.destinations,
    required this.ru,
    required this.onNavigate,
    this.currentBranchIndex,
  });
  final Widget child;
  final List<AppDestination> destinations;
  final bool ru;
  final ValueChanged<String> onNavigate;
  final int? currentBranchIndex;

  @override
  ConsumerState<_MobileShell> createState() => _MobileShellState();
}

class _MobileShellState extends ConsumerState<_MobileShell>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  late final Animation<double> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
      value: 1.0,
    );
    _slideAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _openSettingsWithReveal([Offset? center]) {
    final media = MediaQuery.of(context);
    final fallbackCenter = Offset(
      media.size.width - 42.0,
      media.size.height - media.padding.bottom - 46.0,
    );
    Navigator.of(context, rootNavigator: true).push(
      CircularRevealPageRoute(
        centerOffset: center ?? fallbackCenter,
        builder: (_) => const SettingsScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<bool>(shellHideBottomBarProvider, (previous, hide) {
      if (hide) {
        _animController.reverse();
      } else {
        _animController.forward();
      }
    });

    final shouldHide = ref.watch(shellHideBottomBarProvider);
    if (shouldHide &&
        _animController.status != AnimationStatus.reverse &&
        _animController.value > 0) {
      _animController.reverse();
    } else if (!shouldHide &&
        _animController.status != AnimationStatus.forward &&
        _animController.value < 1.0) {
      _animController.forward();
    }

    final items = widget.destinations
        .where((item) =>
            item.location != '/providers' && item.location != '/settings')
        .toList();
    final location = GoRouterState.of(context).uri.path;
    final activeBranch =
        widget.currentBranchIndex ?? AppShell.branchIndexForLocation(location);
    final selected = items.indexWhere(
      (item) => AppShell.branchIndexForLocation(item.location) == activeBranch,
    );
    final isKeyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;

    return Scaffold(
      extendBody: true,
      body: AnimatedBuilder(
        animation: _slideAnimation,
        builder: (context, child) {
          final maxInset = 76.0 + MediaQuery.paddingOf(context).bottom;
          final currentBottomInset = isKeyboardOpen
              ? 0.0
              : lerpDouble(0.0, maxInset, _slideAnimation.value)!;
          return MediaQuery(
            data: MediaQuery.of(context).copyWith(
              viewInsets: MediaQuery.of(context).viewInsets.copyWith(bottom: 0),
              padding: MediaQuery.of(context).padding.copyWith(
                    bottom: currentBottomInset,
                  ),
            ),
            child: child!,
          );
        },
        child: widget.child,
      ),
      floatingActionButton: isKeyboardOpen
          ? null
          : AnimatedBuilder(
              animation: _slideAnimation,
              builder: (context, child) {
                if (_slideAnimation.value == 0.0) {
                  return const SizedBox.shrink();
                }
                return Transform.translate(
                  offset: Offset(0, (1.0 - _slideAnimation.value) * 80.0),
                  child: Opacity(
                    opacity: _slideAnimation.value.clamp(0.0, 1.0),
                    child: child,
                  ),
                );
              },
              child: Padding(
                padding: const EdgeInsets.only(bottom: 0, right: 2),
                child: LiquidGlassSettingsButton(
                  ru: widget.ru,
                  onTapWithCenter: (center) => _openSettingsWithReveal(center),
                ),
              ),
            ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      bottomNavigationBar: isKeyboardOpen
          ? null
          : AnimatedBuilder(
              animation: _slideAnimation,
              builder: (context, child) {
                if (_slideAnimation.value == 0.0) {
                  return const SizedBox.shrink();
                }
                return Transform.translate(
                  offset: Offset(0, (1.0 - _slideAnimation.value) * 110.0),
                  child: Opacity(
                    opacity: _slideAnimation.value.clamp(0.0, 1.0),
                    child: child,
                  ),
                );
              },
              child: LiquidGlassBottomBar(
                selectedIndex: selected < 0 ? 0 : selected,
                onDestinationSelected: (index) =>
                    widget.onNavigate(items[index].location),
                items: items,
                ru: widget.ru,
              ),
            ),
    );
  }
}

final _enabledArtistConfigsProvider =
    FutureProvider<List<ContentProviderConfig>>((ref) async {
  ref.watch(appSettingsProvider);
  final result = await ref
      .watch(providerManagerProvider)
      .loadArtistConfigs(enabledOnly: true);
  return result is Success<List<ContentProviderConfig>>
      ? result.data
      : const [];
});

class _NavigateIntent extends Intent {
  const _NavigateIntent(this.location);
  final String location;
}

class _BackIntent extends Intent {
  const _BackIntent();
}

class _CycleTabIntent extends Intent {
  const _CycleTabIntent({required this.forward});
  final bool forward;
}

class _RefreshIntent extends Intent {
  const _RefreshIntent();
}

class _HelpIntent extends Intent {
  const _HelpIntent();
}
