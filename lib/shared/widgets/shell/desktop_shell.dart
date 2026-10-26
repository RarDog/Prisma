import 'dart:ui' show ImageFilter, lerpDouble;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:gel_rule_app/app/app.dart';
import 'package:gel_rule_app/app/app_version.dart';
import 'package:gel_rule_app/backend/backend.dart';
import 'package:gel_rule_app/features/settings/presentation/settings_controller.dart';
import '../app_destination.dart';
import '../app_shell.dart';
import 'desktop_rail_widgets.dart';

class DesktopShell extends ConsumerStatefulWidget {
  const DesktopShell({
    super.key,
    required this.child,
    required this.destinations,
    required this.ru,
    required this.onNavigate,
    this.currentBranchIndex,
    this.position = 'left',
  });

  final Widget child;
  final List<AppDestination> destinations;
  final bool ru;
  final ValueChanged<String> onNavigate;
  final int? currentBranchIndex;
  final String position;

  @override
  ConsumerState<DesktopShell> createState() => DesktopShellState();
}

class DesktopShellState extends ConsumerState<DesktopShell>
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
    final isRight = widget.position == 'right';

    final sidebarWidget = MouseRegion(
      onEnter: (_) => _handleHover(true),
      onExit: (_) => _handleHover(false),
      child: AnimatedBuilder(
        animation: _animation,
        builder: (context, _) {
          final progress = _animation.value;
          final width = lerpDouble(74.0, 260.0, progress)!;
          final contentOpacity = (progress - 0.25).clamp(0.0, 0.75) / 0.75;
          final isFullyExpanded = progress > 0.85;

          final isAmoled = isDark &&
              (theme.scaffoldBackgroundColor == const Color(0xFF000000) ||
                  scheme.surface == const Color(0xFF000000));

          final borderSide = BorderSide(
            color: isAmoled
                ? Colors.white.withValues(alpha: 0.14)
                : isDark
                    ? Colors.white.withValues(alpha: 0.10)
                    : scheme.outlineVariant.withValues(alpha: 0.35),
            width: 1,
          );

          return Container(
            width: width,
            decoration: BoxDecoration(
              border: Border(
                left: isRight ? borderSide : BorderSide.none,
                right: !isRight ? borderSide : BorderSide.none,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(
                    alpha: isAmoled ? 0.45 : (isDark ? 0.30 : 0.06),
                  ),
                  blurRadius: 20,
                  offset: Offset(isRight ? -3 : 3, 0),
                ),
                if (isDark)
                  BoxShadow(
                    color: scheme.primary
                        .withValues(alpha: isAmoled ? 0.08 : 0.04),
                    blurRadius: 24,
                    offset: Offset(isRight ? -1 : 1, 0),
                  ),
              ],
            ),
            child: ClipRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: isAmoled
                          ? [
                              const Color(0xFF141414).withValues(alpha: 0.88),
                              const Color(0xFF040404).withValues(alpha: 0.94),
                            ]
                          : isDark
                              ? [
                                  scheme.surfaceContainerHigh
                                      .withValues(alpha: 0.72),
                                  scheme.surface.withValues(alpha: 0.84),
                                ]
                              : [
                                  Colors.white.withValues(alpha: 0.88),
                                  scheme.surface.withValues(alpha: 0.76),
                                ],
                    ),
                  ),
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
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(
                                          color: isDark
                                              ? Colors.white
                                                  .withValues(alpha: 0.15)
                                              : Colors.white
                                                  .withValues(alpha: 0.8),
                                          width: 1.2,
                                        ),
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
                                        borderRadius: BorderRadius.circular(13),
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
                                                          BorderRadius.circular(
                                                              6),
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
                            Divider(
                              height: 1,
                              thickness: 1,
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.08)
                                  : scheme.outlineVariant
                                      .withValues(alpha: 0.25),
                            ),
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
                                    RailButton(
                                      destination: widget.destinations[index],
                                      ru: widget.ru,
                                      selected: (selected < 0 ? 0 : selected) ==
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
                            Divider(
                              height: 1,
                              thickness: 1,
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.08)
                                  : scheme.outlineVariant
                                      .withValues(alpha: 0.25),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 8),
                              child: SizedBox(
                                width: 244,
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: BottomShortcutsButton(
                                        isFullyExpanded: isFullyExpanded,
                                        contentOpacity: contentOpacity,
                                        ru: widget.ru,
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
              ),
            ),
          );
        },
      ),
    );

    return Scaffold(
      body: Row(
        children: [
          if (isRight) Expanded(child: widget.child),
          sidebarWidget,
          if (!isRight) Expanded(child: widget.child),
        ],
      ),
    );
  }
}


