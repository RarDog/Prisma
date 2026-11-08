import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:gel_rule_app/backend/backend.dart';
import 'package:gel_rule_app/features/settings/presentation/settings_controller.dart';

/// Decodes JSON-serialized search preset string into a name and tags map.
Map<String, String> decodeSearchPreset(String raw) {
  try {
    final map = jsonDecode(raw) as Map<String, dynamic>;
    return {'name': map['name'] as String, 'tags': map['tags'] as String};
  } catch (_) {
    return {'name': raw, 'tags': raw};
  }
}

/// Shows a dialog prompting the user for a name to save [tags] as a search preset.
Future<String?> showSavePresetDialog(
  BuildContext context,
  String tags,
) async {
  final isRu = Localizations.maybeLocaleOf(context)?.languageCode == 'ru';
  final ctrl = TextEditingController(text: tags);
  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(isRu ? 'Сохранить пресет' : 'Save preset'),
      content: TextField(
        controller: ctrl,
        decoration: InputDecoration(
          labelText: isRu ? 'Название пресета' : 'Preset name',
        ),
        autofocus: true,
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
}

/// Prompts for a preset name and appends the new preset to [AppSettings.searchPresets].
Future<void> saveCurrentSearchPreset(
  BuildContext context,
  WidgetRef ref,
  List<String> tags,
  AppSettings settings,
) async {
  if (tags.isEmpty) return;
  final tagsStr = tags.join(' ');
  final name = await showSavePresetDialog(context, tagsStr);
  if (name == null || name.isEmpty || !context.mounted) return;
  final preset = jsonEncode({'name': name, 'tags': tagsStr});
  final updated = [...settings.searchPresets, preset];
  await ref
      .read(settingsControllerProvider.notifier)
      .saveSettings(settings.copyWith(searchPresets: updated));
}

/// Horizontal scroll bar with quick search preset pills and deletion dialogs.
class FeedSearchPresetsBar extends StatelessWidget {
  const FeedSearchPresetsBar({
    required this.presets,
    required this.currentTags,
    required this.onApply,
    required this.onDelete,
    super.key,
  });

  final List<String> presets;
  final List<String> currentTags;
  final ValueChanged<String> onApply;
  final ValueChanged<String> onDelete;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: 40,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        scrollDirection: Axis.horizontal,
        itemCount: presets.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final raw = presets[i];
          final decoded = decodeSearchPreset(raw);
          final name = decoded['name'] ?? raw;
          final tags = decoded['tags'] ?? raw;
          final active = currentTags.join(' ') == tags;
          return GestureDetector(
            onLongPress: () {
              final isRu =
                  Localizations.maybeLocaleOf(context)?.languageCode == 'ru';
              showDialog<void>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: Text('«$name»'),
                  content: Text('${isRu ? "Теги" : "Tags"}: $tags'),
                  actions: [
                    TextButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        onDelete(raw);
                      },
                      child: Text(
                        isRu ? 'Удалить' : 'Delete',
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: Text(isRu ? 'Закрыть' : 'Close'),
                    ),
                  ],
                ),
              );
            },
            child: FilterChip(
              avatar: Icon(
                active ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                size: 15,
                color: active ? scheme.primary : scheme.onSurfaceVariant,
              ),
              label: Text(name),
              selected: active,
              onSelected: (_) => onApply(raw),
              selectedColor: scheme.primaryContainer.withValues(alpha: 0.8),
              checkmarkColor: scheme.onPrimaryContainer,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              labelStyle: TextStyle(
                color: active ? scheme.onPrimaryContainer : scheme.onSurface,
                fontWeight: active ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          );
        },
      ),
    );
  }
}
