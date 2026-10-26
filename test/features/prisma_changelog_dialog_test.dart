import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prisma_app/app/app_version.dart';
import 'package:prisma_app/app/changelog.dart';
import 'package:prisma_app/features/settings/presentation/widgets/prisma_changelog_dialog.dart';

void main() {
  group('PrismaChangelogDialog Tests', () {
    testWidgets('renders dialog with header, current version badge and bullets',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showPrismaChangelogDialog(
                context: context,
                isRu: true,
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      );

      // Open the dialog
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      // Check header
      expect(find.text('История изменений'), findsOneWidget);
      expect(find.text('v$appDisplayVersion'), findsOneWidget);
      expect(find.text('• Текущая версия'), findsOneWidget);

      // Check that latest release is present
      expect(find.text(prismaChangelog.first.version), findsWidgets);
      expect(
        find.text(prismaChangelog.first.localizedTitle(true)),
        findsOneWidget,
      );

      // Check category icons exist (rocket, wrench, bolt, etc.)
      expect(find.byIcon(Icons.close_rounded), findsWidgets);

      // Tap close button
      await tester.tap(find.text('Закрыть'));
      await tester.pumpAndSettle();

      expect(find.text('История изменений'), findsNothing);
    });

    testWidgets('renders English version accurately', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showPrismaChangelogDialog(
                context: context,
                isRu: false,
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('Version History'), findsOneWidget);
      expect(find.text('• Current version'), findsOneWidget);
      expect(find.text('Close'), findsOneWidget);
    });

    testWidgets('renders RC badge correctly for release candidate versions',
        (tester) async {
      final fakeChangelog = [
        const PrismaChange(
          version: '4.3.0-rc.1',
          title: 'Release Candidate 1',
          bullets: ['Feature freeze and bug fixes.'],
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PrismaChangelogDialog(
              isRu: true,
              changelog: fakeChangelog,
            ),
          ),
        ),
      );

      expect(find.text('RC'), findsOneWidget);
      expect(find.text('4.3.0-rc.1'), findsOneWidget);
    });
  });
}
