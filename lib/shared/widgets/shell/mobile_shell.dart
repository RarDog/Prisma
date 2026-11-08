import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:gel_rule_app/features/settings/presentation/settings_screen.dart';
import '../app_destination.dart';
import '../app_shell.dart';
import '../circular_reveal_page_route.dart';
import '../liquid_glass_bottom_bar.dart';

class MobileShell extends ConsumerStatefulWidget {
  const MobileShell({
    super.key,
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
  ConsumerState<MobileShell> createState() => MobileShellState();
}

class MobileShellState extends ConsumerState<MobileShell>
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
        .where((item) => item.location != '/providers')
        .toList();
    final settingsIndex = items.indexWhere((item) => item.id == 'settings');
    final location = GoRouterState.of(context).uri.path;
    final activeBranch =
        widget.currentBranchIndex ?? AppShell.branchIndexForLocation(location);
    final selected = items.indexWhere(
      (item) => AppShell.branchIndexForLocation(item.location) == activeBranch,
    );
    final media = MediaQuery.of(context);
    final isKeyboardOpen = media.viewInsets.bottom > 0;
    final bottomInset = isKeyboardOpen ? 0.0 : (76.0 + media.padding.bottom);

    return Scaffold(
      extendBody: true,
      body: MediaQuery(
        data: media.copyWith(
          viewInsets: media.viewInsets.copyWith(bottom: 0),
          padding: media.padding.copyWith(bottom: bottomInset),
        ),
        child: widget.child,
      ),
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
                settingsIndex: settingsIndex >= 0 ? settingsIndex : null,
                onSettingsTap: _openSettingsWithReveal,
              ),
            ),
    );
  }
}
