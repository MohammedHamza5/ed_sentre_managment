import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/supabase/supabase_client.dart';
import '../../../../shared/data/mappers.dart';
import '../../../../shared/models/models.dart';
import '../../../../core/supabase/auth_service.dart';

class TeachersRemoteSource {
  final _uuid = const Uuid();

  Future<String?> _getCenterId() async {
    final savedCenterId = await AuthService.getSavedCenterId();
    if (savedCenterId != null) return savedCenterId;

    final user = SupabaseClientManager.currentUser;
    if (user == null) return null;
    // Try to get from metadata or query if needed (similar to SupabaseRepository)
    // For simplicity, relying on metadata as per recent pattern
    return user.userMetadata?['center_id'] ??
        user.userMetadata?['default_center_id'];
  }

  Future<List<Teacher>> getTeachers() async {
    final centerId = await _getCenterId();
    if (centerId == null || centerId.isEmpty) {
      throw Exception('Center ID غير موجود');
    }

    try {
      debugPrint(
        '📥 [getTeachers] Fetching from teacher_enrollments for center: $centerId',
      );

      final response = await SupabaseClientManager.client
          .from('teacher_enrollments')
          .select('''
            *,
            teachers!teacher_enrollments_teacher_id_fkey!inner (
              *,
              users!inner (full_name, avatar_url, phone, email),
              teacher_courses (
                course_id
              )
            )
          ''')
          .eq('center_id', centerId)
          .filter('deleted_at', 'is', null)
          .neq('employment_status', 'terminated');

      debugPrint('📥 [getTeachers] Data Loaded: ${(response as List).length}');

      final teachers = <Teacher>[];
      for (final json in (response as List)) {
        final teacher = TeacherMapper.fromSupabase(
          json as Map<String, dynamic>,
        );

        // Calculate counts dynamically
        final teacherNode = json['teachers'] as Map<String, dynamic>?;
        final teacherCourses =
            (teacherNode?['teacher_courses'] as List?) ?? const [];
        int courseCount = teacherCourses.length;
        int studentCount = 0;

        if (teacher.id.isNotEmpty) {
          try {
            // 1. Get all groups for this teacher
            final groupsResponse = await SupabaseClientManager.client
                .from('groups')
                .select('id')
                .eq('teacher_id', teacher.id)
                .eq(
                  'status',
                  'active',
                ); // Only count active groups? Or all? Usually active.

            final groupIds = (groupsResponse as List)
                .map((g) => g['id'].toString())
                .toList();

            if (groupIds.isNotEmpty) {
              // 2. Get active enrollments for these groups
              final enrollmentsResponse = await SupabaseClientManager.client
                  .from('student_group_enrollments')
                  .select('student_id')
                  .inFilter('group_id', groupIds)
                  .eq('status', 'active'); // Only active students

              final uniqueStudentIds = (enrollmentsResponse as List)
                  .map((e) => e['student_id'].toString())
                  .toSet();

              studentCount = uniqueStudentIds.length;
            }
          } catch (e) {
            debugPrint(
              '⚠️ Error calculating student count for teacher ${teacher.name}: $e',
            );
          }
        }

        teachers.add(
          teacher.copyWith(
            courseCount: courseCount,
            studentCount: studentCount,
          ),
        );
      }

      return teachers;
    } catch (e) {
      debugPrint('❌ [getTeachers] Error: $e');
      rethrow;
    }
  }

  Future<Teacher> getTeacher(String id) async {
    try {
      final response = await SupabaseClientManager.client
          .from('teachers')
          .select('*')
          .eq('id', id)
          .filter('deleted_at', 'is', null)
          .single();

      return TeacherMapper.fromSupabase(response);
    } catch (e) {
      throw Exception('فشل في جلب المعلم: $e');
    }
  }

