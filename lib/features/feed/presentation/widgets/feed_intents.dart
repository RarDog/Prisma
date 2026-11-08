import 'package:flutter/widgets.dart';

/// Intent to refresh the current feed via keyboard shortcut (Ctrl+R / F5).
class FeedRefreshIntent extends Intent {
  const FeedRefreshIntent();
}

/// Intent to clear post selection via keyboard shortcut (Escape / Delete).
class FeedClearSelectionIntent extends Intent {
  const FeedClearSelectionIntent();
}

/// Intent to select all visible posts on the feed (Ctrl+A).
class FeedSelectVisibleIntent extends Intent {
  const FeedSelectVisibleIntent();
}

/// Intent to open a random post from the currently loaded list (R).
class FeedRandomPostIntent extends Intent {
  const FeedRandomPostIntent();
}

/// Intent to toggle post selection mode on and off (V).
class FeedToggleSelectionIntent extends Intent {
  const FeedToggleSelectionIntent();
}
