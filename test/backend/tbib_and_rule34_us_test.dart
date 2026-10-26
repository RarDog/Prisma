import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:prisma_app/core/http/dio_client.dart';
import 'package:prisma_app/core/models/post.dart';
import 'package:prisma_app/core/models/top_period_filter.dart';
import 'package:prisma_app/features/providers/models/content_provider_config.dart';
import 'package:prisma_app/sources/booru/rule34_us_provider.dart';
import 'package:prisma_app/sources/booru/tbib_provider.dart';
import 'package:prisma_app/sources/interfaces/content_provider.dart';
import 'package:prisma_app/sources/mappers/gelbooru_mapper.dart';
import 'package:prisma_app/sources/provider_factory.dart';

void main() {
  group('TBIB and Rule34.us Provider Tests', () {
    test('ProviderFactory creates TbibProvider', () {
      final factory = ProviderFactory();
      final config = ContentProviderConfig(
        id: 'tbib',
        name: 'TBIB',
        baseUrl: 'https://tbib.org',
        apiType: 'tbib',
        enabled: true,
        priority: 16,
        timeoutSeconds: 20,
        customHeaders: const {},
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      );

      final provider = factory.create(config);
      expect(provider, isA<TbibProvider>());
      expect(provider.id, equals('tbib'));
      expect(provider.name, equals('TBIB'));
      expect(provider.baseUrl, equals('https://tbib.org'));
      expect(provider, isA<TagSuggestionProvider>());
      expect(provider, isA<MediaHeadersProvider>());
      expect(provider, isA<PostPageProvider>());
      expect(provider.supportedTopPeriods, {
        TopPeriodFilter.none,
        TopPeriodFilter.allTime,
      });
    });

    test('ProviderFactory creates Rule34UsProvider', () {
      final factory = ProviderFactory();
      for (final type in ['rule34_us', 'rule34us']) {
        final config = ContentProviderConfig(
          id: 'rule34_us',
          name: 'Rule34.us',
          baseUrl: 'https://rule34.us',
          apiType: type,
          enabled: true,
          priority: 17,
          timeoutSeconds: 20,
          customHeaders: const {},
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
        );

        final provider = factory.create(config);
        expect(provider, isA<Rule34UsProvider>());
        expect(provider.id, equals('rule34_us'));
        expect(provider.name, equals('Rule34.us'));
        expect(provider.baseUrl, equals('https://rule34.us'));
        expect(provider, isA<TagSuggestionProvider>());
        expect(provider, isA<MediaHeadersProvider>());
        expect(provider, isA<PostPageProvider>());
        expect(provider.supportedTopPeriods, {
          TopPeriodFilter.none,
          TopPeriodFilter.allTime,
        });
      }
    });

    test('GelbooruMapper resolves TBIB directory/image URLs', () {
      final tbibJson = [
        {
          "directory": 6698,
          "hash": "2562a93a28a335862930781a3da6b75f",
          "height": 3000,
          "id": 28810381,
          "image": "74f2d627b9843c09f23e850e0ded0a4766bc3196.png",
          "change": 1792751329,
          "owner": "anonymous",
          "parent_id": 0,
          "rating": "explicit",
          "sample": true,
          "sample_height": 850,
          "sample_width": 850,
          "score": null,
          "tags": "hatsune_miku 1girl vocaloid",
          "width": 3000
        },
        {
          "directory": 6704,
          "hash": "369d425c7b1513732967bcd45ca7bdf2",
          "height": 394,
          "id": 7217388,
          "image": "517a678c5d06a21c7de7d05fb90d3ab9deb0a992.jpeg",
          "rating": "explicit",
          "sample": false,
          "tags": "animated video mp4",
          "width": 700
        }
      ];

      final posts = GelbooruMapper.postsFromResponse(
        jsonEncode(tbibJson),
        providerId: 'tbib',
        providerName: 'TBIB',
        baseUrl: 'https://tbib.org',
      );

      expect(posts.length, equals(2));

      // Post 1: PNG with sample: true
      final p1 = posts[0];
      expect(p1.id, equals('28810381'));
      expect(
        p1.fileUrl,
        equals(
          'https://tbib.org/images/6698/74f2d627b9843c09f23e850e0ded0a4766bc3196.png',
        ),
      );
      expect(
        p1.sampleUrl,
        equals(
          'https://tbib.org/samples/6698/sample_74f2d627b9843c09f23e850e0ded0a4766bc3196.jpg',
        ),
      );
      expect(
        p1.previewUrl,
        equals(
          'https://tbib.org/thumbnails/6698/thumbnail_74f2d627b9843c09f23e850e0ded0a4766bc3196.jpg',
        ),
      );
      expect(p1.tags, containsAll(['hatsune_miku', '1girl', 'vocaloid']));

      // Post 2: JPEG with sample: false
      final p2 = posts[1];
      expect(p2.id, equals('7217388'));
      expect(
        p2.fileUrl,
        equals(
          'https://tbib.org/images/6704/517a678c5d06a21c7de7d05fb90d3ab9deb0a992.jpeg',
        ),
      );
      expect(p2.sampleUrl, equals(p2.fileUrl));
      expect(
        p2.previewUrl,
        equals(
          'https://tbib.org/thumbnails/6704/thumbnail_517a678c5d06a21c7de7d05fb90d3ab9deb0a992.jpg',
        ),
      );
    });

    test('TBIB autocomplete parsing', () {
      final client = DioClient(baseUrl: 'https://tbib.org');
      final provider = TbibProvider(
        id: 'tbib',
        name: 'TBIB',
        baseUrl: 'https://tbib.org',
        dioClient: client,
      );

      final raw = [
        {"label": "hatsune_miku (157677)", "value": "hatsune_miku"},
        {"label": "hatsune_miku_(cosplay) (2630)", "value": "hatsune_miku_(cosplay)"}
      ];

      final suggestions = provider.suggestionsFromAutocomplete(jsonEncode(raw), limit: 10);
      expect(suggestions.length, equals(2));
      expect(suggestions[0].name, equals('hatsune_miku'));
      expect(suggestions[0].postCount, equals(157677));
      expect(suggestions[1].name, equals('hatsune_miku_(cosplay)'));
      expect(suggestions[1].postCount, equals(2630));
    });

    test('Rule34.us post list and details HTML parsing', () {
      const sampleListHtml = '''
      <div class="thumbail-container">
        <div style="border-radius: 3px; margin: 0px 10px 15px 10px; overflow: hidden; height: 200px;">
          <a id="13628978" href="https://rule34.us/index.php?r=posts/view&amp;id=13628978">
            <img src="https://img2.rule34.us/thumbnails/f1/44/thumbnail_f144a96b2677d95b38b8a771c5a908dd.jpg"
                 title="cookie run, 2female, 2girls, eternal sugar cookie"
                 alt="Image: 13628978" />
          </a>
        </div>
        <div style="border-radius: 3px; margin: 0px 10px 15px 10px; overflow: hidden; height: 200px; border: 3px solid #0000ff;">
          <a id="13628887" href="https://rule34.us/index.php?r=posts/view&amp;id=13628887">
            <img src="https://img2.rule34.us/thumbnails/51/12/thumbnail_51120739fba71f06f826e89cc0850b2d.jpg"
                 title="meg griffin, family guy, video, mp4"
                 alt="Image: 13628887" />
          </a>
        </div>
      </div>
      ''';

      const sampleDetailsHtml = '''
      <html>
        <body>
          <li class="character-tag"><a href="https://rule34.us/index.php?r=posts/index&amp;q=meg_griffin">meg griffin</a></li>
          <li class="copyright-tag"><a href="https://rule34.us/index.php?r=posts/index&amp;q=family_guy">family guy</a></li>
          <li class="general-tag"><a href="https://rule34.us/index.php?r=posts/index&amp;q=1girl">1girl</a></li>
          <a href="https://video.rule34.us/images/51/12/51120739fba71f06f826e89cc0850b2d.webm">
            <li class="character-tag" style="display: block; padding: 5px;">Original</li>
          </a>
          <video poster="https://video.rule34.us/images/51/12/51120739fba71f06f826e89cc0850b2d.jpg" height="2592" width="1440">
            <source src="https://video.rule34.us/images/51/12/51120739fba71f06f826e89cc0850b2d.mp4" type="video/mp4">
            <source src="https://video.rule34.us/images/51/12/51120739fba71f06f826e89cc0850b2d.webm" type="video/webm">
          </video>
        </body>
      </html>
      ''';

      final client = DioClient(baseUrl: 'https://rule34.us');
      final provider = Rule34UsProvider(
        id: 'rule34_us',
        name: 'Rule34.us',
        baseUrl: 'https://rule34.us',
        dioClient: client,
      );

      final listPosts = provider.parseList(sampleListHtml);
      expect(listPosts.length, equals(2));

      // Post 1: Image
      final p1 = listPosts[0];
      expect(p1.id, equals('13628978'));
      expect(p1.fileType, equals('image'));
      expect(p1.previewUrl, equals('https://img2.rule34.us/thumbnails/f1/44/thumbnail_f144a96b2677d95b38b8a771c5a908dd.jpg'));
      expect(p1.fileUrl, equals('https://img2.rule34.us/images/f1/44/f144a96b2677d95b38b8a771c5a908dd.jpeg'));
      expect(p1.tags, contains('cookie_run'));

      // Post 2: Video
      final p2 = listPosts[1];
      expect(p2.id, equals('13628887'));
      expect(p2.fileType, equals('video'));
      expect(p2.fileUrl, equals('https://video.rule34.us/images/51/12/51120739fba71f06f826e89cc0850b2d.mp4'));

      // Details parsing
      final detail = provider.parseDetails('13628887', sampleDetailsHtml);
      expect(detail, isNotNull);
      expect(detail!.fileType, equals('video'));
      expect(detail.fileUrl, equals('https://video.rule34.us/images/51/12/51120739fba71f06f826e89cc0850b2d.mp4'));
      expect(detail.previewUrl, equals('https://video.rule34.us/images/51/12/51120739fba71f06f826e89cc0850b2d.jpg'));
      expect(detail.width, equals(1440));
      expect(detail.height, equals(2592));
      expect(detail.tagGroups['character'], contains('meg_griffin'));
      expect(detail.tagGroups['copyright'], contains('family_guy'));
      expect(detail.tagGroups['general'], contains('1girl'));
      expect(detail.tagGroups.containsKey('is_detailed'), isTrue);

      final dummyPost = Post(
        id: '13628978',
        providerId: 'rule34_us',
        providerName: 'Rule34.us',
        previewUrl: 'https://img2.rule34.us/thumbnails/f1/44/thumbnail_f144a96b2677d95b38b8a771c5a908dd.jpg',
        sampleUrl: 'https://img2.rule34.us/images/f1/44/f144a96b2677d95b38b8a771c5a908dd.jpeg',
        fileUrl: 'https://img2.rule34.us/images/f1/44/f144a96b2677d95b38b8a771c5a908dd.jpeg',
        tags: const ['cookie_run', '2female'],
        rating: 'explicit',
        width: 3072,
        height: 4096,
        createdAt: DateTime.now(),
        fileType: 'image',
        score: 0,
      );

      expect(provider.postPageUrl(dummyPost), equals('https://rule34.us/index.php?r=posts/view&id=13628978'));
      final headers = provider.mediaHeaders(dummyPost);
      expect(headers['Referer'], equals('https://rule34.us/'));
    });
  });
}
