import 'dart:async';

import 'package:flutter/material.dart';

export 'search/tag_input_search_bar.dart';
export 'search/tag_suggestion_dropdown.dart';

class AppSearchBar extends StatefulWidget {
  const AppSearchBar({
    required this.onSubmitted,
    this.onChanged,
    this.initialValue,
    this.hintText = 'Search tags',
    super.key,
  });

  final ValueChanged<String> onSubmitted;
  final ValueChanged<String>? onChanged;
  final String? initialValue;
  final String hintText;

  @override
  State<AppSearchBar> createState() => _AppSearchBarState();
}


class _AppSearchBarState extends State<AppSearchBar> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
    _focusNode = FocusNode();
  }

  @override
  void didUpdateWidget(covariant AppSearchBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    final next = widget.initialValue ?? '';
    if (_focusNode.hasFocus) return;
    if (oldWidget.initialValue != widget.initialValue &&
        _controller.text != next) {
      _controller.value = TextEditingValue(
        text: next,
        selection: TextSelection.collapsed(offset: next.length),
      );
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      focusNode: _focusNode,
      autocorrect: false,
      enableSuggestions: false,
      textInputAction: TextInputAction.search,
      onSubmitted: (value) {
        _debounce?.cancel();
        widget.onSubmitted(value);
      },
      onChanged: (value) {
        _debounce?.cancel();
        _debounce = Timer(const Duration(milliseconds: 250), () {
          widget.onChanged?.call(value);
        });
      },
      decoration: InputDecoration(
        hintText: widget.hintText,
        prefixIcon: const Icon(Icons.search_rounded),
        suffixIcon: IconButton(
          tooltip: Localizations.maybeLocaleOf(context)?.languageCode == 'ru'
              ? 'Очистить'
              : 'Clear',
          icon: const Icon(Icons.close_rounded),
          onPressed: () {
            _debounce?.cancel();
            _controller.clear();
            widget.onChanged?.call('');
            _focusNode.requestFocus();
          },
        ),
      ),
    );
  }
}
