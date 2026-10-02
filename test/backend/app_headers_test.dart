import 'package:flutter_test/flutter_test.dart';
import 'package:gel_rule_app/app/app_version.dart';
import 'package:gel_rule_app/core/http/app_headers.dart';

void main() {
  group('AppHeaders', () {
    test('defaultUserAgent contains appDisplayVersion', () {
      expect(AppHeaders.defaultUserAgent, contains(appDisplayVersion));
      expect(AppHeaders.defaultUserAgent, startsWith('Prisma/'));
      expect(AppHeaders.defaultUserAgent, endsWith('Flutter local booru browser'));
    });

    test('mangaDexUserAgent contains appDisplayVersion', () {
      expect(AppHeaders.mangaDexUserAgent, contains(appDisplayVersion));
      expect(AppHeaders.mangaDexUserAgent, contains('MangaDex Client'));
    });

    test('e621UserAgent formats correctly with login and version', () {
      final ua = AppHeaders.e621UserAgent('testUser');
      expect(ua, equals('Prisma/$appDisplayVersion (by testUser on e621)'));
    });

    test('browserHeaders returns desktopChrome UA and optional fields', () {
      final headers = AppHeaders.browserHeaders(
        siteId: '1',
        referer: 'https://mangalib.me/',
        origin: 'https://mangalib.me',
      );
      expect(headers['User-Agent'], equals(AppHeaders.desktopChromeUserAgent));
      expect(headers['Site-Id'], equals('1'));
      expect(headers['Referer'], equals('https://mangalib.me/'));
      expect(headers['Origin'], equals('https://mangalib.me'));
      expect(headers['Accept'], contains('application/json'));
    });

    test('mediaHeaders constructs valid image/video stream headers', () {
      final headers = AppHeaders.mediaHeaders(
        referer: 'https://gelbooru.com/',
      );
      expect(headers['User-Agent'], equals(AppHeaders.defaultUserAgent));
      expect(headers['Referer'], equals('https://gelbooru.com/'));
      expect(headers['Accept'], equals('*/*'));
    });
  });
}
