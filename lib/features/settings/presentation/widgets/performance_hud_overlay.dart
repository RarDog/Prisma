import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:gel_rule_app/backend/backend.dart';
import 'package:gel_rule_app/core/performance/performance_monitor.dart';
import 'package:gel_rule_app/features/settings/presentation/settings_controller.dart';

class PerformanceHudOverlay extends ConsumerStatefulWidget {
  const PerformanceHudOverlay({super.key});

  @override
  ConsumerState<PerformanceHudOverlay> createState() => _PerformanceHudOverlayState();
}

class _PerformanceHudOverlayState extends ConsumerState<PerformanceHudOverlay> {
  Offset? _dragPosition;
  bool _isCollapsed = false;

  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(settingsControllerProvider);
    final settings = settingsAsync.value ?? AppSettings.defaults;

    if (!settings.debugHudEnabled) {
      return const SizedBox.shrink();
    }

    final metricsAsync = ref.watch(performanceMetricsStreamProvider);
    final metrics = metricsAsync.value ?? const PerformanceMetrics();

    final screenSize = MediaQuery.sizeOf(context);
    final padding = MediaQuery.paddingOf(context);

    final currentPos = _dragPosition ?? Offset(settings.debugHudX, settings.debugHudY);

    // Keep within screen bounds
    final clampedX = currentPos.dx.clamp(
      padding.left + 8.0,
      (screenSize.width - (_isCollapsed ? 180.0 : 250.0) - padding.right).clamp(padding.left + 8.0, screenSize.width),
    );
    final clampedY = currentPos.dy.clamp(
      padding.top + 8.0,
      (screenSize.height - (_isCollapsed ? 48.0 : 180.0) - padding.bottom).clamp(padding.top + 8.0, screenSize.height),
    );

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final opacity = settings.debugHudOpacity.clamp(0.2, 1.0);

    return Positioned(
      left: clampedX,
      top: clampedY,
      child: GestureDetector(
        onPanUpdate: (details) {
          setState(() {
            _dragPosition = Offset(clampedX + details.delta.dx, clampedY + details.delta.dy);
          });
        },
        onPanEnd: (_) {
          if (_dragPosition != null) {
            ref.read(settingsControllerProvider.notifier).updateDebugHudSettings(
                  x: _dragPosition!.dx,
                  y: _dragPosition!.dy,
                );
          }
        },
        child: Material(
          type: MaterialType.transparency,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
              child: Container(
                constraints: BoxConstraints(
                  minWidth: _isCollapsed ? 120 : 220,
                  maxWidth: _isCollapsed ? 200 : 270,
                ),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.black.withValues(alpha: opacity * 0.85)
                      : Colors.white.withValues(alpha: opacity * 0.9),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.18)
                        : Colors.black.withValues(alpha: 0.12),
                    width: 1.0,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.12),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: _isCollapsed
                    ? _buildCollapsedContent(context, metrics, settings)
                    : _buildExpandedContent(context, metrics, settings),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCollapsedContent(
    BuildContext context,
    PerformanceMetrics metrics,
    AppSettings settings,
  ) {
    return InkWell(
      onTap: () => setState(() => _isCollapsed = false),
      borderRadius: BorderRadius.circular(10),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: const BoxDecoration(
              color: Color(0xFF10B981),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              '${PerformanceMetrics.formatBytes(metrics.rssBytes)} • ${metrics.cpuPercent.toStringAsFixed(1)}%',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 4),
          const Icon(Icons.unfold_more_rounded, size: 14),
        ],
      ),
    );
  }

  Widget _buildExpandedContent(
    BuildContext context,
    PerformanceMetrics metrics,
    AppSettings settings,
  ) {
    final theme = Theme.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: Color(0xFF10B981),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                const Text(
                  'Prisma HUD',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.2,
                  ),
                ),
              ],
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Collapse button
                GestureDetector(
                  onTap: () => setState(() => _isCollapsed = true),
                  child: Padding(
                    padding: const EdgeInsets.all(3),
                    child: Icon(
                      Icons.unfold_less_rounded,
                      size: 14,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                // Close button
                GestureDetector(
                  onTap: () {
                    ref
                        .read(settingsControllerProvider.notifier)
                        .updateDebugHudSettings(enabled: false);
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(3),
                    child: Icon(
                      Icons.close_rounded,
                      size: 14,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 6),

        // Metrics rows
        if (settings.debugHudShowRam)
          _buildMetricRow(
            icon: Icons.memory_rounded,
            label: 'RAM',
            color: const Color(0xFF8B5CF6),
            value: PerformanceMetrics.formatBytes(metrics.rssBytes),
            detail: 'кэш: ${PerformanceMetrics.formatBytes(metrics.imageCacheBytes)} (${metrics.imageCacheCount})',
          ),
        if (settings.debugHudShowCpu)
          _buildMetricRow(
            icon: Icons.speed_rounded,
            label: 'CPU',
            color: const Color(0xFF3B82F6),
            value: '${metrics.cpuPercent.toStringAsFixed(1)} %',
            detail: 'пик: ${PerformanceMetrics.formatBytes(metrics.maxRssBytes)}',
          ),
        if (settings.debugHudShowNetwork)
          _buildMetricRow(
            icon: Icons.wifi_rounded,
            label: 'NET',
            color: const Color(0xFF10B981),
            value: '↓ ${PerformanceMetrics.formatSpeed(metrics.downloadSpeedBytesPerSec)}',
            detail: 'всего: ${PerformanceMetrics.formatBytes(metrics.totalDownloadedBytes)}',
          ),
        if (settings.debugHudShowFps)
          _buildMetricRow(
            icon: Icons.monitor_heart_rounded,
            label: 'FPS',
            color: const Color(0xFFF59E0B),
            value: '${metrics.fps} FPS',
            detail: metrics.fps >= 58 ? 'плавно' : 'нагрузка',
          ),
      ],
    );
  }

  Widget _buildMetricRow({
    required IconData icon,
    required String label,
    required Color color,
    required String value,
    String? detail,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.5),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(icon, size: 11, color: color),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
          if (detail != null) ...[
            const Spacer(),
            Text(
              detail,
              style: TextStyle(
                fontSize: 9.5,
                color: Colors.grey.shade500,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
