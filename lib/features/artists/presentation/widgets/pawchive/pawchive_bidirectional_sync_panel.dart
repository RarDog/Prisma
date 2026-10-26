import 'package:flutter/material.dart';

/// Panel configuring bidirectional sync and pushing local favorites to the
/// active Pawchive account.
class PawchiveBidirectionalSyncPanel extends StatelessWidget {
  const PawchiveBidirectionalSyncPanel({
    super.key,
    required this.bidirectionalSync,
    required this.localFavoritesCount,
    required this.targetUsername,
    required this.busy,
    required this.pushing,
    required this.isRu,
    required this.onToggleBidirectional,
    required this.onPush,
  });

  final bool bidirectionalSync;
  final int localFavoritesCount;
  final String targetUsername;
  final bool busy;
  final bool pushing;
  final bool isRu;
  final ValueChanged<bool> onToggleBidirectional;
  final VoidCallback onPush;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Card(
      elevation: 0,
      color: scheme.surfaceContainerHigh.withValues(alpha: 0.6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: scheme.outlineVariant.withValues(alpha: 0.3),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.swap_vert_rounded, size: 20, color: scheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isRu
                        ? 'Двусторонняя синхронизация'
                        : 'Bidirectional sync',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Switch(
                  value: bidirectionalSync,
                  onChanged: onToggleBidirectional,
                ),
              ],
            ),
            Text(
              isRu
                  ? 'При обычной синхронизации также выгружать всех локальных авторов на сервер Pawchive.'
                  : 'During normal sync, also upload all local artists to Pawchive server.',
              style: TextStyle(
                color: scheme.onSurfaceVariant,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: busy ? null : onPush,
              icon: pushing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child:
                          CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.cloud_upload_rounded, size: 18),
              label: Text(
                isRu
                    ? 'Выгрузить избранное ($localFavoritesCount) в @$targetUsername'
                    : 'Push favorites ($localFavoritesCount) to @$targetUsername',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
