import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/supabase/supabase_client.dart';
import '../../../../shared/models/models.dart';
import '../../../../shared/data/mappers.dart';
import '../../../../core/supabase/auth_service.dart';

class AttendanceRemoteSource {
  final _uuid = const Uuid();

  Future<String?> _getCenterId() async {
    final savedCenterId = await AuthService.getSavedCenterId();
    if (savedCenterId != null) return savedCenterId;

    final user = SupabaseClientManager.currentUser;
    if (user == null) return null;
    return user.userMetadata?['center_id'] ??
        user.userMetadata?['default_center_id'];
  }

  Future<List<AttendanceRecord>> getAttendanceByStudent(
    String studentId,
  ) async {
    final centerId = await _getCenterId();
    if (centerId == null) return [];

    try {
      final response = await SupabaseClientManager.client
          .from('attendance')
          .select('''
            *,
            students(full_name)
          ''')
          .eq('student_id', studentId)
          .eq('center_id', centerId)
          .order('date', ascending: false);

      return (response as List)
          .map((json) => AttendanceMapper.fromSupabase(json))
          .toList();
    } catch (e) {
      debugPrint('Error getting student attendance: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>> startAttendanceSession({
    required String groupId,
    int durationMinutes = 60,
  }) async {
    final centerId = await _getCenterId();
    final userId = SupabaseClientManager.currentUser?.id;

    if (centerId == null) throw Exception('Center ID not found');
    if (userId == null) throw Exception('User not logged in');

    try {
      final response = await SupabaseClientManager.client.rpc(
        'start_attendance_session',
        params: {
          'p_group_id': groupId,
          'p_center_id': centerId,
          'p_created_by': userId,
          'p_duration_minutes': durationMinutes,
        },
      );

      if (response is List) {
        if (response.isEmpty) {
          throw Exception('Failed to start session: No data returned');
        }
        return response.first as Map<String, dynamic>;
      }

      return response as Map<String, dynamic>;
    } catch (e) {
      debugPrint('Error starting attendance session: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getAttendanceSessionStatus(
    String sessionId,
  ) async {
    try {
      final response = await SupabaseClientManager.client.rpc(
        'get_attendance_session_status',
        params: {'p_session_id': sessionId},
      );
      return response as Map<String, dynamic>;
    } catch (e) {
      debugPrint('Error getting session status: $e');
      rethrow;
    }
  }

  Future<void> endAttendanceSession(String sessionId) async {
    try {
      await SupabaseClientManager.client.rpc(
        'end_attendance_session',
        params: {'p_session_id': sessionId},
      );
    } catch (e) {
      debugPrint('Error ending session: $e');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getGroupAttendanceSheet(
    String groupId,
    DateTime date,
  ) async {
    try {
      final response = await SupabaseClientManager.client.rpc(
        'get_group_attendance_sheet',
        params: {'p_group_id': groupId, 'p_date': date.toIso8601String()},
      );

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('❌ Error fetching attendance sheet: $e');
      throw Exception('فشل في جلب كشف الحضور');
    }
  }

  Future<List<AttendanceRecord>> getAttendance() async {
    final centerId = await _getCenterId();
    if (centerId == null) throw Exception('Center ID not found');

    try {
      final response = await SupabaseClientManager.client
          .from('attendance')
          .select('''
            *,
            students(name),
            schedules(subject_id, subjects(name))
          ''')
          .eq('center_id', centerId)
          .order('date', ascending: false)
          .limit(500);

      return (response as List).map((json) {
        return AttendanceMapper.fromSupabase(json);
      }).toList();
    } catch (e) {
      debugPrint('❌ [AttendanceRemote] Get Error: $e');
      rethrow;
    }
  }

  Future<List<AttendanceRecord>> getAttendanceByDate(DateTime date) async {
    final centerId = await _getCenterId();
    if (centerId == null || centerId.isEmpty) {
      throw Exception('Center ID غير موجود');
    }

    try {
      final dateStr = date.toIso8601String().split('T')[0];
      final response = await SupabaseClientManager.client
          .from('attendance')
          .select('''
            *,
            students(name),
            schedules(subject_id, subjects(name))
          ''')
          .eq('center_id', centerId)
          .eq('date', dateStr);

      return (response as List).map((json) {
        return AttendanceMapper.fromSupabase(json);
      }).toList();
    } catch (e) {
      debugPrint('❌ [AttendanceRemote] Error: $e');
      rethrow;
    }
  }

  Future<List<AttendanceRecord>> getAttendanceRange(
    DateTime start,
    DateTime end,
  ) async {
    final centerId = await _getCenterId();
    if (centerId == null || centerId.isEmpty) {
      throw Exception('Center ID غير موجود');
    }

    try {
      final startStr = start.toIso8601String().split('T')[0];
      final endStr = end.toIso8601String().split('T')[0];

      final response = await SupabaseClientManager.client
          .from('attendance')
          .select('''
            *,
            students(name),
            schedules(subject_id, subjects(name))
          ''')
          .eq('center_id', centerId)
          .gte('date', startStr)
          .lte('date', endStr);

      return (response as List).map((json) {
        return AttendanceMapper.fromSupabase(json);
      }).toList();
    } catch (e) {
      debugPrint('❌ [AttendanceRemote] Range Error: $e');
      rethrow;
    }
  }

  Future<void> addAttendance(AttendanceRecord record) async {
    await addBulkAttendance([record]);
  }

  Future<void> addBulkAttendance(List<AttendanceRecord> records) async {
    debugPrint(
      '═══════════════════════════════════════════════════════════════',
    );
    debugPrint('📡 [AttendanceRemote] addBulkAttendance STARTED');
    debugPrint('   📊 Records count: ${records.length}');
    debugPrint(
      '═══════════════════════════════════════════════════════════════',
    );

    final centerId = await _getCenterId();
    debugPrint('   🏢 Center ID: $centerId');

    if (centerId == null || centerId.isEmpty) {
      debugPrint('❌ [AttendanceRemote] Center ID is null or empty!');
      throw Exception('Center ID غير موجود');
    }

    try {
      final data = records
          .map((r) => AttendanceMapper.toSupabase(r, centerId: centerId))
          .toList();

      debugPrint('   📋 Data to upsert:');
      for (int i = 0; i < data.length; i++) {
        debugPrint(
          '      [$i] student_id=${data[i]['student_id']}, schedule_id=${data[i]['schedule_id']}, status=${data[i]['status']}',
        );
      }

      debugPrint('📡 [AttendanceRemote] Calling Supabase upsert...');
      // Upsert to handle existing records for same student/session/date
      await SupabaseClientManager.client
          .from('attendance')
          .upsert(data, onConflict: 'student_id, schedule_id, date');

      debugPrint(
        '✅ [AttendanceRemote] addBulkAttendance COMPLETED successfully',
      );
      debugPrint(
        '═══════════════════════════════════════════════════════════════',
      );
    } catch (e, stack) {
      debugPrint('❌ [AttendanceRemote] Bulk Add Error: $e');
      debugPrint('   Stack: $stack');
      rethrow;
    }
  }

  Future<void> updateAttendance(AttendanceRecord record) async {
    final centerId = await _getCenterId();
    if (centerId == null) throw Exception('Center ID not found');

    try {
      final data = AttendanceMapper.toSupabase(record, centerId: centerId);
      await SupabaseClientManager.client
          .from('attendance')
          .update(data)
          .eq('id', record.id);
    } catch (e) {
      debugPrint('❌ [AttendanceRemote] Update Error: $e');
      rethrow;
    }
  }

  Future<void> deleteAttendance(String id) async {
    try {
      await SupabaseClientManager.client
          .from('attendance')
          .delete()
          .eq('id', id);
    } catch (e) {
      debugPrint('❌ [AttendanceRemote] Delete Error: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getAttendanceStats({DateTime? date}) async {
    final centerId = await _getCenterId();
    if (centerId == null) return {};

    try {
      var query = SupabaseClientManager.client
          .from('attendance')
          .select('status')
          .eq('center_id', centerId);

      if (date != null) {
        query = query.eq('date', date.toIso8601String().split('T')[0]);
      }

      final response = await query;
      final total = (response as List).length;
      final present = response.where((r) => r['status'] == 'present').length;

      return {
        'total': total,
        'present': present,
        'rate': total > 0 ? (present / total * 100) : 0.0,
      };
    } catch (e) {
      return {};
    }
  }

  Future<Map<String, dynamic>> createSmartSession({
    required String groupId,
    required DateTime opensAt,
    DateTime? closesAt,
    DateTime? onTimeUntil,
  }) async {
    try {
      final response = await SupabaseClientManager.client
          .from('attendance_sessions')
          .insert({
            'group_id': groupId,
            'opens_at': opensAt.toIso8601String(),
            'closes_at': closesAt?.toIso8601String(),
            'on_time_until': onTimeUntil?.toIso8601String(),
            'status': 'scheduled',
            'created_at': DateTime.now().toIso8601String(),
          })
          .select()
          .single();
      return response;
    } catch (e) {
      debugPrint('Error creating smart session: $e');
      rethrow;
    }
  }

  Future<String> generateSessionQr(String sessionId) async {
    try {
      final response = await SupabaseClientManager.client.rpc(
        'generate_session_qr',
        params: {'p_session_id': sessionId},
      );
      return response as String;
    } catch (e) {
      debugPrint('Error generating session QR: $e');
      rethrow;
    }
  }

  Future<String> generateUniversalQr() async {
    try {
      final response = await SupabaseClientManager.client.rpc(
        'generate_universal_qr',
      );
      return response as String;
    } catch (e) {
      debugPrint('Error generating universal QR: $e');
      rethrow;
    }
  }

  Future<String?> fetchUniversalQrKey() async {
    final centerId = await _getCenterId();
    if (centerId == null) return null;

    try {
      final response = await SupabaseClientManager.client
          .from('center_settings')
          .select('universal_qr_key')
          .eq('center_id', centerId)
          .maybeSingle();

      return response?['universal_qr_key'] as String?;
    } catch (e) {
      debugPrint('⚠️ Not allowed to read key directly or table empty: $e');
      return null;
    }
  }
}
