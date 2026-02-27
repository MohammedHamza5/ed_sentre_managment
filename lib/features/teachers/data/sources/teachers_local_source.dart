import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../shared/models/models.dart';
import '../../../../core/supabase/supabase_client.dart';

class TeachersLocalSource {
  static const String _keyTeachers = 'cache_teachers';
  static const String _keyTimestamp = 'cache_teachers_timestamp';

  Future<String> _composeKey(String base) async {
    final user = SupabaseClientManager.currentUser;
    final cid = user?.userMetadata?['center_id'] ?? user?.userMetadata?['default_center_id'];
    if (cid == null || cid.toString().isEmpty) return base;
    return '${base}_$cid';
  }

  Future<void> saveTeachers(List<Teacher> teachers) async {
    final prefs = await SharedPreferences.getInstance();
    final data = teachers.map((t) => _teacherToMap(t)).toList();
    final key = await _composeKey(_keyTeachers);
    await prefs.setString(key, jsonEncode(data));
    await prefs.setString('${key}_timestamp', DateTime.now().toIso8601String());
    debugPrint('💾 [TeachersLocal] Saved ${teachers.length} teachers');
  }

  Future<List<Teacher>> getTeachers() async {
    final prefs = await SharedPreferences.getInstance();
    final key = await _composeKey(_keyTeachers);
    final data = prefs.getString(key);
    if (data == null || data.isEmpty) return [];

    try {
      final list = jsonDecode(data) as List;
      final teachers = list.map((m) => _mapToTeacher(m)).toList();
      debugPrint('💾 [TeachersLocal] Loaded ${teachers.length} teachers');
      return teachers;
    } catch (e) {
      debugPrint('⚠️ [TeachersLocal] Error loading teachers: $e');
      return [];
    }
  }

  Future<DateTime?> getLastCacheTime() async {
    final prefs = await SharedPreferences.getInstance();
    final key = await _composeKey(_keyTeachers);
    final timeStr = prefs.getString('${key}_timestamp');
    if (timeStr == null) return null;
    return DateTime.tryParse(timeStr);
  }

  // Mappers
  Map<String, dynamic> _teacherToMap(Teacher t) => {
    'id': t.id,
    'name': t.name,
    'phone': t.phone,
    'email': t.email,
    'imageUrl': t.imageUrl,
    'subjectIds': t.subjectIds,
    'salaryType': t.salaryType.name,
    'salaryAmount': t.salaryAmount,
    'isActive': t.isActive,
    'createdAt': t.createdAt.toIso8601String(),
    'rating': t.rating,
    'courseCount': t.courseCount,
    'studentCount': t.studentCount,
  };

  Teacher _mapToTeacher(Map<String, dynamic> m) => Teacher(
    id: m['id'] ?? '',
    name: m['name'] ?? '',
    phone: m['phone'] ?? '',
    email: m['email'],
    imageUrl: m['imageUrl'],
    subjectIds: List<String>.from(m['subjectIds'] ?? []),
    salaryType: _parseSalaryType(m['salaryType']),
    salaryAmount: (m['salaryAmount'] ?? 0).toDouble(),
    isActive: m['isActive'] ?? true,
    createdAt: DateTime.tryParse(m['createdAt'] ?? '') ?? DateTime.now(),
    rating: (m['rating'] ?? 0).toDouble(),
    courseCount: m['courseCount'] ?? 0,
    studentCount: m['studentCount'] ?? 0,
  );

  SalaryType _parseSalaryType(String? type) {
    switch (type) {
      case 'percentage': return SalaryType.percentage;
      case 'fixed': return SalaryType.fixed;
      case 'perSession': return SalaryType.perSession;
      default: return SalaryType.percentage;
    }
  }
}


