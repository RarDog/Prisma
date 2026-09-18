import 'package:dio/dio.dart';
import 'dart:io';

import 'package:flutter/services.dart';

import 'package:gel_rule_app/app/app_version.dart';
import 'package:gel_rule_app/core/errors/failure.dart';
import 'package:gel_rule_app/core/utils/result.dart';
import 'package:gel_rule_app/features/settings/models/app_update_info.dart';
import 'package:gel_rule_app/features/settings/domain/settings_service.dart';

enum UpdateSource {
  gitea,
  github,
}

class UpdateService {
  UpdateService(this._dio, this._settingsService);

  static const giteaLatestReleaseUrl =
      'https://gitea.rardogsynapse.online/api/v1/repos/RarDog/Prisma/releases/latest';
  static const giteaReleasesUrl =
      'https://gitea.rardogsynapse.online/api/v1/repos/RarDog/Prisma/releases';

  static const githubLatestReleaseUrl =
      'https://api.github.com/repos/RarDog/Prisma/releases/latest';
  static const githubReleasesUrl =
      'https://api.github.com/repos/RarDog/Prisma/releases';

  static const latestReleaseUrl = githubLatestReleaseUrl;
  static const releasesUrl = githubReleasesUrl;

  static const _deviceChannel = MethodChannel('rulegel/device');

  final Dio _dio;
  final SettingsService _settingsService;

  // Cached primary ABI (e.g. "arm64-v8a").
  String? _cachedPrimaryAbi;

  /// Returns the primary ABI of the running device.
  /// On non-Android platforms returns an empty string.
  Future<String> getPrimaryAbi() async {
    if (_cachedPrimaryAbi != null) return _cachedPrimaryAbi!;
    if (!Platform.isAndroid) return '';
    try {
      final abi = await _deviceChannel.invokeMethod<String>('getPrimaryAbi');
      _cachedPrimaryAbi = abi ?? 'armeabi-v7a';
    } catch (_) {
      _cachedPrimaryAbi = 'armeabi-v7a';
    }
    return _cachedPrimaryAbi!;
  }

  /// Returns all supported ABIs of the running device.
  Future<List<String>> getSupportedAbis() async {
    if (!Platform.isAndroid) return const [];
    try {
      final abis = await _deviceChannel.invokeMethod<List<Object?>>('getSupportedAbis');
      return abis?.whereType<String>().toList() ?? const [];
    } catch (_) {
      return const [];
    }
  }

  Future<Result<AppUpdateInfo?>> checkForUpdates({
    bool force = false,
    UpdateSource source = UpdateSource.gitea,
  }) async {
    final settingsResult = await _settingsService.getSettings();
    final settings = settingsResult is Success<AppSettings>
        ? settingsResult.data
        : AppSettings.defaults;

    try {
      final info = await _latestAllowedRelease(settings, source: source);
      final nextSettings = settings.copyWith(
        lastUpdateCheckAt: DateTime.now().toIso8601String(),
      );
      await _settingsService.updateSettings(nextSettings);

      final skipped = settings.skippedUpdateVersion == info.version ||
          settings.skippedUpdateVersion == info.tagName;
      if (!force && skipped) return const Success(null);
      if (!_isNewerVersion(info.version, appDisplayVersion)) {
        return const Success(null);
      }
      return Success(info);
    } catch (error) {
      return Error(
        Failure(
          code: 'update_check_failed',
          message: 'Could not check for updates',
          details: error,
        ),
      );
    }
  }

