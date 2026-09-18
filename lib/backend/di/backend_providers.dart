import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:gel_rule_app/core/cache/cache_service.dart';
import 'package:gel_rule_app/core/cache/image_cache_service.dart';
import 'package:gel_rule_app/core/database/app_database.dart';
import 'package:gel_rule_app/core/database/database_service.dart';
import 'package:gel_rule_app/core/http/network_info.dart';
import 'package:gel_rule_app/core/utils/result.dart';
import 'package:gel_rule_app/sources/provider_factory.dart';
import 'package:gel_rule_app/sources/provider_manager.dart';
import 'package:gel_rule_app/features/downloads/models/download_task.dart';
import 'package:gel_rule_app/features/downloads/models/downloaded_media.dart';
import 'package:gel_rule_app/core/models/post.dart';
import 'package:gel_rule_app/features/collections/data/collection_repository.dart';
import 'package:gel_rule_app/features/downloads/data/downloaded_media_repository.dart';
import 'package:gel_rule_app/features/favorites/data/favorite_repository.dart';
import 'package:gel_rule_app/features/feed/data/post_repository.dart';
import 'package:gel_rule_app/features/providers/data/provider_repository.dart';
import 'package:gel_rule_app/features/search/data/search_repository.dart';
import 'package:gel_rule_app/features/viewed/data/viewed_post_repository.dart';
import 'package:gel_rule_app/features/collections/domain/collection_service.dart';
import 'package:gel_rule_app/features/downloads/domain/download_service.dart';
import 'package:gel_rule_app/features/downloads/domain/download_manager_service.dart';
import 'package:gel_rule_app/features/downloads/domain/downloaded_media_service.dart';
import 'package:gel_rule_app/features/favorites/domain/favorite_service.dart';
import 'package:gel_rule_app/features/feed/domain/feed_service.dart';
import 'package:gel_rule_app/features/providers/domain/provider_check_service.dart';
import 'package:gel_rule_app/features/search/domain/search_service.dart';
import 'package:gel_rule_app/features/search/domain/tag_cache_service.dart';
import 'package:gel_rule_app/features/settings/domain/settings_service.dart';
import 'package:gel_rule_app/features/settings/domain/update_service.dart';
import 'package:gel_rule_app/features/viewed/domain/viewed_history_service.dart';
import 'package:gel_rule_app/features/settings/domain/backup_service.dart';
import 'package:gel_rule_app/features/onboarding/domain/onboarding_service.dart';

final shouldShowOnboardingProvider = StateProvider<bool>((ref) => false);

final appDatabaseProvider = FutureProvider<AppDatabase>((ref) async {
  final database = await AppDatabase.open();
  ref.onDispose(database.close);
  try {
    final dbService = DatabaseService(database);
    final settingsService = SettingsService(dbService);
    final providerRepo = ProviderRepository(dbService);
    await providerRepo.ensureSeedProviders();
    final backupService = BackupService(settingsService, dbService, providerRepo);
    await backupService.autoRestoreIfNeeded();

    final onboardingService = OnboardingService(
      settingsService: settingsService,
      backupService: backupService,
      providerRepository: providerRepo,
    );
    final show = await onboardingService.shouldShowOnboarding();
    ref.read(shouldShowOnboardingProvider.notifier).state = show;
  } catch (e) {
    debugPrint('Prisma startup & autoRestore error: $e');
  }
  return database;
});

final databaseServiceProvider = Provider<DatabaseService>((ref) {
  final database = ref.watch(appDatabaseProvider).requireValue;
  return DatabaseService(database);
});

final connectivityProvider = Provider<Connectivity>((ref) => Connectivity());

final networkInfoProvider = Provider<NetworkInfo>((ref) {
  return NetworkInfo(ref.watch(connectivityProvider));
});

final providerFactoryProvider = Provider<ProviderFactory>((ref) {
  return ProviderFactory();
});

final postRepositoryProvider = Provider<PostRepository>((ref) {
  return PostRepository(ref.watch(databaseServiceProvider));
});

final Provider<ProviderRepository> providerRepositoryProvider =
    Provider<ProviderRepository>((ref) {
  return ProviderRepository(
    ref.watch(databaseServiceProvider),
    onDataChanged: () {
      try {
        ref.read(backupServiceProvider).scheduleAutoBackup();
      } catch (_) {}
    },
  );
});

final searchRepositoryProvider = Provider<SearchRepository>((ref) {
  return SearchRepository(ref.watch(databaseServiceProvider));
});

final viewedPostRepositoryProvider = Provider<ViewedPostRepository>((ref) {
  return ViewedPostRepository(ref.watch(databaseServiceProvider));
});

final downloadedMediaRepositoryProvider =
    Provider<DownloadedMediaRepository>((ref) {
  return DownloadedMediaRepository(ref.watch(databaseServiceProvider));
});

final favoriteRepositoryProvider = Provider<FavoriteRepository>((ref) {
  return FavoriteRepository(
    ref.watch(databaseServiceProvider),
    ref.watch(postRepositoryProvider),
    onDataChanged: () {
      try {
        ref.read(backupServiceProvider).scheduleAutoBackup();
      } catch (_) {}
    },
  );
});

final collectionRepositoryProvider = Provider<CollectionRepository>((ref) {
  return CollectionRepository(
    ref.watch(databaseServiceProvider),
    ref.watch(postRepositoryProvider),
    onDataChanged: () {
      try {
        ref.read(backupServiceProvider).scheduleAutoBackup();
      } catch (_) {}
    },
  );
});

