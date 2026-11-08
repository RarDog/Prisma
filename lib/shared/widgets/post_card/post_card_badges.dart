import 'package:flutter/material.dart';
import 'package:gel_rule_app/app/motion.dart';

class FavoriteButton extends StatelessWidget {
  const FavoriteButton({
    super.key,
    required this.isFavorite,
    required this.onPressed,
  });

  final bool isFavorite;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return InkResponse(
      onTap: onPressed,
      radius: 20,
      child: AnimatedContainer(
        duration: AppMotion.duration(context, 150),
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.58),
          shape: BoxShape.circle,
          border: Border.all(
            color: isFavorite
                ? Colors.redAccent.withValues(alpha: 0.6)
                : Colors.white.withValues(alpha: 0.16),
            width: 0.9,
          ),
          boxShadow: [
            if (isFavorite)
              BoxShadow(
                color: Colors.redAccent.withValues(alpha: 0.35),
                blurRadius: 10,
              ),
          ],
        ),
        child: Center(
          child: Icon(
            isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
            color: isFavorite ? Colors.redAccent : Colors.white,
            size: 18,
          ),
        ),
      ),
    );
  }
}

class ProviderBadge extends StatelessWidget {
  const ProviderBadge({
    super.key,
    required this.name,
    this.providerId,
  });

  final String name;
  final String? providerId;

  static Color providerColor(String? id) {
    if (id == null) return const Color(0xFF64B5F6);
    final lower = id.toLowerCase();
    if (lower.contains('danbooru')) return const Color(0xFFE45F34);
    if (lower.contains('gelbooru')) return const Color(0xFF006FFA);
    if (lower.contains('rule34')) return const Color(0xFFAAE5A4);
    if (lower.contains('e621') || lower.contains('e926')) {
      return const Color(0xFF223C68);
    }
    if (lower.contains('safebooru')) return const Color(0xFF4AA3DF);
    if (lower.contains('realbooru')) return const Color(0xFFD44B38);
    if (lower.contains('tbib')) return const Color(0xFF5B92E5);
    if (lower.contains('wallhaven')) return const Color(0xFF888888);
    if (lower.contains('arena')) return const Color(0xFF444444);
    if (lower.contains('pixiv')) return const Color(0xFF0096FA);
    if (lower.contains('xvideos')) return const Color(0xFFE22626);
    return const Color(0xFF64B5F6);
  }

  @override
  Widget build(BuildContext context) {
    final accent = providerColor(providerId ?? name);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: accent.withValues(alpha: 0.45),
          width: 0.8,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 5.5,
            height: 5.5,
            decoration: BoxDecoration(
              color: accent,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 5.5),
          Flexible(
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 10.5,
                color: Colors.white,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class PageCountBadge extends StatelessWidget {
  const PageCountBadge({super.key, required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3.5),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.3),
          width: 0.7,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Icon(
            Icons.photo_library_rounded,
            size: 11,
            color: Colors.white,
          ),
          const SizedBox(width: 3.5),
          Text(
            '$count',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
              height: 1.1,
            ),
          ),
        ],
      ),
    );
  }
}

class DurationBadge extends StatelessWidget {
  const DurationBadge({super.key, required this.duration});

  final String duration;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.70),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.20),
          width: 0.7,
        ),
      ),
      child: Text(
        duration,
        style: const TextStyle(
          fontSize: 10,
          color: Colors.white,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
          height: 1.1,
        ),
      ),
    );
  }
}

class MediaBadge extends StatelessWidget {
  const MediaBadge({super.key, required this.fileType});

  final String fileType;

  Color _accentColor(String type) => switch (type) {
        'ugoira' => const Color(0xFFC084FC), // fuchsia/violet
        'video' => const Color(0xFFFBBF24), // amber
        'gif' => const Color(0xFF38BDF8), // cyan
        'audio' => const Color(0xFFA78BFA), // violet
        'text' => const Color(0xFF34D399), // emerald
        _ => Colors.white,
      };

  @override
  Widget build(BuildContext context) {
    final type = _type(fileType);
    final accent = _accentColor(type);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: accent.withValues(alpha: 0.40),
          width: 0.8,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_icon(type), size: 13, color: accent),
          const SizedBox(width: 4),
          Text(
            _label(type),
            style: TextStyle(
              fontSize: 10.5,
              color: Colors.white,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.3,
              shadows: [
                Shadow(
                  color: accent.withValues(alpha: 0.4),
                  blurRadius: 4,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _type(String raw) {
    final value = raw.toLowerCase();
    if (value.contains('ugoira')) return 'ugoira';
    if (value.contains('audio') ||
        value.contains('mp3') ||
        value.contains('wav') ||
        value.contains('flac') ||
        value.contains('ogg') ||
        value.contains('m4a')) {
      return 'audio';
    }
    if (value.contains('video') ||
        value.contains('webm') ||
        value.contains('mp4')) {
      return 'video';
    }
    if (value.contains('gif')) return 'gif';
    if (value.contains('text')) return 'text';
    return 'photo';
  }

  IconData _icon(String type) => switch (type) {
        'ugoira' => Icons.motion_photos_on_rounded,
        'audio' => Icons.music_note_rounded,
        'video' => Icons.play_arrow_rounded,
        'gif' => Icons.gif_box_rounded,
        'text' => Icons.article_rounded,
        _ => Icons.image_rounded,
      };

  String _label(String type) => switch (type) {
        'ugoira' => 'UGOIRA',
        'audio' => 'AUDIO',
        'video' => 'VIDEO',
        'gif' => 'GIF',
        'text' => 'TEXT',
        _ => 'PHOTO',
      };
}


class SeenBadge extends StatelessWidget {
  const SeenBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.20),
          width: 0.7,
        ),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.visibility_rounded, size: 12, color: Colors.white70),
          SizedBox(width: 3.5),
          Text(
            'seen',
            style: TextStyle(
              fontSize: 10,
              color: Colors.white70,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class DownloadedBadge extends StatelessWidget {
  const DownloadedBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: const Color(0xFF10B981).withValues(alpha: 0.45),
          width: 0.8,
        ),
      ),
      child: const Icon(
        Icons.download_done_rounded,
        size: 13,
        color: Color(0xFF34D399),
      ),
    );
  }
}
