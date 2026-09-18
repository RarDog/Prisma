import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gel_rule_app/shared/widgets/keyboard_shortcut_utils.dart';

class _TestIntent extends Intent {
  const _TestIntent();
}

void main() {
  testWidgets('NonTextInputAction triggers when no text input is focused', (tester) async {
    var invoked = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Shortcuts(
            shortcuts: {
              LogicalKeySet(LogicalKeyboardKey.keyR): const _TestIntent(),
            },
            child: Actions(
              actions: {
                _TestIntent: NonTextInputAction<_TestIntent>(
                  onInvoke: (_) {
                    invoked = true;
                    return null;
                  },
                ),
              },
              child: const Focus(
                autofocus: true,
                child: Text('Not an input'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    expect(isTextInputFocused(), isFalse);

    await tester.sendKeyEvent(LogicalKeyboardKey.keyR);
    await tester.pumpAndSettle();

    expect(invoked, isTrue);
  });

  testWidgets('NonTextInputAction is disabled when TextField has focus', (tester) async {
    var invoked = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Shortcuts(
            shortcuts: {
              LogicalKeySet(LogicalKeyboardKey.keyR): const _TestIntent(),
              LogicalKeySet(LogicalKeyboardKey.keyV): const _TestIntent(),
            },
            child: Actions(
              actions: {
                _TestIntent: NonTextInputAction<_TestIntent>(
                  onInvoke: (_) {
                    invoked = true;
                    return null;
                  },
                ),
              },
              child: const TextField(
                autofocus: true,
              ),
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    expect(isTextInputFocused(), isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.keyR);
    await tester.pumpAndSettle();

    expect(invoked, isFalse);

    await tester.sendKeyEvent(LogicalKeyboardKey.keyV);
    await tester.pumpAndSettle();

    expect(invoked, isFalse);
  });
}
