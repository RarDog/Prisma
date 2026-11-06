import 'package:flutter/material.dart';
import 'package:gel_rule_app/backend/backend.dart';
import 'package:gel_rule_app/features/artists/models/artist_sort_order.dart';

import 'artist_service_utils.dart';

class ArtistsFilterSheet extends StatefulWidget {
  const ArtistsFilterSheet({
    super.key,
    required this.selectedSort,
    required this.selectedServices,
    required this.providers,
    required this.selectedProviderId,
    required this.isRu,
    required this.onApply,
  });

  final ArtistSortOrder selectedSort;
  final Set<String> selectedServices;
  final List<ContentProviderConfig> providers;
  final String? selectedProviderId;
  final bool isRu;
  final void Function({
    required ArtistSortOrder sort,
    required Set<String> services,
    required String? providerId,
  }) onApply;

  static Future<void> show(
    BuildContext context, {
    required ArtistSortOrder selectedSort,
    required Set<String> selectedServices,
    required List<ContentProviderConfig> providers,
    required String? selectedProviderId,
    required bool isRu,
    required void Function({
      required ArtistSortOrder sort,
      required Set<String> services,
      required String? providerId,
    }) onApply,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ArtistsFilterSheet(
        selectedSort: selectedSort,
        selectedServices: selectedServices,
        providers: providers,
        selectedProviderId: selectedProviderId,
        isRu: isRu,
        onApply: onApply,
      ),
    );
  }

  @override
  State<ArtistsFilterSheet> createState() => _ArtistsFilterSheetState();
}

class _ArtistsFilterSheetState extends State<ArtistsFilterSheet> {
  late ArtistSortOrder _sort;
  late Set<String> _services;
  late String? _providerId;

  static const _availableServices = ['patreon', 'fanbox'];

  @override
  void initState() {
    super.initState();
    _sort = widget.selectedSort;
    _services = Set<String>.from(widget.selectedServices);
    _providerId = widget.selectedProviderId;
  }

  bool get _hasNonDefaultFilters =>
      _sort != ArtistSortOrder.popularityDesc ||
      _services.isNotEmpty ||
      (_providerId != null &&
          widget.providers.isNotEmpty &&
          _providerId != widget.providers.first.id);

  void _reset() {
    setState(() {
      _sort = ArtistSortOrder.popularityDesc;
      _services.clear();
      _providerId =
          widget.providers.isNotEmpty ? widget.providers.first.id : null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isRu = widget.isRu;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.82,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF14181F) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(
          top: BorderSide(
            color: isDark
                ? Colors.white.withValues(alpha: 0.12)
                : Colors.black.withValues(alpha: 0.08),
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Handle bar
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 10, bottom: 6),
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.black12,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 16, 12),
              child: Row(
                children: [
                  Icon(
                    Icons.tune_rounded,
                    size: 20,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      isRu ? 'Фильтры и сортировка' : 'Filters & Sorting',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  if (_hasNonDefaultFilters)
                    TextButton(
                      onPressed: _reset,
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        foregroundColor: isDark ? Colors.white60 : Colors.black54,
                      ),
                      child: Text(isRu ? 'Сбросить' : 'Reset'),
                    ),
                ],
              ),
            ),
            const Divider(height: 1),

            // Content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Sorting section
                    _SectionTitle(
                      title: isRu ? 'Сортировка авторов' : 'Sort artists by',
                      icon: Icons.sort_rounded,
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: ArtistSortOrder.values.map((s) {
                        final selected = _sort == s;
                        return _ChoiceChipItem(
                          label: s.label(isRu),
                          icon: s.icon,
                          selected: selected,
                          onTap: () => setState(() => _sort = s),
                        );
                      }).toList(growable: false),
                    ),

                    const SizedBox(height: 22),

                    // Platforms section
                    _SectionTitle(
                      title: isRu ? 'Платформы' : 'Platforms',
                      icon: Icons.apps_rounded,
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _ChoiceChipItem(
                          label: isRu ? 'Все платформы' : 'All platforms',
                          selected: _services.isEmpty,
                          onTap: () => setState(() => _services.clear()),
                        ),
                        for (final s in _availableServices)
                          _ChoiceChipItem(
                            label: formatArtistServiceName(s),
                            dotColor: artistServiceColor(s),
                            selected: _services.contains(s),
                            selectedColor: artistServiceColor(s),
                            onTap: () {
                              setState(() {
                                if (_services.contains(s)) {
                                  _services.remove(s);
                                } else {
                                  _services.add(s);
                                }
                              });
                            },
                          ),
                      ],
                    ),

                    // Providers section if multiple
                    if (widget.providers.length > 1) ...[
                      const SizedBox(height: 22),
                      _SectionTitle(
                        title: isRu ? 'Источник каталога' : 'Catalog source',
                        icon: Icons.dns_rounded,
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: widget.providers.map((p) {
                          final selected = _providerId == p.id;
                          return _ChoiceChipItem(
                            label: p.name,
                            selected: selected,
                            onTap: () => setState(() => _providerId = p.id),
                          );
                        }).toList(growable: false),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // Apply button
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: FilledButton(
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: () {
                  Navigator.of(context).pop();
                  widget.onApply(
                    sort: _sort,
                    services: _services,
                    providerId: _providerId,
                  );
                },
                child: Text(
                  isRu ? 'Применить' : 'Apply',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.icon});

  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Row(
      children: [
        Icon(
          icon,
          size: 15,
          color: isDark ? Colors.white60 : Colors.black54,
        ),
        const SizedBox(width: 6),
        Text(
          title,
          style: theme.textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white70 : Colors.black87,
          ),
        ),
      ],
    );
  }
}

class _ChoiceChipItem extends StatelessWidget {
  const _ChoiceChipItem({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
    this.dotColor,
    this.selectedColor,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;
  final Color? dotColor;
  final Color? selectedColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final activeBg = selectedColor ?? theme.colorScheme.primary;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? activeBg.withValues(alpha: isDark ? 0.28 : 0.15)
              : (isDark
                  ? Colors.white.withValues(alpha: 0.05)
                  : Colors.black.withValues(alpha: 0.04)),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected
                ? activeBg.withValues(alpha: isDark ? 0.7 : 0.6)
                : (isDark
                    ? Colors.white.withValues(alpha: 0.09)
                    : Colors.black.withValues(alpha: 0.08)),
            width: selected ? 1.2 : 0.9,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (dotColor != null) ...[
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  color: dotColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
            ] else if (icon != null) ...[
              Icon(
                icon,
                size: 15,
                color: selected
                    ? (selectedColor ?? theme.colorScheme.primary)
                    : (isDark ? Colors.white60 : Colors.black54),
              ),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: selected ? FontWeight.bold : FontWeight.w500,
                color: selected
                    ? (isDark ? Colors.white : Colors.black87)
                    : (isDark ? Colors.white70 : Colors.black54),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
