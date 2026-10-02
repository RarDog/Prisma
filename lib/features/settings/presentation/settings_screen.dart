import 'package:flutter/material.dart';
import 'package:flutter/services.dart' hide appBuildNumber;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:gel_rule_app/app/app_strings.dart';
import 'package:gel_rule_app/app/app_version.dart';
import 'package:gel_rule_app/backend/backend.dart';
import 'package:gel_rule_app/features/settings/presentation/screens/about_settings_screen.dart';
import 'package:gel_rule_app/features/settings/presentation/screens/accounts_settings_screen.dart';
import 'package:gel_rule_app/features/settings/presentation/screens/appearance_settings_screen.dart';
import 'package:gel_rule_app/features/settings/presentation/screens/feed_settings_screen.dart';
import 'package:gel_rule_app/features/settings/presentation/screens/filters_settings_screen.dart';
import 'package:gel_rule_app/features/settings/presentation/screens/general_settings_screen.dart';
import 'package:gel_rule_app/features/settings/presentation/screens/storage_settings_screen.dart';
import 'package:gel_rule_app/features/settings/presentation/settings_controller.dart';
import 'package:gel_rule_app/features/settings/presentation/widgets/settings_shared_widgets.dart';
import 'package:gel_rule_app/shared/widgets/adaptive_scaffold.dart';
import 'package:gel_rule_app/shared/widgets/error_view.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsAsync = ref.watch(settingsControllerProvider);
    final currentSettings = settingsAsync.value ?? AppSettings.defaults;
    final strings = AppStrings(currentSettings.languageCode);

    return AdaptiveScaffold(
      title: strings.settings,
      body: settingsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => ErrorView(message: error.toString()),
        data: (settings) => _SettingsHubContent(settings: settings),
      ),
    );
  }
}

class _SettingsHubContent extends ConsumerWidget {
  const _SettingsHubContent({required this.settings});

  final AppSettings settings;

