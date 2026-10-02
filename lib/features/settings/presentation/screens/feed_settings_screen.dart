import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:gel_rule_app/app/app_strings.dart';
import 'package:gel_rule_app/app/motion.dart';
import 'package:gel_rule_app/backend/backend.dart';
import 'package:gel_rule_app/features/settings/presentation/settings_controller.dart';
import 'package:gel_rule_app/features/settings/presentation/widgets/settings_shared_widgets.dart';

class FeedSettingsScreen extends ConsumerWidget {
  const FeedSettingsScreen({super.key});

  Future<void> _update(WidgetRef ref, AppSettings settings) {
    return ref.read(settingsControllerProvider.notifier).saveSettings(settings);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings =
        ref.watch(settingsControllerProvider).value ?? AppSettings.defaults;
    final strings = AppStrings(settings.languageCode);
    final isRu = strings.ru;
    final theme = Theme.of(context);
    final isAndroid = Platform.isAndroid;

    final deviceInfo =
        isAndroid ? ref.watch(motionDeviceInfoProvider).value : null;
    final detectedHz =
        isAndroid ? View.maybeOf(context)?.display.refreshRate ?? 60.0 : 60.0;
    final motion = isAndroid
        ? resolveMotionSettings(
            settings: settings,
            detectedHz: detectedHz,
            device: deviceInfo,
          )
        : null;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const SettingsIconBadge(
              icon: Icons.dashboard_customize_rounded,
              color: Color(0xFF10B981),
              size: 30,
              iconSize: 16,
            ),
            const SizedBox(width: 10),
            Text(
              strings.feedLayout,
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
              // Grid Columns & Layout
              SettingsCardGroup(
                title: isRu ? 'Сетка и колонки' : 'Grid & Columns',
                icon: Icons.grid_view_rounded,
                accentColor: const Color(0xFF10B981),
                children: [
                  SettingsStepperTile(
                    icon: Icons.smartphone_rounded,
                    iconColor: const Color(0xFF6366F1),
                    title: strings.mobileColumns,
                    subtitle: isRu
                        ? 'Количество столбцов постов на телефоне'
                        : 'Columns on phone layout',
                    value: settings.mobileColumns,
                    min: 1,
                    max: 3,
                    onChanged: (val) =>
                        _update(ref, settings.copyWith(mobileColumns: val)),
                  ),
                  const SettingsDivider(),
                  SettingsStepperTile(
                    icon: Icons.desktop_windows_rounded,
                    iconColor: const Color(0xFF3B82F6),
                    title: strings.desktopColumns,
                    subtitle: isRu
                        ? 'Количество столбцов постов на ПК и планшетах'
                        : 'Columns on desktop & tablet layout',
                    value: settings.desktopColumns,
                    min: 3,
                    max: 8,
                    onChanged: (val) =>
                        _update(ref, settings.copyWith(desktopColumns: val)),
                  ),
                  const SettingsDivider(),
                  SettingsSwitchTile(
                    icon: Icons.visibility_off_rounded,
                    iconColor: const Color(0xFFF59E0B),
                    title: strings.hideViewed,
                    subtitle: isRu
                        ? 'Автоматически скрывать просмотренные посты из ленты'
                        : 'Automatically hide already seen posts from feed',
                    value: settings.hideViewedPosts,
                    onChanged: (val) =>
                        _update(ref, settings.copyWith(hideViewedPosts: val)),
                  ),
                ],
              ),

              // Media Quality in Grid
              SettingsCardGroup(
                title: strings.mediaQuality,
                icon: Icons.high_quality_rounded,
                accentColor: const Color(0xFF06B6D4),
                children: [
                  SettingsSegmentedTile<String>(
                    icon: Icons.image_rounded,
                    iconColor: const Color(0xFF06B6D4),
                    title: strings.mediaQuality,
                    subtitle: isRu
                        ? 'Разрешение загружаемых картинок в сетке'
                        : 'Resolution profile for feed thumbnails',
                    segments: [
                      for (final mode in MediaQualityMode.values)
                        ButtonSegment(
                          value: mode.name,
                          label: Text(
                            isRu
                                ? switch (mode) {
                                    MediaQualityMode.auto => 'Авто',
                                    MediaQualityMode.dataSaver => 'Экономия',
                                    MediaQualityMode.highQuality => 'HQ',
                                  }
                                : mode.label,
                          ),
                        ),
                    ],
                    selected: {settings.mediaQualityMode},
                    onSelectionChanged: (set) => _update(
                      ref,
                      settings.copyWith(mediaQualityMode: set.first),
                    ),
                  ),
                ],
              ),

              // Motion & Smoothness (Android)
              if (isAndroid)
                SettingsCardGroup(
                  title: isRu ? 'Плавность экрана и частота' : 'Screen Refresh Rate',
                  icon: Icons.speed_rounded,
                  accentColor: const Color(0xFFF59E0B),
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const SettingsIconBadge(
                                icon: Icons.speed_rounded,
                                color: Color(0xFFF59E0B),
                                size: 34,
                                iconSize: 18,
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      isRu
                                          ? 'Частота обновления экрана'
                                          : 'Animation refresh profile',
                                      style: theme.textTheme.bodyLarge
                                          ?.copyWith(fontWeight: FontWeight.w600),
                                    ),
                                    Text(
                                      isRu
                                          ? 'Оптимизация плавности скролла ленты'
                                          : 'Fluid 120-165 Hz scrolling optimization',
                                      style: theme.textTheme.bodyMedium?.copyWith(
                                        color: theme.colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (final mode in MotionRefreshMode.values)
                                ChoiceChip(
                                  label: Text(mode.label),
                                  selected:
                                      settings.motionRefreshMode == mode.name,
                                  onSelected: (selected) {
                                    if (selected) {
                                      _update(
                                        ref,
                                        settings.copyWith(
                                          motionRefreshMode: mode.name,
                                        ),
                                      );
                                    }
                                  },
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SettingsDivider(),
                    SettingsSwitchTile(
                      icon: Icons.battery_saver_rounded,
                      iconColor: const Color(0xFF22C55E),
                      title: isRu
                          ? 'Энергосбережение: 60 Гц при < 20% батареи'
                          : 'Auto 60 Hz below 20% battery',
                      subtitle: isRu
                          ? 'Определено ${motion?.detectedHz.toStringAsFixed(0) ?? "60"} Гц'
                              '${motion?.batteryLevel == null ? '' : ', заряд ${motion!.batteryLevel}%'}'
                              '${motion?.batterySaverActive == true ? ', режим энергосбережения' : ''}'
                          : 'Detected ${motion?.detectedHz.toStringAsFixed(0) ?? "60"} Hz'
                              '${motion?.batteryLevel == null ? '' : ', battery ${motion!.batteryLevel}%'}'
                              '${motion?.batterySaverActive == true ? ', saver active' : ''}',
                      value: settings.autoBatterySaver60Hz,
                      onChanged: (val) => _update(
                        ref,
                        settings.copyWith(autoBatterySaver60Hz: val),
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
