import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

class MangaReaderPageImage extends StatelessWidget {
  const MangaReaderPageImage({
    super.key,
    required this.url,
    this.headers,
    required this.fit,
    this.memWidth,
    this.backgroundColor,
  });

  final String url;
  final Map<String, String>? headers;
  final BoxFit fit;
  final int? memWidth;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    if (url.startsWith('/') || url.startsWith('file:')) {
      final cleanPath = url.replaceFirst('file://', '');
      return Image.file(
        File(cleanPath),
        fit: fit,
        width: fit == BoxFit.fitWidth ? double.infinity : null,
        alignment: Alignment.topCenter,
        errorBuilder: (_, __, ___) => const Center(
          child:
              Icon(Icons.broken_image_rounded, color: Colors.white38, size: 48),
        ),
      );
    }
    return CachedNetworkImage(
      imageUrl: url,
      httpHeaders: headers,
      fit: fit,
      width: fit == BoxFit.fitWidth ? double.infinity : null,
      alignment: Alignment.topCenter,
      memCacheWidth: memWidth,
      placeholder: (_, __) => AspectRatio(
        aspectRatio: 0.7,
        child: Container(
          color: backgroundColor ?? Colors.black,
          child: const Center(
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Color(0xFFFF6740),
            ),
          ),
        ),
      ),
      errorWidget: (_, __, ___) => Container(
        height: 300,
        color: Colors.black26,
        child: const Center(
          child:
              Icon(Icons.broken_image_rounded, color: Colors.white38, size: 48),
        ),
      ),
    );
  }
}
