import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:gel_rule_app/app/app.dart';
import 'package:gel_rule_app/backend/backend.dart';
import 'package:gel_rule_app/features/onboarding/presentation/widgets/onboarding_shared_widgets.dart';
import 'package:gel_rule_app/features/providers/presentation/providers_controller.dart';

class OnboardingCompletionStep extends ConsumerStatefulWidget {
  const OnboardingCompletionStep({
    super.key,
    required this.configuredProvidersCount,
    required this.onFinish,
  });

  final int configuredProvidersCount;
  final VoidCallback onFinish;

  @override
  ConsumerState<OnboardingCompletionStep> createState() =>
      _OnboardingCompletionStepState();
}

class _OnboardingCompletionStepState
    extends ConsumerState<OnboardingCompletionStep>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  late final Animation<double> _floatAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);

    _floatAnim = Tween<double>(begin: -4.0, end: 4.0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: Curves.easeInOutSine,
      ),
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final settings =
        ref.watch(appSettingsProvider).value ?? AppSettings.defaults;
    final isRu = settings.languageCode == 'ru';

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 20),

          // Floating Animated Rocket Badge
          AnimatedBuilder(
            animation: _floatAnim,
            builder: (context, child) {
              return Transform.translate(
                offset: Offset(0, _floatAnim.value),
                child: child,
              );
            },
            child: const PulsingIconBadge(
              icon: Icons.rocket_launch_rounded,
              gradientColors: [Color(0xFF10B981), Color(0xFF059669)],
              size: 56,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            isRu ? 'Всё готово!' : 'All Set!',
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            isRu
                ? 'Вы можете начать своё путешествие по миру артов. Все настройки сохранены и защищены.'
                : 'You are ready to begin your journey. All settings are safely preserved.',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),

          // Summary Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest
                  .withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.45),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                SummaryRow(
                  icon: Icons.language_rounded,
                  label: isRu ? 'Язык приложения' : 'Language',
                  value: isRu ? 'Русский 🇷🇺' : 'English 🇬🇧',
                ),
                const Divider(height: 24),
                SummaryRow(
                  icon: Icons.palette_rounded,
                  label: isRu ? 'Тема оформления' : 'Theme',
                  value: settings.themeMode == 'dark'
                      ? (settings.amoledMode
                          ? (isRu ? 'Тёмная (AMOLED)' : 'Dark (AMOLED)')
                          : (isRu ? 'Тёмная' : 'Dark'))
                      : settings.themeMode == 'light'
                          ? (isRu ? 'Светлая' : 'Light')
                          : (isRu ? 'Системная' : 'System'),
                  valueColor: theme.colorScheme.primary,
                ),
                const Divider(height: 24),
                SummaryRow(
                  icon: Icons.shield_rounded,
                  label: isRu ? 'Фильтрация контента' : 'Content Filter',
                  value: settings.nsfwEnabled
                      ? (isRu ? '18+ Разрешён' : 'NSFW Allowed')
                      : (isRu ? 'Safe Mode (Безопасный)' : 'Safe Mode Only'),
                  valueColor: settings.nsfwEnabled
                      ? const Color(0xFFEF4444)
                      : const Color(0xFF10B981),
                ),
                const Divider(height: 24),
                SummaryRow(
                  icon: Icons.hub_rounded,
                  label: isRu ? 'Активные источники' : 'Active sources',
                  value:
                      '${(ref.watch(providersControllerProvider).value ?? []).where((p) => p.enabled && p.apiType != "fapello" && p.id != "fapello").length}',
                  valueColor: const Color(0xFF6366F1),
                ),
                const Divider(height: 24),
                SummaryRow(
                  icon: Icons.cloud_done_rounded,
                  label: isRu ? 'Персистентный автобэкап' : 'Persistent backup',
                  value: isRu ? 'Включен' : 'Active',
                  valueColor: const Color(0xFF10B981),
                ),
                if (widget.configuredProvidersCount > 0) ...[
                  const Divider(height: 24),
                  SummaryRow(
                    icon: Icons.vpn_key_rounded,
                    label: isRu ? 'Настроено ключей' : 'Keys configured',
                    value: '${widget.configuredProvidersCount}',
                    valueColor: theme.colorScheme.primary,
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 40),
          FilledButton.icon(
            onPressed: widget.onFinish,
            icon: const Icon(Icons.explore_rounded),
            label: Text(
              isRu ? 'Начать путешествие' : 'Start Journey',
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
            style: FilledButton.styleFrom(
              minimumSize: const Size(double.infinity, 58),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18)),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
