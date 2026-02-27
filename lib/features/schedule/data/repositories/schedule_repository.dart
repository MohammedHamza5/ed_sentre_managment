import 'package:flutter/foundation.dart';
import '../../../../core/offline/network_monitor.dart';
import '../../../../shared/models/models.dart';
import '../sources/schedule_local_source.dart';
import '../sources/schedule_remote_source.dart';

class ScheduleRepository {
  final ScheduleRemoteSource _remoteSource;
  final ScheduleLocalSource _localSource;
  final NetworkMonitor _networkMonitor;

  static const Duration _cacheTTL = Duration(minutes: 5);

  ScheduleRepository({
    ScheduleRemoteSource? remoteSource,
    ScheduleLocalSource? localSource,
    NetworkMonitor? networkMonitor,
  }) : _remoteSource = remoteSource ?? ScheduleRemoteSource(),
       _localSource = localSource ?? ScheduleLocalSource(),
       _networkMonitor = networkMonitor ?? NetworkMonitor();

  Future<void> invalidateCache() async {
    await _localSource.clearSessions();
  }

  Future<List<ScheduleSession>> getSessions({bool forceRefresh = false}) async {
    // 1. Check cache validity
    final lastCacheTime = await _localSource.getLastCacheTime();
    final isCacheValid =
        lastCacheTime != null &&
        DateTime.now().difference(lastCacheTime) < _cacheTTL;

    // 2. Return local if valid and no force refresh
    if (!forceRefresh && isCacheValid) {
      final localData = await _localSource.getSessions();
      if (localData.isNotEmpty) {
        debugPrint(
          '⚡ [ScheduleRepo] Returning cached sessions (${localData.length})',
        );
        return localData;
      }
    }

    // 3. If offline, return local whatever we have
    if (!_networkMonitor.isOnline) {
      debugPrint('📴 [ScheduleRepo] Offline: Returning local sessions');
      return await _localSource.getSessions();
    }

    // 4. Fetch from remote
    try {
      final remoteData = await _remoteSource.getSessions();
      await _localSource.saveSessions(remoteData);
      return remoteData;
    } catch (e) {
      debugPrint('❌ [ScheduleRepo] Remote fetch failed: $e');
      // Fallback to local on error
      return await _localSource.getSessions();
    }
  }

  Future<ScheduleSession> addSession(ScheduleSession session) async {
    if (!_networkMonitor.isOnline) {
      throw Exception('Adding session is only available online');
    }

    final newSession = await _remoteSource.addSession(session);

    // Invalidate cache to force refresh next time
    await invalidateCache();
    return newSession;
  }

  Future<void> updateSession(ScheduleSession session) async {
    if (!_networkMonitor.isOnline) {
      throw Exception('Updating session is only available online');
    }
    await _remoteSource.updateSession(session);
    await invalidateCache();
  }

  Future<void> deleteSession(String id) async {
    if (!_networkMonitor.isOnline) {
      throw Exception('Deleting session is only available online');
    }
    await _remoteSource.deleteSession(id);
    await invalidateCache();
  }

  Future<List<Room>> getRooms() async {
    if (!_networkMonitor.isOnline) {
      // TODO: Add local caching for rooms
      debugPrint('📴 [ScheduleRepo] Offline: Cannot fetch rooms');
      return [];
    }
    return await _remoteSource.getRooms();
  }

  Future<List<ScheduleSession>> checkScheduleConflict({
    required String teacherId,
    required int dayOfWeek,
    required String startTime,
    required String endTime,
    String? excludeSessionId,
  }) async {
    if (!_networkMonitor.isOnline) return [];
    return await _remoteSource.checkScheduleConflict(
      teacherId: teacherId,
      dayOfWeek: dayOfWeek,
      startTime: startTime,
      endTime: endTime,
      excludeSessionId: excludeSessionId,
    );
  }
}


