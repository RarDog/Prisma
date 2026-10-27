import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:gel_rule_app/core/utils/result.dart';
import 'package:gel_rule_app/features/downloads/models/downloaded_media.dart';
import 'package:gel_rule_app/core/models/post.dart';
import 'package:gel_rule_app/features/downloads/data/downloaded_media_repository.dart';

class DownloadedMediaService {
  DownloadedMediaService(this._repository);

  final DownloadedMediaRepository _repository;

  /// Bumped whenever the downloaded-media table changes, so FutureProviders
  /// reading it can re-run (the offline favorites tab resolves its posts
  /// through this table).
  final ValueNotifier<int> changeNotifier = ValueNotifier<int>(0);

  void _notify() => changeNotifier.value++;

  Future<Result<void>> markDownloaded(
    Post post, {
    required String savedPath,
    required String fileName,
  }) async {
    final result = await _repository.markDownloaded(
      post,
      savedPath: savedPath,
      fileName: fileName,
    );
    if (result is Success<void>) _notify();
    return result;
  }

  Future<Result<DownloadedMedia?>> getByCacheKey(String cacheKey) {
    return _repository.getByCacheKey(cacheKey);
  }

  Future<Result<Map<String, DownloadedMedia>>> allByKeys(
    Iterable<String> cacheKeys,
  ) {
    return _repository.allByKeys(cacheKeys);
  }

  Future<Result<void>> deleteLocalFile(String cacheKey) async {
    final result = await getByCacheKey(cacheKey);
    if (result is Error<DownloadedMedia?>) return Error(result.failure);
    final media = (result as Success<DownloadedMedia?>).data;
    if (media != null && media.savedPath.isNotEmpty) {
      final file = File(media.savedPath);
      if (await file.exists()) {
        await file.delete();
      }
    }
    final deleted = await _repository.deleteRecord(cacheKey);
    if (deleted is Success<void>) _notify();
    return deleted;
  }

  Future<Result<void>> clearMissingFiles() => _repository.clearMissingFiles();

  Future<Result<int>> count() => _repository.count();

  static int getFileSizeSync(DownloadedMedia media) {
    if (media.savedPath.isEmpty) return 0;
    final file = File(media.savedPath);
    if (!file.existsSync()) return 0;
    try {
      return file.lengthSync();
    } catch (_) {
      return 0;
    }
  }

  static Future<int> totalDiskSizeBytes(Iterable<DownloadedMedia> items) async {
    int total = 0;
    for (final media in items) {
      if (media.savedPath.isNotEmpty) {
        final file = File(media.savedPath);
        if (await file.exists()) {
          try {
            total += await file.length();
          } catch (_) {}
        }
      }
    }
    return total;
  }

  static String formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }
}
