import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:gel_rule_app/app/app.dart';
import 'package:gel_rule_app/backend/backend.dart';
import 'package:gel_rule_app/core/utils/result.dart';
import 'package:gel_rule_app/features/manga/domain/manga_library_providers.dart';
import 'package:gel_rule_app/features/onboarding/presentation/widgets/onboarding_shared_widgets.dart';
import 'package:gel_rule_app/features/settings/presentation/settings_controller.dart';
import 'package:gel_rule_app/features/viewed/presentation/viewed_controller.dart';

class OnboardingLanguageStep extends ConsumerStatefulWidget {
  const OnboardingLanguageStep({
    super.key,
    required this.onNext,
  });

  final VoidCallback onNext;

  @override
  ConsumerState<OnboardingLanguageStep> createState() =>
      _OnboardingLanguageStepState();
}

class _OnboardingLanguageStepState
    extends ConsumerState<OnboardingLanguageStep> {
  Future<void> _setLanguage(String langCode) async {
    unawaited(HapticFeedback.selectionClick());
    final current = ref.read(appSettingsProvider).value ?? AppSettings.defaults;
    if (current.languageCode != langCode) {
      await ref.read(settingsControllerProvider.notifier).saveSettings(
            current.copyWith(languageCode: langCode),
          );
    }
  }

  Future<void> _handleRestoreResult(
    Result<BackupRestoreSummary> result,
    bool isRu,
  ) async {
    if (result is Success<BackupRestoreSummary>) {
      ref.invalidate(appSettingsProvider);
      ref.invalidate(settingsControllerProvider);
      ref.invalidate(providerRepositoryProvider);
      ref.invalidate(providerManagerProvider);
      ref.invalidate(favoriteRepositoryProvider);
      ref.invalidate(collectionRepositoryProvider);
      ref.invalidate(viewedKeysProvider);
      ref.invalidate(viewedControllerProvider);
      ref.invalidate(mangaLibraryEntriesProvider);
      ref.invalidate(mangaReadingHistoryProvider);
      ref.invalidate(downloadedMediaByKeyProvider);

      await ref.read(onboardingServiceProvider).markCompleted();

      if (mounted) {
        final summary = result.data;
        final count = summary.totalItemsRestored;
        final extra = count > 0 ? (isRu ? ' ($count элементов)' : ' ($count items)') : '';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isRu
                  ? 'Данные успешно восстановлены!$extra Добро пожаловать.'
                  : 'Data successfully restored!$extra Welcome.',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
        context.go('/');
      }
    } else if (result is Error<BackupRestoreSummary>) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${isRu ? "Ошибка восстановления" : "Restore error"}: ${result.failure.message}',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _showRestoreModal(BuildContext context, bool isRu) async {
    final theme = Theme.of(context);

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: theme.colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (bottomSheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.settings_backup_restore_rounded,
                      color: theme.colorScheme.primary,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isRu
                              ? 'Восстановление из копии'
                              : 'Restore from Backup',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          isRu
                              ? 'Выберите удобный способ импорта'
                              : 'Select a restore method',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
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
                      ? 'Файл резервной копии со смартфона или ПК'
                      : 'Backup file from device or PC',
                ),
                onTap: () async {
                  Navigator.pop(bottomSheetContext);
                  final result =
                      await ref.read(backupServiceProvider).importBackup();
                  if (!mounted) return;
                  if (result != null) {
                    await _handleRestoreResult(result, isRu);
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
                    color: const Color(0xFF10B981).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.restore_page_rounded,
                    color: Color(0xFF10B981),
                  ),
                ),
                title: Text(isRu
                    ? 'Найти системный автобэкап'
                    : 'Restore from device auto-backup'),
                subtitle: Text(
                  isRu
                      ? 'Поиск копии в системном хранилище/папке Downloads'
                      : 'Search for auto-backup in system storage',
                ),
                onTap: () async {
                  Navigator.pop(bottomSheetContext);
                  final result = await ref
                      .read(backupServiceProvider)
                      .restoreFromPersistentStorage();
                  if (!mounted) return;
                  await _handleRestoreResult(result, isRu);
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
                      ? 'Вставить текст резервной копии из буфера обмена'
                      : 'Paste backup JSON string from clipboard manually',
                ),
                onTap: () {
                  Navigator.pop(bottomSheetContext);
                  _showPasteJsonDialog(context, isRu);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showPasteJsonDialog(BuildContext context, bool isRu) async {
    final controller = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(isRu ? 'Вставка JSON бэкапа' : 'Paste Backup JSON'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              isRu
                  ? 'Вставьте скопированный JSON резервной копии:'
                  : 'Paste your backup JSON text here:',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 10),
            TextField(
              controller: controller,
              minLines: 5,
              maxLines: 8,
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
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(isRu ? 'Отмена' : 'Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final text = controller.text.trim();
              if (text.isEmpty) return;
              Navigator.pop(dialogContext);
              final result =
                  await ref.read(backupServiceProvider).restoreFromJson(text);
              if (!mounted) return;
              await _handleRestoreResult(result, isRu);
            },
            child: Text(isRu ? 'Восстановить' : 'Restore'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final settings =
        ref.watch(appSettingsProvider).value ?? AppSettings.defaults;
    final isRu = settings.languageCode == 'ru';
    final currentLang = settings.languageCode;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 14),
          const PulsingIconBadge(
            icon: Icons.language_rounded,
            gradientColors: [Color(0xFF3B82F6), Color(0xFF6366F1)],
            size: 50,
          ),
          const SizedBox(height: 22),
          Text(
            isRu ? 'Добро пожаловать в Prizma!' : 'Welcome to Prizma!',
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            isRu
                ? 'Выберите язык интерфейса приложения'
                : 'Select the app interface language',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 36),

          // Russian Option
          LanguageCard(
            title: 'Русский',
            subtitle: 'Интерфейс на русском языке',
            flag: '🇷🇺',
            isSelected: currentLang == 'ru',
            onTap: () => _setLanguage('ru'),
          ),
          const SizedBox(height: 16),

          // English Option
          LanguageCard(
            title: 'English',
            subtitle: 'Interface in English',
            flag: '🇬🇧',
            isSelected: currentLang == 'en',
            onTap: () => _setLanguage('en'),
          ),

          const SizedBox(height: 40),
          FilledButton.icon(
            onPressed: widget.onNext,
            icon: const Icon(Icons.arrow_forward_rounded),
            label: Text(
              isRu ? 'Продолжить' : 'Continue',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            style: FilledButton.styleFrom(
              minimumSize: const Size(double.infinity, 54),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: Divider(
                  color:
                      theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Text(
                  isRu ? 'или' : 'or',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              Expanded(
                child: Divider(
                  color:
                      theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () => _showRestoreModal(context, isRu),
            icon: const Icon(Icons.settings_backup_restore_rounded),
            label: Text(
              isRu ? 'Восстановить из копии' : 'Restore from backup',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 52),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              side: BorderSide(
                color: theme.colorScheme.primary.withValues(alpha: 0.5),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isRu
                ? 'Быстрый перенос всех настроек, аккаунтов и избранного'
                : 'Quickly restore all settings, accounts and favorites',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
