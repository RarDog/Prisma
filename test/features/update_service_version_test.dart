import 'package:flutter_test/flutter_test.dart';
import 'package:prisma_app/features/settings/domain/update_service.dart';

void main() {
  group('UpdateService Version Parsing & Beta Support', () {
    test('compares standard major.minor.patch versions correctly', () {
      expect(UpdateService.compareVersionsForTest('1.2.1', '1.2.0'),
          greaterThan(0));
      expect(
          UpdateService.compareVersionsForTest('1.2.0', '1.2.1'), lessThan(0));
      expect(UpdateService.compareVersionsForTest('1.2.0', '1.2.0'), equals(0));
      expect(UpdateService.compareVersionsForTest('2.0.0', '1.9.9'),
          greaterThan(0));
    });

    test('prerelease is older than same stable version', () {
      // 1.2.0 stable is newer than 1.2.0-beta.1
      expect(UpdateService.compareVersionsForTest('1.2.0', '1.2.0-beta.1'),
          greaterThan(0));
      expect(UpdateService.compareVersionsForTest('1.2.0-beta.1', '1.2.0'),
          lessThan(0));
    });

    test('prerelease revision progression works', () {
      // beta.2 > beta.1
      expect(
          UpdateService.compareVersionsForTest('1.2.0-beta.2', '1.2.0-beta.1'),
          greaterThan(0));
      expect(
          UpdateService.compareVersionsForTest('1.2.0-beta.1', '1.2.0-beta.2'),
          lessThan(0));

      // rc.1 > beta.5
      expect(UpdateService.compareVersionsForTest('1.2.0-rc.1', '1.2.0-beta.5'),
          greaterThan(0));
      // beta.1 > alpha.1
      expect(
          UpdateService.compareVersionsForTest('1.2.0-beta.1', '1.2.0-alpha.1'),
          greaterThan(0));
    });

    test('newer major/minor with beta is newer than older stable', () {
      // 1.3.0-beta.1 > 1.2.0
      expect(UpdateService.compareVersionsForTest('1.3.0-beta.1', '1.2.0'),
          greaterThan(0));
      // 2.0.0-rc.1 > 1.9.9
      expect(UpdateService.compareVersionsForTest('2.0.0-rc.1', '1.9.9'),
          greaterThan(0));
    });
  });
}
