import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../shared/models/models.dart';
import '../../../../core/supabase/supabase_client.dart';

class AttendanceLocalSource {
  static const String _keyAttendance = 'cache_attendance';

  Future<String> _composeKey(String base) async {
    final user = SupabaseClientManager.currentUser;
    final cid =
        user?.userMetadata?['center_id'] ??
        user?.userMetadata?['default_center_id'];
    if (cid == null || cid.toString().isEmpty) return base;
    return '${base}_$cid';
  }

  // Universal QR Key Management
  static const String _keyUniversalQr = 'universal_qr_key';

  Future<void> saveUniversalQrKey(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final storageKey = await _composeKey(_keyUniversalQr);
    await prefs.setString(storageKey, key);
  }

  Future<String?> getUniversalQrKey() async {
    final prefs = await SharedPreferences.getInstance();
    final storageKey = await _composeKey(_keyUniversalQr);
    return prefs.getString(storageKey);
  }

  // Save attendance for a specific date
  Future<void> saveAttendance(
    DateTime date,
    List<AttendanceRecord> records,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final dateStr = date.toIso8601String().split('T')[0];
    final key = await _composeKey('${_keyAttendance}_$dateStr');

    // We might want to store as map to simplify upserts, but list is okay for full day replace
    final data = records.map((r) => _recordToMap(r)).toList();
    await prefs.setString(key, jsonEncode(data));
    debugPrint(
      '💾 [AttendanceLocal] Saved ${records.length} records for $dateStr',
    );
  }

  Future<List<AttendanceRecord>> getAttendanceByDate(DateTime date) async {
    final prefs = await SharedPreferences.getInstance();
    final dateStr = date.toIso8601String().split('T')[0];
    final key = await _composeKey('${_keyAttendance}_$dateStr');

    final data = prefs.getString(key);
    if (data == null || data.isEmpty) return [];

    try {
      final list = jsonDecode(data) as List;
      return list.map((m) => _mapToRecord(m)).toList();
    } catch (e) {
      debugPrint('⚠️ [AttendanceLocal] Error loading: $e');
      return [];
    }
  }

  // Mappers (Since AttendanceRecord doesn't have standard toJson/fromJson in shared models yet or I prefer explicit)
  Map<String, dynamic> _recordToMap(AttendanceRecord r) => {
    'id': r.id,
    'studentId': r.studentId,
    'studentName': r.studentName,
    'sessionId': r.sessionId,
    'sessionName': r.sessionName,
    'date': r.date.toIso8601String(),
    'status': r.status.name,
    'checkInTime': r.checkInTime?.toIso8601String(),
    'checkOutTime': r.checkOutTime?.toIso8601String(),
    'notes': r.notes,
  };

  AttendanceRecord _mapToRecord(Map<String, dynamic> m) => AttendanceRecord(
    id: m['id'] ?? '',
    studentId: m['studentId'] ?? '',
    studentName: m['studentName'] ?? '',
    sessionId: m['sessionId'],
    sessionName: m['sessionName'],
    date: DateTime.tryParse(m['date'] ?? '') ?? DateTime.now(),
    status: AttendanceStatus.values.firstWhere(
      (e) => e.name == m['status'],
      orElse: () => AttendanceStatus.present,
    ),
    checkInTime: m['checkInTime'] != null
        ? DateTime.tryParse(m['checkInTime'])
        : null,
    checkOutTime: m['checkOutTime'] != null
        ? DateTime.tryParse(m['checkOutTime'])
        : null,
    notes: m['notes'],
  );
}
