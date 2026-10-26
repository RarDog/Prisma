import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:prisma_app/app/app.dart';
import 'package:prisma_app/backend/backend.dart';
import 'package:prisma_app/features/onboarding/presentation/steps/onboarding_api_keys_step.dart';
import 'package:prisma_app/features/onboarding/presentation/steps/onboarding_appearance_step.dart';
import 'package:prisma_app/features/onboarding/presentation/steps/onboarding_completion_step.dart';
import 'package:prisma_app/features/onboarding/presentation/steps/onboarding_language_step.dart';
import 'package:prisma_app/features/onboarding/presentation/steps/onboarding_sources_step.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  int _configuredProvidersCount = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _nextPage() {
    HapticFeedback.selectionClick();
    if (_currentPage < 4) {
      _pageController.animateToPage(
        _currentPage + 1,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  void _prevPage() {
    HapticFeedback.selectionClick();
    if (_currentPage > 0) {
      _pageController.animateToPage(
        _currentPage - 1,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  Future<void> _finishOnboarding() async {
    unawaited(HapticFeedback.mediumImpact());
    await ref.read(onboardingServiceProvider).markCompleted();
    if (mounted) {
      context.go('/');
    }
  }

  String _getStepTitle(int step, bool isRu) {
    switch (step) {
      case 0:
        return isRu ? 'ШАГ 1 ИЗ 5 • ЯЗЫК' : 'STEP 1 OF 5 • LANGUAGE';
      case 1:
        return isRu ? 'ШАГ 2 ИЗ 5 • ОФОРМЛЕНИЕ' : 'STEP 2 OF 5 • THEME';
      case 2:
        return isRu ? 'ШАГ 3 ИЗ 5 • ИСТОЧНИКИ' : 'STEP 3 OF 5 • SOURCES';
      case 3:
        return isRu ? 'ШАГ 4 ИЗ 5 • АККАУНТЫ' : 'STEP 4 OF 5 • ACCOUNTS';
      case 4:
        return isRu ? 'ШАГ 5 ИЗ 5 • ЗАВЕРШЕНИЕ' : 'STEP 5 OF 5 • ALL SET';
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final settings =
        ref.watch(appSettingsProvider).value ?? AppSettings.defaults;
    final isRu = settings.languageCode == 'ru';

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            // Top Bar with progress indicator
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Row(
                children: [
                  SizedBox(
                    width: 40,
                    child: _currentPage > 0
                        ? IconButton(
                            padding: EdgeInsets.zero,
                            icon: const Icon(Icons.arrow_back_rounded),
                            tooltip: isRu ? 'Назад' : 'Back',
                            onPressed: _prevPage,
                          )
                        : null,
                  ),
                  const Spacer(),
                  // Step Dots with passed check styling
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(5, (index) {
                      final isActive = index == _currentPage;
                      final isPassed = index < _currentPage;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeOutCubic,
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: isActive ? 28 : (isPassed ? 14 : 8),
                        height: 8,
                        decoration: BoxDecoration(
                          color: isActive
                              ? theme.colorScheme.primary
                              : (isPassed
                                  ? const Color(0xFF10B981)
                                  : theme.colorScheme.outlineVariant
                                      .withValues(alpha: 0.4)),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      );
                    }),
                  ),
                  const Spacer(),
                  Container(
                    width: 76,
                    alignment: Alignment.centerRight,
                    child: _currentPage < 4
                        ? TextButton(
                            style: TextButton.styleFrom(
                              padding: EdgeInsets.zero,
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            onPressed: () {
                              HapticFeedback.selectionClick();
                              _finishOnboarding();
                            },
                            child: Text(
                              isRu ? 'Пропустить' : 'Skip',
                              style: TextStyle(
                                  color: theme.colorScheme.onSurfaceVariant),
                            ),
                          )
                        : null,
                  ),
                ],
              ),
            ),

            // Step Indicator Badge
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: Text(
                  _getStepTitle(_currentPage, isRu),
                  key: ValueKey<int>(_currentPage),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant
                        .withValues(alpha: 0.75),
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
            ),

            // Page Content
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (page) => setState(() => _currentPage = page),
                children: [
                  OnboardingLanguageStep(
                    onNext: _nextPage,
                  ),
                  OnboardingAppearanceStep(
                    onNext: _nextPage,
                  ),
                  OnboardingSourcesStep(
                    onNext: _nextPage,
                  ),
                  OnboardingApiKeysStep(
                    onNext: (count) {
                      setState(() => _configuredProvidersCount = count);
                      _nextPage();
                    },
                    onSkip: _nextPage,
                  ),
                  OnboardingCompletionStep(
                    configuredProvidersCount: _configuredProvidersCount,
                    onFinish: _finishOnboarding,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
