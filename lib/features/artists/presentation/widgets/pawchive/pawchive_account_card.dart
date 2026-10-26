import 'package:flutter/material.dart';
import 'package:gel_rule_app/features/artists/models/pawchive_account.dart';

/// Connected Pawchive account tile with push/sync shortcuts and a
/// overflow menu (set active / push / delete).
class PawchiveAccountCard extends StatelessWidget {
  const PawchiveAccountCard({
    super.key,
    required this.account,
    required this.isSyncing,
    required this.isPushing,
    required this.isRu,
    required this.onPush,
    required this.onSync,
    required this.onSetActive,
    required this.onDelete,
  });

  final PawchiveAccount account;
  final bool isSyncing;
  final bool isPushing;
  final bool isRu;
  final VoidCallback onPush;
  final VoidCallback onSync;
  final VoidCallback onSetActive;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final acc = account;
    final isBusy = isSyncing || isPushing;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      color: acc.isActive
          ? scheme.primaryContainer.withValues(alpha: 0.35)
          : scheme.surfaceContainerHigh,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: acc.isActive
              ? scheme.primary.withValues(alpha: 0.6)
              : scheme.outlineVariant.withValues(alpha: 0.3),
          width: acc.isActive ? 1.5 : 1,
        ),
      ),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
        leading: CircleAvatar(
          backgroundColor:
              acc.isActive ? scheme.primary : scheme.surfaceContainerHighest,
          foregroundColor:
              acc.isActive ? scheme.onPrimary : scheme.onSurfaceVariant,
          child: Text(
            acc.username.isNotEmpty ? acc.username[0].toUpperCase() : 'P',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        title: Row(
          children: [
            Flexible(
              child: Text(
                acc.username,
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (acc.isActive) ...[
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  isRu ? 'Активен' : 'Active',
                  style: TextStyle(
                    color: scheme.primary,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Text(
            '${isRu ? "Авторов" : "Artists"}: ${acc.syncedArtistsCount} • ${acc.lastSyncedAt != null ? _formatDate(acc.lastSyncedAt!, isRu) : (isRu ? "не синхр." : "not synced")}',
            style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              visualDensity: VisualDensity.compact,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              padding: const EdgeInsets.all(6),
              iconSize: 18,
              icon: isPushing
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.cloud_upload_outlined),
              tooltip: isRu
                  ? 'Выгрузить локальное избранное в этот аккаунт'
                  : 'Push local favorites to this account',
              onPressed: isBusy ? null : onPush,
            ),
            IconButton(
              visualDensity: VisualDensity.compact,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              padding: const EdgeInsets.all(6),
              iconSize: 18,
              icon: isSyncing
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.sync_rounded),
              tooltip:
                  isRu ? 'Синхронизировать этот аккаунт' : 'Sync this account',
              onPressed: isBusy ? null : onSync,
            ),
            PopupMenuButton<String>(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 28, minHeight: 32),
              iconSize: 18,
              icon: const Icon(Icons.more_vert_rounded),
              onSelected: (val) {
                if (val == 'active') {
                  onSetActive();
                } else if (val == 'push') {
                  onPush();
                } else if (val == 'delete') {
                  onDelete();
                }
              },
              itemBuilder: (ctx) => [
                if (!acc.isActive)
                  PopupMenuItem(
                    value: 'active',
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle_outline_rounded,
                            size: 20),
                        const SizedBox(width: 8),
                        Text(isRu ? 'Сделать активным' : 'Set as active'),
                      ],
                    ),
                  ),
                PopupMenuItem(
                  value: 'push',
                  child: Row(
                    children: [
                      const Icon(Icons.cloud_upload_outlined, size: 20),
                      const SizedBox(width: 8),
                      Text(isRu ? 'Выгрузить в Pawchive' : 'Push to Pawchive'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      const Icon(Icons.delete_outline_rounded,
                          color: Colors.red, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        isRu ? 'Удалить аккаунт' : 'Delete account',
                        style: const TextStyle(color: Colors.red),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime dt, bool isRu) {
    final now = DateTime.now();
    if (now.difference(dt).inMinutes < 1) {
      return isRu
          ? '${now.difference(dt).inMinutes} мин назад'
          : '${now.difference(dt).inMinutes} min ago';
    }
    return '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}