  Future<Map<String, dynamic>> addTeacher(Teacher teacher) async {
    try {
      final centerId = await _getCenterId();
      if (centerId == null || centerId.isEmpty) {
        throw Exception('Center ID is not available');
      }

      // Check Phone
      final existingUserResponse = await SupabaseClientManager.client
          .from('users')
          .select('id, full_name, is_active')
          .eq('phone', teacher.phone)
          .maybeSingle();

      if (existingUserResponse != null) {
        throw Exception(
          'رقم الهاتف هذا مستخدم بالفعل من قبل المعلم: "${existingUserResponse['full_name']}"',
        );
      }

      final newUserId = _uuid.v4();
      final teacherId = teacher.id.isEmpty ? _uuid.v4() : teacher.id;

      // 1. Create User
      await SupabaseClientManager.client.from('users').insert({
        'id': newUserId,
        'full_name': teacher.name,
        'phone': teacher.phone,
        'email': teacher.email,
        'role': 'teacher',
        'default_center_id': centerId,
        'is_active': teacher.isActive,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });

      // 2. Create Teacher
      await SupabaseClientManager.client.from('teachers').insert({
        'id': teacherId,
        'user_id': newUserId,
        'experience_years': 0,
        'specializations': teacher.subjectIds,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });

      // 3. Create Enrollment
      final enrollmentResult = await SupabaseClientManager.client
          .from('teacher_enrollments')
          .insert({
            'teacher_id': teacherId,
            'teacher_user_id': newUserId,
            'center_id': centerId,
            'employment_status': teacher.isActive ? 'active' : 'suspended',
            'hired_at': DateTime.now().toIso8601String(),
            'salary_type': teacher.salaryType.name,
            'salary_amount': teacher.salaryAmount,
          })
          .select('id, invitation_code')
          .single();

      final invitationCode = enrollmentResult['invitation_code'] as String?;

      // 4. Link Courses
      if (teacher.subjectIds.isNotEmpty) {
        for (final courseId in teacher.subjectIds) {
          try {
            await SupabaseClientManager.client.from('teacher_courses').insert({
              'teacher_id': teacherId,
              'course_id': courseId,
              'center_id': centerId,
              'created_at': DateTime.now().toIso8601String(),
            });
          } catch (e) {
            debugPrint('⚠️ [addTeacher] Could not link course $courseId: $e');
          }
        }
      }

      return {
        'teacher_code': invitationCode,
        'teacher_id': teacherId,
        'teacher_name': teacher.name,
        'phone': teacher.phone,
      };
    } catch (e) {
      throw Exception('فشل في إضافة المعلم: $e');
    }
  }

  Future<Map<String, dynamic>> createTeacherInvitation({
    required String teacherName,
    String? phone,
    String? specialization,
  }) async {
    final centerId = await _getCenterId();
    if (centerId == null) throw Exception('Center ID required');

    final response = await SupabaseClientManager.client.rpc(
      'create_teacher_invitation',
      params: {
        'p_center_id': centerId,
        'p_name': teacherName,
        'p_phone': phone,
        'p_specialization': specialization,
      },
    );

    if (response['success'] == true) {
      return response as Map<String, dynamic>;
    } else {
      throw Exception(response['error'] ?? 'Failed to create invitation');
    }
  }

  Future<List<Map<String, dynamic>>> getTeacherInvitations() async {
    final centerId = await _getCenterId();
    if (centerId == null) throw Exception('Center ID required');

    final response = await SupabaseClientManager.client
        .from('teacher_invitations')
        .select()
        .eq('center_id', centerId)
        .order('created_at', ascending: false);

    return List<Map<String, dynamic>>.from(response);
  }

  Future<List<Map<String, dynamic>>> getTeacherTiers(
    String centerId,
    String teacherId,
  ) async {
    final response = await SupabaseClientManager.client
        .from('teacher_tiers')
        .select()
        .eq('center_id', centerId)
        .eq('teacher_id', teacherId)
        .order('min_revenue', ascending: true);

    return List<Map<String, dynamic>>.from(response);
  }

