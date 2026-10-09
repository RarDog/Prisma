import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gel_rule_app/core/errors/app_exception.dart';
import 'package:gel_rule_app/core/http/dio_client.dart';
import 'package:gel_rule_app/core/models/post.dart';
import 'package:gel_rule_app/core/models/provider_health.dart';
import 'package:gel_rule_app/core/models/top_period_filter.dart';
import 'package:gel_rule_app/features/artists/models/artist_work_query.dart';
import 'package:gel_rule_app/features/providers/models/content_provider_config.dart';
import 'package:gel_rule_app/sources/booru/fapello_provider.dart';
import 'package:gel_rule_app/sources/provider_factory.dart';

class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.handler);

  final Future<ResponseBody> Function(RequestOptions options) handler;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<dynamic>? requestStream,
    Future<void>? cancelFuture,
  ) =>
      handler(options);

  @override
  void close({bool force = false}) {}
}

/// Cloudflare's JS interstitial: same 403 as a real rejection, different body.
String _challenge(String marker) => '<!DOCTYPE html><html lang="en-US"><head>'
    '<title>Just a moment...</title>'
    '<meta http-equiv="Content-Type" content="text/html; charset=UTF-8">'
    '</head><body><div id="challenge-running">$marker</div>'
    '<script src="https://challenges.cloudflare.com/turnstile/v0/api.js">'
    '</script></body></html>';

ResponseBody _blocked(String body) => ResponseBody.fromString(body, 403);

const _baseUrl = 'https://fapello.com';

ResponseBody _html(String body) => ResponseBody.fromString(
      body,
      200,
      headers: {
        Headers.contentTypeHeader: ['text/html; charset=utf-8'],
      },
    );

FapelloProvider _providerWith(
  Dio dio, {
  String id = 'fapello',
  String name = 'Fapello',
}) {
  dio.options.baseUrl = _baseUrl;
  return FapelloProvider(
    id: id,
    name: name,
    baseUrl: _baseUrl,
    dioClient: DioClient(dio: dio),
  );
}

/// `/top-likes/` page 1: two real models plus one sponsored card.
const _topLikesPage1 = '''
<html><body>
<div id="content">
<div class="mt-6 grid lg:grid-cols-3 grid-cols-2 gap-3">
  <div>
    <div class="bg-yellow-400 max-w-full lg:h-72 h-48 rounded-lg relative overflow-hidden shadow uk-transition-toggle">
      <a href="https://fapello.com/soyisabelasalar/">
        <img src="https://fapello.com/content/s/o/soyisabelasalar/1000/soyisabelasalar_0080_300px.jpg" class="w-full h-full absolute object-cover inset-0">
      </a>
      <div class="flex flex-1 items-center absolute bottom-0 w-full p-3 text-white custom-overly1">
        <a href="https://fapello.com/soyisabelasalar/" class="lg:flex flex-1 items-center" >
          <div class="p-1 rounded-full transform -rotate-2 hover:rotate-3 transition hover:scale-105 m-0.5 mr-2">
            <img src="https://fapello.com/content/s/o/soyisabelasalar/1000/soyisabelasalar_0014.jpg" class="bg-gray-200 border border-white rounded-full w-8">
          </div>
          <div> soyisabelasalar </div>
        </a>
      </div>
    </div>
  </div>
  <div>
    <div class="bg-yellow-400 max-w-full lg:h-60 h-48 rounded-lg relative overflow-hidden shadow uk-transition-toggle">
      <a href="https://onlyfans.com/mariah_970/trial/abc" target="_blank">
        <img src="https://fapello.com/assets/exclusive/mariah-970-2.jpg" class="w-full h-full absolute object-cover inset-0">
      </a>
      <div class="flex flex-1 items-center absolute bottom-0 w-full p-3 text-white custom-overly1">
        <a href="https://onlyfans.com/mariah_970/trial/abc" class="lg:flex flex-1 items-center" target="_blank">
          <div class="p-1 rounded-full transform -rotate-2 hover:rotate-3 transition hover:scale-105 m-0.5 mr-2">
            <img src="http://fapello.com/assets/exclusive/hot.png" class="bg-gray-200 border border-white rounded-full w-8">
          </div>
          <div> Mariah 970 </div>
        </a>
      </div>
    </div>
  </div>
  <div>
    <div class="bg-yellow-400 max-w-full lg:h-72 h-48 rounded-lg relative overflow-hidden shadow uk-transition-toggle">
      <a href="https://fapello.com/trixie-foopahh-2/">
        <img src="https://fapello.com/content/t/r/trixie-foopahh-2/1000/trixie-foopahh-2_0041_300px.jpg" class="w-full h-full absolute object-cover inset-0">
      </a>
      <div class="flex flex-1 items-center absolute bottom-0 w-full p-3 text-white custom-overly1">
        <a href="https://fapello.com/trixie-foopahh-2/" class="lg:flex flex-1 items-center" >
          <div class="p-1 rounded-full transform -rotate-2 hover:rotate-3 transition hover:scale-105 m-0.5 mr-2">
            <img src="https://fapello.com/assets/images/avatar.jpg" class="bg-gray-200 border border-white rounded-full w-8">
          </div>
          <div> Trixie Foopahh </div>
        </a>
      </div>
    </div>
  </div>
</div>
</div>
<div id="showmore" class="showmore" data-page="1" data-max="100">
  <img class="showmore" src="https://fapello.com/assets/images/load.svg" alt="">
</div>
<div id="next_page" class="flex justify-center mt-6">
  <a href="https://fapello.com/top-likes/page-2/" class="rounded-full shadow-md">Next Page</a>
</div>
</body></html>
''';

