import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:prisma_app/app/app.dart';
import 'package:prisma_app/backend/backend.dart';
import 'package:prisma_app/features/onboarding/presentation/widgets/onboarding_shared_widgets.dart';
import 'package:prisma_app/features/settings/presentation/settings_controller.dart';
import 'package:prisma_app/features/settings/presentation/widgets/settings_shared_widgets.dart';

class OnboardingAppearanceStep extends ConsumerWidget {
  const OnboardingAppearanceStep({
    super.key,
    required this.onNext,
  });

  final VoidCallback onNext;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final settings =
        ref.watch(appSettingsProvider).value ?? AppSettings.defaults;
    final isRu = settings.languageCode == 'ru';
    final isAndroid = Platform.isAndroid;
    final isDark = settings.themeMode == 'dark' ||
        (settings.themeMode == 'system' &&
            MediaQuery.platformBrightnessOf(context) == Brightness.dark);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 12),
          PulsingIconBadge(
            icon: Icons.palette_rounded,
            gradientColors: [
              theme.colorScheme.primary,
              theme.colorScheme.secondary,
            ],
            size: 46,
          ),
          const SizedBox(height: 18),
          Text(
            isRu ? 'Оформление и стиль' : 'Theme & Appearance',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            isRu
                ? 'Выберите тему интерфейса и цветовую палитру под свой вкус'
                : 'Select your preferred theme mode and color palette',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),

          // Interactive Live Preview Mockup Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.cardColor,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Mini Mock Header
                Row(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Center(
                        child: Text(
                          'P',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Prizma',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.auto_awesome_rounded,
                            size: 13,
                            color: theme.colorScheme.onPrimaryContainer,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            isRu ? 'Живое превью' : 'Live Preview',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.onPrimaryContainer,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Mock Post Item with Seed Accent
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest
                        .withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color:
                              theme.colorScheme.primary.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          Icons.image_rounded,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    '#genshin_impact',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: theme.colorScheme.primary,
                                      fontSize: 13,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF10B981)
                                        .withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Text(
                                    'SAFE',
                                    style: TextStyle(
                                      color: Color(0xFF10B981),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 10,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              isRu
                                  ? 'Интерфейс мгновенно адаптируется'
                                  : 'Theme adapts instantly in real time',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Theme Mode Selector
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              isRu ? 'Тема оформления' : 'Theme Mode',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 10),
          SegmentedButton<String>(
            segments: [
              ButtonSegment(
                value: 'dark',
                icon: const Icon(Icons.dark_mode_rounded, size: 18),
                label: Text(isRu ? 'Тёмная' : 'Dark'),
              ),
              ButtonSegment(
                value: 'light',
                icon: const Icon(Icons.light_mode_rounded, size: 18),
                label: Text(isRu ? 'Светлая' : 'Light'),
              ),
              ButtonSegment(
                value: 'system',
                icon: const Icon(Icons.brightness_auto_rounded, size: 18),
                label: Text(isRu ? 'Система' : 'System'),
              ),
            ],
            selected: {settings.themeMode},
            showSelectedIcon: false,
            style: ButtonStyle(
              minimumSize:
                  const WidgetStatePropertyAll(Size(double.infinity, 44)),
              shape: WidgetStatePropertyAll(
                RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
            onSelectionChanged: (selected) {
              HapticFeedback.selectionClick();
              ref.read(settingsControllerProvider.notifier).saveSettings(
                    settings.copyWith(themeMode: selected.first),
                  );
            },
          ),

          // AMOLED True Black (shown if dark or system)
          if (isDark) ...[
            const SizedBox(height: 14),
            Container(
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest
                    .withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color:
                      theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
                ),
              ),
              child: Material(
                color: Colors.transparent,
                child: SwitchListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  secondary: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white24, width: 0.8),
                    ),
                    child: const Icon(
                      Icons.nights_stay_rounded,
                      size: 18,
                      color: Colors.white,
                    ),
                  ),
                  title: Text(
                    isRu ? 'Глубокий чёрный (AMOLED)' : 'Pure Black (AMOLED)',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    isRu
                        ? 'Истинный черный #000000 для OLED дисплеев'
                        : 'True #000000 black background for OLED screens',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  value: settings.amoledMode,
                  onChanged: (val) {
                    HapticFeedback.selectionClick();
                    ref.read(settingsControllerProvider.notifier).saveSettings(
                          settings.copyWith(amoledMode: val),
                        );
                  },
                ),
              ),
            ),
          ],

          const SizedBox(height: 20),

          // Dynamic Colors (Android only)
          if (isAndroid) ...[
            Container(
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest
                    .withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color:
                      theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
                ),
              ),
              child: Material(
                color: Colors.transparent,
                child: SwitchListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  secondary: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.auto_awesome_rounded,
                      size: 18,
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                  title: Text(
                    isRu
                        ? 'Динамические цвета Material You'
                        : 'Material You Dynamic Colors',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    isRu
                        ? 'Палитра подстраивается под обои устройства'
                        : 'Palette adapts to device wallpaper',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  value: settings.useDynamicColor,
                  onChanged: (val) {
                    HapticFeedback.selectionClick();
                    ref.read(settingsControllerProvider.notifier).saveSettings(
                          settings.copyWith(useDynamicColor: val),
                        );
                  },
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Color Swatches
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              isRu ? 'Цветовая палитра' : 'Color Palette',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 12),
          ColorSwatches(
            selected: settings.appSeedColor,
            onChanged: (color) {
              HapticFeedback.selectionClick();
              ref.read(settingsControllerProvider.notifier).saveSettings(
                    settings.copyWith(
                      appSeedColor: color,
                      useDynamicColor: false,
                    ),
                  );
            },
          ),

          const SizedBox(height: 36),
          FilledButton.icon(
            onPressed: onNext,
            icon: const Icon(Icons.arrow_forward_rounded),
            label: Text(
              isRu ? 'Продолжить' : 'Continue',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            style: FilledButton.styleFrom(
              minimumSize: const Size(double.infinity, 54),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
