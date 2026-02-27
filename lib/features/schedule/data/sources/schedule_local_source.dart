import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../shared/models/models.dart';

class ScheduleLocalSource {
  static const String _storageKey = 'cached_schedule_sessions';
  static const String _timestampKey = 'schedule_cache_timestamp';

  Future<List<ScheduleSession>> getSessions() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_storageKey);

      if (jsonString == null) return [];

      final List<dynamic> jsonList = json.decode(jsonString);
      return jsonList.map((json) => ScheduleSession.fromJson(json)).toList();
    } catch (e) {
      debugPrint('❌ [ScheduleLocal] Error reading cache: $e');
      return [];
    }
  }

  Future<void> saveSessions(List<ScheduleSession> sessions) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = sessions.map((s) => s.toJson()).toList();
      await prefs.setString(_storageKey, json.encode(jsonList));
      await prefs.setString(_timestampKey, DateTime.now().toIso8601String());
    } catch (e) {
      debugPrint('❌ [ScheduleLocal] Error saving cache: $e');
    }
  }

  Future<DateTime?> getLastCacheTime() async {
    final prefs = await SharedPreferences.getInstance();
    final timestamp = prefs.getString(_timestampKey);
    if (timestamp != null) {
      return DateTime.tryParse(timestamp);
    }
    return null;
  }

  Future<void> clearCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_storageKey);
    await prefs.remove(_timestampKey);
  }

  Future<void> clearSessions() async {
    await clearCache();
  }
}


