import 'dart:typed_data';

class UgoiraFrame {
  const UgoiraFrame({
    required this.file,
    required this.delayMs,
    this.bytes,
  });

  final String file;
  final int delayMs;
  final Uint8List? bytes;

  UgoiraFrame copyWith({Uint8List? bytes}) {
    return UgoiraFrame(
      file: file,
      delayMs: delayMs,
      bytes: bytes ?? this.bytes,
    );
  }

  Map<String, dynamic> toJson() => {
        'file': file,
        'delay': delayMs,
      };

  factory UgoiraFrame.fromJson(Map<String, dynamic> json) {
    return UgoiraFrame(
      file: json['file']?.toString() ?? '',
      delayMs: int.tryParse('${json['delay'] ?? 100}') ?? 100,
    );
  }
}

class UgoiraMetadata {
  const UgoiraMetadata({
    required this.zipUrl,
    required this.originalZipUrl,
    required this.mimeType,
    required this.frames,
  });

  final String zipUrl;
  final String originalZipUrl;
  final String mimeType;
  final List<UgoiraFrame> frames;

  int get totalDurationMs =>
      frames.fold(0, (sum, frame) => sum + frame.delayMs);

  Map<String, dynamic> toJson() => {
        'src': zipUrl,
        'originalSrc': originalZipUrl,
        'mime_type': mimeType,
        'frames': frames.map((f) => f.toJson()).toList(),
      };
}
