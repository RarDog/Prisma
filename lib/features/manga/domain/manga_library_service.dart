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
  MangaLibraryService(this._databaseService);

  final DatabaseService _databaseService;
  static const _kLibraryKey = 'manga_library_entries_v1';
  static const _kProgressKey = 'manga_reading_progress_v1';

  final ValueNotifier<int> changeNotifier = ValueNotifier<int>(0);

  Future<Map<String, MangaLibraryEntry>> _loadEntries() async {
    final result = await _databaseService.safeRead<Map<String, MangaLibraryEntry>>((isar) async {
      final entity = await isar.appSettingEntitys
          .filter()
          .keyEqualTo(_kLibraryKey)
          .findFirst();
      if (entity == null || entity.jsonValue.isEmpty) {
        return <String, MangaLibraryEntry>{};
      }
      try {
        final decoded = jsonDecode(entity.jsonValue);
        if (decoded is List) {
          final map = <String, MangaLibraryEntry>{};
          for (final item in decoded) {
            if (item is Map) {
              final entry = MangaLibraryEntry.fromJson(
                  Map<String, dynamic>.from(item));
              if (entry.mangaId.isNotEmpty) {
                map[entry.mangaId] = entry;
              }
            }
          }
          return map;
        }
      } catch (_) {}
      return <String, MangaLibraryEntry>{};
    });
    return result is Success<Map<String, MangaLibraryEntry>> ? result.data : <String, MangaLibraryEntry>{};
  }

  Future<Map<String, MangaReadingProgress>> _loadProgressMap() async {
    final result = await _databaseService.safeRead<Map<String, MangaReadingProgress>>((isar) async {
      final entity = await isar.appSettingEntitys
          .filter()
          .keyEqualTo(_kProgressKey)
          .findFirst();
      if (entity == null || entity.jsonValue.isEmpty) {
        return <String, MangaReadingProgress>{};
      }
      try {
        final decoded = jsonDecode(entity.jsonValue);
        if (decoded is Map) {
          final map = <String, MangaReadingProgress>{};
          decoded.forEach((key, value) {
            if (value is Map) {
              map[key.toString()] = MangaReadingProgress.fromJson(
                  Map<String, dynamic>.from(value));
            }
          });
          return map;
        }
      } catch (_) {}
      return <String, MangaReadingProgress>{};
    });
    return result is Success<Map<String, MangaReadingProgress>> ? result.data : <String, MangaReadingProgress>{};
  }

  Future<void> _saveEntries(Map<String, MangaLibraryEntry> entries) async {
    final list = entries.values.map((e) => e.toJson()).toList();
    final jsonStr = jsonEncode(list);
    await _databaseService.safeWrite((isar) async {
      final existing = await isar.appSettingEntitys
          .filter()
          .keyEqualTo(_kLibraryKey)
          .findFirst();
      final entity = (existing ?? AppSettingEntity())
        ..key = _kLibraryKey
        ..jsonValue = jsonStr
        ..updatedAt = DateTime.now();
      await isar.appSettingEntitys.put(entity);
    });
    changeNotifier.value++;
  }

  Future<void> _saveProgressMap(Map<String, MangaReadingProgress> progressMap) async {
    final map = progressMap.map((key, val) => MapEntry(key, val.toJson()));
    final jsonStr = jsonEncode(map);
    await _databaseService.safeWrite((isar) async {
      final existing = await isar.appSettingEntitys
          .filter()
          .keyEqualTo(_kProgressKey)
          .findFirst();
      final entity = (existing ?? AppSettingEntity())
        ..key = _kProgressKey
        ..jsonValue = jsonStr
        ..updatedAt = DateTime.now();
      await isar.appSettingEntitys.put(entity);
    });
    changeNotifier.value++;
  }

  Future<List<MangaLibraryEntry>> getLibraryEntries({String? statusFilter}) async {
    final entries = await _loadEntries();
    final progressMap = await _loadProgressMap();

    final result = entries.values.map((e) {
      final prog = progressMap[e.mangaId];
      return e.copyWith(progress: prog);
    }).toList();

    if (statusFilter != null && statusFilter.isNotEmpty) {
      result.retainWhere((e) => e.status == statusFilter);
    }

    result.sort((a, b) {
      final timeA = a.progress?.updatedAt ?? a.addedAt;
      final timeB = b.progress?.updatedAt ?? b.addedAt;
      return timeB.compareTo(timeA);
    });

    return result;
  }

  Future<List<MangaLibraryEntry>> getReadingHistory({int limit = 50}) async {
    final entries = await _loadEntries();
    final progressMap = await _loadProgressMap();

    final list = progressMap.values.map((p) {
      final entry = entries[p.mangaId];
      return MangaLibraryEntry(
        mangaId: p.mangaId,
        providerId: p.providerId,
        title: p.title,
        coverUrl: p.coverUrl,
        status: entry?.status ?? 'reading',
        addedAt: entry?.addedAt ?? p.updatedAt,
        progress: p,
      );
    }).toList();

    list.sort((a, b) {
      final timeA = a.progress?.updatedAt ?? DateTime(1970);
      final timeB = b.progress?.updatedAt ?? DateTime(1970);
      return timeB.compareTo(timeA);
    });

    return list.take(limit).toList();
  }

  Future<MangaReadingProgress?> getProgress(String mangaId) async {
    final map = await _loadProgressMap();
    return map[mangaId];
  }

  Future<MangaLibraryEntry?> getLibraryEntry(String mangaId) async {
    final map = await _loadEntries();
    final entry = map[mangaId];
    if (entry != null) {
      final prog = await getProgress(mangaId);
      return entry.copyWith(progress: prog);
    }
    return null;
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
    final map = await _loadProgressMap();
    final current = map[mangaId];
    final readSet = current != null
        ? Set<String>.from(current.readChapterIds)
        : <String>{};
    if (markChapterComplete && chapterId.isNotEmpty) {
      readSet.add(chapterId);
    }

    map[mangaId] = MangaReadingProgress(
      mangaId: mangaId,
      providerId: providerId,
      title: title.isNotEmpty ? title : (current?.title ?? 'Manga'),
      coverUrl: coverUrl.isNotEmpty ? coverUrl : (current?.coverUrl ?? ''),
      chapterId: chapterId,
      chapterNumber: chapterNumber,
      pageIndex: pageIndex,
      totalPages: totalPages,
      readChapterIds: readSet,
      updatedAt: DateTime.now(),
    );

    await _saveProgressMap(map);
  }

  Future<void> toggleChapterRead({
    required String mangaId,
    required String chapterId,
    required bool isRead,
    String? title,
    String? coverUrl,
    String? providerId,
  }) async {
    final map = await _loadProgressMap();
    final current = map[mangaId];
    final readSet = current != null
        ? Set<String>.from(current.readChapterIds)
        : <String>{};

    if (isRead) {
      readSet.add(chapterId);
    } else {
      readSet.remove(chapterId);
    }

    if (current != null) {
      map[mangaId] = current.copyWith(
        readChapterIds: readSet,
        updatedAt: DateTime.now(),
      );
    } else {
      map[mangaId] = MangaReadingProgress(
        mangaId: mangaId,
        providerId: providerId ?? 'mangadex',
        title: title ?? 'Manga',
        coverUrl: coverUrl ?? '',
        chapterId: chapterId,
        chapterNumber: '',
        pageIndex: 0,
        totalPages: 1,
        readChapterIds: readSet,
        updatedAt: DateTime.now(),
      );
    }

    await _saveProgressMap(map);
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
    required String? status, // null to remove from library
  }) async {
    final entries = await _loadEntries();
    if (status == null || status.isEmpty) {
      entries.remove(mangaId);
    } else {
      final existing = entries[mangaId];
      entries[mangaId] = MangaLibraryEntry(
        mangaId: mangaId,
        providerId: providerId,
        title: title.isNotEmpty ? title : (existing?.title ?? 'Manga'),
        coverUrl: coverUrl.isNotEmpty ? coverUrl : (existing?.coverUrl ?? ''),
        status: status,
        addedAt: existing?.addedAt ?? DateTime.now(),
      );
    }
    await _saveEntries(entries);
  }

  Future<void> removeLibraryEntry(String mangaId) async {
    final entries = await _loadEntries();
    if (entries.containsKey(mangaId)) {
      entries.remove(mangaId);
      await _saveEntries(entries);
    }
  }

  Future<int> checkForUpdates(
    Future<int> Function(String providerId, String mangaId) fetchChapterCount,
  ) async {
    final entries = await _loadEntries();
    int totalNew = 0;
    for (final entry in entries.values) {
      try {
        final count = await fetchChapterCount(entry.providerId, entry.mangaId);
        if (count > entry.totalChaptersCount && entry.totalChaptersCount > 0) {
          final diff = count - entry.totalChaptersCount;
          entries[entry.mangaId] = entry.copyWith(
            newChaptersCount: entry.newChaptersCount + diff,
            totalChaptersCount: count,
          );
          totalNew += diff;
        } else if (entry.totalChaptersCount == 0 && count > 0) {
          entries[entry.mangaId] = entry.copyWith(
            totalChaptersCount: count,
          );
        }
      } catch (_) {}
    }
    if (entries.isNotEmpty) {
      await _saveEntries(entries);
    }
    return totalNew;
  }

  Future<void> resetNewChapters(String mangaId) async {
    final entries = await _loadEntries();
    final entry = entries[mangaId];
    if (entry != null && entry.newChaptersCount > 0) {
      entries[mangaId] = entry.copyWith(newChaptersCount: 0);
      await _saveEntries(entries);
    }
  }
}
