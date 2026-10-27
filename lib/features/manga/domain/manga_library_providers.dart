import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:gel_rule_app/backend/di/backend_providers.dart';
import 'manga_library_service.dart';
import 'manga_offline_service.dart';

final mangaOfflineServiceProvider = Provider<MangaOfflineService>((ref) {
  return MangaOfflineService();
});

final mangaLibraryServiceProvider = Provider<MangaLibraryService>((ref) {
  final dbService = ref.watch(databaseServiceProvider);
  return MangaLibraryService(
    dbService,
    onDataChanged: () {
      try {
        ref.read(backupServiceProvider).scheduleAutoBackup();
      } catch (_) {}
    },
  );
});

final mangaLibraryEntriesProvider = FutureProvider.autoDispose
    .family<List<MangaLibraryEntry>, String?>((ref, statusFilter) async {
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

final _mangaLibraryChangeProvider = StateProvider<int>((ref) {
  final service = ref.watch(mangaLibraryServiceProvider);
  void listener() {
    ref.controller.state = service.changeNotifier.value;
  }

  service.changeNotifier.addListener(listener);
  ref.onDispose(() => service.changeNotifier.removeListener(listener));
  return service.changeNotifier.value;
});
