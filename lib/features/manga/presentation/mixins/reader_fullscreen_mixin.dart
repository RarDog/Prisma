import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gel_rule_app/shared/widgets/app_shell.dart';

/// Shared mixin for manga and novel reader screens managing fullscreen mode,
/// system UI overlays (status/navigation bars), and shell bottom bar visibility.
mixin ReaderFullscreenMixin<T extends ConsumerStatefulWidget> on ConsumerState<T> {
  bool _isReaderFullscreen = false;
  ShellBottomBarVisibilityNotifier? _shellBottomBarNotifier;
  bool _hasReleasedBottomBarHide = false;

  /// Whether the reader is currently in fullscreen mode.
  bool get isReaderFullscreen => _isReaderFullscreen;

  /// Initializes reader fullscreen capabilities, suppressing the app shell bottom bar.
  void initReaderFullscreen({bool initialFullscreen = false}) {
    _isReaderFullscreen = initialFullscreen;
    try {
      _shellBottomBarNotifier = ref.read(shellHideBottomBarProvider.notifier);
      _shellBottomBarNotifier?.pushHide();
    } catch (_) {}

    if (_isReaderFullscreen) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    }
  }

  /// Sets reader fullscreen state and synchronizes System UI mode.
  void setReaderFullscreen(bool fullscreen) {
    if (_isReaderFullscreen == fullscreen) return;
    setState(() {
      _isReaderFullscreen = fullscreen;
    });
    _syncSystemUi();
  }

  /// Toggles between fullscreen and normal reading mode.
  void toggleReaderFullscreen() {
    setReaderFullscreen(!_isReaderFullscreen);
  }

  void _syncSystemUi() {
    if (_isReaderFullscreen) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    } else {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
  }

  /// Restores shell bottom bar and resets System UI mode.
  void disposeReaderFullscreen() {
    if (!_hasReleasedBottomBarHide) {
      _hasReleasedBottomBarHide = true;
      try {
        _shellBottomBarNotifier?.popHide();
      } catch (_) {}
    }
    if (_isReaderFullscreen) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
  }
}
