import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Modal bottom sheet for picking a catalog page:
/// 1. Interactive 3D wheel (`ListWheelScrollView`) where you can fling/scroll
///    numbers with your finger.
/// 2. Smooth scrubbing slider for instant multi-page jumps.
/// 3. Quick jump chips (e.g. 1, 10, 50, 100, 110, last).
/// 4. Direct numeric input field.
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
            blurRadius: 20,
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

          // Header
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
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isRu ? 'Выбор страницы' : 'Go to Page',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        widget.totalPages != null
                            ? (isRu
                                ? 'Страница $_selectedPage из $_maxPage'
                                : 'Page $_selectedPage of $_maxPage')
                            : (isRu
                                ? 'Страница $_selectedPage'
                                : 'Page $_selectedPage'),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: isRu ? 'Ввод вручную' : 'Manual entry',
                  icon: Icon(
                    _isManualInput
                        ? Icons.swap_vert_rounded
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
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _textController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      autofocus: true,
                      decoration: InputDecoration(
                        labelText: isRu ? 'Номер страницы' : 'Page number',
                        hintText: '1 - $_maxPage',
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
                ],
              ),
            ),
          ] else ...[
            // 3D Wheel Picker: touch and fling with your finger!
            SizedBox(
              height: 160,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Center selection band highlight
                  Container(
                    height: 44,
                    margin: const EdgeInsets.symmetric(horizontal: 24),
                    decoration: BoxDecoration(
                      color: scheme.primary.withValues(alpha: isDark ? 0.16 : 0.10),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: scheme.primary.withValues(alpha: 0.35),
                      ),
                    ),
                  ),
                  ListWheelScrollView.useDelegate(
                    controller: _wheelController,
                    itemExtent: 44,
                    diameterRatio: 1.35,
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
                            duration: const Duration(milliseconds: 120),
                            style: theme.textTheme.titleLarge!.copyWith(
                              fontWeight: isSelected
                                  ? FontWeight.w800
                                  : FontWeight.w500,
                              fontSize: isSelected ? 24 : 17,
                              color: isSelected
                                  ? scheme.primary
                                  : scheme.onSurfaceVariant
                                      .withValues(alpha: 0.45),
                            ),
                            child: Text(
                              isRu ? 'Стр. $p' : 'Page $p',
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Slider for quick scrubbing across hundreds of pages
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 4,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 9),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 18),
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

          // Quick jump buttons
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _QuickJumpChip(
                    label: isRu ? 'Первая (1)' : 'First (1)',
                    onTap: () => _updatePage(1),
                  ),
                  if (_selectedPage > 10)
                    _QuickJumpChip(
                      label: '-10',
                      onTap: () => _updatePage(_selectedPage - 10),
                    ),
                  if (_selectedPage > 50)
                    _QuickJumpChip(
                      label: '-50',
                      onTap: () => _updatePage(_selectedPage - 50),
                    ),
                  if (_maxPage >= 50 && (_selectedPage - 50).abs() > 10)
                    _QuickJumpChip(
                      label: '50',
                      onTap: () => _updatePage(50),
                    ),
                  if (_maxPage >= 100 && (_selectedPage - 100).abs() > 10)
                    _QuickJumpChip(
                      label: '100',
                      onTap: () => _updatePage(100),
                    ),
                  if (_maxPage >= 110 && (_selectedPage - 110).abs() > 10)
                    _QuickJumpChip(
                      label: '110',
                      onTap: () => _updatePage(110),
                    ),
                  if (_selectedPage + 10 <= _maxPage)
                    _QuickJumpChip(
                      label: '+10',
                      onTap: () => _updatePage(_selectedPage + 10),
                    ),
                  if (_selectedPage + 50 <= _maxPage)
                    _QuickJumpChip(
                      label: '+50',
                      onTap: () => _updatePage(_selectedPage + 50),
                    ),
                  if (_maxPage > 1)
                    _QuickJumpChip(
                      label: isRu ? 'Посл. ($_maxPage)' : 'Last ($_maxPage)',
                      onTap: () => _updatePage(_maxPage),
                    ),
                ],
              ),
            ),
          ),

          // Confirm button
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
            child: SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                onPressed: _confirmSelection,
                child: Text(
                  isRu
                      ? 'Перейти к странице $_selectedPage'
                      : 'Go to page $_selectedPage',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
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
    required this.onTap,
  });

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withValues(alpha: 0.07)
                : Colors.black.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.1)
                  : Colors.black.withValues(alpha: 0.07),
            ),
          ),
          child: Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}
