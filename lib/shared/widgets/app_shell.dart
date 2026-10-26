import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:prisma_app/app/app.dart';
import 'package:prisma_app/app/responsive.dart';
import 'package:prisma_app/app/router.dart';
import 'package:prisma_app/backend/backend.dart';
import 'package:prisma_app/core/utils/result.dart';
import 'package:prisma_app/features/feed/presentation/feed_controller.dart';
import 'package:prisma_app/features/settings/presentation/settings_screen.dart';
import 'app_destination.dart';
import 'circular_reveal_page_route.dart';
import 'desktop_shortcuts_dialog.dart';
import 'keyboard_shortcut_utils.dart';
import 'shell/desktop_shell.dart';
import 'shell/mobile_shell.dart';
import 'shell/shell_shortcuts.dart';

export 'shell/shell_bottom_bar_controller.dart';
export 'shell/shell_shortcuts.dart';

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
              const NavigateIntent('/search'),
          LogicalKeySet(LogicalKeyboardKey.escape): const BackIntent(),
          // Ctrl + 1..8
          LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.digit1):
              const NavigateIntent('/'),
          LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.digit2):
              const NavigateIntent('/search'),
          LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.digit3):
              const NavigateIntent('/favorites'),
          LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.digit4):
              const NavigateIntent('/viewed'),
          LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.digit5):
              const NavigateIntent('/collections'),
          LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.digit6):
              const NavigateIntent('/artists'),
          LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.digit7):
              const NavigateIntent('/providers'),
          LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.digit8):
              const NavigateIntent('/settings'),
          // Alt + 1..8
          LogicalKeySet(LogicalKeyboardKey.alt, LogicalKeyboardKey.digit1):
              const NavigateIntent('/'),
          LogicalKeySet(LogicalKeyboardKey.alt, LogicalKeyboardKey.digit2):
              const NavigateIntent('/search'),
          LogicalKeySet(LogicalKeyboardKey.alt, LogicalKeyboardKey.digit3):
              const NavigateIntent('/favorites'),
          LogicalKeySet(LogicalKeyboardKey.alt, LogicalKeyboardKey.digit4):
              const NavigateIntent('/viewed'),
          LogicalKeySet(LogicalKeyboardKey.alt, LogicalKeyboardKey.digit5):
              const NavigateIntent('/collections'),
          LogicalKeySet(LogicalKeyboardKey.alt, LogicalKeyboardKey.digit6):
              const NavigateIntent('/artists'),
          LogicalKeySet(LogicalKeyboardKey.alt, LogicalKeyboardKey.digit7):
              const NavigateIntent('/providers'),
          LogicalKeySet(LogicalKeyboardKey.alt, LogicalKeyboardKey.digit8):
              const NavigateIntent('/settings'),
          // Tab cycling
          LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.tab):
              const CycleTabIntent(forward: true),
          LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.shift,
              LogicalKeyboardKey.tab): const CycleTabIntent(forward: false),
          // Refresh
          LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyR):
              const RefreshIntent(),
          LogicalKeySet(LogicalKeyboardKey.f5): const RefreshIntent(),
          // Shortcuts help cheat sheet
          LogicalKeySet(LogicalKeyboardKey.question): const HelpIntent(),
          LogicalKeySet(LogicalKeyboardKey.f1): const HelpIntent(),
          LogicalKeySet(LogicalKeyboardKey.shift, LogicalKeyboardKey.slash):
              const HelpIntent(),
        },
        child: Actions(
          actions: {
            NavigateIntent: NonTextInputAction<NavigateIntent>(
              onInvoke: (intent) {
                _onNavigate(intent.location);
                return null;
              },
            ),
            BackIntent: NonTextInputAction<BackIntent>(
              onInvoke: (_) {
                _handleBack();
                return null;
              },
            ),
            CycleTabIntent: NonTextInputAction<CycleTabIntent>(
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
            RefreshIntent: NonTextInputAction<RefreshIntent>(
              onInvoke: (_) {
                ref.read(feedControllerProvider.notifier).refresh();
                return null;
              },
            ),
            HelpIntent: NonTextInputAction<HelpIntent>(
              onInvoke: (_) {
                DesktopShortcutsDialog.show(context);
                return null;
              },
            ),
          },
          child: Focus(
            autofocus: true,
            child: Responsive.isDesktop(context)
                ? (settings.desktopNavPosition == 'bottom'
                    ? MobileShell(
                        destinations: destinations,
                        ru: ru,
                        currentBranchIndex:
                            widget.navigationShell?.currentIndex,
                        onNavigate: _onNavigate,
                        child: widget.child,
                      )
                    : DesktopShell(
                        destinations: destinations,
                        ru: ru,
                        currentBranchIndex:
                            widget.navigationShell?.currentIndex,
                        onNavigate: _onNavigate,
                        position: settings.desktopNavPosition,
                        child: widget.child,
                      ))
                : MobileShell(
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


