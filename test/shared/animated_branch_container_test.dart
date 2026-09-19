import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gel_rule_app/shared/widgets/animated_branch_container.dart';

class _StatefulCounter extends StatefulWidget {
  const _StatefulCounter({super.key, required this.title});
  final String title;

  @override
  State<_StatefulCounter> createState() => _StatefulCounterState();
}

class _StatefulCounterState extends State<_StatefulCounter> {
  int count = 0;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text('${widget.title}: $count'),
        ElevatedButton(
          onPressed: () => setState(() => count++),
          child: Text('Inc ${widget.title}'),
        ),
      ],
    );
  }
}

void main() {
  testWidgets('AnimatedBranchContainer preserves state between tab transitions',
      (tester) async {
    int currentIndex = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            return Scaffold(
              body: AnimatedBranchContainer(
                currentIndex: currentIndex,
                children: const [
                  _StatefulCounter(title: 'TabA'),
                  _StatefulCounter(title: 'TabB'),
                ],
              ),
              bottomNavigationBar: Row(
                children: [
                  TextButton(
                    onPressed: () => setState(() => currentIndex = 0),
                    child: const Text('Go TabA'),
                  ),
                  TextButton(
                    onPressed: () => setState(() => currentIndex = 1),
                    child: const Text('Go TabB'),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );

    // TabA is visible
    expect(find.text('TabA: 0'), findsOneWidget);

    // Increment TabA counter
    await tester.tap(find.text('Inc TabA'));
    await tester.pumpAndSettle();
    expect(find.text('TabA: 1'), findsOneWidget);

    // Switch to TabB
    await tester.tap(find.text('Go TabB'));
    // Advance partially during transition
    await tester.pump(const Duration(milliseconds: 100));
    // Settle transition
    await tester.pumpAndSettle();

    expect(find.text('TabB: 0'), findsOneWidget);

    // Increment TabB counter
    await tester.tap(find.text('Inc TabB'));
    await tester.pumpAndSettle();
    expect(find.text('TabB: 1'), findsOneWidget);

    // Switch back to TabA
    await tester.tap(find.text('Go TabA'));
    await tester.pumpAndSettle();

    // Verify TabA preserved its counter state!
    expect(find.text('TabA: 1'), findsOneWidget);

    // Switch back to TabB and verify its counter state is preserved!
    await tester.tap(find.text('Go TabB'));
    await tester.pumpAndSettle();
    expect(find.text('TabB: 1'), findsOneWidget);
  });
}
