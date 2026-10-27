import 'dart:async';
import 'dart:isolate';

import 'package:dio/dio.dart';

import 'package:gel_rule_app/core/errors/app_exception.dart';
import 'package:gel_rule_app/core/http/app_headers.dart';
import 'package:gel_rule_app/core/http/dio_client.dart';
import 'package:gel_rule_app/features/artists/models/artist_announcement.dart';
import 'package:gel_rule_app/features/artists/models/artist_link.dart';
import 'package:gel_rule_app/features/artists/models/artist_profile.dart';
import 'package:gel_rule_app/features/artists/models/artist_tag.dart';
import 'package:gel_rule_app/features/artists/models/artist_work_query.dart';
import 'package:gel_rule_app/core/models/post.dart';
import 'package:gel_rule_app/core/models/post_comment.dart';
import 'package:gel_rule_app/core/models/provider_health.dart';
import 'package:gel_rule_app/core/models/top_period_filter.dart';
import 'package:gel_rule_app/sources/interfaces/content_provider.dart';

/// HTML scraper for [Fapello](https://fapello.com).
///
/// Fapello exposes no public API, so every read is a regex parse of the
/// server-rendered markup. The site also serves bare HTML fragments through
/// its `/ajax/...` endpoints — the same ones its own infinite scroll uses.
/// Those fragments are an order of magnitude smaller and carry identical item
/// markup, so the media grid reads go through them.
///
/// Reads are anonymous and read-only: no session cookie, no CSRF token, no
/// signed media URLs. Only posting likes/follows needs an account.
class FapelloProvider
    implements
        ContentProvider,
        ArtistProvider,
        CommentProvider,
        PostPageProvider,
        MediaHeadersProvider {
  FapelloProvider({
    required this.id,
    required this.name,
    required this.baseUrl,
    required DioClient dioClient,
    Map<String, String> queryParameters = const {},
  }) : _dio = dioClient.dio;

  @override
  final String id;

  @override
  final String name;

  @override
  final String baseUrl;

  /// Host that serves the mp4 files; images stay on [baseUrl].
  static const _mediaCdnHost = 'cdn.fapello.com';

  /// The site never advertises which platform a model came from (OnlyFans,
  /// Patreon, Fansly, ...), so every profile carries this single label.
  static const _service = 'fapello';

  final Dio _dio;

  @override
  Set<TopPeriodFilter> get supportedTopPeriods => const {
        TopPeriodFilter.none,
      };

  /// `validateStatus` is widened so that a Cloudflare challenge can be told
  /// apart from a genuine 404: the challenge shares the 403 status but is the
  /// only response whose body is the interstitial page.
  static final _htmlOptions = Options(
    responseType: ResponseType.plain,
    validateStatus: (_) => true,
    headers: {
      'Accept': 'text/html,application/xhtml+xml,*/*;q=0.8',
      'User-Agent': AppHeaders.desktopChromeUserAgent,
    },
  );

  /// The "avatar + display name" row shared by every model card.
  ///
  /// Anchoring the href on `https://fapello.com/` drops the sponsored cards,
  /// whose links point at third-party hosts such as `onlyfans.com`.
  static final _modelCardPattern = RegExp(
    r'''<a\s[^>]*href=["'](https://fapello\.com/([a-z0-9][a-z0-9._-]*)/)["'][^>]*class=["'][^"']*\blg:flex flex-1 items-center\b[^"']*["'][^>]*>(.*?)</a>''',
    caseSensitive: false,
    dotAll: true,
  );

  /// One tile of the media grid on a model profile, and of its `/ajax` form.
  static final _mediaItemPattern = RegExp(
    r'''<a\s[^>]*href=["'](https://fapello\.com/([a-z0-9][a-z0-9._-]*)/(\d+)/)["'][^>]*>(.*?)</a>''',
    caseSensitive: false,
    dotAll: true,
  );

  static final _imgSrcPattern = RegExp(r'''<img[^>]+src=["']([^"']+)["']''');

  static final _imgAltPattern = RegExp(r'''<img[^>]+alt=["']([^"']*)["']''');

  /// The only in-grid discriminator between a video tile and an image tile:
  /// videos carry a play-icon overlay.
  static final _playIconPattern = RegExp(r'assets/images/icon-play\.svg');

  static final _fullImagePattern = RegExp(
    r'''<a\s[^>]*href=["']([^"']*fapello\.com/content/[^"']+\.(?:jpe?g|png|gif|webp))["'][^>]*target=["']_blank["'][^>]*>(.*?)</a>''',
    caseSensitive: false,
    dotAll: true,
  );

  static final _videoSourcePattern = RegExp(
    r'''<source[^>]+type=["']video/mp4["'][^>]+src=["']([^"']+\.mp4)["']''',
    caseSensitive: false,
  );

  static final _videoPosterPattern =
      RegExp(r'''<video[^>]+poster=["']([^"']+)["']''', caseSensitive: false);

  static final _detailTagPattern = RegExp(
    r'''<a\s[^>]*href=["']https://fapello\.com/tags/([a-z0-9][a-z0-9._-]*)/["'][^>]*class=["'][^"']*tags-chip[^"']*["'][^>]*>\s*#?([^<]+?)\s*</a>''',
    caseSensitive: false,
    dotAll: true,
  );

  static final _likeCountPattern = RegExp(
    r'''id=["']count_likes_\d+["'][^>]*>\s*(\d+)\s*Like''',
    caseSensitive: false,
    dotAll: true,
  );

  /// The markup exposes only the commenter's avatar URL and the body — there
  /// is no username and no timestamp to scrape.
  static final _commentPattern = RegExp(
    r'''<div class="w-10 h-10 rounded-full relative flex-shrink-0">\s*<img src=["']([^"']+)["'][^>]*>\s*</div>\s*<div class="text-gray-700 py-2 px-3 rounded-md bg-gray-100[^"]*"[^>]*>\s*<p class="leading-6">(.*?)</p>''',
    caseSensitive: false,
    dotAll: true,
  );

  static final _thumbnailSuffixPattern =
      RegExp(r'_300px\.[a-z0-9]+$', caseSensitive: false);

  static final _challengeMarkers = <Pattern>[
    'Just a moment...',
    'cf-mitigated',
    'challenges.cloudflare.com',
    'Enable JavaScript and cookies to continue',
  ];

  /// Whether the body is Cloudflare's JS interstitial rather than content.
  ///
  /// The site puts the HTML pages behind a managed challenge. Media on the
  /// apex host is served without it, so only document requests are affected —
  /// which is why a request can 403 here while the very same client fetches
  /// images from the same domain.
  static bool _isChallenge(String body) {
    if (body.isEmpty) return false;
    final head = body.substring(0, body.length.clamp(0, 4000));
    return _challengeMarkers.any(head.contains);
  }

  static const _challengeMessage =
      'Fapello is behind a Cloudflare challenge that blocks automated '
      'requests. Only media downloads go through; the pages cannot be read '
      'from the app.';

  Future<String> _getHtml(String path) async {
    final response = await _dio.get<String>(path, options: _htmlOptions);
    final status = response.statusCode ?? 0;
    final body = response.data is String ? response.data as String : '';
    if (status == 403 || status == 503) {
      if (_isChallenge(body)) {
        throw const ProviderUnavailableException(_challengeMessage);
      }
    }
    if (status < 200 || status >= 300) {
      throw BadResponseException('HTTP $status');
    }
    return body;
  }

  @override
  Future<List<Post>> searchPosts({
    required List<String> tags,
    required int page,
    int limit = 50,
    String? rating,
    TopPeriodFilter topPeriod = TopPeriodFilter.none,
    CancelToken? cancelToken,
  }) async =>
      // Fapello is registered as an artist provider, so the feed never routes
      // a query here, and there is no booru-style post listing to scrape.
      const [];

  @override
  Future<Post?> getPost(String postId) async {
    final parsed = _parseMediaId(postId);
    if (parsed == null) return null;
    final (slug, mediaId) = parsed;
    try {
      final html = await _getHtml('/$slug/$mediaId/');
      if (html.trim().isEmpty) return null;
      // Snapshot sendable locals — the parse closure must not capture `this`.
      final providerId = id;
      final providerName = name;
      return await Isolate.run(
          () => _postFromDetailPage(slug, mediaId, html,
              providerId: providerId, providerName: providerName));
    } catch (_) {
      return null;
    }
  }

  @override
  Future<ProviderHealth> checkHealth() async {
    final sw = Stopwatch()..start();
    try {
      final html = await _getHtml('/top-likes/');
      sw.stop();
      final healthy = html.isNotEmpty && _modelCardPattern.hasMatch(html);
      return ProviderHealth(
        providerId: id,
        status: healthy ? ProviderStatus.online : ProviderStatus.offline,
        pingMs: healthy ? sw.elapsedMilliseconds : 0,
        lastCheckedAt: DateTime.now(),
        apiVersion: 'fapello-html',
        errorMessage: healthy ? null : 'No model cards found in HTML response',
      );
    } on AppException catch (error) {
      sw.stop();
      return ProviderHealth(
        providerId: id,
        status: ProviderStatus.offline,
        pingMs: 0,
        lastCheckedAt: DateTime.now(),
        errorMessage: error.message,
        apiVersion: 'fapello-html',
      );
    } catch (error) {
      sw.stop();
      return ProviderHealth(
        providerId: id,
        status: ProviderStatus.offline,
        pingMs: 0,
        lastCheckedAt: DateTime.now(),
        errorMessage: error.toString(),
        apiVersion: 'fapello-html',
      );
    }
  }

  @override
  Future<List<PostComment>> getComments(String postId) async {
    final parsed = _parseMediaId(postId);
    if (parsed == null) return const [];
    try {
      final html = await _getHtml('/${parsed.$1}/${parsed.$2}/');
      final providerId = id;
      return await Isolate.run(
          () => _parseCommentsHtml(html, postId, providerId: providerId));
    } catch (_) {
      return const [];
    }
  }

  @override
  Future<List<PostComment>> getArtistPostComments(
    String service,
    String artistId,
    String postId,
  ) async {
    if (artistId.isEmpty) return const [];
    return getComments('$artistId:$postId');
  }

  @override
  String? postPageUrl(Post post) {
    final parsed = _parseMediaId(post.id);
    if (parsed == null) return null;
    return 'https://fapello.com/${parsed.$1}/${parsed.$2}/';
  }

  @override
  Map<String, String> mediaHeaders(Post post) => {
        'User-Agent': AppHeaders.desktopChromeUserAgent,
        'Referer': '$baseUrl/',
        'Accept': '*/*',
      };

  @override
  Future<List<ArtistProfile>> listArtists({
    String? service,
    List<String>? services,
    String? query,
    int page = 1,
    int limit = 30,
  }) async {
    final requested = <String>[
      ...?services?.where((value) => value.trim().isNotEmpty),
      if ((service ?? '').isNotEmpty) service!,
    ];
    if (requested.isNotEmpty &&
        !requested.any((value) => value.toLowerCase() == _service)) {
      return const [];
    }

    final trimmed = (query ?? '').trim();
    if (trimmed.isNotEmpty && page > 1) {
      // Search is a single un-paged result set; asking again would only
      // duplicate the same models.
      return const [];
    }

    final html = trimmed.isEmpty
        ? await _getHtml(_modelListPath(page))
        : await _getHtml('/search/${Uri.encodeQueryComponent(trimmed)}/');
    final cards = await _parseModelCards(html);
    // Paging terminates on the first empty page. The `/top-likes/` listing
    // keeps returning new models well past its own `data-max` marker, and
    // eventually 302-redirects to the post feed, which yields no model cards.
    return cards.take(limit).toList(growable: false);
  }

  @override
  Future<List<ArtistProfile>> searchArtists(
    String query, {
    String? service,
    List<String>? services,
    int page = 1,
    int limit = 30,
  }) =>
      listArtists(
        service: service,
        services: services,
        query: query,
        page: page,
        limit: limit,
      );

  @override
  Future<List<ArtistTag>> getArtistTags(
          String service, String artistId) async =>
      const [];

  @override
  Future<List<ArtistLink>> getArtistLinks(
          String service, String artistId) async =>
      const [];

  @override
  Future<List<ArtistAnnouncement>> getArtistAnnouncements(
          String service, String artistId) async =>
      const [];

  @override
  Future<List<Post>> getArtistPosts({
    required ArtistWorkQuery query,
    int page = 0,
    int limit = 50,
  }) async {
    final slug = query.artistId.trim();
    if (slug.isEmpty) return const [];
    // `page` is 0-based here while the site is 1-based.
    final path = '/ajax/model/${Uri.encodeComponent(slug)}/page-${page + 1}/';
    final html = await _getHtml(path);
    if (html.trim().isEmpty) return const [];

    final artistName =
        query.artistName.trim().isNotEmpty ? query.artistName.trim() : slug;
    final items = await _parseMediaItems(html, slug);
    final posts = <Post>[];
    for (final item in items) {
      posts.add(_postFromMediaItem(
        item,
        slug: slug,
        artistName: artistName,
      ));
      if (posts.length >= limit) break;
    }
    return posts;
  }

  // ---------------------------------------------------------------- listing

  String _modelListPath(int page) =>
      page <= 1 ? '/top-likes/' : '/top-likes/page-$page/';

  Future<List<ArtistProfile>> _parseModelCards(String html) {
    final providerId = id;
    // Parsing the listing page runs regexes over 100s of KB of HTML — keep
    // it off the UI thread.
    return Isolate.run(() => _parseModelCardsHtml(html, providerId));
  }

  static List<ArtistProfile> _parseModelCardsHtml(
    String html,
    String providerId,
  ) {
    final section = _listingSection(html);
    final seen = <String>{};
    final profiles = <ArtistProfile>[];
    for (final match in _modelCardPattern.allMatches(section)) {
      final slug = match.group(2) ?? '';
      if (slug.isEmpty || !seen.add(slug)) continue;

      final row = match.group(3) ?? '';
      final avatar = _imgSrcPattern.firstMatch(row)?.group(1) ?? '';
      if (avatar.contains('/assets/exclusive/')) continue;

      final displayName = _bareText(row).trim();
      profiles.add(ArtistProfile(
        id: slug,
        providerId: providerId,
        service: _service,
        name: slug,
        displayName: displayName.isEmpty ? slug : displayName,
        url: 'https://fapello.com/$slug/',
        avatarUrl: avatar.isEmpty ? null : avatar,
      ));
    }
    return profiles;
  }

  // ------------------------------------------------------------- media grid

  Future<List<_MediaItem>> _parseMediaItems(String html, String expectedSlug) {
    return Isolate.run(() => _parseMediaItemsHtml(html, expectedSlug));
  }

  static List<_MediaItem> _parseMediaItemsHtml(
    String html,
    String expectedSlug,
  ) {
    final section = _listingSection(html);
    final items = <_MediaItem>[];
    for (final match in _mediaItemPattern.allMatches(section)) {
      final slug = match.group(2) ?? '';
      final mediaId = match.group(3) ?? '';
      if (slug.isEmpty || mediaId.isEmpty) continue;
      if (expectedSlug.isNotEmpty && slug != expectedSlug) continue;

      final body = match.group(4) ?? '';
      final thumbnailUrl = _imgSrcPattern.firstMatch(body)?.group(1) ?? '';
      if (thumbnailUrl.isEmpty) continue;

      items.add(_MediaItem(
        mediaId: mediaId,
        thumbnailUrl: thumbnailUrl,
        isVideo: _playIconPattern.hasMatch(body),
      ));
    }
    return items;
  }

  Post _postFromMediaItem(
    _MediaItem item, {
    required String slug,
    required String artistName,
  }) {
    final previewUrl = item.thumbnailUrl;
    final posterUrl = _fullMediaUrl(previewUrl);
    return Post(
      id: '$slug:${item.mediaId}',
      providerId: id,
      providerName: name,
      previewUrl: previewUrl,
      sampleUrl: posterUrl,
      fileUrl: item.isVideo ? _videoUrl(previewUrl) : posterUrl,
      tags: const [],
      rating: 'explicit',
      width: 0,
      height: 0,
      source: 'https://fapello.com/$slug/${item.mediaId}/',
      // The site exposes no upload date. Scaling the file id keeps the
      // newest-first grid order intact whenever something sorts by date.
      createdAt: _pseudoDate(item.mediaId),
      fileType: item.isVideo ? 'video' : 'image',
      score: 0,
      tagGroups: {
        'artist': [artistName]
      },
    );
  }

  // ------------------------------------------------------------ detail page

  static Post? _postFromDetailPage(
    String slug,
    String mediaId,
    String html, {
    required String providerId,
    required String providerName,
  }) {
    final imageMatch = _fullImagePattern.firstMatch(html);
    if (imageMatch != null) {
      final fileUrl = imageMatch.group(1) ?? '';
      if (fileUrl.isEmpty) return null;
      final alt = _decodeHtml(
        _imgAltPattern.firstMatch(imageMatch.group(2) ?? '')?.group(1) ?? '',
      );
      return _buildPost(
        providerId: providerId,
        providerName: providerName,
        slug: slug,
        mediaId: mediaId,
        previewUrl: _thumbnailFromMediaUrl(fileUrl),
        fileUrl: fileUrl,
        fileType: 'image',
        title: alt.isEmpty ? _pageTitle(html) : alt,
        html: html,
      );
    }

    final videoMatch = _videoSourcePattern.firstMatch(html);
    if (videoMatch != null) {
      final fileUrl = videoMatch.group(1) ?? '';
      if (fileUrl.isEmpty) return null;
      final poster = _videoPosterPattern.firstMatch(html)?.group(1) ?? '';
      final posterUrl =
          poster.isEmpty ? _thumbnailFromMediaUrl(fileUrl) : poster;
      return _buildPost(
        providerId: providerId,
        providerName: providerName,
        slug: slug,
        mediaId: mediaId,
        previewUrl: posterUrl,
        fileUrl: fileUrl,
        fileType: 'video',
        title: _pageTitle(html),
        html: html,
      );
    }
    return null;
  }

  static Post _buildPost({
    required String providerId,
    required String providerName,
    required String slug,
    required String mediaId,
    required String previewUrl,
    required String fileUrl,
    required String fileType,
    required String title,
    required String html,
  }) {
    final tags = _parseDetailTags(html);
    final groups = <String, List<String>>{
      'artist': [title.isEmpty ? slug : title],
    };
    if (title.isNotEmpty) groups['copyright'] = [title];
    if (tags.isNotEmpty) groups['general'] = tags;
    return Post(
      id: '$slug:$mediaId',
      providerId: providerId,
      providerName: providerName,
      previewUrl: previewUrl,
      sampleUrl: previewUrl,
      fileUrl: fileUrl,
      tags: tags,
      rating: 'explicit',
      width: 0,
      height: 0,
      source: 'https://fapello.com/$slug/$mediaId/',
      createdAt: _pseudoDate(mediaId),
      fileType: fileType,
      score: _parseLikeCount(html),
      tagGroups: groups,
    );
  }

  static DateTime _pseudoDate(String mediaId) {
    final numeric = int.tryParse(mediaId) ?? 0;
    return DateTime.fromMillisecondsSinceEpoch(
      numeric.clamp(0, 1 << 40) * 1000,
    );
  }

  static int _parseLikeCount(String html) =>
      int.tryParse(_likeCountPattern.firstMatch(html)?.group(1) ?? '') ?? 0;

  static List<String> _parseDetailTags(String html) {
    final tags = <String>[];
    for (final match in _detailTagPattern.allMatches(html)) {
      final name = (match.group(2) ?? '').trim();
      if (name.isNotEmpty) tags.add(name);
    }
    return tags;
  }

  static String _pageTitle(String html) {
    final match =
        RegExp(r'<title>(.*?)</title>', caseSensitive: false).firstMatch(html);
    if (match == null) return '';
    return _decodeHtml(match.group(1)!)
        .replaceAll(RegExp(r'\s*[|–-]\s*Fapello\s*$', caseSensitive: false), '')
        .trim();
  }

  static List<PostComment> _parseCommentsHtml(
    String html,
    String postId, {
    required String providerId,
  }) {
    final comments = <PostComment>[];
    var index = 0;
    for (final match in _commentPattern.allMatches(html)) {
      final body = _decodeHtml(match.group(2) ?? '').trim();
      if (body.isEmpty) continue;
      comments.add(PostComment(
        id: '${postId}_$index',
        postId: postId,
        providerId: providerId,
        authorName: '',
        body: body,
        createdAt: DateTime.fromMillisecondsSinceEpoch(0),
      ));
      index++;
    }
    return comments;
  }

  // ------------------------------------------------------------------- urls

  /// `..._0009_300px.jpg` -> `..._0009.jpg`
  static String _fullMediaUrl(String thumbnailUrl) {
    if (thumbnailUrl.isEmpty) return '';
    final uri = Uri.tryParse(thumbnailUrl);
    if (uri == null) return thumbnailUrl;
    final extension = uri.path.split('.').last;
    final path = uri.path.replaceFirst(_thumbnailSuffixPattern, '.$extension');
    return uri.replace(path: path).toString();
  }

  /// `..._0009_300px.jpg` -> mp4 on the dedicated CDN host.
  static String _videoUrl(String thumbnailUrl) {
    if (thumbnailUrl.isEmpty) return '';
    final uri = Uri.tryParse(thumbnailUrl);
    if (uri == null) return thumbnailUrl;
    final path = uri.path.replaceFirst(_thumbnailSuffixPattern, '.mp4');
    return uri.replace(host: _mediaCdnHost, path: path).toString();
  }

  static String _thumbnailFromMediaUrl(String mediaUrl) {
    if (mediaUrl.isEmpty) return '';
    final uri = Uri.tryParse(mediaUrl);
    if (uri == null) return mediaUrl;
    final segments = uri.pathSegments;
    if (segments.isEmpty) return mediaUrl;
    final last = segments.last;
    final dot = last.lastIndexOf('.');
    if (dot <= 0) return mediaUrl;
    final thumbnailName =
        '${last.substring(0, dot)}_300px.${last.substring(dot + 1)}';
    return uri.replace(
      pathSegments: [
        ...segments.sublist(0, segments.length - 1),
        thumbnailName,
      ],
    ).toString();
  }

  // ---------------------------------------------------------------- parsing

  /// Restricts parsing to the repeating list area when the page wraps it in
  /// `#content`, so navigation, sidebar and footer links can never be mistaken
  /// for items.
  static String _listingSection(String html) {
    final start = html.indexOf('id="content"');
    final body = start >= 0 ? html.substring(start) : html;
    var end = body.length;
    for (final marker in ['id="showmore"', 'id="next_page"']) {
      final found = body.indexOf(marker);
      if (found >= 0 && found < end) end = found;
    }
    return body.substring(0, end);
  }

  /// Text of the bare `<div>` holding the display name inside a card row.
  static String _bareText(String html) {
    String? last;
    for (final match
        in RegExp(r'<div>\s*(.*?)\s*</div>', dotAll: true).allMatches(html)) {
      last = match.group(1);
    }
    return _decodeHtml(last ?? '');
  }

  (String, String)? _parseMediaId(String postId) {
    final parts = postId.split(':');
    if (parts.length < 2) return null;
    final slug = parts[0].trim();
    final mediaId = parts[1].trim();
    if (slug.isEmpty || mediaId.isEmpty) return null;
    return (slug, mediaId);
  }

  static String _decodeHtml(String input) {
    if (!input.contains('&')) return input;
    return input.replaceAllMapped(
      RegExp(r'&(#x?[0-9a-f]+|[a-z][a-z0-9]+);', caseSensitive: false),
      (match) {
        final entity = match.group(1)!;
        if (entity.startsWith('#')) {
          final isHex =
              entity.length > 1 && (entity[1] == 'x' || entity[1] == 'X');
          final code = int.tryParse(
            isHex ? entity.substring(2) : entity.substring(1),
            radix: isHex ? 16 : 10,
          );
          if (code != null && code > 0 && code <= 0x10FFFF) {
            return String.fromCharCode(code);
          }
          return match.group(0)!;
        }
        return switch (entity) {
          'amp' => '&',
          'lt' => '<',
          'gt' => '>',
          'quot' => '"',
          'apos' => "'",
          'nbsp' => ' ',
          'mdash' => '—',
          'ndash' => '–',
          'hellip' => '…',
          _ => match.group(0)!,
        };
      },
    );
  }
}

class _MediaItem {
  const _MediaItem({
    required this.mediaId,
    required this.thumbnailUrl,
    required this.isVideo,
  });

  final String mediaId;
  final String thumbnailUrl;
  final bool isVideo;
}
