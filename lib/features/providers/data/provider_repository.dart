import 'dart:convert';

import 'package:isar/isar.dart';

import 'package:gel_rule_app/core/database/app_database.dart';
import 'package:gel_rule_app/core/database/database_service.dart';
import 'package:gel_rule_app/core/http/app_headers.dart';
import 'package:gel_rule_app/core/utils/result.dart';
import 'package:gel_rule_app/features/providers/models/content_provider_config.dart';
import 'package:gel_rule_app/core/models/provider_diagnostics.dart';
import 'package:gel_rule_app/core/models/provider_health.dart';

class ProviderRepository {
  ProviderRepository(this._databaseService, {this.onDataChanged});

  final DatabaseService _databaseService;
  final void Function()? onDataChanged;

  static List<ContentProviderConfig> seedProviders() {
    final now = DateTime.now();
    return [
      ContentProviderConfig(
        id: 'gelbooru',
        name: 'Gelbooru',
        baseUrl: 'https://gelbooru.com',
        apiType: 'gelbooru',
        enabled: true,
        priority: 0,
        timeoutSeconds: 20,
        customHeaders: const {},
        createdAt: now,
        updatedAt: now,
      ),
      ContentProviderConfig(
        id: 'rule34',
        name: 'Rule34',
        baseUrl: 'https://api.rule34.xxx',
        apiType: 'rule34',
        enabled: true,
        priority: 1,
        timeoutSeconds: 20,
        customHeaders: const {},
        createdAt: now,
        updatedAt: now,
      ),
      ContentProviderConfig(
        id: 'safebooru',
        name: 'Safebooru',
        baseUrl: 'https://safebooru.org',
        apiType: 'safebooru',
        enabled: true,
        priority: 2,
        timeoutSeconds: 20,
        customHeaders: {
          'User-Agent': AppHeaders.defaultUserAgent,
        },
        createdAt: now,
        updatedAt: now,
      ),
      ContentProviderConfig(
        id: 'danbooru',
        name: 'Danbooru',
        baseUrl: 'https://danbooru.donmai.us',
        apiType: 'danbooru',
        enabled: true,
        priority: 3,
        timeoutSeconds: 20,
        customHeaders: {
          'User-Agent': AppHeaders.defaultUserAgent,
        },
        createdAt: now,
        updatedAt: now,
      ),
      ContentProviderConfig(
        id: 'realbooru',
        name: 'Realbooru',
        baseUrl: 'https://realbooru.com',
        apiType: 'realbooru_html',
        enabled: true,
        priority: 4,
        timeoutSeconds: 20,
        customHeaders: const {},
        createdAt: now,
        updatedAt: now,
      ),
      ContentProviderConfig(
        id: 'e621',
        name: 'e621',
        baseUrl: 'https://e621.net',
        apiType: 'e621',
        enabled: true,
        priority: 5,
        timeoutSeconds: 20,
        customHeaders: {
          'User-Agent': AppHeaders.defaultUserAgent,
        },
        createdAt: now,
        updatedAt: now,
      ),
      ContentProviderConfig(
        id: 'e926',
        name: 'e926',
        baseUrl: 'https://e926.net',
        apiType: 'e621',
        enabled: true,
        priority: 6,
        timeoutSeconds: 20,
        customHeaders: {
          'User-Agent': AppHeaders.defaultUserAgent,
        },
        createdAt: now,
        updatedAt: now,
      ),
      ContentProviderConfig(
        id: 'pawchive',
        name: 'Pawchive',
        baseUrl: 'https://pawchive.pw',
        apiType: 'pawchive',
        enabled: true,
        priority: 7,
        timeoutSeconds: 20,
        customHeaders: const {},
        createdAt: now,
        updatedAt: now,
      ),
      ContentProviderConfig(
        id: 'pixiv',
        name: 'Pixiv',
        baseUrl: 'https://www.pixiv.net',
        apiType: 'pixiv',
        enabled: true,
        priority: 8,
        timeoutSeconds: 25,
        customHeaders: {
          'Referer': 'https://www.pixiv.net/',
          'User-Agent': AppHeaders.desktopChromeUserAgent,
        },
        createdAt: now,
        updatedAt: now,
      ),
      ContentProviderConfig(
        id: 'mangadex',
        name: 'MangaDex',
        baseUrl: 'https://api.mangadex.org',
        apiType: 'mangadex',
        enabled: true,
        priority: 9,
        timeoutSeconds: 25,
        customHeaders: {
          'Referer': 'https://mangadex.org/',
          'User-Agent': AppHeaders.mangaDexUserAgent,
        },
        createdAt: now,
        updatedAt: now,
      ),
      ContentProviderConfig(
        id: 'mangalib',
        name: 'MangaLib',
        baseUrl: 'https://api.cdnlibs.org/api',
        apiType: 'mangalib',
        enabled: true,
        priority: 10,
        timeoutSeconds: 25,
        customHeaders: AppHeaders.browserHeaders(
          siteId: '1',
          referer: 'https://mangalib.me/',
          origin: 'https://mangalib.me',
        ),
        createdAt: now,
        updatedAt: now,
      ),
      ContentProviderConfig(
        id: 'ranobelib',
        name: 'RanobeLib',
        baseUrl: 'https://api.cdnlibs.org/api',
        apiType: 'ranobelib',
        enabled: true,
        priority: 11,
        timeoutSeconds: 25,
        customHeaders: AppHeaders.browserHeaders(
          siteId: '3',
          referer: 'https://ranobelib.me/',
          origin: 'https://ranobelib.me',
        ),
        createdAt: now,
        updatedAt: now,
      ),
      ContentProviderConfig(
        id: 'fapello',
        name: 'Fapello',
        baseUrl: 'https://fapello.com',
        apiType: 'fapello',
        // Off by default: the site serves its HTML behind a Cloudflare
        // managed challenge, which the app's HTTP client cannot pass. The
        // parser is complete and its tests cover it, so it only needs the
        // protection lifted (or a browser-grade TLS stack) to work.
        enabled: false,
        priority: 12,
        timeoutSeconds: 25,
        customHeaders: const {},
        createdAt: now,
        updatedAt: now,
      ),
      ContentProviderConfig(
        id: 'wallhaven',
        name: 'Wallhaven',
        baseUrl: 'https://wallhaven.cc',
        apiType: 'wallhaven',
        enabled: true,
        priority: 13,
        timeoutSeconds: 20,
        customHeaders: {
          'Referer': 'https://wallhaven.cc/',
          'User-Agent': AppHeaders.defaultUserAgent,
        },
        createdAt: now,
        updatedAt: now,
      ),
      ContentProviderConfig(
        id: 'yandere',
        name: 'Yande.re',
        baseUrl: 'https://yande.re',
        apiType: 'moebooru',
        enabled: true,
        priority: 14,
        timeoutSeconds: 25,
        customHeaders: {
          'Referer': 'https://yande.re/',
          'User-Agent': AppHeaders.defaultUserAgent,
        },
        createdAt: now,
        updatedAt: now,
      ),
      ContentProviderConfig(
        id: 'konachan',
        name: 'Konachan',
        baseUrl: 'https://konachan.net',
        apiType: 'moebooru',
        enabled: true,
        priority: 15,
        timeoutSeconds: 25,
        customHeaders: {
          'Referer': 'https://konachan.net/',
          'User-Agent': AppHeaders.defaultUserAgent,
        },
        createdAt: now,
        updatedAt: now,
      ),
      ContentProviderConfig(
        id: 'tbib',
        name: 'TBIB',
        baseUrl: 'https://tbib.org',
        apiType: 'tbib',
        enabled: true,
        priority: 16,
        timeoutSeconds: 20,
        customHeaders: {
          'Referer': 'https://tbib.org/',
          'User-Agent': AppHeaders.defaultUserAgent,
        },
        createdAt: now,
        updatedAt: now,
      ),
      ContentProviderConfig(
        id: 'rule34_us',
        name: 'Rule34.us',
        baseUrl: 'https://rule34.us',
        apiType: 'rule34_us',
        enabled: true,
        priority: 17,
        timeoutSeconds: 20,
        customHeaders: {
          'Referer': 'https://rule34.us/',
          'User-Agent': AppHeaders.desktopChromeUserAgent,
        },
        createdAt: now,
        updatedAt: now,
      ),
      ContentProviderConfig(
        id: 'xvideos',
        name: 'XVideos',
        baseUrl: 'https://www.xvideos.com',
        apiType: 'xvideos',
        enabled: true,
        priority: 18,
        timeoutSeconds: 25,
        customHeaders: {
          'Referer': 'https://www.xvideos.com/',
          'User-Agent': AppHeaders.desktopChromeUserAgent,
        },
        createdAt: now,
        updatedAt: now,
      ),
    ];
  }

