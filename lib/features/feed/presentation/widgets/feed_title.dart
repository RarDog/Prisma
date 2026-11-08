import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:gel_rule_app/app/app.dart';

/// Interactive AppBar title for the Feed screen with expanding toolbar chevron.
class FeedTitle extends StatelessWidget {
  const FeedTitle({
    required this.toolbarVisible,
    required this.onToggle,
    super.key,
  });

  final ValueNotifier<bool> toolbarVisible;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isRu = Localizations.maybeLocaleOf(context)?.languageCode == 'ru';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onToggle,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Prisma',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(width: 8),
              Consumer(
                builder: (context, ref, _) => Text(
                  ref.watch(appStringsProvider).feed,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              ValueListenableBuilder<bool>(
                valueListenable: toolbarVisible,
                builder: (context, visible, _) {
                  return Tooltip(
                    message: visible
                        ? (isRu ? 'Свернуть панель' : 'Collapse toolbar')
                        : (isRu ? 'Развернуть панель' : 'Expand toolbar'),
                    child: AnimatedRotation(
                      turns: visible ? 0.0 : 0.5,
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeInOutCubic,
                      child: Icon(
                        Icons.keyboard_arrow_up_rounded,
                        size: 20,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
