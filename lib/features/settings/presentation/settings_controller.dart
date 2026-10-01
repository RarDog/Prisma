import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:gel_rule_app/app/app.dart';
import 'package:gel_rule_app/app/app_version.dart';
import 'package:gel_rule_app/backend/backend.dart';
import 'package:gel_rule_app/core/utils/logger.dart';
import 'package:gel_rule_app/core/utils/result.dart';

final settingsControllerProvider =
    AsyncNotifierProvider<SettingsController, AppSettings>(
        SettingsController.new);

class SettingsController extends AsyncNotifier<AppSettings> {
  @override
  Future<AppSettings> build() async {
    try {
      final result = await ref.read(settingsServiceProvider).getSettings();
      return result is Success<AppSettings> ? result.data : AppSettings.defaults;
    } catch (_) {
      return AppSettings.defaults;
    }
  }

  Future<void> saveSettings(AppSettings settings) async {
    state = AsyncData(settings);
    try {
      await ref.read(settingsServiceProvider).updateSettings(settings);
    } catch (e) {
      const AppLogger().debug('Could not persist settings', e);
    }
    ref.invalidate(appSettingsProvider);
  }

  Future<void> saveMangaCatalogState({
    String? rating,
    double? scrollOffset,
    String? providerId,
  }) async {
    final current = state.valueOrNull ?? AppSettings.defaults;
    final updated = current.copyWith(
      mangaSelectedRating: rating ?? current.mangaSelectedRating,
      mangaScrollOffset: scrollOffset ?? current.mangaScrollOffset,
      mangaSelectedProviderId: providerId ?? current.mangaSelectedProviderId,
    );
    await saveSettings(updated);
  }

  Future<void> saveMangaReaderSettings({
    required String readingMode,
    required bool isRtl,
  }) async {
    final current = state.valueOrNull ?? AppSettings.defaults;
    final updated = current.copyWith(
      mangaReadingMode: readingMode,
      mangaReaderRtl: isRtl,
    );
    await saveSettings(updated);
  }

  Future<void> saveMangaVolumeNavigation({
    required bool enabled,
    bool? invert,
  }) async {
    final current = state.valueOrNull ?? AppSettings.defaults;
    final updated = current.copyWith(
      mangaVolumeNavigation: enabled,
      mangaInvertVolumeKeys: invert ?? current.mangaInvertVolumeKeys,
    );
    await saveSettings(updated);
  }

  Future<void> setVideoPlayerVolume(double volume) async {
    final current = state.valueOrNull ?? AppSettings.defaults;
    final clamped = volume.clamp(0.0, 100.0);
    if ((current.videoPlayerVolume - clamped).abs() < 0.01) return;
    final updated = current.copyWith(videoPlayerVolume: clamped);
    state = AsyncData(updated);
    await ref.read(settingsServiceProvider).setVideoPlayerVolume(clamped);
    ref.invalidate(appSettingsProvider);
  }

  Future<void> clearCache() async {
    await ref.read(cacheServiceProvider).clear();
  }

  Future<void> clearViewedHistory() async {
    await ref.read(viewedHistoryServiceProvider).clearHistory();
    ref.invalidate(viewedKeysProvider);
  }

  Future<void> clearHiddenPosts() async {
    await ref.read(settingsServiceProvider).clearHiddenPosts();
    ref.invalidate(appSettingsProvider);
    ref.invalidateSelf();
  }

  Future<void> clearSearchHistory() async {
    await ref.read(searchServiceProvider).clearHistory();
  }

  Future<void> clearTagCache() async {
    await ref.read(searchServiceProvider).clearTagCache();
  }

  Future<String> diagnosticsReport() async {
    final result =
        await ref.read(settingsServiceProvider).buildDiagnosticsReport(
              appVersion: appDisplayVersion,
              buildNumber: appBuildNumber,
            );
    return result is Success<String> ? result.data : '{}';
  }

  Future<String> diagnosticLogs() async {
    final settings = state.value ?? AppSettings.defaults;
    final persistent = settings.diagnosticLogLines;
    final runtime = AppLogger.lines;
    return [...persistent, ...runtime].join('\n');
  }

  Future<void> clearDiagnosticLogs() async {
    AppLogger.clear();
    await ref.read(settingsServiceProvider).clearDiagnosticLogs();
    ref.invalidateSelf();
  }

  Future<String> exportJson() async {
    final result =
        await ref.read(settingsServiceProvider).exportSettingsToJson();
    return result is Success<String> ? result.data : '{}';
  }

  Future<void> importJson(String json) async {
    await ref.read(settingsServiceProvider).importSettingsFromJson(json);
    ref.invalidate(appSettingsProvider);
    ref.invalidateSelf();
  }
}
