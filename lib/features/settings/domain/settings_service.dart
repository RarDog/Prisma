import 'dart:convert';

import 'package:isar/isar.dart';

import 'package:gel_rule_app/core/database/app_database.dart';
import 'package:gel_rule_app/core/database/database_service.dart';
import 'package:gel_rule_app/core/errors/failure.dart';
import 'package:gel_rule_app/core/utils/result.dart';
import 'package:gel_rule_app/features/providers/models/content_provider_config.dart';
import 'package:gel_rule_app/core/models/provider_diagnostics.dart';
import 'package:gel_rule_app/features/providers/data/provider_repository.dart';

export 'package:gel_rule_app/features/settings/models/app_settings.dart';
import 'package:gel_rule_app/features/settings/models/app_settings.dart';


class SettingsService {
  SettingsService(
    this._databaseService, {
    ProviderRepository? providerRepository,
    this.onDataChanged,
  }) : _providerRepository = providerRepository;

  final DatabaseService _databaseService;
  final ProviderRepository? _providerRepository;
  final void Function()? onDataChanged;
  static const _settingsKey = 'app_settings';

  Future<Result<AppSettings>> getSettings() {
    return _databaseService.safeRead((isar) async {
      final entity = await isar.appSettingEntitys
          .filter()
          .keyEqualTo(_settingsKey)
          .findFirst();
      if (entity == null) return AppSettings.defaults;
      return AppSettings.fromJson(
          jsonDecode(entity.jsonValue) as Map<String, dynamic>);
    });
  }

  Future<Result<void>> updateSettings(AppSettings settings) async {
    final res = await _databaseService.safeWrite((isar) async {
      await isar.appSettingEntitys.put(
        AppSettingEntity()
          ..key = _settingsKey
          ..jsonValue = jsonEncode(settings.toJson())
          ..updatedAt = DateTime.now(),
      );
    });
    if (res is Success) onDataChanged?.call();
    return res;
  }

  Future<Result<void>> saveEnabledProviders(List<String> providerIds) async {
    final result = await getSettings();
    if (result is Error<AppSettings>) return Error(result.failure);
    final settings = (result as Success<AppSettings>).data;
    final updateResult = await updateSettings(
        settings.copyWith(enabledProviderIds: providerIds));
    if (updateResult is Error<void>) return updateResult;

    final repository = _providerRepository;
    if (repository == null) return updateResult;

    final providersResult = await repository.getProviders();
    if (providersResult is Error<List<ContentProviderConfig>>) {
      return Error(providersResult.failure);
    }
    final enabled = providerIds.toSet();
    for (final provider
        in (providersResult as Success<List<ContentProviderConfig>>).data) {
      await repository.saveProvider(
        provider.copyWith(
          enabled: enabled.contains(provider.id),
          updatedAt: DateTime.now(),
        ),
      );
    }
    return updateResult;
  }

  Future<Result<void>> saveLastActiveLocation(String location) async {
    final result = await getSettings();
    if (result is Error<AppSettings>) return Error(result.failure);
    final settings = (result as Success<AppSettings>).data;
    if (settings.lastActiveLocation == location) return const Success(null);
    return updateSettings(settings.copyWith(lastActiveLocation: location));
  }

  Future<Result<void>> saveMangaCatalogState({
    String? rating,
    double? scrollOffset,
    String? providerId,
  }) async {
    final result = await getSettings();
    if (result is Error<AppSettings>) return Error(result.failure);
    final settings = (result as Success<AppSettings>).data;
    final updated = settings.copyWith(
      mangaSelectedRating: rating ?? settings.mangaSelectedRating,
      mangaScrollOffset: scrollOffset ?? settings.mangaScrollOffset,
      mangaSelectedProviderId: providerId ?? settings.mangaSelectedProviderId,
    );
    return updateSettings(updated);
  }

  Future<Result<void>> saveMangaVolumeNavigation({
    required bool enabled,
    bool? invert,
  }) async {
    final result = await getSettings();
    if (result is Error<AppSettings>) return Error(result.failure);
    final settings = (result as Success<AppSettings>).data;
    final updated = settings.copyWith(
      mangaVolumeNavigation: enabled,
      mangaInvertVolumeKeys: invert ?? settings.mangaInvertVolumeKeys,
    );
    return updateSettings(updated);
  }

