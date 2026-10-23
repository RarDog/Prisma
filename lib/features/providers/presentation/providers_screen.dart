import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:gel_rule_app/shared/widgets/confirm_dialog.dart';
import 'package:gel_rule_app/shared/widgets/error_view.dart';
import 'provider_check_screen.dart';
import 'provider_form_screen.dart';
import 'providers_controller.dart';
import 'widgets/provider_card.dart';

class ProvidersScreen extends ConsumerStatefulWidget {
  const ProvidersScreen({super.key});

  @override
  ConsumerState<ProvidersScreen> createState() => _ProvidersScreenState();
}

class _ProvidersScreenState extends ConsumerState<ProvidersScreen> {
  String _activeFilter = 'all'; // 'all', 'enabled', 'booru', 'art'
  String _searchQuery = '';
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool _isBooru(String apiType) {
    final lower = apiType.toLowerCase();
    return lower == 'gelbooru' ||
        lower == 'danbooru' ||
        lower == 'moebooru' ||
        lower == 'rule34' ||
        lower == 'rule34_us' ||
        lower == 'rule34us' ||
        lower == 'safebooru' ||
        lower == 'tbib' ||
        lower == 'paheal' ||
        lower == 'realbooru_html' ||
        lower == 'e621';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final isAmoled = isDark &&
        (theme.scaffoldBackgroundColor == const Color(0xFF000000) ||
            scheme.surface == const Color(0xFF000000));
    final isRu = Localizations.maybeLocaleOf(context)?.languageCode == 'ru';
    final providers = ref.watch(providersControllerProvider);
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(60),
        child: ClipRRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: AppBar(
              backgroundColor: isAmoled
                  ? const Color(0xFF0C0C0C).withValues(alpha: 0.85)
                  : (isDark
                      ? scheme.surface.withValues(alpha: 0.72)
                      : Colors.white.withValues(alpha: 0.82)),
              surfaceTintColor: Colors.transparent,
              elevation: 0,
              centerTitle: false,
              leading: Navigator.of(context).canPop()
                  ? IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new_rounded,
                          size: 20),
                      onPressed: () {
                        if (Navigator.of(context).canPop()) {
                          Navigator.of(context).pop();
                        } else {
                          context.go('/posts');
                        }
                      },
                      tooltip: isRu ? 'Назад' : 'Back',
                    )
                  : null,
              title: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: scheme.primary
                          .withValues(alpha: isDark ? 0.20 : 0.12),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: scheme.primary
                            .withValues(alpha: isDark ? 0.35 : 0.22),
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: scheme.primary.withValues(alpha: 0.20),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Icon(
                        Icons.hub_rounded,
                        size: 17,
                        color: scheme.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(
                      isRu ? 'Провайдеры' : 'Providers',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              actions: [
                // Provider Check Glass Button
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: Material(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () {
                        HapticFeedback.lightImpact();
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const ProviderCheckScreen(),
                          ),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: scheme.primary
                              .withValues(alpha: isDark ? 0.15 : 0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: scheme.primary
                                .withValues(alpha: isDark ? 0.30 : 0.18),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.network_check_rounded,
                              size: 15,
                              color: scheme.primary,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              isRu ? 'Проверка' : 'Check',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: scheme.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                // Add Provider Button
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: Material(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () {
                        HapticFeedback.lightImpact();
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const ProviderFormScreen(),
                          ),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 11, vertical: 6),
                        decoration: BoxDecoration(
                          color: scheme.primary,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: scheme.primary.withValues(alpha: 0.30),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.add_rounded,
                              size: 16,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              isRu ? 'Создать' : 'Add',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: providers.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => ErrorView(message: error.toString()),
        data: (rawItems) {
          final items = rawItems
              .where((p) => p.apiType != 'fapello' && p.id != 'fapello')
              .toList();
          final activeCount = items.where((p) => p.enabled).length;
          final booruCount = items.where((p) => _isBooru(p.apiType)).length;
          final artCount = items.where((p) => !_isBooru(p.apiType)).length;

          // Apply filter
          final filteredItems = items.where((p) {
            if (_activeFilter == 'enabled' && !p.enabled) return false;
            if (_activeFilter == 'booru' && !_isBooru(p.apiType)) return false;
            if (_activeFilter == 'art' && _isBooru(p.apiType)) return false;
            if (_searchQuery.isNotEmpty) {
              final q = _searchQuery.toLowerCase();
              final matchName = p.name.toLowerCase().contains(q);
              final matchType = p.apiType.toLowerCase().contains(q);
              final matchUrl = p.baseUrl.toLowerCase().contains(q);
              if (!matchName && !matchType && !matchUrl) return false;
            }
            return true;
          }).toList();

          return Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1060),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth >= 720;

                  return ListView(
                    padding: EdgeInsets.fromLTRB(
                      16,
                      MediaQuery.paddingOf(context).top + 68,
                      16,
                      130 + bottomInset,
                    ),
                    children: [
                      // Overview Glass Card
                      Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(18),
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: isAmoled
                                ? [
                                    const Color(0xFF141414)
                                        .withValues(alpha: 0.85),
                                    const Color(0xFF080808)
                                        .withValues(alpha: 0.90),
                                  ]
                                : isDark
                                    ? [
                                        scheme.surfaceContainerHigh
                                            .withValues(alpha: 0.65),
                                        scheme.surfaceContainerLow
                                            .withValues(alpha: 0.40),
                                      ]
                                    : [
                                        Colors.white.withValues(alpha: 0.90),
                                        Colors.white.withValues(alpha: 0.75),
                                      ],
                          ),
                          border: Border.all(
                            color: isAmoled
                                ? Colors.white.withValues(alpha: 0.14)
                                : isDark
                                    ? Colors.white.withValues(alpha: 0.10)
                                    : Colors.white.withValues(alpha: 0.85),
                            width: 1.1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(
                                alpha: isDark ? 0.20 : 0.04,
                              ),
                              blurRadius: 14,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    isRu
                                        ? 'Управление источниками'
                                        : 'Provider Management',
                                    style: theme.textTheme.titleSmall?.copyWith(
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: -0.2,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    isRu
                                        ? 'Подключение к API, ключи и приоритеты booru-сервисов'
                                        : 'Configure connections, API keys and priorities',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: scheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: const Color(0xFF10B981)
                                    .withValues(alpha: isDark ? 0.16 : 0.10),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: const Color(0xFF10B981)
                                      .withValues(alpha: isDark ? 0.35 : 0.24),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 6,
                                    height: 6,
                                    decoration: const BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Color(0xFF10B981),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    '$activeCount / ${items.length} ${isRu ? 'вкл' : 'on'}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF10B981),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Filter Capsules & Search Row
                      Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            _FilterPill(
                              label: isRu
                                  ? 'Все (${items.length})'
                                  : 'All (${items.length})',
                              selected: _activeFilter == 'all',
                              onTap: () =>
                                  setState(() => _activeFilter = 'all'),
                              isDark: isDark,
                            ),
                            _FilterPill(
                              label: isRu
                                  ? 'Включены ($activeCount)'
                                  : 'Active ($activeCount)',
                              selected: _activeFilter == 'enabled',
                              onTap: () =>
                                  setState(() => _activeFilter = 'enabled'),
                              isDark: isDark,
                            ),
                            _FilterPill(
                              label: 'Booru ($booruCount)',
                              selected: _activeFilter == 'booru',
                              onTap: () =>
                                  setState(() => _activeFilter = 'booru'),
                              isDark: isDark,
                            ),
                            _FilterPill(
                              label: isRu
                                  ? 'Арт / Манга ($artCount)'
                                  : 'Art / Manga ($artCount)',
                              selected: _activeFilter == 'art',
                              onTap: () =>
                                  setState(() => _activeFilter = 'art'),
                              isDark: isDark,
                            ),

                            // Search toggle button
                            Material(
                              color: Colors.transparent,
                              borderRadius: BorderRadius.circular(10),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(10),
                                onTap: () {
                                  setState(() {
                                    _isSearching = !_isSearching;
                                    if (!_isSearching) {
                                      _searchController.clear();
                                      _searchQuery = '';
                                    }
                                  });
                                },
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 160),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 5),
                                  decoration: BoxDecoration(
                                    color:
                                        _isSearching || _searchQuery.isNotEmpty
                                            ? scheme.primary.withValues(
                                                alpha: isDark ? 0.22 : 0.12)
                                            : (isDark
                                                ? Colors.white
                                                    .withValues(alpha: 0.05)
                                                : Colors.black
                                                    .withValues(alpha: 0.04)),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: _isSearching ||
                                              _searchQuery.isNotEmpty
                                          ? scheme.primary.withValues(
                                              alpha: isDark ? 0.45 : 0.30)
                                          : (isDark
                                              ? Colors.white
                                                  .withValues(alpha: 0.08)
                                              : Colors.black
                                                  .withValues(alpha: 0.06)),
                                      width: 1,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.search_rounded,
                                        size: 15,
                                        color: _isSearching ||
                                                _searchQuery.isNotEmpty
                                            ? scheme.primary
                                            : scheme.onSurfaceVariant,
                                      ),
                                      if (_isSearching ||
                                          _searchQuery.isNotEmpty) ...[
                                        const SizedBox(width: 4),
                                        Text(
                                          isRu ? 'Поиск' : 'Search',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: scheme.primary,
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
                      ),

                      // Optional search bar
                      if (_isSearching)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Container(
                            height: 38,
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.06)
                                  : Colors.black.withValues(alpha: 0.04),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: scheme.primary
                                    .withValues(alpha: isDark ? 0.35 : 0.22),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.search_rounded,
                                  size: 16,
                                  color: scheme.primary,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: TextField(
                                    controller: _searchController,
                                    onChanged: (val) =>
                                        setState(() => _searchQuery = val),
                                    style: const TextStyle(fontSize: 13),
                                    decoration: InputDecoration(
                                      hintText: isRu
                                          ? 'Поиск по названию или ссылке...'
                                          : 'Search by name or URL...',
                                      hintStyle: TextStyle(
                                        fontSize: 13,
                                        color: scheme.onSurfaceVariant
                                            .withValues(alpha: 0.6),
                                      ),
                                      border: InputBorder.none,
                                      isDense: true,
                                      contentPadding: EdgeInsets.zero,
                                    ),
                                  ),
                                ),
                                if (_searchQuery.isNotEmpty)
                                  GestureDetector(
                                    onTap: () {
                                      _searchController.clear();
                                      setState(() => _searchQuery = '');
                                    },
                                    child: Icon(
                                      Icons.close_rounded,
                                      size: 16,
                                      color: scheme.onSurfaceVariant,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),

                      // Empty State
                      if (filteredItems.isEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 24, vertical: 36),
                          decoration: BoxDecoration(
                            color: isDark
                                ? scheme.surfaceContainerHigh
                                    .withValues(alpha: 0.35)
                                : Colors.white.withValues(alpha: 0.70),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.08)
                                  : Colors.white,
                            ),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.cloud_off_rounded,
                                size: 42,
                                color: scheme.onSurfaceVariant
                                    .withValues(alpha: 0.5),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                isRu
                                    ? 'Нет источников в этой категории'
                                    : 'No providers match criteria',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                isRu
                                    ? 'Попробуйте сменить фильтр или нажмите «Создать»'
                                    : 'Try switching filters or tap "Add" to create one',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: scheme.onSurfaceVariant,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        )
                      else
                        // Responsive Layout (Wrap: 2 columns on wide screen, 1 column on mobile)
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: filteredItems.map((item) {
                            final cardWidth = isWide
                                ? (constraints.maxWidth - 12) / 2
                                : constraints.maxWidth;
                            return SizedBox(
                              width: cardWidth,
                              child: ProviderCard(
                                key: ValueKey(item.id),
                                config: item,
                                onToggle: (enabled) => ref
                                    .read(providersControllerProvider.notifier)
                                    .toggle(item.id, enabled),
                                onEdit: () => Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => ProviderFormScreen(
                                      initialConfig: item,
                                    ),
                                  ),
                                ),
                                onSaveConfig: (updated) => ref
                                    .read(providersControllerProvider.notifier)
                                    .save(updated),
                                onDelete: () async {
                                  final ok = await showConfirmDialog(
                                    context,
                                    title: isRu
                                        ? 'Удалить источник'
                                        : 'Delete provider',
                                    message: isRu
                                        ? 'Вы действительно хотите удалить ${item.name}?'
                                        : 'Remove ${item.name}?',
                                  );
                                  if (ok) {
                                    await ref
                                        .read(providersControllerProvider
                                            .notifier)
                                        .delete(item.id);
                                  }
                                },
                              ),
                            );
                          }).toList(),
                        ),
                    ],
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }
}

class _FilterPill extends StatelessWidget {
  const _FilterPill({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.isDark,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: selected
                ? scheme.primary.withValues(alpha: isDark ? 0.22 : 0.12)
                : (isDark
                    ? Colors.white.withValues(alpha: 0.05)
                    : Colors.black.withValues(alpha: 0.04)),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected
                  ? scheme.primary.withValues(alpha: isDark ? 0.45 : 0.30)
                  : (isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : Colors.black.withValues(alpha: 0.06)),
              width: 1,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color: selected ? scheme.primary : scheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}
