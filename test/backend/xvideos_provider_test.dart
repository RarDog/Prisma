import 'package:flutter_test/flutter_test.dart';
import 'package:gel_rule_app/core/http/dio_client.dart';
import 'package:gel_rule_app/core/models/post.dart';
import 'package:gel_rule_app/features/providers/models/content_provider_config.dart';
import 'package:gel_rule_app/sources/booru/xvideos_provider.dart';
import 'package:gel_rule_app/sources/provider_factory.dart';

void main() {
  group('XVideosProvider Tests', () {
    test('ProviderFactory creates XVideosProvider from config', () {
      final factory = ProviderFactory();
      final config = ContentProviderConfig(
        id: 'xvideos',
        name: 'XVideos',
        baseUrl: 'https://www.xvideos.com',
        apiType: 'xvideos',
        enabled: true,
        priority: 18,
        timeoutSeconds: 25,
        customHeaders: const {},
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final provider = factory.create(config);
      expect(provider, isA<XVideosProvider>());
      expect(provider.id, equals('xvideos'));
      expect(provider.name, equals('XVideos'));
      expect(provider.baseUrl, equals('https://www.xvideos.com'));
    });

    test('XVideosProvider.parseVideoList parses video blocks from HTML', () {
      final provider = XVideosProvider(
        id: 'xvideos',
        name: 'XVideos',
        baseUrl: 'https://www.xvideos.com',
        dioClient: DioClient(),
      );

      const sampleHtml = '''
<div id="content">
  <div class="mozaique cust-nb-cols">
    <div id="video_kmlafhv3e4e" data-id="58240793" data-eid="kmlafhv3e4e" class="frame-block thumb-block">
      <div class="thumb-inside">
        <div class="thumb">
          <a href="/video.kmlafhv3e4e/_2">
            <img src="blank.gif" data-src="https://thumb-cdn77.xvideos-cdn.com/d8ad5cbd/0/xv_22_t.jpg" />
            <span class="video-hd-mark">720p</span>
          </a>
        </div>
      </div>
      <div class="thumb-under">
        <p class="title"><a href="/video.kmlafhv3e4e/_2" title="Sample Anime Game 2">Sample Anime Game 2 <span class="duration">11 min</span></a></p>
        <p class="metadata"><span class="bg"><span class="duration">11 min</span><span><a href="/caribbeancom"><span class="name">Caribbeancom</span></a><span> 3.8M Views</span></span></span></p>
      </div>
    </div>
  </div>
</div>
''';

      final posts = provider.parseVideoList(sampleHtml);
      expect(posts.length, equals(1));

      final post = posts.first;
      expect(post.id, equals('kmlafhv3e4e'));
      expect(post.providerId, equals('xvideos'));
      expect(post.previewUrl,
          equals('https://thumb-cdn77.xvideos-cdn.com/d8ad5cbd/0/xv_22_t.jpg'));
      expect(post.fileType, equals('mp4'));
      expect(post.rating, equals('e'));
      expect(post.source, equals('https://www.xvideos.com/video.kmlafhv3e4e/_'));
      expect(post.tagGroups['title'], equals(['Sample Anime Game 2']));
      expect(post.tagGroups['artist'], equals(['Caribbeancom']));
      expect(post.tagGroups['duration_text'], equals(['11 min']));
      expect(post.tagGroups['duration'], equals(['660']));
      expect(post.score, equals(3800000));
    });

    test('XVideosProvider.parsePostDetail parses direct MP4 stream and metadata', () {
      final provider = XVideosProvider(
        id: 'xvideos',
        name: 'XVideos',
        baseUrl: 'https://www.xvideos.com',
        dioClient: DioClient(),
      );

      const detailHtml = '''
<!DOCTYPE html>
<html>
<head>
  <div class="video-metadata video-tags-list">
    <li class="main-uploader"><a href="/channel1" class="btn btn-default label main uploader-tag"><span class="name">AuthorChannel</span></a></li>
    <li><a href="/tags/anime">anime</a></li>
    <li><a href="/tags/cosplay">cosplay</a></li>
  </div>
</head>
<body>
  <script>
    html5player.setVideoTitle('Cool Animation Video');
    html5player.setVideoUrlLow('https://mp4-cdn.xvideos.com/video_240p.mp4');
    html5player.setVideoUrlHigh('https://mp4-cdn.xvideos.com/video_720p.mp4');
    html5player.setVideoHLS('https://hls-cdn.xvideos.com/hls.m3u8');
    html5player.setThumbUrl169('https://thumb-cdn.xvideos.com/thumb.jpg');
  </script>
</body>
</html>
''';

      final post = provider.parsePostDetail('test1234', detailHtml);
      expect(post, isNotNull);
      expect(post!.id, equals('test1234'));
      expect(post.fileUrl, equals('https://mp4-cdn.xvideos.com/video_720p.mp4'));
      expect(post.sampleUrl, equals('https://mp4-cdn.xvideos.com/video_720p.mp4'));
      expect(post.previewUrl, equals('https://thumb-cdn.xvideos.com/thumb.jpg'));
      expect(post.fileType, equals('mp4'));
      expect(post.rating, equals('e'));
      expect(post.tags, contains('AuthorChannel'));
      expect(post.tags, contains('anime'));
      expect(post.tags, contains('cosplay'));
      expect(post.tagGroups['artist'], equals(['AuthorChannel']));
      expect(post.tagGroups['title'], equals(['Cool Animation Video']));
      expect(post.tagGroups['is_detailed'], equals(['true']));
    });

    test('XVideosProvider mediaHeaders provides Chrome User-Agent and Referer', () {
      final provider = XVideosProvider(
        id: 'xvideos',
        name: 'XVideos',
        baseUrl: 'https://www.xvideos.com',
        dioClient: DioClient(),
      );

      final headers = provider.mediaHeaders(Post(
        id: '1',
        providerId: 'xvideos',
        providerName: 'XVideos',
        previewUrl: '',
        sampleUrl: '',
        fileUrl: '',
        tags: const [],
        rating: 'e',
        width: 100,
        height: 100,
        createdAt: DateTime.now(),
        fileType: 'mp4',
        score: 0,
      ));

      expect(headers['Referer'], equals('https://www.xvideos.com/'));
      expect(headers['User-Agent'], isNotEmpty);
    });
  });
}
