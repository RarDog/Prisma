import 'package:flutter/material.dart';

/// Floating action bar displayed at the bottom of the feed when posts are selected.
class FeedBatchActionBar extends StatelessWidget {
  const FeedBatchActionBar({
    required this.count,
    required this.onFavorite,
    required this.onCollection,
    required this.onClear,
    super.key,
  });

  final int count;
  final VoidCallback onFavorite;
  final VoidCallback onCollection;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [
              BoxShadow(color: Colors.black26, blurRadius: 16),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                Text(
                  '$count selected',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const Spacer(),
                IconButton.filledTonal(
                  tooltip: 'Favorite selected',
                  onPressed: onFavorite,
                  icon: const Icon(Icons.favorite_rounded),
                ),
                const SizedBox(width: 8),
                FilledButton.tonalIcon(
                  onPressed: onCollection,
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Collection'),
                ),
                IconButton(
                  tooltip: 'Clear',
                  onPressed: onClear,
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
