import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../shared/models/models.dart';
import '../../../../core/supabase/supabase_client.dart';

class StudentsLocalSource {
  static const String _keyStudents = 'cache_students';
  static const String _keyTimestamp = 'cache_students_timestamp';

  Future<String> _composeKey(String base) async {
    final user = SupabaseClientManager.currentUser;
    final cid = user?.userMetadata?['center_id'] ?? user?.userMetadata?['default_center_id'];
    if (cid == null || cid.toString().isEmpty) return base;
    return '${base}_$cid';
  }

  Future<void> saveStudents(List<Student> students) async {
    final prefs = await SharedPreferences.getInstance();
    final data = students.map((s) => _studentToMap(s)).toList();
    final key = await _composeKey(_keyStudents);
    await prefs.setString(key, jsonEncode(data));
    await prefs.setString('${key}_timestamp', DateTime.now().toIso8601String());
    debugPrint('💾 [StudentsLocal] Saved ${students.length} students');
  }

  Future<List<Student>> getStudents() async {
    final prefs = await SharedPreferences.getInstance();
    final key = await _composeKey(_keyStudents);
    final data = prefs.getString(key);
    if (data == null || data.isEmpty) return [];

    try {
      final list = jsonDecode(data) as List;
      final students = list.map((m) => _mapToStudent(m)).toList();
      debugPrint('💾 [StudentsLocal] Loaded ${students.length} students');
      return students;
    } catch (e) {
      debugPrint('⚠️ [StudentsLocal] Error loading students: $e');
      return [];
    }
  }

  Future<DateTime?> getLastCacheTime() async {
    final prefs = await SharedPreferences.getInstance();
    final key = await _composeKey(_keyStudents);
    final timeStr = prefs.getString('${key}_timestamp');
    if (timeStr == null) return null;
    return DateTime.tryParse(timeStr);
  }

  // Mappers
  Map<String, dynamic> _studentToMap(Student s) => {
    'id': s.id,
    'name': s.name,
    'phone': s.phone,
    'studentNumber': s.studentNumber,
    'email': s.email,
    'imageUrl': s.imageUrl,
    'birthDate': s.birthDate.toIso8601String(),
    'address': s.address,
    'stage': s.stage,
    'subjectIds': s.subjectIds,
    'parentId': s.parentId,
    'status': s.status.name,
    'createdAt': s.createdAt.toIso8601String(),
    'lastAttendance': s.lastAttendance?.toIso8601String(),
  };

  Student _mapToStudent(Map<String, dynamic> m) => Student(
    id: m['id'] ?? '',
    name: m['name'] ?? '',
    phone: m['phone'] ?? '',
    studentNumber: m['studentNumber'],
    email: m['email'],
    imageUrl: m['imageUrl'],
    birthDate: DateTime.tryParse(m['birthDate'] ?? '') ?? DateTime.now(),
    address: m['address'] ?? '',
    stage: m['stage'] ?? '',
    subjectIds: List<String>.from(m['subjectIds'] ?? []),
    parentId: m['parentId'],
    status: _parseStudentStatus(m['status']),
    createdAt: DateTime.tryParse(m['createdAt'] ?? '') ?? DateTime.now(),
    lastAttendance: m['lastAttendance'] != null 
        ? DateTime.tryParse(m['lastAttendance']) 
        : null,
  );

  StudentStatus _parseStudentStatus(String? status) {
    switch (status) {
      case 'active': return StudentStatus.active;
      case 'suspended': return StudentStatus.suspended;
      case 'overdue': return StudentStatus.overdue;
      case 'inactive': return StudentStatus.inactive;
      default: return StudentStatus.active;
    }
  }
}


