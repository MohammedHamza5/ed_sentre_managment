import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../shared/models/models.dart';
import '../../../../core/supabase/supabase_client.dart';

class GroupsLocalSource {
  static const String _keyGroups = 'cache_groups';
  
  Future<String> _composeKey(String base) async {
    final user = SupabaseClientManager.currentUser;
    final cid = user?.userMetadata?['center_id'] ?? user?.userMetadata?['default_center_id'];
    if (cid == null || cid.toString().isEmpty) return base;
    return '${base}_$cid';
  }

  Future<void> saveGroups(List<Group> groups) async {
    final prefs = await SharedPreferences.getInstance();
    final data = groups.map((g) => g.toJson()).toList();
    final key = await _composeKey(_keyGroups);
    await prefs.setString(key, jsonEncode(data));
    await prefs.setString('${key}_timestamp', DateTime.now().toIso8601String());
    debugPrint('💾 [GroupsLocal] Saved ${groups.length} groups');
  }

  Future<List<Group>> getGroups() async {
    final prefs = await SharedPreferences.getInstance();
    final key = await _composeKey(_keyGroups);
    final data = prefs.getString(key);
    if (data == null || data.isEmpty) return [];

    try {
      final list = jsonDecode(data) as List;
      final groups = list.map((m) => Group.fromJson(m as Map<String, dynamic>)).toList();
      debugPrint('💾 [GroupsLocal] Loaded ${groups.length} groups');
      return groups;
    } catch (e) {
      debugPrint('⚠️ [GroupsLocal] Error loading groups: $e');
      return [];
    }
  }

  Future<DateTime?> getLastCacheTime() async {
    final prefs = await SharedPreferences.getInstance();
    final key = await _composeKey(_keyGroups);
    final timeStr = prefs.getString('${key}_timestamp');
    if (timeStr == null) return null;
    return DateTime.tryParse(timeStr);
  }

  /// Clears the cache timestamp, forcing the next getGroups call
  /// to fetch from remote instead of returning stale cached data.
  Future<void> clearCacheTime() async {
    final prefs = await SharedPreferences.getInstance();
    final key = await _composeKey(_keyGroups);
    await prefs.remove('${key}_timestamp');
    debugPrint('🗑️ [GroupsLocal] Cache time cleared — next read will fetch remote');
  }
}


