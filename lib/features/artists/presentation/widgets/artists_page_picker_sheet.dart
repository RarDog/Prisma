import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Modal bottom sheet for picking a catalog page:
/// 1. Hero counter badge: large prominent current page display.
/// 2. Interactive 3D wheel with clean numbers and top/bottom fading.
/// 3. Smooth scrubbing slider with min/max page labels.
/// 4. Quick jump chips (-50, -10, +10, +50, 110, last).
/// 5. Direct keyboard input toggle.
/// 6. Primary gradient confirmation button.
class ArtistsPagePickerSheet extends StatefulWidget {
  const ArtistsPagePickerSheet({
    super.key,
    required this.currentPage,
    required this.totalPages,
    required this.isRu,
    required this.onPageSelected,
  });

  final int currentPage;
  final int? totalPages;
  final bool isRu;
  final ValueChanged<int> onPageSelected;

  static Future<void> show(
    BuildContext context, {
    required int currentPage,
    required int? totalPages,
    required bool isRu,
    required ValueChanged<int> onPageSelected,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ArtistsPagePickerSheet(
        currentPage: currentPage,
        totalPages: totalPages,
        isRu: isRu,
        onPageSelected: onPageSelected,
      ),
    );
  }

  @override
  State<ArtistsPagePickerSheet> createState() => _ArtistsPagePickerSheetState();
}

class _ArtistsPagePickerSheetState extends State<ArtistsPagePickerSheet> {
  late int _selectedPage;
  late final int _maxPage;
  late final FixedExtentScrollController _wheelController;
  late final TextEditingController _textController;
  bool _isManualInput = false;

  @override
  void initState() {
    super.initState();
    _maxPage = (widget.totalPages ?? 200).clamp(1, 99999);
    _selectedPage = widget.currentPage.clamp(1, _maxPage);
    _wheelController =
        FixedExtentScrollController(initialItem: _selectedPage - 1);
    _textController = TextEditingController(text: '$_selectedPage');
  }

  @override
  void dispose() {
    _wheelController.dispose();
    _textController.dispose();
    super.dispose();
  }

  void _updatePage(int newPage, {bool animateWheel = true}) {
    final clamped = newPage.clamp(1, _maxPage);
    if (clamped == _selectedPage) return;
    setState(() {
      _selectedPage = clamped;
      _textController.text = '$clamped';
    });
    if (animateWheel && _wheelController.hasClients) {
      _wheelController.animateToItem(
        clamped - 1,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
      );
    }
  }

