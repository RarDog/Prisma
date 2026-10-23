import 'package:archive/archive.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:gel_rule_app/sources/models/ugoira_metadata.dart';

class _UnpackParams {
  const _UnpackParams(this.zipBytes, this.frames);
  final Uint8List zipBytes;
  final List<UgoiraFrame> frames;
}

List<UgoiraFrame> _unpackIsolateEntry(_UnpackParams params) {
  return UgoiraService.unpackFramesSync(
    zipBytes: params.zipBytes,
    frames: params.frames,
  );
}

class UgoiraService {
  UgoiraService({Dio? dio}) : _dio = dio ?? Dio();

  final Dio _dio;
  final Map<String, List<UgoiraFrame>> _memoryCache = {};
  final Map<String, List<UgoiraFrame>> _postCache = {};
  final Map<String, UgoiraMetadata> _metaCache = {};

  bool isCached(String key) =>
      _memoryCache.containsKey(key) || _postCache.containsKey(key);

  List<UgoiraFrame>? getCached(String key) =>
      _memoryCache[key] ?? _postCache[key];

  List<UgoiraFrame>? getCachedByPostId(String postId) => _postCache[postId];

  void cacheByPostId(String postId, List<UgoiraFrame> frames) {
    _postCache[postId] = frames;
  }

  UgoiraMetadata? getCachedMeta(String postId) => _metaCache[postId];

  void cacheMeta(String postId, UgoiraMetadata meta) {
    _metaCache[postId] = meta;
  }

  /// Synchronously unpacks frames from in-memory zip bytes.
  /// Used directly in unit tests and inside isolates.
  static List<UgoiraFrame> unpackFramesSync({
    required Uint8List zipBytes,
    required List<UgoiraFrame> frames,
  }) {
    final archive = ZipDecoder().decodeBytes(zipBytes);
    final fileMap = <String, Uint8List>{};

    for (final file in archive.files) {
      if (file.isFile) {
        final content = file.content;
        if (content is List<int>) {
          final normalizedName = file.name.split('/').last.split('\\').last.toLowerCase();
          fileMap[normalizedName] = content is Uint8List
              ? content
              : Uint8List.fromList(content);
        }
      }
    }

    final result = <UgoiraFrame>[];
    for (int i = 0; i < frames.length; i++) {
      final f = frames[i];
      final targetName = f.file.split('/').last.split('\\').last.toLowerCase();
      Uint8List? matchedBytes = fileMap[targetName];

      // Fallback: if not matched by exact name, try sequential match if file count matches
      if (matchedBytes == null && i < archive.files.length) {
        final altContent = archive.files[i].content;
        if (altContent is List<int>) {
          matchedBytes = altContent is Uint8List ? altContent : Uint8List.fromList(altContent);
        }
      }

      result.add(f.copyWith(bytes: matchedBytes));
    }

    return result;
  }

  /// Downloads and extracts Ugoira frames in a background isolate.
  Future<List<UgoiraFrame>> loadUgoiraFrames(
    UgoiraMetadata meta, {
    String? postId,
    Map<String, String>? headers,
    void Function(double progress)? onProgress,
    CancelToken? cancelToken,
    int maxRetries = 3,
  }) async {
    final cacheKey = meta.zipUrl;
    if (_memoryCache.containsKey(cacheKey)) {
      final cached = _memoryCache[cacheKey]!;
      if (postId != null && postId.isNotEmpty) {
        _postCache[postId] = cached;
      }
      onProgress?.call(1.0);
      return cached;
    }
    if (postId != null && postId.isNotEmpty && _postCache.containsKey(postId)) {
      final cached = _postCache[postId]!;
      _memoryCache[cacheKey] = cached;
      onProgress?.call(1.0);
      return cached;
    }

    Response<List<int>>? response;
    dynamic lastError;

    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      if (cancelToken?.isCancelled ?? false) {
        throw DioException(
          requestOptions: RequestOptions(path: meta.zipUrl),
          type: DioExceptionType.cancel,
        );
      }
      try {
        response = await _dio.get<List<int>>(
          meta.zipUrl,
          options: Options(
            responseType: ResponseType.bytes,
            headers: headers,
          ),
          cancelToken: cancelToken,
          onReceiveProgress: (received, total) {
            if (total > 0 && onProgress != null) {
              onProgress(received / total);
            }
          },
        );
        if (response.data != null && response.data!.isNotEmpty) {
          break;
        }
      } catch (e) {
        lastError = e;
        if (cancelToken?.isCancelled ?? false) rethrow;
        if (attempt >= maxRetries) rethrow;
        await Future<void>.delayed(Duration(milliseconds: 700 * attempt));
      }
    }

    final rawData = response?.data;
    if (rawData == null || rawData.isEmpty) {
      throw lastError ?? Exception('Empty Ugoira archive received');
    }

    final zipBytes = rawData is Uint8List
        ? rawData
        : Uint8List.fromList(rawData);

    // Unpack in a background isolate to keep UI thread 100% fluid
    final unpacked = await compute(
      _unpackIsolateEntry,
      _UnpackParams(zipBytes, meta.frames),
    );

    _memoryCache[cacheKey] = unpacked;
    if (postId != null && postId.isNotEmpty) {
      _postCache[postId] = unpacked;
    }
    return unpacked;
  }

  void clearCache() {
    _memoryCache.clear();
    _postCache.clear();
    _metaCache.clear();
  }
}
