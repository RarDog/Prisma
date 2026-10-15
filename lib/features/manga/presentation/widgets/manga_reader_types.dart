import 'package:flutter/material.dart';

enum MangaReaderMode {
  pagedRtl,
  pagedLtr,
  webtoon,
}

enum MangaReaderTheme {
  black(Color(0xFF000000), 'OLED Чёрный', 'OLED Black'),
  dark(Color(0xFF141418), 'Тёмный', 'Dark Gray'),
  sepia(Color(0xFF2B241E), 'Сепия', 'Sepia'),
  white(Color(0xFFF4F3ED), 'Светлый', 'Light Paper');

  const MangaReaderTheme(this.backgroundColor, this.labelRu, this.labelEn);
  final Color backgroundColor;
  final String labelRu;
  final String labelEn;
}
