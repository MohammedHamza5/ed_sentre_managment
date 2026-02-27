import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/supabase/supabase_client.dart';
import '../../../../core/supabase/auth_service.dart';
import '../../../../shared/models/auth_models.dart';
import '../../../../shared/models/pricing_models.dart';

class SettingsLocalSource {
  static const String _keyUsers = 'cache_settings_users';
  static const String _keyRoles = 'cache_settings_roles';
  static const String _keyPrices = 'cache_settings_course_prices';
  static const String _keyBillableCount = 'cache_settings_billable_count';
  static const String _keyAiStats = 'cache_settings_ai_stats';

  Future<String> _composeKey(String base, {String? centerId}) async {
    String? cid = centerId;
    cid ??= await AuthService.getSavedCenterId();
    cid ??= SupabaseClientManager.currentUser?.userMetadata?['center_id'] ??
        SupabaseClientManager.currentUser?.userMetadata?['default_center_id'];
    if (cid == null || cid.toString().isEmpty) return base;
    return '${base}_$cid';
  }

  Future<void> saveCenterUsers(List<CenterUser> users) async {
    final prefs = await SharedPreferences.getInstance();
    final key = await _composeKey(_keyUsers);
    final data = users.map((u) => {
          'id': u.id,
          'full_name': u.fullName,
          'email': u.email,
          'phone': u.phone,
          'role': u.role,
          'is_active': u.isActive,
          'avatar_url': u.avatarUrl,
        }).toList();
    await prefs.setString(key, jsonEncode(data));
    await prefs.setString('${key}_timestamp', DateTime.now().toIso8601String());
    debugPrint('💾 [SettingsLocal] Saved ${users.length} center users');
  }

  Future<List<CenterUser>> getCenterUsers() async {
    final prefs = await SharedPreferences.getInstance();
    final key = await _composeKey(_keyUsers);
    final data = prefs.getString(key);
    if (data == null || data.isEmpty) return [];
    try {
      final list = jsonDecode(data) as List;
      return list.map((m) => CenterUser.fromJson(Map<String, dynamic>.from(m))).toList();
    } catch (e) {
      debugPrint('⚠️ [SettingsLocal] Error loading center users: $e');
      return [];
    }
  }

  Future<DateTime?> getUsersLastCacheTime() async {
    final prefs = await SharedPreferences.getInstance();
    final key = await _composeKey(_keyUsers);
    final timeStr = prefs.getString('${key}_timestamp');
    if (timeStr == null) return null;
    return DateTime.tryParse(timeStr);
  }

  Future<void> saveCenterRoles(List<AppRole> roles) async {
    final prefs = await SharedPreferences.getInstance();
    final key = await _composeKey(_keyRoles);
    final data = roles
        .map((r) => {
              'id': r.id,
              'center_id': r.centerId,
              'name': r.name,
              'name_ar': r.nameAr,
              'description': r.description,
              'is_system': r.isSystem,
              'role_permissions': r.permissions
                  .map((p) => {'permission_code': p})
                  .toList(),
              'created_at': r.createdAt.toIso8601String(),
            })
        .toList();
    await prefs.setString(key, jsonEncode(data));
    await prefs.setString('${key}_timestamp', DateTime.now().toIso8601String());
    debugPrint('💾 [SettingsLocal] Saved ${roles.length} roles');
  }

  Future<List<AppRole>> getCenterRoles() async {
    final prefs = await SharedPreferences.getInstance();
    final key = await _composeKey(_keyRoles);
    final data = prefs.getString(key);
    if (data == null || data.isEmpty) return [];
    try {
      final list = jsonDecode(data) as List;
      return list.map((m) => AppRole.fromJson(Map<String, dynamic>.from(m))).toList();
    } catch (e) {
      debugPrint('⚠️ [SettingsLocal] Error loading roles: $e');
      return [];
    }
  }

  Future<DateTime?> getRolesLastCacheTime() async {
    final prefs = await SharedPreferences.getInstance();
    final key = await _composeKey(_keyRoles);
    final timeStr = prefs.getString('${key}_timestamp');
    if (timeStr == null) return null;
    return DateTime.tryParse(timeStr);
  }