  Future<AppUpdateInfo> _latestAllowedRelease(
    AppSettings settings, {
    UpdateSource source = UpdateSource.gitea,
  }) async {
    final isGitea = source == UpdateSource.gitea;
    final rUrl = isGitea ? giteaReleasesUrl : githubReleasesUrl;
    final latestUrl = isGitea ? giteaLatestReleaseUrl : githubLatestReleaseUrl;

    final options = Options(
      headers: isGitea
          ? {
              'Authorization': 'token 1c744d6044d756759d7b1f693c94c80cf70d75fa',
            }
          : {
              'User-Agent': 'Prisma-App',
              'Accept': 'application/vnd.github+json',
            },
    );

    final response = await _dio.get<dynamic>(
      rUrl,
      queryParameters: isGitea ? {'limit': 30} : {'per_page': 30},
      options: options,
    );
    final items = (response.data as List?) ?? const [];
    final releases = items
        .whereType<Map>()
        .where((item) => item['draft'] != true)
        .where((item) =>
            settings.allowExperimentalUpdates || item['prerelease'] != true)
        .map((item) => _releaseFromJson(Map<String, dynamic>.from(item)))
        .toList(growable: false);
    if (releases.isEmpty) {
      final latest = await _dio.get<dynamic>(
        latestUrl,
        options: options,
      );
      return _releaseFromJson(Map<String, dynamic>.from(latest.data as Map));
    }
    releases.sort((a, b) {
      final versionCompare = _compareVersions(b.version, a.version);
      if (versionCompare != 0) return versionCompare;
      final left = b.publishedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final right = a.publishedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return left.compareTo(right);
    });
    return releases.first;
  }

  Future<Result<void>> remindLater() async {
    final result = await _settingsService.getSettings();
    if (result is Error<AppSettings>) return Error(result.failure);
    final settings = (result as Success<AppSettings>).data;
    return _settingsService.updateSettings(
      settings.copyWith(lastUpdateCheckAt: DateTime.now().toIso8601String()),
    );
  }

  Future<Result<void>> skipVersion(AppUpdateInfo info) async {
    final result = await _settingsService.getSettings();
    if (result is Error<AppSettings>) return Error(result.failure);
    final settings = (result as Success<AppSettings>).data;
    return _settingsService.updateSettings(
      settings.copyWith(skippedUpdateVersion: info.version),
    );
  }

  AppUpdateInfo _releaseFromJson(Map<String, dynamic> json) {
    final tag = (json['tag_name'] ?? '').toString();
    final assets = (json['assets'] as List?) ?? const [];

    String? apkUrl;
    String? apkArm64Url;
    String? apkArmv7Url;
    String? apkX86_64Url;
    String? windowsInstallerUrl;
    String? windowsZipUrl;
    String? portableZipUrl;
    String? linuxAppImageUrl;
    String? linuxTarGzUrl;
    String? macosZipUrl;

    for (final item in assets.whereType<Map>()) {
      final name = (item['name'] ?? '').toString().toLowerCase();
      final url = (item['browser_download_url'] ?? '').toString();
      if (url.isEmpty) continue;

      if (name.endsWith('.apk')) {
        // Detect per-ABI APKs by name pattern produced by --split-per-abi.
        if (name.contains('arm64-v8a') || name.contains('arm64_v8a')) {
          apkArm64Url = url;
        } else if (name.contains('armeabi-v7a') || name.contains('armeabi_v7a')) {
          apkArmv7Url = url;
        } else if (name.contains('x86_64')) {
          apkX86_64Url = url;
        } else {
          // Universal / fat APK
          apkUrl = url;
        }
      } else if (name.endsWith('.appimage')) {
        linuxAppImageUrl = url;
      } else if (name.endsWith('.exe')) {
        windowsInstallerUrl = url;
      } else if (name.contains('macos') && name.endsWith('.zip')) {
        macosZipUrl = url;
      } else if (name.contains('windows') && name.endsWith('.zip')) {
        windowsZipUrl = url;
        portableZipUrl ??= url;
      } else if (name.endsWith('.tar.gz') || name.endsWith('.tgz')) {
        linuxTarGzUrl = url;
      } else if (name.endsWith('.zip')) {
        portableZipUrl ??= url;
      }
    }

    return AppUpdateInfo(
      version: _versionFromTag(tag),
      tagName: tag,
      name: (json['name'] ?? tag).toString(),
      body: (json['body'] ?? '').toString(),
      htmlUrl: (json['html_url'] ?? '').toString(),
      publishedAt: DateTime.tryParse((json['published_at'] ?? '').toString()),
      apkUrl: apkUrl,
      apkArm64Url: apkArm64Url,
      apkArmv7Url: apkArmv7Url,
      apkX86_64Url: apkX86_64Url,
      windowsInstallerUrl: windowsInstallerUrl,
      windowsZipUrl: windowsZipUrl,
      portableZipUrl: portableZipUrl,
      linuxAppImageUrl: linuxAppImageUrl,
      linuxTarGzUrl: linuxTarGzUrl,
      macosZipUrl: macosZipUrl,
    );
  }

