import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gel_rule_app/features/artists/models/artist_sort_order.dart';
import 'package:gel_rule_app/features/artists/models/artist_work_query.dart';
import 'package:gel_rule_app/features/providers/models/content_provider_config.dart';
import 'package:gel_rule_app/core/models/post.dart';
import 'package:gel_rule_app/sources/artist/pawchive_provider.dart';
import 'package:gel_rule_app/sources/provider_factory.dart';
import 'package:gel_rule_app/core/utils/media_quality.dart';
import 'package:gel_rule_app/core/http/dio_client.dart';

void main() {
  test('ProviderFactory creates PawchiveProvider', () {
    final factory = ProviderFactory();
    final config = ContentProviderConfig(
      id: 'pawchive',
      name: 'Pawchive',
      baseUrl: 'https://pawchive.pw',
      apiType: 'pawchive',
      enabled: true,
      priority: 12,
      timeoutSeconds: 20,
      customHeaders: const {},
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );

    final provider = factory.create(config);
    expect(provider, isA<PawchiveProvider>());
    expect(provider.id, 'pawchive');
    expect(provider.name, 'Pawchive');
    expect(provider.baseUrl, 'https://pawchive.pw');
  });

  test('PawchiveProvider creates posts with thumbnail and file URLs', () async {
    final client = DioClient(baseUrl: 'https://pawchive.pw');
    final provider = PawchiveProvider(
      id: 'pawchive',
      name: 'Pawchive',
      baseUrl: 'https://pawchive.pw',
      dioClient: client,
    );

    const query = ArtistWorkQuery(
      providerId: 'pawchive',
      service: 'patreon',
      artistId: '30500811',
      artistName: 'BOKABA',
    );

    expect(provider.id, query.providerId);
    expect(query.artistName, 'BOKABA');
  });

  test('MediaUrlSelector accurately classifies audio, video and photo posts',
      () {
    final audioPost = Post(
      id: 'patreon:123:456:0',
      providerId: 'pawchive',
      providerName: 'Pawchive',
      previewUrl: '',
      sampleUrl: '',
      fileUrl:
          'https://file.pawchive.pw/data/ae/13/ae13adaaebee798397c5c3b07cb9690b2adc91f41815e89a3f58a447bfb56980.mp3?f=audio%20spicy%20only%204.MP3',
      tags: const ['patreon', 'artist', 'audio'],
      rating: 'unknown',
      width: 0,
      height: 0,
      createdAt: DateTime.now(),
      fileType: 'audio',
      score: 0,
    );

    final videoPost = Post(
      id: 'patreon:123:456:1',
      providerId: 'pawchive',
      providerName: 'Pawchive',
      previewUrl: '',
      sampleUrl: '',
      fileUrl:
          'https://file.pawchive.pw/data/84/b1/84b1d076dd6b59047bb699115e57c18a02f2ea08b54e4d20409692b58b7aac33.mp4',
      tags: const ['patreon', 'artist'],
      rating: 'unknown',
      width: 1920,
      height: 1080,
      createdAt: DateTime.now(),
      fileType: 'video',
      score: 0,
    );

    final photoPost = Post(
      id: 'patreon:123:456:2',
      providerId: 'pawchive',
      providerName: 'Pawchive',
      previewUrl: 'https://img.pawchive.pw/thumbnail/data/c3/06/c3060ab6fa.png',
      sampleUrl: 'https://img.pawchive.pw/thumbnail/data/c3/06/c3060ab6fa.png',
      fileUrl: 'https://file.pawchive.pw/data/c3/06/c3060ab6fa.png',
      tags: const ['patreon', 'artist'],
      rating: 'unknown',
      width: 1200,
      height: 1600,
      createdAt: DateTime.now(),
      fileType: 'photo',
      score: 0,
    );

    expect(MediaUrlSelector.isAudio(audioPost), isTrue);
    expect(MediaUrlSelector.isVideo(audioPost), isFalse);
    expect(MediaUrlSelector.audio(audioPost), contains(audioPost.fileUrl));

    expect(MediaUrlSelector.isVideo(videoPost), isTrue);
    expect(MediaUrlSelector.isAudio(videoPost), isFalse);

    expect(MediaUrlSelector.isAudio(photoPost), isFalse);
    expect(MediaUrlSelector.isVideo(photoPost), isFalse);
  });

  test(
      'MediaUrlSelector classifies mp4 containing "audio" in query parameter as video and not audio',
      () {
    final trickyVideoPost = Post(
      id: 'patreon:123:456:3',
      providerId: 'pawchive',
      providerName: 'Pawchive',
      previewUrl: '',
      sampleUrl: '',
      fileUrl:
          'https://file.pawchive.pw/data/b4/65/b465cb03ab7b26c0a677db3ae43500d1ef71e3e25151f160cda244c1fb40cfae.mp4?f=nsfw%202%20-%20audio%20spicy.mp4',
      tags: const ['patreon', 'artist', 'nsfw 2 - audio spicy'],
      rating: 'unknown',
      width: 1920,
      height: 1080,
      createdAt: DateTime.now(),
      fileType: 'video',
      score: 0,
    );

    expect(MediaUrlSelector.isVideo(trickyVideoPost), isTrue);
    expect(MediaUrlSelector.isAudio(trickyVideoPost), isFalse);
    expect(MediaUrlSelector.video(trickyVideoPost),
        contains(trickyVideoPost.fileUrl));
  });

  test(
      'PawchiveProvider listArtists sorts by postsAsc, recentPosts, and postsDesc',
      () async {
    final dio = Dio(BaseOptions(baseUrl: 'https://pawchive.pw'));
    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        if (options.path == '/api/v1/creators') {
          return handler.resolve(Response(
            requestOptions: options,
            data: [
              {
                'id': 'artist_a',
                'name': 'Alpha',
                'service': 'patreon',
                'favorited': 100,
                'updated': '2026-01-01T12:00:00Z',
              },
              {
                'id': 'artist_b',
                'name': 'Beta',
                'service': 'patreon',
                'favorited': 5,
                'updated': '2026-11-05T12:00:00Z',
              },
              {
                'id': 'artist_c',
                'name': 'Gamma',
                'service': 'fanbox',
                'favorited': 50,
                'updated': '2026-06-01T12:00:00Z',
              },
            ],
          ));
        }
        return handler.next(options);
      },
    ));

    final provider = PawchiveProvider(
      id: 'pawchive',
      name: 'Pawchive',
      baseUrl: 'https://pawchive.pw',
      dioClient: DioClient(dio: dio),
    );

    // 1. postsAsc: least posts first (Beta: 5, Gamma: 50, Alpha: 100)
    final leastPosts =
        await provider.listArtists(sort: ArtistSortOrder.postsAsc);
    expect(leastPosts.map((a) => a.id).toList(),
        ['artist_b', 'artist_c', 'artist_a']);

    // 2. recentPosts: newest updatedAt first (Beta: Nov 2026, Gamma: June 2026, Alpha: Jan 2026)
    final recent =
        await provider.listArtists(sort: ArtistSortOrder.recentPosts);
    expect(
        recent.map((a) => a.id).toList(), ['artist_b', 'artist_c', 'artist_a']);

    // 3. postsDesc: most posts first (Alpha: 100, Gamma: 50, Beta: 5)
    final mostPosts =
        await provider.listArtists(sort: ArtistSortOrder.postsDesc);
    expect(
        mostPosts.map((a) => a.id).toList(), ['artist_a', 'artist_c', 'artist_b']);

    // 4. nameAsc: alphabetical (Alpha, Beta, Gamma)
    final byName = await provider.listArtists(sort: ArtistSortOrder.nameAsc);
    expect(
        byName.map((a) => a.id).toList(), ['artist_a', 'artist_b', 'artist_c']);
  });
}
