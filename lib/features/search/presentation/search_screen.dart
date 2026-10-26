import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:prisma_app/app/app.dart';
import 'package:prisma_app/features/feed/presentation/feed_controller.dart';
import 'package:prisma_app/features/search/models/search_history.dart';
import 'package:prisma_app/shared/widgets/adaptive_scaffold.dart';
import 'package:prisma_app/shared/widgets/confirm_dialog.dart';
import 'package:prisma_app/shared/widgets/error_view.dart';
import 'search_controller.dart';
import 'widgets/recent_searches.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({this.initialQuery, super.key});

  final String? initialQuery;

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final TextEditingBarController _searchBarController =
      TextEditingBarController();

  @override
  void initState() {
    super.initState();
    final query = widget.initialQuery?.trim();
    if (query != null && query.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(searchControllerProvider.notifier).updateQuery(query);
      });
    }
  }

  @override
  void didUpdateWidget(SearchScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    final query = widget.initialQuery?.trim();
    if (query != null &&
        query.isNotEmpty &&
        query != oldWidget.initialQuery?.trim()) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(searchControllerProvider.notifier).updateQuery(query);
      });
    }
  }

  Future<void> _onRecentHistoryItemTap(SearchHistory item) async {
    await HapticFeedback.selectionClick();
    if (item.providerId.isNotEmpty) {
      await ref
          .read(feedControllerProvider.notifier)
          .setProviders([item.providerId]);
    }
    if (mounted) {
      context.go('/?q=${Uri.encodeQueryComponent(item.query)}');
    }
  }

  void _onRecentSearchTap(String query) async {
    await HapticFeedback.selectionClick();
    if (mounted) {
      context.go('/?q=${Uri.encodeQueryComponent(query)}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(searchControllerProvider);
    final strings = ref.watch(appStringsProvider);
    final isRu = strings.ru;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return AdaptiveScaffold(
      title: isRu ? 'История' : 'History',
      actions: [
        IconButton(
          tooltip: isRu ? 'Очистить историю' : 'Clear history',
          onPressed: () async {
            final ok = await showConfirmDialog(
              context,
              title: isRu ? 'Очистить историю?' : 'Clear history?',
              message: isRu
                  ? 'Все недавние запросы и история поиска будут удалены.'
                  : 'All recent search queries and tag history will be cleared.',
            );
            if (ok) {
              await ref.read(searchControllerProvider.notifier).clearHistory();
            }
          },
          icon: const Icon(Icons.delete_sweep_rounded),
        ),
      ],
      body: state.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => ErrorView(message: error.toString()),
        data: (data) {
          final filteredRecent = data.filteredRecent;

          // Unique providers found in recent searches
          final availableProviders = <String, String>{};
          for (final r in data.recent) {
            if (r.providerId.isNotEmpty) {
              availableProviders[r.providerId] =
                  r.providerName.isNotEmpty ? r.providerName : r.providerId;
            }
          }

          return Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 860),
              child: ListView(
                padding: EdgeInsets.fromLTRB(16, 14, 16, 140 + bottomInset),
                children: [
                  // 1. Search Bar for History
                  _SearchLiquidCard(
                    glowColor: theme.colorScheme.primary,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            const _SearchIconBadge(
                              icon: Icons.history_rounded,
                              color: Color(0xFF6366F1),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    isRu
                                        ? 'Поиск по истории'
                                        : 'Search history',
                                    style:
                                        theme.textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 16,
                                      letterSpacing: -0.2,
                                    ),
                                  ),
                                  Text(
                                    isRu
                                        ? 'Недавние запросы с фильтрацией по источникам'
                                        : 'Recent queries with provider filtering',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Container(
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.black.withValues(alpha: 0.28)
                                : Colors.black.withValues(alpha: 0.04),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.12)
                                  : Colors.black.withValues(alpha: 0.08),
                            ),
                          ),
                          child: TextField(
                            controller: _searchBarController,
                            onChanged: (text) => ref
                                .read(searchControllerProvider.notifier)
                                .updateQuery(text),
                            onSubmitted: (text) {
                              if (text.trim().isNotEmpty) {
                                context.go(
                                    '/?q=${Uri.encodeQueryComponent(text.trim())}');
                              }
                            },
                            decoration: InputDecoration(
                              hintText: isRu
                                  ? 'Поиск по запросам или новый поиск...'
                                  : 'Search queries or enter new search...',
                              prefixIcon: const Icon(Icons.search_rounded),
                              suffixIcon: data.query.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(Icons.clear_rounded),
                                      onPressed: () {
                                        _searchBarController.clear();
                                        ref
                                            .read(searchControllerProvider
                                                .notifier)
                                            .updateQuery('');
                                      },
                                    )
                                  : null,
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 14,
                              ),
                            ),
                          ),
                        ),

                        // Providers Filter Row
                        if (availableProviders.isNotEmpty) ...[
                          const SizedBox(height: 14),
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                _ProviderFilterBadge(
                                  label: isRu ? 'Все источники' : 'All sources',
                                  isSelected:
                                      data.selectedProviderFilter == null,
                                  color: theme.colorScheme.primary,
                                  count: data.recent.length,
                                  onTap: () => ref
                                      .read(searchControllerProvider.notifier)
                                      .setProviderFilter(null),
                                ),
                                for (final entry
                                    in availableProviders.entries) ...[
                                  const SizedBox(width: 8),
                                  _ProviderFilterBadge(
                                    label: entry.value,
                                    isSelected: data.selectedProviderFilter ==
                                        entry.key,
                                    color: _providerColor(entry.key),
                                    count: data.recent
                                        .where((r) => r.providerId == entry.key)
                                        .length,
                                    onTap: () {
                                      final next =
                                          data.selectedProviderFilter ==
                                                  entry.key
                                              ? null
                                              : entry.key;
                                      ref
                                          .read(
                                              searchControllerProvider.notifier)
                                          .setProviderFilter(next);
                                    },
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // 2. Recent Search Queries Card
                  _SearchLiquidCard(
                    glowColor: const Color(0xFF8B5CF6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const _SearchIconBadge(
                              icon: Icons.manage_search_rounded,
                              color: Color(0xFF8B5CF6),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Flexible(
                                    child: Text(
                                      isRu
                                          ? 'Недавний поиск'
                                          : 'Recent searches',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style:
                                          theme.textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 16,
                                        letterSpacing: -0.2,
                                      ),
                                    ),
                                  ),
                                  if (filteredRecent.isNotEmpty) ...[
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF8B5CF6)
                                            .withValues(alpha: 0.16),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Text(
                                        '${filteredRecent.length}',
                                        style: theme.textTheme.labelSmall
                                            ?.copyWith(
                                          fontWeight: FontWeight.bold,
                                          color: const Color(0xFF8B5CF6),
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            if (data.recent.isNotEmpty)
                              TextButton(
                                style: TextButton.styleFrom(
                                  visualDensity: VisualDensity.compact,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 4),
                                  minimumSize: Size.zero,
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                                onPressed: () {
                                  HapticFeedback.selectionClick();
                                  ref
                                      .read(searchControllerProvider.notifier)
                                      .clearHistory();
                                },
                                child: Text(
                                  isRu ? 'Очистить' : 'Clear',
                                  style: TextStyle(
                                    color: theme.colorScheme.primary,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          isRu
                              ? 'Нажмите на запрос, чтобы открыть его сразу с нужным источником'
                              : 'Tap a query to open it directly with its provider',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 14),
                        if (filteredRecent.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 24),
                            child: Center(
                              child: Column(
                                children: [
                                  Icon(
                                    Icons.history_toggle_off_rounded,
                                    size: 40,
                                    color: theme.colorScheme.onSurfaceVariant
                                        .withValues(alpha: 0.5),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    isRu
                                        ? 'Нет недавних запросов'
                                        : 'No recent searches',
                                    style: TextStyle(
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        else
                          RecentSearches(
                            items: filteredRecent,
                            onItemTap: _onRecentHistoryItemTap,
                            onTap: _onRecentSearchTap,
                            onDelete: (id) => ref
                                .read(searchControllerProvider.notifier)
                                .deleteHistory(id),
                          ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  static Color _providerColor(String pid) {
    final lower = pid.toLowerCase();
    if (lower.contains('gelbooru')) return const Color(0xFF006ffa);
    if (lower.contains('danbooru')) return const Color(0xFFe45f34);
    if (lower.contains('e621')) return const Color(0xFF00549e);
    if (lower.contains('rule34_us') || lower.contains('rule34us')) {
      return const Color(0xFFE11D48);
    }
    if (lower.contains('rule34')) return const Color(0xFF2e7d32);
    if (lower.contains('tbib')) return const Color(0xFF2563EB);
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

class TextEditingBarController extends TextEditingController {}

class _ProviderFilterBadge extends StatelessWidget {
  const _ProviderFilterBadge({
    required this.label,
    required this.isSelected,
    required this.color,
    required this.count,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final Color color;
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: isSelected
                ? color.withValues(alpha: isDark ? 0.32 : 0.20)
                : (isDark
                    ? Colors.white.withValues(alpha: 0.05)
                    : Colors.black.withValues(alpha: 0.04)),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected
                  ? color
                  : (isDark
                      ? Colors.white.withValues(alpha: 0.12)
                      : Colors.black.withValues(alpha: 0.08)),
              width: isSelected ? 1.4 : 1.0,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected
                      ? (isDark ? Colors.white : color)
                      : theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(width: 5),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(
                  color: isSelected
                      ? color.withValues(alpha: 0.35)
                      : (isDark
                          ? Colors.white.withValues(alpha: 0.10)
                          : Colors.black.withValues(alpha: 0.08)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: isSelected
                        ? (isDark ? Colors.white : color)
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SearchLiquidCard extends StatelessWidget {
  const _SearchLiquidCard({
    required this.child,
    this.glowColor,
  });

  final Widget child;
  final Color? glowColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final accent = glowColor ?? theme.colorScheme.primary;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.35)
                : accent.withValues(alpha: 0.08),
            blurRadius: 18,
            offset: const Offset(0, 6),
            spreadRadius: -2,
          ),
          BoxShadow(
            color: accent.withValues(alpha: isDark ? 0.06 : 0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isDark
                    ? [
                        theme.colorScheme.surfaceContainerHigh
                            .withValues(alpha: 0.60),
                        theme.colorScheme.surfaceContainerLow
                            .withValues(alpha: 0.38),
                      ]
                    : [
                        Colors.white.withValues(alpha: 0.88),
                        Colors.white.withValues(alpha: 0.72),
                      ],
              ),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.14)
                    : Colors.white.withValues(alpha: 0.85),
                width: 1.2,
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

class _SearchIconBadge extends StatelessWidget {
  const _SearchIconBadge({
    required this.icon,
    required this.color,
  });

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    const size = 34.0;
    const iconSize = 18.0;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color,
            color.withValues(alpha: 0.86),
          ],
        ),
        borderRadius: BorderRadius.circular(size * 0.28),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.35),
            blurRadius: 7,
            offset: const Offset(0, 2.5),
          ),
        ],
      ),
      child: Center(
        child: Icon(icon, size: iconSize, color: Colors.white),
      ),
    );
  }
}
