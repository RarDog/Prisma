import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gel_rule_app/features/post/services/ugoira_service.dart';
import 'package:gel_rule_app/sources/models/ugoira_metadata.dart';

void main() {
  group('UgoiraService', () {
    test('unpackUgoiraZip decodes zip bytes and correlates frames accurately', () {
      // 1. Create a synthetic zip in memory with 2 files
      final archive = Archive();
      final frame0Bytes = Uint8List.fromList([1, 2, 3, 4]);
      final frame1Bytes = Uint8List.fromList([5, 6, 7, 8]);

      archive.addFile(ArchiveFile('000000.jpg', frame0Bytes.length, frame0Bytes));
      archive.addFile(ArchiveFile('000001.jpg', frame1Bytes.length, frame1Bytes));

      final encoder = ZipEncoder();
      final zipBytes = Uint8List.fromList(encoder.encode(archive)!);

      final meta = const UgoiraMetadata(
        zipUrl: 'https://example.com/ugoira.zip',
        originalZipUrl: 'https://example.com/ugoira0.zip',
        mimeType: 'image/vnd.pixiv.ugoira+zip',
        frames: [
          UgoiraFrame(file: '000000.jpg', delayMs: 120),
          UgoiraFrame(file: '000001.jpg', delayMs: 240),
        ],
      );

      final unpackedFrames = UgoiraService.unpackFramesSync(
        zipBytes: zipBytes,
        frames: meta.frames,
      );

      expect(unpackedFrames.length, equals(2));
      expect(unpackedFrames[0].file, equals('000000.jpg'));
      expect(unpackedFrames[0].delayMs, equals(120));
      expect(unpackedFrames[0].bytes, equals(frame0Bytes));

      expect(unpackedFrames[1].file, equals('000001.jpg'));
      expect(unpackedFrames[1].delayMs, equals(240));
      expect(unpackedFrames[1].bytes, equals(frame1Bytes));
    });

    test('unpackUgoiraZip handles frames even if archive file paths have leading subdirectories', () {
      final archive = Archive();
      final frame0Bytes = Uint8List.fromList([9, 8, 7]);
      archive.addFile(ArchiveFile('subfolder/000000.jpg', frame0Bytes.length, frame0Bytes));

      final encoder = ZipEncoder();
      final zipBytes = Uint8List.fromList(encoder.encode(archive)!);

      final meta = const UgoiraMetadata(
        zipUrl: 'https://example.com/ugoira.zip',
        originalZipUrl: 'https://example.com/ugoira0.zip',
        mimeType: 'image/vnd.pixiv.ugoira+zip',
        frames: [
          UgoiraFrame(file: '000000.jpg', delayMs: 100),
        ],
      );

      final unpackedFrames = UgoiraService.unpackFramesSync(
        zipBytes: zipBytes,
        frames: meta.frames,
      );

      expect(unpackedFrames.length, equals(1));
      expect(unpackedFrames[0].bytes, equals(frame0Bytes));
    });
  });
}