  Future<Result<void>> hidePostKey(String cacheKey) async {
    final result = await getSettings();
    if (result is Error<AppSettings>) return Error(result.failure);
    final settings = (result as Success<AppSettings>).data;
    final hidden = <String>{...settings.hiddenPostKeys, cacheKey}.toList()
      ..sort();
    return updateSettings(settings.copyWith(hiddenPostKeys: hidden));
  }

  Future<Result<void>> unhidePostKey(String cacheKey) async {
    final result = await getSettings();
    if (result is Error<AppSettings>) return Error(result.failure);
    final settings = (result as Success<AppSettings>).data;
    return updateSettings(
      settings.copyWith(
        hiddenPostKeys:
            settings.hiddenPostKeys.where((key) => key != cacheKey).toList(),
      ),
    );
  }

  Future<Result<void>> clearHiddenPosts() async {
    final result = await getSettings();
    if (result is Error<AppSettings>) return Error(result.failure);
    final settings = (result as Success<AppSettings>).data;
    return updateSettings(settings.copyWith(hiddenPostKeys: const []));
  }

  Future<Result<int>> importBlacklistFromE621(List<String> incomingTags) async {
    final result = await getSettings();
    if (result is Error<AppSettings>) return Error(result.failure);
    final settings = (result as Success<AppSettings>).data;

    final currentTags = settings.blacklistedTags.toSet();
    final currentRules = settings.smartBlacklistRules.toSet();
    int addedCount = 0;

    for (final raw in incomingTags) {
      final line = raw.trim();
      if (line.isEmpty) continue;

      if (line.contains(' ') ||
          line.startsWith('rating:') ||
          line.startsWith('score:')) {
        if (!currentRules.contains(line)) {
          currentRules.add(line);
          addedCount++;
        }
      } else {
        final cleanTag = line.toLowerCase();
        if (!currentTags.contains(cleanTag)) {
          currentTags.add(cleanTag);
          addedCount++;
        }
      }
    }

    if (addedCount == 0) return const Success(0);

    final updated = settings.copyWith(
      blacklistedTags: currentTags.toList(),
      smartBlacklistRules: currentRules.toList(),
    );
    final saveResult = await updateSettings(updated);
    if (saveResult is Error<void>) return Error(saveResult.failure);
    return Success(addedCount);
  }

  Future<Result<void>> saveVideoPlaybackPosition(
    String cacheKey,
    int milliseconds, {
    int maxEntries = 300,
  }) async {
    if (cacheKey.isEmpty || milliseconds < 1000) return const Success(null);
    final result = await getSettings();
    if (result is Error<AppSettings>) return Error(result.failure);
    final settings = (result as Success<AppSettings>).data;
    final existing = settings.videoPlaybackPositions[cacheKey] ?? 0;
    if ((existing - milliseconds).abs() < 1000) return const Success(null);
    final positions = <String, int>{
      ...settings.videoPlaybackPositions,
      cacheKey: milliseconds,
    };
    if (positions.length > maxEntries) {
      final removeCount = positions.length - maxEntries;
      for (final key in positions.keys.take(removeCount).toList()) {
        positions.remove(key);
      }
    }
    return updateSettings(settings.copyWith(videoPlaybackPositions: positions));
  }

  Future<Result<void>> setVideoPlayerVolume(double volume) async {
    final result = await getSettings();
    if (result is Error<AppSettings>) return Error(result.failure);
    final settings = (result as Success<AppSettings>).data;
    final clamped = volume.clamp(0.0, 100.0);
    if ((settings.videoPlayerVolume - clamped).abs() < 0.01) {
      return const Success(null);
    }
    return updateSettings(settings.copyWith(videoPlayerVolume: clamped));
  }


  Future<Result<void>> clearDiagnosticLogs() async {
    final result = await getSettings();
    if (result is Error<AppSettings>) return Error(result.failure);
    final settings = (result as Success<AppSettings>).data;
    return updateSettings(settings.copyWith(diagnosticLogLines: const []));
  }

