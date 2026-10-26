import 'package:flutter/material.dart';
import 'package:gel_rule_app/backend/backend.dart';

import 'artist_service_utils.dart';

/// Horizontal chip row: artist providers | divider | platform filters.
class ArtistsFilterBar extends StatelessWidget {
  const ArtistsFilterBar({
    super.key,
    required this.providers,
    required this.selectedProviderId,
    required this.selectedServices,
    required this.onProviderChanged,
    required this.onToggleService,
    required this.onClearServices,
    required this.isRu,
  });

  final List<ContentProviderConfig> providers;
  final String? selectedProviderId;
  final Set<String> selectedServices;
  final ValueChanged<String?> onProviderChanged;
  final ValueChanged<String> onToggleService;
  final VoidCallback onClearServices;
  final bool isRu;

  static const _availableServices = [
    'patreon',
    'fanbox',
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SizedBox(
      height: 32,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          for (final provider in providers) ...[
            _GlassChip(
              label: provider.name,
              icon: Icons.dns_rounded,
              selected: provider.id == selectedProviderId,
              isDark: isDark,
              onTap: () => onProviderChanged(provider.id),
            ),
            const SizedBox(width: 6),
          ],
          if (providers.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
              child: Container(
                width: 1,
                color: isDark
                    ? Colors.white.withValues(alpha: 0.15)
                    : Colors.black.withValues(alpha: 0.12),
              ),
            ),
            const SizedBox(width: 6),
          ],
          _GlassChip(
            label: isRu ? 'Все платформы' : 'All platforms',
            selected: selectedServices.isEmpty,
            isDark: isDark,
            onTap: onClearServices,
          ),
          const SizedBox(width: 6),
          for (final service in _availableServices) ...[
            _GlassChip(
              label: formatArtistServiceName(service),
              dotColor: artistServiceColor(service),
              selected: selectedServices.contains(service),
              selectedColor: artistServiceColor(service),
              isDark: isDark,
              onTap: () => onToggleService(service),
            ),
            const SizedBox(width: 6),
          ],
        ],
      ),
    );
  }
}

/// Shared chip decoration for provider / platform / "all" chips — the three
/// near-identical AnimatedContainers of the old header deduplicated.
class _GlassChip extends StatelessWidget {
  const _GlassChip({
    required this.label,
    required this.selected,
    required this.isDark,
    required this.onTap,
    this.icon,
    this.dotColor,
    this.selectedColor,
  });

  final String label;
  final bool selected;
  final bool isDark;
  final VoidCallback onTap;
  final IconData? icon;
  final Color? dotColor;
  final Color? selectedColor;

  Color get _selectedColor => selectedColor ?? (isDark
      ? Colors.white.withValues(alpha: 0.20)
      : const Color(0xFF0F172A));
  Color get _selectedForeground =>
      selectedColor == null ? Colors.white : selectedColor!;

  Color _borderColor(Color idleBorder) {
    if (!selected) return idleBorder;
    if (selectedColor == null) {
      return isDark
          ? Colors.white.withValues(alpha: 0.40)
          : const Color(0xFF0F172A);
    }
    return selectedColor!.withValues(alpha: 0.75);
  }

  @override
  Widget build(BuildContext context) {
    final idleBackground = isDark
        ? Colors.white.withValues(alpha: 0.05)
        : Colors.black.withValues(alpha: 0.04);
    final idleBorder = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.black.withValues(alpha: 0.06);
    final idleForeground =
        isDark ? Colors.white70 : const Color(0xFF334155);

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: selected ? _selectedColor : idleBackground,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _borderColor(idleBorder),
            width: 1.1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 14,
                color: selected ? _selectedForeground : idleForeground,
              ),
              const SizedBox(width: 5),
            ],
            if (dotColor != null) ...[
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: dotColor,
                  shape: BoxShape.circle,
                  boxShadow: selected
                      ? [
                          BoxShadow(
                            color: dotColor!.withValues(alpha: 0.6),
                            blurRadius: 4,
                          ),
                        ]
                      : null,
                ),
              ),
              const SizedBox(width: 5),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? _selectedForeground : idleForeground,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
