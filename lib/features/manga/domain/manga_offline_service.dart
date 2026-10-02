import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:gel_rule_app/core/http/app_headers.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import 'package:gel_rule_app/sources/booru/mangadex_provider.dart';

class MangaOfflineService {
  MangaOfflineService({Dio? dio, String? baseDir})
      : _dio = dio ?? Dio(),
        _baseDir = baseDir;

  final Dio _dio;
  final String? _baseDir;
  final ValueNotifier<int> changeNotifier = ValueNotifier<int>(0);

  Future<Directory> _getOfflineDir() async {
    if (_baseDir != null) {
      final dir = Directory('$_baseDir/manga_offline');
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      return dir;
    }
    final appDir = await getApplicationDocumentsDirectory();
    final dir = Directory('${appDir.path}/manga_offline');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<Directory> _getChapterDir(String mangaId, String chapterId) async {
    final root = await _getOfflineDir();
    final cleanMangaId = mangaId.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    final cleanChapterId = chapterId.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    final dir = Directory('${root.path}/$cleanMangaId/$cleanChapterId');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<bool> isChapterDownloaded(String mangaId, String chapterId) async {
    try {
      final dir = await _getChapterDir(mangaId, chapterId);
      final infoFile = File('${dir.path}/info.json');
      return await infoFile.exists();
    } catch (_) {
      return false;
    }
  }

  Future<List<String>> getDownloadedChapterIds(String mangaId) async {
    try {
      final root = await _getOfflineDir();
      final cleanMangaId = mangaId.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
      final mangaDir = Directory('${root.path}/$cleanMangaId');
      if (!await mangaDir.exists()) return [];

      final list = <String>[];
      final entities = await mangaDir.list().toList();
      for (final entity in entities) {
        if (entity is Directory) {
          final infoFile = File('${entity.path}/info.json');
          if (await infoFile.exists()) {
            try {
              final content = await infoFile.readAsString();
              final json = jsonDecode(content);
              final origId = json['chapterId']?.toString() ?? entity.path.split('/').last;
              list.add(origId);
            } catch (_) {
              list.add(entity.path.split('/').last);
            }
          }
        }
      }
      return list;
    } catch (_) {
      return [];
    }
  }

  Future<List<String>> getDownloadedPages(String mangaId, String chapterId) async {
    try {
      final dir = await _getChapterDir(mangaId, chapterId);
      final infoFile = File('${dir.path}/info.json');
      if (!await infoFile.exists()) return [];

      final entities = await dir.list().toList();
      final files = entities
          .whereType<File>()
          .where((f) => !f.path.endsWith('info.json') && !f.path.endsWith('.txt'))
          .map((f) => f.path)
          .toList();

      files.sort((a, b) {
        final aNum = int.tryParse(a.split('/').last.split('.').first) ?? 0;
        final bNum = int.tryParse(b.split('/').last.split('.').first) ?? 0;
        return aNum.compareTo(bNum);
      });

      return files;
    } catch (_) {
      return [];
    }
  }

  Future<String?> getDownloadedNovelContent(String mangaId, String chapterId) async {
    try {
      final dir = await _getChapterDir(mangaId, chapterId);
      final textFile = File('${dir.path}/novel.txt');
      if (await textFile.exists()) {
        return await textFile.readAsString();
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<void> downloadMangaChapter({
    required String mangaId,
    required MangaDexChapter chapter,
    required List<String> pageUrls,
    required String providerId,
    Function(int current, int total)? onProgress,
  }) async {
    final total = pageUrls.length;
    if (total == 0) {
      throw StateError('Cannot download empty chapter');
    }

    final dir = await _getChapterDir(mangaId, chapter.id);
    int completedCount = 0;
    final failedIndices = <int>[];

    // Download concurrently in chunks of 3 for speed and reliability
    const concurrency = 3;
    for (int i = 0; i < total; i += concurrency) {
      final end = (i + concurrency < total) ? i + concurrency : total;
      final chunkIndices = [for (int idx = i; idx < end; idx++) idx];

      await Future.wait(
        chunkIndices.map((idx) async {
          final url = pageUrls[idx];
          final ext = url.contains('.') ? url.split('.').last.split('?').first : 'jpg';
          final savePath = '${dir.path}/$idx.$ext';
          final file = File(savePath);

          // Skip if page was already fully downloaded on previous attempt
          if (await file.exists() && (await file.length()) > 0) {
            completedCount++;
            onProgress?.call(completedCount, total);
            return;
          }

          try {
            await _dio.download(
              url,
              savePath,
              options: Options(
                headers: {
                  'User-Agent': AppHeaders.desktopChromeUserAgent,
                },
              ),
            );
            completedCount++;
            onProgress?.call(completedCount, total);
          } catch (e) {
            debugPrint('Error downloading page $idx ($url): $e');
            failedIndices.add(idx);
          }
        }),
      );
    }

    if (failedIndices.isNotEmpty) {
      throw StateError(
        'Failed to download ${failedIndices.length} of $total pages for chapter ${chapter.chapterNumber}',
      );
    }

    final infoFile = File('${dir.path}/info.json');
    await infoFile.writeAsString(
      jsonEncode({
        'mangaId': mangaId,
        'chapterId': chapter.id,
        'chapterNumber': chapter.chapterNumber,
        'title': chapter.title,
        'providerId': providerId,
        'isNovel': false,
        'pageCount': completedCount,
        'downloadedAt': DateTime.now().toIso8601String(),
      }),
    );

    changeNotifier.value++;
  }

  Future<void> downloadNovelChapter({
    required String mangaId,
    required MangaDexChapter chapter,
    required String content,
    required String providerId,
  }) async {
    final dir = await _getChapterDir(mangaId, chapter.id);

    final textFile = File('${dir.path}/novel.txt');
    await textFile.writeAsString(content);

    final infoFile = File('${dir.path}/info.json');
    await infoFile.writeAsString(
      jsonEncode({
        'mangaId': mangaId,
        'chapterId': chapter.id,
        'chapterNumber': chapter.chapterNumber,
        'title': chapter.title,
        'providerId': providerId,
        'isNovel': true,
        'pageCount': 1,
        'downloadedAt': DateTime.now().toIso8601String(),
      }),
    );

    changeNotifier.value++;
  }

  Future<void> deleteDownloadedChapter(String mangaId, String chapterId) async {
    try {
      final dir = await _getChapterDir(mangaId, chapterId);
      if (await dir.exists()) {
        await dir.delete(recursive: true);
      }
      changeNotifier.value++;
    } catch (_) {}
  }
}