  Future<Result<String>> buildDiagnosticsReport({
    required String appVersion,
    required int buildNumber,
  }) async {
    final settingsResult = await getSettings();
    if (settingsResult is Error<AppSettings>) {
      return Error(settingsResult.failure);
    }
    final settings = (settingsResult as Success<AppSettings>).data;
    final providers = <ContentProviderConfig>[];
    final diagnostics = <String>[];
    final repository = _providerRepository;
    if (repository != null) {
      final providersResult = await repository.getProviders(enabledOnly: false);
      if (providersResult is Success<List<ContentProviderConfig>>) {
        providers.addAll(providersResult.data);
      }
      final diagnosticsResult = await repository.getDiagnostics();
      if (diagnosticsResult is Success<List<ProviderDiagnostics>>) {
        for (final item in diagnosticsResult.data) {
          diagnostics.add(
            '${item.providerId}: ${item.lastResultCount} posts, '
            'lastSearchAt=${item.lastSearchAt}, '
            'error=${item.lastErrorMessage ?? 'none'}',
          );
        }
      }
    }
    final enabledProviders =
        providers.where((provider) => provider.enabled).map((p) => p.id);
    return Success(
      const JsonEncoder.withIndent('  ').convert({
        'app': {
          'name': 'Prisma',
          'version': appVersion,
          'build': buildNumber,
          'generatedAt': DateTime.now().toIso8601String(),
        },
        'settingsSummary': {
          'themeMode': settings.themeMode,
          'languageCode': settings.languageCode,
          'appSeedColor': settings.appSeedColor,
          'hiddenTabs': settings.hiddenTabs,
          'allowExperimentalUpdates': settings.allowExperimentalUpdates,
          'nsfwEnabled': settings.nsfwEnabled,
          'blurExplicitContent': settings.blurExplicitContent,
          'mediaQualityMode': settings.mediaQualityMode,
          'motionRefreshMode': settings.motionRefreshMode,
          'autoBatterySaver60Hz': settings.autoBatterySaver60Hz,
          'cacheMaxItems': settings.cacheMaxItems,
          'hiddenPosts': settings.hiddenPostKeys.length,
          'blacklistRules': settings.smartBlacklistRules.length,
          'whitelistTags': settings.whitelistedTags.length,
          'hideViewedPosts': settings.hideViewedPosts,
        },
        'providers': {
          'enabled': enabledProviders.toList(),
          'all': providers
              .map((provider) => {
                    'id': provider.id,
                    'name': provider.name,
                    'apiType': provider.apiType,
                    'enabled': provider.enabled,
                    'priority': provider.priority,
                    'baseUrl': provider.baseUrl,
                  })
              .toList(),
        },
        'recentLogs': settings.diagnosticLogLines.take(60).toList(),
        'providerDiagnostics': diagnostics,
      }),
    );
  }

  Future<Result<String>> exportSettingsToJson() async {
    final result = await getSettings();
    if (result is Error<AppSettings>) return Error(result.failure);
    final settings = (result as Success<AppSettings>).data;
    final providers = <ContentProviderConfig>[];
    final repository = _providerRepository;
    if (repository != null) {
      final providersResult = await repository.getProviders(enabledOnly: false);
      if (providersResult is Success<List<ContentProviderConfig>>) {
        providers.addAll(providersResult.data);
      }
    }
    return Success(
      const JsonEncoder.withIndent('  ').convert({
        'schemaVersion': 2,
        'settings': settings.toJson(),
        'filters': {
          'blacklistedTags': settings.blacklistedTags,
          'whitelistedTags': settings.whitelistedTags,
          'smartBlacklistRules': settings.smartBlacklistRules,
          'hiddenPostKeys': settings.hiddenPostKeys,
        },
        'providers': providers.map((provider) => provider.toJson()).toList(),
      }),
    );
  }

  Future<Result<void>> importSettingsFromJson(String json) async {
    try {
      final decoded = jsonDecode(json) as Map<String, dynamic>;
      final settingsJson =
          (decoded['settings'] as Map?)?.cast<String, dynamic>() ?? decoded;
      final filtersJson =
          (decoded['filters'] as Map?)?.cast<String, dynamic>() ?? const {};
      for (final key in [
        'blacklistedTags',
        'whitelistedTags',
        'smartBlacklistRules',
        'hiddenPostKeys',
      ]) {
        settingsJson.putIfAbsent(key, () => filtersJson[key]);
      }
      final settings = AppSettings.fromJson(settingsJson);
      final result = await updateSettings(settings);
      if (result is Error<void>) return result;
      final repository = _providerRepository;
      final providerItems = decoded['providers'];
      if (repository != null && providerItems is List) {
        for (final item in providerItems.whereType<Map>()) {
          await repository.saveProvider(
            ContentProviderConfig.fromJson(
              Map<String, dynamic>.from(item),
            ).copyWith(updatedAt: DateTime.now()),
          );
        }
      }
      await saveEnabledProviders(settings.enabledProviderIds);
      return result;
    } catch (error) {
      return Error(
        Failure(
          code: 'settings_import',
          message: 'Invalid settings JSON',
          details: error,
        ),
      );
    }
  }
}
