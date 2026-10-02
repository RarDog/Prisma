import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' hide appBuildNumber;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:gel_rule_app/app/app_strings.dart';
import 'package:gel_rule_app/app/app_version.dart';
import 'package:gel_rule_app/app/changelog.dart';
import 'package:gel_rule_app/backend/backend.dart';
import 'package:gel_rule_app/core/utils/result.dart';
import 'package:gel_rule_app/features/settings/presentation/settings_controller.dart';
import 'package:gel_rule_app/features/settings/presentation/widgets/app_update_dialog.dart';
import 'package:gel_rule_app/core/performance/performance_monitor.dart';
import 'package:gel_rule_app/features/settings/presentation/widgets/settings_shared_widgets.dart';

class AboutSettingsScreen extends ConsumerWidget {
  const AboutSettingsScreen({super.key});

  Future<void> _checkUpdates(BuildContext context, WidgetRef ref, bool isRu) async {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final selectedSource = await showModalBottomSheet<UpdateSource>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
            child: Container(
              decoration: BoxDecoration(
                color: isDark
                    ? theme.colorScheme.surface.withValues(alpha: 0.88)
                    : Colors.white.withValues(alpha: 0.94),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                border: Border(
                  top: BorderSide(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.18)
                        : Colors.white.withValues(alpha: 0.85),
                    width: 1.2,
                  ),
                ),
              ),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    20,
                    14,
                    20,
                    24 + MediaQuery.paddingOf(sheetContext).bottom,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Container(
                          width: 38,
                          height: 4.5,
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.35),
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      ),
                      Text(
                        isRu ? 'Источник обновлений' : 'Update Source',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        isRu
                            ? 'Выберите сервер для быстрой загрузки новой версии'
                            : 'Choose a server to download updates from',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),

