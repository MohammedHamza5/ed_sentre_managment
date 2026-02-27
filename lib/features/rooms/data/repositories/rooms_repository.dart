import 'package:flutter/foundation.dart';
import '../../../../core/offline/network_monitor.dart';
import '../../../../shared/models/models.dart';
import '../sources/rooms_local_source.dart';
import '../sources/rooms_remote_source.dart';

class RoomsRepository {
  final RoomsRemoteSource _remoteSource;
  final RoomsLocalSource _localSource;
  final NetworkMonitor _networkMonitor;

  static const Duration _cacheTTL = Duration(minutes: 5);

  RoomsRepository({
    RoomsRemoteSource? remoteSource,
    RoomsLocalSource? localSource,
    NetworkMonitor? networkMonitor,
  }) : _remoteSource = remoteSource ?? RoomsRemoteSource(),
       _localSource = localSource ?? RoomsLocalSource(),
       _networkMonitor = networkMonitor ?? NetworkMonitor();

  Future<List<Room>> getRooms({bool forceRefresh = false}) async {
    // 1. Check Cache
    final lastCacheTime = await _localSource.getLastCacheTime();
    final isCacheValid = lastCacheTime != null &&
        DateTime.now().difference(lastCacheTime) < _cacheTTL;

    if (!forceRefresh && isCacheValid) {
      final localData = await _localSource.getRooms();
      if (localData.isNotEmpty) {
        debugPrint('⚡ [RoomsRepo] Returning cached data (${localData.length})');
        return localData;
      }
    }

    // 2. Check Offline
    if (!_networkMonitor.isOnline) {
      debugPrint('📴 [RoomsRepo] Offline: Returning local data');
      return await _localSource.getRooms();
    }

    // 3. Fetch Remote
    try {
      final remoteData = await _remoteSource.getRooms();
      await _localSource.saveRooms(remoteData);
      return remoteData;
    } catch (e) {
      debugPrint('❌ [RoomsRepo] Remote fetch failed: $e');
      return await _localSource.getRooms();
    }
  }

  Future<Room> addRoom(Room room) async {
    if (!_networkMonitor.isOnline) {
      throw Exception('Adding rooms is only available online');
    }

    final newRoom = await _remoteSource.addRoom(room);

    // Optimistic Update
    final currentList = await _localSource.getRooms();
    currentList.add(newRoom);
    await _localSource.saveRooms(currentList);

    return newRoom;
  }

  Future<void> updateRoom(Room room) async {
    if (!_networkMonitor.isOnline) {
      throw Exception('Updating rooms is only available online');
    }

    await _remoteSource.updateRoom(room);

    // Optimistic Update
    final currentList = await _localSource.getRooms();
    final index = currentList.indexWhere((r) => r.id == room.id);
    if (index != -1) {
      currentList[index] = room;
      await _localSource.saveRooms(currentList);
    }
  }

  Future<void> deleteRoom(String id) async {
    if (!_networkMonitor.isOnline) {
      throw Exception('Deleting rooms is only available online');
    }

    await _remoteSource.deleteRoom(id);

    // Optimistic Update
    final currentList = await _localSource.getRooms();
    currentList.removeWhere((r) => r.id == id);
    await _localSource.saveRooms(currentList);
  }
}