  /// Returns the download URL for the current platform/ABI.
  /// Pass [abi] (e.g. from [getPrimaryAbi]) on Android for per-ABI selection.
  Future<String?> assetUrlForCurrentPlatform(AppUpdateInfo info) async {
    if (Platform.isAndroid) {
      final abi = await getPrimaryAbi();
      return info.apkUrlForAbi(abi);
    }
    if (Platform.isLinux) {
      return info.linuxAppImageUrl ?? info.linuxTarGzUrl ?? info.portableZipUrl;
    }
    if (Platform.isWindows) {
      return info.windowsInstallerUrl ?? info.windowsZipUrl ?? info.portableZipUrl;
    }
    if (Platform.isMacOS) {
      return info.macosZipUrl ?? info.portableZipUrl;
    }
    return info.portableZipUrl;
  }

  String assetFileName(AppUpdateInfo info, String url) {
    final parsed = Uri.tryParse(url);
    final fromUrl =
        parsed?.pathSegments.isEmpty ?? true ? '' : parsed!.pathSegments.last;
    if (fromUrl.contains('.')) return fromUrl;
    final lowerUrl = url.toLowerCase();
    if (lowerUrl.contains('appimage')) {
      return 'Prisma-v${info.version}-linux-x86_64.AppImage';
    }
    if (Platform.isAndroid) return 'Prisma-v${info.version}-android.apk';
    if (Platform.isLinux) return 'Prisma-v${info.version}-linux-x64.tar.gz';
    if (Platform.isWindows) return 'Prisma-v${info.version}-windows-x64.zip';
    if (Platform.isMacOS) return 'Prisma-v${info.version}-macos.zip';
    return 'PrismaPortable-v${info.version}.zip';
  }

  /// Downloads and automatically replaces/installs the update on Desktop/Mobile.
  /// Reports [progress] (0.0 to 1.0, or -1.0 if indeterminate) and human-readable [status].
  Future<void> downloadAndApplyUpdate({
    required AppUpdateInfo info,
    required void Function(double progress, String status) onProgress,
    CancelToken? cancelToken,
  }) async {
    final assetUrl = await assetUrlForCurrentPlatform(info);
    if (assetUrl == null) {
      throw Exception('No update package available for current platform');
    }

    final fileName = assetFileName(info, assetUrl);
    final tempDir = await Directory.systemTemp.createTemp('prisma_update_');
    final targetPath = '${tempDir.path}${Platform.pathSeparator}$fileName';

    onProgress(0.0, 'Начало загрузки...');

    await _dio.download(
      assetUrl,
      targetPath,
      cancelToken: cancelToken,
      onReceiveProgress: (received, total) {
        if (total > 0) {
          final ratio = received / total;
          final mbReceived = (received / (1024 * 1024)).toStringAsFixed(1);
          final mbTotal = (total / (1024 * 1024)).toStringAsFixed(1);
          onProgress(ratio, '$mbReceived / $mbTotal МБ (${(ratio * 100).toInt()}%)');
        } else {
          final mbReceived = (received / (1024 * 1024)).toStringAsFixed(1);
          onProgress(-1.0, '$mbReceived МБ');
        }
      },
    );

    onProgress(1.0, 'Установка обновления и перезапуск...');

    if (Platform.isAndroid) {
      const downloadChannel = MethodChannel('rulegel/downloads');
      await downloadChannel.invokeMethod('openFile', {
        'path': targetPath,
        'mimeType': 'application/vnd.android.package-archive',
      });
      return;
    }

    if (Platform.isLinux) {
      await _installLinuxUpdate(targetPath);
      return;
    }

    if (Platform.isWindows) {
      await _installWindowsUpdate(targetPath);
      return;
    }

    if (Platform.isMacOS) {
      await _installMacOSUpdate(targetPath);
      return;
    }
  }

