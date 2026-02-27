import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../shared/models/models.dart';

class RoomsLocalSource {
  static const String _storageKey = 'cached_rooms';
  static const String _lastCacheTimeKey = 'rooms_cache_time';

  Future<List<Room>> getRooms() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_storageKey);
    if (jsonString == null) return [];

    try {
      final List<dynamic> jsonList = json.decode(jsonString);
      return jsonList
          .map((json) => _RoomLocalMapper.fromJson(json))
          .toList();
    } catch (e) {
      debugPrint('❌ [RoomsLocal] Parse Error: $e');
      return [];
    }
  }

  Future<void> saveRooms(List<Room> rooms) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = rooms
        .map((room) => _RoomLocalMapper.toJson(room))
        .toList();
    await prefs.setString(_storageKey, json.encode(jsonList));
    await prefs.setString(_lastCacheTimeKey, DateTime.now().toIso8601String());
  }

  Future<DateTime?> getLastCacheTime() async {
    final prefs = await SharedPreferences.getInstance();
    final timeStr = prefs.getString(_lastCacheTimeKey);
    if (timeStr == null) return null;
    return DateTime.tryParse(timeStr);
  }

  Future<void> clearCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_storageKey);
    await prefs.remove(_lastCacheTimeKey);
  }
}

class _RoomLocalMapper {
  static Room fromJson(Map<String, dynamic> json) {
    return Room(
      id: json['id'],
      number: json['number'],
      name: json['name'],
      capacity: json['capacity'],
      equipment: (json['equipment'] as List).map((e) => e.toString()).toList(),
      status: RoomStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => RoomStatus.available,
      ),
    );
  }

  static Map<String, dynamic> toJson(Room room) {
    return {
      'id': room.id,
      'number': room.number,
      'name': room.name,
      'capacity': room.capacity,
      'equipment': room.equipment,
      'status': room.status.name,
    };
  }
}