const _searchPage = '''
<html><body>
<div id="content">
<div class="my-3 grid lg:grid-cols-4 grid-cols-2 gap-3">
  <div>
    <div class="bg-red-400 max-w-full lg:h-56 h-48 rounded-lg relative overflow-hidden shadow uk-transition-toggle">
      <a href="https://fapello.com/thiessita/">
        <img src="https://fapello.com/content/t/h/thiessita/1000/thiessita_0050_300px.jpg" class="w-full h-full absolute object-cover inset-0">
      </a>
      <div class="flex flex-1 items-center absolute bottom-0 w-full p-3 text-white custom-overly1">
        <a href="https://fapello.com/thiessita/" class="lg:flex flex-1 items-center">
          <div class="p-1 rounded-full transform -rotate-2 hover:rotate-3 transition hover:scale-105 m-0.5 mr-2">
            <img src="https://fapello.com/content/t/h/thiessita/1000/thiessita_0009.jpg" class="bg-gray-200 border border-white rounded-full w-8">
          </div>
          <div> Thiessita </div>
        </a>
      </div>
    </div>
  </div>
  <div>
    <div class="bg-red-400 max-w-full lg:h-56 h-48 rounded-lg relative overflow-hidden shadow uk-transition-toggle">
      <a href="https://fapello.com/tokyotea/">
        <img src="https://fapello.com/content/t/o/tokyotea/1000/tokyotea_0019_300px.jpg" class="w-full h-full absolute object-cover inset-0 scale-150 transform">
      </a>
      <div class="flex flex-1 items-center absolute bottom-0 w-full p-3 text-white custom-overly1">
        <a href="https://fapello.com/tokyotea/" class="lg:flex flex-1 items-center">
          <div class="p-1 rounded-full transform -rotate-2 hover:rotate-3 transition hover:scale-105 m-0.5 mr-2">
            <img src="https://fapello.com/content/t/o/tokyotea/1000/tokyotea_0007.jpg" class="bg-gray-200 border border-white rounded-full w-8">
          </div>
          <div> TokyoTea </div>
        </a>
      </div>
    </div>
  </div>
</div>
</div>
</body></html>
''';

/// Bare `/ajax/model/<slug>/page-1/` fragment: a video tile then an image tile.
const _modelPage1 = '''
<div>
	<a href="https://fapello.com/mikatanaka869/9/">
		<div class="max-w-full lg:h-64 h-40 rounded-md relative overflow-hidden uk-transition-toggle" tabindex="0">
			<img src="https://fapello.com/content/m/i/mikatanaka869/1000/mikatanaka869_0009_300px.jpg" class="w-full h-full absolute object-cover inset-0">
			<div class="absolute flex h-full items-center justify-center w-8 w-full  bg-black bg-opacity-10">
				<img src="https://fapello.com/assets/images/icon-play.svg" alt="" class="w-16 h-16">
			</div>
		</div>
	</a>
</div>
<div>
	<a href="https://fapello.com/mikatanaka869/8/">
		<div class="max-w-full lg:h-64 h-40 rounded-md relative overflow-hidden uk-transition-toggle" tabindex="0">
			<img src="https://fapello.com/content/m/i/mikatanaka869/1000/mikatanaka869_0008_300px.jpg" class="w-full h-full absolute object-cover inset-0">
		</div>
	</a>
</div>
''';

