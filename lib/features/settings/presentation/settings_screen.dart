import 'package:flutter/material.dart';
import 'package:flutter/services.dart' hide appBuildNumber;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:gel_rule_app/app/app.dart';
import 'package:gel_rule_app/app/app_version.dart';
import 'package:gel_rule_app/app/responsive.dart';
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
    final strings = ref.watch(appStringsProvider);
    final isDesktop = Responsive.isDesktop(context);

    if (isDesktop) {
      return Scaffold(
        body: settingsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => ErrorView(message: error.toString()),
          data: (settings) => DesktopSettingsLayout(settings: settings),
        ),
      );
    }

    final canPop = Navigator.of(context).canPop();
    return AdaptiveScaffold(
      title: strings.settings,
      leading: canPop
          ? IconButton(
              icon: const Icon(Icons.arrow_back_rounded),
              tooltip: strings.close,
              onPressed: () => Navigator.of(context).maybePop(),
            )
          : null,
      body: settingsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => ErrorView(message: error.toString()),
        data: (settings) => _SettingsHubContent(settings: settings),
      ),
    );
  }
}

/// Native desktop two-column master-detail layout for settings:
/// Left: Category sidebar with icon badges, quick theme switcher, and active highlight.
/// Right: Direct embedded view of the active settings screen (no full-screen routing, no back button).
class DesktopSettingsLayout extends ConsumerStatefulWidget {
  const DesktopSettingsLayout({super.key, required this.settings});
  final AppSettings settings;

  @override
  ConsumerState<DesktopSettingsLayout> createState() =>
      _DesktopSettingsLayoutState();
}

class _DesktopSettingsLayoutState extends ConsumerState<DesktopSettingsLayout> {
  int _selectedIndex = 0;

  void _handleClose(BuildContext context) {
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else if (context.canPop()) {
      context.pop();
    } else {
      context.go('/');
    }
  }

