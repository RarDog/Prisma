import 'package:flutter/material.dart';

class TabVisibilityEditor extends StatelessWidget {
  const TabVisibilityEditor({
    required this.hiddenTabs,
    required this.onChanged,
    super.key,
  });

  final List<String> hiddenTabs;
  final ValueChanged<List<String>> onChanged;

  static const tabs = <String, (String, IconData)>{
    'feed': ('Feed', Icons.dynamic_feed_rounded),
    'search': ('Search', Icons.search_rounded),
    'favorites': ('Favorites', Icons.favorite_rounded),
    'viewed': ('Viewed', Icons.history_rounded),
    'collections': ('Collections', Icons.collections_bookmark_rounded),
    'artists': ('Artists', Icons.person_rounded),
    'manga': ('Manga', Icons.menu_book_rounded),
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isRu = Localizations.maybeLocaleOf(context)?.languageCode == 'ru';
    final hidden = hiddenTabs.toSet();

    String tabLabel(String key, String defaultLabel) {
      if (!isRu) return defaultLabel;
      return switch (key) {
        'feed' => 'Лента',
        'search' => 'Тэги',
        'favorites' => 'Избранное',
        'viewed' => 'История',
        'collections' => 'Коллекции',
        'artists' => 'Авторы',
        'manga' => 'Манга',
        _ => defaultLabel,
      };
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.tab_rounded, size: 20, color: Color(0xFF8B5CF6)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                isRu
                    ? 'Отображение вкладок навигации'
                    : 'Navigation tabs visibility',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final entry in tabs.entries)
              FilterChip(
                selected: !hidden.contains(entry.key),
                avatar: Icon(entry.value.$2, size: 16),
                label: Text(tabLabel(entry.key, entry.value.$1)),
                onSelected: (visible) {
                  final next = {...hidden};
                  if (visible) {
                    next.remove(entry.key);
                  } else if (entry.key != 'feed') {
                    next.add(entry.key);
                  }
                  onChanged(next.toList()..sort());
                },
              ),
          ],
        ),
      ],
    );
  }
}