const _imageDetailPage = '''
<html><head><title>Thiessa / Thiessita Nude Leaked  Photo #50  - Fapello</title></head><body>
<div id="content">
<div class="bg-white shadow rounded-md dark:bg-gray-900 -mx-2 lg:mx-0">
  <div class="flex justify-between items-center p-5 border-b">
    <div class="flex flex-1 items-center space-x-4">
      <a href="https://fapello.com/thiessita/">
        <img src="https://fapello.com/content/t/h/thiessita/1000/thiessita_0009.jpg" class="rounded-full w-10 h-10">
      </a>
      <a href="https://fapello.com/thiessita/" class="block capitalize font-semibold text-lg"> Thiessita</a>
      <span class="text-gray-400 text-base ml-2">Photo #50</span>
    </div>
  </div>
  <div class="flex justify-between items-center">
    <a href="https://fapello.com/content/t/h/thiessita/1000/thiessita_0050.jpg" target="_blank" class="uk-align-center">
      <img src="https://fapello.com/content/t/h/thiessita/1000/thiessita_0050.jpg" alt="Thiessa / Thiessita Nude Leaked  Photo #50">
    </a>
  </div>
  <div class="flex items-center" id="count_likes_30879094"> 5 Likes </div>
  <div class="flex space-x-5 py-2 px-5 border-b">
    <div class="flex-1 tags-chips">
      <a href="https://fapello.com/tags/solo/" class="hover:underline tags-chip">#solo</a>
      <a href="https://fapello.com/tags/pov/" class="hover:underline tags-chip">#pov</a>
    </div>
  </div>
  <a name="comments"></a>
  <div class="border-t pt-4 space-y-4 dark:border-gray-600">
    <div class="flex">
      <div class="w-10 h-10 rounded-full relative flex-shrink-0">
        <img src="https://fapello.com/data/avatars/default/1459581.png" alt="" class="absolute h-full rounded-full w-full">
      </div>
      <div class="text-gray-700 py-2 px-3 rounded-md bg-gray-100 h-full relative lg:ml-5 ml-2 lg:mr-20  dark:bg-gray-800 dark:text-gray-100">
        <p class="leading-6">Nice</p>
        <div class="absolute w-3 h-3 top-3 -left-1 bg-gray-100 transform rotate-45 dark:bg-gray-700"></div>
      </div>
    </div>
    <div class="flex">
      <div class="w-10 h-10 rounded-full relative flex-shrink-0">
        <img src="https://fapello.com/data/avatars/000/030/676.jpg" alt="" class="absolute h-full rounded-full w-full">
      </div>
      <div class="text-gray-700 py-2 px-3 rounded-md bg-gray-100 h-full relative lg:ml-5 ml-2 lg:mr-20  dark:bg-gray-800 dark:text-gray-100">
        <p class="leading-6">69 &amp; Every Position</p>
        <div class="absolute w-3 h-3 top-3 -left-1 bg-gray-100 transform rotate-45 dark:bg-gray-700"></div>
      </div>
    </div>
  </div>
</div>
</div>
</body></html>
''';

const _videoDetailPage = '''
<html><head><title>Mikatanaka869 Video #9  - Fapello</title></head><body>
<div id="content">
<div class="bg-white shadow rounded-md dark:bg-gray-900 -mx-2 lg:mx-0">
  <div class="flex justify-between items-center p-5 border-b">
    <a href="https://fapello.com/mikatanaka869/" class="block capitalize font-semibold text-lg"> Mikatanaka869</a>
    <span class="text-gray-400 text-base ml-2">Video #9</span>
  </div>
  <div class="flex justify-between items-center">
    <video class="uk-align-center" poster="https://fapello.com/content/m/i/mikatanaka869/1000/mikatanaka869_0009.jpg" preload="metadata" controls="controls"><source type="video/mp4" src="https://cdn.fapello.com/content/m/i/mikatanaka869/1000/mikatanaka869_0009.mp4" /></video>
  </div>
  <div class="flex items-center" id="count_likes_32565377"> 12 Likes </div>
  <div class="flex space-x-5 py-2 px-5 border-b">
    <div class="flex-1 tags-chips">
      <a href="https://fapello.com/tags/cameltoe-fetish/" class="hover:underline tags-chip">#cameltoe-fetish</a>
    </div>
  </div>
</div>
</div>
</body></html>
''';

