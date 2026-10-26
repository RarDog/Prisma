import 'package:flutter/material.dart';
import 'package:gel_rule_app/app/responsive.dart';

enum ArtistsTab {
  all,
  favorites,
}

/// Column count for the artist card grids: 1 on mobile, 2 on medium
/// tablets/narrow desktop, 3 on wide desktop.
int artistGridColumns(BuildContext context, BoxConstraints constraints) {
  if (Responsive.isMobile(context)) return 1;
  if (constraints.maxWidth >= 1100) return 3;
  if (constraints.maxWidth >= 760) return 2;
  return 1;
}

Color artistServiceColor(String service) {
  switch (service.toLowerCase()) {
    case 'patreon':
      return const Color(0xFFFF424D);
    case 'fanbox':
      return const Color(0xFF0096FA);
    case 'fantia':
      return const Color(0xFFFF2E74);
    case 'boosty':
      return const Color(0xFFF15F2C);
    case 'discord':
      return const Color(0xFF5865F2);
    case 'subscribestar':
      return const Color(0xFF009688);
    case 'gumroad':
      return const Color(0xFFFF90E8);
    case 'afdian':
      return const Color(0xFF946CE6);
    case 'fapello':
      return const Color(0xFFE8467C);
    default:
      return const Color(0xFF7C4DFF);
  }
}

String formatArtistServiceName(String s) {
  switch (s.toLowerCase()) {
    case 'patreon':
      return 'Patreon';
    case 'fanbox':
      return 'Pixiv Fanbox';
    case 'fantia':
      return 'Fantia';
    case 'boosty':
      return 'Boosty';
    case 'discord':
      return 'Discord';
    case 'fapello':
      return 'Fapello';
    default:
      return s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
  }
}

/// Human-friendly "updated" stamp: relative for the last month, absolute
/// date beyond that.
String formatArtistRelativeTime(DateTime dt, bool isRu) {
  final diff = DateTime.now().difference(dt);
  final minutes = diff.inMinutes;
  final hours = diff.inHours;
  final days = diff.inDays;
  if (minutes < 1) return isRu ? 'только что' : 'just now';
  if (minutes < 60) {
    return isRu
        ? '$minutes мин. назад'
        : '${minutes}m ago';
  }
  if (hours < 24) {
    return isRu
        ? '$hours ${_pluralRu(hours, 'час', 'часа', 'часов')} назад'
        : '${hours}h ago';
  }
  if (days < 7) {
    return isRu
        ? '$days ${_pluralRu(days, 'день', 'дня', 'дней')} назад'
        : days == 1
            ? 'yesterday'
            : '${days}d ago';
  }
  if (days < 30) {
    final weeks = (days / 7).floor();
    return isRu
        ? '$weeks ${_pluralRu(weeks, 'нед.', 'нед.', 'нед.')} назад'
        : '${weeks}w ago';
  }
  final d = dt.day.toString().padLeft(2, '0');
  final m = dt.month.toString().padLeft(2, '0');
  return '$d.$m.${dt.year}';
}

String _pluralRu(int n, String one, String few, String many) {
  final mod10 = n % 10;
  final mod100 = n % 100;
  if (mod10 == 1 && mod100 != 11) return one;
  if (mod10 >= 2 && mod10 <= 4 && (mod100 < 12 || mod100 > 14)) return few;
  return many;
}
