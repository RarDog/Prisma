import 'package:flutter/material.dart';
import 'manga_reader_types.dart';

Future<void> showMangaReaderSettingsSheet({
  required BuildContext context,
  required MangaReaderMode currentMode,
  required ValueChanged<MangaReaderMode> onModeChanged,
  required MangaReaderTheme currentTheme,
  required ValueChanged<MangaReaderTheme> onThemeChanged,
  required bool volumeNavigationEnabled,
  required ValueChanged<bool> onVolumeNavigationChanged,
  required bool invertVolumeKeys,
  required ValueChanged<bool> onInvertVolumeKeysChanged,
  required bool hasChapters,
  required VoidCallback onOpenChapterPicker,
}) async {
  final isRu = Localizations.maybeLocaleOf(context)?.languageCode == 'ru';

  var mode = currentMode;
  var theme = currentTheme;
  var volumeEnabled = volumeNavigationEnabled;
  var invertVolume = invertVolumeKeys;

  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: const Color(0xFF1E1E24),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setSheetState) {
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.tune_rounded,
                          color: Color(0xFFFF6740), size: 22),
                      const SizedBox(width: 10),
                      Text(
                        isRu ? 'Настройки чтения' : 'Reader Settings',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Reading Mode Segmented
                  Text(
                    isRu ? 'Режим чтения' : 'Reading Mode',
                    style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                        fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  SegmentedButton<MangaReaderMode>(
                    segments: [
                      ButtonSegment(
                        value: MangaReaderMode.pagedRtl,
                        label: Text(isRu ? 'Манга (RTL)' : 'RTL Manga'),
                        icon: const Icon(
                            Icons.format_textdirection_r_to_l_rounded,
                            size: 16),
                      ),
                      ButtonSegment(
                        value: MangaReaderMode.pagedLtr,
                        label: Text(isRu ? 'Комиксы' : 'LTR Comic'),
                        icon: const Icon(
                            Icons.format_textdirection_l_to_r_rounded,
                            size: 16),
                      ),
                      ButtonSegment(
                        value: MangaReaderMode.webtoon,
                        label: Text(isRu ? 'Webtoon' : 'Webtoon'),
                        icon: const Icon(Icons.view_headline_rounded, size: 16),
                      ),
                    ],
                    selected: {mode},
                    onSelectionChanged: (newVal) {
                      final selected = newVal.first;
                      setSheetState(() => mode = selected);
                      onModeChanged(selected);
                    },
                    style: ButtonStyle(
                      foregroundColor: WidgetStateProperty.resolveWith(
                        (states) => states.contains(WidgetState.selected)
                            ? Colors.black
                            : Colors.white70,
                      ),
                      backgroundColor: WidgetStateProperty.resolveWith(
                        (states) => states.contains(WidgetState.selected)
                            ? const Color(0xFFFF6740)
                            : Colors.white10,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Background Theme
                  Text(
                    isRu ? 'Цвет фона' : 'Background Theme',
                    style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                        fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: MangaReaderTheme.values.map((item) {
                      final isSelected = theme == item;
                      return Expanded(
                        child: GestureDetector(
                          onTap: () {
                            setSheetState(() => theme = item);
                            onThemeChanged(item);
                          },
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: item.backgroundColor,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isSelected
                                    ? const Color(0xFFFF6740)
                                    : Colors.white24,
                                width: isSelected ? 2 : 1,
                              ),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (isSelected)
                                  const Icon(Icons.check_circle_rounded,
                                      color: Color(0xFFFF6740), size: 16)
                                else
                                  const SizedBox(height: 16),
                                const SizedBox(height: 4),
                                Text(
                                  isRu ? item.labelRu : item.labelEn,
                                  style: TextStyle(
                                    color: item == MangaReaderTheme.white
                                        ? Colors.black87
                                        : Colors.white70,
                                    fontSize: 11,
                                    fontWeight: isSelected
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),

                  // Volume Navigation Options
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: Column(
                      children: [
                        SwitchListTile.adaptive(
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 0),
                          dense: true,
                          activeTrackColor: const Color(0xFFFF6740),
                          secondary: const Icon(Icons.volume_up_rounded,
                              color: Color(0xFFFF6740), size: 22),
                          title: Text(
                            isRu ? 'Кнопки громкости' : 'Volume key navigation',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(
                            isRu
                                ? (invertVolume
                                    ? 'Вверх — след., Вниз — пред.'
                                    : 'Вниз — след., Вверх — пред.')
                                : (invertVolume
                                    ? 'Up = next, Down = prev'
                                    : 'Down = next, Up = prev'),
                            style: const TextStyle(
                                color: Colors.white54, fontSize: 11),
                          ),
                          value: volumeEnabled,
                          onChanged: (val) {
                            setSheetState(() => volumeEnabled = val);
                            onVolumeNavigationChanged(val);
                          },
                        ),
                        if (volumeEnabled) ...[
                          const Divider(
                              height: 1, indent: 48, color: Colors.white10),
                          SwitchListTile.adaptive(
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 0),
                            dense: true,
                            activeTrackColor: const Color(0xFFFF6740),
                            secondary: const Icon(Icons.swap_vert_rounded,
                                color: Colors.white70, size: 20),
                            title: Text(
                              isRu
                                  ? 'Инвертировать кнопки'
                                  : 'Invert volume buttons',
                              style: const TextStyle(
                                  color: Colors.white70, fontSize: 13),
                            ),
                            value: invertVolume,
                            onChanged: (val) {
                              setSheetState(() => invertVolume = val);
                              onInvertVolumeKeysChanged(val);
                            },
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Quick Chapter Switch Button
                  if (hasChapters)
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white24),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.format_list_bulleted_rounded,
                          size: 18),
                      label: Text(
                        isRu ? 'Выбрать другую главу' : 'Switch Chapter',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      onPressed: () {
                        Navigator.of(context).pop();
                        onOpenChapterPicker();
                      },
                    ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}
