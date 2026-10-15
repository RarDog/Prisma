import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:gel_rule_app/backend/backend.dart';

class RecentSearches extends StatefulWidget {
  const RecentSearches({
    required this.items,
    this.onTap,
    this.onItemTap,
    this.onDelete,
    super.key,
  });

  final List<SearchHistory> items;
  final ValueChanged<String>? onTap;
  final ValueChanged<SearchHistory>? onItemTap;
  final ValueChanged<String>? onDelete;

  @override
  State<RecentSearches> createState() => _RecentSearchesState();
}

class _RecentSearchesState extends State<RecentSearches> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isRu = Localizations.maybeLocaleOf(context)?.languageCode == 'ru';
    if (widget.items.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
        alignment: Alignment.center,
        child: Column(
          children: [
            Icon(
              Icons.history_toggle_off_rounded,
              size: 40,
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 10),
            Text(
              isRu ? 'История поиска пуста' : 'Search history is empty',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    // Deduplicate items by normalized query
    final seen = <String>{};
    final uniqueItems = <SearchHistory>[];
    for (final item in widget.items) {
      final key = item.query.trim().toLowerCase();
      if (key.isEmpty) continue;
      if (seen.add(key)) {
        uniqueItems.add(item);
      }
    }

    if (uniqueItems.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
        alignment: Alignment.center,
        child: Column(
          children: [
            Icon(
              Icons.history_toggle_off_rounded,
              size: 40,
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 10),
            Text(
              isRu ? 'История поиска пуста' : 'Search history is empty',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    final visibleItems =
        _expanded ? uniqueItems : uniqueItems.take(20).toList();
    final screenW = MediaQuery.sizeOf(context).width;
    final maxQueryWidth = (screenW - 200).clamp(180.0, 480.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final item in visibleItems)
              Material(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(16),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () {
                    HapticFeedback.selectionClick();
                    if (widget.onItemTap != null) {
                      widget.onItemTap!(item);
                    } else if (widget.onTap != null) {
                      widget.onTap!(item.query);
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.only(
                        left: 10, right: 6, top: 6, bottom: 6),
                    decoration: BoxDecoration(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? theme.colorScheme.surfaceContainerHighest
                              .withValues(alpha: 0.45)
                          : Colors.white.withValues(alpha: 0.65),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: item.providerId.isNotEmpty
                            ? _providerColor(item.providerId).withValues(
                                alpha: Theme.of(context).brightness ==
                                        Brightness.dark
                                    ? 0.35
                                    : 0.25)
                            : (Theme.of(context).brightness == Brightness.dark
                                ? Colors.white.withValues(alpha: 0.12)
                                : theme.colorScheme.outlineVariant
                                    .withValues(alpha: 0.35)),
                        width: 1.0,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(
                              alpha: Theme.of(context).brightness ==
                                      Brightness.dark
                                  ? 0.15
                                  : 0.04),
                          blurRadius: 6,
                          offset: const Offset(0, 1.5),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.history_rounded,
                          size: 15,
                          color: item.providerId.isNotEmpty
                              ? _providerColor(item.providerId)
                              : theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 6),
                        ConstrainedBox(
                          constraints: BoxConstraints(maxWidth: maxQueryWidth),
                          child: Tooltip(
                            message: item.query,
                            waitDuration: const Duration(milliseconds: 600),
                            child: Text(
                              item.query,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        if (item.providerId.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: _providerColor(item.providerId).withValues(
                                  alpha: Theme.of(context).brightness ==
                                          Brightness.dark
                                      ? 0.22
                                      : 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              item.providerName.isNotEmpty
                                  ? item.providerName
                                  : item.providerId,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: _providerColor(item.providerId),
                              ),
                            ),
                          ),
                        ],
                        if (item.resultCount > 0) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary
                                  .withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '${item.resultCount}',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.primary,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                        if (widget.onDelete != null) ...[
                          const SizedBox(width: 4),
                          Material(
                            color: Colors.transparent,
                            shape: const CircleBorder(),
                            clipBehavior: Clip.antiAlias,
                            child: InkWell(
                              customBorder: const CircleBorder(),
                              onTap: () {
                                HapticFeedback.lightImpact();
                                widget.onDelete!(item.id);
                              },
                              child: Padding(
                                padding: const EdgeInsets.all(4),
                                child: Icon(
                                  Icons.close_rounded,
                                  size: 15,
                                  color: theme.colorScheme.onSurfaceVariant
                                      .withValues(alpha: 0.75),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
        if (uniqueItems.length > 20) ...[
          const SizedBox(height: 10),
          Center(
            child: TextButton.icon(
              onPressed: () => setState(() => _expanded = !_expanded),
              icon: Icon(
                _expanded
                    ? Icons.unfold_less_rounded
                    : Icons.unfold_more_rounded,
                size: 16,
              ),
              label: Text(
                _expanded
                    ? (isRu ? 'Свернуть' : 'Collapse')
                    : (isRu
                        ? 'Показать все (${uniqueItems.length})'
                        : 'Show all (${uniqueItems.length})'),
              ),
            ),
          ),
        ],
      ],
    );
  }

  static Color _providerColor(String pid) {
    final lower = pid.toLowerCase();
    if (lower.contains('gelbooru')) return const Color(0xFF006ffa);
    if (lower.contains('danbooru')) return const Color(0xFFe45f34);
    if (lower.contains('e621')) return const Color(0xFF00549e);
    if (lower.contains('rule34')) return const Color(0xFF2e7d32);
    if (lower.contains('safebooru')) return const Color(0xFF10b981);
    if (lower.contains('realbooru')) return const Color(0xFF455a64);
    if (lower.contains('wallhaven')) return const Color(0xFF10b981);
    if (lower.contains('arena') || lower.contains('are.na')) {
      return const Color(0xFF6366F1);
    }
    if (lower.contains('mangalib') || lower.contains('manga')) {
      return const Color(0xFFE53935);
    }
    return const Color(0xFF8B5CF6);
  }
}
