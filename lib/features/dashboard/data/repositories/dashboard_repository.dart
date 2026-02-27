import 'package:flutter/foundation.dart';
import '../../../../core/offline/network_monitor.dart';
import '../sources/dashboard_remote_source.dart';

class DashboardRepository {
  final DashboardRemoteSource _remoteSource;
  final NetworkMonitor _networkMonitor;

  DashboardRepository({
    DashboardRemoteSource? remoteSource,
    NetworkMonitor? networkMonitor,
  }) : _remoteSource = remoteSource ?? DashboardRemoteSource(),
       _networkMonitor = networkMonitor ?? NetworkMonitor();

  Future<Map<String, dynamic>> getDashboardSummary({String? centerId}) async {
    if (!_networkMonitor.isOnline) {
      debugPrint('📴 [DashboardRepo] Offline: Returning empty summary');
      // TODO: Implement local caching for dashboard if needed
      return {};
    }

    try {
      return await _remoteSource.getDashboardSummary(centerId: centerId);
    } catch (e) {
      debugPrint('❌ [DashboardRepo] Remote fetch failed: $e');
      return {};
    }
  }
}


