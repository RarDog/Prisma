import 'package:flutter/material.dart';

/// Preset definition for pre-filling provider forms.
class ProviderPreset {
  const ProviderPreset({
    required this.name,
    required this.color,
    required this.baseUrl,
    required this.apiType,
  });

  final String name;
  final Color color;
  final String baseUrl;
  final String apiType;
}

/// Standard quick-fill presets for popular imageboards and catalogs.
const defaultProviderPresets = <ProviderPreset>[
  ProviderPreset(
    name: 'Gelbooru',
    color: Color(0xFF10B981),
    baseUrl: 'https://gelbooru.com',
    apiType: 'gelbooru',
  ),
  ProviderPreset(
    name: 'Rule34',
    color: Color(0xFF84CC16),
    baseUrl: 'https://api.rule34.xxx',
    apiType: 'rule34',
  ),
  ProviderPreset(
    name: 'Safebooru',
    color: Color(0xFF0284C7),
    baseUrl: 'https://safebooru.org',
    apiType: 'safebooru',
  ),
  ProviderPreset(
    name: 'TBIB',
    color: Color(0xFF2563EB),
    baseUrl: 'https://tbib.org',
    apiType: 'tbib',
  ),
  ProviderPreset(
    name: 'Rule34.us',
    color: Color(0xFFE11D48),
    baseUrl: 'https://rule34.us',
    apiType: 'rule34_us',
  ),
  ProviderPreset(
    name: 'Danbooru',
    color: Color(0xFF3B82F6),
    baseUrl: 'https://danbooru.donmai.us',
    apiType: 'danbooru',
  ),
  ProviderPreset(
    name: 'e621',
    color: Color(0xFFF59E0B),
    baseUrl: 'https://e621.net',
    apiType: 'e621',
  ),
  ProviderPreset(
    name: 'Yande.re',
    color: Color(0xFF8B5CF6),
    baseUrl: 'https://yande.re',
    apiType: 'moebooru',
  ),
  ProviderPreset(
    name: 'Konachan',
    color: Color(0xFFEC4899),
    baseUrl: 'https://konachan.net',
    apiType: 'moebooru',
  ),
  ProviderPreset(
    name: 'Paheal',
    color: Color(0xFFF97316),
    baseUrl: 'https://rule34.paheal.net',
    apiType: 'paheal',
  ),
  ProviderPreset(
    name: 'Pixiv',
    color: Color(0xFF0096FA),
    baseUrl: 'https://www.pixiv.net',
    apiType: 'pixiv',
  ),
  ProviderPreset(
    name: 'nHentai',
    color: Color(0xFFED2553),
    baseUrl: 'https://nhentai.net',
    apiType: 'nhentai',
  ),
  ProviderPreset(
    name: 'MangaDex',
    color: Color(0xFFFF6740),
    baseUrl: 'https://api.mangadex.org',
    apiType: 'mangadex',
  ),
];

/// Tappable pill widget for a single preset.
class PresetChip extends StatelessWidget {
  const PresetChip({
    required this.name,
    required this.color,
    required this.onTap,
    super.key,
  });

  final String name;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: color.withValues(alpha: isDark ? 0.16 : 0.10),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: color.withValues(alpha: isDark ? 0.40 : 0.28),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                name,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Horizontal scrolling bar of quick presets displayed when creating a new provider.
class ProviderPresetsBar extends StatelessWidget {
  const ProviderPresetsBar({
    required this.onPresetSelected,
    this.presets = defaultProviderPresets,
    super.key,
  });

  final ValueChanged<ProviderPreset> onPresetSelected;
  final List<ProviderPreset> presets;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isRu = Localizations.maybeLocaleOf(context)?.languageCode == 'ru';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          isRu ? 'Быстрые пресеты' : 'Quick Presets',
          style: theme.textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: theme.colorScheme.onSurfaceVariant,
            letterSpacing: -0.1,
          ),
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (int i = 0; i < presets.length; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                PresetChip(
                  name: presets[i].name,
                  color: presets[i].color,
                  onTap: () => onPresetSelected(presets[i]),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}
