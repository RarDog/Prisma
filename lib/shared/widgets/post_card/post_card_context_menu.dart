import 'package:flutter/material.dart';

/// Displays desktop right-click context menu for a post card.
Future<void> showPostCardContextMenu({
  required BuildContext context,
  required Offset globalPosition,
  required VoidCallback onOpen,
  required VoidCallback onFavorite,
  VoidCallback? onAddToCollection,
  VoidCallback? onHide,
}) {
  return showMenu<void>(
    context: context,
    position: RelativeRect.fromLTRB(
      globalPosition.dx,
      globalPosition.dy,
      globalPosition.dx,
      globalPosition.dy,
    ),
    items: [
      PopupMenuItem(
        onTap: onOpen,
        child: const Text('Open'),
      ),
      PopupMenuItem(
        onTap: onFavorite,
        child: const Text('Favorite'),
      ),
      if (onAddToCollection != null)
        PopupMenuItem(
          onTap: onAddToCollection,
          child: const Text('Add to collection'),
        ),
      if (onHide != null)
        PopupMenuItem(
          onTap: onHide,
          child: const Text('Hide post'),
        ),
    ],
  );
}