  Future<void> _installLinuxUpdate(String downloadedPath) async {
    await Process.run('chmod', ['+x', downloadedPath]);

    final runningAppImage = Platform.environment['APPIMAGE'];
    if (runningAppImage != null && runningAppImage.isNotEmpty) {
      final appImageFile = File(runningAppImage);
      if (appImageFile.existsSync()) {
        final oldBackup = '$runningAppImage.old';
        try {
          final old = File(oldBackup);
          if (old.existsSync()) old.deleteSync();
        } catch (_) {}

        appImageFile.renameSync(oldBackup);
        File(downloadedPath).renameSync(runningAppImage);
        await Process.run('chmod', ['+x', runningAppImage]);
        try {
          File(oldBackup).deleteSync();
        } catch (_) {}

        await Process.start(runningAppImage, [], mode: ProcessStartMode.detached);
        exit(0);
      }
    }

    if (downloadedPath.endsWith('.AppImage')) {
      await Process.start(downloadedPath, [], mode: ProcessStartMode.detached);
      exit(0);
    } else if (downloadedPath.endsWith('.tar.gz') || downloadedPath.endsWith('.tgz')) {
      final appDir = File(Platform.resolvedExecutable).parent.path;
      await Process.run('tar', ['-xzf', downloadedPath, '-C', appDir]);
      await Process.start(Platform.resolvedExecutable, [], mode: ProcessStartMode.detached);
      exit(0);
    }
  }

  Future<void> _installWindowsUpdate(String downloadedPath) async {
    if (downloadedPath.toLowerCase().endsWith('.exe')) {
      await Process.start(downloadedPath, ['/SILENT'], mode: ProcessStartMode.detached);
      exit(0);
    }

    final exePath = Platform.resolvedExecutable;
    final exeDir = File(exePath).parent.path;
    final scriptPath = '${Directory.systemTemp.path}\\prisma_apply_update.bat';
    final scriptContent = '''
@echo off
timeout /t 2 /nobreak >nul
tar -xf "$downloadedPath" -C "$exeDir"
del /f /q "$downloadedPath"
start "" "$exePath"
del /f /q "%~f0"
''';
    await File(scriptPath).writeAsString(scriptContent);
    await Process.start('cmd.exe', ['/c', scriptPath], mode: ProcessStartMode.detached);
    exit(0);
  }

  Future<void> _installMacOSUpdate(String downloadedPath) async {
    final execPath = Platform.resolvedExecutable;
    var current = Directory(execPath);
    String? appBundlePath;
    while (current.path != current.parent.path) {
      if (current.path.endsWith('.app')) {
        appBundlePath = current.path;
        break;
      }
      current = current.parent;
    }
    appBundlePath ??= '/Applications/Prisma.app';
    final parentDir = Directory(appBundlePath).parent.path;

    final scriptPath = '${Directory.systemTemp.path}/prisma_apply_update.sh';
    final scriptContent = '''#!/bin/sh
sleep 2
rm -rf "$appBundlePath"
unzip -q -o "$downloadedPath" -d "$parentDir"
rm -f "$downloadedPath"
open "$appBundlePath"
rm -f "\$0"
''';
    final scriptFile = File(scriptPath);
    await scriptFile.writeAsString(scriptContent);
    await Process.run('chmod', ['+x', scriptPath]);
    await Process.start('sh', [scriptPath], mode: ProcessStartMode.detached);
    exit(0);
  }

  static String _versionFromTag(String tag) {
    final match = RegExp(r'v?(\d+\.\d+\.\d+)').firstMatch(tag);
    return match?.group(1) ?? tag.replaceFirst(RegExp(r'^v'), '');
  }

  static bool _isNewerVersion(String latest, String current) {
    return _compareVersions(latest, current) > 0;
  }

  static int _compareVersions(String latest, String current) {
    final left = _parts(latest);
    final right = _parts(current);
    for (var i = 0; i < 3; i++) {
      if (left[i] > right[i]) return 1;
      if (left[i] < right[i]) return -1;
    }
    return 0;
  }

  static List<int> _parts(String value) {
    final match = RegExp(r'(\d+)\.(\d+)\.(\d+)').firstMatch(value);
    if (match == null) return const [0, 0, 0];
    return [
      int.tryParse(match.group(1) ?? '') ?? 0,
      int.tryParse(match.group(2) ?? '') ?? 0,
      int.tryParse(match.group(3) ?? '') ?? 0,
    ];
  }
}
