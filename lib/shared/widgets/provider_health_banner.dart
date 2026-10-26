import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:prisma_app/app/app.dart';
import 'package:prisma_app/features/providers/presentation/providers_controller.dart';
import 'package:prisma_app/features/settings/domain/settings_service.dart';

/// A thin notice shown above the feed and the Artists tab when at least one
/// enabled source is known to be down.
///
/// Automatically hides after [autoDismissDuration] (default 4 seconds)
/// or when manually dismissed by the user. Can be turned off in settings.
class ProviderHealthBanner extends ConsumerStatefulWidget {
  const ProviderHealthBanner({
    super.key,
    this.autoDismiss = true,
    this.autoDismissDuration = const Duration(seconds: 4),
  });

  final bool autoDismiss;
  final Duration autoDismissDuration;

  @override
  ConsumerState<ProviderHealthBanner> createState() =>
      _ProviderHealthBannerState();
}

class _ProviderHealthBannerState extends ConsumerState<ProviderHealthBanner> {
  Timer? _dismissTimer;
  bool _dismissed = false;

  @override
  void dispose() {
    _dismissTimer?.cancel();
    super.dispose();
  }

  void _scheduleDismissIfNeeded() {
    if (widget.autoDismiss && !_dismissed && _dismissTimer == null) {
      _dismissTimer = Timer(widget.autoDismissDuration, () {
        if (mounted) {
          setState(() {
            _dismissed = true;
          });
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_dismissed) return const SizedBox.shrink();

    final settings =
        ref.watch(appSettingsProvider).value ?? AppSettings.defaults;
    if (!settings.showProviderHealthBanner) {
      return const SizedBox.shrink();
    }

    final strings = ref.watch(appStringsProvider);
    final offline = ref.watch(enabledProviderHealthProvider).maybeWhen(
          data: (entries) =>
              entries.where((entry) => !entry.health.isOnline).toList(),
          orElse: () => const <ProviderHealthEntry>[],
        );
    if (offline.isEmpty) return const SizedBox.shrink();

    _scheduleDismissIfNeeded();

    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final names = offline.map((entry) => entry.config.name).join(', ');

    return AnimatedSize(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
        child: Material(
          color: scheme.errorContainer.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                Icon(Icons.cloud_off_rounded,
                    size: 20, color: scheme.onErrorContainer),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        offline.length == 1
                            ? strings.sourcesUnavailableSingle
                            : strings.sourcesUnavailableCount(offline.length),
                        style: textTheme.labelLarge?.copyWith(
                          color: scheme.onErrorContainer,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        names,
                        style: textTheme.bodySmall
                            ?.copyWith(color: scheme.onErrorContainer),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () => context.push('/providers/check'),
                  child: Text(strings.checkSources),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 18),
                  tooltip: strings.ru ? 'Скрыть' : 'Dismiss',
                  color: scheme.onErrorContainer,
                  onPressed: () {
                    _dismissTimer?.cancel();
                    setState(() {
                      _dismissed = true;
                    });
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
