import 'package:flutter_test/flutter_test.dart';
import 'package:gel_rule_app/core/http/dio_client.dart';
import 'package:gel_rule_app/sources/booru/ranobelib_provider.dart';

void main() {
  test('RanobeLibProvider fetches various novel chapters', () async {
    final client = DioClient();
    final p = RanobeLibProvider(
      id: 'ranobelib',
      name: 'RanobeLib',
      baseUrl: 'https://api.cdnlibs.org/api',
      dioClient: client,
    );

    final novelIds = [
      '6709--youkoso-jitsuryoku-shijou-shugi-no-kyoushitsu-e-novel',
      '17971--trash-of-the-counts-family-novel',
      '26690--omniscient-readers-viewpoint-novel',
      '11407--solo-leveling',
    ];

    for (final nid in novelIds) {
      final chapters = await p.fetchChapters(nid);
      expect(chapters, isNotEmpty);
      final ch0 = chapters.first;
      final content0 = await p.fetchChapterContent(ch0.id);
      expect(content0, isNotEmpty);

      if (chapters.length > 1) {
        final ch1 = chapters[1];
        final content1 = await p.fetchChapterContent(ch1.id);
        expect(content1, isNotEmpty);
      }
    }
  });
}
