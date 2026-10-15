import 'package:flutter/material.dart';

enum ArtistsTab {
  all,
  favorites,
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
