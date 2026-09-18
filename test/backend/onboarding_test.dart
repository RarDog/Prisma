import 'package:flutter_test/flutter_test.dart';
import 'package:gel_rule_app/features/providers/models/content_provider_config.dart';
import 'package:gel_rule_app/features/providers/data/provider_repository.dart';
import 'package:gel_rule_app/features/settings/domain/backup_service.dart';
import 'package:gel_rule_app/features/onboarding/domain/onboarding_service.dart';
import 'package:gel_rule_app/features/settings/domain/settings_service.dart';
import 'package:gel_rule_app/core/utils/result.dart';

class _FakeSettingsService extends Fake implements SettingsService {
  AppSettings current = AppSettings.defaults;

  @override
  Future<Result<AppSettings>> getSettings() async => Success(current);

  @override
  Future<Result<void>> updateSettings(AppSettings settings) async {
    current = settings;
    return const Success(null);
  }
}

class _FakeBackupService extends Fake implements BackupService {
  bool backupExists = false;
  bool scheduledBackup = false;

  @override
  Future<bool> hasPersistentBackup() async => backupExists;

  @override
  void scheduleAutoBackup({Duration delay = const Duration(seconds: 2)}) {
    scheduledBackup = true;
  }
}

class _FakeProviderRepository extends Fake implements ProviderRepository {
  List<ContentProviderConfig> providers = [];

  @override
  Future<Result<List<ContentProviderConfig>>> getProviders({
    bool enabledOnly = false,
  }) async {
    return Success(providers);
  }
}

void main() {
  group('OnboardingService Tests', () {
    late _FakeSettingsService fakeSettings;
    late _FakeBackupService fakeBackup;
    late _FakeProviderRepository fakeRepo;
    late OnboardingService onboardingService;

    setUp(() {
      fakeSettings = _FakeSettingsService();
      fakeBackup = _FakeBackupService();
      fakeRepo = _FakeProviderRepository();
      onboardingService = OnboardingService(
        settingsService: fakeSettings,
        backupService: fakeBackup,
        providerRepository: fakeRepo,
      );
    });

    test('Brand new user without backup or API keys should see onboarding', () async {
      fakeSettings.current = AppSettings.defaults.copyWith(
        hasCompletedOnboarding: false,
      );
      fakeBackup.backupExists = false;
      fakeRepo.providers = [
        ContentProviderConfig(
          id: 'gelbooru',
          name: 'Gelbooru',
          baseUrl: 'https://gelbooru.com',
          apiType: 'gelbooru',
          enabled: true,
          priority: 0,
          timeoutSeconds: 20,
          customHeaders: const {},
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      ];

      final shouldShow = await onboardingService.shouldShowOnboarding();
      expect(shouldShow, isTrue);
    });

    test('User who already completed onboarding should NOT see onboarding', () async {
      fakeSettings.current = AppSettings.defaults.copyWith(
        hasCompletedOnboarding: true,
      );
      fakeBackup.backupExists = false;

      final shouldShow = await onboardingService.shouldShowOnboarding();
      expect(shouldShow, isFalse);
    });

    test('User with existing backup file should NOT see onboarding and auto-complete', () async {
      fakeSettings.current = AppSettings.defaults.copyWith(
        hasCompletedOnboarding: false,
      );
      fakeBackup.backupExists = true;

      final shouldShow = await onboardingService.shouldShowOnboarding();
      expect(shouldShow, isFalse);
      expect(fakeSettings.current.hasCompletedOnboarding, isTrue);
    });

    test('User with at least one API key configured should NOT see onboarding and auto-complete', () async {
      fakeSettings.current = AppSettings.defaults.copyWith(
        hasCompletedOnboarding: false,
      );
      fakeBackup.backupExists = false;
      fakeRepo.providers = [
        ContentProviderConfig(
          id: 'e621',
          name: 'e621',
          baseUrl: 'https://e621.net',
          apiType: 'e621',
          enabled: true,
          priority: 0,
          timeoutSeconds: 20,
          customHeaders: const {
            'query.api_key': 'secret_api_key_123',
            'query.login': 'artist_fan',
          },
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      ];

      final shouldShow = await onboardingService.shouldShowOnboarding();
      expect(shouldShow, isFalse);
      expect(fakeSettings.current.hasCompletedOnboarding, isTrue);
    });

    test('hasAnyProviderApiKey recognizes query.api_key, api_key, and Authorization', () {
      final p1 = ContentProviderConfig(
        id: '1',
        name: 'P1',
        baseUrl: '',
        apiType: '',
        enabled: true,
        priority: 0,
        timeoutSeconds: 20,
        customHeaders: {'api_key': 'key123'},
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      expect(OnboardingService.hasAnyProviderApiKey([p1]), isTrue);

      final p2 = ContentProviderConfig(
        id: '2',
        name: 'P2',
        baseUrl: '',
        apiType: '',
        enabled: true,
        priority: 0,
        timeoutSeconds: 20,
        customHeaders: {'Authorization': 'Basic dXNlcjpwYXNz'},
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      expect(OnboardingService.hasAnyProviderApiKey([p2]), isTrue);

      final p3 = ContentProviderConfig(
        id: '3',
        name: 'P3',
        baseUrl: '',
        apiType: '',
        enabled: true,
        priority: 0,
        timeoutSeconds: 20,
        customHeaders: {'User-Agent': 'SomeAgent'},
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      expect(OnboardingService.hasAnyProviderApiKey([p3]), isFalse);
    });

    test('markCompleted updates settings and schedules backup', () async {
      fakeSettings.current = AppSettings.defaults.copyWith(
        hasCompletedOnboarding: false,
      );

      await onboardingService.markCompleted();
      expect(fakeSettings.current.hasCompletedOnboarding, isTrue);
      expect(fakeBackup.scheduledBackup, isTrue);
    });
  });
}