  void _pushScreen(BuildContext context, Widget screen) {
    HapticFeedback.lightImpact();
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => screen),
    );
  }

  Future<void> _update(WidgetRef ref, AppSettings newSettings) {
    return ref.read(settingsControllerProvider.notifier).saveSettings(newSettings);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isRu = settings.languageCode == 'ru';
    final strings = AppStrings(settings.languageCode);

    // Dynamic subtitles reflecting current state
    final generalSummary = _buildGeneralSummary(isRu);
    final appearanceSummary = _buildAppearanceSummary(isRu);
    final feedSummary = _buildFeedSummary(isRu);
    final filtersSummary = _buildFiltersSummary(isRu);
    final storageSummary = _buildStorageSummary(isRu);
    final accountsSummary = _buildAccountsSummary(isRu);
    const aboutSummary = 'Prisma v$appDisplayVersion (b$appBuildNumber)';

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            16,
            12,
            16,
            120 + MediaQuery.paddingOf(context).bottom,
          ),
          children: [
            // Top Quick Hero Card
            Container(
              padding: const EdgeInsets.all(18),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: theme.colorScheme.outlineVariant.withValues(alpha: 0.35),
                ),
                gradient: LinearGradient(
                  colors: [
                    theme.colorScheme.surfaceContainerLow,
                    theme.colorScheme.surfaceContainer,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFE84D8A).withValues(alpha: 0.30),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: Image.asset(
                            'assets/icon/app_icon.png',
                            width: 48,
                            height: 48,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFFE84D8A), Color(0xFF8B5CF6)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: const Icon(
                                Icons.palette_rounded,
                                color: Colors.white,
                                size: 26,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Prisma',
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.4,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'v$appDisplayVersion (build $appBuildNumber)',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          isRu ? 'Настройки' : 'Hub',
                          style: theme.textTheme.labelMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Quick Theme Segment
                  SegmentedButton<String>(
                    segments: [
                      ButtonSegment(
                        value: 'system',
                        icon: const Icon(Icons.brightness_auto_rounded, size: 16),
                        label: Text(
                          isRu ? 'Авто' : 'Auto',
                          maxLines: 1,
                          softWrap: false,
                        ),
                      ),
                      ButtonSegment(
                        value: 'light',
                        icon: const Icon(Icons.light_mode_rounded, size: 16),
                        label: Text(
                          isRu ? 'Светлая' : 'Light',
                          maxLines: 1,
                          softWrap: false,
                        ),
                      ),
                      ButtonSegment(
                        value: 'dark',
                        icon: const Icon(Icons.dark_mode_rounded, size: 16),
                        label: Text(
                          isRu ? 'Темная' : 'Dark',
                          maxLines: 1,
                          softWrap: false,
                        ),
                      ),
                    ],
                    selected: {settings.themeMode},
                    showSelectedIcon: false,
                    style: ButtonStyle(
                      visualDensity: const VisualDensity(horizontal: -2, vertical: -2),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      padding: const WidgetStatePropertyAll(
                        EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                      ),
                      textStyle: const WidgetStatePropertyAll(
                        TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.2,
                        ),
                      ),
                      shape: WidgetStatePropertyAll(
                        RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                    onSelectionChanged: (selected) {
                      HapticFeedback.selectionClick();
                      _update(ref, settings.copyWith(themeMode: selected.first));
                    },
                  ),
                ],
              ),
            ),

            // 1. General
            SettingsCategoryCard(
              title: isRu ? 'Основное' : 'General',
              subtitle: generalSummary,
              icon: Icons.tune_rounded,
              color: const Color(0xFF8B5CF6),
              onTap: () => _pushScreen(
                context,
                const GeneralSettingsScreen(),
              ),
            ),
            const SizedBox(height: 10),

            // 2. Appearance
            SettingsCategoryCard(
              title: isRu ? 'Внешний вид' : 'Appearance',
              subtitle: appearanceSummary,
              icon: Icons.palette_rounded,
              color: const Color(0xFFE84D8A),
              onTap: () => _pushScreen(
                context,
                const AppearanceSettingsScreen(),
              ),
            ),
            const SizedBox(height: 10),

            // 3. Feed & Grid
            SettingsCategoryCard(
              title: isRu ? 'Лента и сетка' : 'Feed & Grid',
              subtitle: feedSummary,
              icon: Icons.grid_view_rounded,
              color: const Color(0xFF10B981),
              onTap: () => _pushScreen(
                context,
                const FeedSettingsScreen(),
              ),
            ),
            const SizedBox(height: 10),

            // 4. Filters & Content
            SettingsCategoryCard(
              title: isRu ? 'Фильтры и контент' : 'Filters & Content',
              subtitle: filtersSummary,
              icon: Icons.filter_alt_rounded,
              color: const Color(0xFFF59E0B),
              onTap: () => _pushScreen(
                context,
                const FiltersSettingsScreen(),
              ),
            ),
            const SizedBox(height: 10),

            // 5. Storage & Backups
            SettingsCategoryCard(
              title: isRu ? 'Память и бэкап' : 'Storage & Backup',
              subtitle: storageSummary,
              icon: Icons.storage_rounded,
              color: const Color(0xFF06B6D4),
              onTap: () => _pushScreen(
                context,
                const StorageSettingsScreen(),
              ),
            ),
            const SizedBox(height: 10),

            // 6. Accounts
            SettingsCategoryCard(
              title: isRu ? 'Аккаунты и источники' : 'Accounts & Sync',
              subtitle: accountsSummary,
              icon: Icons.cloud_sync_rounded,
              color: const Color(0xFF0EA5E9),
              onTap: () => _pushScreen(
                context,
                const AccountsSettingsScreen(),
              ),
            ),
            const SizedBox(height: 10),

            // 7. About & Diagnostics
            SettingsCategoryCard(
              title: strings.about,
              subtitle: aboutSummary,
              icon: Icons.info_rounded,
              color: const Color(0xFF6366F1),
              onTap: () => _pushScreen(
                context,
                const AboutSettingsScreen(),
              ),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  String _buildGeneralSummary(bool isRu) {
    final themeTitle = settings.themeMode == 'dark'
        ? (settings.amoledMode ? (isRu ? 'AMOLED' : 'AMOLED') : (isRu ? 'Темная' : 'Dark'))
        : settings.themeMode == 'light'
            ? (isRu ? 'Светлая' : 'Light')
            : (isRu ? 'Авто' : 'Auto');
    final langTitle = settings.languageCode == 'ru' ? 'Русский' : 'English';
    return '$themeTitle • $langTitle';
  }

  String _buildAppearanceSummary(bool isRu) {
    final dynamicCol = settings.useDynamicColor
        ? (isRu ? 'Material You' : 'Dynamic Color')
        : (isRu ? 'Свой акцент' : 'Custom accent');
    final badges = settings.showPostBadges
        ? (isRu ? 'Бейджи' : 'Badges')
        : (isRu ? 'Без бейджей' : 'No badges');
    return '$dynamicCol • $badges';
  }

  String _buildFeedSummary(bool isRu) {
    final cols = isRu
        ? '${settings.mobileColumns} ${settings.mobileColumns == 1 ? "колонка" : (settings.mobileColumns < 5 ? "колонки" : "колонок")}'
        : '${settings.mobileColumns} cols';
    final motion = _formatMotionMode(settings.motionRefreshMode, isRu);
    return '$cols • $motion';
  }

  String _formatMotionMode(String mode, bool isRu) {
    return switch (mode) {
      'hz165' => '165 Гц',
      'hz144' => '144 Гц',
      'hz120' => '120 Гц',
      'hz90' => '90 Гц',
      'hz60' => '60 Гц',
      'followDisplay' => isRu ? 'Авто' : 'Auto',
      'system' => isRu ? 'Система' : 'System',
      _ => mode.replaceAll('hz', '') + (isRu ? ' Гц' : ' Hz'),
    };
  }

  String _buildFiltersSummary(bool isRu) {
    final nsfw = settings.nsfwEnabled
        ? (isRu ? 'NSFW вкл.' : 'NSFW allowed')
        : (isRu ? 'Только Safe' : 'Safe only');
    final blacklistCount = settings.blacklistedTags.length;
    final bl = isRu
        ? 'Бан: $blacklistCount'
        : 'Blacklist: $blacklistCount';
    return '$nsfw • $bl';
  }

  String _buildStorageSummary(bool isRu) {
    final cacheItems = isRu
        ? 'Кэш: ${settings.cacheMaxItems}'
        : 'Cache: ${settings.cacheMaxItems}';
    final autoBackup = settings.autoDownloadFavorites
        ? (isRu ? 'Автозагрузка' : 'Auto-DL')
        : (isRu ? 'Ручная' : 'Manual');
    return '$cacheItems • $autoBackup';
  }

  String _buildAccountsSummary(bool isRu) {
    final pawchiveCount = settings.pawchiveAccounts.length;
    return isRu
        ? 'Pawchive ($pawchiveCount) • Провайдеры'
        : 'Pawchive ($pawchiveCount) • Providers';
  }
}