final cacheServiceProvider = Provider<CacheService>((ref) {
  return CacheService(ref.watch(databaseServiceProvider));
});

final imageCacheServiceProvider = Provider<ImageCacheService>((ref) {
  return ImageCacheService();
});

final providerManagerProvider = Provider<ProviderManager>((ref) {
  return ProviderManager(
    ref.watch(providerRepositoryProvider),
    ref.watch(providerFactoryProvider),
  );
});

final feedServiceProvider = Provider<FeedService>((ref) {
  return FeedService(
    ref.watch(providerManagerProvider),
    ref.watch(cacheServiceProvider),
    ref.watch(settingsServiceProvider),
    ref.watch(viewedHistoryServiceProvider),
  );
});

final viewedHistoryServiceProvider = Provider<ViewedHistoryService>((ref) {
  return ViewedHistoryService(
    ref.watch(viewedPostRepositoryProvider),
    ref.watch(postRepositoryProvider),
  );
});

final viewedKeysProvider = FutureProvider<Set<String>>((ref) async {
  final result = await ref.watch(viewedHistoryServiceProvider).getViewedKeys();
  return result is Success<Set<String>> ? result.data : <String>{};
});

final tagCacheServiceProvider = Provider<TagCacheService>((ref) {
  final service = TagCacheService();
  unawaited(service.init());
  return service;
});

final searchServiceProvider = Provider<SearchService>((ref) {
  return SearchService(
    ref.watch(searchRepositoryProvider),
    ref.watch(providerManagerProvider),
    ref.watch(tagCacheServiceProvider),
  );
});

final providerCheckServiceProvider = Provider<ProviderCheckService>((ref) {
  return ProviderCheckService(
    ref.watch(providerRepositoryProvider),
    ref.watch(providerFactoryProvider),
    ref.watch(providerManagerProvider),
  );
});

final favoriteServiceProvider = Provider<FavoriteService>((ref) {
  return FavoriteService(
    ref.watch(favoriteRepositoryProvider),
    ref.watch(postRepositoryProvider),
  );
});

final collectionServiceProvider = Provider<CollectionService>((ref) {
  return CollectionService(ref.watch(collectionRepositoryProvider));
});

final Provider<SettingsService> settingsServiceProvider =
    Provider<SettingsService>((ref) {
  return SettingsService(
    ref.watch(databaseServiceProvider),
    providerRepository: ref.watch(providerRepositoryProvider),
    onDataChanged: () {
      try {
        ref.read(backupServiceProvider).scheduleAutoBackup();
      } catch (_) {}
    },
  );
});

final downloadServiceProvider = Provider<DownloadService>((ref) {
  return DownloadService();
});

final downloadedMediaServiceProvider = Provider<DownloadedMediaService>((ref) {
  return DownloadedMediaService(ref.watch(downloadedMediaRepositoryProvider));
});

final downloadManagerServiceProvider = Provider<DownloadManagerService>((ref) {
  return DownloadManagerService(
    ref.watch(downloadServiceProvider),
    downloadedMediaService: ref.watch(downloadedMediaServiceProvider),
    settingsService: ref.watch(settingsServiceProvider),
  );
});

final downloadedMediaByKeysProvider =
    FutureProvider.family<Map<String, DownloadedMedia>, Iterable<String>>(
        (ref, keys) async {
  final result =
      await ref.watch(downloadedMediaServiceProvider).allByKeys(keys);
  return result is Success<Map<String, DownloadedMedia>>
      ? result.data
      : const {};
});

final offlineDiskSizeProvider =
    FutureProvider.family<int, Iterable<DownloadedMedia>>((ref, items) {
  return DownloadedMediaService.totalDiskSizeBytes(items);
});

final downloadedMediaByKeyProvider =
    FutureProvider.family<DownloadedMedia?, String>((ref, cacheKey) async {
  final result =
      await ref.watch(downloadedMediaServiceProvider).getByCacheKey(cacheKey);
  return result is Success<DownloadedMedia?> ? result.data : null;
});

final postMediaHeadersProvider =
    FutureProvider.family<Map<String, String>, Post>((ref, post) async {
  final result = await ref.watch(providerManagerProvider).getMediaHeaders(post);
  return result is Success<Map<String, String>> ? result.data : const {};
});

final downloadTasksProvider = StreamProvider<List<DownloadTask>>((ref) {
  final manager = ref.watch(downloadManagerServiceProvider);
  return manager.stream;
});

final updateServiceProvider = Provider<UpdateService>((ref) {
  return UpdateService(
    Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 12),
        receiveTimeout: const Duration(seconds: 12),
        headers: const {
          'User-Agent': 'Prisma/2.0.1 Flutter local booru browser',
          'Accept': 'application/json',
        },
      ),
    ),
    ref.watch(settingsServiceProvider),
  );
});

final Provider<BackupService> backupServiceProvider =
    Provider<BackupService>((ref) {
  return BackupService(
    ref.watch(settingsServiceProvider),
    ref.watch(databaseServiceProvider),
    ref.watch(providerRepositoryProvider),
  );
});

final Provider<OnboardingService> onboardingServiceProvider =
    Provider<OnboardingService>((ref) {
  return OnboardingService(
    settingsService: ref.watch(settingsServiceProvider),
    backupService: ref.watch(backupServiceProvider),
    providerRepository: ref.watch(providerRepositoryProvider),
  );
});


