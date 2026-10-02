import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:gel_rule_app/backend/di/backend_providers.dart';
import 'manga_library_service.dart';
import 'manga_offline_service.dart';

final mangaOfflineServiceProvider = Provider<MangaOfflineService>((ref) {
  return MangaOfflineService();
});

final mangaDownloadedChaptersProvider =
    FutureProvider.autoDispose.family<List<String>, String>((ref, mangaId) async {
  final service = ref.watch(mangaOfflineServiceProvider);
  ref.watch(_mangaOfflineChangeProvider);
  return service.getDownloadedChapterIds(mangaId);
});

final _mangaOfflineChangeProvider = StateProvider<int>((ref) {
  final service = ref.watch(mangaOfflineServiceProvider);
  void listener() {
    ref.controller.state = service.changeNotifier.value;
  }
  service.changeNotifier.addListener(listener);
  ref.onDispose(() => service.changeNotifier.removeListener(listener));
  return service.changeNotifier.value;
});

final mangaLibraryServiceProvider = Provider<MangaLibraryService>((ref) {
  final dbService = ref.watch(databaseServiceProvider);
  return MangaLibraryService(dbService);
});

final mangaLibraryEntriesProvider =
    FutureProvider.autoDispose.family<List<MangaLibraryEntry>, String?>((ref, statusFilter) async {
  final service = ref.watch(mangaLibraryServiceProvider);
  // Re-run whenever changeNotifier changes
  ref.watch(_mangaLibraryChangeProvider);
  return service.getLibraryEntries(statusFilter: statusFilter);
});

final mangaReadingHistoryProvider =
    FutureProvider.autoDispose<List<MangaLibraryEntry>>((ref) async {
  final service = ref.watch(mangaLibraryServiceProvider);
  ref.watch(_mangaLibraryChangeProvider);
  return service.getReadingHistory();
});

final mangaProgressProvider =
    FutureProvider.autoDispose.family<MangaReadingProgress?, String>((ref, mangaId) async {
  final service = ref.watch(mangaLibraryServiceProvider);
  ref.watch(_mangaLibraryChangeProvider);
  return service.getProgress(mangaId);
});

final mangaEntryProvider =
    FutureProvider.autoDispose.family<MangaLibraryEntry?, String>((ref, mangaId) async {
  final service = ref.watch(mangaLibraryServiceProvider);
  ref.watch(_mangaLibraryChangeProvider);
  return service.getLibraryEntry(mangaId);
});

final _mangaLibraryChangeProvider = StateProvider<int>((ref) {
  final service = ref.watch(mangaLibraryServiceProvider);
  void listener() {
    ref.controller.state = service.changeNotifier.value;
  }

  service.changeNotifier.addListener(listener);
  ref.onDispose(() => service.changeNotifier.removeListener(listener));
  return service.changeNotifier.value;
});
