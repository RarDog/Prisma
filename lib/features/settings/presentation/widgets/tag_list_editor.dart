import 'package:flutter/material.dart';

class TagListEditor extends StatefulWidget {
  const TagListEditor({
    required this.title,
    required this.icon,
    required this.accentColor,
    required this.tags,
    required this.onChanged,
    this.helper,
    this.allowSpaces = false,
    this.hintText,
    super.key,
  });

  final String title;
  final IconData icon;
  final Color accentColor;
  final List<String> tags;
  final ValueChanged<List<String>> onChanged;
  final String? helper;
  final bool allowSpaces;
  final String? hintText;

  @override
  State<TagListEditor> createState() => _TagListEditorState();
}

class _TagListEditorState extends State<TagListEditor> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(widget.icon, size: 20, color: widget.accentColor),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                widget.title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: widget.accentColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '${widget.tags.length}',
                style: theme.textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: widget.accentColor,
                ),
              ),
            ),
          ],
        ),
        if (widget.helper != null) ...[
          const SizedBox(height: 6),
          Text(
            widget.helper!,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final tag in widget.tags)
              InputChip(
                label: Text(tag),
                visualDensity: VisualDensity.compact,
                onDeleted: () => widget.onChanged(
                  widget.tags.where((item) => item != tag).toList(),
                ),
              ),
            SizedBox(
              width: 240,
              child: TextField(
                controller: _controller,
                decoration: InputDecoration(
                  isDense: true,
                  hintText: widget.hintText ?? 'Add tag...',
                  prefixIcon: const Icon(Icons.add_rounded, size: 18),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                ),
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _submit(),
              ),
            ),
            IconButton.filledTonal(
              visualDensity: VisualDensity.compact,
              tooltip: 'Add',
              onPressed: _submit,
              icon: const Icon(Icons.check_rounded, size: 18),
            ),
          ],
        ),
      ],
    );
  }

  void _submit() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    final Iterable<String> incoming;
    if (widget.allowSpaces) {
      incoming = text
          .split(',')
          .map((tag) => tag.trim().toLowerCase())
          .where((tag) => tag.isNotEmpty);
    } else {
      incoming = text
          .split(RegExp(r'[\s,]+'))
          .map((tag) => tag.trim().toLowerCase())
          .where((tag) => tag.isNotEmpty);
    }

    final merged = <String>{...widget.tags, ...incoming}.toList()..sort();
    _controller.clear();
    widget.onChanged(merged);
  }
}
