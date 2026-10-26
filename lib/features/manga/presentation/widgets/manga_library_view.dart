import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/manga_library_service.dart';
import '../../domain/manga_library_providers.dart';
import 'manga_library_card.dart';

class MangaLibraryView extends ConsumerWidget {
  const MangaLibraryView({
    super.key,
    required this.libraryFilter,
    required this.onFilterSelected,
    required this.checkingUpdates,
    required this.onCheckUpdates,
    required this.onOpenEntry,
    required this.onShowEntryOptions,
  });

  final String libraryFilter;
  final ValueChanged<String> onFilterSelected;
  final bool checkingUpdates;
  final VoidCallback onCheckUpdates;
  final ValueChanged<MangaLibraryEntry> onOpenEntry;
  final ValueChanged<MangaLibraryEntry> onShowEntryOptions;

  Widget _libraryFilterChip({
    required String keyName,
    required String label,
    required IconData icon,
  }) {
    final isSelected = libraryFilter == keyName;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        avatar: Icon(
          icon,
          size: 15,
          color: isSelected ? Colors.white : Colors.white70,
        ),
        label: Text(label),
        selected: isSelected,
        selectedColor: const Color(0xFFFF6740),
        onSelected: (_) {
          HapticFeedback.selectionClick();
          onFilterSelected(keyName);
        },
        visualDensity: VisualDensity.compact,
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isRu = Localizations.maybeLocaleOf(context)?.languageCode == 'ru';

    final AsyncValue<List<MangaLibraryEntry>> entriesAsync =
        libraryFilter == 'history'
            ? ref.watch(mangaReadingHistoryProvider)
            : ref.watch(mangaLibraryEntriesProvider(
                libraryFilter == 'all' ? null : libraryFilter));

    return CustomScrollView(
      // ignore: deprecated_member_use
      cacheExtent: 180.0,
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              16,
              MediaQuery.paddingOf(context).top + 68,
              16,
              10,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Filter pills & sync button
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 38,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          children: [
                            _libraryFilterChip(
                              keyName: 'all',
                              label: isRu ? 'Все сохранённые' : 'All Saved',
                              icon: Icons.bookmarks_rounded,
                            ),
                            _libraryFilterChip(
                              keyName: 'reading',
                              label: isRu ? 'Читаю' : 'Reading',
                              icon: Icons.auto_stories_rounded,
                            ),
                            _libraryFilterChip(
                              keyName: 'plan_to_read',
                              label: isRu ? 'В планах' : 'Plan to read',
                              icon: Icons.bookmark_added_rounded,
                            ),
                            _libraryFilterChip(
                              keyName: 'completed',
                              label: isRu ? 'Прочитано' : 'Completed',
                              icon: Icons.check_circle_outline_rounded,
                            ),
                            _libraryFilterChip(
                              keyName: 'history',
                              label: isRu ? '⏱ История чтения' : '⏱ History',
                              icon: Icons.history_rounded,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filledTonal(
                      onPressed: checkingUpdates ? null : onCheckUpdates,
                      tooltip: isRu
                          ? 'Проверить обновления глав'
                          : 'Check for new chapters',
                      icon: checkingUpdates
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.sync_rounded, size: 20),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        entriesAsync.when(
          loading: () => const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 60),
              child: Center(
                  child: CircularProgressIndicator(color: Color(0xFFFF6740))),
            ),
          ),
          error: (err, _) => SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Ошибка загрузки библиотеки: $err',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.redAccent)),
                    const SizedBox(height: 12),
                    FilledButton.tonalIcon(
                      onPressed: () {
                        if (libraryFilter == 'history') {
                          ref.invalidate(mangaReadingHistoryProvider);
                        } else {
                          ref.invalidate(mangaLibraryEntriesProvider(
                              libraryFilter == 'all' ? null : libraryFilter));
                        }
                      },
                      icon: const Icon(Icons.refresh_rounded, size: 18),
                      label: Text(isRu ? 'Повторить' : 'Retry'),
                    ),
                  ],
                ),
              ),
            ),
          ),
          data: (entries) {
            if (entries.isEmpty) {
              return SliverToBoxAdapter(
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(vertical: 80, horizontal: 24),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(
                          libraryFilter == 'history'
                              ? Icons.history_toggle_off_rounded
                              : Icons.bookmark_border_rounded,
                          size: 64,
                          color: theme.colorScheme.onSurfaceVariant
                              .withValues(alpha: 0.5),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          libraryFilter == 'history'
                              ? (isRu
                                  ? 'История чтения пуста'
                                  : 'Reading history is empty')
                              : (isRu
                                  ? 'В библиотеке пока пусто'
                                  : 'Your library is empty'),
                          style: theme.textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          libraryFilter == 'history'
                              ? (isRu
                                  ? 'Начните читать мангу в каталоге, и она появится здесь!'
                                  : 'Read any manga to see it here!')
                              : (isRu
                                  ? 'Нажмите кнопку закладки на странице манги, чтобы добавить её сюда.'
                                  : 'Bookmark manga from details screen to save it here.'),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: theme.colorScheme.onSurfaceVariant,
                              fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }

            return SliverPadding(
              padding: const EdgeInsets.all(12),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 0.58,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 12,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final entry = entries[index];
                    return RepaintBoundary(
                      child: MangaLibraryCard(
                        entry: entry,
                        onTap: () => onOpenEntry(entry),
                        onLongPress: () => onShowEntryOptions(entry),
                      ),
                    );
                  },
                  childCount: entries.length,
                  addAutomaticKeepAlives: false,
                  addRepaintBoundaries: true,
                ),
              ),
            );
          },
        ),
        SliverToBoxAdapter(
          child: SizedBox(height: MediaQuery.paddingOf(context).bottom + 80),
        ),
      ],
    );
  }
}
