import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:gel_rule_app/app/app_strings.dart';
import 'package:gel_rule_app/backend/backend.dart';
import 'package:gel_rule_app/features/settings/presentation/settings_controller.dart';
import 'package:gel_rule_app/features/settings/presentation/widgets/settings_shared_widgets.dart';

class GeneralSettingsScreen extends ConsumerWidget {
  const GeneralSettingsScreen({super.key});

  Future<void> _update(WidgetRef ref, AppSettings settings) {
    return ref.read(settingsControllerProvider.notifier).saveSettings(settings);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings =
        ref.watch(settingsControllerProvider).value ?? AppSettings.defaults;
    final strings = AppStrings(settings.languageCode);
    final isRu = strings.ru;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const SettingsIconBadge(
              icon: Icons.tune_rounded,
              color: Color(0xFF6366F1),
              size: 30,
              iconSize: 16,
            ),
            const SizedBox(width: 10),
            Text(
              strings.general,
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
              // Theme Mode Group
              SettingsCardGroup(
                title: strings.theme,
                icon: Icons.brightness_6_rounded,
                accentColor: const Color(0xFF6366F1),
                children: [
                  SettingsSegmentedTile<String>(
                    icon: Icons.dark_mode_rounded,
                    iconColor: const Color(0xFF6366F1),
                    title: strings.theme,
                    subtitle: isRu
                        ? 'Оформление цветовой схемы приложения'
                        : 'App theme brightness mode',
                    segments: [
                      ButtonSegment(
                        value: 'dark',
                        icon: const Icon(Icons.dark_mode_rounded, size: 16),
                        label: Text(isRu ? 'Темная' : 'Dark'),
                      ),
                      ButtonSegment(
                        value: 'light',
                        icon: const Icon(Icons.light_mode_rounded, size: 16),
                        label: Text(isRu ? 'Светлая' : 'Light'),
                      ),
                      ButtonSegment(
                        value: 'system',
                        icon: const Icon(Icons.brightness_auto_rounded, size: 16),
                        label: Text(isRu ? 'Авто' : 'Auto'),
                      ),
                    ],
                    selected: {settings.themeMode},
                    onSelectionChanged: (set) => _update(
                      ref,
                      settings.copyWith(themeMode: set.first),
                    ),
                  ),
                  const SettingsDivider(),
                  SettingsSwitchTile(
                    icon: Icons.contrast_rounded,
                    iconColor: const Color(0xFF475569),
                    title: isRu ? 'AMOLED Pure Black' : 'AMOLED Pure Black',
                    subtitle: isRu
                        ? 'Абсолютно черный фон (#000000) для OLED-дисплеев'
                        : 'Deep black (#000000) surfaces for OLED screens',
                    value: settings.amoledMode,
                    onChanged: (val) =>
                        _update(ref, settings.copyWith(amoledMode: val)),
                  ),
                ],
              ),

              // Language Group
              SettingsCardGroup(
                title: strings.language,
                icon: Icons.translate_rounded,
                accentColor: const Color(0xFF8B5CF6),
                children: [
                  SettingsSegmentedTile<String>(
                    icon: Icons.language_rounded,
                    iconColor: const Color(0xFF8B5CF6),
                    title: strings.language,
                    subtitle: isRu
                        ? 'Язык интерфейса приложения'
                        : 'App user interface language',
                    segments: const [
                      ButtonSegment(
                        value: 'ru',
                        label: Text('🇷🇺 Русский'),
                      ),
                      ButtonSegment(
                        value: 'en',
                        label: Text('🇬🇧 English'),
                      ),
                    ],
                    selected: {settings.languageCode},
                    onSelectionChanged: (set) => _update(
                      ref,
                      settings.copyWith(languageCode: set.first),
                    ),
                  ),
                ],
              ),

              // Downloads & Automation
              SettingsCardGroup(
                title: isRu ? 'Загрузки и медиа' : 'Downloads & Media',
                icon: Icons.download_rounded,
                accentColor: const Color(0xFF10B981),
                children: [
                  SettingsSwitchTile(
                    icon: Icons.download_rounded,
                    iconColor: const Color(0xFF10B981),
                    title: strings.allowDownloads,
                    subtitle: isRu
                        ? 'Кнопки быстрого скачивания медиафайлов'
                        : 'Enable direct download buttons on cards & viewer',
                    value: settings.allowDownloads,
                    onChanged: (val) =>
                        _update(ref, settings.copyWith(allowDownloads: val)),
                  ),
                  const SettingsDivider(),
                  SettingsSwitchTile(
                    icon: Icons.offline_pin_rounded,
                    iconColor: const Color(0xFF06B6D4),
                    title: isRu ? 'Offline избранное' : 'Offline favorites',
                    subtitle: isRu
                        ? 'Фоновая загрузка медиафайла при добавлении поста в избранное'
                        : 'Automatically cache files in background when favorited',
                    value: settings.autoDownloadFavorites,
                    onChanged: (val) => _update(
                      ref,
                      settings.copyWith(autoDownloadFavorites: val),
                    ),
                  ),
                  if (settings.allowDownloads) ...[
                    const SettingsDivider(),
                    SettingsFolderStructureTile(
                      currentTemplate: settings.downloadPathTemplate,
                      isRu: isRu,
                      onChanged: (template) => _update(
                        ref,
                        settings.copyWith(downloadPathTemplate: template),
                      ),
                    ),
                  ],
                ],
              ),

              // Updates & System Preferences
              SettingsCardGroup(
                title: isRu ? 'Обновления и система' : 'Updates & System',
                icon: Icons.system_update_rounded,
                accentColor: const Color(0xFFF97316),
                children: [
                  SettingsSwitchTile(
                    icon: Icons.science_rounded,
                    iconColor: const Color(0xFFF97316),
                    title: isRu
                        ? 'Beta и экспериментальные обновления'
                        : 'Receive beta & experimental updates',
                    subtitle: isRu
                        ? 'Проверка и уведомление о prerelease сборках Prisma'
                        : 'Include prerelease builds when checking for updates',
                    value: settings.allowExperimentalUpdates,
                    onChanged: (val) => _update(
                      ref,
                      settings.copyWith(allowExperimentalUpdates: val),
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
