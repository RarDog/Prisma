import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:isar/isar.dart';

import 'package:gel_rule_app/core/database/app_database.dart';
import 'package:gel_rule_app/core/database/database_service.dart';
import 'package:gel_rule_app/core/utils/result.dart';

class MangaReadingProgress {
  const MangaReadingProgress({
    required this.mangaId,
    required this.providerId,
    required this.title,
    required this.coverUrl,
    required this.chapterId,
    required this.chapterNumber,
    required this.pageIndex,
    required this.totalPages,
    required this.readChapterIds,
    required this.updatedAt,
  });

  final String mangaId;
  final String providerId;
  final String title;
  final String coverUrl;
  final String chapterId;
  final String chapterNumber;
  final int pageIndex;
  final int totalPages;
  final Set<String> readChapterIds;
  final DateTime updatedAt;

  Map<String, dynamic> toJson() => {
        'mangaId': mangaId,
        'providerId': providerId,
        'title': title,
        'coverUrl': coverUrl,
        'chapterId': chapterId,
        'chapterNumber': chapterNumber,
        'pageIndex': pageIndex,
        'totalPages': totalPages,
        'readChapterIds': readChapterIds.toList(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory MangaReadingProgress.fromJson(Map<String, dynamic> json) {
    return MangaReadingProgress(
      mangaId: json['mangaId']?.toString() ?? '',
      providerId: json['providerId']?.toString() ?? 'mangadex',
      title: json['title']?.toString() ?? '',
      coverUrl: json['coverUrl']?.toString() ?? '',
      chapterId: json['chapterId']?.toString() ?? '',
      chapterNumber: json['chapterNumber']?.toString() ?? '1',
      pageIndex: json['pageIndex'] is int ? json['pageIndex'] as int : 0,
      totalPages: json['totalPages'] is int ? json['totalPages'] as int : 1,
      readChapterIds: (json['readChapterIds'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toSet() ??
          {},
      updatedAt: DateTime.tryParse(json['updatedAt']?.toString() ?? '') ??
          DateTime.now(),
    );
  }

  MangaReadingProgress copyWith({
    String? chapterId,
    String? chapterNumber,
    int? pageIndex,
    int? totalPages,
    Set<String>? readChapterIds,
    DateTime? updatedAt,
  }) {
    return MangaReadingProgress(
      mangaId: mangaId,
      providerId: providerId,
      title: title,
      coverUrl: coverUrl,
      chapterId: chapterId ?? this.chapterId,
      chapterNumber: chapterNumber ?? this.chapterNumber,
      pageIndex: pageIndex ?? this.pageIndex,
      totalPages: totalPages ?? this.totalPages,
      readChapterIds: readChapterIds ?? this.readChapterIds,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class MangaLibraryEntry {
  const MangaLibraryEntry({
    required this.mangaId,
    required this.providerId,
    required this.title,
    required this.coverUrl,
    required this.status, // 'reading', 'plan_to_read', 'completed', 'dropped'
    required this.addedAt,
    this.progress,
    this.totalChaptersCount = 0,
    this.newChaptersCount = 0,
  });

  final String mangaId;
  final String providerId;
  final String title;
  final String coverUrl;
  final String status;
  final DateTime addedAt;
  final MangaReadingProgress? progress;
  final int totalChaptersCount;
  final int newChaptersCount;

  Map<String, dynamic> toJson() => {
        'mangaId': mangaId,
        'providerId': providerId,
        'title': title,
        'coverUrl': coverUrl,
        'status': status,
        'addedAt': addedAt.toIso8601String(),
        'totalChaptersCount': totalChaptersCount,
        'newChaptersCount': newChaptersCount,
        if (progress != null) 'progress': progress!.toJson(),
      };

  factory MangaLibraryEntry.fromJson(Map<String, dynamic> json) {
    return MangaLibraryEntry(
      mangaId: json['mangaId']?.toString() ?? '',
      providerId: json['providerId']?.toString() ?? 'mangadex',
      title: json['title']?.toString() ?? '',
      coverUrl: json['coverUrl']?.toString() ?? '',
      status: json['status']?.toString() ?? 'reading',
      addedAt: DateTime.tryParse(json['addedAt']?.toString() ?? '') ??
          DateTime.now(),
      totalChaptersCount: (json['totalChaptersCount'] as num?)?.toInt() ?? 0,
      newChaptersCount: (json['newChaptersCount'] as num?)?.toInt() ?? 0,
      progress: json['progress'] is Map
          ? MangaReadingProgress.fromJson(
              Map<String, dynamic>.from(json['progress'] as Map))
          : null,
    );
  }

  MangaLibraryEntry copyWith({
    String? status,
    MangaReadingProgress? progress,
    int? totalChaptersCount,
    int? newChaptersCount,
  }) {
    return MangaLibraryEntry(
      mangaId: mangaId,
      providerId: providerId,
      title: title,
      coverUrl: coverUrl,
      status: status ?? this.status,
      addedAt: addedAt,
      progress: progress ?? this.progress,
      totalChaptersCount: totalChaptersCount ?? this.totalChaptersCount,
      newChaptersCount: newChaptersCount ?? this.newChaptersCount,
    );
  }
}

class MangaLibraryService {
  MangaLibraryService(this._databaseService, {this.onDataChanged});

  final DatabaseService _databaseService;
  final void Function()? onDataChanged;
  static const _kLibraryKey = 'manga_library_entries_v1';
  static const _kProgressKey = 'manga_reading_progress_v1';

  final ValueNotifier<int> changeNotifier = ValueNotifier<int>(0);
  bool _migrated = false;

  void _notifyChange() {
    changeNotifier.value++;
    onDataChanged?.call();
  }

  Future<void> _checkMigration() async {
    if (_migrated) return;
    _migrated = true;

    await _databaseService.safeWrite((isar) async {
      final legacyLib = await isar.appSettingEntitys
          .filter()
          .keyEqualTo(_kLibraryKey)
          .findFirst();
      if (legacyLib != null && legacyLib.jsonValue.isNotEmpty) {
        try {
          final decoded = jsonDecode(legacyLib.jsonValue);
          if (decoded is List) {
            final entities = <MangaLibraryEntryEntity>[];
            for (final item in decoded) {
              if (item is Map) {
                final m = MangaLibraryEntry.fromJson(
                    Map<String, dynamic>.from(item));
                if (m.mangaId.isNotEmpty) {
                  entities.add(MangaLibraryEntryEntity()
                    ..mangaId = m.mangaId
                    ..providerId = m.providerId
                    ..title = m.title
                    ..coverUrl = m.coverUrl
                    ..status = m.status
                    ..addedAt = m.addedAt
                    ..totalChaptersCount = m.totalChaptersCount
                    ..newChaptersCount = m.newChaptersCount);
                }
              }
            }
            if (entities.isNotEmpty) {
              await isar.mangaLibraryEntryEntitys.putAll(entities);
            }
          }
        } catch (_) {}
        await isar.appSettingEntitys.delete(legacyLib.isarId);
      }

      final legacyProg = await isar.appSettingEntitys
          .filter()
          .keyEqualTo(_kProgressKey)
          .findFirst();
      if (legacyProg != null && legacyProg.jsonValue.isNotEmpty) {
        try {
          final decoded = jsonDecode(legacyProg.jsonValue);
          if (decoded is Map) {
            final entities = <MangaReadingProgressEntity>[];
            decoded.forEach((key, val) {
              if (val is Map) {
                final p = MangaReadingProgress.fromJson(
                    Map<String, dynamic>.from(val));
                if (p.mangaId.isNotEmpty) {
                  entities.add(MangaReadingProgressEntity()
                    ..mangaId = p.mangaId
                    ..providerId = p.providerId
                    ..title = p.title
                    ..coverUrl = p.coverUrl
                    ..chapterId = p.chapterId
                    ..chapterNumber = p.chapterNumber
                    ..pageIndex = p.pageIndex
                    ..totalPages = p.totalPages
                    ..readChapterIds = p.readChapterIds.toList()
                    ..updatedAt = p.updatedAt);
                }
              }
            });
            if (entities.isNotEmpty) {
              await isar.mangaReadingProgressEntitys.putAll(entities);
            }
          }
        } catch (_) {}
        await isar.appSettingEntitys.delete(legacyProg.isarId);
      }
    });
  }

  Future<List<MangaLibraryEntry>> getLibraryEntries({String? statusFilter}) async {
    await _checkMigration();
    final result = await _databaseService.safeRead<List<MangaLibraryEntry>>((isar) async {
      List<MangaLibraryEntryEntity> entities;
      if (statusFilter != null && statusFilter.isNotEmpty) {
        entities = await isar.mangaLibraryEntryEntitys
            .filter()
            .statusEqualTo(statusFilter)
            .findAll();
      } else {
        entities = await isar.mangaLibraryEntryEntitys.where().findAll();
      }

      final progresses = await isar.mangaReadingProgressEntitys.where().findAll();
      final progressMap = <String, MangaReadingProgress>{};
      for (final p in progresses) {
        progressMap[p.mangaId] = MangaReadingProgress(
          mangaId: p.mangaId,
          providerId: p.providerId,
          title: p.title,
          coverUrl: p.coverUrl,
          chapterId: p.chapterId,
          chapterNumber: p.chapterNumber,
          pageIndex: p.pageIndex,
          totalPages: p.totalPages,
          readChapterIds: p.readChapterIds.toSet(),
          updatedAt: p.updatedAt,
        );
      }

      final list = entities.map((e) {
        return MangaLibraryEntry(
          mangaId: e.mangaId,
          providerId: e.providerId,
          title: e.title,
          coverUrl: e.coverUrl,
          status: e.status,
          addedAt: e.addedAt,
          totalChaptersCount: e.totalChaptersCount,
          newChaptersCount: e.newChaptersCount,
          progress: progressMap[e.mangaId],
        );
      }).toList();

      list.sort((a, b) {
        final timeA = a.progress?.updatedAt ?? a.addedAt;
        final timeB = b.progress?.updatedAt ?? b.addedAt;
        return timeB.compareTo(timeA);
      });

      return list;
    });

    return result is Success<List<MangaLibraryEntry>> ? result.data : <MangaLibraryEntry>[];
  }

  Future<List<MangaLibraryEntry>> getReadingHistory({int limit = 50}) async {
    await _checkMigration();
    final result = await _databaseService.safeRead<List<MangaLibraryEntry>>((isar) async {
      final progresses = await isar.mangaReadingProgressEntitys
          .where()
          .sortByUpdatedAtDesc()
          .limit(limit)
          .findAll();

      final entries = await isar.mangaLibraryEntryEntitys.where().findAll();
      final entryMap = {for (final e in entries) e.mangaId: e};

      return progresses.map((p) {
        final entry = entryMap[p.mangaId];
        final prog = MangaReadingProgress(
          mangaId: p.mangaId,
          providerId: p.providerId,
          title: p.title,
          coverUrl: p.coverUrl,
          chapterId: p.chapterId,
          chapterNumber: p.chapterNumber,
          pageIndex: p.pageIndex,
          totalPages: p.totalPages,
          readChapterIds: p.readChapterIds.toSet(),
          updatedAt: p.updatedAt,
        );

        return MangaLibraryEntry(
          mangaId: p.mangaId,
          providerId: p.providerId,
          title: p.title,
          coverUrl: p.coverUrl,
          status: entry?.status ?? 'reading',
          addedAt: entry?.addedAt ?? p.updatedAt,
          progress: prog,
        );
      }).toList();
    });

    return result is Success<List<MangaLibraryEntry>> ? result.data : <MangaLibraryEntry>[];
  }

  Future<MangaReadingProgress?> getProgress(String mangaId) async {
    await _checkMigration();
    final result = await _databaseService.safeRead<MangaReadingProgress?>((isar) async {
      final p = await isar.mangaReadingProgressEntitys
          .filter()
          .mangaIdEqualTo(mangaId)
          .findFirst();
      if (p == null) return null;
      return MangaReadingProgress(
        mangaId: p.mangaId,
        providerId: p.providerId,
        title: p.title,
        coverUrl: p.coverUrl,
        chapterId: p.chapterId,
        chapterNumber: p.chapterNumber,
        pageIndex: p.pageIndex,
        totalPages: p.totalPages,
        readChapterIds: p.readChapterIds.toSet(),
        updatedAt: p.updatedAt,
      );
    });

    return result is Success<MangaReadingProgress?> ? result.data : null;
  }

  Future<MangaLibraryEntry?> getLibraryEntry(String mangaId) async {
    await _checkMigration();
    final result = await _databaseService.safeRead<MangaLibraryEntry?>((isar) async {
      final e = await isar.mangaLibraryEntryEntitys
          .filter()
          .mangaIdEqualTo(mangaId)
          .findFirst();
      if (e == null) return null;

      final p = await isar.mangaReadingProgressEntitys
          .filter()
          .mangaIdEqualTo(mangaId)
          .findFirst();

      final prog = p != null
          ? MangaReadingProgress(
              mangaId: p.mangaId,
              providerId: p.providerId,
              title: p.title,
              coverUrl: p.coverUrl,
              chapterId: p.chapterId,
              chapterNumber: p.chapterNumber,
              pageIndex: p.pageIndex,
              totalPages: p.totalPages,
              readChapterIds: p.readChapterIds.toSet(),
              updatedAt: p.updatedAt,
            )
          : null;

      return MangaLibraryEntry(
        mangaId: e.mangaId,
        providerId: e.providerId,
        title: e.title,
        coverUrl: e.coverUrl,
        status: e.status,
        addedAt: e.addedAt,
        totalChaptersCount: e.totalChaptersCount,
        newChaptersCount: e.newChaptersCount,
        progress: prog,
      );
    });

    return result is Success<MangaLibraryEntry?> ? result.data : null;
  }

  Future<void> saveProgress({
    required String mangaId,
    required String providerId,
    required String title,
    required String coverUrl,
    required String chapterId,
    required String chapterNumber,
    required int pageIndex,
    required int totalPages,
    bool markChapterComplete = false,
  }) async {
    await _checkMigration();
    await _databaseService.safeWrite((isar) async {
      final existing = await isar.mangaReadingProgressEntitys
          .filter()
          .mangaIdEqualTo(mangaId)
          .findFirst();

      final readSet = existing != null
          ? Set<String>.from(existing.readChapterIds)
          : <String>{};
      if (markChapterComplete && chapterId.isNotEmpty) {
        readSet.add(chapterId);
      }

      final entity = (existing ?? MangaReadingProgressEntity())
        ..mangaId = mangaId
        ..providerId = providerId
        ..title = title.isNotEmpty ? title : (existing?.title ?? 'Manga')
        ..coverUrl = coverUrl.isNotEmpty ? coverUrl : (existing?.coverUrl ?? '')
        ..chapterId = chapterId
        ..chapterNumber = chapterNumber
        ..pageIndex = pageIndex
        ..totalPages = totalPages
        ..readChapterIds = readSet.toList()
        ..updatedAt = DateTime.now();

      await isar.mangaReadingProgressEntitys.put(entity);
    });

    _notifyChange();
  }

  Future<void> toggleChapterRead({
    required String mangaId,
    required String chapterId,
    required bool isRead,
    String? title,
    String? coverUrl,
    String? providerId,
  }) async {
    await _checkMigration();
    await _databaseService.safeWrite((isar) async {
      final existing = await isar.mangaReadingProgressEntitys
          .filter()
          .mangaIdEqualTo(mangaId)
          .findFirst();

      final readSet = existing != null
          ? Set<String>.from(existing.readChapterIds)
          : <String>{};

      if (isRead) {
        readSet.add(chapterId);
      } else {
        readSet.remove(chapterId);
      }

      final entity = (existing ?? MangaReadingProgressEntity())
        ..mangaId = mangaId
        ..providerId = providerId ?? existing?.providerId ?? 'mangadex'
        ..title = title ?? existing?.title ?? 'Manga'
        ..coverUrl = coverUrl ?? existing?.coverUrl ?? ''
        ..chapterId = existing?.chapterId ?? chapterId
        ..chapterNumber = existing?.chapterNumber ?? ''
        ..pageIndex = existing?.pageIndex ?? 0
        ..totalPages = existing?.totalPages ?? 1
        ..readChapterIds = readSet.toList()
        ..updatedAt = DateTime.now();

      await isar.mangaReadingProgressEntitys.put(entity);
    });

    _notifyChange();
  }

  Future<bool> isChapterRead(String mangaId, String chapterId) async {
    final prog = await getProgress(mangaId);
    return prog?.readChapterIds.contains(chapterId) ?? false;
  }

  Future<void> setLibraryStatus({
    required String mangaId,
    required String providerId,
    required String title,
    required String coverUrl,
    required String? status,
  }) async {
    await _checkMigration();
    await _databaseService.safeWrite((isar) async {
      final existing = await isar.mangaLibraryEntryEntitys
          .filter()
          .mangaIdEqualTo(mangaId)
          .findFirst();

      if (status == null || status.isEmpty) {
        if (existing != null) {
          await isar.mangaLibraryEntryEntitys.delete(existing.isarId);
        }
      } else {
        final entity = (existing ?? MangaLibraryEntryEntity())
          ..mangaId = mangaId
          ..providerId = providerId
          ..title = title.isNotEmpty ? title : (existing?.title ?? 'Manga')
          ..coverUrl = coverUrl.isNotEmpty ? coverUrl : (existing?.coverUrl ?? '')
          ..status = status
          ..addedAt = existing?.addedAt ?? DateTime.now()
          ..totalChaptersCount = existing?.totalChaptersCount ?? 0
          ..newChaptersCount = existing?.newChaptersCount ?? 0;

        await isar.mangaLibraryEntryEntitys.put(entity);
      }
    });

    _notifyChange();
  }

  Future<void> removeLibraryEntry(String mangaId) async {
    await _checkMigration();
    await _databaseService.safeWrite((isar) async {
      final existing = await isar.mangaLibraryEntryEntitys
          .filter()
          .mangaIdEqualTo(mangaId)
          .findFirst();
      if (existing != null) {
        await isar.mangaLibraryEntryEntitys.delete(existing.isarId);
      }
    });

    _notifyChange();
  }

  Future<int> checkForUpdates(
    Future<int> Function(String providerId, String mangaId) fetchChapterCount,
  ) async {
    final entries = await getLibraryEntries();
    int totalNew = 0;
    for (final entry in entries) {
      try {
        final count = await fetchChapterCount(entry.providerId, entry.mangaId);
        if (count > entry.totalChaptersCount && entry.totalChaptersCount > 0) {
          final diff = count - entry.totalChaptersCount;
          totalNew += diff;
          await _databaseService.safeWrite((isar) async {
            final e = await isar.mangaLibraryEntryEntitys
                .filter()
                .mangaIdEqualTo(entry.mangaId)
                .findFirst();
            if (e != null) {
              e.totalChaptersCount = count;
              e.newChaptersCount = diff;
              await isar.mangaLibraryEntryEntitys.put(e);
            }
          });
        } else if (count > 0 && entry.totalChaptersCount == 0) {
          await _databaseService.safeWrite((isar) async {
            final e = await isar.mangaLibraryEntryEntitys
                .filter()
                .mangaIdEqualTo(entry.mangaId)
                .findFirst();
            if (e != null) {
              e.totalChaptersCount = count;
              await isar.mangaLibraryEntryEntitys.put(e);
            }
          });
        }
      } catch (_) {}
    }
    if (totalNew > 0) _notifyChange();
    return totalNew;
  }

  Future<void> resetNewChapters(String mangaId) async {
    await _databaseService.safeWrite((isar) async {
      final e = await isar.mangaLibraryEntryEntitys
          .filter()
          .mangaIdEqualTo(mangaId)
          .findFirst();
      if (e != null && e.newChaptersCount > 0) {
        e.newChaptersCount = 0;
        await isar.mangaLibraryEntryEntitys.put(e);
      }
    });
    _notifyChange();
  }
}