  void _confirmSelection() {
    Navigator.of(context).pop();
    widget.onPageSelected(_selectedPage);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final isRu = widget.isRu;

    return Container(
      margin: EdgeInsets.only(
        left: 10,
        right: 10,
        bottom: MediaQuery.paddingOf(context).bottom + 10,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF16161A) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.12)
              : Colors.black.withValues(alpha: 0.08),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.6 : 0.15),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          const SizedBox(height: 10),
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.25)
                  : Colors.black.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 12),

          // Header Row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: scheme.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.auto_stories_rounded,
                    color: scheme.primary,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isRu ? 'Переход к странице' : 'Jump to Page',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        widget.totalPages != null
                            ? (isRu
                                ? 'Всего $_maxPage страниц'
                                : '$_maxPage pages total')
                            : (isRu
                                ? 'Выберите страницу'
                                : 'Select a page'),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: isRu ? 'Ввод вручную' : 'Manual entry',
                  icon: Icon(
                    _isManualInput
                        ? Icons.tune_rounded
                        : Icons.edit_outlined,
                    size: 20,
                    color: scheme.primary,
                  ),
                  onPressed: () {
                    setState(() => _isManualInput = !_isManualInput);
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 20),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          const Divider(height: 16),

          if (_isManualInput) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: TextField(
                controller: _textController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                autofocus: true,
                decoration: InputDecoration(
                  labelText: isRu ? 'Номер страницы' : 'Page number',
                  hintText: '1 - $_maxPage',
                  prefixIcon: const Icon(Icons.numbers_rounded),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
                onChanged: (val) {
                  final parsed = int.tryParse(val);
                  if (parsed != null) {
                    _updatePage(parsed, animateWheel: false);
                  }
                },
                onSubmitted: (_) => _confirmSelection(),
              ),
            ),
          ] else ...[
            const SizedBox(height: 4),

            // Hero Page Badge (Selected Page / Total Pages)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 7),
              decoration: BoxDecoration(
                color: scheme.primary.withValues(alpha: isDark ? 0.16 : 0.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: scheme.primary.withValues(alpha: 0.25),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$_selectedPage',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      color: scheme.primary,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '/ $_maxPage',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: scheme.onSurfaceVariant.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // 3D Wheel: numbers only with smooth top/bottom edge fade
            SizedBox(
              height: 140,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Center selection band
                  Container(
                    height: 42,
                    margin: const EdgeInsets.symmetric(horizontal: 36),
                    decoration: BoxDecoration(
                      color: scheme.primary
                          .withValues(alpha: isDark ? 0.14 : 0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: scheme.primary.withValues(alpha: 0.3),
                      ),
                    ),
                  ),

                  // Fading gradient shader over wheel
                  ShaderMask(
                    shaderCallback: (Rect bounds) {
                      return const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black,
                          Colors.black,
                          Colors.transparent,
                        ],
                        stops: [0.0, 0.22, 0.78, 1.0],
                      ).createShader(bounds);
                    },
                    blendMode: BlendMode.dstIn,
                    child: ListWheelScrollView.useDelegate(
                      controller: _wheelController,
                      itemExtent: 40,
                      diameterRatio: 1.4,
                      physics: const FixedExtentScrollPhysics(),
                      perspective: 0.003,
                      onSelectedItemChanged: (index) {
                        final p = index + 1;
                        if (p != _selectedPage) {
                          HapticFeedback.selectionClick();
                          setState(() {
                            _selectedPage = p;
                            _textController.text = '$p';
                          });
                        }
                      },
                      childDelegate: ListWheelChildBuilderDelegate(
                        childCount: _maxPage,
                        builder: (context, index) {
                          final p = index + 1;
                          final isSelected = p == _selectedPage;
                          return Center(
                            child: AnimatedDefaultTextStyle(
                              duration: const Duration(milliseconds: 140),
                              style: theme.textTheme.titleLarge!.copyWith(
                                fontWeight: isSelected
                                    ? FontWeight.w900
                                    : FontWeight.w600,
                                fontSize: isSelected ? 22 : 16,
                                color: isSelected
                                    ? scheme.primary
                                    : scheme.onSurfaceVariant
                                        .withValues(alpha: 0.40),
                              ),
                              child: Text('$p'),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 6),

          // Scrubbing Slider with 1 and Max Page labels
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Text(
                  '1',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurfaceVariant.withValues(alpha: 0.6),
                  ),
                ),
                Expanded(
                  child: SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 4,
                      thumbShape: const RoundSliderThumbShape(
                        enabledThumbRadius: 8,
                      ),
                      overlayShape: const RoundSliderOverlayShape(
                        overlayRadius: 16,
                      ),
                      activeTrackColor: scheme.primary,
                      thumbColor: scheme.primary,
                    ),
                    child: Slider(
                      value: _selectedPage.toDouble(),
                      min: 1,
                      max: _maxPage.toDouble(),
                      divisions: _maxPage > 1 ? _maxPage - 1 : 1,
                      onChanged: (value) {
                        final newPage = value.round();
                        if (newPage != _selectedPage) {
                          setState(() {
                            _selectedPage = newPage;
                            _textController.text = '$newPage';
                          });
                          if (_wheelController.hasClients) {
                            _wheelController.jumpToItem(newPage - 1);
                          }
                        }
                      },
                    ),
                  ),
                ),
                Text(
                  '$_maxPage',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurfaceVariant.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),

          // Quick jump buttons row
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: [
                  _QuickJumpChip(
                    label: isRu ? 'Первая (1)' : 'First (1)',
                    selected: _selectedPage == 1,
                    accent: scheme.primary,
                    isDark: isDark,
                    onTap: () => _updatePage(1),
                  ),
                  if (_selectedPage > 10)
                    _QuickJumpChip(
                      label: '-10',
                      selected: false,
                      accent: scheme.primary,
                      isDark: isDark,
                      onTap: () => _updatePage(_selectedPage - 10),
                    ),
                  if (_selectedPage > 50)
                    _QuickJumpChip(
                      label: '-50',
                      selected: false,
                      accent: scheme.primary,
                      isDark: isDark,
                      onTap: () => _updatePage(_selectedPage - 50),
                    ),
                  if (_maxPage >= 50 && (_selectedPage - 50).abs() > 10)
                    _QuickJumpChip(
                      label: '50',
                      selected: _selectedPage == 50,
                      accent: scheme.primary,
                      isDark: isDark,
                      onTap: () => _updatePage(50),
                    ),
                  if (_maxPage >= 100 && (_selectedPage - 100).abs() > 10)
                    _QuickJumpChip(
                      label: '100',
                      selected: _selectedPage == 100,
                      accent: scheme.primary,
                      isDark: isDark,
                      onTap: () => _updatePage(100),
                    ),
                  if (_maxPage >= 110 && (_selectedPage - 110).abs() > 10)
                    _QuickJumpChip(
                      label: '110',
                      selected: _selectedPage == 110,
                      accent: scheme.primary,
                      isDark: isDark,
                      onTap: () => _updatePage(110),
                    ),
                  if (_selectedPage + 10 <= _maxPage)
                    _QuickJumpChip(
                      label: '+10',
                      selected: false,
                      accent: scheme.primary,
                      isDark: isDark,
                      onTap: () => _updatePage(_selectedPage + 10),
                    ),
                  if (_selectedPage + 50 <= _maxPage)
                    _QuickJumpChip(
                      label: '+50',
                      selected: false,
                      accent: scheme.primary,
                      isDark: isDark,
                      onTap: () => _updatePage(_selectedPage + 50),
                    ),
                  if (_maxPage > 1)
                    _QuickJumpChip(
                      label: isRu ? 'Посл. ($_maxPage)' : 'Last ($_maxPage)',
                      selected: _selectedPage == _maxPage,
                      accent: scheme.primary,
                      isDark: isDark,
                      onTap: () => _updatePage(_maxPage),
                    ),
                ],
              ),
            ),
          ),

          // Primary gradient action button
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: SizedBox(
              width: double.infinity,
              height: 48,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      scheme.primary,
                      scheme.primary.withValues(alpha: 0.85),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: scheme.primary.withValues(alpha: 0.35),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: _confirmSelection,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        isRu
                            ? 'Перейти к странице $_selectedPage'
                            : 'Go to page $_selectedPage',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(
                        Icons.arrow_forward_rounded,
                        color: Colors.white,
                        size: 18,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickJumpChip extends StatelessWidget {
  const _QuickJumpChip({
    required this.label,
    required this.selected,
    required this.accent,
    required this.isDark,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final Color accent;
  final bool isDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: InkWell(
        borderRadius: BorderRadius.circular(11),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
          decoration: BoxDecoration(
            color: selected
                ? accent.withValues(alpha: isDark ? 0.35 : 0.18)
                : (isDark
                    ? Colors.white.withValues(alpha: 0.06)
                    : Colors.black.withValues(alpha: 0.04)),
            borderRadius: BorderRadius.circular(11),
            border: Border.all(
              color: selected
                  ? accent.withValues(alpha: 0.6)
                  : (isDark
                      ? Colors.white.withValues(alpha: 0.1)
                      : Colors.black.withValues(alpha: 0.07)),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
              color: selected
                  ? accent
                  : (isDark ? Colors.white70 : Colors.black87),
            ),
          ),
        ),
      ),
    );
  }
}
