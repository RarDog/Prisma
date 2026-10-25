import 'package:flutter/material.dart';

import '../app_destination.dart';
import '../desktop_shortcuts_dialog.dart';

class BottomShortcutsButton extends StatefulWidget {
  const BottomShortcutsButton({
    super.key,
    required this.isFullyExpanded,
    required this.contentOpacity,
    required this.ru,
  });

  final bool isFullyExpanded;
  final double contentOpacity;
  final bool ru;

  @override
  State<BottomShortcutsButton> createState() => BottomShortcutsButtonState();
}

class BottomShortcutsButtonState extends State<BottomShortcutsButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Tooltip(
      message: widget.isFullyExpanded
          ? ''
          : (widget.ru
              ? 'Горячие клавиши (F1 / ?)'
              : 'Keyboard Shortcuts (F1 / ?)'),
      waitDuration: const Duration(milliseconds: 300),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2A2A2A) : const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.15),
          width: 0.8,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      textStyle: const TextStyle(
        color: Colors.white,
        fontSize: 12,
        fontWeight: FontWeight.w500,
      ),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => DesktopShortcutsDialog.show(context),
            borderRadius: BorderRadius.circular(14),
            hoverColor: Colors.transparent,
            splashColor: scheme.primary.withValues(alpha: 0.12),
            highlightColor: scheme.primary.withValues(alpha: 0.08),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              height: 44,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                color: _hovered
                    ? (isDark ? Colors.white : Colors.black)
                        .withValues(alpha: isDark ? 0.07 : 0.04)
                    : Colors.transparent,
                border: Border.all(
                  color: _hovered
                      ? (isDark ? Colors.white : Colors.black)
                          .withValues(alpha: isDark ? 0.12 : 0.08)
                      : Colors.transparent,
                  width: 1.1,
                ),
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 58,
                    child: Center(
                      child: Icon(
                        Icons.keyboard_rounded,
                        size: 21,
                        color: _hovered
                            ? scheme.primary
                            : (isDark
                                ? scheme.onSurfaceVariant
                                    .withValues(alpha: 0.85)
                                : scheme.onSurfaceVariant),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Opacity(
                      opacity: widget.contentOpacity,
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              widget.ru ? 'Горячие клавиши' : 'Shortcuts',
                              maxLines: 1,
                              softWrap: false,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                                color: _hovered
                                    ? scheme.onSurface
                                    : scheme.onSurface.withValues(alpha: 0.85),
                              ),
                            ),
                          ),
                          AnimatedOpacity(
                            duration: const Duration(milliseconds: 180),
                            opacity: _hovered ? 1.0 : 0.55,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2.5,
                              ),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? Colors.white.withValues(alpha: 0.08)
                                    : Colors.black.withValues(alpha: 0.05),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: isDark
                                      ? Colors.white.withValues(alpha: 0.14)
                                      : Colors.black.withValues(alpha: 0.10),
                                  width: 0.8,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(
                                      alpha: isDark ? 0.25 : 0.05,
                                    ),
                                    blurRadius: 2,
                                    offset: const Offset(0, 1),
                                  ),
                                ],
                              ),
                              child: const Text(
                                '?',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'monospace',
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class RailButton extends StatefulWidget {
  const RailButton({
    super.key,
    required this.destination,
    required this.selected,
    required this.contentOpacity,
    required this.isFullyExpanded,
    required this.ru,
    required this.shortcutKey,
    required this.onTap,
  });

  final AppDestination destination;
  final bool selected;
  final double contentOpacity;
  final bool isFullyExpanded;
  final bool ru;
  final String shortcutKey;
  final VoidCallback onTap;

  @override
  State<RailButton> createState() => RailButtonState();
}

class RailButtonState extends State<RailButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final label = widget.destination.labelFor(widget.ru);
    final selected = widget.selected;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.5),
      child: Tooltip(
        message: widget.isFullyExpanded ? '' : '$label (${widget.shortcutKey})',
        waitDuration: const Duration(milliseconds: 300),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF2A2A2A) : const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.15),
            width: 0.8,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        textStyle: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
        child: MouseRegion(
          onEnter: (_) => setState(() => _hovered = true),
          onExit: (_) => setState(() => _hovered = false),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(14),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: widget.onTap,
              borderRadius: BorderRadius.circular(14),
              hoverColor: Colors.transparent,
              splashColor: scheme.primary.withValues(alpha: 0.12),
              highlightColor: scheme.primary.withValues(alpha: 0.08),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOutCubic,
                width: 244,
                height: 46,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  gradient: selected
                      ? LinearGradient(
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                          colors: [
                            scheme.primary
                                .withValues(alpha: isDark ? 0.22 : 0.14),
                            scheme.primary
                                .withValues(alpha: isDark ? 0.08 : 0.04),
                          ],
                        )
                      : (_hovered
                          ? LinearGradient(
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                              colors: [
                                (isDark ? Colors.white : Colors.black)
                                    .withValues(alpha: isDark ? 0.07 : 0.04),
                                (isDark ? Colors.white : Colors.black)
                                    .withValues(alpha: isDark ? 0.03 : 0.02),
                              ],
                            )
                          : null),
                  border: Border.all(
                    color: selected
                        ? scheme.primary.withValues(alpha: isDark ? 0.42 : 0.28)
                        : (_hovered
                            ? (isDark ? Colors.white : Colors.black)
                                .withValues(alpha: isDark ? 0.12 : 0.08)
                            : Colors.transparent),
                    width: 1.1,
                  ),
                  boxShadow: selected
                      ? [
                          BoxShadow(
                            color: scheme.primary
                                .withValues(alpha: isDark ? 0.22 : 0.12),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  children: [
                    // Glowing active indicator
                    Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeOutCubic,
                        width: selected ? 3.5 : 0,
                        height: selected ? 20 : 0,
                        decoration: BoxDecoration(
                          color: scheme.primary,
                          borderRadius: BorderRadius.circular(3),
                          boxShadow: selected
                              ? [
                                  BoxShadow(
                                    color:
                                        scheme.primary.withValues(alpha: 0.65),
                                    blurRadius: 8,
                                    spreadRadius: 0.5,
                                  ),
                                ]
                              : null,
                        ),
                      ),
                    ),
                    SizedBox(
                      width: selected ? 50.5 : 54.0,
                      child: Center(
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: selected
                                ? scheme.primary
                                    .withValues(alpha: isDark ? 0.15 : 0.12)
                                : Colors.transparent,
                          ),
                          child: Center(
                            child: Icon(
                              selected
                                  ? widget.destination.effectiveSelectedIcon
                                  : widget.destination.icon,
                              size: 21,
                              color: selected
                                  ? scheme.primary
                                  : (isDark
                                      ? scheme.onSurfaceVariant
                                          .withValues(alpha: 0.85)
                                      : scheme.onSurfaceVariant),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Opacity(
                        opacity: widget.contentOpacity,
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                label,
                                maxLines: 1,
                                softWrap: false,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: selected
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                  letterSpacing: 0.15,
                                  color: selected
                                      ? scheme.primary
                                      : scheme.onSurface,
                                ),
                              ),
                            ),
                            AnimatedOpacity(
                              duration: const Duration(milliseconds: 180),
                              opacity:
                                  selected ? 1.0 : (_hovered ? 0.95 : 0.45),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2.5,
                                ),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? (selected
                                          ? scheme.primary
                                              .withValues(alpha: 0.18)
                                          : Colors.white
                                              .withValues(alpha: 0.06))
                                      : (selected
                                          ? scheme.primary
                                              .withValues(alpha: 0.12)
                                          : Colors.black
                                              .withValues(alpha: 0.04)),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: isDark
                                        ? (selected
                                            ? scheme.primary
                                                .withValues(alpha: 0.35)
                                            : Colors.white
                                                .withValues(alpha: 0.10))
                                        : (selected
                                            ? scheme.primary
                                                .withValues(alpha: 0.25)
                                            : Colors.black
                                                .withValues(alpha: 0.08)),
                                    width: 0.8,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(
                                        alpha: isDark ? 0.25 : 0.05,
                                      ),
                                      blurRadius: 2,
                                      offset: const Offset(0, 1),
                                    ),
                                  ],
                                ),
                                child: Text(
                                  widget.shortcutKey,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    fontFamily: 'monospace',
                                    letterSpacing: 0.3,
                                    color: selected
                                        ? scheme.primary
                                        : scheme.onSurfaceVariant,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                          ],
                        ),
                      ),
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
}


