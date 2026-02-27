import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/supabase/supabase_client.dart';
import '../../../../shared/data/mappers.dart';
import '../../../../shared/models/models.dart';
import '../../../../core/supabase/auth_service.dart';

class SubjectsRemoteSource {
  final _uuid = const Uuid();

  Future<String?> _getCenterId() async {
    final savedCenterId = await AuthService.getSavedCenterId();
    if (savedCenterId != null) return savedCenterId;

    final user = SupabaseClientManager.currentUser;
    if (user == null) return null;
    return user.userMetadata?['center_id'] ??
        user.userMetadata?['default_center_id'];
  }

  Future<List<Subject>> getSubjects() async {
    final centerId = await _getCenterId();
    if (centerId == null || centerId.isEmpty) {
      throw Exception('Center ID غير موجود');
    }

    try {
      debugPrint(
        '📥 [getSubjects] Fetching from courses for center: $centerId',
      );

      // جلب المواد مع عدد الطلاب الفعلي من student_courses
      final response = await SupabaseClientManager.client
          .from('courses')
          .select('''
            *,
            teacher_courses(teacher_id),
            student_courses(id, status)
          ''')
          .eq('center_id', centerId);

      debugPrint('📥 [getSubjects] Data Loaded: ${(response as List).length}');

      return (response as List).map((json) {
        final data = json as Map<String, dynamic>;
        // حساب عدد الطلاب من student_courses المرتبطة (فقط active)
        final studentCourses = data['student_courses'] as List? ?? [];
        final activeStudents = studentCourses.where((sc) => 
            sc['status'] == 'active' || sc['status'] == null
        ).length;
        data['student_count'] = activeStudents;
        
        debugPrint('   📚 ${data['name']}: student_courses=${studentCourses.length}, active=$activeStudents');
        
        return SubjectMapper.fromSupabase(data);
      }).toList();
    } catch (e) {
      debugPrint('❌ [getSubjects] Error: $e');
      rethrow;
    }
  }

  Future<Subject> getSubject(String id) async {
    try {
      final response = await SupabaseClientManager.client
          .from('courses')
          .select('*, teacher_courses(teacher_id)')
          .eq('id', id)
          .single();

      return SubjectMapper.fromSupabase(response);
    } catch (e) {
      throw Exception('فشل في جلب المادة: $e');
    }
  }

  Future<Subject> addSubject(Subject subject) async {
    final centerId = await _getCenterId();
    if (centerId == null || centerId.isEmpty) {
      throw Exception('Center ID غير موجود');
    }

    try {
      final subjectData = SubjectMapper.toSupabase(subject, centerId: centerId);
      // Remove id if it's empty so DB generates it
      if ((subjectData['id'] as String).isEmpty) {
        subjectData.remove('id');
      }

      final response = await SupabaseClientManager.client
          .from('courses')
          .insert(subjectData)
          .select('*, teacher_courses(teacher_id)')
          .single();

      final newSubject = SubjectMapper.fromSupabase(response);

      // Add teacher associations if needed (though map might not have them immediately if separate insert)
      // Actually, if we insert course first, then teacher_courses, the first select might not have teacher_courses yet.
      // So we need to insert teacher_courses then return the full object.

      final newSubjectId = newSubject.id;

      if (subject.teacherIds.isNotEmpty) {
        final teacherCourses = subject.teacherIds
            .map(
              (teacherId) => {
                'course_id': newSubjectId,
                'teacher_id': teacherId,
                'center_id': centerId,
              },
            )
            .toList();

        await SupabaseClientManager.client
            .from('teacher_courses')
            .insert(teacherCourses);
      }

      // Return the subject with the new ID and teachers
      return newSubject.copyWith(teacherIds: subject.teacherIds);
    } catch (e) {
      debugPrint('❌ [addSubject] Error: $e');
      rethrow;
    }
  }

  Future<void> updateSubject(Subject subject) async {
    final centerId = await _getCenterId();
    if (centerId == null || centerId.isEmpty) {
      throw Exception('Center ID غير موجود');
    }

    try {
      final subjectData = SubjectMapper.toSupabase(subject, centerId: centerId);

      await SupabaseClientManager.client
          .from('courses')
          .update(subjectData)
          .eq('id', subject.id);

      // Update teacher associations
      // First delete existing, then add new (simplest approach)
      // Ideally should diff, but for now this works
      await SupabaseClientManager.client
          .from('teacher_courses')
          .delete()
          .eq('course_id', subject.id);

      if (subject.teacherIds.isNotEmpty) {
        final teacherCourses = subject.teacherIds
            .map(
              (teacherId) => {
                'course_id': subject.id,
                'teacher_id': teacherId,
                'center_id': centerId,
              },
            )
            .toList();

        await SupabaseClientManager.client
            .from('teacher_courses')
            .insert(teacherCourses);
      }
    } catch (e) {
      debugPrint('❌ [updateSubject] Error: $e');
      rethrow;
    }
  }

  Future<void> deleteSubject(String id) async {
    try {
      // Cascade delete should handle teacher_courses, but to be safe/explicit:
      // Assuming DB has cascade on delete.
      await SupabaseClientManager.client.from('courses').delete().eq('id', id);
    } catch (e) {
      debugPrint('❌ [deleteSubject] Error: $e');
      rethrow;
    }
  }
}


