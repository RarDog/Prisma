import 'package:flutter/material.dart';

class ColorSwatches extends StatelessWidget {
  const ColorSwatches({
    required this.selected,
    required this.onChanged,
    super.key,
  });

  final int selected;
  final ValueChanged<int> onChanged;

  static const themes = <(int, String, String, String)>[
    (0xFFE84D8A, 'Prisma Pink', 'Розовый Prisma', '🌸'),
    (0xFFF472B6, 'Sakura Velvet', 'Сакура Вельвет', '🌺'),
    (0xFF8B5CF6, 'Cyberpunk Neon', 'Киберпанк Неон', '🌌'),
    (0xFF6366F1, 'Deep Indigo', 'Глубокий индиго', '🔮'),
    (0xFF3B82F6, 'Azure Horizon', 'Лазурный горизонт', '🌊'),
    (0xFF0EA5E9, 'Sky Cyan', 'Небесный циановый', '💎'),
    (0xFF10B981, 'Emerald Forest', 'Изумрудный бор', '🌲'),
    (0xFF14B8A6, 'Mint Teal', 'Мятный бирюзовый', '🍃'),
    (0xFFF97316, 'Sunset Amber', 'Закатный янтарь', '🌅'),
    (0xFFEAB308, 'Electric Gold', 'Электрическое золото', '⚡'),
    (0xFFEF4444, 'Crimson Ruby', 'Алый рубин', '🍷'),
    (0xFF64748B, 'Obsidian Slate', 'Обсидиановый сланец', '🌑'),
  ];

  static List<(int, String)> get colors =>
      themes.map((t) => (t.$1, t.$2)).toList();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isRu = Localizations.maybeLocaleOf(context)?.languageCode == 'ru';
    final activeTheme = themes.where((t) => t.$1 == selected).firstOrNull ??
        (selected, 'Custom', 'Свой', '🎨');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.palette_outlined,
                size: 20, color: Color(0xFF8B5CF6)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                isRu ? 'Цветовая тема оформления' : 'Theme Color Preset',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
              decoration: BoxDecoration(
                color: Color(selected).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: Color(selected).withValues(alpha: 0.35),
                  width: 0.8,
                ),
              ),
              child: Text(
                '${activeTheme.$4} ${isRu ? activeTheme.$3 : activeTheme.$2}',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.bold,
                  color: Color(selected),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final entry in themes)
              Tooltip(
                message:
                    '${isRu ? entry.$3 : entry.$2} #${entry.$1.toRadixString(16).substring(2).toUpperCase()}',
                child: InkWell(
                  borderRadius: BorderRadius.circular(999),
                  onTap: () => onChanged(entry.$1),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    decoration: BoxDecoration(
                      color: Color(entry.$1),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: selected == entry.$1
                            ? theme.colorScheme.onSurface
                            : theme.colorScheme.outlineVariant
                                .withValues(alpha: 0.5),
                        width: selected == entry.$1 ? 3 : 1.5,
                      ),
                      boxShadow: selected == entry.$1
                          ? [
                              BoxShadow(
                                color: Color(entry.$1).withValues(alpha: 0.5),
                                blurRadius: 10,
                                spreadRadius: 1.5,
                              ),
                            ]
                          : null,
                    ),
                    child: SizedBox(
                      width: 38,
                      height: 38,
                      child: selected == entry.$1
                          ? const Icon(Icons.check_rounded,
                              color: Colors.white, size: 20)
                          : null,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

