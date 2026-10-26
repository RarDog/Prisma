import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:prisma_app/backend/backend.dart';
import 'tag_suggestion_dropdown.dart';

class TagInputSearchBar extends StatefulWidget {
  const TagInputSearchBar({
    required this.onSubmitted,
    this.onChanged,
    this.onSuggestionApplied,
    this.onTagRemoved,
    this.onCleared,
    this.initialValue,
    this.hintText = 'Search tags',
    this.suggestions = const [],
    this.isPlainSearch = false,
    this.onToggleSearchMode,
    super.key,
  });

  final ValueChanged<String> onSubmitted;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSuggestionApplied;
  final ValueChanged<String>? onTagRemoved;
  final VoidCallback? onCleared;
  final String? initialValue;
  final String hintText;
  final List<TagSuggestion> suggestions;
  final bool isPlainSearch;
  final VoidCallback? onToggleSearchMode;

  @override
  State<TagInputSearchBar> createState() => _TagInputSearchBarState();
}

class _TagInputSearchBarState extends State<TagInputSearchBar> {
  final _fieldKey = GlobalKey();
  final _layerLink = LayerLink();
  final _portalController = OverlayPortalController();
  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  late final ScrollController _tagScrollController;
  Timer? _debounce;
  List<String> _tags = [];
  String _lastExternalValue = '';

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _focusNode = FocusNode();
    _tagScrollController = ScrollController();
    _focusNode.addListener(_handleFocusChanged);
    _controller.addListener(_handleControllerChanged);
    _lastExternalValue = widget.initialValue ?? '';
    _setFromQuery(_lastExternalValue);
  }

  void _handleControllerChanged() {
    if (_controller.text.trim().isEmpty && _portalController.isShowing) {
      _portalController.hide();
    }
  }

  @override
  void didUpdateWidget(covariant TagInputSearchBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isPlainSearch != widget.isPlainSearch) {
      if (widget.isPlainSearch) {
        final combined = _query;
        _tags = [];
        _controller.value = TextEditingValue(
          text: combined,
          selection: TextSelection.collapsed(offset: combined.length),
        );
      } else {
        final text = _controller.text;
        _controller.clear();
        _setFromQuery(text);
      }
      setState(() {});
    }

    final next = widget.initialValue ?? '';
    final externalChanged = widget.initialValue != oldWidget.initialValue;
    if (externalChanged && (!_focusNode.hasFocus || next != _query)) {
      if (widget.isPlainSearch) {
        _controller.value = TextEditingValue(
          text: next,
          selection: TextSelection.collapsed(offset: next.length),
        );
        _lastExternalValue = next;
      } else {
        final oldTagCount = _tags.length;
        _setFromQuery(next);
        _lastExternalValue = next;
        if (_tags.length > oldTagCount) {
          _scrollToEnd();
        }
      }
      setState(() {});
    }
    if (oldWidget.suggestions != widget.suggestions) {
      _syncSuggestions();
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    if (_portalController.isShowing) {
      _portalController.hide();
    }
    _tagScrollController.dispose();
    _controller.removeListener(_handleControllerChanged);
    _focusNode.removeListener(_handleFocusChanged);
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _requestFocusAndShowKeyboard() {
    if (_focusNode.hasFocus) {
      _focusNode.unfocus();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        FocusScope.of(context).requestFocus(_focusNode);
        SystemChannels.textInput.invokeMethod<void>('TextInput.show');
      });
    } else {
      FocusScope.of(context).requestFocus(_focusNode);
      SystemChannels.textInput.invokeMethod<void>('TextInput.show');
    }
  }

  void _handleFocusChanged() {
    if (!mounted) return;
    if (_focusNode.hasFocus) {
      _syncSuggestions();
    }
    setState(() {});
  }

  void _syncSuggestions() {
    if (!mounted) return;
    final token = _activeToken;
    if (!_focusNode.hasFocus || token.isEmpty) {
      if (_portalController.isShowing) {
        _portalController.hide();
      }
      return;
    }
    final matches = _matchingSuggestions;
    if (matches.isEmpty) {
      if (_portalController.isShowing) {
        _portalController.hide();
      }
      return;
    }
    if (!_portalController.isShowing) {
      _portalController.show();
    }
  }

  List<TagSuggestion> get _matchingSuggestions {
    final token = _activeToken;
    if (token.isEmpty) return const [];
    return widget.suggestions
        .where((item) => item.name.toLowerCase().startsWith(token))
        .toList(growable: false);
  }

  void _hideSuggestions() {
    if (_portalController.isShowing) {
      _portalController.hide();
    }
    _focusNode.unfocus();
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_tagScrollController.hasClients) return;
      final max = _tagScrollController.position.maxScrollExtent;
      if (max <= 0) return;
      _tagScrollController.animateTo(
        max,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return TapRegion(
      groupId: _fieldKey,
      onTapOutside: (_) => _hideSuggestions(),
      child: OverlayPortal(
        controller: _portalController,
        overlayChildBuilder: (context) {
          try {
            final token = _activeToken;
            final suggestions = _matchingSuggestions;
            if (suggestions.isEmpty || token.isEmpty) {
              return const SizedBox.shrink();
            }

            final screenSize = MediaQuery.sizeOf(context);
            final renderBox =
                _fieldKey.currentContext?.findRenderObject() as RenderBox?;
            final fieldWidth =
                renderBox?.hasSize == true ? renderBox!.size.width : 360.0;
            final fieldHeight =
                renderBox?.hasSize == true ? renderBox!.size.height : 48.0;

            final screenW = screenSize.width;
            final maxAllowedWidth = math.max(180.0, screenW - 24.0);
            final safeFieldWidth = fieldWidth.clamp(180.0, maxAllowedWidth);
            final targetWidth =
                screenW < 600 ? maxAllowedWidth : safeFieldWidth;
            final dropdownWidth = targetWidth
                .clamp(
                  math.min(safeFieldWidth, maxAllowedWidth),
                  maxAllowedWidth,
                )
                .toDouble();

            // Ensure dropdown stays fully on screen and doesn't get clipped
            double dxOffset = 0.0;
            if (renderBox?.hasSize == true && renderBox?.attached == true) {
              final globalPos = renderBox!.localToGlobal(Offset.zero);
              final globalRight = globalPos.dx + dropdownWidth;
              final maxRight = screenW - 12.0;
              if (globalRight > maxRight) {
                dxOffset = maxRight - globalRight;
              }
              if (globalPos.dx + dxOffset < 12.0) {
                dxOffset = 12.0 - globalPos.dx;
              }
            }

            return CompositedTransformFollower(
              link: _layerLink,
              showWhenUnlinked: false,
              offset: Offset(dxOffset, fieldHeight + 6),
              child: Align(
                alignment: Alignment.topLeft,
                child: TapRegion(
                  groupId: _fieldKey,
                  child: SizedBox(
                    width: dropdownWidth,
                    child: TagSuggestionDropdown(
                      suggestions: suggestions,
                      query: token,
                      onSelected: _applySuggestion,
                    ),
                  ),
                ),
              ),
            );
          } catch (e, st) {
            AppLogger.error('Error in TagInputSearchBar overlay', e, st);
            return const SizedBox.shrink();
          }
        },
        child: CompositedTransformTarget(
          link: _layerLink,
          child: DecoratedBox(
            key: _fieldKey,
            decoration: BoxDecoration(
              color: Theme.of(context).inputDecorationTheme.fillColor ??
                  scheme.surfaceContainerHighest.withValues(alpha: 0.38),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: _focusNode.hasFocus
                    ? scheme.primary.withValues(alpha: 0.6)
                    : Colors.white.withValues(alpha: 0.08),
                width: 1.0,
              ),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(22),
              onTap: _requestFocusAndShowKeyboard,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Icon(Icons.search_rounded, color: scheme.onSurfaceVariant),
                    const SizedBox(width: 8),
                    Expanded(
                      child: widget.isPlainSearch
                          ? SizedBox(
                              height: 38,
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: Focus(
                                  onKeyEvent: _handleKeyEvent,
                                  child: TextField(
                                    controller: _controller,
                                    focusNode: _focusNode,
                                    autocorrect: false,
                                    enableSuggestions: false,
                                    textInputAction: TextInputAction.search,
                                    onTap: () {
                                      SystemChannels.textInput
                                          .invokeMethod<void>(
                                              'TextInput.show');
                                    },
                                    onSubmitted: (_) => _submit(),
                                    onChanged: _handleDraftChanged,
                                    decoration: InputDecoration(
                                      isDense: true,
                                      border: InputBorder.none,
                                      enabledBorder: InputBorder.none,
                                      focusedBorder: InputBorder.none,
                                      filled: false,
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                        vertical: 8,
                                      ),
                                      hintText: widget.hintText,
                                      prefixIcon: null,
                                      suffixIcon: null,
                                    ),
                                  ),
                                ),
                              ),
                            )
                          : SizedBox(
                              height: 38,
                              child: Scrollbar(
                                controller: _tagScrollController,
                                thumbVisibility: false,
                                child: SingleChildScrollView(
                                  controller: _tagScrollController,
                                  scrollDirection: Axis.horizontal,
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      for (final tag in _tags) ...[
                                        _buildTagChip(context, tag),
                                        const SizedBox(width: 6),
                                      ],
                                      IntrinsicWidth(
                                        stepWidth: 10,
                                        child: ConstrainedBox(
                                          constraints: BoxConstraints(
                                            minWidth: _tags.isEmpty ? 140 : 48,
                                            maxWidth: 240,
                                          ),
                                          child: Focus(
                                            onKeyEvent: _handleKeyEvent,
                                            child: TextField(
                                              controller: _controller,
                                              focusNode: _focusNode,
                                              autocorrect: false,
                                              enableSuggestions: false,
                                              textInputAction:
                                                  TextInputAction.search,
                                              onTap: () {
                                                SystemChannels.textInput
                                                    .invokeMethod<void>(
                                                        'TextInput.show');
                                              },
                                              onSubmitted: (_) => _submit(),
                                              onChanged: _handleDraftChanged,
                                              decoration: InputDecoration(
                                                isDense: true,
                                                border: InputBorder.none,
                                                enabledBorder: InputBorder.none,
                                                focusedBorder: InputBorder.none,
                                                filled: false,
                                                contentPadding:
                                                    const EdgeInsets.symmetric(
                                                  vertical: 8,
                                                ),
                                                hintText: _tags.isEmpty
                                                    ? widget.hintText
                                                    : 'tag',
                                                prefixIcon: null,
                                                suffixIcon: null,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                    ),
                    if (_query.isNotEmpty)
                      IconButton(
                        tooltip:
                            Localizations.maybeLocaleOf(context)?.languageCode ==
                                    'ru'
                                ? 'Очистить'
                                : 'Clear',
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(Icons.close_rounded),
                        onPressed: _clear,
                      ),
                    if (widget.onToggleSearchMode != null)
                      IconButton(
                        tooltip: widget.isPlainSearch
                            ? (Localizations.maybeLocaleOf(context)?.languageCode ==
                                    'ru'
                                ? 'Режим: Поисковик (нажмите для тегов)'
                                : 'Mode: Search engine (tap for tags)')
                            : (Localizations.maybeLocaleOf(context)?.languageCode ==
                                    'ru'
                                ? 'Режим: Теги (нажмите для поисковика)'
                                : 'Mode: Tags (tap for search engine)'),
                        visualDensity: VisualDensity.compact,
                        icon: Icon(
                          widget.isPlainSearch
                              ? Icons.manage_search_rounded
                              : Icons.label_rounded,
                          size: 20,
                          color: widget.isPlainSearch
                              ? scheme.primary
                              : scheme.onSurfaceVariant.withValues(alpha: 0.7),
                        ),
                        onPressed: widget.onToggleSearchMode,
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTagChip(BuildContext context, String tag) {
    final scheme = Theme.of(context).colorScheme;
    final isAnd = tag.toLowerCase() == 'and';
    return InputChip(
      label: Text(
        isAnd ? 'AND' : tag,
        style: TextStyle(
          color:
              isAnd ? scheme.onSecondaryContainer : scheme.onPrimaryContainer,
          fontWeight: isAnd ? FontWeight.w900 : FontWeight.w700,
          letterSpacing: isAnd ? 0.8 : 0,
        ),
      ),
      avatar: Icon(
        isAnd ? Icons.alt_route_rounded : Icons.tag_rounded,
        size: 16,
        color: isAnd ? scheme.secondary : scheme.primary,
      ),
      deleteIcon: const Icon(Icons.close_rounded, size: 16),
      onPressed: () => _editTag(tag),
      onDeleted: () => _removeTag(tag),
      backgroundColor: isAnd
          ? scheme.secondaryContainer.withValues(alpha: 0.7)
          : scheme.primaryContainer.withValues(alpha: 0.54),
      side: BorderSide(
        color: isAnd
            ? scheme.secondary.withValues(alpha: 0.4)
            : scheme.primary.withValues(alpha: 0.18),
      ),
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (event.logicalKey == LogicalKeyboardKey.enter ||
        event.logicalKey == LogicalKeyboardKey.numpadEnter) {
      if (!widget.isPlainSearch) {
        _commitDraft(_controller.text);
      }
      _submit();
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.escape) {
      if (_portalController.isShowing) {
        _portalController.hide();
        return KeyEventResult.handled;
      }
      _focusNode.unfocus();
      return KeyEventResult.handled;
    }
    if (widget.isPlainSearch) {
      return KeyEventResult.ignored;
    }
    if (event.logicalKey != LogicalKeyboardKey.backspace) {
      return KeyEventResult.ignored;
    }
    if (_controller.text.isNotEmpty || _tags.isEmpty) {
      return KeyEventResult.ignored;
    }
    final tag = _tags.removeLast();
    _controller.value = TextEditingValue(
      text: tag,
      selection: TextSelection.collapsed(offset: tag.length),
    );
    setState(() {});
    _notifyChanged();
    return KeyEventResult.handled;
  }

  void _handleDraftChanged(String value) {
    if (widget.isPlainSearch) {
      setState(() {});
      _notifyChangedDebounced();
      return;
    }
    if (value.trim().isEmpty) {
      _debounce?.cancel();
      if (_portalController.isShowing) {
        _portalController.hide();
      }
      setState(() {});
      _notifyChanged();
      return;
    }
    final composing = _controller.value.composing;
    if (!composing.isValid && RegExp(r'\s$').hasMatch(value)) {
      _commitDraft(value);
      return;
    }
    _notifyChangedDebounced();
  }

  void _setFromQuery(String query) {
    if (widget.isPlainSearch) {
      _tags = [];
      _controller.value = TextEditingValue(
        text: query,
        selection: TextSelection.collapsed(offset: query.length),
      );
      return;
    }
    _tags = _parseTags(query);
    _controller.clear();
  }

  void _commitDraft(String value) {
    final additions = _parseTags(value);
    if (additions.isEmpty) return;
    setState(() {
      for (final tag in additions) {
        if (tag.toLowerCase() == 'and' || !_tags.contains(tag)) {
          _tags.add(tag);
        }
      }
      _controller.clear();
    });
    if (_portalController.isShowing) {
      _portalController.hide();
    }
    _scrollToEnd();
    _notifyChanged();
  }

  void _submit() {
    _debounce?.cancel();
    if (_portalController.isShowing) {
      _portalController.hide();
    }
    if (!widget.isPlainSearch) {
      _commitDraft(_controller.text);
    }
    _lastExternalValue = _query;
    _focusNode.unfocus();
    widget.onSubmitted(_query);
  }

  void _clear() {
    _debounce?.cancel();
    if (_portalController.isShowing) {
      _portalController.hide();
    }
    setState(() {
      _tags = [];
      _controller.clear();
    });
    _lastExternalValue = '';
    _notifyChanged();
    _focusNode.unfocus();
    widget.onCleared?.call();
    widget.onSubmitted('');
  }

  void _editTag(String tag) {
    if (_portalController.isShowing) {
      _portalController.hide();
    }
    setState(() {
      _tags = _tags.where((item) => item != tag).toList(growable: true);
      _controller.value = TextEditingValue(
        text: tag,
        selection: TextSelection.collapsed(offset: tag.length),
      );
    });
    _notifyChanged();
    _focusNode.requestFocus();
  }

  void _removeTag(String tag) {
    if (_portalController.isShowing) {
      _portalController.hide();
    }
    setState(() {
      _tags = _tags.where((item) => item != tag).toList(growable: true);
    });
    _lastExternalValue = _query;
    _notifyChanged();
    if (widget.onTagRemoved != null) {
      widget.onTagRemoved!(_query);
    }
  }

  void _applySuggestion(String suggestion) {
    if (widget.isPlainSearch) {
      setState(() {
        final text = _controller.text;
        final words = text.split(RegExp(r'\s+'));
        if (words.isNotEmpty && words.last.isNotEmpty) {
          words[words.length - 1] = suggestion;
          final updated = '${words.join(' ')} ';
          _controller.value = TextEditingValue(
            text: updated,
            selection: TextSelection.collapsed(offset: updated.length),
          );
        } else {
          final updated = '$suggestion ';
          _controller.value = TextEditingValue(
            text: updated,
            selection: TextSelection.collapsed(offset: updated.length),
          );
        }
      });
      if (_portalController.isShowing) {
        _portalController.hide();
      }
      _lastExternalValue = _query;
      _notifyChanged();
      widget.onSuggestionApplied?.call(_query);
      _focusNode.requestFocus();
      return;
    }
    final draft = _controller.text.trim();
    setState(() {
      if (draft.isNotEmpty) {
        final tokens = _parseTags(draft);
        if (tokens.isNotEmpty) {
          final prefixTokens = tokens.sublist(0, tokens.length - 1);
          for (final token in prefixTokens) {
            if (token.toLowerCase() == 'and' || !_tags.contains(token)) {
              _tags.add(token);
            }
          }
        }
      }
      if (!_tags.contains(suggestion)) {
        _tags.add(suggestion);
      }
      _controller.clear();
    });
    if (_portalController.isShowing) {
      _portalController.hide();
    }
    _lastExternalValue = _query;
    _scrollToEnd();
    _notifyChanged();
    widget.onSuggestionApplied?.call(_query);
    _focusNode.requestFocus();
  }

  void _notifyChangedDebounced() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 100), _notifyChanged);
  }

  void _notifyChanged() {
    widget.onChanged?.call(_query);
    _syncSuggestions();
  }

  List<String> _parseTags(String query) {
    final seen = <String>{};
    final result = <String>[];
    for (final raw in query.trim().split(RegExp(r'\s+'))) {
      final tag = raw.trim();
      if (tag.isEmpty) continue;
      if (tag.toLowerCase() != 'and' && !seen.add(tag.toLowerCase())) continue;
      result.add(tag);
    }
    return result;
  }

  String get _query {
    if (widget.isPlainSearch) {
      return _controller.text.trim();
    }
    final draft = _controller.text.trim();
    final all = [..._tags, if (draft.isNotEmpty) draft];
    return all.join(' ');
  }

  String get _activeToken {
    final draft = _controller.text.trim().toLowerCase();
    if (draft.isEmpty) return '';
    final raw = draft.split(RegExp(r'\s+')).last;
    return raw.trim();
  }
}


