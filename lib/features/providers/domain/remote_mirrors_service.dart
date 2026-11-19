import 'dart:convert';
import 'package:dio/dio.dart';

import 'package:gel_rule_app/core/errors/failure.dart';
import 'package:gel_rule_app/core/security/credential_store.dart';
import 'package:gel_rule_app/core/utils/result.dart';
import 'package:gel_rule_app/features/providers/data/provider_repository.dart';
import 'package:gel_rule_app/features/providers/models/content_provider_config.dart';
import 'package:gel_rule_app/features/providers/models/remote_mirrors_config.dart';
import 'package:gel_rule_app/sources/provider_manager.dart';

class RemoteMirrorsService {
  RemoteMirrorsService({
    required Dio dio,
    required ProviderRepository providerRepository,
    required ProviderManager providerManager,
  })  : _dio = dio,
        _providerRepository = providerRepository,
        _providerManager = providerManager;

  final Dio _dio;
  final ProviderRepository _providerRepository;
  final ProviderManager _providerManager;

  static const primaryMirrorsUrl =
      'https://raw.githubusercontent.com/RarDog/Prisma/main/mirrors.json';
  static const fallbackMirrorsUrl =
      'https://raw.githubusercontent.com/Prisma-CI/Prisma-CI/main/mirrors.json';

  DateTime? _lastSyncTime;
  RemoteBroadcastMessage? _cachedBroadcast;

  DateTime? get lastSyncTime => _lastSyncTime;
  RemoteBroadcastMessage? get activeBroadcast =>
      (_cachedBroadcast != null && _cachedBroadcast!.active)
          ? _cachedBroadcast
          : null;

  Future<Result<RemoteMirrorsSyncResult>> syncMirrors({
    bool force = false,
  }) async {
    final now = DateTime.now();
    if (!force &&
        _lastSyncTime != null &&
        now.difference(_lastSyncTime!) < const Duration(hours: 12)) {
      return Success(RemoteMirrorsSyncResult(
        updatedCount: 0,
        broadcast: activeBroadcast,
      ));
    }

    final configResult = await _fetchRemoteConfig();
    if (configResult is! Success<RemoteMirrorsConfig>) {
      return Error(configResult is Error<RemoteMirrorsConfig>
          ? configResult.failure
          : const Failure(
              code: 'remote_mirrors_fetch_failed',
              message: 'Failed to fetch remote mirrors',
            ));
    }

    final config = configResult.data;
    _cachedBroadcast = config.broadcast;

    var updatedCount = 0;

    for (final entry in config.mirrors.entries) {
      final providerId = entry.key;
      final mirror = entry.value;
      if (mirror.baseUrl.trim().isEmpty) continue;

      final existingResult =
          await _providerRepository.getProvider(providerId);
      if (existingResult is! Success<ContentProviderConfig?> ||
          existingResult.data == null) {
        continue;
      }

      final current = existingResult.data!;
      var needsUpdate = false;
      var updated = current;

      final cleanMirrorUrl = mirror.baseUrl.trim();
      if (current.baseUrl.trim() != cleanMirrorUrl) {
        updated = updated.copyWith(baseUrl: cleanMirrorUrl);
        needsUpdate = true;
      }

      if (mirror.customHeaders != null && mirror.customHeaders!.isNotEmpty) {
        final currentHeaders = Map<String, String>.from(current.customHeaders);
        var headersChanged = false;
        for (final h in mirror.customHeaders!.entries) {
          if (CredentialStore.isSecretKey(h.key)) continue;
          if (currentHeaders[h.key] != h.value) {
            currentHeaders[h.key] = h.value;
            headersChanged = true;
          }
        }
        if (headersChanged) {
          updated = updated.copyWith(customHeaders: currentHeaders);
          needsUpdate = true;
        }
      }

      if (needsUpdate) {
        updated = updated.copyWith(updatedAt: now);
        final saveRes = await _providerRepository.saveProvider(updated);
        if (saveRes is Success) {
          updatedCount++;
        }
      }
    }

    _lastSyncTime = now;

    if (updatedCount > 0) {
      // Invalidate provider manager cache so feeds immediately use new endpoints
      _providerManager.invalidateConfigCache();
    }

    return Success(RemoteMirrorsSyncResult(
      updatedCount: updatedCount,
      broadcast: activeBroadcast,
    ));
  }

  Future<Result<RemoteMirrorsConfig>> _fetchRemoteConfig() async {
    const urls = [primaryMirrorsUrl, fallbackMirrorsUrl];

    for (final url in urls) {
      try {
        final response = await _dio.get<dynamic>(
          url,
          options: Options(
            sendTimeout: const Duration(seconds: 6),
            receiveTimeout: const Duration(seconds: 6),
            headers: const {
              'Accept': 'application/json',
              'Cache-Control': 'no-cache',
            },
          ),
        );

        final rawData = response.data;
        final Map<String, dynamic> decoded;
        if (rawData is Map<String, dynamic>) {
          decoded = rawData;
        } else if (rawData is String && rawData.trim().isNotEmpty) {
          final json = jsonDecode(rawData);
          if (json is Map<String, dynamic>) {
            decoded = json;
          } else {
            continue;
          }
        } else {
          continue;
        }

        return Success(RemoteMirrorsConfig.fromJson(decoded));
      } catch (_) {
        // Try fallback url
        continue;
      }
    }

    return const Error(Failure(
      code: 'remote_mirrors_unavailable',
      message: 'Remote mirrors registry is unreachable',
    ));
  }
}
