import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/services.dart';
import 'package:isar/isar.dart' hide Collection;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'package:prisma_app/core/utils/logger.dart';

import 'package:prisma_app/core/database/app_database.dart';
import 'package:prisma_app/core/database/database_service.dart';
import 'package:prisma_app/core/errors/failure.dart';
import 'package:prisma_app/core/security/credential_store.dart';
import 'package:prisma_app/core/utils/result.dart';
import 'package:prisma_app/features/providers/models/content_provider_config.dart';
import 'package:prisma_app/core/models/post.dart';
import 'package:prisma_app/features/providers/data/provider_repository.dart';
import 'package:prisma_app/features/settings/domain/settings_service.dart';

class BackupRestoreSummary {
  const BackupRestoreSummary({
    required this.settings,
    this.providersCount = 0,
    this.favoritesCount = 0,
    this.collectionsCount = 0,
    this.mangaEntriesCount = 0,
    this.historyCount = 0,
    this.downloadedMediaCount = 0,
    this.warning,
  });

  final AppSettings settings;
  final int providersCount;
  final int favoritesCount;
  final int collectionsCount;
  final int mangaEntriesCount;
  final int historyCount;
  final int downloadedMediaCount;

  /// Set when some sections could not be restored (e.g. a DB transaction
  /// failed) while others succeeded.
  final String? warning;

  int get totalItemsRestored =>
      providersCount +
      favoritesCount +
      collectionsCount +
      mangaEntriesCount +
      historyCount +
      downloadedMediaCount;
}

class BackupService {
  BackupService(
    this._settingsService, [
    this._databaseService,
    this._providerRepository,
  ]);

  final SettingsService _settingsService;
  final DatabaseService? _databaseService;
  final ProviderRepository? _providerRepository;

  static const String backupFileName = 'prisma_backup.json';
  static const MethodChannel _channel = MethodChannel('rulegel/downloads');

  Timer? _debounceTimer;
  DateTime? lastPersistentBackupAt;
  String? lastPersistentBackupPath;
  String? _lastSavedPayloadDigest;

