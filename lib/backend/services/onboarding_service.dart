import 'package:flutter/foundation.dart';

import '../../core/utils/result.dart';
import '../models/content_provider_config.dart';
import '../repositories/provider_repository.dart';
import 'backup_service.dart';
import 'settings_service.dart';

class OnboardingService {
  OnboardingService({
    required this.settingsService,
    required this.backupService,
    required this.providerRepository,
  });

  final SettingsService settingsService;
  final BackupService backupService;
  final ProviderRepository providerRepository;

  /// Checks if any provider has an API key or auth credentials configured.
  static bool hasAnyProviderApiKey(List<ContentProviderConfig> providers) {
    for (final p in providers) {
      final headers = p.customHeaders;
      final queryApiKey = headers['query.api_key']?.trim() ?? '';
      final apiKey = headers['api_key']?.trim() ?? '';
      final auth = headers['Authorization']?.trim() ?? '';
      if (queryApiKey.isNotEmpty || apiKey.isNotEmpty || auth.isNotEmpty) {
        return true;
      }
    }
    return false;
  }

  /// Determines whether the first-run onboarding screen should be shown.
  ///
  /// The onboarding screen appears ONLY ONCE.
  /// It will NOT appear if:
  /// 1. The user has already completed onboarding (`hasCompletedOnboarding == true`).
  /// 2. A persistent backup file already exists on the device.
  /// 3. At least one provider already has an API key configured.
  Future<bool> shouldShowOnboarding() async {
    try {
      final settingsResult = await settingsService.getSettings();
      final settings = settingsResult is Success<AppSettings>
          ? settingsResult.data
          : AppSettings.defaults;

      if (settings.hasCompletedOnboarding) {
        return false;
      }

      // Check if persistent backup file exists on device
      final hasBackup = await backupService.hasPersistentBackup();
      if (hasBackup) {
        debugPrint('Onboarding: skipped because persistent backup exists.');
        await markCompleted();
        return false;
      }

      // Check if any provider has an API key configured
      final providersResult = await providerRepository.getProviders();
      if (providersResult is Success<List<ContentProviderConfig>>) {
        if (hasAnyProviderApiKey(providersResult.data)) {
          debugPrint('Onboarding: skipped because API key already configured.');
          await markCompleted();
          return false;
        }
      }

      // Brand new user with no backup and no API keys
      return true;
    } catch (e) {
      debugPrint('shouldShowOnboarding error: $e');
      return false;
    }
  }

  /// Marks onboarding as completed and triggers a persistent backup.
  Future<void> markCompleted() async {
    try {
      final settingsResult = await settingsService.getSettings();
      final settings = settingsResult is Success<AppSettings>
          ? settingsResult.data
          : AppSettings.defaults;

      if (!settings.hasCompletedOnboarding) {
        await settingsService.updateSettings(
          settings.copyWith(hasCompletedOnboarding: true),
        );
        backupService.scheduleAutoBackup();
      }
    } catch (e) {
      debugPrint('markCompleted error: $e');
    }
  }

  /// Resets onboarding flag (e.g. for replaying setup from Settings).
  Future<void> resetOnboarding() async {
    final settingsResult = await settingsService.getSettings();
    final settings = settingsResult is Success<AppSettings>
        ? settingsResult.data
        : AppSettings.defaults;

    await settingsService.updateSettings(
      settings.copyWith(hasCompletedOnboarding: false),
    );
  }
}
