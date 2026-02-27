import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../shared/models/models.dart';
import '../../../../core/supabase/supabase_client.dart';

class SubjectsLocalSource {
  static const String _keySubjects = 'cache_subjects';
  
  Future<String> _composeKey(String base) async {
    final user = SupabaseClientManager.currentUser;
    final cid = user?.userMetadata?['center_id'] ?? user?.userMetadata?['default_center_id'];
    if (cid == null || cid.toString().isEmpty) return base;
    return '${base}_$cid';
  }

  Future<void> saveSubjects(List<Subject> subjects) async {
    final prefs = await SharedPreferences.getInstance();
    final data = subjects.map((s) => _subjectToMap(s)).toList();
    final key = await _composeKey(_keySubjects);
    await prefs.setString(key, jsonEncode(data));
    await prefs.setString('${key}_timestamp', DateTime.now().toIso8601String());
    debugPrint('💾 [SubjectsLocal] Saved ${subjects.length} subjects');
  }

  Future<List<Subject>> getSubjects() async {
    final prefs = await SharedPreferences.getInstance();
    final key = await _composeKey(_keySubjects);
    final data = prefs.getString(key);
    if (data == null || data.isEmpty) return [];

    try {
      final list = jsonDecode(data) as List;
      final subjects = list.map((m) => _mapToSubject(m)).toList();
      debugPrint('💾 [SubjectsLocal] Loaded ${subjects.length} subjects');
      return subjects;
    } catch (e) {
      debugPrint('⚠️ [SubjectsLocal] Error loading subjects: $e');
      return [];
    }
  }

  Future<DateTime?> getLastCacheTime() async {
    final prefs = await SharedPreferences.getInstance();
    final key = await _composeKey(_keySubjects);
    final timeStr = prefs.getString('${key}_timestamp');
    if (timeStr == null) return null;
    return DateTime.tryParse(timeStr);
  }

  // Mappers
  Map<String, dynamic> _subjectToMap(Subject s) => {
    'id': s.id,
    'name': s.name,
    'description': s.description,
    'monthlyFee': s.monthlyFee,
    'teacherIds': s.teacherIds,
    'isActive': s.isActive,
    'studentCount': s.studentCount,
    'gradeLevel': s.gradeLevel,
  };

  Subject _mapToSubject(Map<String, dynamic> m) => Subject(
    id: m['id'] ?? '',
    name: m['name'] ?? '',
    description: m['description'],
    monthlyFee: (m['monthlyFee'] ?? 0).toDouble(),
    teacherIds: List<String>.from(m['teacherIds'] ?? []),
    isActive: m['isActive'] ?? true,
    studentCount: m['studentCount'] ?? 0,
    gradeLevel: m['gradeLevel'],
  );
}


