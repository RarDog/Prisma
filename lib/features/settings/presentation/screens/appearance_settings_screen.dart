import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:gel_rule_app/app/app_strings.dart';
import 'package:gel_rule_app/backend/backend.dart';
import 'package:gel_rule_app/features/settings/presentation/settings_controller.dart';
import 'package:gel_rule_app/features/settings/presentation/widgets/settings_shared_widgets.dart';

class AppearanceSettingsScreen extends ConsumerWidget {
  const AppearanceSettingsScreen({super.key});

  Future<void> _update(WidgetRef ref, AppSettings settings) {
    return ref.read(settingsControllerProvider.notifier).saveSettings(settings);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings =
        ref.watch(settingsControllerProvider).value ?? AppSettings.defaults;
    final strings = AppStrings(settings.languageCode);
    final isRu = strings.ru;
    final isAndroid = Platform.isAndroid;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const SettingsIconBadge(
              icon: Icons.palette_rounded,
              color: Color(0xFF8B5CF6),
              size: 30,
              iconSize: 16,
            ),
            const SizedBox(width: 10),
            Text(
              strings.appearance,
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
              // Accent & Palette
              SettingsCardGroup(
                title: isRu ? 'Цветовая палитра' : 'Color Palette',
                icon: Icons.color_lens_rounded,
                accentColor: const Color(0xFF8B5CF6),
                children: [
                  if (isAndroid) ...[
                    SettingsSwitchTile(
                      icon: Icons.auto_awesome_rounded,
                      iconColor: const Color(0xFFEC4899),
                      title: isRu
                          ? 'Динамические цвета Material You'
                          : 'Material You Dynamic Colors',
                      subtitle: isRu
                          ? 'Палитра интерфейса подстраивается под обои системы'
                          : 'Color palette adapts automatically to device wallpaper',
                      value: settings.useDynamicColor,
                      onChanged: (val) =>
                          _update(ref, settings.copyWith(useDynamicColor: val)),
                    ),
                    const SettingsDivider(),
                  ],
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    child: ColorSwatches(
                      selected: settings.appSeedColor,
                      onChanged: (color) =>
                          _update(ref, settings.copyWith(appSeedColor: color)),
                    ),
                  ),
                ],
              ),

              // Badges & Card Elements
              SettingsCardGroup(
                title: isRu ? 'Карточки постов' : 'Post Cards',
                icon: Icons.style_rounded,
                accentColor: const Color(0xFFF59E0B),
                children: [
                  SettingsSwitchTile(
                    icon: Icons.label_important_outline_rounded,
                    iconColor: const Color(0xFFF59E0B),
                    title: strings.showPostBadges,
                    subtitle: isRu
                        ? 'Индикаторы видео, источников, рейтингов и статусов'
                        : 'Show source, rating and media indicators on cards',
                    value: settings.showPostBadges,
                    onChanged: (val) =>
                        _update(ref, settings.copyWith(showPostBadges: val)),
                  ),
                ],
              ),

              // Navigation Tabs Visibility
              SettingsCardGroup(
                title: isRu ? 'Панель навигации' : 'Navigation Bar',
                icon: Icons.tab_rounded,
                accentColor: const Color(0xFF3B82F6),
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    child: TabVisibilityEditor(
                      hiddenTabs: settings.hiddenTabs,
                      onChanged: (hiddenTabs) =>
                          _update(ref, settings.copyWith(hiddenTabs: hiddenTabs)),
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
