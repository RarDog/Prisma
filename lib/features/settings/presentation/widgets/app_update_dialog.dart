import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gel_rule_app/app/app.dart';
import 'package:gel_rule_app/backend/di/backend_providers.dart';
import 'package:gel_rule_app/features/settings/models/app_update_info.dart';

Future<void> showAppUpdateDialog({
  required BuildContext context,
  required WidgetRef ref,
  required AppUpdateInfo info,
}) async {
  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (context) => AppUpdateDialog(info: info),
  );
  ref.invalidate(appSettingsProvider);
}

class AppUpdateDialog extends ConsumerStatefulWidget {
  const AppUpdateDialog({required this.info, super.key});

  final AppUpdateInfo info;

  @override
  ConsumerState<AppUpdateDialog> createState() => _AppUpdateDialogState();
}

class _AppUpdateDialogState extends ConsumerState<AppUpdateDialog> {
  bool _isDownloading = false;
  double _progress = 0.0;
  String? _statusText;
  String? _error;
  CancelToken? _cancelToken;

  String get _platformTarget {
    if (Platform.isAndroid) return 'Android APK';
    if (Platform.isLinux) {
      final isAppImage = Platform.environment.containsKey('APPIMAGE');
      return isAppImage ? 'Linux AppImage' : 'Linux';
    }
    if (Platform.isWindows) return 'Windows (x64)';
    if (Platform.isMacOS) return 'macOS';
    return 'Portable Zip';
  }

  Future<void> _startUpdate() async {
    setState(() {
      _isDownloading = true;
      _progress = 0.0;
      _error = null;
      _statusText = 'Подготовка к загрузке...';
      _cancelToken = CancelToken();
    });

    final updateService = ref.read(updateServiceProvider);
    try {
      await updateService.downloadAndApplyUpdate(
        info: widget.info,
        cancelToken: _cancelToken,
        onProgress: (progress, status) {
          if (mounted) {
            setState(() {
              _progress = progress;
              _statusText = status;
            });
          }
        },
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _isDownloading = false;
          _error = e.toString().contains('cancel')
              ? null
              : 'Ошибка обновления: $e';
          _statusText = null;
        });
      }
    }
  }

  void _cancelUpdate() {
    _cancelToken?.cancel('Отменено пользователем');
    setState(() {
      _isDownloading = false;
      _statusText = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final strings = ref.watch(appStringsProvider);
    final isRu = strings.ru;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      backgroundColor: scheme.surface,
      surfaceTintColor: scheme.primary,
      elevation: 6,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 680),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: scheme.primary.withValues(alpha: 0.2),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Image.asset(
                      'assets/icon/app_icon_rounded.png',
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Icon(
                        Icons.system_update_rounded,
                        size: 32,
                        color: scheme.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'Prisma',
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.2,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: scheme.primaryContainer,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'v${widget.info.version}',
                                style: theme.textTheme.labelMedium?.copyWith(
                                  color: scheme.onPrimaryContainer,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          isRu
                              ? 'Доступна новая версия'
                              : 'A new version is available',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // Platform badge
              Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHighest.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: scheme.outlineVariant.withValues(alpha: 0.5),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Platform.isAndroid
                            ? Icons.android_rounded
                            : (Platform.isLinux
                                ? Icons.terminal_rounded
                                : (Platform.isWindows
                                    ? Icons.window_rounded
                                    : Icons.laptop_mac_rounded)),
                        size: 15,
                        color: scheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _platformTarget,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Release notes / Changelog container
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHighest.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: scheme.outlineVariant.withValues(alpha: 0.4),
                    ),
                  ),
                  padding: const EdgeInsets.all(14),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (widget.info.name.isNotEmpty &&
                            widget.info.name != widget.info.tagName) ...[
                          Text(
                            widget.info.name,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: scheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 8),
                        ],
                        Text(
                          widget.info.body.trim().isNotEmpty
                              ? widget.info.body.trim()
                              : (isRu
                                  ? 'Улучшения стабильности и исправления ошибок.'
                                  : 'Bug fixes and performance improvements.'),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: scheme.onSurfaceVariant,
                            height: 1.45,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Progress or Error status
              if (_isDownloading) ...[
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    LinearProgressIndicator(
                      value: _progress >= 0 ? _progress : null,
                      borderRadius: BorderRadius.circular(4),
                      backgroundColor: scheme.surfaceContainerHighest,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _statusText ?? '',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        if (_progress > 0)
                          Text(
                            '${(_progress * 100).toInt()}%',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: scheme.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              ] else if (_error != null) ...[
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: scheme.errorContainer.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    _error!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onErrorContainer,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Actions
              if (_isDownloading)
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton(
                      onPressed: _cancelUpdate,
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(isRu ? 'Отмена' : 'Cancel'),
                    ),
                  ],
                )
              else
                Row(
                  children: [
                    TextButton(
                      onPressed: () async {
                        await ref
                            .read(updateServiceProvider)
                            .skipVersion(widget.info);
                        if (context.mounted) Navigator.pop(context);
                      },
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                      ),
                      child: Text(
                        strings.skipThisVersion,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.outline,
                        ),
                      ),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () async {
                        await ref.read(updateServiceProvider).remindLater();
                        if (context.mounted) Navigator.pop(context);
                      },
                      child: Text(strings.later),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.icon(
                      onPressed: _startUpdate,
                      style: FilledButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                      icon: const Icon(Icons.auto_awesome_rounded, size: 18),
                      label: Text(
                        Platform.isAndroid
                            ? (isRu ? 'Скачать и установить' : 'Download & Install')
                            : (isRu
                                ? 'Обновить и перезапустить'
                                : 'Update & Restart'),
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
