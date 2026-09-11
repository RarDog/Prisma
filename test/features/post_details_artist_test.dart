import 'package:flutter_test/flutter_test.dart';
import 'package:gel_rule_app/backend/models/post.dart';
import 'package:gel_rule_app/backend/providers/e621_provider.dart';

void main() {
  group('e621 tag sanitizer', () {
    test('strips artist: and creator: and category prefixes for e621', () {
      final tags = [
        'artist:burgerkiss',
        'creator:falco',
        'character:fox_mccloud',
        'species:canine',
        'general:fluffy',
        'rating:s',
        'order:score',
      ];
      final sanitized = E621Provider.sanitizeTags(tags);
      expect(sanitized, [
        'burgerkiss',
        'falco',
        'fox_mccloud',
        'canine',
        'fluffy',
        'rating:s',
        'order:score',
      ]);
    });

    test('preserves plain tags and metatags', () {
      final tags = ['burgerkiss', 'order:favcount', 'score:>100'];
      final sanitized = E621Provider.sanitizeTags(tags);
      expect(sanitized, tags);
    });
  });

  group('post artist extraction for e621', () {
    test('extracts clean artist ignoring e621 meta policy tags', () {
      final post = Post(
        id: '6699010',
        providerId: 'e621',
        providerName: 'e621',
        previewUrl: 'https://example.com/thumb.jpg',
        sampleUrl: 'https://example.com/sample.jpg',
        fileUrl: 'https://example.com/file.jpg',
        tags: ['burgerkiss', 'conditional_dnp', 'canine'],
        rating: 's',
        width: 1000,
        height: 1000,
        createdAt: DateTime.now(),
        fileType: 'image',
        score: 42,
        tagGroups: {
          'artist': ['conditional_dnp', 'burgerkiss'],
          'species': ['canine'],
        },
      );

      final rawArtists = post.tagGroups['artist'] ?? const [];
      const nonArtistTags = {
        'conditional_dnp',
        'avoid_posting',
        'soundless',
        'third_party_edit',
        'unknown_artist',
        'anonymous_artist',
      };
      final realArtists = rawArtists
          .where((a) => !nonArtistTags.contains(a.toLowerCase()))
          .toList();
      final artistName =
          realArtists.isNotEmpty ? realArtists.first : rawArtists.first;

      expect(artistName, 'burgerkiss');
    });
  });
}
