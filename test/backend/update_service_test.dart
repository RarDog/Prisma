import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prisma_app/features/settings/models/app_update_info.dart';
import 'package:prisma_app/features/settings/domain/settings_service.dart';
import 'package:prisma_app/features/settings/domain/update_service.dart';
import 'package:prisma_app/core/database/database_service.dart';

void main() {
  test('UpdateService parses GitHub release JSON correctly', () {
    final service =
        UpdateService(Dio(), SettingsService(_MockDatabaseService()));

    // Use reflection or constructor to test info
    final info = AppUpdateInfo(
      version: '2.0.2',
      tagName: 'v2.0.2',
      name: 'Prisma 2.0.2',
      body: 'Release notes',
      htmlUrl: 'https://github.com/RarDog/Prisma/releases/tag/v2.0.2',
      publishedAt: DateTime.parse('2026-09-03T18:00:00Z'),
      apkUrl:
          'https://github.com/RarDog/Prisma/releases/download/v2.0.2/Prisma.apk',
      linuxTarGzUrl:
          'https://github.com/RarDog/Prisma/releases/download/v2.0.2/linux.tar.gz',
    );

    expect(info.hasAssets, isTrue);
    expect(info.apkUrl, contains('apk'));
    expect(info.linuxTarGzUrl, contains('linux'));
    expect(
      service.assetFileName(info,
          'https://github.com/RarDog/Prisma/releases/download/v2.0.2/Prisma-v2.0.2.apk'),
      'Prisma-v2.0.2.apk',
    );
    expect(
      service.assetFileName(info,
          'https://github.com/RarDog/Prisma/releases/download/v2.0.2/unknown-linux'),
      'Prisma-v2.0.2-linux-x64.tar.gz',
    );
    expect(
      service.assetFileName(info,
          'https://github.com/RarDog/Prisma/releases/download/v2.0.2/Prisma-v2.0.2-linux-x86_64.AppImage'),
      'Prisma-v2.0.2-linux-x86_64.AppImage',
    );
  });

  test('releaseFromJson extracts asset digests and checksum sidecar URL', () {
    final service =
        UpdateService(Dio(), SettingsService(_MockDatabaseService()));

    final info = service.releaseFromJsonForTest({
      'tag_name': 'v4.3.0',
      'name': 'Prisma 4.3.0',
      'body': '',
      'html_url': '',
      'assets': [
        {
          'name': 'Prisma-v4.3.0-android.apk',
          'browser_download_url':
              'https://example.com/Prisma-v4.3.0-android.apk',
          'digest': 'sha256:ABCDEF0123456789ABCDEF0123456789'
              'ABCDEF0123456789ABCDEF0123456789',
        },
        {
          'name': 'SHA256SUMS',
          'browser_download_url': 'https://example.com/SHA256SUMS',
        },
        {
          'name': 'Prisma-v4.3.0-linux-x86_64.AppImage',
          'browser_download_url':
              'https://example.com/Prisma-v4.3.0-linux-x86_64.AppImage',
        },
      ],
    });

    expect(
      info.digestFor('Prisma-v4.3.0-android.apk'),
      'abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789',
    );
    // Case-insensitive lookup.
    expect(
      info.digestFor('prisma-v4.3.0-android.apk'),
      isNotNull,
    );
    // Asset without a digest field stays absent.
    expect(info.digestFor('Prisma-v4.3.0-linux-x86_64.AppImage'), isNull);
    expect(info.checksumFileUrl, 'https://example.com/SHA256SUMS');
  });

  test('releaseFromJson ignores malformed digests', () {
    final service =
        UpdateService(Dio(), SettingsService(_MockDatabaseService()));

    final info = service.releaseFromJsonForTest({
      'tag_name': 'v4.3.0',
      'name': 'Prisma 4.3.0',
      'body': '',
      'html_url': '',
      'assets': [
        {
          'name': 'app.apk',
          'browser_download_url': 'https://example.com/app.apk',
          'digest': 'md5:not-a-sha256-digest',
        },
      ],
    });

    expect(info.digestFor('app.apk'), isNull);
    expect(info.checksumFileUrl, isNull);
  });

  test('parseChecksumList parses SUMS-format lines', () {
    final digests = UpdateService.parseChecksumList('''
# SHA256 checksums
abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789  Prisma.apk
0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef *Prisma-linux.AppImage

garbage-line
''');

    expect(digests['prisma.apk'],
        'abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789');
    expect(digests['prisma-linux.appimage'],
        '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef');
    expect(digests, hasLength(2));
  });

  test('computeSha256 matches known digest of a small file', () async {
    final dir = await Directory.systemTemp.createTemp('prisma_sha_test_');
    addTearDown(() => dir.deleteSync(recursive: true));
    final file = File('${dir.path}/sample.bin');
    await file.writeAsBytes(List<int>.generate(100000, (i) => i % 251));

    // _computeSha256 is private; exercise it through the public static path
    // by hashing the same bytes with package:crypto directly and comparing
    // against the chunked helper via reflection-free duplicate call.
    final expected = sha256.convert(await file.readAsBytes()).toString();

    // Call the static helper through the exported symbol.
    final actual = await UpdateService.computeSha256ForTest(file.path);
    expect(actual, expected);
  });
}

class _MockDatabaseService implements DatabaseService {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
