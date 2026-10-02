import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:gel_rule_app/app/app.dart';
import 'package:gel_rule_app/app/app_strings.dart';
import 'package:gel_rule_app/backend/backend.dart';
import 'package:gel_rule_app/core/utils/result.dart';
import 'package:gel_rule_app/features/settings/presentation/settings_controller.dart';
import 'package:gel_rule_app/features/settings/presentation/widgets/settings_shared_widgets.dart';

class StorageSettingsScreen extends ConsumerWidget {
  const StorageSettingsScreen({super.key});

  Future<void> _update(WidgetRef ref, AppSettings settings) {
    return ref.read(settingsControllerProvider.notifier).saveSettings(settings);
  }

  void _handleRestoreResult(
    BuildContext context,
    WidgetRef ref,
    Result<AppSettings> result,
    bool isRu,
  ) {
    if (result is Success<AppSettings>) {
      ref.invalidate(appSettingsProvider);
      ref.invalidate(settingsControllerProvider);
      ref.invalidate(providerRepositoryProvider);
      ref.invalidate(providerManagerProvider);
      ref.invalidate(favoriteRepositoryProvider);
      ref.invalidate(collectionRepositoryProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isRu
                ? 'Все данные (настройки, провайдеры, избранное, коллекции) успешно импортированы!'
                : 'All data (settings, providers, favorites, collections) successfully imported!',
          ),
        ),
      );
    } else if (result is Error<AppSettings>) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${isRu ? "Ошибка импорта" : "Import error"}: ${result.failure.message}',
          ),
        ),
      );
    }
  }

  Future<void> _exportJson(BuildContext context, WidgetRef ref) async {
    final isRu = Localizations.maybeLocaleOf(context)?.languageCode == 'ru';
    final theme = Theme.of(context);

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: theme.colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (bottomSheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                isRu ? 'JSON Экспорт' : 'JSON Export',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.file_download_rounded,
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
                title: Text(isRu ? 'Сохранить как файл .json' : 'Save as .json file'),
                subtitle: Text(
                  isRu
                      ? 'Полный бэкап настроек, аккаунтов, избранного и коллекций'
                      : 'Complete snapshot of settings, accounts, favorites and collections',
                ),
                onTap: () async {
                  Navigator.pop(bottomSheetContext);
                  final success =
                      await ref.read(backupServiceProvider).exportBackup();
                  if (!context.mounted) return;
                  if (success) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          isRu
                              ? 'Бэкап успешно сохранен в файл'
                              : 'Backup saved to file successfully',
                        ),
                      ),
                    );
                  }
                },
              ),
              const SizedBox(height: 6),
              ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.copy_all_rounded,
                    color: theme.colorScheme.onSecondaryContainer,
                  ),
                ),
                title:
                    Text(isRu ? 'Скопировать JSON в буфер' : 'Copy JSON to clipboard'),
                subtitle: Text(
                  isRu
                      ? 'Скопировать текстовый JSON полного бэкапа'
                      : 'Copy full backup formatted JSON text to clipboard',
                ),
                onTap: () async {
                  Navigator.pop(bottomSheetContext);
                  final json =
                      await ref.read(backupServiceProvider).createBackupJson();
                  await Clipboard.setData(ClipboardData(text: json));
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        isRu
                            ? 'Полный JSON бэкапа скопирован в буфер обмена'
                            : 'Full backup JSON copied to clipboard',
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _importJson(BuildContext context, WidgetRef ref) async {
    final isRu = Localizations.maybeLocaleOf(context)?.languageCode == 'ru';
    final theme = Theme.of(context);

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: theme.colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (bottomSheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                isRu ? 'JSON Импорт' : 'JSON Import',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.file_open_rounded,
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
                title: Text(isRu ? 'Выбрать файл .json' : 'Choose .json file'),
                subtitle: Text(
                  isRu
                      ? 'Восстановить настройки, аккаунты, избранное и коллекции'
                      : 'Restore settings, accounts, favorites and collections from file',
                ),
                onTap: () async {
                  Navigator.pop(bottomSheetContext);
                  final result =
                      await ref.read(backupServiceProvider).importBackup();
                  if (!context.mounted) return;
                  if (result != null) {
                    _handleRestoreResult(context, ref, result, isRu);
                  }
                },
              ),
              const SizedBox(height: 6),
              ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.paste_rounded,
                    color: theme.colorScheme.onSecondaryContainer,
                  ),
                ),
                title: Text(isRu ? 'Вставить JSON текст' : 'Paste JSON text'),
                subtitle: Text(
                  isRu
                      ? 'Вставить текст JSON бэкапа из буфера обмена'
                      : 'Paste backup JSON string from clipboard manually',
                ),
                onTap: () {
                  Navigator.pop(bottomSheetContext);
                  _importDialog(context, ref);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _importDialog(BuildContext context, WidgetRef ref) async {
    final isRu = Localizations.maybeLocaleOf(context)?.languageCode == 'ru';
    final controller = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isRu ? 'Импорт JSON' : 'Import JSON'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              isRu
                  ? 'Вставьте JSON настроек или полного бэкапа:'
                  : 'Paste settings or full backup JSON:',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 10),
            TextField(
              controller: controller,
              minLines: 5,
              maxLines: 10,
              decoration: InputDecoration(
                hintText: '{\n  "version": 3,\n  ...\n}',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(isRu ? 'Отмена' : 'Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final text = controller.text.trim();
              if (text.isEmpty) return;
              Navigator.pop(context);
              final result =
                  await ref.read(backupServiceProvider).restoreFromJson(text);
              if (!context.mounted) return;
              _handleRestoreResult(context, ref, result, isRu);
            },
            child: Text(isRu ? 'Импортировать' : 'Import'),
          ),
        ],
      ),
    );
  }

  Future<void> _saveAutoBackupNow(BuildContext context, WidgetRef ref) async {
    final isRu = Localizations.maybeLocaleOf(context)?.languageCode == 'ru';
    final success = await ref
        .read(backupServiceProvider)
        .saveAutoBackupToPersistentStorage(force: true);
    if (!context.mounted) return;
    if (success) {
      final path =
          ref.read(backupServiceProvider).lastPersistentBackupPath ?? '';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isRu
                ? 'Автобэкап успешно сохранен!${path.isNotEmpty ? " ($path)" : ""}'
                : 'Auto-backup saved successfully!${path.isNotEmpty ? " ($path)" : ""}',
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isRu
                ? 'Не удалось сохранить в хранилище'
                : 'Failed to save to storage',
          ),
        ),
      );
    }
  }

  Future<void> _restoreFromPersistentBackup(
      BuildContext context, WidgetRef ref) async {
    final isRu = Localizations.maybeLocaleOf(context)?.languageCode == 'ru';
    final result =
        await ref.read(backupServiceProvider).restoreFromPersistentStorage();
    if (!context.mounted) return;
    _handleRestoreResult(context, ref, result, isRu);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings =
        ref.watch(settingsControllerProvider).value ?? AppSettings.defaults;
    final strings = AppStrings(settings.languageCode);
    final isRu = strings.ru;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const SettingsIconBadge(
              icon: Icons.storage_rounded,
              color: Color(0xFF06B6D4),
              size: 30,
              iconSize: 16,
            ),
            const SizedBox(width: 10),
            Text(
              strings.storage,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 860),
          child: ListView(
            padding: EdgeInsets.fromLTRB(
              16,
              12,
              16,
              120 + MediaQuery.paddingOf(context).bottom,
            ),
            children: [
              // Cache & Data Management
              SettingsCardGroup(
                title: isRu ? 'Управление кэшем' : 'Cache Management',
                icon: Icons.pie_chart_rounded,
                accentColor: const Color(0xFF06B6D4),
                children: [
                  SettingsTile(
                    icon: Icons.pie_chart_rounded,
                    iconColor: const Color(0xFF06B6D4),
                    title: isRu ? 'Менеджер кэша' : 'Cache Manager',
                    subtitle: isRu
                        ? 'Просмотр размера картинок, видео и быстрое освобождение памяти'
                        : 'Detailed cache analytics and smart cleanup tools',
                    trailing:
                        const Icon(Icons.chevron_right_rounded, size: 20),
                    onTap: () => context.go('/settings/cache'),
                  ),
                  const SettingsDivider(),
                  SettingsTile(
                    icon: Icons.cleaning_services_rounded,
                    iconColor: const Color(0xFFEF4444),
                    title: strings.clearCache,
                    subtitle: isRu
                        ? 'Удалить временные кэшированные файлы'
                        : 'Purge all cached thumbnail and image data',
                    onTap: () async {
                      await ref
                          .read(settingsControllerProvider.notifier)
                          .clearCache();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              isRu ? 'Кэш очищен' : 'Cache cleared',
                            ),
                          ),
                        );
                      }
                    },
                  ),
                ],
              ),

              // Storage Limits
              SettingsCardGroup(
                title: isRu ? 'Лимиты хранения' : 'Storage Limits',
                icon: Icons.tune_rounded,
                accentColor: const Color(0xFF3B82F6),
                children: [
                  SettingsStepperTile(
                    icon: Icons.photo_library_rounded,
                    iconColor: const Color(0xFF06B6D4),
                    title: strings.cacheMaxItems,
                    subtitle: isRu
                        ? 'Максимальное количество файлов в дисковом кэше'
                        : 'Max items stored in image/video cache',
                    value: settings.cacheMaxItems,
                    min: 100,
                    max: 10000,
                    onChanged: (val) =>
                        _update(ref, settings.copyWith(cacheMaxItems: val)),
                  ),
                  const SettingsDivider(),
                  SettingsStepperTile(
                    icon: Icons.history_rounded,
                    iconColor: const Color(0xFF3B82F6),
                    title: isRu ? 'Лимит истории поиска' : 'Search history limit',
                    subtitle: isRu
                        ? 'Хранение недавних поисковых запросов'
                        : 'Max search query entries stored',
                    value: settings.searchHistoryLimit,
                    min: 50,
                    max: 2000,
                    onChanged: (val) =>
                        _update(ref, settings.copyWith(searchHistoryLimit: val)),
                  ),
                  const SettingsDivider(),
                  SettingsStepperTile(
                    icon: Icons.tag_rounded,
                    iconColor: const Color(0xFF8B5CF6),
                    title:
                        isRu ? 'Лимит кэша тегов (диск)' : 'Tag cache limit (disk)',
                    subtitle: isRu
                        ? 'Количество кэшируемых подсказок тегов на диске'
                        : 'Max tag autocomplete entries persisted on disk',
                    value: settings.tagCacheLimit,
                    min: 500,
                    max: 20000,
                    onChanged: (val) =>
                        _update(ref, settings.copyWith(tagCacheLimit: val)),
                  ),
                ],
              ),

              // Clean History & Data Actions
              SettingsCardGroup(
                title: isRu ? 'Очистка истории' : 'History Cleanup',
                icon: Icons.auto_delete_rounded,
                accentColor: const Color(0xFFF59E0B),
                children: [
                  SettingsTile(
                    icon: Icons.label_off_rounded,
                    iconColor: const Color(0xFFF59E0B),
                    title: isRu ? 'Очистить кэш тегов' : 'Clear tag cache',
                    subtitle: isRu
                        ? 'Сбросить базу сохраненных подсказок тегов'
                        : 'Reset autocomplete tag database',
                    onTap: () async {
                      await ref
                          .read(settingsControllerProvider.notifier)
                          .clearTagCache();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              isRu
                                  ? 'Кэш подсказок тегов очищен'
                                  : 'Tag suggestions cache cleared',
                            ),
                          ),
                        );
                      }
                    },
                  ),
                  const SettingsDivider(),
                  SettingsTile(
                    icon: Icons.history_toggle_off_rounded,
                    iconColor: const Color(0xFF6366F1),
                    title: isRu
                        ? 'Очистить историю поиска'
                        : 'Clear search history',
                    subtitle: isRu
                        ? 'Удалить список последних запросов поиска'
                        : 'Remove all search history entries',
                    onTap: () async {
                      await ref
                          .read(settingsControllerProvider.notifier)
                          .clearSearchHistory();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              isRu
                                  ? 'История поиска очищена'
                                  : 'Search history cleared',
                            ),
                          ),
                        );
                      }
                    },
                  ),
                  const SettingsDivider(),
                  SettingsTile(
                    icon: Icons.visibility_off_rounded,
                    iconColor: const Color(0xFFEC4899),
                    title: strings.clearViewed,
                    subtitle: isRu
                        ? 'Очистить список просмотренных постов'
                        : 'Reset your viewed post history',
                    onTap: () async {
                      await ref
                          .read(settingsControllerProvider.notifier)
                          .clearViewedHistory();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              isRu ? 'История просмотров очищена' : 'Viewed history cleared',
                            ),
                          ),
                        );
                      }
                    },
                  ),
                ],
              ),

              // Backup & Restore
              SettingsCardGroup(
                title: isRu
                    ? 'Резервное копирование и экспорт'
                    : 'Backup & Export',
                icon: Icons.cloud_sync_rounded,
                accentColor: const Color(0xFF10B981),
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerHighest
                                .withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: theme.colorScheme.primary
                                  .withValues(alpha: 0.2),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.cloud_sync_rounded,
                                    size: 20,
                                    color: theme.colorScheme.primary,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      isRu
                                          ? 'Автобэкап: Prisma'
                                          : 'Auto-Sync: Prisma',
                                      style: theme.textTheme.labelLarge
                                          ?.copyWith(
                                        fontWeight: FontWeight.w700,
                                        color: theme.colorScheme.primary,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                isRu
                                    ? 'Настройки, аккаунты, избранное и коллекции сохраняются и автоматически восстанавливаются при переустановке.'
                                    : 'Settings, accounts, favorites and collections are saved and restored upon re-installation.',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                  height: 1.3,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: FilledButton.icon(
                                      onPressed: () =>
                                          _saveAutoBackupNow(context, ref),
                                      icon: const Icon(Icons.save_rounded,
                                          size: 16),
                                      label: Text(
                                        isRu ? 'Сохранить сейчас' : 'Save now',
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: () =>
                                          _restoreFromPersistentBackup(
                                              context, ref),
                                      icon: const Icon(Icons.restore_rounded,
                                          size: 16),
                                      label: Text(
                                        isRu ? 'Восстановить' : 'Restore',
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: FilledButton.tonalIcon(
                                onPressed: () => _exportJson(context, ref),
                                icon: const Icon(Icons.data_object_rounded,
                                    size: 18),
                                label: Text(
                                  isRu ? 'JSON Экспорт' : 'JSON Export',
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: FilledButton.tonalIcon(
                                onPressed: () => _importJson(context, ref),
                                icon: const Icon(
                                    Icons.download_for_offline_rounded,
                                    size: 18),
                                label: Text(
                                  isRu ? 'JSON Импорт' : 'JSON Import',
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        OutlinedButton.icon(
                          onPressed: () => context.push('/onboarding'),
                          icon: const Icon(Icons.school_rounded, size: 18),
                          label: Text(
                            isRu
                                ? 'Первичная настройка (Мастер)'
                                : 'Initial Setup Wizard',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
