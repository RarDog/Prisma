import 'package:flutter/material.dart';

class HistoryTagItem {
  const HistoryTagItem({
    required this.tag,
    required this.providerId,
    required this.providerName,
    required this.count,
    required this.lastSeen,
  });

  final String tag;
  final String providerId;
  final String providerName;
  final int count;
  final DateTime lastSeen;

  Color get providerBrandColor {
    final pid = providerId.toLowerCase();
    if (pid.contains('gelbooru')) return const Color(0xFF006ffa);
    if (pid.contains('danbooru')) return const Color(0xFFe45f34);
    if (pid.contains('e621')) return const Color(0xFF00549e);
    if (pid.contains('rule34')) return const Color(0xFFaae5a4);
    if (pid.contains('safebooru')) return const Color(0xFF2e7d32);
    if (pid.contains('realbooru')) return const Color(0xFF455a64);
    if (pid.contains('wallhaven')) return const Color(0xFF10B981);
    if (pid.contains('arena') || pid.contains('are.na')) {
      return const Color(0xFF6366F1);
    }
    if (pid.contains('mangalib') || pid.contains('manga')) {
      return const Color(0xFFE53935);
    }
    return const Color(0xFF8B5CF6);
  }
}
