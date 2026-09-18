import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:isar/isar.dart' hide Collection;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'package:gel_rule_app/core/database/app_database.dart';
import 'package:gel_rule_app/core/database/database_service.dart';
import 'package:gel_rule_app/core/errors/failure.dart';
import 'package:gel_rule_app/core/utils/result.dart';
import 'package:gel_rule_app/features/providers/models/content_provider_config.dart';
import 'package:gel_rule_app/core/models/post.dart';
import 'package:gel_rule_app/features/providers/data/provider_repository.dart';
import 'package:gel_rule_app/features/settings/domain/settings_service.dart';

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
        final favoriteEntities =
            await isar.favoriteEntitys.where().findAll();
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

        // 4. Cached posts needed by favorites & collections
        final neededKeys = {...favoriteKeys, ...collectionPostKeys};
        final cachedPostEntities =
            await isar.cachedPostEntitys.where().findAll();
        for (final cp in cachedPostEntities) {
          if (neededKeys.contains(cp.cacheKey)) {
            favoritePostsData.add(cp.toModel().toJson());
          }
        }

        // 5. Search history
        final searchEntities =
            await isar.searchHistoryEntitys.where().findAll();
        for (final s in searchEntities) {
          searchHistoryData.add(s.toModel().toJson());
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
      'version': 3,
      'createdAt': DateTime.now().toIso8601String(),
      ...payload,
    });
  }

  /// Restores all user data from a backup JSON string.
  Future<Result<AppSettings>> restoreFromJson(String jsonContent) async {
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

      // 2. Database entities
      final db = _databaseService;
      if (db != null) {
        await db.safeWrite((isar) async {
          // Providers
          final providersList = decoded['providers'];
          if (providersList is List) {
            for (final item in providersList) {
              if (item is Map) {
                final model = ContentProviderConfig.fromJson(
                  Map<String, dynamic>.from(item),
                );
                await isar.providerConfigEntitys
                    .put(ProviderConfigEntity.fromModel(model));
              }
            }
          }

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
                  ..favoriteId = (fav['id'] ?? fav['favoriteId'] ?? key).toString()
                  ..postId = (fav['postId'] ?? '').toString()
                  ..providerId = (fav['providerId'] ?? '').toString()
                  ..savedAt = DateTime.tryParse(fav['savedAt']?.toString() ?? '') ??
                      DateTime.now();
                await isar.favoriteEntitys.putByFavoriteKey(entity);
              }
            }
          }

          // Cached Posts
          final postsList = decoded['favoritePosts'];
          if (postsList is List) {
            for (final item in postsList) {
              if (item is Map) {
                final post =
                    Post.fromJson(Map<String, dynamic>.from(item));
                await isar.cachedPostEntitys
                    .putByCacheKey(CachedPostEntity.fromModel(post));
              }
            }
          }

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
                  ..createdAt = DateTime.tryParse(
                          col['createdAt']?.toString() ?? '') ??
                      DateTime.now()
                  ..updatedAt = DateTime.tryParse(
                          col['updatedAt']?.toString() ?? '') ??
                      DateTime.now();
                await isar.collectionEntitys.putByCollectionId(entity);
              }
            }
          }

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
                  ..addedAt = DateTime.tryParse(
                          cp['addedAt']?.toString() ?? '') ??
                      DateTime.now();
                await isar.collectionPostEntitys.putByLinkKey(entity);
              }
            }
          }

          // Search History
          final searchList = decoded['searchHistory'];
          if (searchList is List) {
            for (final item in searchList) {
              if (item is Map) {
                final sh = Map<String, dynamic>.from(item);
                final histId =
                    (sh['id'] ?? sh['historyId'] ?? '').toString();
                final entity = SearchHistoryEntity()
                  ..historyId = histId
                  ..query = (sh['query'] ?? '').toString()
                  ..tags = List<String>.from(
                      (sh['tags'] as List?) ?? const [])
                  ..searchedAt = DateTime.tryParse(
                          sh['searchedAt']?.toString() ?? '') ??
                      DateTime.now()
                  ..resultCount =
                      (sh['resultCount'] as num?)?.toInt() ?? 0;
                await isar.searchHistoryEntitys.putByHistoryId(entity);
              }
            }
          }
        });
      }

      final repo = _providerRepository;
      if (repo != null) {
        await repo.ensureSeedProviders();
      }

      return Success(settings);
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
          if (!dir.existsSync()) {
            dir.createSync(recursive: true);
          }
          final file = File('$dirPath/$backupFileName');
          await file.writeAsString(json);
          anySaved = true;
          lastPersistentBackupPath = file.path;
        } catch (_) {}
      }

      if (Platform.isAndroid) {
        try {
          await _channel.invokeMethod<String>('savePersistentBackup', {
            'content': json,
            'fileName': backupFileName,
          });
          anySaved = true;
          lastPersistentBackupPath = 'Downloads/Prisma/$backupFileName';
        } catch (_) {}
      }

      if (anySaved) {
        _lastSavedPayloadDigest = payloadJson;
        lastPersistentBackupAt = DateTime.now();
      }
      return anySaved;
    } catch (e) {
      debugPrint('saveAutoBackupToPersistentStorage error: $e');
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
        } catch (e) {
          debugPrint('native readPersistentBackup error: $e');
        }
      }

      final candidateDirs = await getCandidateBackupDirectories();
      for (final dirPath in candidateDirs) {
        try {
          final dir = Directory(dirPath);
          if (!dir.existsSync()) continue;

          final files = dir.listSync().whereType<File>().where((f) {
            final name = f.uri.pathSegments.last;
            return name.startsWith('prisma_backup') && name.endsWith('.json');
          }).toList();

          if (files.isNotEmpty) {
            files.sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
            for (final f in files) {
              try {
                final text = await f.readAsString();
                if (text.trim().isNotEmpty && text.contains('"version"')) {
                  lastPersistentBackupPath = f.path;
                  return text;
                }
              } catch (_) {}
            }
          }
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('readPersistentBackup error: $e');
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
        return favCount > 0 || colCount > 0;
      });

      if (hasData is Success<bool> && hasData.data) {
        // App already has active local user data
        return false;
      }

      // App is freshly installed/reinstalled; look for persistent backup
      final backupJson = await readPersistentBackup();
      if (backupJson != null && backupJson.trim().isNotEmpty) {
        final result = await restoreFromJson(backupJson);
        if (result is Success<AppSettings>) {
          debugPrint('Prisma: Auto-restored user data from persistent storage!');
          return true;
        }
      }
    } catch (e) {
      debugPrint('autoRestoreIfNeeded error: $e');
    }
    return false;
  }

  /// Restores explicitly from persistent storage.
  Future<Result<AppSettings>> restoreFromPersistentStorage() async {
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
            files.sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
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
            'path': lastPersistentBackupPath ?? 'Downloads/Prisma/$backupFileName',
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
  Future<Result<AppSettings>?> importBackup() async {
    const typeGroup = XTypeGroup(
      label: 'JSON files',
      extensions: ['json'],
      mimeTypes: ['application/json', 'text/plain', 'text/*', '*/*'],
    );
    final file = await openFile(acceptedTypeGroups: [typeGroup]);
    if (file == null) return null;
    final content = await file.readAsString();
    final result = await restoreFromJson(content);
    if (result is Success<AppSettings>) {
      await saveAutoBackupToPersistentStorage(force: true);
    }
    return result;
  }
}
