import 'dart:async';
import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:prisma_app/app/app.dart';
import 'package:prisma_app/app/app_strings.dart';
import 'package:prisma_app/backend/backend.dart';

/// Overlay that listens to [downloadTasksProvider] and places [DownloadDynamicIsland]
/// adaptively at the top-center on mobile or top-right on desktop.
class DownloadDynamicIslandOverlay extends ConsumerWidget {
  const DownloadDynamicIslandOverlay({
    super.key,
    required this.child,
  });

  final Widget? child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasks = ref.watch(downloadTasksProvider).value ?? const [];
    final visible = tasks
        .where((task) =>
            task.status == DownloadTaskStatus.running ||
            task.status == DownloadTaskStatus.queued ||
            task.status == DownloadTaskStatus.failed ||
            task.status == DownloadTaskStatus.completed)
        .toList();

    return Stack(
      children: [
        if (child != null) child!,
        if (visible.isNotEmpty)
          _AdaptiveIslandPosition(
            tasks: visible,
          ),
      ],
    );
  }
}

class _AdaptiveIslandPosition extends StatelessWidget {
  const _AdaptiveIslandPosition({required this.tasks});

  final List<DownloadTask> tasks;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final isDesktop = size.width >= 720;

    if (isDesktop) {
      return Positioned(
        top: 16,
        right: 16,
        child: SafeArea(
          child: DownloadDynamicIsland(tasks: tasks),
        ),
      );
    }

    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        top: true,
        bottom: false,
        child: Align(
          alignment: Alignment.topCenter,
          child: Padding(
            padding: const EdgeInsets.only(top: 8, left: 16, right: 16),
            child: DownloadDynamicIsland(tasks: tasks),
          ),
        ),
      ),
    );
  }
}

/// Frosted-glass Dynamic Island component displaying active and finished download tasks.
class DownloadDynamicIsland extends ConsumerStatefulWidget {
  const DownloadDynamicIsland({
    super.key,
    required this.tasks,
  });

  final List<DownloadTask> tasks;

  @override
  ConsumerState<DownloadDynamicIsland> createState() =>
      _DownloadDynamicIslandState();
}

class _DownloadDynamicIslandState extends ConsumerState<DownloadDynamicIsland> {
  bool _isExpanded = false;
  bool _isDismissed = false;
  Timer? _autoDismissTimer;
  int _lastTaskCount = 0;

  @override
  void initState() {
    super.initState();
    _lastTaskCount = widget.tasks.length;
    _checkAutoDismiss();
  }

