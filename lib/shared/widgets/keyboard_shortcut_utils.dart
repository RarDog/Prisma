import 'package:flutter/material.dart';

/// Checks whether any text input (e.g. TextField, EditableText) currently has primary focus.
bool isTextInputFocused() {
  final primaryFocus = FocusManager.instance.primaryFocus;
  if (primaryFocus == null) return false;
  final context = primaryFocus.context;
  if (context == null) return false;
  if (context.widget is EditableText) return true;
  return context.findAncestorWidgetOfExactType<EditableText>() != null;
}

/// An [Action] that is automatically disabled when the primary focus is within an [EditableText]
/// unless [allowInTextInput] is explicitly true.
///
/// When disabled, Flutter's [Shortcuts] system leaves the key event unhandled, allowing
/// the text input field to receive the keystroke normally (e.g. typing characters, deleting,
/// or using shortcuts like Ctrl+A to select text inside the field).
class NonTextInputAction<T extends Intent> extends CallbackAction<T> {
  NonTextInputAction({
    required super.onInvoke,
    this.allowInTextInput = false,
  });

  final bool allowInTextInput;

  @override
  bool isEnabled(T intent) {
    if (!allowInTextInput && isTextInputFocused()) {
      return false;
    }
    return super.isEnabled(intent);
  }
}
