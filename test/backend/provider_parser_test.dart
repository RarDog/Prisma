import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gel_rule_app/sources/mappers/danbooru_mapper.dart';
import 'package:gel_rule_app/sources/mappers/e621_mapper.dart';
import 'package:gel_rule_app/sources/mappers/gelbooru_mapper.dart';
import 'package:gel_rule_app/sources/mappers/moebooru_mapper.dart';
import 'package:gel_rule_app/sources/mappers/rule34_mapper.dart';
import 'package:gel_rule_app/features/providers/models/content_provider_config.dart';
import 'package:gel_rule_app/core/models/top_period_filter.dart';
import 'package:gel_rule_app/sources/booru/custom_provider.dart';
import 'package:gel_rule_app/sources/provider_factory.dart';
import 'package:gel_rule_app/sources/booru/realbooru_html_provider.dart';
import 'package:gel_rule_app/features/providers/data/provider_repository.dart';
import 'package:gel_rule_app/core/http/dio_client.dart';

void main() {
  test('parses Gelbooru array response', () {
    final posts = GelbooruMapper.postsFromResponse(
      [
        {
          'id': 1,
          'file_url': 'https://example.test/a.jpg',
          'sample_url': 'https://example.test/sample.jpg',
          'preview_url': 'https://example.test/preview.jpg',
          'tags': 'cat cute',
          'rating': 'safe',
          'width': '100',
          'height': '200',
          'score': '7',
        }
      ],
      providerId: 'gelbooru',
      providerName: 'Gelbooru',
    );

    expect(posts, hasLength(1));
    expect(posts.first.id, '1');
    expect(posts.first.tags, ['cat', 'cute']);
    expect(posts.first.fileType, 'image');
  });

  test('parses Gelbooru object/posts response', () {
    final posts = GelbooruMapper.postsFromResponse(
      {
        'post': [
          {'id': '2', 'file_url': 'https://example.test/b.gif'}
        ],
      },
      providerId: 'gelbooru',
      providerName: 'Gelbooru',
    );

    expect(posts.single.id, '2');
    expect(posts.single.fileType, 'gif');
  });

  test('parses Gelbooru compatible XML post response', () {
    final posts = GelbooruMapper.postsFromResponse(
      '''
      <posts count="1">
        <post id="7" file_url="https://example.test/r.jpg" preview_url="https://example.test/r-preview.jpg" tags="real booru" rating="explicit" width="300" height="400" score="12" />
      </posts>
      ''',
      providerId: 'realbooru',
      providerName: 'Realbooru',
    );

    expect(posts.single.id, '7');
    expect(posts.single.providerId, 'realbooru');
    expect(posts.single.tags, ['real', 'booru']);
    expect(posts.single.rating, 'explicit');
  });

  test('parses Gelbooru compatible tag category fields', () {
    final posts = GelbooruMapper.postsFromResponse(
      [
        {
          'id': '8',
          'file_url': 'https://example.test/cat.jpg',
          'tag_string_artist': 'artist_name',
          'tag_string_character': 'char_name',
          'tag_string_copyright': 'source_title',
          'tag_string_general': 'blue sky',
          'tag_string_meta': 'highres',
        }
      ],
      providerId: 'gelbooru',
      providerName: 'Gelbooru',
    );

    expect(posts.single.tagGroups['artist'], ['artist_name']);
    expect(posts.single.tagGroups['character'], ['char_name']);
    expect(posts.single.tagGroups['copyright'], ['source_title']);
    expect(posts.single.tagGroups['general'], ['blue', 'sky']);
    expect(posts.single.tagGroups['meta'], ['highres']);
  });

  test('parses Rule34 compatible response', () {
    final posts = Rule34Mapper.postsFromResponse(
      {
        'posts': [
          {'id': '3', 'file_url': 'https://example.test/c.webm'}
        ],
      },
      providerId: 'rule34',
      providerName: 'Rule34',
    );

    expect(posts.single.providerId, 'rule34');
    expect(posts.single.fileType, 'video');
  });

  test('parses Rule34 gif with query and file_ext', () {
    final posts = Rule34Mapper.postsFromResponse(
      {
        'posts': [
          {
            'id': '33',
            'file_url': 'https://example.test/c.gif?download=1',
            'file_ext': 'gif',
          }
        ],
      },
      providerId: 'rule34',
      providerName: 'Rule34',
    );

    expect(posts.single.fileType, 'gif');
  });

  test('parses Danbooru response', () {
    final posts = DanbooruMapper.postsFromResponse(
      [
        {
          'id': 4,
          'file_url': 'https://example.test/d.png',
          'large_file_url': 'https://example.test/large.png',
          'preview_file_url': 'https://example.test/preview.png',
          'tag_string': 'blue sky',
          'image_width': 640,
          'image_height': 480,
        }
      ],
      providerId: 'danbooru',
      providerName: 'Danbooru',
    );

    expect(posts.single.id, '4');
    expect(posts.single.previewUrl, contains('preview'));
    expect(posts.single.tags, ['blue', 'sky']);
  });

  test('parses Danbooru tag groups', () {
    final posts = DanbooruMapper.postsFromResponse(
      [
        {
          'id': 40,
          'file_url': 'https://example.test/d.jpg',
          'tag_string_general': 'blue sky',
          'tag_string_artist': 'artist_name',
          'tag_string_character': 'char_name',
        }
      ],
      providerId: 'danbooru',
      providerName: 'Danbooru',
    );

    expect(posts.single.tagGroups['artist'], ['artist_name']);
    expect(posts.single.tagGroups['character'], ['char_name']);
    expect(posts.single.tagGroups['general'], ['blue', 'sky']);
  });

  test('parses Danbooru response with media_asset variants fallback', () {
    final posts = DanbooruMapper.postsFromResponse(
      [
        {
          'id': 12345,
          'media_asset': {
            'variants': [
              {
                'type': '180x180',
                'url': 'https://cdn.donmai.us/180x180/preview.jpg',
              },
              {
                'type': 'sample',
                'url': 'https://cdn.donmai.us/sample/sample.jpg',
              },
              {
                'type': 'original',
                'url': 'https://cdn.donmai.us/original/original.jpg',
              },
            ]
          },
          'tag_string_general': 'blue_sky landscape',
        }
      ],
      providerId: 'danbooru',
      providerName: 'Danbooru',
    );

    expect(posts.single.previewUrl, 'https://cdn.donmai.us/180x180/preview.jpg');
    expect(posts.single.sampleUrl, 'https://cdn.donmai.us/sample/sample.jpg');
    expect(posts.single.fileUrl, 'https://cdn.donmai.us/original/original.jpg');
  });

  test('parses Moebooru response for yande.re and konachan', () {
    final posts = MoebooruMapper.postsFromResponse(
      [
        {
          'id': 1270940,
          'tags': 'pantyhose skirt_lift sora01o',
          'created_at': 1792481906,
          'source': 'https://www.pixiv.net/en/artworks/147279437',
          'score': 2,
          'file_size': 4722386,
          'file_ext': 'jpg',
          'file_url': 'https://files.yande.re/image/full.jpg',
          'preview_url': 'https://assets.yande.re/data/preview/thumb.jpg',
          'sample_url': 'https://files.yande.re/sample/sample.jpg',
          'rating': 's',
          'width': 2894,
          'height': 4093,
          'parent_id': 123,
          'has_children': true,
        }
      ],
      providerId: 'yandere',
      providerName: 'Yande.re',
    );

    expect(posts.single.providerId, 'yandere');
    expect(posts.single.id, '1270940');
    expect(posts.single.tags, contains('pantyhose'));
    expect(posts.single.fileUrl, 'https://files.yande.re/image/full.jpg');
    expect(posts.single.sampleUrl, 'https://files.yande.re/sample/sample.jpg');
    expect(posts.single.previewUrl, 'https://assets.yande.re/data/preview/thumb.jpg');
    expect(posts.single.parentId, '123');
    expect(posts.single.createdAt.year, greaterThan(2020));
    expect(posts.single.hasRelations, isTrue);
  });

  test('parses e621 response and tag groups', () {
    final posts = E621Mapper.postsFromResponse(
      {
        'posts': [
          {
            'id': 60,
            'file': {
              'url': 'https://example.test/e.webm',
              'width': 1280,
              'height': 720,
              'ext': 'webm',
            },
            'preview': {'url': 'https://example.test/e-preview.jpg'},
            'sample': {'url': 'https://example.test/e-sample.jpg'},
            'rating': 'e',
            'score': {'total': 10},
            'tags': {
              'artist': ['artist_e'],
              'species': ['wolf'],
              'general': ['running'],
            },
          }
        ],
      },
      providerId: 'e621',
      providerName: 'e621',
    );

    expect(posts.single.fileType, 'video');
    expect(posts.single.rating, 'explicit');
    expect(posts.single.tagGroups['species'], ['wolf']);
  });

  test('missing optional fields do not crash parser', () {
    final posts = GelbooruMapper.postsFromResponse(
      [
        {'id': 5}
      ],
      providerId: 'gelbooru',
      providerName: 'Gelbooru',
    );

    expect(posts.single.fileUrl, '');
    expect(posts.single.rating, 'unknown');
  });

  test(
      'seed providers include Realbooru HTML Pawchive Fapello and exclude deprecated providers',
      () {
    final pawchive = ProviderRepository.seedProviders()
        .where((provider) => provider.id == 'pawchive')
        .single;
    expect(pawchive.enabled, isTrue);
    expect(pawchive.apiType, 'pawchive');
    expect(pawchive.baseUrl, 'https://pawchive.pw');
    final fapello = ProviderRepository.seedProviders()
        .where((provider) => provider.id == 'fapello')
        .single;
    // Off by default: Cloudflare blocks the HTML pages this provider reads.
    expect(fapello.enabled, isFalse);
    expect(fapello.apiType, 'fapello');
    expect(fapello.baseUrl, 'https://fapello.com');
    final realbooru = ProviderRepository.seedProviders()
        .where((provider) => provider.id == 'realbooru')
        .single;
    expect(realbooru.enabled, isTrue);
    expect(realbooru.apiType, 'realbooru_html');
    expect(realbooru.baseUrl, 'https://realbooru.com');
    expect(
      ProviderRepository.seedProviders()
          .where((provider) => provider.id == 'cosbooru'),
      isEmpty,
    );
    expect(
      ProviderRepository.seedProviders()
          .where((provider) => provider.id == 'paheal'),
      isEmpty,
    );
    expect(
      ProviderRepository.seedProviders()
          .where((provider) => provider.id == 'xbooru'),
      isEmpty,
    );
    expect(
      ProviderRepository.seedProviders()
          .where((provider) => provider.id == 'kemono'),
      isEmpty,
    );
    expect(
      ProviderRepository.seedProviders()
          .where((provider) => provider.id == 'coomer'),
      isEmpty,
    );
  });

  test(
      'provider factory creates Realbooru provider from legacy realbooru api type',
      () {
    final now = DateTime(2026);
    final provider = ProviderFactory().create(ContentProviderConfig(
      id: 'realbooru',
      name: 'Realbooru',
      baseUrl: 'https://realbooru.com',
      apiType: 'realbooru',
      enabled: true,
      priority: 7,
      timeoutSeconds: 20,
      customHeaders: const {},
      createdAt: now,
      updatedAt: now,
    ));

    expect(provider, isA<RealbooruHtmlProvider>());
  });

  test('provider factory creates Realbooru HTML provider', () {
    final now = DateTime(2026);
    final provider = ProviderFactory().create(ContentProviderConfig(
      id: 'realbooru',
      name: 'Realbooru',
      baseUrl: 'https://realbooru.com',
      apiType: 'realbooru_html',
      enabled: true,
      priority: 7,
      timeoutSeconds: 20,
      customHeaders: const {},
      createdAt: now,
      updatedAt: now,
    ));

    expect(provider, isA<RealbooruHtmlProvider>());
  });

  test('provider factory treats removed Kemono and Coomer as unsupported', () {
    final now = DateTime(2026);
    for (final apiType in ['kemono', 'coomer']) {
      final provider = ProviderFactory().create(ContentProviderConfig(
        id: apiType,
        name: apiType,
        baseUrl: 'https://$apiType.su',
        apiType: apiType,
        enabled: true,
        priority: 10,
        timeoutSeconds: 20,
        customHeaders: const {},
        createdAt: now,
        updatedAt: now,
      ));

      expect(provider, isA<UnsupportedCustomProvider>());
    }
  });

  test(
      'RealbooruHtmlProvider parses video post details, metadata and tag categories',
      () async {
    final dio = Dio();
    dio.httpClientAdapter = _FakeAdapter((options) async {
      const html = '''
        <div class="content">
          <video style="width: 100%;" controls loop id="gelcomVideoPlayer">
            <source src="https://realbooru.com//images/33/19/3319e66c3dac8d361a51d628037bfb8e.mp4" type="video/mp4" />
            <source src="https://realbooru.com//images/33/19/3319e66c3dac8d361a51d628037bfb8e.webm" type="video/webm" />
          </video>
          <div id="tagLink">
            Posted at Sep, 16 2026 by <a href="index.php?page=account&s=profile&id=1">alienpineapples</a>
            Current Score: <b><span id="psc1007638">42</span></b>
            <a class="model" href="index.php?page=post&amp;s=list&amp;tags=cosplay_queen">cosplay queen</a>
            <a class="copyright" href="index.php?page=post&amp;s=list&amp;tags=genshin_impact">genshin impact</a>
            <a class="metadata" href="index.php?page=post&amp;s=list&amp;tags=watermark">watermark</a>
            <a class="tag-type-general" href="index.php?page=post&amp;s=list&amp;tags=cosplay">cosplay</a>
          </div>
        </div>
      ''';
      return ResponseBody.fromString(html, 200);
    });

    final provider = RealbooruHtmlProvider(
      id: 'realbooru',
      name: 'Realbooru',
      baseUrl: 'https://realbooru.com',
      dioClient: DioClient(dio: dio),
    );

    final post = await provider.getPost('1007638');
    expect(post, isNotNull);
    expect(post!.fileType, 'video');
    expect(post.fileUrl,
        'https://realbooru.com/images/33/19/3319e66c3dac8d361a51d628037bfb8e.mp4');
    expect(post.previewUrl,
        'https://realbooru.com/thumbnails/33/19/thumbnail_3319e66c3dac8d361a51d628037bfb8e.jpg');
    expect(post.score, 42);
    expect(post.createdAt.year, 2026);
    expect(post.createdAt.month, 9);
    expect(post.createdAt.day, 16);
    expect(post.tagGroups['artist'], contains('cosplay_queen'));
    expect(post.tagGroups['copyright'], contains('genshin_impact'));
    expect(post.tagGroups['metadata'], contains('watermark'));
    expect(post.tagGroups['general'], contains('cosplay'));
  });

  test('RealbooruHtmlProvider parses autocomplete with post counts', () async {
    final dio = Dio();
    dio.httpClientAdapter = _FakeAdapter((options) async {
      final jsonStr = jsonEncode([
        {'label': 'cosplay (60503)', 'value': 'cosplay'},
        {'label': 'cosplayer (692)', 'value': 'cosplayer'},
      ]);
      return ResponseBody.fromString(jsonStr, 200);
    });

    final provider = RealbooruHtmlProvider(
      id: 'realbooru',
      name: 'Realbooru',
      baseUrl: 'https://realbooru.com',
      dioClient: DioClient(dio: dio),
    );

    final suggestions = await provider.suggestTags('cos');
    expect(suggestions, hasLength(2));
    expect(suggestions.first.name, 'cosplay');
    expect(suggestions.first.postCount, 60503);
    expect(suggestions.last.name, 'cosplayer');
    expect(suggestions.last.postCount, 692);
  });

  test('RealbooruHtmlProvider parses user comments', () async {
    final dio = Dio();
    dio.httpClientAdapter = _FakeAdapter((options) async {
      expect(options.path, '/index.php');
      expect(options.queryParameters['page'], 'post');
      expect(options.queryParameters['s'], 'view');
      expect(options.queryParameters['id'], '995364');

      const html = '''
        <div style="width: 100%; padding: 00px;">
          <h5>User Comments</h5>
          <div class="userComment" id="c145488">
            <div style="margin-bottom: 5px; font-style: italic;"><a href="index.php?page=account&amp;s=profile&amp;uname=Rufo6969">Rufo6969</a> <span style="font-size: 11px; color: #8f8f8f;">&raquo; #145488</span></div>
            <div id="c145488" style="display:inline;"><b>Posted on 2026-06-08 22:24:11 Score: <a id="sc145488">4</a></b></div>
            <div style="font-size: .8em;">This lady has an amazing look!<br />Love it.</div>
          </div>
          <br />
          <div class="userComment" id="c146172">
            <div style="margin-bottom: 5px; font-style: italic;"><a href="index.php?page=account&amp;s=profile&amp;uname=Brazil_Horny">Brazil Horny</a> <span style="font-size: 11px; color: #8f8f8f;">&raquo; #146172</span></div>
            <div id="c146172" style="display:inline;"><b>Posted on 2026-06-11 20:30:50 Score: <a id="sc146172">0</a></b></div>
            <div style="font-size: .8em;">Que perfei&ccedil;&atilde;o de mulher hein<br /></div>
          </div>
        </div>
      ''';
      return ResponseBody.fromString(html, 200);
    });

    final provider = RealbooruHtmlProvider(
      id: 'realbooru',
      name: 'Realbooru',
      baseUrl: 'https://realbooru.com',
      dioClient: DioClient(dio: dio),
    );

    final comments = await provider.getComments('995364');
    expect(comments, hasLength(2));
    expect(comments.first.id, '145488');
    expect(comments.first.postId, '995364');
    expect(comments.first.authorName, 'Rufo6969');
    expect(comments.first.createdAt.year, 2026);
    expect(comments.first.createdAt.month, 6);
    expect(comments.first.createdAt.day, 8);
    expect(comments.first.body, 'This lady has an amazing look!\nLove it.');

    expect(comments.last.id, '146172');
    expect(comments.last.authorName, 'Brazil Horny');
    expect(comments.last.body, 'Que perfeição de mulher hein');
  });

  test('RealbooruHtmlProvider applies sort:score:desc on TopPeriodFilter',
      () async {
    final dio = Dio();
    late String queryTags;
    dio.httpClientAdapter = _FakeAdapter((options) async {
      queryTags = options.queryParameters['tags']?.toString() ?? '';
      return ResponseBody.fromString('', 200);
    });

    final provider = RealbooruHtmlProvider(
      id: 'realbooru',
      name: 'Realbooru',
      baseUrl: 'https://realbooru.com',
      dioClient: DioClient(dio: dio),
    );

    await provider.searchPosts(
      tags: ['cosplay'],
      page: 0,
      topPeriod: TopPeriodFilter.allTime,
    );
    expect(queryTags, 'cosplay sort:score:desc');

    await provider.searchPosts(
      tags: const [],
      page: 0,
      topPeriod: TopPeriodFilter.week,
    );
    expect(queryTags, 'sort:score:desc');

    await provider.searchPosts(
      tags: const [],
      page: 0,
      topPeriod: TopPeriodFilter.none,
    );
    expect(queryTags, 'all');
  });
}

class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.handler);
  final Future<ResponseBody> Function(RequestOptions options) handler;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<dynamic>? requestStream,
    Future<void>? cancelFuture,
  ) {
    return handler(options);
  }

  @override
  void close({bool force = false}) {}
}