  @override
  void didUpdateWidget(covariant DownloadDynamicIsland oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.tasks.length != _lastTaskCount) {
      _lastTaskCount = widget.tasks.length;
      if (_isDismissed) {
        setState(() => _isDismissed = false);
      }
    }
    _checkAutoDismiss();
  }

  @override
  void dispose() {
    _autoDismissTimer?.cancel();
    super.dispose();
  }

  void _checkAutoDismiss() {
    final hasActive = widget.tasks.any((t) =>
        t.status == DownloadTaskStatus.running ||
        t.status == DownloadTaskStatus.queued);

    if (!hasActive && !_isExpanded) {
      _autoDismissTimer ??= Timer(const Duration(seconds: 4), () {
        if (mounted && !_isExpanded) {
          setState(() => _isDismissed = true);
          ref.read(downloadManagerServiceProvider).clearFinished();
        }
      });
    } else {
      _autoDismissTimer?.cancel();
      _autoDismissTimer = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isDismissed || widget.tasks.isEmpty) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final strings = ref.watch(appStringsProvider);
    final manager = ref.read(downloadManagerServiceProvider);

    final activeTasks = widget.tasks
        .where((t) =>
            t.status == DownloadTaskStatus.running ||
            t.status == DownloadTaskStatus.queued)
        .toList();

    final finishedTasks = widget.tasks
        .where((t) =>
            t.status == DownloadTaskStatus.completed ||
            t.status == DownloadTaskStatus.failed ||
            t.status == DownloadTaskStatus.canceled)
        .toList();

    return Dismissible(
      key: const ValueKey('download_dynamic_island_dismissible'),
      direction: DismissDirection.horizontal,
      onDismissed: (_) {
        setState(() => _isDismissed = true);
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(_isExpanded ? 20 : 24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOutCubic,
            constraints: BoxConstraints(
              maxWidth: _isExpanded ? 380 : 280,
            ),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.black.withValues(alpha: _isExpanded ? 0.88 : 0.75)
                  : scheme.surface.withValues(alpha: _isExpanded ? 0.94 : 0.84),
              borderRadius: BorderRadius.circular(_isExpanded ? 20 : 24),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.14)
                    : scheme.outlineVariant.withValues(alpha: 0.5),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.15),
                  blurRadius: _isExpanded ? 24 : 12,
                  offset: Offset(0, _isExpanded ? 8 : 4),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: AnimatedCrossFade(
                duration: const Duration(milliseconds: 220),
                crossFadeState: _isExpanded
                    ? CrossFadeState.showSecond
                    : CrossFadeState.showFirst,
                firstChild: _buildCollapsedView(
                  context,
                  scheme,
                  strings,
                  activeTasks,
                  finishedTasks,
                ),
                secondChild: _buildExpandedView(
                  context,
                  scheme,
                  strings,
                  manager,
                  activeTasks,
                  finishedTasks,
                  isDark,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCollapsedView(
    BuildContext context,
    ColorScheme scheme,
    AppStrings strings,
    List<DownloadTask> activeTasks,
    List<DownloadTask> finishedTasks,
  ) {
    final primaryTask = activeTasks.isNotEmpty ? activeTasks.first : widget.tasks.first;
    final totalProgress = activeTasks.isNotEmpty
        ? activeTasks.map((t) => t.progress).reduce((a, b) => a + b) /
            activeTasks.length
        : 1.0;

    String statusText;
    if (activeTasks.isNotEmpty) {
      final percentStr = '${(totalProgress.clamp(0.0, 1.0) * 100).toInt()}%';
      if (activeTasks.length == 1) {
        statusText = '${strings.downloading} • $percentStr';
      } else {
        statusText = '${activeTasks.length} ${strings.ru ? 'файла' : 'files'} • $percentStr';
      }
    } else {
      final failedCount = widget.tasks
          .where((t) => t.status == DownloadTaskStatus.failed)
          .length;
      if (failedCount > 0) {
        statusText = '${strings.failed} ($failedCount)';
      } else {
        statusText = '✓ ${strings.downloaded}';
      }
    }

    return InkWell(
      onTap: () {
        setState(() {
          _isExpanded = true;
          _checkAutoDismiss();
        });
      },
      borderRadius: BorderRadius.circular(24),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildThumbnailOrIcon(primaryTask, size: 24),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                statusText,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.1,
                    ),
              ),
            ),
            const SizedBox(width: 6),
            Icon(
              Icons.expand_more_rounded,
              size: 18,
              color: scheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExpandedView(
    BuildContext context,
    ColorScheme scheme,
    AppStrings strings,
    DownloadManagerService manager,
    List<DownloadTask> activeTasks,
    List<DownloadTask> finishedTasks,
    bool isDark,
  ) {
    final paused = manager.queuePaused;

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(
                strings.download,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: scheme.primaryContainer.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${widget.tasks.length}',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: scheme.onPrimaryContainer,
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ),
              const Spacer(),
              IconButton(
                visualDensity: VisualDensity.compact,
                iconSize: 20,
                tooltip: paused ? strings.resumeQueue : strings.pauseQueue,
                onPressed: () {
                  if (paused) {
                    manager.resumeQueue();
                  } else {
                    manager.pauseQueue();
                  }
                  setState(() {});
                },
                icon: Icon(
                  paused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                ),
              ),
              if (activeTasks.isNotEmpty)
                IconButton(
                  visualDensity: VisualDensity.compact,
                  iconSize: 20,
                  tooltip: strings.cancelActive,
                  onPressed: () {
                    for (final task in activeTasks) {
                      manager.cancel(task.id);
                    }
                  },
                  icon: const Icon(Icons.cancel_rounded),
                ),
              if (finishedTasks.isNotEmpty)
                IconButton(
                  visualDensity: VisualDensity.compact,
                  iconSize: 20,
                  tooltip: strings.clearFinished,
                  onPressed: () {
                    manager.clearFinished();
                  },
                  icon: const Icon(Icons.clear_all_rounded),
                ),
              IconButton(
                visualDensity: VisualDensity.compact,
                iconSize: 20,
                tooltip: strings.ru ? 'Свернуть' : 'Collapse',
                onPressed: () {
                  setState(() {
                    _isExpanded = false;
                    _checkAutoDismiss();
                  });
                },
                icon: const Icon(Icons.expand_less_rounded),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Divider(
            height: 1,
            color: isDark ? Colors.white12 : Colors.black12,
          ),
          const SizedBox(height: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 280),
            child: ListView.separated(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              itemCount: widget.tasks.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final task = widget.tasks[index];
                return _buildTaskRow(context, scheme, strings, manager, task, isDark);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTaskRow(
    BuildContext context,
    ColorScheme scheme,
    AppStrings strings,
    DownloadManagerService manager,
    DownloadTask task,
    bool isDark,
  ) {
    final isRunning = task.status == DownloadTaskStatus.running;
    final isFailed = task.status == DownloadTaskStatus.failed;
    final isQueued = task.status == DownloadTaskStatus.queued;
    final isCompleted = task.status == DownloadTaskStatus.completed;

    return Row(
      children: [
        _buildThumbnailOrIcon(task, size: 36),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                task.fileName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 3),
              if (task.error != null)
                Text(
                  task.error!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: scheme.error,
                    fontSize: 11,
                  ),
                )
              else
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    minHeight: 4,
                    value: isRunning
                        ? task.progress.clamp(0.0, 1.0)
                        : (isCompleted ? 1.0 : (isQueued ? null : 0.0)),
                    backgroundColor: isDark ? Colors.white12 : Colors.black12,
                    valueColor: AlwaysStoppedAnimation(
                      isFailed
                          ? scheme.error
                          : (isCompleted ? Colors.greenAccent : scheme.primary),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(width: 6),
        if (isFailed)
          IconButton(
            visualDensity: VisualDensity.compact,
            iconSize: 20,
            tooltip: strings.retry,
            onPressed: () => manager.retry(task.id),
            icon: const Icon(Icons.refresh_rounded),
          )
        else if (isRunning || isQueued)
          IconButton(
            visualDensity: VisualDensity.compact,
            iconSize: 20,
            tooltip: strings.cancel,
            onPressed: () => manager.cancel(task.id),
            icon: const Icon(Icons.close_rounded),
          )
        else if (isCompleted)
          const Padding(
            padding: EdgeInsets.all(8.0),
            child: Icon(
              Icons.check_circle_rounded,
              color: Colors.greenAccent,
              size: 20,
            ),
          ),
      ],
    );
  }

  Widget _buildThumbnailOrIcon(DownloadTask task, {required double size}) {
    final previewUrl = task.post?.previewUrl ?? task.post?.sampleUrl;

    if (previewUrl != null && previewUrl.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: SizedBox(
          width: size,
          height: size,
          child: CachedNetworkImage(
            imageUrl: previewUrl,
            fit: BoxFit.cover,
            placeholder: (_, __) => _buildStatusFallback(
              task.status,
              size,
              progress: task.progress,
            ),
            errorWidget: (_, __, ___) => _buildStatusFallback(
              task.status,
              size,
              progress: task.progress,
            ),
          ),
        ),
      );
    }

    return _buildStatusFallback(
      task.status,
      size,
      progress: task.progress,
    );
  }

  Widget _buildStatusFallback(
    DownloadTaskStatus status,
    double size, {
    double? progress,
  }) {
    final iconSize = size * 0.75;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(6),
      ),
      child: switch (status) {
        DownloadTaskStatus.completed => Icon(
            Icons.check_circle_rounded,
            color: Colors.greenAccent,
            size: iconSize,
          ),
        DownloadTaskStatus.failed => Icon(
            Icons.error_outline_rounded,
            color: Colors.redAccent,
            size: iconSize,
          ),
        DownloadTaskStatus.running => SizedBox(
            width: iconSize,
            height: iconSize,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              value: progress != null && progress > 0
                  ? progress.clamp(0.0, 1.0)
                  : 0.0,
            ),
          ),
        DownloadTaskStatus.queued => Icon(
            Icons.schedule_rounded,
            size: iconSize,
          ),
        _ => Icon(
            Icons.download_rounded,
            size: iconSize,
          ),
      },
    );
  }
}
