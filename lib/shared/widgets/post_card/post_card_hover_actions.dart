import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:gel_rule_app/app/motion.dart';

/// Desktop hover overlay with quick action buttons (Favorite, Add to Collection, Hide).
class PostCardHoverActionsOverlay extends StatelessWidget {
  const PostCardHoverActionsOverlay({
    required this.hovered,
    required this.isMobile,
    required this.isFavorite,
    required this.onFavorite,
    this.onAddToCollection,
    this.onHide,
    super.key,
  });

  final bool hovered;
  final bool isMobile;
  final bool isFavorite;
  final VoidCallback onFavorite;
  final VoidCallback? onAddToCollection;
  final VoidCallback? onHide;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        ignoring: !hovered || isMobile,
        child: AnimatedOpacity(
          opacity: hovered && !isMobile ? 1 : 0,
          duration: AppMotion.duration(context, 140),
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.55),
                  Colors.transparent,
                ],
              ),
            ),
            child: Align(
              alignment: Alignment.bottomRight,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton.filledTonal(
                      tooltip: isFavorite ? 'Remove favorite' : 'Favorite',
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        onFavorite();
                      },
                      icon: Icon(
                        isFavorite
                            ? Icons.favorite_rounded
                            : Icons.favorite_border_rounded,
                      ),
                    ),
                    if (onAddToCollection != null) ...[
                      const SizedBox(width: 6),
                      IconButton.filledTonal(
                        tooltip: 'Add to collection',
                        onPressed: onAddToCollection,
                        icon: const Icon(Icons.add_rounded),
                      ),
                    ],
                    if (onHide != null) ...[
                      const SizedBox(width: 6),
                      IconButton.filledTonal(
                        tooltip: 'Hide post',
                        onPressed: onHide,
                        icon: const Icon(Icons.visibility_off_rounded),
                      ),
                    ],
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
