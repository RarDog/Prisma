import 'package:dio/dio.dart';
import 'dart:io';
import 'dart:isolate';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import 'package:prisma_app/app/app_version.dart';
import 'package:prisma_app/core/errors/failure.dart';
import 'package:prisma_app/core/utils/result.dart';
import 'package:prisma_app/features/settings/models/app_update_info.dart';
import 'package:prisma_app/features/settings/domain/settings_service.dart';

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
      final abis =
          await _deviceChannel.invokeMethod<List<Object?>>('getSupportedAbis');
      return abis?.whereType<String>().toList() ?? const [];
    } catch (_) {
      return const [];
    }
  }

  Future<Result<AppUpdateInfo?>> checkForUpdates({
    bool force = false,
    UpdateSource source = UpdateSource.github,
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
    UpdateSource source = UpdateSource.github,
  }) async {
    final isGitea = source == UpdateSource.gitea;
    final rUrl = isGitea ? giteaReleasesUrl : githubReleasesUrl;
    final latestUrl = isGitea ? giteaLatestReleaseUrl : githubLatestReleaseUrl;

    // Both release APIs expose public release metadata. Never embed a
    // personal access token in the application binary or source repository.
    final options = Options(
      headers: isGitea
          ? const {
              'User-Agent': 'Prisma-App',
              'Accept': 'application/json',
            }
          : const {
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

    final assetDigests = <String, String>{};
    String? checksumFileUrl;

    for (final item in assets.whereType<Map>()) {
      final name = (item['name'] ?? '').toString();
      final lowerName = name.toLowerCase();
      final url = (item['browser_download_url'] ?? '').toString();
      if (url.isEmpty) continue;

      // GitHub exposes `digest` as "sha256:<hex>" on release assets.
      final digestRaw = (item['digest'] ?? '').toString();
      if (digestRaw.toLowerCase().startsWith('sha256:')) {
        final hash = digestRaw.split(':').last.trim().toLowerCase();
        if (RegExp(r'^[0-9a-f]{64}$').hasMatch(hash)) {
          assetDigests[lowerName] = hash;
        }
      }
      // Gitea and other hosts: rely on a sidecar checksum list asset.
      if (const {
        'sha256sums',
        'sha256sums.txt',
        'checksums.txt',
        'sha256-checksums.txt',
      }.contains(lowerName)) {
        checksumFileUrl ??= url;
      }

      if (name.endsWith('.apk')) {
        // Detect per-ABI APKs by name pattern produced by --split-per-abi.
        if (name.contains('arm64-v8a') || name.contains('arm64_v8a')) {
          apkArm64Url = url;
        } else if (name.contains('armeabi-v7a') ||
            name.contains('armeabi_v7a')) {
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

    final isPrerelease = json['prerelease'] == true ||
        tag.toLowerCase().contains('beta') ||
        tag.toLowerCase().contains('rc') ||
        tag.toLowerCase().contains('alpha');

    return AppUpdateInfo(
      version: _versionFromTag(tag),
      tagName: tag,
      name: (json['name'] ?? tag).toString(),
      body: (json['body'] ?? '').toString(),
      htmlUrl: (json['html_url'] ?? '').toString(),
      publishedAt: DateTime.tryParse((json['published_at'] ?? '').toString()),
      isPrerelease: isPrerelease,
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
      assetDigests: Map.unmodifiable(assetDigests),
      checksumFileUrl: checksumFileUrl,
    );
  }

  /// Parses the content of a SHA256SUMS-style checksum list into a map of
  /// lowercase file name -> sha256 hex digest. Skips comments and malformed
  /// lines; supports the `*` binary-mode marker.
  static Map<String, String> parseChecksumList(String content) {
    final result = <String, String>{};
    for (final rawLine in content.split(RegExp(r'\r?\n'))) {
      final line = rawLine.trim();
      if (line.isEmpty || line.startsWith('#')) continue;
      final match =
          RegExp(r'^([0-9a-fA-F]{64})\s+\*?(.+)$').firstMatch(line);
      if (match == null) continue;
      final hash = match.group(1)!.toLowerCase();
      final fileName = match.group(2)!.trim().toLowerCase();
      if (fileName.isEmpty) continue;
      result[fileName] = hash;
    }
    return result;
  }

  /// Visible for testing: parses a release JSON payload into [AppUpdateInfo].
  AppUpdateInfo releaseFromJsonForTest(Map<String, dynamic> json) =>
      _releaseFromJson(json);

  /// Returns the download URL for the current platform/ABI.
  /// Pass [abi] (e.g. from [getPrimaryAbi]) on Android for per-ABI selection.
  Future<String?> assetUrlForCurrentPlatform(AppUpdateInfo info) async {
    if (Platform.isAndroid) {
      final abi = await getPrimaryAbi();
      return info.apkUrlForAbi(abi);
    }
    if (Platform.isLinux) {
      final isAppImage = Platform.environment.containsKey('APPIMAGE');
      if (isAppImage) {
        if (info.linuxAppImageUrl != null) {
          return info.linuxAppImageUrl;
        }
        throw Exception(
          'Обновление в формате AppImage недоступно для этой версии на сервере обновлений.',
        );
      }
      return info.linuxTarGzUrl ?? info.portableZipUrl ?? info.linuxAppImageUrl;
    }
    if (Platform.isWindows) {
      return info.windowsInstallerUrl ??
          info.windowsZipUrl ??
          info.portableZipUrl;
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
    if (Platform.isLinux) {
      if (Platform.environment.containsKey('APPIMAGE')) {
        return 'Prisma-v${info.version}-linux-x86_64.AppImage';
      }
      return 'Prisma-v${info.version}-linux-x64.tar.gz';
    }
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
    Directory baseTempDir;
    try {
      baseTempDir = await getTemporaryDirectory();
    } catch (_) {
      baseTempDir = Directory.systemTemp;
    }
    final tempDir = await baseTempDir.createTemp('prisma_update_');
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
          onProgress(
              ratio, '$mbReceived / $mbTotal МБ (${(ratio * 100).toInt()}%)');
        } else {
          final mbReceived = (received / (1024 * 1024)).toStringAsFixed(1);
          onProgress(-1.0, '$mbReceived МБ');
        }
      },
    );

    // Integrity gate: never install a package whose checksum can be checked
    // but does not match. When the release publishes no digest at all we
    // proceed, since refusing would brick every update for such releases.
    final expectedDigest = await _expectedDigestFor(info, fileName);
    String installStatus = 'Установка обновления и перезапуск...';
    if (expectedDigest != null) {
      onProgress(1.0, 'Проверка целостности...');
      final actualDigest = await _computeSha256(targetPath);
      if (actualDigest != expectedDigest) {
        try {
          await tempDir.delete(recursive: true);
        } catch (_) {}
        throw Exception(
          'Проверка целостности обновления не пройдена (SHA-256 не совпадает). '
          'Загрузка отменена, установленная версия не тронута.',
        );
      }
      installStatus = 'Целостность подтверждена. Установка обновления...';
    }

    onProgress(1.0, installStatus);

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

  /// Resolves the expected SHA-256 digest for a downloaded release asset:
  /// first from the release JSON `digest` fields, then from a sidecar
  /// checksum list (SHA256SUMS / checksums.txt) if the release carries one.
  /// Returns null when the release publishes no verifiable digest.
  Future<String?> _expectedDigestFor(
    AppUpdateInfo info,
    String fileName,
  ) async {
    final fromJson = info.digestFor(fileName);
    if (fromJson != null) return fromJson;

    final checksumUrl = info.checksumFileUrl;
    if (checksumUrl == null || checksumUrl.isEmpty) return null;
    try {
      final response = await _dio.get<String>(
        checksumUrl,
        options: Options(responseType: ResponseType.plain),
      );
      final digests = parseChecksumList(response.data ?? '');
      final expected = digests[fileName.toLowerCase()];
      if (expected == null) return null;
      return RegExp(r'^[0-9a-f]{64}$').hasMatch(expected) ? expected : null;
    } catch (_) {
      // Sidecar unavailable — fall through to unverified install rather than
      // blocking updates whose metadata simply moved.
      return null;
    }
  }

  /// Computes the SHA-256 hex digest of the file at [path] off the main
  /// isolate so large packages do not jank the UI.
  static Future<String> _computeSha256(String path) {
    return Isolate.run(() async {
      final sink = _HexDigestSink();
      final converter = sha256.startChunkedConversion(sink);
      await for (final chunk in File(path).openRead()) {
        converter.add(chunk);
      }
      converter.close();
      return sink.hex;
    });
  }

  /// Visible for testing: exposes the isolate-based SHA-256 helper.
  static Future<String> computeSha256ForTest(String path) =>
      _computeSha256(path);

  Future<void> _installLinuxUpdate(String downloadedPath) async {
    await Process.run('chmod', ['+x', downloadedPath]);

    final isAppImageFile = downloadedPath.endsWith('.AppImage') ||
        downloadedPath.toLowerCase().endsWith('.appimage');

    final runningAppImage = Platform.environment['APPIMAGE'];
    if (runningAppImage != null && runningAppImage.isNotEmpty) {
      if (!isAppImageFile) {
        throw Exception(
          'Скачанный файл не является AppImage и не может заменить текущий запускаемый файл.',
        );
      }

      final appImageFile = File(runningAppImage);
      if (appImageFile.existsSync()) {
        final oldBackup = '$runningAppImage.old';
        try {
          final old = File(oldBackup);
          if (old.existsSync()) old.deleteSync();
        } catch (_) {}

        appImageFile.renameSync(oldBackup);
        try {
          _safeMoveFile(downloadedPath, runningAppImage);
        } catch (e) {
          // Rollback on failure so the original AppImage is not lost or broken
          try {
            if (!File(runningAppImage).existsSync() &&
                File(oldBackup).existsSync()) {
              File(oldBackup).renameSync(runningAppImage);
            }
          } catch (_) {}
          rethrow;
        }

        await Process.run('chmod', ['+x', runningAppImage]);
        try {
          File(oldBackup).deleteSync();
        } catch (_) {}

        await Process.start(runningAppImage, [],
            mode: ProcessStartMode.detached);
        exit(0);
      }
    }

    if (isAppImageFile) {
      await Process.start(downloadedPath, [], mode: ProcessStartMode.detached);
      exit(0);
    } else if (downloadedPath.endsWith('.tar.gz') ||
        downloadedPath.endsWith('.tgz')) {
      final appDir = File(Platform.resolvedExecutable).parent.path;
      final res = await Process.run(
        'tar',
        ['--unlink-first', '-xzf', downloadedPath, '-C', appDir],
      );
      if (res.exitCode != 0) {
        await Process.run('tar', ['-xzf', downloadedPath, '-C', appDir]);
      }
      await Process.start(Platform.resolvedExecutable, [],
          mode: ProcessStartMode.detached);
      exit(0);
    }
  }

  void _safeMoveFile(String sourcePath, String targetPath) {
    final source = File(sourcePath);
    try {
      source.renameSync(targetPath);
      return;
    } on FileSystemException {
      // Fallback for cross-device links (e.g. /tmp on tmpfs to /home on disk)
    }

    source.copySync(targetPath);
    try {
      source.deleteSync();
    } catch (_) {}
  }

  Future<void> _installWindowsUpdate(String downloadedPath) async {
    if (downloadedPath.toLowerCase().endsWith('.exe')) {
      await Process.start(downloadedPath, ['/SILENT'],
          mode: ProcessStartMode.detached);
      exit(0);
    }

    final exePath = Platform.resolvedExecutable;
    final exeDir = File(exePath).parent.path;
    final cleanExeDir =
        exeDir.replaceAll('/', '\\').replaceAll(RegExp(r'\\+$'), '');
    final cleanDownloadedPath = downloadedPath.replaceAll('/', '\\');
    final cleanExePath = exePath.replaceAll('/', '\\');

    final scriptPath = '${Directory.systemTemp.path}\\prisma_apply_update.bat';
    final scriptContent = '''
@echo off
timeout /t 2 /nobreak >nul
tar -xf "$cleanDownloadedPath" -C "$cleanExeDir"
del /f /q "$cleanDownloadedPath"
start "" "$cleanExePath"
del /f /q "%~f0"
''';
    await File(scriptPath).writeAsString(scriptContent);
    await Process.start('cmd.exe', ['/c', scriptPath],
        mode: ProcessStartMode.detached);
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

    // Unzip into a staging directory FIRST and only replace the live bundle
    // once extraction succeeded, so a corrupt archive can never destroy the
    // working installation.
    final stagingDir = '$parentDir/.prisma_update_staging';
    final scriptPath = '${Directory.systemTemp.path}/prisma_apply_update.sh';
    final scriptContent = '''#!/bin/sh
sleep 2
rm -rf "$stagingDir"
if unzip -q -o "$downloadedPath" -d "$stagingDir"; then
  STAGED_APP=\$(find "\$stagingDir" -maxdepth 1 -name "*.app" | head -n 1)
  if [ -n "\$STAGED_APP" ]; then
    rm -rf "$appBundlePath"
    mv "\$STAGED_APP" "$appBundlePath"
  else
    unzip -q -o "$downloadedPath" -d "$parentDir"
  fi
fi
rm -rf "$stagingDir"
rm -f "$downloadedPath"
xattr -dr com.apple.quarantine "$appBundlePath" 2>/dev/null || true
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
    // Preserve full version including prerelease, e.g. "1.2.3-beta.1"
    final clean =
        tag.trim().replaceFirst(RegExp(r'^v', caseSensitive: false), '');
    return clean;
  }

  static bool _isNewerVersion(String latest, String current) {
    return _compareVersions(latest, current) > 0;
  }

  /// Compares two version strings supporting Semantic Versioning and prerelease suffixes:
  /// Examples:
  /// - 1.2.1 > 1.2.0
  /// - 1.2.0 > 1.2.0-beta.2
  /// - 1.2.0-beta.2 > 1.2.0-beta.1
  /// - 1.2.0-rc.1 > 1.2.0-beta.2
  static int _compareVersions(String latest, String current) {
    final vA = _ParsedVersion.parse(latest);
    final vB = _ParsedVersion.parse(current);
    return vA.compareTo(vB);
  }

  static int compareVersionsForTest(String latest, String current) =>
      _compareVersions(latest, current);
}

class _HexDigestSink implements Sink<Digest> {
  String hex = '';

  @override
  void add(Digest data) => hex = data.toString();

  @override
  void close() {}
}

class _ParsedVersion implements Comparable<_ParsedVersion> {
  const _ParsedVersion({
    required this.major,
    required this.minor,
    required this.patch,
    this.preType,
    this.preNumber = 0,
  });

  final int major;
  final int minor;
  final int patch;
  final String? preType; // e.g. "alpha", "beta", "rc"
  final int preNumber; // e.g. 1 in beta.1

  static _ParsedVersion parse(String value) {
    final clean =
        value.trim().replaceFirst(RegExp(r'^v', caseSensitive: false), '');
    final match = RegExp(
      r'^(\d+)(?:\.(\d+))?(?:\.(\d+))?(?:[-._]?(alpha|beta|rc|dev|preview)[-._]?(\d+)?)?',
      caseSensitive: false,
    ).firstMatch(clean);
    if (match == null) {
      return const _ParsedVersion(major: 0, minor: 0, patch: 0);
    }

    final maj = int.tryParse(match.group(1) ?? '0') ?? 0;
    final min = int.tryParse(match.group(2) ?? '0') ?? 0;
    final pat = int.tryParse(match.group(3) ?? '0') ?? 0;
    final type = match.group(4)?.toLowerCase();
    final num = int.tryParse(match.group(5) ?? '1') ?? 1;

    return _ParsedVersion(
      major: maj,
      minor: min,
      patch: pat,
      preType: type,
      preNumber: num,
    );
  }

  @override
  int compareTo(_ParsedVersion other) {
    if (major != other.major) return major.compareTo(other.major);
    if (minor != other.minor) return minor.compareTo(other.minor);
    if (patch != other.patch) return patch.compareTo(other.patch);

    // If major.minor.patch are equal:
    // A stable release (no preType) is ALWAYS newer than a prerelease (e.g. 1.2.0 > 1.2.0-beta)
    if (preType == null && other.preType != null) return 1;
    if (preType != null && other.preType == null) return -1;
    if (preType == null && other.preType == null) return 0;

    // Both are prereleases: order alpha < beta < rc
    final rankA = _preRank(preType!);
    final rankB = _preRank(other.preType!);
    if (rankA != rankB) return rankA.compareTo(rankB);

    // Same pre-type, compare pre-number (e.g. beta.2 > beta.1)
    return preNumber.compareTo(other.preNumber);
  }

  static int _preRank(String type) {
    switch (type) {
      case 'alpha':
      case 'dev':
        return 1;
      case 'beta':
      case 'preview':
        return 2;
      case 'rc':
        return 3;
      default:
        return 2;
    }
  }
}