  Future<void> saveCoursePrices(String centerId, List<CoursePrice> prices) async {
    final prefs = await SharedPreferences.getInstance();
    final key = await _composeKey(_keyPrices, centerId: centerId);
    final data = prices
        .map((c) => {
              ...c.toJson(),
              'teacher_name': c.teacherName,
              'created_at': c.createdAt.toIso8601String(),
              'updated_at': c.updatedAt.toIso8601String(),
            })
        .toList();
    await prefs.setString(key, jsonEncode(data));
    await prefs.setString('${key}_timestamp', DateTime.now().toIso8601String());
    debugPrint('💾 [SettingsLocal] Saved ${prices.length} course prices');
  }

  Future<List<CoursePrice>> getCoursePrices(String centerId) async {
    final prefs = await SharedPreferences.getInstance();
    final key = await _composeKey(_keyPrices, centerId: centerId);
    final data = prefs.getString(key);
    if (data == null || data.isEmpty) return [];
    try {
      final list = jsonDecode(data) as List;
      return list
          .map((m) => CoursePrice.fromJson(Map<String, dynamic>.from(m)))
          .toList();
    } catch (e) {
      debugPrint('⚠️ [SettingsLocal] Error loading course prices: $e');
      return [];
    }
  }

  Future<DateTime?> getCoursePricesLastCacheTime(String centerId) async {
    final prefs = await SharedPreferences.getInstance();
    final key = await _composeKey(_keyPrices, centerId: centerId);
    final timeStr = prefs.getString('${key}_timestamp');
    if (timeStr == null) return null;
    return DateTime.tryParse(timeStr);
  }

  Future<void> saveBillableActiveEnrollmentsCount(int count) async {
    final prefs = await SharedPreferences.getInstance();
    final key = await _composeKey(_keyBillableCount);
    await prefs.setInt(key, count);
    await prefs.setString('${key}_timestamp', DateTime.now().toIso8601String());
  }

  Future<int> getBillableActiveEnrollmentsCount() async {
    final prefs = await SharedPreferences.getInstance();
    final key = await _composeKey(_keyBillableCount);
    return prefs.getInt(key) ?? 0;
  }

  Future<DateTime?> getBillableCountLastCacheTime() async {
    final prefs = await SharedPreferences.getInstance();
    final key = await _composeKey(_keyBillableCount);
    final timeStr = prefs.getString('${key}_timestamp');
    if (timeStr == null) return null;
    return DateTime.tryParse(timeStr);
  }

  Future<void> saveAiUsageStats(Map<String, int> stats) async {
    final prefs = await SharedPreferences.getInstance();
    final key = await _composeKey(_keyAiStats);
    await prefs.setString(key, jsonEncode(stats));
    await prefs.setString('${key}_timestamp', DateTime.now().toIso8601String());
  }

  Future<Map<String, int>> getAiUsageStats() async {
    final prefs = await SharedPreferences.getInstance();
    final key = await _composeKey(_keyAiStats);
    final data = prefs.getString(key);
    if (data == null || data.isEmpty) return {'questions': 0, 'exams': 0, 'reports': 0};
    try {
      final map = Map<String, dynamic>.from(jsonDecode(data));
      return {
        'questions': (map['questions'] as num?)?.toInt() ?? 0,
        'exams': (map['exams'] as num?)?.toInt() ?? 0,
        'reports': (map['reports'] as num?)?.toInt() ?? 0,
      };
    } catch (e) {
      debugPrint('⚠️ [SettingsLocal] Error loading AI stats: $e');
      return {'questions': 0, 'exams': 0, 'reports': 0};
    }
  }

  Future<DateTime?> getAiStatsLastCacheTime() async {
    final prefs = await SharedPreferences.getInstance();
    final key = await _composeKey(_keyAiStats);
    final timeStr = prefs.getString('${key}_timestamp');
    if (timeStr == null) return null;
    return DateTime.tryParse(timeStr);
  }
}

