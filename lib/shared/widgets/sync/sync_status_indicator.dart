/// Sync Status Indicator
///
/// A widget that displays the current sync status in the app bar.
/// Shows sync progress, success, failure, and pending operations.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/sync/sync_service.dart';
import '../../../core/constants/app_colors.dart';

/// Sync Status Indicator Widget
///
/// Displays the current sync status with appropriate icons and colors.
class SyncStatusIndicator extends StatelessWidget {
  const SyncStatusIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<SyncService>(
      builder: (context, syncService, child) {
        return _buildSyncStatus(syncService, context);
      },
    );
  }

  Widget _buildSyncStatus(SyncService syncService, BuildContext context) {
    final status = syncService.status;
    final pendingChanges = syncService.pendingChanges;
    final hasPendingChanges = syncService.hasPendingChanges;

    // Determine icon and color based on status
    IconData icon;
    Color color;
    String tooltip;

    switch (status) {
      case SyncStatus.syncing:
        icon = Icons.sync;
        color = AppColors.warning;
        tooltip = 'جاري المزامنة...';
        break;
      case SyncStatus.success:
        icon = Icons.check_circle;
        color = AppColors.success;
        tooltip = 'تمت المزامنة بنجاح';
        break;
      case SyncStatus.failed:
        icon = Icons.error;
        color = AppColors.error;
        tooltip = 'فشلت المزامنة';
        break;
      case SyncStatus.conflict:
        icon = Icons.warning;
        color = AppColors.warning;
        tooltip = 'هناك تعارض في البيانات';
        break;
      case SyncStatus.idle:
      default:
        if (hasPendingChanges) {
          icon = Icons.cloud_upload;
          color = AppColors.info;
          tooltip = 'هناك بيانات بانتظار المزامنة ($pendingChanges)';
        } else {
          icon = Icons.cloud_done;
          color = AppColors.success;
          tooltip = 'البيانات محدثة';
        }
        break;
    }

    return Tooltip(
      message: tooltip,
      child: Stack(
        children: [
          IconButton(
            onPressed: () {
              // Show sync details or trigger manual sync
              _showSyncDetails(context, syncService);
            },
            icon: Icon(icon, color: color),
          ),
          // Show pending changes badge if there are pending changes
          if (hasPendingChanges && status != SyncStatus.syncing)
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: AppColors.error,
                  shape: BoxShape.circle,
                ),
                constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                child: Text(
                  pendingChanges > 9 ? '9+' : pendingChanges.toString(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _showSyncDetails(BuildContext context, SyncService syncService) {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return _SyncDetailsSheet(syncService: syncService);
      },
    );
  }
}

/// Sync Details Sheet
///
/// Shows detailed information about sync status and pending operations.
class _SyncDetailsSheet extends StatelessWidget {
  final SyncService syncService;

  const _SyncDetailsSheet({required this.syncService});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('حالة المزامنة', style: theme.textTheme.titleLarge),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Sync status indicator
          _buildStatusCard(syncService, theme, isDark),

          const SizedBox(height: 16),

          // Pending changes
          _buildPendingChangesCard(syncService, theme, isDark),

          const SizedBox(height: 16),

          // Actions
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ElevatedButton.icon(
                onPressed: syncService.isSyncing
                    ? null
                    : () {
                        syncService.syncAll();
                        Navigator.pop(context);
                      },
                icon: const Icon(Icons.sync),
                label: const Text('مزامنة الآن'),
              ),
              OutlinedButton.icon(
                onPressed: syncService.lastError == null
                    ? null
                    : () {
                        syncService.clearError();
                      },
                icon: const Icon(Icons.refresh),
                label: const Text('إعادة المحاولة'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusCard(
    SyncService syncService,
    ThemeData theme,
    bool isDark,
  ) {
    final status = syncService.status;
    final lastSyncTime = syncService.lastSyncTime;
    final lastError = syncService.lastError;

    IconData icon;
    Color color;
    String statusText;

    switch (status) {
      case SyncStatus.syncing:
        icon = Icons.sync;
        color = AppColors.warning;
        statusText = 'جاري المزامنة...';
        break;
      case SyncStatus.success:
        icon = Icons.check_circle;
        color = AppColors.success;
        statusText = 'تمت المزامنة بنجاح';
        break;
      case SyncStatus.failed:
        icon = Icons.error;
        color = AppColors.error;
        statusText = 'فشلت المزامنة';
        break;
      case SyncStatus.conflict:
        icon = Icons.warning;
        color = AppColors.warning;
        statusText = 'هناك تعارض في البيانات';
        break;
      case SyncStatus.idle:
      default:
        icon = Icons.cloud_done;
        color = AppColors.success;
        statusText = 'البيانات محدثة';
        break;
    }

    return Card(
      color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 24),
                const SizedBox(width: 8),
                Text(statusText, style: theme.textTheme.titleMedium),
              ],
            ),
            if (lastSyncTime != null) ...[
              const SizedBox(height: 8),
              Text(
                'آخر مزامنة: ${_formatDateTime(lastSyncTime)}',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: isDark
                      ? AppColors.darkTextSecondary
                      : AppColors.lightTextSecondary,
                ),
              ),
            ],
            if (lastError != null) ...[
              const SizedBox(height: 8),
              Text(
                'خطأ: $lastError',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppColors.error,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPendingChangesCard(
    SyncService syncService,
    ThemeData theme,
    bool isDark,
  ) {
    final pendingChanges = syncService.pendingChanges;
    final hasPendingChanges = syncService.hasPendingChanges;

    if (!hasPendingChanges) {
      return const SizedBox.shrink();
    }

    return Card(
      color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.cloud_upload, color: AppColors.info),
                const SizedBox(width: 8),
                Text(
                  'تغييرات بانتظار المزامنة',
                  style: theme.textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'يوجد $pendingChanges تغييرات لم تتم مزامنتها بعد',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: isDark
                    ? AppColors.darkTextSecondary
                    : AppColors.lightTextSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'الآن';
    } else if (difference.inMinutes < 60) {
      return 'منذ ${difference.inMinutes} دقيقة';
    } else if (difference.inHours < 24) {
      return 'منذ ${difference.inHours} ساعة';
    } else {
      return '${dateTime.year}/${dateTime.month}/${dateTime.day}';
    }
  }
}


