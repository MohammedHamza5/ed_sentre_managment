import '../../../../core/offline/network_monitor.dart';
import '../sources/notifications_remote_source.dart';

class NotificationsRepository {
  final NotificationsRemoteSource _remoteSource;
  final NetworkMonitor _networkMonitor;

  NotificationsRepository({
    NotificationsRemoteSource? remoteSource,
    NetworkMonitor? networkMonitor,
  }) : _remoteSource = remoteSource ?? NotificationsRemoteSource(),
       _networkMonitor = networkMonitor ?? NetworkMonitor();

  Future<List<Map<String, dynamic>>> getNotifications({int limit = 50}) async {
    if (!_networkMonitor.isOnline) {
      return []; // TODO: Implement local caching
    }
    return await _remoteSource.getNotifications(limit: limit);
  }

  Future<void> markNotificationRead(String id) async {
    if (!_networkMonitor.isOnline) return;
    await _remoteSource.markNotificationRead(id);
  }

  Future<void> markAllNotificationsRead() async {
    if (!_networkMonitor.isOnline) return;
    await _remoteSource.markAllNotificationsRead();
  }

  Future<int> getUnreadNotificationsCount() async {
    if (!_networkMonitor.isOnline) return 0;
    return await _remoteSource.getUnreadNotificationsCount();
  }

  Future<void> runSmartNotificationChecks() async {
    if (!_networkMonitor.isOnline) return;
    await _remoteSource.runSmartNotificationChecks();
  }
}