  Future<void> _update(AppSettings newSettings) {
    return ref
        .read(settingsControllerProvider.notifier)
        .saveSettings(newSettings);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final strings = ref.watch(appStringsProvider);
    final isRu = widget.settings.languageCode == 'ru';

    final categories = [
      (
        icon: Icons.tune_rounded,
        color: const Color(0xFF6366F1),
        title: isRu ? 'Основное' : 'General',
        subtitle: buildGeneralSummary(widget.settings, isRu),
      ),
      (
        icon: Icons.palette_rounded,
        color: const Color(0xFFE84D8A),
        title: isRu ? 'Внешний вид' : 'Appearance',
        subtitle: buildAppearanceSummary(widget.settings, isRu),
      ),
      (
        icon: Icons.grid_view_rounded,
        color: const Color(0xFF10B981),
        title: isRu ? 'Лента и сетка' : 'Feed & Grid',
        subtitle: buildFeedSummary(widget.settings, isRu),
      ),
      (
        icon: Icons.filter_alt_rounded,
        color: const Color(0xFFF59E0B),
        title: isRu ? 'Фильтры и контент' : 'Filters & Content',
        subtitle: buildFiltersSummary(widget.settings, isRu),
      ),
      (
        icon: Icons.storage_rounded,
        color: const Color(0xFF06B6D4),
        title: isRu ? 'Память и бэкап' : 'Storage & Backup',
        subtitle: buildStorageSummary(widget.settings, isRu),
      ),
      (
        icon: Icons.cloud_sync_rounded,
        color: const Color(0xFF0EA5E9),
        title: isRu ? 'Аккаунты и источники' : 'Accounts & Sync',
        subtitle: buildAccountsSummary(widget.settings, isRu),
      ),
      (
        icon: Icons.info_rounded,
        color: const Color(0xFF8B5CF6),
        title: strings.about,
        subtitle: 'Prisma v$appDisplayVersion (b$appBuildNumber)',
      ),
    ];

    Widget selectedScreen;
    switch (_selectedIndex) {
      case 0:
        selectedScreen = const GeneralSettingsScreen(embedded: true);
        break;
      case 1:
        selectedScreen = const AppearanceSettingsScreen(embedded: true);
        break;
      case 2:
        selectedScreen = const FeedSettingsScreen(embedded: true);
        break;
      case 3:
        selectedScreen = const FiltersSettingsScreen(embedded: true);
        break;
      case 4:
        selectedScreen = const StorageSettingsScreen(embedded: true);
        break;
      case 5:
        selectedScreen = const AccountsSettingsScreen(embedded: true);
        break;
      case 6:
      default:
        selectedScreen = const AboutSettingsScreen(embedded: true);
        break;
    }

    final content = Row(
          children: [
            // Left master category sidebar
            Container(
              width: 325,
              decoration: BoxDecoration(
                color: isDark
                    ? theme.colorScheme.surfaceContainerLowest
                    : theme.colorScheme.surfaceContainerLow,
                border: Border(
                  right: BorderSide(
                    color: theme.colorScheme.outlineVariant
                        .withValues(alpha: 0.25),
                  ),
                ),
              ),
              child: Column(
                children: [
                  // Top Bar with Back / Close Button and Title
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
                    child: Row(
                      children: [
                        IconButton.filledTonal(
                          icon: const Icon(Icons.arrow_back_rounded, size: 20),
                          tooltip: isRu ? 'Назад (Esc)' : 'Back (Esc)',
                          onPressed: () => _handleClose(context),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            strings.settings,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                              fontSize: 17,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, size: 20),
                          tooltip: isRu ? 'Закрыть (Esc)' : 'Close (Esc)',
                          onPressed: () => _handleClose(context),
                        ),
                      ],
                    ),
                  ),

                  // Top Quick Brand Card
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 4, 14, 6),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainer,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: theme.colorScheme.outlineVariant
                          .withValues(alpha: 0.3),
                    ),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Image.asset(
                              'assets/icon/app_icon.png',
                              width: 36,
                              height: 36,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                width: 36,
                                height: 36,
                                color: const Color(0xFFE84D8A),
                                child: const Icon(Icons.palette_rounded,
                                    color: Colors.white, size: 20),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Prisma',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 15,
                                  ),
                                ),
                                Text(
                                  'v$appDisplayVersion (build $appBuildNumber)',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      SegmentedButton<String>(
                        segments: [
                          ButtonSegment<String>(
                            value: 'system',
                            icon: const Icon(Icons.brightness_auto_rounded,
                                size: 14),
                            label: Text(
                              isRu ? 'Авто' : 'Auto',
                              style: const TextStyle(fontSize: 10.5),
                              maxLines: 1,
                              softWrap: false,
                            ),
                          ),
                          ButtonSegment<String>(
                            value: 'light',
                            icon:
                                const Icon(Icons.light_mode_rounded, size: 14),
                            label: Text(
                              isRu ? 'Светлая' : 'Light',
                              style: const TextStyle(fontSize: 10.5),
                              maxLines: 1,
                              softWrap: false,
                            ),
                          ),
                          ButtonSegment<String>(
                            value: 'dark',
                            icon: const Icon(Icons.dark_mode_rounded, size: 14),
                            label: Text(
                              isRu ? 'Темная' : 'Dark',
                              style: const TextStyle(fontSize: 10.5),
                              maxLines: 1,
                              softWrap: false,
                            ),
                          ),
                        ],
                        selected: {widget.settings.themeMode},
                        showSelectedIcon: false,
                        style: ButtonStyle(
                          visualDensity:
                              const VisualDensity(horizontal: -3, vertical: -3),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          padding: const WidgetStatePropertyAll(
                            EdgeInsets.symmetric(horizontal: 2, vertical: 3),
                          ),
                          shape: WidgetStatePropertyAll(
                            RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                        onSelectionChanged: (selected) {
                          HapticFeedback.selectionClick();
                          _update(widget.settings
                              .copyWith(themeMode: selected.first));
                        },
                      ),
                    ],
                  ),
                ),
              ),