  Future<Result<void>> ensureSeedProviders() {
    return _databaseService.safeWrite((isar) async {
      final existingProviders =
          await isar.providerConfigEntitys.where().findAll();
      const removedIds = {
        'xbooru',
        'paheal',
        'kemono',
        'coomer',
        'nhentai',
        'mangaupdates',
        'hitomi',
        'ehentai',
        'arena',
      };
      for (final provider in existingProviders) {
        if (provider.providerId == 'cosbooru') {
          provider.enabled = false;
          provider.updatedAt = DateTime.now();
          await isar.providerConfigEntitys.put(provider);
        } else if (removedIds.contains(provider.providerId)) {
          await isar.providerConfigEntitys.delete(provider.isarId);
        }
      }
      final seeds = seedProviders();
      for (final seed in seeds) {
        final exists = await isar.providerConfigEntitys
            .filter()
            .providerIdEqualTo(seed.id)
            .findFirst();
        if (exists == null) {
          await isar.providerConfigEntitys
              .put(ProviderConfigEntity.fromModel(seed));
        } else if (exists.apiType != seed.apiType ||
            exists.baseUrl != seed.baseUrl ||
            (seed.customHeaders.isNotEmpty &&
                (exists.customHeadersJson.isEmpty ||
                    exists.customHeadersJson == '{}'))) {
          exists.name = seed.name;
          exists.baseUrl = seed.baseUrl;
          exists.apiType = seed.apiType;
          if (seed.customHeaders.isNotEmpty &&
              (exists.customHeadersJson.isEmpty ||
                  exists.customHeadersJson == '{}')) {
            exists.customHeadersJson = jsonEncode(seed.customHeaders);
          }
          exists.timeoutSeconds = seed.timeoutSeconds;
          exists.updatedAt = DateTime.now();
          await isar.providerConfigEntitys.put(exists);
        }
      }
    });
  }

