import 'package:flutter_riverpod/flutter_riverpod.dart';

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


