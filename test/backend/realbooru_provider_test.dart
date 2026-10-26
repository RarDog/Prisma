import 'package:flutter_test/flutter_test.dart';
import 'package:dio/dio.dart';
import 'package:gel_rule_app/core/models/post.dart';
import 'package:gel_rule_app/core/utils/media_quality.dart';
import 'package:gel_rule_app/features/providers/models/content_provider_config.dart';
import 'package:gel_rule_app/sources/interfaces/content_provider.dart';
import 'package:gel_rule_app/sources/provider_factory.dart';
import 'package:gel_rule_app/sources/booru/realbooru_html_provider.dart';
import 'package:gel_rule_app/core/http/dio_client.dart';

void main() {
  group('RealbooruProvider Tests', () {
    test(
        'ProviderFactory creates RealbooruHtmlProvider from both realbooru and realbooru_html',
        () {
      final factory = ProviderFactory();
      for (final apiType in ['realbooru', 'realbooru_html']) {
        final config = ContentProviderConfig(
          id: 'realbooru',
          name: 'Realbooru',
          baseUrl: 'https://realbooru.com',
          apiType: apiType,
          enabled: true,
          priority: 3,
          timeoutSeconds: 20,
          customHeaders: const {},
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
        );

        final provider = factory.create(config);
        expect(provider, isA<RealbooruHtmlProvider>());
        expect(provider.id, equals('realbooru'));
        expect(provider.name, equals('Realbooru'));
        expect(provider.baseUrl, equals('https://realbooru.com'));
        expect(provider, isA<TagSuggestionProvider>());
        expect(provider, isA<CommentProvider>());
        expect(provider, isA<MediaHeadersProvider>());
        expect(provider, isA<PostPageProvider>());
      }
    });

    test('RealbooruProvider URLs and headers', () {
      final client = DioClient(baseUrl: 'https://realbooru.com');
      final provider = RealbooruHtmlProvider(
        id: 'realbooru',
        name: 'Realbooru',
        baseUrl: 'https://realbooru.com',
        dioClient: client,
      );

      final dummyPost = Post(
        id: '100123',
        providerId: 'realbooru',
        providerName: 'Realbooru',
        previewUrl: 'https://realbooru.com/thumbnails/ed/29/thumbnail_test.jpg',
        sampleUrl: 'https://realbooru.com/images/ed/29/test.jpeg',
        fileUrl: 'https://realbooru.com/images/ed/29/test.jpeg',
        tags: const ['blonde', 'bikini'],
        rating: 'explicit',
        width: 1200,
        height: 800,
        createdAt: DateTime.now(),
        fileType: 'jpeg',
        score: 10,
      );

      expect(
        provider.postPageUrl(dummyPost),
        equals('https://realbooru.com/index.php?page=post&s=view&id=100123'),
      );

      final headers = provider.mediaHeaders(dummyPost);
      expect(headers['Referer'], equals('https://realbooru.com/'));
      expect(headers['User-Agent'], isNotEmpty);
    });

    test('searchPosts correctly identifies video, png image, and formats URLs',
        () async {
      final dio = Dio();
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            const html = '''
<div class="col thumb" id="s1001">
  <a id="p1001" href="https://realbooru.com/index.php?page=post&s=view&id=1001">
    <img src="https://realbooru.com/thumbnails/12/34/thumbnail_1234abcd.jpg" title="girl, solo, png, smiling" alt="Image: 1001" style=""/>
  </a>
</div>
<div class="col thumb" id="s1002">
  <a id="p1002" href="https://realbooru.com/index.php?page=post&s=view&id=1002">
    <img src="https://realbooru.com/thumbnails/56/78/thumbnail_5678ef01.jpg" title="model, video, webm" alt="Image: 1002" style="border: 3px solid #0000ff;"/>
  </a>
</div>
''';
            return handler.resolve(
              Response(
                requestOptions: options,
                data: html,
                statusCode: 200,
              ),
            );
          },
        ),
      );

      final client = DioClient(dio: dio);
      final provider = RealbooruHtmlProvider(
        id: 'realbooru',
        name: 'Realbooru',
        baseUrl: 'https://realbooru.com',
        dioClient: client,
      );

      final posts = await provider.searchPosts(tags: const [], page: 0);
      expect(posts, hasLength(2));

      // PNG image post
      final imgPost = posts[0];
      expect(imgPost.id, equals('1001'));
      expect(imgPost.fileType, equals('image'));
      expect(imgPost.previewUrl,
          equals('https://realbooru.com/thumbnails/12/34/thumbnail_1234abcd.jpg'));
      expect(imgPost.sampleUrl,
          equals('https://realbooru.com/images/12/34/1234abcd.png'));
      expect(imgPost.fileUrl,
          equals('https://realbooru.com/images/12/34/1234abcd.png'));
      expect(imgPost.tagGroups, isEmpty);

      // Video post
      final vidPost = posts[1];
      expect(vidPost.id, equals('1002'));
      expect(vidPost.fileType, equals('video'));
      expect(vidPost.previewUrl,
          equals('https://realbooru.com/thumbnails/56/78/thumbnail_5678ef01.jpg'));
      // sampleUrl MUST be thumbnail image (not mp4) so feed image decoder doesn't crash
      expect(vidPost.sampleUrl,
          equals('https://realbooru.com/thumbnails/56/78/thumbnail_5678ef01.jpg'));
      // fileUrl MUST be the playable mp4 stream
      expect(vidPost.fileUrl,
          equals('https://realbooru.com/images/56/78/5678ef01.mp4'));
      expect(vidPost.tagGroups, isEmpty);
    });

    test('getPost extracts exact media, categorized tag groups, author, score, and is_detailed',
        () async {
      final dio = Dio();
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            const html = '''
<div class="imageContainer">
  <video id="gelcomVideoPlayer" controls>
    <source src="https://realbooru.com//images/ab/cd/abcd1234.mp4" type="video/mp4" />
    <source src="https://realbooru.com//images/ab/cd/abcd1234.webm" type="video/webm" />
  </video>
  <div id="tagLink">
    <span>Posted at Oct, 23 2026 by <a href="#">VideoUploader</a></span>
    - Current Score: <b><span id="psc999">42</span></b>
    <a class="copyright" href="index.php?page=post&s=list&tags=studio_alpha">studio alpha</a>
    <a class="model" href="index.php?page=post&s=list&tags=jane_doe">jane doe</a>
    <a class="metadata" href="index.php?page=post&s=list&tags=hd">hd</a>
    <a class="tag-type-general" href="index.php?page=post&s=list&tags=bikini">bikini</a>
  </div>
  <a href="https://realbooru.com//images/ab/cd/abcd1234.mp4">Original</a>
</div>
''';
            return handler.resolve(
              Response(
                requestOptions: options,
                data: html,
                statusCode: 200,
              ),
            );
          },
        ),
      );

      final client = DioClient(dio: dio);
      final provider = RealbooruHtmlProvider(
        id: 'realbooru',
        name: 'Realbooru',
        baseUrl: 'https://realbooru.com',
        dioClient: client,
      );

      final post = await provider.getPost('999');
      expect(post, isNotNull);
      expect(post!.id, equals('999'));
      expect(post.fileType, equals('video'));
      expect(post.score, equals(42));
      expect(post.fileUrl,
          equals('https://realbooru.com/images/ab/cd/abcd1234.mp4'));
      expect(post.sampleUrl,
          equals('https://realbooru.com/thumbnails/ab/cd/thumbnail_abcd1234.jpg'));
      expect(post.previewUrl,
          equals('https://realbooru.com/thumbnails/ab/cd/thumbnail_abcd1234.jpg'));

      // Tag groups
      expect(post.tagGroups['copyright'], equals(['studio_alpha']));
      expect(post.tagGroups['artist'], containsAll(['jane_doe', 'VideoUploader']));
      expect(post.tagGroups['meta'], equals(['hd']));
      expect(post.tagGroups['general'], equals(['bikini']));
      expect(post.tagGroups['is_detailed'], equals(['true']));
    });

    test('MediaUrlSelector.details supplies alternative extensions for realbooru image', () {
      final post = Post(
        id: '123',
        providerId: 'realbooru',
        providerName: 'Realbooru',
        previewUrl: 'https://realbooru.com/thumbnails/11/22/thumbnail_test123.jpg',
        sampleUrl: 'https://realbooru.com/images/11/22/test123.jpeg',
        fileUrl: 'https://realbooru.com/images/11/22/test123.jpeg',
        tags: const ['test'],
        rating: 'e',
        width: 1000,
        height: 1000,
        createdAt: DateTime.now(),
        fileType: 'image',
        score: 0,
      );

      final detailsUrls = MediaUrlSelector.details(post);
      expect(detailsUrls, contains('https://realbooru.com/images/11/22/test123.jpeg'));
      expect(detailsUrls, contains('https://realbooru.com/images/11/22/test123.jpg'));
      expect(detailsUrls, contains('https://realbooru.com/images/11/22/test123.png'));
      expect(detailsUrls.last, equals('https://realbooru.com/thumbnails/11/22/thumbnail_test123.jpg'));
    });
  });
}