  Future<Result<List<ContentProviderConfig>>> getProviders({
    bool enabledOnly = false,
  }) {
    return _databaseService.safeRead((isar) async {
      final providers = enabledOnly
          ? await isar.providerConfigEntitys
              .filter()
              .enabledEqualTo(true)
              .findAll()
          : await isar.providerConfigEntitys.where().findAll();
      providers.sort((a, b) => a.priority.compareTo(b.priority));
      return providers.map((entity) => entity.toModel()).toList();
    });
  }

  Future<Result<ContentProviderConfig?>> getProvider(String id) {
    return _databaseService.safeRead((isar) async {
      final entity = await isar.providerConfigEntitys
          .filter()
          .providerIdEqualTo(id)
          .findFirst();
      return entity?.toModel();
    });
  }

  Future<Result<void>> saveProvider(ContentProviderConfig config) async {
    final res = await _databaseService.safeWrite((isar) async {
      await isar.providerConfigEntitys
          .put(ProviderConfigEntity.fromModel(config));
    });
    if (res is Success) onDataChanged?.call();
    return res;
  }

  Future<Result<void>> deleteProvider(String id) async {
    final res = await _databaseService.safeWrite((isar) async {
      await isar.providerConfigEntitys
          .filter()
          .providerIdEqualTo(id)
          .deleteAll();
      await isar.providerHealthEntitys
          .filter()
          .providerIdEqualTo(id)
          .deleteAll();
    });
    if (res is Success) onDataChanged?.call();
    return res;
  }

  Future<Result<void>> saveHealth(ProviderHealth health) {
    return _databaseService.safeWrite((isar) async {
      await isar.providerHealthEntitys
          .put(ProviderHealthEntity.fromModel(health));
    });
  }

  Future<Result<ProviderHealth?>> getHealth(String providerId) {
    return _databaseService.safeRead((isar) async {
      final entity = await isar.providerHealthEntitys
          .filter()
          .providerIdEqualTo(providerId)
          .findFirst();
      return entity?.toModel();
    });
  }

  Future<Result<List<ProviderHealth>>> getAllHealth() {
    return _databaseService.safeRead((isar) async {
      final entities = await isar.providerHealthEntitys.where().findAll();
      return entities.map((e) => e.toModel()).toList();
    });
  }

  Future<Result<void>> saveDiagnostics(ProviderDiagnostics diagnostics) {
    return _databaseService.safeWrite((isar) async {
      await isar.providerDiagnosticsEntitys.put(
        ProviderDiagnosticsEntity.fromModel(diagnostics),
      );
    });
  }

  Future<Result<List<ProviderDiagnostics>>> getDiagnostics() {
    return _databaseService.safeRead((isar) async {
      final items = await isar.providerDiagnosticsEntitys.where().findAll();
      return items.map((item) => item.toModel()).toList();
    });
  }
}
