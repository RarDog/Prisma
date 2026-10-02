import 'package:gel_rule_app/app/app_version.dart';

/// Centralized repository and utility for application HTTP headers and User-Agents.
abstract final class AppHeaders {
  /// Default User-Agent for Prisma: "Prisma/<version> Flutter local booru browser"
  static String get defaultUserAgent =>
      'Prisma/$appDisplayVersion Flutter local booru browser';

  /// Specialized User-Agent for MangaDex client requests.
  static String get mangaDexUserAgent =>
      'Prisma/$appDisplayVersion Flutter MangaDex Client';

  /// User-Agent for e621 API compliance: "Prisma/<version> (by <login> on e621)"
  static String e621UserAgent(String login) =>
      'Prisma/$appDisplayVersion (by $login on e621)';

  /// Desktop Chrome User-Agent used for scraping / CDN bypass.
  static const String desktopChromeUserAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/129.0.0.0 Safari/537.36';

  /// Mobile Chrome User-Agent for providers needing mobile emulation (e.g. Realbooru).
  static const String mobileChromeUserAgent =
      'Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 Chrome/125 Mobile Safari/537.36';

  /// Default headers map for general network requests.
  static Map<String, String> get defaultHeaders => {
        'User-Agent': defaultUserAgent,
      };

  /// Common browser headers for scraping (MangaLib, RanobeLib, etc.)
  static Map<String, String> browserHeaders({
    String? referer,
    String? origin,
    String? siteId,
    String? accept,
  }) {
    return {
      'User-Agent': desktopChromeUserAgent,
      'Accept': accept ?? 'application/json, text/plain, */*',
      if (referer != null) 'Referer': referer,
      if (origin != null) 'Origin': origin,
      if (siteId != null) 'Site-Id': siteId,
    };
  }

  /// Media request headers for image / video streams.
  static Map<String, String> mediaHeaders({
    String? referer,
    String? userAgent,
    String? accept,
  }) {
    return {
      'User-Agent': userAgent ?? defaultUserAgent,
      'Accept': accept ?? '*/*',
      if (referer != null) 'Referer': referer,
    };
  }
}