                      // GitHub
                      Material(
                        color: isDark
                            ? theme.colorScheme.primaryContainer.withValues(alpha: 0.35)
                            : theme.colorScheme.primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(18),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(18),
                          onTap: () {
                            HapticFeedback.selectionClick();
                            Navigator.pop(sheetContext, UpdateSource.github);
                          },
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: isDark
                                    ? Colors.white.withValues(alpha: 0.15)
                                    : theme.colorScheme.primary.withValues(alpha: 0.35),
                                width: 1.2,
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [Color(0xFF6366F1), Color(0xFF4F46E5)],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    borderRadius: BorderRadius.circular(13),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFF6366F1).withValues(alpha: 0.40),
                                        blurRadius: 10,
                                        offset: const Offset(0, 3),
                                      ),
                                    ],
                                  ),
                                  child: const Center(
                                    child: Icon(
                                      Icons.bolt_rounded,
                                      color: Colors.white,
                                      size: 24,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Text(
                                            'GitHub',
                                            style: theme.textTheme.titleSmall?.copyWith(
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 7,
                                              vertical: 2.5,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.green.withValues(alpha: 0.20),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              isRu ? 'Рекомендуется' : 'Recommended',
                                              style: const TextStyle(
                                                fontSize: 10.5,
                                                fontWeight: FontWeight.w700,
                                                color: Colors.green,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        isRu
                                            ? 'Прямая быстрая загрузка релизов без задержек'
                                            : 'Direct fast download without limits',
                                        style: theme.textTheme.bodySmall?.copyWith(
                                          color: theme.colorScheme.onSurfaceVariant,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Icon(
                                  Icons.arrow_forward_ios_rounded,
                                  size: 15,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Gitea
                      Material(
                        color: isDark
                            ? theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35)
                            : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.40),
                        borderRadius: BorderRadius.circular(18),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(18),
                          onTap: () {
                            HapticFeedback.selectionClick();
                            Navigator.pop(sheetContext, UpdateSource.gitea);
                          },
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: isDark
                                    ? Colors.white.withValues(alpha: 0.12)
                                    : theme.colorScheme.outlineVariant.withValues(alpha: 0.35),
                                width: 1.2,
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [Color(0xFF0EA5E9), Color(0xFF0284C7)],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    borderRadius: BorderRadius.circular(13),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFF0EA5E9).withValues(alpha: 0.35),
                                        blurRadius: 10,
                                        offset: const Offset(0, 3),
                                      ),
                                    ],
                                  ),
                                  child: const Center(
                                    child: Icon(
                                      Icons.dns_rounded,
                                      color: Colors.white,
                                      size: 22,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Gitea (Synapse)',
                                        style: theme.textTheme.titleSmall?.copyWith(
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        isRu
                                            ? 'Альтернативный независимый сервер релизов'
                                            : 'Alternative independent release mirror',
                                        style: theme.textTheme.bodySmall?.copyWith(
                                          color: theme.colorScheme.onSurfaceVariant,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Icon(
                                  Icons.arrow_forward_ios_rounded,
                                  size: 15,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );

    if (selectedSource == null) return;
    if (!context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          selectedSource == UpdateSource.gitea
              ? (isRu ? 'Проверка обновлений на Gitea...' : 'Checking updates on Gitea...')
              : (isRu ? 'Проверка обновлений на GitHub...' : 'Checking updates on GitHub...'),
        ),
      ),
    );
    final result = await ref.read(updateServiceProvider).checkForUpdates(
          force: true,
          source: selectedSource,
        );
    if (!context.mounted) return;
    messenger.hideCurrentSnackBar();
    if (result is Error<AppUpdateInfo?>) {
      messenger.showSnackBar(SnackBar(content: Text(result.failure.message)));
      return;
    }
    final update = (result as Success<AppUpdateInfo?>).data;
    if (update == null) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            isRu ? 'У вас установлена последняя версия Prisma' : 'Prisma is up to date',
          ),
        ),
      );
      return;
    }
    await showAppUpdateDialog(
      context: context,
      ref: ref,
      info: update,
    );
    ref.invalidate(settingsControllerProvider);
  }

  Future<void> _showChangelog(BuildContext context, bool isRu) {
    return showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isRu ? 'История изменений Prisma' : 'Prisma changelog'),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final change in prismaChangelog) ...[
                  Text(
                    '${change.version} - ${change.localizedTitle(isRu)}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 6),
                  for (final bullet in change.localizedBullets(isRu))
                    Padding(
                      padding: const EdgeInsets.only(left: 8, bottom: 4),
                      child: Text('- $bullet'),
                    ),
                  const SizedBox(height: 12),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(isRu ? 'Закрыть' : 'Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _copyDiagnostics(BuildContext context, WidgetRef ref, bool isRu) async {
    final report =
        await ref.read(settingsControllerProvider.notifier).diagnosticsReport();
    await Clipboard.setData(ClipboardData(text: report));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          isRu ? 'Диагностика скопирована' : 'Diagnostics copied',
        ),
      ),
    );
  }

  Future<void> _copyLogs(BuildContext context, WidgetRef ref, bool isRu) async {
    final logs =
        await ref.read(settingsControllerProvider.notifier).diagnosticLogs();
    await Clipboard.setData(ClipboardData(text: logs));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(isRu ? 'Логи скопированы' : 'Diagnostic logs copied'),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final settings =
        ref.watch(settingsControllerProvider).value ?? AppSettings.defaults;
    final strings = AppStrings(settings.languageCode);
    final isRu = strings.ru;

    return Scaffold(
      appBar: AppBar(
        title: Text(strings.about),
        leading: Navigator.canPop(context)
            ? IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: () => Navigator.pop(context),
              )
            : null,
      ),
      body: Center(
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
              // Hero Brand Card
              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(24),
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
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(22),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFE84D8A).withValues(alpha: 0.35),
                            blurRadius: 20,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(22),
                        child: Image.asset(
                          'assets/icon/app_icon.png',
                          width: 72,
                          height: 72,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFFE84D8A), Color(0xFF8B5CF6)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(22),
                            ),
                            child: const Icon(
                              Icons.palette_rounded,
                              color: Colors.white,
                              size: 40,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Prisma',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4.5),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.secondaryContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'v$appDisplayVersion (build $appBuildNumber)',
                        style: theme.textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.onSecondaryContainer,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      isRu
                          ? 'Быстрый и красивый Booru & Anime клиент'
                          : 'Modern, fast & customizable booru client',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Updates & Releases
              SettingsCardGroup(
                title: isRu ? 'Обновления и релизы' : 'Updates & Releases',
                icon: Icons.system_update_alt_rounded,
                accentColor: const Color(0xFFE84D8A),
                children: [
                  SettingsTile(
                    title: isRu ? 'Проверить обновления' : 'Check for updates',
                    subtitle: isRu
                        ? 'Поиск новых версий на GitHub или Gitea'
                        : 'Check releases on GitHub or Gitea mirror',
                    icon: Icons.download_rounded,
                    iconColor: const Color(0xFF6366F1),
                    onTap: () => _checkUpdates(context, ref, isRu),
                  ),
                  const SettingsDivider(),
                  SettingsTile(
                    title: isRu ? 'Что нового' : 'Changelog',
                    subtitle: isRu
                        ? 'История версий и список изменений'
                        : 'Recent features and improvements',
                    icon: Icons.new_releases_rounded,
                    iconColor: const Color(0xFFE84D8A),
                    onTap: () => _showChangelog(context, isRu),
                  ),
                  const SettingsDivider(),
                  SettingsTile(
                    title: 'GitHub Repository',
                    subtitle: isRu
                        ? 'Исходный код, багрепорты и участие в проекте'
                        : 'Source code, bug reports & contributions',
                    icon: Icons.code_rounded,
                    iconColor: const Color(0xFF374151),
                    onTap: () async {
                      final url = Uri.parse('https://github.com/RarDog/Prisma');
                      await launchUrl(url, mode: LaunchMode.externalApplication);
                    },
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // Diagnostics & System
              SettingsCardGroup(
                title: isRu ? 'Диагностика и система' : 'System & Diagnostics',
                icon: Icons.hub_rounded,
                accentColor: const Color(0xFF3B82F6),
                children: [
                  Padding(
                    padding: const EdgeInsets.all(14),
                    child: ActionGrid(
                      children: [
                        ActionButton(
                          icon: Icons.hub_rounded,
                          label: isRu ? 'Провайдеры' : 'Providers',
                          isPrimary: true,
                          onPressed: () => context.go('/providers'),
                        ),
                        ActionButton(
                          icon: Icons.network_check_rounded,
                          label: isRu ? 'Диагностика сети' : 'Diagnostics',
                          isPrimary: true,
                          onPressed: () => context.go('/providers/check'),
                        ),
                        ActionButton(
                          icon: Icons.bug_report_rounded,
                          label: isRu ? 'Копировать отчет' : 'Copy report',
                          onPressed: () => _copyDiagnostics(context, ref, isRu),
                        ),
                        ActionButton(
                          icon: Icons.receipt_long_rounded,
                          label: isRu ? 'Копировать логи' : 'Copy logs',
                          onPressed: () => _copyLogs(context, ref, isRu),
                        ),
                        ActionButton(
                          icon: Icons.delete_sweep_rounded,
                          label: isRu ? 'Очистить логи' : 'Clear logs',
                          onPressed: () {
                            ref
                                .read(settingsControllerProvider.notifier)
                                .clearDiagnosticLogs();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  isRu ? 'Логи очищены' : 'Logs cleared',
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // Performance & Debug Monitor
              _PerformanceDebugSection(isRu: isRu),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

class _PerformanceDebugSection extends ConsumerWidget {
  const _PerformanceDebugSection({required this.isRu});
  final bool isRu;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final settingsAsync = ref.watch(settingsControllerProvider);
    final settings = settingsAsync.value ?? AppSettings.defaults;
    final metricsAsync = ref.watch(performanceMetricsStreamProvider);
    final metrics = metricsAsync.value ?? const PerformanceMetrics();

    return SettingsCardGroup(
      title: isRu ? 'Мониторинг ресурсов и Debug' : 'Resource Monitor & Debug',
      icon: Icons.speed_rounded,
      accentColor: const Color(0xFF10B981),
      children: [
        // Live statistics block
        Padding(
          padding: const EdgeInsets.all(14),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.25),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      isRu ? 'Текущее состояние процесса' : 'Live Process Stats',
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: Color(0xFF10B981),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'LIVE',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: const Color(0xFF10B981),
                              fontWeight: FontWeight.w900,
                              fontSize: 9,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _StatItem(
                  icon: Icons.memory_rounded,
                  label: isRu ? 'Память (RAM RSS)' : 'Memory (RAM RSS)',
                  value: PerformanceMetrics.formatBytes(metrics.rssBytes),
                  subValue: isRu
                      ? 'пик: ${PerformanceMetrics.formatBytes(metrics.maxRssBytes)}'
                      : 'peak: ${PerformanceMetrics.formatBytes(metrics.maxRssBytes)}',
                  color: const Color(0xFF8B5CF6),
                ),
                const SizedBox(height: 8),
                _StatItem(
                  icon: Icons.image_rounded,
                  label: isRu ? 'Кэш картинок в ОЗУ' : 'Image RAM Cache',
                  value: PerformanceMetrics.formatBytes(metrics.imageCacheBytes),
                  subValue: isRu
                      ? '${metrics.imageCacheCount} объектов'
                      : '${metrics.imageCacheCount} items',
                  color: const Color(0xFFEC4899),
                ),
                const SizedBox(height: 8),
                _StatItem(
                  icon: Icons.speed_rounded,
                  label: isRu ? 'Загрузка ЦП процессом' : 'Process CPU',
                  value: '${metrics.cpuPercent.toStringAsFixed(1)} %',
                  subValue: isRu ? 'все ядра' : 'all cores',
                  color: const Color(0xFF3B82F6),
                ),
                const SizedBox(height: 8),
                _StatItem(
                  icon: Icons.wifi_rounded,
                  label: isRu ? 'Сеть (скачивание)' : 'Network (Download)',
                  value: PerformanceMetrics.formatSpeed(metrics.downloadSpeedBytesPerSec),
                  subValue: isRu
                      ? 'всего: ${PerformanceMetrics.formatBytes(metrics.totalDownloadedBytes)}'
                      : 'total: ${PerformanceMetrics.formatBytes(metrics.totalDownloadedBytes)}',
                  color: const Color(0xFF10B981),
                ),
                const SizedBox(height: 8),
                _StatItem(
                  icon: Icons.monitor_heart_rounded,
                  label: isRu ? 'Частота кадров' : 'Frame Rate',
                  value: '${metrics.fps} FPS',
                  subValue: metrics.fps >= 58
                      ? (isRu ? 'плавно' : 'smooth')
                      : (isRu ? 'нагрузка' : 'heavy'),
                  color: const Color(0xFFF59E0B),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () {
                    PaintingBinding.instance.imageCache.clear();
                    PaintingBinding.instance.imageCache.clearLiveImages();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          isRu
                              ? 'Кэш изображений в оперативной памяти очищен'
                              : 'Image cache cleared from RAM',
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.cleaning_services_rounded, size: 16),
                  label: Text(isRu ? 'Очистить кэш картинок в ОЗУ' : 'Clear RAM image cache'),
                ),
              ],
            ),
          ),
        ),

        const SettingsDivider(),

        // Toggle HUD
        SettingsSwitchTile(
          title: isRu ? 'Плавающее окно поверх экрана (HUD)' : 'Floating On-Screen HUD',
          subtitle: isRu
              ? 'Отображает полупрозрачное окно с метриками поверх всех экранов'
              : 'Shows a semi-transparent floating widget with live metrics across all screens',
          icon: Icons.picture_in_picture_alt_rounded,
          iconColor: const Color(0xFF10B981),
          value: settings.debugHudEnabled,
          onChanged: (val) {
            ref.read(settingsControllerProvider.notifier).updateDebugHudSettings(enabled: val);
          },
        ),

        if (settings.debugHudEnabled) ...[
          const SettingsDivider(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  isRu ? 'Отображаемые показатели в окне:' : 'Display metrics in HUD:',
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilterChip(
                      label: const Text('RAM (ОЗУ)'),
                      selected: settings.debugHudShowRam,
                      onSelected: (val) => ref
                          .read(settingsControllerProvider.notifier)
                          .updateDebugHudSettings(showRam: val),
                    ),
                    FilterChip(
                      label: const Text('CPU (ЦП)'),
                      selected: settings.debugHudShowCpu,
                      onSelected: (val) => ref
                          .read(settingsControllerProvider.notifier)
                          .updateDebugHudSettings(showCpu: val),
                    ),
                    FilterChip(
                      label: const Text('Network (Сеть)'),
                      selected: settings.debugHudShowNetwork,
                      onSelected: (val) => ref
                          .read(settingsControllerProvider.notifier)
                          .updateDebugHudSettings(showNetwork: val),
                    ),
                    FilterChip(
                      label: const Text('FPS (Кадры)'),
                      selected: settings.debugHudShowFps,
                      onSelected: (val) => ref
                          .read(settingsControllerProvider.notifier)
                          .updateDebugHudSettings(showFps: val),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      isRu ? 'Непрозрачность окна:' : 'HUD Opacity:',
                      style: theme.textTheme.bodySmall,
                    ),
                    Text(
                      '${(settings.debugHudOpacity * 100).toInt()}%',
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                Slider(
                  value: settings.debugHudOpacity.clamp(0.2, 1.0),
                  min: 0.2,
                  max: 1.0,
                  divisions: 8,
                  onChanged: (val) => ref
                      .read(settingsControllerProvider.notifier)
                      .updateDebugHudSettings(opacity: val),
                ),
                TextButton.icon(
                  onPressed: () {
                    ref.read(settingsControllerProvider.notifier).updateDebugHudSettings(
                          x: 16.0,
                          y: 90.0,
                        );
                  },
                  icon: const Icon(Icons.refresh_rounded, size: 16),
                  label: Text(
                    isRu ? 'Сбросить позицию окна' : 'Reset window position',
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _StatItem extends StatelessWidget {
  const _StatItem({
    required this.icon,
    required this.label,
    required this.value,
    required this.subValue,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final String subValue;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 14, color: color),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontSize: 11,
                ),
              ),
              Text(
                value,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ),
        Text(
          subValue,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
            fontSize: 11,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}
