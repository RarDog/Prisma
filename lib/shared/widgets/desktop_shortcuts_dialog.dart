import 'dart:ui';
import 'package:flutter/material.dart';

class DesktopShortcutsDialog extends StatelessWidget {
  const DesktopShortcutsDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (_) => const DesktopShortcutsDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isRu = Localizations.maybeLocaleOf(context)?.languageCode == 'ru';
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720, maxHeight: 680),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              decoration: BoxDecoration(
                color: isDark
                    ? scheme.surfaceContainerHigh.withValues(alpha: 0.88)
                    : Colors.white.withValues(alpha: 0.94),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.16)
                      : scheme.outlineVariant.withValues(alpha: 0.4),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.12),
                    blurRadius: 32,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 20, 16, 16),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: scheme.primaryContainer.withValues(alpha: 0.7),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(
                            Icons.keyboard_rounded,
                            color: scheme.primary,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isRu ? 'Горячие клавиши' : 'Keyboard Shortcuts',
                                style: theme.textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                isRu
                                    ? 'Быстрое управление с клавиатуры для ПК'
                                    : 'Quick keyboard controls for desktop',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.close_rounded),
                          tooltip: isRu ? 'Закрыть (Esc)' : 'Close (Esc)',
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),

                  // Shortcuts list
                  Flexible(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                      children: [
                        _ShortcutSection(
                          icon: Icons.navigation_rounded,
                          title: isRu ? 'Общие и навигация' : 'General & Navigation',
                          items: [
                            _ShortcutRow(const ['Ctrl', '1…8'], isRu ? 'Переключение между вкладками' : 'Switch tabs'),
                            _ShortcutRow(const ['Ctrl', 'Tab'], isRu ? 'Следующая вкладка' : 'Next tab'),
                            _ShortcutRow(const ['Ctrl', 'Shift', 'Tab'], isRu ? 'Предыдущая вкладка' : 'Previous tab'),
                            _ShortcutRow(const ['Ctrl', 'F'], isRu ? 'Перейти к поиску / строка поиска' : 'Focus search bar'),
                            _ShortcutRow(const ['Ctrl', 'R'], isRu ? 'Обновить ленту / страницу' : 'Refresh feed / page'),
                            _ShortcutRow(const ['F5'], isRu ? 'Обновить страницу' : 'Refresh page'),
                            _ShortcutRow(const ['Esc'], isRu ? 'Закрыть окно / назад / сбросить выбор' : 'Close dialog / back / cancel selection'),
                            _ShortcutRow(const ['?'], isRu ? 'Открыть это окно горячих клавиш' : 'Show keyboard shortcuts'),
                          ],
                        ),
                        const SizedBox(height: 20),
                        _ShortcutSection(
                          icon: Icons.smart_display_rounded,
                          title: isRu ? 'Видеоплеер' : 'Video Player',
                          items: [
                            _ShortcutRow([isRu ? 'Пробел' : 'Space'], isRu ? 'Воспроизведение / Пауза' : 'Play / Pause'),
                            _ShortcutRow(const ['←', '→'], isRu ? 'Перемотка на 5 секунд назад / вперед' : 'Seek 5s backward / forward'),
                            _ShortcutRow(const ['Shift', '← / →'], isRu ? 'Перемотка на 15 секунд' : 'Seek 15s backward / forward'),
                            _ShortcutRow(const ['↑', '↓'], isRu ? 'Регулировка громкости (±5%)' : 'Volume control (±5%)'),
                            _ShortcutRow(const ['M'], isRu ? 'Включить / выключить звук' : 'Mute / unmute'),
                            _ShortcutRow(const ['F'], isRu ? 'Полноэкранный режим (Full Screen)' : 'Toggle fullscreen'),
                            _ShortcutRow(const ['L'], isRu ? 'Повтор видео (Loop on/off)' : 'Toggle video loop'),
                            _ShortcutRow(const ['Esc'], isRu ? 'Выйти из полноэкранного режима' : 'Exit fullscreen'),
                          ],
                        ),
                        const SizedBox(height: 20),
                        _ShortcutSection(
                          icon: Icons.photo_library_rounded,
                          title: isRu ? 'Фото и просмотр постов' : 'Photo & Post Viewer',
                          items: [
                            _ShortcutRow(const ['←', '→'], isRu ? 'Предыдущее / следующее фото или пост' : 'Previous / next post'),
                            _ShortcutRow(const ['+'], isRu ? 'Увеличить масштаб (Zoom In)' : 'Zoom in'),
                            _ShortcutRow(const ['-'], isRu ? 'Уменьшить масштаб (Zoom Out)' : 'Zoom out'),
                            _ShortcutRow(const ['0'], isRu ? 'Сбросить масштаб (100%)' : 'Reset zoom (100%)'),
                            _ShortcutRow(const ['F'], isRu ? 'Подгонка по экрану / на весь экран' : 'Fit to screen / fullscreen'),
                            _ShortcutRow(const ['D'], isRu ? 'Скачать текущее изображение' : 'Download current image'),
                            _ShortcutRow(const ['Ctrl', 'S'], isRu ? 'Сохранить / Скачать файл' : 'Save / download file'),
                            _ShortcutRow(const ['Esc'], isRu ? 'Сброс зума / назад' : 'Reset zoom / back'),
                          ],
                        ),
                        const SizedBox(height: 20),
                        _ShortcutSection(
                          icon: Icons.grid_view_rounded,
                          title: isRu ? 'Лента и посты' : 'Feed & Posts',
                          items: [
                            _ShortcutRow(const ['R'], isRu ? 'Открыть случайный пост' : 'Open random post'),
                            _ShortcutRow(const ['V'], isRu ? 'Включить/выключить режим выбора постов' : 'Toggle selection mode'),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ShortcutSection extends StatelessWidget {
  const _ShortcutSection({
    required this.icon,
    required this.title,
    required this.items,
  });

  final IconData icon;
  final String title;
  final List<_ShortcutRow> items;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 18, color: scheme.primary),
            const SizedBox(width: 8),
            Text(
              title,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: scheme.primary,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: isDark
                ? scheme.surface.withValues(alpha: 0.6)
                : scheme.surfaceContainerHighest.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.black.withValues(alpha: 0.04),
            ),
          ),
          child: Column(
            children: [
              for (var i = 0; i < items.length; i++) ...[
                if (i > 0)
                  Divider(
                    height: 1,
                    thickness: 1,
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.05)
                        : Colors.black.withValues(alpha: 0.04),
                  ),
                items[i],
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _ShortcutRow extends StatelessWidget {
  const _ShortcutRow(this.keys, this.description);

  final List<String> keys;
  final String description;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              description,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurface,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: keys.map((key) => _KeyCap(key)).toList(growable: false),
          ),
        ],
      ),
    );
  }
}

class _KeyCap extends StatelessWidget {
  const _KeyCap(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final scheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isDark
            ? scheme.surfaceContainerHighest.withValues(alpha: 0.9)
            : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.2)
              : Colors.black.withValues(alpha: 0.15),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.08),
            offset: const Offset(0, 1.5),
            blurRadius: 1,
          ),
        ],
      ),
      child: Text(
        text,
        style: TextStyle(
          fontFamily: 'monospace',
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: scheme.onSurface,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}