              // Categories List
              Expanded(
                child: ListView.separated(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  itemCount: categories.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 4),
                  itemBuilder: (context, index) {
                    final cat = categories[index];
                    final isSelected = _selectedIndex == index;

                    return Material(
                      color: isSelected
                          ? scheme.primary
                              .withValues(alpha: isDark ? 0.20 : 0.12)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () {
                          if (_selectedIndex != index) {
                            HapticFeedback.selectionClick();
                            setState(() => _selectedIndex = index);
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected
                                  ? scheme.primary
                                      .withValues(alpha: isDark ? 0.45 : 0.30)
                                  : Colors.transparent,
                              width: 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              SettingsIconBadge(
                                icon: cat.icon,
                                color: cat.color,
                                size: 32,
                                iconSize: 16,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      cat.title,
                                      style:
                                          theme.textTheme.bodyMedium?.copyWith(
                                        fontWeight: isSelected
                                            ? FontWeight.w700
                                            : FontWeight.w600,
                                        fontSize: 13.5,
                                        color: isSelected
                                            ? scheme.primary
                                            : (isDark
                                                ? Colors.white
                                                : Colors.black87),
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      cat.subtitle,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style:
                                          theme.textTheme.bodySmall?.copyWith(
                                        color:
                                            theme.colorScheme.onSurfaceVariant,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (isSelected)
                                Container(
                                  width: 3.5,
                                  height: 20,
                                  decoration: BoxDecoration(
                                    color: scheme.primary,
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),

        // Right detail screen panel
        Expanded(
          child: KeyedSubtree(
            key: ValueKey(_selectedIndex),
            child: selectedScreen,
          ),
        ),
      ],
    );

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): () =>
            _handleClose(context),
      },
      child: Focus(
        autofocus: true,
        child: content,
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
    return ref
        .read(settingsControllerProvider.notifier)
        .saveSettings(newSettings);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isRu = settings.languageCode == 'ru';
    final strings = ref.watch(appStringsProvider);

    // Dynamic subtitles reflecting current state
    final generalSummary = buildGeneralSummary(settings, isRu);
    final appearanceSummary = buildAppearanceSummary(settings, isRu);
    final feedSummary = buildFeedSummary(settings, isRu);
    final filtersSummary = buildFiltersSummary(settings, isRu);
    final storageSummary = buildStorageSummary(settings, isRu);
    final accountsSummary = buildAccountsSummary(settings, isRu);
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
                  color:
                      theme.colorScheme.outlineVariant.withValues(alpha: 0.35),
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
                              color: const Color(0xFFE84D8A)
                                  .withValues(alpha: 0.30),
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
                                  colors: [
                                    Color(0xFFE84D8A),
                                    Color(0xFF8B5CF6)
                                  ],
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
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Quick Theme Segment
                  SegmentedButton<String>(
                    segments: [
                      ButtonSegment(
                        value: 'system',
                        icon:
                            const Icon(Icons.brightness_auto_rounded, size: 16),
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
                      visualDensity:
                          const VisualDensity(horizontal: -2, vertical: -2),
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
                        RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                    onSelectionChanged: (selected) {
                      HapticFeedback.selectionClick();
                      _update(
                          ref, settings.copyWith(themeMode: selected.first));
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
}

String buildGeneralSummary(AppSettings settings, bool isRu) {
  final themeTitle = settings.themeMode == 'dark'
      ? (settings.amoledMode
          ? (isRu ? 'AMOLED' : 'AMOLED')
          : (isRu ? 'Темная' : 'Dark'))
      : settings.themeMode == 'light'
          ? (isRu ? 'Светлая' : 'Light')
          : (isRu ? 'Авто' : 'Auto');
  final langTitle = settings.languageCode == 'ru' ? 'Русский' : 'English';
  return '$themeTitle • $langTitle';
}

String buildAppearanceSummary(AppSettings settings, bool isRu) {
  final dynamicCol = settings.useDynamicColor
      ? (isRu ? 'Material You' : 'Dynamic Color')
      : (isRu ? 'Свой акцент' : 'Custom accent');
  final badges = settings.showPostBadges
      ? (isRu ? 'Бейджи' : 'Badges')
      : (isRu ? 'Без бейджей' : 'No badges');
  return '$dynamicCol • $badges';
}

String buildFeedSummary(AppSettings settings, bool isRu) {
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

String buildFiltersSummary(AppSettings settings, bool isRu) {
  final nsfw = settings.nsfwEnabled
      ? (isRu ? 'NSFW вкл.' : 'NSFW allowed')
      : (isRu ? 'Только Safe' : 'Safe only');
  final blacklistCount =
      {...settings.blacklistedTags, ...settings.smartBlacklistRules}.length;
  final bl = isRu ? 'Бан: $blacklistCount' : 'Blacklist: $blacklistCount';
  return '$nsfw • $bl';
}

String buildStorageSummary(AppSettings settings, bool isRu) {
  final cacheItems = isRu
      ? 'Кэш: ${settings.cacheMaxItems}'
      : 'Cache: ${settings.cacheMaxItems}';
  final autoBackup = settings.autoDownloadFavorites
      ? (isRu ? 'Автозагрузка' : 'Auto-DL')
      : (isRu ? 'Ручная' : 'Manual');
  return '$cacheItems • $autoBackup';
}

String buildAccountsSummary(AppSettings settings, bool isRu) {
  final pawchiveCount = settings.pawchiveAccounts.length;
  return isRu
      ? 'Pawchive ($pawchiveCount) • e621 / e926 • Источники'
      : 'Pawchive ($pawchiveCount) • e621 / e926 • Providers';
}