  /// Schedules a debounced persistent backup (defaults to 5 seconds).
  void scheduleAutoBackup({Duration delay = const Duration(seconds: 5)}) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(delay, () {
      saveAutoBackupToPersistentStorage();
    });
  }

  /// Creates a raw map snapshot of user data for comparison and backup.
  Future<Map<String, dynamic>> createBackupDataMap() async {
    final settingsResult = await _settingsService.getSettings();
    final settings = settingsResult is Success<AppSettings>
        ? settingsResult.data
        : AppSettings.defaults;

    final providersData = <Map<String, dynamic>>[];
    final favoritesData = <Map<String, dynamic>>[];
    final favoritePostsData = <Map<String, dynamic>>[];
    final collectionsData = <Map<String, dynamic>>[];
    final collectionPostsData = <Map<String, dynamic>>[];
    final searchHistoryData = <Map<String, dynamic>>[];
    final mangaLibraryData = <Map<String, dynamic>>[];
    final mangaProgressData = <Map<String, dynamic>>[];
    final viewedHistoryData = <Map<String, dynamic>>[];
    final downloadedMediaData = <Map<String, dynamic>>[];

    final db = _databaseService;
    if (db != null) {
      await db.safeRead((isar) async {
        // 1. Providers / Accounts
        final providerEntities =
            await isar.providerConfigEntitys.where().findAll();
        for (final p in providerEntities) {
          providersData.add(p.toModel().toJson());
        }

        // 2. Favorites
        final favoriteEntities = await isar.favoriteEntitys.where().findAll();
        final favoriteKeys = <String>{};
        for (final f in favoriteEntities) {
          favoriteKeys.add(f.favoriteKey);
          favoritesData.add(f.toModel().toJson());
        }

        // 3. Collections & Collection posts
        final collectionEntities =
            await isar.collectionEntitys.where().findAll();
        for (final c in collectionEntities) {
          collectionsData.add(c.toModel().toJson());
        }

        final collectionPostEntities =
            await isar.collectionPostEntitys.where().findAll();
        final collectionPostKeys = <String>{};
        for (final cp in collectionPostEntities) {
          collectionPostKeys.add('${cp.providerId}:${cp.postId}');
          collectionPostsData.add({
            'linkKey': cp.linkKey,
            'collectionId': cp.collectionId,
            'postId': cp.postId,
            'providerId': cp.providerId,
            'addedAt': cp.addedAt.toIso8601String(),
          });
        }

        // 4. Viewed history (up to 500 recent items)
        final viewedEntities = await isar.viewedPostEntitys
            .where()
            .sortByViewedAtDesc()
            .limit(500)
            .findAll();
        final viewedKeys = <String>{};
        for (final v in viewedEntities) {
          viewedKeys.add(v.viewedKey);
          viewedHistoryData.add({
            'viewedKey': v.viewedKey,
            'providerId': v.providerId,
            'postId': v.postId,
            'viewedAt': v.viewedAt.toIso8601String(),
          });
        }

        // 5. Cached posts needed by favorites, collections & viewed history
        final neededKeys = {
          ...favoriteKeys,
          ...collectionPostKeys,
          ...viewedKeys,
        };
        final cachedPostEntities =
            await isar.cachedPostEntitys.where().findAll();
        for (final cp in cachedPostEntities) {
          if (neededKeys.contains(cp.cacheKey)) {
            favoritePostsData.add(cp.toModel().toJson());
          }
        }

        // 6. Search history
        final searchEntities =
            await isar.searchHistoryEntitys.where().findAll();
        for (final s in searchEntities) {
          searchHistoryData.add(s.toModel().toJson());
        }

        // 7. Manga library
        final mangaEntities =
            await isar.mangaLibraryEntryEntitys.where().findAll();
        for (final m in mangaEntities) {
          mangaLibraryData.add({
            'mangaId': m.mangaId,
            'providerId': m.providerId,
            'title': m.title,
            'coverUrl': m.coverUrl,
            'status': m.status,
            'addedAt': m.addedAt.toIso8601String(),
            'totalChaptersCount': m.totalChaptersCount,
            'newChaptersCount': m.newChaptersCount,
          });
        }

        // 8. Manga reading progress
        final progressEntities =
            await isar.mangaReadingProgressEntitys.where().findAll();
        for (final p in progressEntities) {
          mangaProgressData.add({
            'mangaId': p.mangaId,
            'providerId': p.providerId,
            'title': p.title,
            'coverUrl': p.coverUrl,
            'chapterId': p.chapterId,
            'chapterNumber': p.chapterNumber,
            'pageIndex': p.pageIndex,
            'totalPages': p.totalPages,
            'readChapterIds': p.readChapterIds,
            'updatedAt': p.updatedAt.toIso8601String(),
          });
        }

        // 9. Downloaded offline media
        final downloadedMediaEntities =
            await isar.downloadedMediaEntitys.where().findAll();
        for (final dm in downloadedMediaEntities) {
          downloadedMediaData.add({
            'cacheKey': dm.cacheKey,
            'providerId': dm.providerId,
            'postId': dm.postId,
            'savedPath': dm.savedPath,
            'fileName': dm.fileName,
            'downloadedAt': dm.downloadedAt.toIso8601String(),
            'status': dm.status,
          });
        }
      });
    }

    return {
      'settings': settings.toJson(),
      'providers': providersData,
      'favorites': favoritesData,
      'favoritePosts': favoritePostsData,
      'collections': collectionsData,
      'collectionPosts': collectionPostsData,
      'searchHistory': searchHistoryData,
      'mangaLibrary': mangaLibraryData,
      'mangaProgress': mangaProgressData,
      'viewedHistory': viewedHistoryData,
      'downloadedMedia': downloadedMediaData,
    };
  }

  /// Creates a full JSON snapshot of all user data:
  /// - Settings (UI, themes, blacklist, whitelist, etc.)
  /// - Accounts & Provider configurations (API keys, logins, auth)
  /// - Favorites & their cached post data
  /// - Collections & their posts and cached post data
  /// - Search history
  Future<String> createBackupJson() async {
    final payload = await createBackupDataMap();
    const encoder = JsonEncoder.withIndent('  ');
    return encoder.convert({
      'version': 4,
      'createdAt': DateTime.now().toIso8601String(),
      ...payload,
    });
  }

  /// Restores all user data from a backup JSON string.
  Future<Result<BackupRestoreSummary>> restoreFromJson(String jsonContent) async {
    try {
      final decoded = jsonDecode(jsonContent);
      if (decoded is! Map<String, dynamic>) {
        return const Error(Failure(
          code: 'invalid_json',
          message: 'Invalid JSON file format',
        ));
      }

      // 1. Settings
      final rawSettings = decoded['settings'] is Map<String, dynamic>
          ? decoded['settings'] as Map<String, dynamic>
          : decoded;
      final settings = AppSettings.fromJson(rawSettings);
      await _settingsService.updateSettings(settings);

      var providerCount = 0;
      var favCount = 0;
      var colCount = 0;
      var mangaCount = 0;
      var histCount = 0;
      var dmCount = 0;

      // 2. Database entities — one transaction per section: a failure in a
      // malformed section must not silently zero the whole restore.
      final db = _databaseService;
      Failure? dbFailure;
      if (db != null) {
        Future<void> runSection(
          Future<void> Function(Isar isar) section,
        ) async {
          final result = await db.safeWrite(section);
          if (result is Error) dbFailure ??= result.failure;
        }

        await runSection((isar) async {
          // Providers
          final providersList = decoded['providers'];
          if (providersList is List) {
            final credentialStore = CredentialStore();
            for (final item in providersList) {
              if (item is Map) {
                final model = ContentProviderConfig.fromJson(
                  Map<String, dynamic>.from(item),
                );
                // Route credentials into the secure store so restored
                // configs never persist API keys in the database itself.
                var toPersist = model;
                final secrets =
                    CredentialStore.extractSecrets(model.customHeaders);
                if (secrets.isNotEmpty) {
                  final storedSecurely =
                      await credentialStore.write(model.id, secrets);
                  if (storedSecurely) {
                    toPersist = model.copyWith(
                      customHeaders:
                          CredentialStore.stripSecrets(model.customHeaders),
                    );
                  }
                }
                await isar.providerConfigEntitys
                    .putByProviderId(ProviderConfigEntity.fromModel(toPersist));
                providerCount++;
              }
            }
          }
        });

        await runSection((isar) async {
          // Favorites
          final favoritesList = decoded['favorites'];
          if (favoritesList is List) {
            for (final item in favoritesList) {
              if (item is Map) {
                final fav = Map<String, dynamic>.from(item);
                final key = (fav['id'] ??
                        fav['favoriteKey'] ??
                        '${fav['providerId']}:${fav['postId']}')
                    .toString();
                final entity = FavoriteEntity()
                  ..favoriteKey = key
                  ..favoriteId =
                      (fav['id'] ?? fav['favoriteId'] ?? key).toString()
                  ..postId = (fav['postId'] ?? '').toString()
                  ..providerId = (fav['providerId'] ?? '').toString()
                  ..savedAt =
                      DateTime.tryParse(fav['savedAt']?.toString() ?? '') ??
                          DateTime.now();
                await isar.favoriteEntitys.putByFavoriteKey(entity);
                favCount++;
              }
            }
          }
        });

        await runSection((isar) async {
          // Cached Posts
          final postsList = decoded['favoritePosts'];
          if (postsList is List) {
            for (final item in postsList) {
              if (item is Map) {
                final post = Post.fromJson(Map<String, dynamic>.from(item));
                await isar.cachedPostEntitys
                    .putByCacheKey(CachedPostEntity.fromModel(post));
              }
            }
          }
        });

        await runSection((isar) async {
          // Collections
          final collectionsList = decoded['collections'];
          if (collectionsList is List) {
            for (final item in collectionsList) {
              if (item is Map) {
                final col = Map<String, dynamic>.from(item);
                final colId =
                    (col['id'] ?? col['collectionId'] ?? '').toString();
                final entity = CollectionEntity()
                  ..collectionId = colId
                  ..name = (col['name'] ?? '').toString()
                  ..description = col['description']?.toString()
                  ..coverUrl = col['coverUrl']?.toString()
                  ..createdAt =
                      DateTime.tryParse(col['createdAt']?.toString() ?? '') ??
                          DateTime.now()
                  ..updatedAt =
                      DateTime.tryParse(col['updatedAt']?.toString() ?? '') ??
                          DateTime.now();
                await isar.collectionEntitys.putByCollectionId(entity);
                colCount++;
              }
            }
          }
        });

        await runSection((isar) async {
          // Collection Posts
          final cpList = decoded['collectionPosts'];
          if (cpList is List) {
            for (final item in cpList) {
              if (item is Map) {
                final cp = Map<String, dynamic>.from(item);
                final linkKey = (cp['linkKey'] ??
                        '${cp['collectionId']}:${cp['providerId']}:${cp['postId']}')
                    .toString();
                final entity = CollectionPostEntity()
                  ..linkKey = linkKey
                  ..collectionId = (cp['collectionId'] ?? '').toString()
                  ..postId = (cp['postId'] ?? '').toString()
                  ..providerId = (cp['providerId'] ?? '').toString()
                  ..addedAt =
                      DateTime.tryParse(cp['addedAt']?.toString() ?? '') ??
                          DateTime.now();
                await isar.collectionPostEntitys.putByLinkKey(entity);
              }
            }
          }
        });

        await runSection((isar) async {
          // Search History
          final searchList = decoded['searchHistory'];
          if (searchList is List) {
            for (final item in searchList) {
              if (item is Map) {
                final sh = Map<String, dynamic>.from(item);
                final histId = (sh['id'] ?? sh['historyId'] ?? '').toString();
                final entity = SearchHistoryEntity()
                  ..historyId = histId
                  ..query = (sh['query'] ?? '').toString()
                  ..tags = List<String>.from((sh['tags'] as List?) ?? const [])
                  ..searchedAt =
                      DateTime.tryParse(sh['searchedAt']?.toString() ?? '') ??
                          DateTime.now()
                  ..resultCount = (sh['resultCount'] as num?)?.toInt() ?? 0
                  ..providerId = (sh['providerId'] ?? '').toString()
                  ..providerName = (sh['providerName'] ?? '').toString();
                await isar.searchHistoryEntitys.putByHistoryId(entity);
              }
            }
          }
        });

        await runSection((isar) async {
          // Manga Library
          final mangaList = decoded['mangaLibrary'];
          if (mangaList is List) {
            for (final item in mangaList) {
              if (item is Map) {
                final m = Map<String, dynamic>.from(item);
                final entity = MangaLibraryEntryEntity()
                  ..mangaId = (m['mangaId'] ?? '').toString()
                  ..providerId = (m['providerId'] ?? '').toString()
                  ..title = (m['title'] ?? '').toString()
                  ..coverUrl = (m['coverUrl'] ?? '').toString()
                  ..status = (m['status'] ?? 'reading').toString()
                  ..addedAt =
                      DateTime.tryParse(m['addedAt']?.toString() ?? '') ??
                          DateTime.now()
                  ..totalChaptersCount =
                      (m['totalChaptersCount'] as num?)?.toInt() ?? 0
                  ..newChaptersCount =
                      (m['newChaptersCount'] as num?)?.toInt() ?? 0;
                await isar.mangaLibraryEntryEntitys.putByMangaId(entity);
                mangaCount++;
              }
            }
          }
        });

        await runSection((isar) async {
          // Manga Reading Progress
          final progressList = decoded['mangaProgress'];
          if (progressList is List) {
            for (final item in progressList) {
              if (item is Map) {
                final p = Map<String, dynamic>.from(item);
                final entity = MangaReadingProgressEntity()
                  ..mangaId = (p['mangaId'] ?? '').toString()
                  ..providerId = (p['providerId'] ?? '').toString()
                  ..title = (p['title'] ?? '').toString()
                  ..coverUrl = (p['coverUrl'] ?? '').toString()
                  ..chapterId = (p['chapterId'] ?? '').toString()
                  ..chapterNumber = (p['chapterNumber'] ?? '').toString()
                  ..pageIndex = (p['pageIndex'] as num?)?.toInt() ?? 0
                  ..totalPages = (p['totalPages'] as num?)?.toInt() ?? 0
                  ..readChapterIds = List<String>.from(
                      (p['readChapterIds'] as List?) ?? const [])
                  ..updatedAt =
                      DateTime.tryParse(p['updatedAt']?.toString() ?? '') ??
                          DateTime.now();
                await isar.mangaReadingProgressEntitys.putByMangaId(entity);
              }
            }
          }
        });

        await runSection((isar) async {
          // Viewed History
          final viewedList = decoded['viewedHistory'];
          if (viewedList is List) {
            for (final item in viewedList) {
              if (item is Map) {
                final v = Map<String, dynamic>.from(item);
                final key =
                    (v['viewedKey'] ?? '${v['providerId']}:${v['postId']}')
                        .toString();
                final entity = ViewedPostEntity()
                  ..viewedKey = key
                  ..providerId = (v['providerId'] ?? '').toString()
                  ..postId = (v['postId'] ?? '').toString()
                  ..viewedAt =
                      DateTime.tryParse(v['viewedAt']?.toString() ?? '') ??
                          DateTime.now();
                await isar.viewedPostEntitys.putByViewedKey(entity);
                histCount++;
              }
            }
          }
        });

        await runSection((isar) async {
          // Downloaded Media
          final dmList = decoded['downloadedMedia'];
          if (dmList is List) {
            for (final item in dmList) {
              if (item is Map) {
                final dm = Map<String, dynamic>.from(item);
                final entity = DownloadedMediaEntity()
                  ..cacheKey = (dm['cacheKey'] ?? '').toString()
                  ..providerId = (dm['providerId'] ?? '').toString()
                  ..postId = (dm['postId'] ?? '').toString()
                  ..savedPath = (dm['savedPath'] ?? '').toString()
                  ..fileName = (dm['fileName'] ?? '').toString()
                  ..downloadedAt = DateTime.tryParse(
                          dm['downloadedAt']?.toString() ?? '') ??
                      DateTime.now()
                  ..status = (dm['status'] ?? 'completed').toString();
                await isar.downloadedMediaEntitys.putByCacheKey(entity);
                dmCount++;
              }
            }
          }
        });
      }

      final restoredTotal = providerCount +
          favCount +
          colCount +
          mangaCount +
          histCount +
          dmCount;
      if (dbFailure != null && restoredTotal == 0) {
        return Error(Failure(
          code: 'import_error',
          message: 'Failed to import data: ${dbFailure!.message}',
        ));
      }

      final repo = _providerRepository;
      if (repo != null) {
        await repo.ensureSeedProviders();
      }

      return Success(BackupRestoreSummary(
        settings: settings,
        providersCount: providerCount,
        favoritesCount: favCount,
        collectionsCount: colCount,
        mangaEntriesCount: mangaCount,
        historyCount: histCount,
        downloadedMediaCount: dmCount,
        warning: dbFailure?.message,
      ));
    } catch (e) {
      return Error(Failure(
        code: 'import_error',
        message: 'Failed to import data: $e',
      ));
    }
  }

  /// Resolves candidate persistent directories across platforms.
  Future<List<String>> getCandidateBackupDirectories() async {
    final dirs = <String>[];

    if (Platform.isAndroid) {
      try {
        final ext = await getExternalStorageDirectory();
        if (ext != null) {
          dirs.add('${ext.path}/Prisma');
        }
      } catch (_) {}
    } else if (Platform.isLinux) {
      final home = Platform.environment['HOME'];
      if (home != null && home.isNotEmpty) {
        dirs.add('$home/Documents/Prisma');
        final xdgConfig = Platform.environment['XDG_CONFIG_HOME'];
        dirs.add(xdgConfig != null && xdgConfig.isNotEmpty
            ? '$xdgConfig/Prisma'
            : '$home/.config/Prisma');
      }
    } else if (Platform.isWindows) {
      final userProfile = Platform.environment['USERPROFILE'];
      if (userProfile != null && userProfile.isNotEmpty) {
        dirs.add('$userProfile\\Documents\\Prisma');
      }
      final appData = Platform.environment['APPDATA'];
      if (appData != null && appData.isNotEmpty) {
        dirs.add('$appData\\Prisma');
      }
    } else if (Platform.isMacOS) {
      final home = Platform.environment['HOME'];
      if (home != null && home.isNotEmpty) {
        dirs.add('$home/Documents/Prisma');
        dirs.add('$home/Library/Application Support/Prisma');
      }
    }

    try {
      final appDoc = await getApplicationDocumentsDirectory();
      dirs.add('${appDoc.path}/Prisma');
    } catch (_) {}

    return dirs;
  }

  /// User-content weight of a backup payload: favorites, collections, manga
  /// entries and history. Used to compare snapshots so a fresh install's
  /// empty state can never silently shadow a data-bearing backup.
  int _backupContentWeight(Map<String, dynamic> payload) {
    int len(Object? value) => value is List ? value.length : 0;
    return len(payload['favorites']) +
        len(payload['collections']) +
        len(payload['mangaLibrary']) +
        len(payload['searchHistory']) +
        len(payload['viewedHistory']);
  }

  /// Automatically writes backup JSON snapshot to external persistent storage.
  Future<bool> saveAutoBackupToPersistentStorage({bool force = false}) async {
    try {
      final payload = await createBackupDataMap();
      final payloadJson = jsonEncode(payload);

      // Skip redundant writes if data hasn't changed
      if (!force && payloadJson == _lastSavedPayloadDigest) {
        return true;
      }

      const encoder = JsonEncoder.withIndent('  ');
      final json = encoder.convert({
        'version': 3,
        'createdAt': DateTime.now().toIso8601String(),
        ...payload,
      });

      bool anySaved = false;

      final candidateDirs = await getCandidateBackupDirectories();
      for (final dirPath in candidateDirs) {
        try {
          final dir = Directory(dirPath);
          if (!await dir.exists()) {
            await dir.create(recursive: true);
          }
          final mainFile = File('$dirPath/$backupFileName');
          // Rotate: keep the previous generation alongside the newest one so
          // a degraded (e.g. freshly-installed) state can never destroy the
          // last data-bearing snapshot — it only displaces it.
          if (await mainFile.exists()) {
            final previous = File('$dirPath/prisma_backup_previous.json');
            if (await previous.exists()) {
              await previous.delete();
            }
            try {
              await mainFile.rename(previous.path);
            } catch (_) {}
          }
          await mainFile.writeAsString(json);
          anySaved = true;
          lastPersistentBackupPath = mainFile.path;
        } catch (e, st) {
          AppLogger.log(
              'BackupService: failed to write backup to $dirPath', e, st);
        }
      }

      if (Platform.isAndroid) {
        try {
          await _channel.invokeMethod<String>('savePersistentBackup', {
            'content': json,
            'fileName': backupFileName,
          });
          anySaved = true;
          lastPersistentBackupPath = 'Downloads/Prisma/$backupFileName';
        } catch (e, st) {
          AppLogger.log(
              'BackupService: Android persistent backup failed', e, st);
        }
      }

      if (anySaved) {
        _lastSavedPayloadDigest = payloadJson;
        lastPersistentBackupAt = DateTime.now();
      }
      return anySaved;
    } catch (e, st) {
      AppLogger.log(
          'BackupService.saveAutoBackupToPersistentStorage error', e, st);
      return false;
    }
  }

  /// Reads persistent backup from external persistent storage.
  Future<String?> readPersistentBackup() async {
    try {
      if (Platform.isAndroid) {
        try {
          final content = await _channel.invokeMethod<String>(
            'readPersistentBackup',
            {'fileName': backupFileName},
          );
          if (content != null && content.trim().isNotEmpty) {
            lastPersistentBackupPath = 'Downloads/Prisma/$backupFileName';
            return content;
          }
        } catch (e, st) {
          AppLogger.log(
              'BackupService: native readPersistentBackup error', e, st);
        }
      }

      final candidateDirs = await getCandidateBackupDirectories();
      final candidates = <(String, String, int, DateTime)>[];
      for (final dirPath in candidateDirs) {
        try {
          final dir = Directory(dirPath);
          if (!await dir.exists()) continue;

          final entities = await dir.list().toList();
          final files = entities.whereType<File>().where((f) {
            final name = f.uri.pathSegments.last;
            return name.startsWith('prisma_backup') && name.endsWith('.json');
          }).toList();

          for (final f in files) {
            try {
              final text = await f.readAsString();
              if (text.trim().isEmpty || !text.contains('"version"')) continue;
              DateTime modified =
                  DateTime.fromMillisecondsSinceEpoch(0);
              try {
                modified = await f.lastModified();
              } catch (_) {}
              var weight = 0;
              try {
                final decoded = jsonDecode(text);
                if (decoded is Map<String, dynamic>) {
                  weight = _backupContentWeight(decoded);
                }
              } catch (_) {}
              candidates.add((f.path, text, weight, modified));
            } catch (e, st) {
              AppLogger.log(
                  'BackupService: failed reading candidate file ${f.path}',
                  e,
                  st);
            }
          }
        } catch (e, st) {
          AppLogger.log(
              'BackupService: candidateDir scan error for $dirPath', e, st);
        }
      }

      if (candidates.isNotEmpty) {
        // Prefer the snapshot with the most user content, newest first on
        // ties. A fresh install's empty auto-backup must never shadow the
        // last data-bearing snapshot during auto-restore.
        candidates.sort((a, b) {
          final byWeight = b.$3.compareTo(a.$3);
          if (byWeight != 0) return byWeight;
          return b.$4.compareTo(a.$4);
        });
        lastPersistentBackupPath = candidates.first.$1;
        return candidates.first.$2;
      }
    } catch (e, st) {
      AppLogger.log('BackupService.readPersistentBackup error', e, st);
    }
    return null;
  }

  /// Checks if database is freshly installed or empty, and restores automatically.
  Future<bool> autoRestoreIfNeeded() async {
    final db = _databaseService;
    if (db == null) return false;

    try {
      final hasData = await db.safeRead((isar) async {
        final favCount = await isar.favoriteEntitys.count();
        final colCount = await isar.collectionEntitys.count();
        final mangaCount = await isar.mangaLibraryEntryEntitys.count();
        final viewedCount = await isar.viewedPostEntitys.count();
        return favCount > 0 ||
            colCount > 0 ||
            mangaCount > 0 ||
            viewedCount > 0;
      });

      if (hasData is Success<bool> && hasData.data) {
        // App already has active local user data
        return false;
      }

      // App is freshly installed/reinstalled; look for persistent backup
      final backupJson = await readPersistentBackup();
      if (backupJson != null && backupJson.trim().isNotEmpty) {
        final result = await restoreFromJson(backupJson);
        if (result is Success<BackupRestoreSummary>) {
          AppLogger.log(
              'Prisma: Auto-restored user data from persistent storage!');
          return true;
        }
      }
    } catch (e) {
      AppLogger.error('autoRestoreIfNeeded error', e);
    }
    return false;
  }

  /// Restores explicitly from persistent storage.
  Future<Result<BackupRestoreSummary>> restoreFromPersistentStorage() async {
    final backupJson = await readPersistentBackup();
    if (backupJson == null || backupJson.trim().isEmpty) {
      return const Error(Failure(
        code: 'not_found',
        message: 'Auto-backup file not found',
      ));
    }
    return restoreFromJson(backupJson);
  }

  /// Returns true if a persistent backup file already exists on the device.
  Future<bool> hasPersistentBackup() async {
    final status = await getPersistentBackupStatus();
    if (status['exists'] == true) return true;
    final backup = await readPersistentBackup();
    return backup != null && backup.trim().isNotEmpty;
  }

  /// Returns current status of persistent backup.
  Future<Map<String, dynamic>> getPersistentBackupStatus() async {
    final candidateDirs = await getCandidateBackupDirectories();
    for (final dirPath in candidateDirs) {
      try {
        final dir = Directory(dirPath);
        if (dir.existsSync()) {
          final files = dir.listSync().whereType<File>().where((f) {
            final name = f.uri.pathSegments.last;
            return name.startsWith('prisma_backup') && name.endsWith('.json');
          }).toList();
          if (files.isNotEmpty) {
            files.sort(
                (a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
            final file = files.first;
            final stat = file.statSync();
            return {
              'exists': true,
              'path': file.path,
              'lastModified': stat.modified,
              'fileSize': stat.size,
            };
          }
        }
      } catch (_) {}
    }

    if (lastPersistentBackupAt != null) {
      return {
        'exists': true,
        'path': lastPersistentBackupPath ?? 'Downloads/Prisma/$backupFileName',
        'lastModified': lastPersistentBackupAt,
        'fileSize': null,
      };
    }

    if (Platform.isAndroid) {
      try {
        final content = await _channel.invokeMethod<String>(
          'readPersistentBackup',
          {'fileName': backupFileName},
        );
        if (content != null && content.trim().isNotEmpty) {
          return {
            'exists': true,
            'path':
                lastPersistentBackupPath ?? 'Downloads/Prisma/$backupFileName',
            'lastModified': null,
            'fileSize': content.length,
          };
        }
      } catch (_) {}
    }

    return {
      'exists': false,
      'path': candidateDirs.firstOrNull != null
          ? '${candidateDirs.first}/$backupFileName'
          : 'Downloads/Prisma/$backupFileName',
      'lastModified': null,
      'fileSize': null,
    };
  }

  /// Exports backup to user-selected file or shares it.
  Future<bool> exportBackup() async {
    final json = await createBackupJson();
    final fileName =
        'prisma_backup_${DateTime.now().millisecondsSinceEpoch}.json';

    if (Platform.isAndroid) {
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/$fileName');
      await file.writeAsString(json);
      await Share.shareXFiles([XFile(file.path)], text: 'Prisma Backup');
      // Also ensure auto-backup in persistent storage is updated
      await saveAutoBackupToPersistentStorage();
      return true;
    }

    final location = await getSaveLocation(
      suggestedName: fileName,
      acceptedTypeGroups: [
        const XTypeGroup(label: 'JSON files', extensions: ['json']),
      ],
    );
    if (location == null) return false;
    final file = File(location.path);
    await file.writeAsString(json);
    await saveAutoBackupToPersistentStorage();
    return true;
  }

  /// Imports backup from user-selected file.
  Future<Result<BackupRestoreSummary>?> importBackup() async {
    // No type filter: platform dialogs hide files whose extension does not
    // match (e.g. renamed or extension-less exports). JSON validity is
    // checked by the restore itself.
    final XFile? file;
    try {
      file = await openFile();
    } catch (e) {
      return Error(Failure(
        code: 'file_picker_failed',
        message: 'Could not open the file picker: $e',
      ));
    }
    if (file == null) return null;
    try {
      final content = await file.readAsString();
      final result = await restoreFromJson(content);
      if (result is Success<BackupRestoreSummary>) {
        await saveAutoBackupToPersistentStorage(force: true);
      }
      return result;
    } catch (e) {
      return Error(Failure(
        code: 'import_error',
        message: 'Failed to read the backup file: $e',
      ));
    }
  }
}