  Future<void> addTeacherTier({
    required String centerId,
    required String teacherId,
    required double minRevenue,
    required double maxRevenue,
    required double percentage,
  }) async {
    await SupabaseClientManager.client.from('teacher_tiers').insert({
      'center_id': centerId,
      'teacher_id': teacherId,
      'min_revenue': minRevenue,
      'max_revenue': maxRevenue,
      'percentage': percentage,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<void> deleteTeacherTier(String id) async {
    await SupabaseClientManager.client
        .from('teacher_tiers')
        .delete()
        .eq('id', id);
  }

  Future<List<Map<String, dynamic>>> getTeacherSalaryHistory(
    String teacherId,
  ) async {
    final response = await SupabaseClientManager.client
        .from('teacher_salaries')
        .select()
        .eq('teacher_id', teacherId)
        .order('month_year', ascending: false);

    return List<Map<String, dynamic>>.from(response);
  }

  Future<Map<String, dynamic>> getTeacherSalary({
    required String teacherId,
    required int month,
    required int year,
  }) async {
    final centerId = await _getCenterId();
    if (centerId == null) throw Exception('Center ID not found');

    try {
      final data = await SupabaseClientManager.client.rpc(
        'get_teacher_salary_detailed',
        params: {
          'p_teacher_id': teacherId,
          'p_center_id': centerId,
          'p_month': month,
          'p_year': year,
        },
      );

      final result = Map<String, dynamic>.from(data as Map);

      // Extract values from the detailed response
      final summary = result['summary'] as Map<String, dynamic>? ?? {};
      final teacher = result['teacher'] as Map<String, dynamic>? ?? {};

      // Ensure backward compatibility with old UI
      result['teacher_name'] ??= teacher['name'] ?? 'معلم';
      result['salary_type'] ??= teacher['salary_type'] ?? 'fixed';
      result['base_salary'] ??= (teacher['salary_type'] == 'fixed')
          ? (teacher['salary_amount'] ?? 0.0)
          : 0.0;
      result['sessions_total'] ??= 0.0;
      result['percentage_total'] ??= (teacher['salary_type'] == 'percentage')
          ? (summary['teacher_share'] ?? 0.0)
          : 0.0;
      result['gross_salary'] ??= summary['teacher_share'] ?? 0.0;
      result['net_salary'] ??= summary['teacher_share'] ?? 0.0;

      // Groups as sessions for backward compatibility
      result['sessions'] ??= [];
      result['groups'] ??= [];
      result['by_grade'] ??= [];
      result['bonuses'] ??= [];
      result['deductions'] ??= [];
      result['comparison'] ??= {};
      result['insights'] ??= [];

      return result;
    } catch (e) {
      debugPrint('❌ [getTeacherSalary] Error: $e');
      rethrow;
    }
  }

  Future<void> updateTeacher(Teacher teacher) async {
    try {
      final centerId = await _getCenterId();

      final teacherRecord = await SupabaseClientManager.client
          .from('teachers')
          .select('user_id')
          .eq('id', teacher.id)
          .maybeSingle();

      final userId = teacherRecord?['user_id'] as String?;
      if (userId == null) throw Exception('Teacher not found');

      // Update User
      await SupabaseClientManager.client
          .from('users')
          .update({
            'full_name': teacher.name,
            'phone': teacher.phone,
            'email': teacher.email,
            'is_active': teacher.isActive,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', userId);

      // Update Enrollment
      if (centerId != null) {
        await SupabaseClientManager.client
            .from('teacher_enrollments')
            .update({
              'employment_status': teacher.isActive ? 'active' : 'suspended',
              'salary_type': teacher.salaryType.name,
              'salary_amount': teacher.salaryAmount,
            })
            .eq('teacher_user_id', userId)
            .eq('center_id', centerId);

        // Update Courses
        await SupabaseClientManager.client
            .from('teacher_courses')
            .delete()
            .eq('teacher_id', teacher.id)
            .eq('center_id', centerId);

        if (teacher.subjectIds.isNotEmpty) {
          for (final courseId in teacher.subjectIds) {
            try {
              await SupabaseClientManager.client
                  .from('teacher_courses')
                  .insert({
                    'teacher_id': teacher.id,
                    'course_id': courseId,
                    'center_id': centerId,
                    'created_at': DateTime.now().toIso8601String(),
                  });
            } catch (_) {}
          }
        }
      }
    } catch (e) {
      throw Exception('فشل في تحديث المعلم: $e');
    }
  }

  Future<void> deleteTeacher(String id, {bool softDelete = true}) async {
    final centerId = await _getCenterId();
    if (centerId != null) {
      final now = DateTime.now().toIso8601String();
      await SupabaseClientManager.client
          .from('teacher_enrollments')
          .update({
            'employment_status': 'terminated',
            'status': 'inactive',
            'deleted_at': now,
            'updated_at': now,
          })
          .eq('teacher_id', id)
          .eq('center_id', centerId);
    }
  }

  Future<void> deactivateTeacher(String id) async {
    final centerId = await _getCenterId();
    debugPrint(
      '🛠️ [RemoteSource] Deactivating teacher: $id at center: $centerId',
    );
    if (centerId != null) {
      await SupabaseClientManager.client
          .from('teacher_enrollments')
          .update({'employment_status': 'suspended'})
          .eq('teacher_id', id)
          .eq('center_id', centerId);
      debugPrint(
        '✅ [RemoteSource] Teacher Deactivated (Status set to suspended)',
      );
    }
  }

  Future<void> reactivateTeacher(String id) async {
    final centerId = await _getCenterId();
    debugPrint(
      '🛠️ [RemoteSource] Reactivating teacher: $id at center: $centerId',
    );
    if (centerId != null) {
      await SupabaseClientManager.client
          .from('teacher_enrollments')
          .update({'employment_status': 'active'})
          .eq('teacher_id', id)
          .eq('center_id', centerId);
      debugPrint('✅ [RemoteSource] Teacher Reactivated (Status set to active)');
    }
  }

  Future<void> reassignTeacherGroups(String oldId, String newId) async {
    final centerId = await _getCenterId();
    if (centerId == null) return;

    // Update sessions/groups where teacher_id = oldId to newId
    // This depends on schema. Assuming 'sessions' table has teacher_id
    // Update schedules where teacher_id = oldId to newId
    await SupabaseClientManager.client
        .from('schedules')
        .update({'teacher_id': newId})
        .eq('teacher_id', oldId)
        .eq('center_id', centerId);

    // Update groups where teacher_id = oldId to newId
    await SupabaseClientManager.client
        .from('groups')
        .update({'teacher_id': newId})
        .eq('teacher_id', oldId)
        .eq('center_id', centerId);
  }

  Future<Map<String, int>> getTeacherDependencies(String id) async {
    final centerId = await _getCenterId();
    if (centerId == null) return {'groups': 0, 'sessions': 0};

    final sessionsCount = await SupabaseClientManager.client
        .from('schedules')
        .select('id')
        .eq('teacher_id', id)
        .eq('center_id', centerId)
        .count(CountOption.exact);

    final groupsCount = await SupabaseClientManager.client
        .from('groups')
        .select('id')
        .eq('teacher_id', id)
        .eq('center_id', centerId)
        .count(CountOption.exact);

    return {'groups': groupsCount.count, 'sessions': sessionsCount.count};
  }

  // Subjects helper needed for TeachersBloc
  Future<List<Subject>> getSubjects() async {
    final centerId = await _getCenterId();
    if (centerId == null) return [];

    final response = await SupabaseClientManager.client
        .from('courses')
        .select('*, teacher_courses(teacher_id)')
        .eq('center_id', centerId)
        .order('created_at', ascending: false);

    final subjects = <Subject>[];
    for (final data in (response as List)) {
      final subject = SubjectMapper.fromSupabase(data as Map<String, dynamic>);
      subjects.add(subject);
    }
    return subjects;
  }

  Future<void> saveTeacherSalary({
    required String teacherId,
    required int month,
    required int year,
    required Map<String, dynamic> salaryData,
  }) async {
    final centerId = await _getCenterId();
    if (centerId == null) throw Exception('Center ID not found');

    await SupabaseClientManager.client.from('teacher_salaries').upsert({
      'teacher_id': teacherId,
      'center_id': centerId,
      'month': month,
      'year': year,
      ...salaryData,
      'updated_at': DateTime.now().toIso8601String(),
    }, onConflict: 'teacher_id, center_id, month, year');
  }

  Future<List<Map<String, dynamic>>> findSimilarTeachers(String name) async {
    final centerId = await _getCenterId();
    if (centerId == null) return [];

    try {
      final response = await SupabaseClientManager.client
          .from('users')
          .select('full_name, phone')
          .ilike('full_name', '%$name%')
          .eq('role', 'teacher')
          .eq('default_center_id', centerId)
          .limit(5);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('❌ [findSimilarTeachers] Error: $e');
      return [];
    }
  }

  Future<String?> getTeacherInvitationCode(String teacherId) async {
    final centerId = await _getCenterId();
    if (centerId == null) return null;
    try {
      final response = await SupabaseClientManager.client
          .from('teacher_enrollments')
          .select('invitation_code')
          .eq('teacher_id', teacherId)
          .eq('center_id', centerId)
          .maybeSingle();
      return response?['invitation_code'] as String?;
    } catch (e) {
      return null;
    }
  }

  /// جلب إحصائيات المعلمين الشاملة (مُحسّنة)
  /// يتضمن: المحصل الفعلي، نصيب المعلم، نصيب المركز
  Future<Map<String, dynamic>> getTeacherStatistics({
    String? teacherId,
    int? month,
    int? year,
  }) async {
    final centerId = await _getCenterId();
    if (centerId == null) return {};

    try {
      debugPrint('📊 [TeacherStats] Fetching statistics...');

      final data = await SupabaseClientManager.client.rpc(
        'get_teacher_statistics',
        params: {
          'p_center_id': centerId,
          'p_teacher_id': teacherId,
          'p_month': month,
          'p_year': year,
        },
      );

      final result = Map<String, dynamic>.from(data as Map);
      debugPrint('📊 [TeacherStats] Teachers: ${result['teachers_count']}');
      return result;
    } catch (e) {
      debugPrint('❌ [TeacherStats] Error: $e');
      return {};
    }
  }

  /// لوحة المالية الشاملة للمركز
  Future<Map<String, dynamic>> getFinancialDashboard({
    int? month,
    int? year,
  }) async {
    final centerId = await _getCenterId();
    if (centerId == null) return {};

    try {
      debugPrint('💰 [FinancialDashboard] Fetching data...');

      final data = await SupabaseClientManager.client.rpc(
        'get_center_financial_dashboard',
        params: {'p_center_id': centerId, 'p_month': month, 'p_year': year},
      );

      final result = Map<String, dynamic>.from(data as Map);
      debugPrint(
        '💰 [FinancialDashboard] Net Profit: ${result['center']?['net_profit']}',
      );
      return result;
    } catch (e) {
      debugPrint('❌ [FinancialDashboard] Error: $e');
      return {};
    }
  }
}
