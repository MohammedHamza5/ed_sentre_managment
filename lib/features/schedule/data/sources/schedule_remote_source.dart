import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/supabase/supabase_client.dart';
import '../../../../shared/models/models.dart';
import '../../../../shared/data/mappers.dart';
import '../../../../core/supabase/auth_service.dart';

class ScheduleRemoteSource {
  final _uuid = const Uuid();

  Future<String?> _getCenterId() async {
    final savedCenterId = await AuthService.getSavedCenterId();
    if (savedCenterId != null) return savedCenterId;

    final user = SupabaseClientManager.currentUser;
    if (user == null) return null;
    return user.userMetadata?['center_id'] ??
        user.userMetadata?['default_center_id'];
  }

  Future<List<ScheduleSession>> getSessions() async {
    final centerId = await _getCenterId();
    if (centerId == null || centerId.isEmpty) {
      throw Exception('Center ID غير موجود');
    }

    try {
      // 1. Fetch schedules without the broken 'courses' join
      final response = await SupabaseClientManager.client
          .from('schedules')
          .select('''
            *,
            classrooms:classroom_id(name),
            groups:group_id(group_name, deleted_at)
          ''')
          .eq('center_id', centerId)
          .filter('deleted_at', 'is', null)
          .neq('status', 'cancelled');

      // 2. Prepare Sets for manual fetching
      final Set<String> courseIds = {};
      final Set<String> teacherIds = {};

      for (final json in response as List) {
         if (json['course_id'] != null) courseIds.add(json['course_id']);
         if (json['teacher_id'] != null) teacherIds.add(json['teacher_id']);
      }

      // 3. Manual Fetch: Courses
      Map<String, String> courseNamesMap = {};
      if (courseIds.isNotEmpty) {
        try {
          final coursesData = await SupabaseClientManager.client
              .from('courses')
              .select('id, name')
              .filter('id', 'in', courseIds.toList());
          
          for (final c in coursesData as List) {
            courseNamesMap[c['id']] = c['name'] as String;
          }
        } catch (e) {
          debugPrint('⚠️ [ScheduleRemote] Failed to fetch course names: $e');
        }
      }

      // 4. Manual Fetch: Teachers
      Map<String, String> teacherNamesMap = {};
      if (teacherIds.isNotEmpty) {
        try {
          final teachersData = await SupabaseClientManager.client
              .from('teachers')
              .select('id, users(full_name)')
              .filter('id', 'in', teacherIds.toList());
          
          for (final t in teachersData as List) {
            final tId = t['id'] as String;
            final tName = t['users']?['full_name'] as String? ?? '';
            teacherNamesMap[tId] = tName;
          }
        } catch (e) {
          debugPrint('⚠️ [ScheduleRemote] Failed to fetch teacher names: $e');
        }
      }

      // 5. Build Result List — skip schedules for deleted groups
      final List<ScheduleSession> sessions = [];
      for (final json in response) {
        // Skip if the group was soft-deleted
        final groupData = json['groups'];
        if (groupData != null && groupData['deleted_at'] != null) continue;

        // Extract nested data
        final courseId = json['course_id'] as String?;
        final teacherId = json['teacher_id'] as String?;
        
        final courseName = courseNamesMap[courseId] ?? '';
        final teacherName = teacherNamesMap[teacherId] ?? '';
        final classroomName = json['classrooms']?['name'] ?? '';
        final groupName = groupData?['group_name'] ?? '';

        // Create enriched JSON
        final Map<String, dynamic> enrichedJson = {
          ...(json as Map<String, dynamic>),
          'subject_name': courseName,
          'teacher_name': teacherName,
          'room_name': classroomName,
          'group_name': groupName,
        };
        
        sessions.add(ScheduleMapper.fromSupabase(enrichedJson));
      }
      
      return sessions;
    } catch (e) {
      debugPrint('❌ [ScheduleRemote] Error: $e');
      rethrow;
    }
  }

  Future<ScheduleSession> addSession(ScheduleSession session) async {
    final centerId = await _getCenterId();
    if (centerId == null || centerId.isEmpty) {
      throw Exception('Center ID غير موجود');
    }

    try {
      final data = ScheduleMapper.toSupabase(session, centerId: centerId);
      // Let DB generate ID if empty
      if (session.id.isEmpty) {
        data.remove('id');
      }

      final response = await SupabaseClientManager.client
          .from('schedules')
          .insert(data)
          .select('*')
          .single();

      return ScheduleMapper.fromSupabase(response);
    } catch (e) {
      debugPrint('❌ [ScheduleRemote] Add Error: $e');
      rethrow;
    }
  }

  Future<void> updateSession(ScheduleSession session) async {
    final centerId = await _getCenterId();
    if (centerId == null) throw Exception('Center ID not found');

    try {
      final data = ScheduleMapper.toSupabase(session, centerId: centerId);
      await SupabaseClientManager.client
          .from('schedules')
          .update(data)
          .eq('id', session.id);
    } catch (e) {
      debugPrint('❌ [ScheduleRemote] Update Error: $e');
      rethrow;
    }
  }

  Future<void> deleteSession(String id) async {
    try {
      await SupabaseClientManager.client
          .from('schedules')
          .delete()
          .eq('id', id);
    } catch (e) {
      debugPrint('❌ [ScheduleRemote] Delete Error: $e');
      rethrow;
    }
  }

  Future<List<Room>> getRooms() async {
    final centerId = await _getCenterId();
    if (centerId == null) throw Exception('Center ID not found');

    try {
      final response = await SupabaseClientManager.client
          .from('classrooms')
          .select()
          .eq('center_id', centerId)
          .order('name');

      return (response as List).map((json) => Room.fromJson(json)).toList();
    } catch (e) {
      debugPrint('❌ [ScheduleRemote] Get Rooms Error: $e');
      rethrow;
    }
  }

  Future<List<ScheduleSession>> checkScheduleConflict({
    required String teacherId,
    required int dayOfWeek,
    required String startTime,
    required String endTime,
    String? excludeSessionId,
  }) async {
    try {
      final centerId = await _getCenterId();
      if (centerId == null) return [];

      final response = await SupabaseClientManager.client
          .from('schedules')
          .select('*')
          .eq('center_id', centerId)
          .eq('teacher_id', teacherId)
          .eq('day_of_week', dayOfWeek)
          .filter('deleted_at', 'is', null)
          .neq('status', 'cancelled');

      final schedules = (response as List).map((json) {
        return ScheduleMapper.fromSupabase(json);
      }).toList();

      final conflicts = schedules.where((s) {
        if (excludeSessionId != null && s.id == excludeSessionId) return false;

        final sStart = _timeToMinutes(s.startTime);
        final sEnd = _timeToMinutes(s.endTime);
        final cStart = _timeToMinutes(startTime);
        final cEnd = _timeToMinutes(endTime);

        return (sStart < cEnd) && (sEnd > cStart);
      }).toList();

      return conflicts;
    } catch (e) {
      debugPrint('⚠️ [checkScheduleConflict] Error: $e');
      return [];
    }
  }

  int _timeToMinutes(String time) {
    final parts = time.split(':');
    return int.parse(parts[0]) * 60 + int.parse(parts[1]);
  }
}


