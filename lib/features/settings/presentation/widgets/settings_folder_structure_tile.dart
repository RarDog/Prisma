import 'package:flutter/material.dart';

import 'settings_shared_widgets.dart';

class SettingsFolderStructureTile extends StatelessWidget {
  const SettingsFolderStructureTile({
    required this.currentTemplate,
    required this.isRu,
    required this.onChanged,
    super.key,
  });

  final String currentTemplate;
  final bool isRu;
  final ValueChanged<String> onChanged;

  static const _presets = [
    '{Artist}',
    '{Provider}/{Artist}',
    '{Service}/{ID}',
    '{Date}/{Artist}',
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: () => _showPicker(context),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const SettingsIconBadge(
                  icon: Icons.folder_copy_rounded,
                  color: Color(0xFF0EA5E9),
                  size: 34,
                  iconSize: 18,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isRu ? 'Папки скачивания' : 'Download folder structure',
                        style: theme.textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isRu
                            ? 'Шаблон организации сохраняемых файлов'
                            : 'Path template for organized downloads',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.chevron_right_rounded,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ],
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest
                    .withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color:
                      theme.colorScheme.outlineVariant.withValues(alpha: 0.35),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.folder_open_rounded, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      currentTemplate,
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ),
                  Text(
                    isRu ? 'Выбрать' : 'Select',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showPicker(BuildContext context) async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  isRu
                      ? 'Структура папок скачивания'
                      : 'Download path template',
                  style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 6),
                Text(
                  isRu
                      ? 'Переменные: {Artist}, {Provider}, {Service}, {ID}, {Date}'
                      : 'Tags: {Artist}, {Provider}, {Service}, {ID}, {Date}',
                  style: Theme.of(ctx).textTheme.bodySmall,
                ),
                const SizedBox(height: 14),
                for (final preset in _presets)
                  ListTile(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    leading: const Icon(Icons.folder_outlined),
                    title: Text(preset,
                        style: const TextStyle(fontFamily: 'monospace')),
                    trailing: currentTemplate == preset
                        ? const Icon(Icons.check_rounded, color: Colors.green)
                        : null,
                    onTap: () => Navigator.pop(ctx, preset),
                  ),
                ListTile(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  leading: const Icon(Icons.edit_note_rounded),
                  title: Text(
                    isRu ? 'Пользовательский шаблон...' : 'Custom template...',
                  ),
                  onTap: () => Navigator.pop(ctx, '__custom__'),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (picked == '__custom__' && context.mounted) {
      final ctrl = TextEditingController(text: currentTemplate);
      final custom = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(isRu ? 'Свой шаблон папок' : 'Custom path template'),
          content: TextField(
            controller: ctrl,
            decoration: InputDecoration(
              labelText: isRu ? 'Шаблон' : 'Template',
              helperText: '{Artist}, {Provider}, {Service}, {ID}, {Date}',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(isRu ? 'Отмена' : 'Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
              child: Text(isRu ? 'Сохранить' : 'Save'),
            ),
          ],
        ),
      );
      if (custom != null && custom.isNotEmpty) {
        onChanged(custom);
      }
    } else if (picked != null && picked != '__custom__') {
      onChanged(picked);
    }
  }
}

