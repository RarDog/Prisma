import 'package:flutter_test/flutter_test.dart';
import 'package:prisma_app/sources/mappers/danbooru_mapper.dart';
import 'package:prisma_app/core/utils/media_quality.dart';

void main() {
  test('danbooru video mapping', () {
    final json = {
      'id': 12415698,
      'file_ext': 'mp4',
      'file_url': 'https://cdn.donmai.us/original/2b/e7/2be732d6406d6f4c64818f1bf7fb2a03.mp4',
      'large_file_url': 'https://cdn.donmai.us/original/2b/e7/2be732d6406d6f4c64818f1bf7fb2a03.mp4',
      'preview_file_url': 'https://cdn.donmai.us/180x180/2b/e7/2be732d6406d6f4c64818f1bf7fb2a03.jpg',
      'image_width': 1072,
      'image_height': 720,
      'rating': 'e',
      'tag_string': 'blue_archive test',
      'media_asset': {
        'variants': [
          {'type': '180x180', 'url': 'https://cdn.donmai.us/180x180/2b/e7/2be732d6406d6f4c64818f1bf7fb2a03.jpg'},
          {'type': '360x360', 'url': 'https://cdn.donmai.us/360x360/2b/e7/2be732d6406d6f4c64818f1bf7fb2a03.jpg'},
          {'type': '720x720', 'url': 'https://cdn.donmai.us/720x720/2b/e7/2be732d6406d6f4c64818f1bf7fb2a03.webp'},
          {'type': 'original', 'url': 'https://cdn.donmai.us/original/2b/e7/2be732d6406d6f4c64818f1bf7fb2a03.mp4'}
        ]
      }
    };

    final post = DanbooruMapper.postFromJson(json, providerId: 'danbooru', providerName: 'Danbooru');
    expect(post.fileUrl, contains('.mp4'));
    expect(post.sampleUrl, contains('720x720'));
    expect(post.previewUrl, contains('180x180'));
    expect(post.fileType, 'video');
    expect(MediaUrlSelector.isVideo(post), isTrue);
    expect(MediaUrlSelector.looksLikeVideoUrl(post.previewUrl), isFalse);
    expect(MediaUrlSelector.looksLikeVideoUrl(post.sampleUrl), isFalse);
    expect(MediaUrlSelector.feed(post, mode: MediaQualityMode.auto, mobile: true), contains(post.previewUrl));
    expect(MediaUrlSelector.feed(post, mode: MediaQualityMode.highQuality, mobile: true).first, post.sampleUrl);
  });

  test('danbooru fallback url reconstruction when fields are null', () {
    final json = {
      'id': 12415926,
      'file_ext': 'mp4',
      'image_width': 1362,
      'image_height': 1024,
      'rating': 'e',
      'media_asset': {
        'id': 50567643,
        'pixel_hash': 'debd07c2f0249bdae9b0aa68730eec45',
        'file_ext': 'mp4',
      }
    };

    final post = DanbooruMapper.postFromJson(json, providerId: 'danbooru', providerName: 'Danbooru');
    expect(post.fileUrl, 'https://cdn.donmai.us/original/de/bd/debd07c2f0249bdae9b0aa68730eec45.mp4');
    expect(post.sampleUrl, 'https://cdn.donmai.us/720x720/de/bd/debd07c2f0249bdae9b0aa68730eec45.webp');
    expect(post.previewUrl, 'https://cdn.donmai.us/180x180/de/bd/debd07c2f0249bdae9b0aa68730eec45.jpg');
    expect(post.fileType, 'video');
    expect(MediaUrlSelector.isVideo(post), isTrue);
  });
}
