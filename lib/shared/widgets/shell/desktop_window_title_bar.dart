import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

class DesktopWindowTitleBar extends StatefulWidget {
  const DesktopWindowTitleBar({super.key});

  @override
  State<DesktopWindowTitleBar> createState() => _DesktopWindowTitleBarState();
}

class _DesktopWindowTitleBarState extends State<DesktopWindowTitleBar>
    with WindowListener {
  bool _isMaximized = false;
  bool _isFullScreen = false;

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    _checkWindowState();
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    super.dispose();
  }

  Future<void> _checkWindowState() async {
    try {
      final max = await windowManager.isMaximized();
      final fs = await windowManager.isFullScreen();
      if (mounted) {
        setState(() {
          _isMaximized = max;
          _isFullScreen = fs;
        });
      }
    } catch (_) {}
  }

  @override
  void onWindowMaximize() {
    if (mounted) setState(() => _isMaximized = true);
  }

  @override
  void onWindowUnmaximize() {
    if (mounted) setState(() => _isMaximized = false);
  }

  @override
  void onWindowEnterFullScreen() {
    if (mounted) setState(() => _isFullScreen = true);
  }

  @override
  void onWindowLeaveFullScreen() {
    if (mounted) setState(() => _isFullScreen = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_isFullScreen) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final bgColor = isDark
        ? const Color(0xFF141518)
        : theme.colorScheme.surface;

    return Container(
      height: 32,
      color: bgColor,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // App brand / Icon
          DragToMoveArea(
            child: Padding(
              padding: const EdgeInsets.only(left: 12, right: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset(
                    'assets/icon/app_icon.png',
                    width: 16,
                    height: 16,
                    errorBuilder: (_, __, ___) => Icon(
                      Icons.blur_on_rounded,
                      size: 16,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Prisma',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.2,
                      color: isDark ? Colors.white70 : Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Center drag area
          const Expanded(
            child: DragToMoveArea(
              child: SizedBox.expand(),
            ),
          ),
          // Window caption buttons (minimize, maximize/unmaximize, close)
          WindowCaptionButton.minimize(
            brightness: theme.brightness,
            onPressed: () async {
              final isMin = await windowManager.isMinimized();
              if (isMin) {
                await windowManager.restore();
              } else {
                await windowManager.minimize();
              }
            },
          ),
          _isMaximized
              ? WindowCaptionButton.unmaximize(
                  brightness: theme.brightness,
                  onPressed: () => windowManager.unmaximize(),
                )
              : WindowCaptionButton.maximize(
                  brightness: theme.brightness,
                  onPressed: () => windowManager.maximize(),
                ),
          WindowCaptionButton.close(
            brightness: theme.brightness,
            onPressed: () => windowManager.close(),
          ),
        ],
      ),
    );
  }
}