/// Reused by the metadata group so each test does not repeat the constructor.
Post _stub([String id = 'thiessita:50']) => Post(
      id: id,
      providerId: 'fapello',
      providerName: 'Fapello',
      previewUrl: '',
      sampleUrl: '',
      fileUrl: '',
      tags: const [],
      rating: 'explicit',
      width: 0,
      height: 0,
      createdAt: DateTime.utc(2026),
      fileType: 'image',
      score: 0,
    );

/// Reused by the metadata group so each test does not repeat the constructor.
final _stubPost = _stub();

void main() {
  group('ProviderFactory', () {
    test('creates a FapelloProvider for the fapello apiType', () {
      final provider = ProviderFactory().create(
        ContentProviderConfig(
          id: 'fapello',
          name: 'Fapello',
          baseUrl: _baseUrl,
          apiType: 'fapello',
          enabled: true,
          priority: 12,
          timeoutSeconds: 25,
          customHeaders: const {},
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
        ),
      );
      expect(provider, isA<FapelloProvider>());
      expect(provider.id, 'fapello');
      expect(provider.baseUrl, _baseUrl);
    });
  });

  group('FapelloProvider artist listing', () {
    late Dio dio;

    setUp(() => dio = Dio());

    test('parses model cards from /top-likes/ and drops sponsored ones',
        () async {
      dio.httpClientAdapter = _FakeAdapter((options) async {
        expect(options.path, '/top-likes/');
        return _html(_topLikesPage1);
      });
      final provider = _providerWith(dio);

      final artists = await provider.listArtists();

      expect(artists.map((a) => a.id), ['soyisabelasalar', 'trixie-foopahh-2']);
      final first = artists.first;
      expect(first.service, 'fapello');
      expect(first.providerId, 'fapello');
      expect(first.displayName, 'soyisabelasalar');
      expect(first.url, 'https://fapello.com/soyisabelasalar/');
      expect(
        first.avatarUrl,
        'https://fapello.com/content/s/o/soyisabelasalar/1000/'
            'soyisabelasalar_0014.jpg',
      );
      // A default placeholder avatar is kept; the UI falls back to initials.
      expect(
        artists.last.avatarUrl,
        'https://fapello.com/assets/images/avatar.jpg',
      );
    });

    test('walks top-likes pages until one comes back empty', () async {
      final requested = <String>[];
      dio.httpClientAdapter = _FakeAdapter((options) async {
        requested.add(options.path);
        switch (options.path) {
          case '/top-likes/':
          case '/top-likes/page-2/':
            return _html(_topLikesPage1);
          case '/top-likes/page-3/':
            // The listing eventually 302-redirects to the post feed, which
            // carries no model cards.
            return _html('<html><body><div id="content" class="space-y-5">'
                '</div></body></html>');
          default:
            fail('unexpected request: ${options.path}');
        }
      });
      final provider = _providerWith(dio);

      expect((await provider.listArtists(page: 1)).length, 2);
      expect((await provider.listArtists(page: 2)).length, 2);
      expect(await provider.listArtists(page: 3), isEmpty);
      expect(requested, [
        '/top-likes/',
        '/top-likes/page-2/',
        '/top-likes/page-3/',
      ]);
    });

    test('keeps paging past the site data-max marker', () async {
      // `data-max` is not a hard cap: the site serves fresh models well
      // beyond it, so the provider must not clamp on it.
      final requested = <String>[];
      dio.httpClientAdapter = _FakeAdapter((options) async {
        requested.add(options.path);
        expect(options.path, '/top-likes/page-101/');
        return _html(_topLikesPage1);
      });
      final provider = _providerWith(dio);

      expect((await provider.listArtists(page: 101)).length, 2);
    });

    test('skips providers that do not carry the requested service', () async {
      dio.httpClientAdapter = _FakeAdapter((options) async => fail('no request'));
      final provider = _providerWith(dio);

      expect(await provider.listArtists(services: const ['patreon']), isEmpty);
      expect(await provider.listArtists(service: 'fanbox'), isEmpty);
    });

    test('searchArtists hits /search/<q>/', () async {
      dio.httpClientAdapter = _FakeAdapter((options) async {
        expect(options.path, '/search/thiessita/');
        return _html(_searchPage);
      });
      final provider = _providerWith(dio);

      final artists = await provider.searchArtists('thiessita');
      expect(artists.map((a) => a.id), ['thiessita', 'tokyotea']);
      expect(artists.first.displayName, 'Thiessita');
    });

    test('search results are un-paged, so page 2 is empty', () async {
      final paths = <String>[];
      dio.httpClientAdapter = _FakeAdapter((options) async {
        paths.add(options.path);
        return _html(_searchPage);
      });
      final provider = _providerWith(dio);

      expect((await provider.searchArtists('thiessita', page: 1)).length, 2);
      expect(await provider.searchArtists('thiessita', page: 2), isEmpty);
      expect(paths, ['/search/thiessita/']);
    });
  });

  group('FapelloProvider posts', () {
    late Dio dio;

    setUp(() => dio = Dio());

    test('reads the media grid from the ajax fragment', () async {
      dio.httpClientAdapter = _FakeAdapter((options) async {
        expect(options.path, '/ajax/model/mikatanaka869/page-1/');
        return _html(_modelPage1);
      });
      final provider = _providerWith(dio);

      const query = ArtistWorkQuery(
        providerId: 'fapello',
        service: 'fapello',
        artistId: 'mikatanaka869',
        artistName: 'Mikatanaka869',
      );
      final posts = await provider.getArtistPosts(query: query);

      expect(posts.length, 2);
      // Grid order is newest first and is preserved: the pseudo timestamp is
      // derived from the file id so it stays monotonic with the grid order.
      expect(posts.map((p) => p.id), [
        'mikatanaka869:9',
        'mikatanaka869:8',
      ]);
      expect(
        posts.first.createdAt.isAfter(posts.last.createdAt),
        isTrue,
      );
    });

    test('derives video URLs from the poster thumbnail', () async {
      dio.httpClientAdapter =
          _FakeAdapter((options) async => _html(_modelPage1));
      final provider = _providerWith(dio);
      final posts = await provider.getArtistPosts(
        query: const ArtistWorkQuery(
          providerId: 'fapello',
          service: 'fapello',
          artistId: 'mikatanaka869',
          artistName: 'Mikatanaka869',
        ),
      );

      final video = posts.first;
      expect(video.fileType, 'video');
      expect(
        video.fileUrl,
        'https://cdn.fapello.com/content/m/i/mikatanaka869/1000/'
            'mikatanaka869_0009.mp4',
      );
      expect(
        video.sampleUrl,
        'https://fapello.com/content/m/i/mikatanaka869/1000/'
            'mikatanaka869_0009.jpg',
      );
      expect(
        video.previewUrl,
        'https://fapello.com/content/m/i/mikatanaka869/1000/'
            'mikatanaka869_0009_300px.jpg',
      );
    });

    test('derives image URLs from the poster thumbnail', () async {
      dio.httpClientAdapter =
          _FakeAdapter((options) async => _html(_modelPage1));
      final provider = _providerWith(dio);
      final posts = await provider.getArtistPosts(
        query: const ArtistWorkQuery(
          providerId: 'fapello',
          service: 'fapello',
          artistId: 'mikatanaka869',
          artistName: 'Mikatanaka869',
        ),
      );

      final image = posts.last;
      expect(image.fileType, 'image');
      expect(
        image.fileUrl,
        'https://fapello.com/content/m/i/mikatanaka869/1000/'
            'mikatanaka869_0008.jpg',
      );
      expect(image.sampleUrl, image.fileUrl);
      expect(image.rating, 'explicit');
      expect(image.source, 'https://fapello.com/mikatanaka869/8/');
    });

    test('pages through the grid with a 0-based page argument', () async {
      final paths = <String>[];
      dio.httpClientAdapter = _FakeAdapter((options) async {
        paths.add(options.path);
        return _html(options.path.endsWith('page-1/') ? _modelPage1 : '');
      });
      final provider = _providerWith(dio);
      const query = ArtistWorkQuery(
        providerId: 'fapello',
        service: 'fapello',
        artistId: 'mikatanaka869',
        artistName: 'Mikatanaka869',
      );

      expect((await provider.getArtistPosts(query: query, page: 0)).length, 2);
      expect(await provider.getArtistPosts(query: query, page: 1), isEmpty);
      expect(paths, [
        '/ajax/model/mikatanaka869/page-1/',
        '/ajax/model/mikatanaka869/page-2/',
      ]);
    });

    test('respects the limit', () async {
      dio.httpClientAdapter =
          _FakeAdapter((options) async => _html(_modelPage1));
      final provider = _providerWith(dio);
      final posts = await provider.getArtistPosts(
        query: const ArtistWorkQuery(
          providerId: 'fapello',
          service: 'fapello',
          artistId: 'mikatanaka869',
          artistName: 'Mikatanaka869',
        ),
        limit: 1,
      );
      expect(posts.length, 1);
      expect(posts.single.id, 'mikatanaka869:9');
    });

    test('searchPosts stays empty because fapello is artist-only', () async {
      dio.httpClientAdapter = _FakeAdapter((options) async => fail('no request'));
      final provider = _providerWith(dio);
      expect(
        await provider.searchPosts(tags: const ['solo'], page: 0),
        isEmpty,
      );
    });

    test('ignores media that belongs to a different model', () async {
      dio.httpClientAdapter = _FakeAdapter((options) async => _html(_modelPage1));
      final provider = _providerWith(dio);
      const query = ArtistWorkQuery(
        providerId: 'fapello',
        service: 'fapello',
        artistId: 'somebody-else',
        artistName: 'Somebody Else',
      );
      expect(await provider.getArtistPosts(query: query), isEmpty);
    });
  });

  group('FapelloProvider detail pages', () {
    late Dio dio;

    setUp(() => dio = Dio());

    test('parses an image media page', () async {
      dio.httpClientAdapter = _FakeAdapter((options) async {
        expect(options.path, '/thiessita/50/');
        return _html(_imageDetailPage);
      });
      final provider = _providerWith(dio);

      final post = await provider.getPost('thiessita:50');

      expect(post, isNotNull);
      expect(post!.id, 'thiessita:50');
      expect(post.fileType, 'image');
      expect(
        post.fileUrl,
        'https://fapello.com/content/t/h/thiessita/1000/thiessita_0050.jpg',
      );
      expect(post.score, 5);
      expect(post.tags, ['solo', 'pov']);
      expect(post.tagGroups['copyright'], [
        'Thiessa / Thiessita Nude Leaked  Photo #50',
      ]);
      expect(post.tagGroups['artist'], [
        'Thiessa / Thiessita Nude Leaked  Photo #50',
      ]);
      // Derived back to the 300px thumbnail for the preview.
      expect(
        post.previewUrl,
        'https://fapello.com/content/t/h/thiessita/1000/'
            'thiessita_0050_300px.jpg',
      );
    });

    test('parses a video media page', () async {
      dio.httpClientAdapter = _FakeAdapter((options) async {
        expect(options.path, '/mikatanaka869/9/');
        return _html(_videoDetailPage);
      });
      final provider = _providerWith(dio);

      final post = await provider.getPost('mikatanaka869:9');

      expect(post, isNotNull);
      expect(post!.fileType, 'video');
      expect(
        post.fileUrl,
        'https://cdn.fapello.com/content/m/i/mikatanaka869/1000/'
            'mikatanaka869_0009.mp4',
      );
      expect(post.score, 12);
      expect(post.tags, ['cameltoe-fetish']);
    });

    test('returns null for media that no longer exists', () async {
      dio.httpClientAdapter = _FakeAdapter(
        (options) async => ResponseBody.fromString('not found', 404),
      );
      final provider = _providerWith(dio);
      expect(await provider.getPost('thiessita:999'), isNull);
    });

    test('surfaces a Cloudflare challenge instead of a raw DioException',
        () async {
      dio.httpClientAdapter = _FakeAdapter((options) async {
        expect(options.path, '/top-likes/');
        return _blocked(_challenge('cf-mitigated'));
      });
      final provider = _providerWith(dio);

      await expectLater(
        provider.listArtists(),
        throwsA(isA<ProviderUnavailableException>().having(
          (error) => error.message,
          'message',
          contains('Cloudflare challenge'),
        )),
      );
    });

    test('challenge-free 403 bodies are reported as a plain HTTP error',
        () async {
      dio.httpClientAdapter = _FakeAdapter(
        (options) async => ResponseBody.fromString('forbidden', 403),
      );
      final provider = _providerWith(dio);

      await expectLater(
        provider.listArtists(),
        throwsA(isA<BadResponseException>().having(
          (error) => error.message,
          'message',
          'HTTP 403',
        )),
      );
    });

    test('media requests that redirect are not treated as errors', () async {
      // cdn.fapello.com answers media with a 302 to a signed URL; the client
      // follows it, so a redirect must never reach the challenge branch.
      dio.httpClientAdapter = _FakeAdapter((options) async {
        expect(options.path, '/ajax/model/mikatanaka869/page-1/');
        return _html(_modelPage1);
      });
      final provider = _providerWith(dio);
      final posts = await provider.getArtistPosts(
        query: const ArtistWorkQuery(
          providerId: 'fapello',
          service: 'fapello',
          artistId: 'mikatanaka869',
          artistName: 'Thiessita',
        ),
      );
      expect(posts, isNotEmpty);
    });

    test('ignores malformed post ids', () async {
      dio.httpClientAdapter = _FakeAdapter((options) async => fail('no request'));
      final provider = _providerWith(dio);
      expect(await provider.getPost('thiessita'), isNull);
      expect(await provider.getPost(':50'), isNull);
    });
  });

  group('FapelloProvider comments', () {
    test('extracts comment bodies and decodes entities', () async {
      final dio = Dio();
      dio.httpClientAdapter = _FakeAdapter((options) async {
        expect(options.path, '/africangonwild/102/');
        return _html(_imageDetailPage);
      });
      final provider = _providerWith(dio);

      final comments = await provider.getComments('africangonwild:102');

      expect(comments.length, 2);
      expect(comments.first.body, 'Nice');
      // `&amp;` is decoded, and the site exposes no author or timestamp.
      expect(comments.last.body, '69 & Every Position');
      expect(comments.every((c) => c.authorName.isEmpty), isTrue);
      expect(comments.every((c) => c.providerId == 'fapello'), isTrue);
    });

    test('getArtistPostComments composes the post id', () async {
      final dio = Dio();
      dio.httpClientAdapter = _FakeAdapter((options) async {
        expect(options.path, '/africangonwild/102/');
        return _html(_imageDetailPage);
      });
      final provider = _providerWith(dio);

      final comments = await provider.getArtistPostComments(
        'fapello',
        'africangonwild',
        '102',
      );
      expect(comments.map((c) => c.postId), ['africangonwild:102', 'africangonwild:102']);
    });
  });

  group('FapelloProvider metadata', () {
    late Dio dio;

    setUp(() => dio = Dio());

    test('postPageUrl points at the media page', () {
      final provider = _providerWith(dio);
      expect(
        provider.postPageUrl(_stubPost),
        'https://fapello.com/thiessita/50/',
      );
      expect(provider.postPageUrl(_stub('no-media-id')), isNull);
    });

    test('mediaHeaders ask for the CDN with a browser UA and referer', () {
      final provider = _providerWith(dio);
      final headers = provider.mediaHeaders(_stubPost);
      expect(headers['Referer'], '$_baseUrl/');
      expect(headers['User-Agent'], contains('Chrome'));
    });

    test('checkHealth reports online when cards are parsed', () async {
      dio.httpClientAdapter =
          _FakeAdapter((options) async => _html(_topLikesPage1));
      final provider = _providerWith(dio);

      final health = await provider.checkHealth();

      expect(health.status, ProviderStatus.online);
      expect(health.providerId, 'fapello');
      expect(health.apiVersion, 'fapello-html');
      expect(health.errorMessage, isNull);
    });

    test('checkHealth reports offline with the challenge message', () async {
      dio.httpClientAdapter = _FakeAdapter((options) async {
        expect(options.path, '/top-likes/');
        return _blocked(_challenge('Just a moment...'));
      });
      final provider = _providerWith(dio);

      final health = await provider.checkHealth();

      expect(health.status, ProviderStatus.offline);
      expect(health.errorMessage, contains('Cloudflare'));
    });

    test('checkHealth reports offline when the markup is unusable', () async {
      dio.httpClientAdapter =
          _FakeAdapter((options) async => _html('<html><body>nope</body></html>'));
      final provider = _providerWith(dio);

      final health = await provider.checkHealth();

      expect(health.status, ProviderStatus.offline);
      expect(health.errorMessage, isNotNull);
    });

    test('supports no top periods', () {
      expect(_providerWith(dio).supportedTopPeriods, {
        TopPeriodFilter.none,
      });
    });
  });
}
