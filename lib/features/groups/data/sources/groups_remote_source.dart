import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/supabase/supabase_client.dart';
import '../../../../core/services/notification_helper.dart';
import '../../../../shared/models/models.dart';
import '../../../../core/supabase/auth_service.dart';
import '../../models/smart_enrollment_models.dart';

class GroupsRemoteSource {
  final _uuid = const Uuid();

  Future<String?> _getCenterId() async {
    final savedCenterId = await AuthService.getSavedCenterId();
    if (savedCenterId != null) return savedCenterId;

    final user = SupabaseClientManager.currentUser;
    if (user == null) return null;
    return user.userMetadata?['center_id'] ??
        user.userMetadata?['default_center_id'];
  }

  /// Get teacher's user_id from a group (for notifications)
  Future<String?> _getTeacherUserIdFromGroup(String groupId) async {
    try {
      final groupRes = await SupabaseClientManager.client
          .from('groups')
          .select('teachers!inner(user_id)')
          .eq('id', groupId)
          .maybeSingle();
      return (groupRes?['teachers'] as Map<String, dynamic>?)?['user_id'] as String?;
    } catch (_) {
      return null;
    }
  }

  Future<List<Group>> getGroups({
    String? courseId,
    String? teacherId,
    GroupStatus? status,
    String? gradeLevel,
  }) async {
    final centerId = await _getCenterId();
    if (centerId == null || centerId.isEmpty) {
      throw Exception('Center ID غير موجود');
    }

    try {
      var query = SupabaseClientManager.client
          .from('groups')
          .select('''
            *,
            courses(name),
            teachers(
              users(full_name)
            )
          ''')
          .eq('center_id', centerId)
          .filter('deleted_at', 'is', null);

      if (courseId != null) query = query.eq('course_id', courseId);
      if (teacherId != null) query = query.eq('teacher_id', teacherId);
      if (status != null) query = query.eq('status', status.name);
      if (gradeLevel != null) query = query.eq('grade_level', gradeLevel);

      final response = await query.order('created_at', ascending: false);

      return (response as List).map((data) {
        String? teacherName;
        try {
          final teacherData = data['teachers'] as Map<String, dynamic>?;
          final userData = teacherData?['users'] as Map<String, dynamic>?;
          teacherName = userData?['full_name'] as String?;
        } catch (_) {}

        return Group.fromJson({
          ...data,
          'course_name': data['courses']?['name'],
          'teacher_name': teacherName,
        });
      }).toList();
    } catch (e) {
      debugPrint('❌ [GroupsRemote] Error: $e');
      rethrow;
    }
  }

  Future<Group> getGroup(String id) async {
    try {
      final response = await SupabaseClientManager.client
          .from('groups')
          .select('''
            *,
            courses(name),
            teachers(
              users(full_name)
            )
          ''')
          .eq('id', id)
          .single();

      String? teacherName;
      try {
        final teacherData = response['teachers'] as Map<String, dynamic>?;
        final userData = teacherData?['users'] as Map<String, dynamic>?;
        teacherName = userData?['full_name'] as String?;
      } catch (_) {}

      // Fetch sessions from schedules table
      final schedulesResponse = await SupabaseClientManager.client
          .from('schedules')
          .select('''
            *,
            classrooms(name)
          ''')
          .eq('group_id', id)
          .order('day_of_week');

      final List<ScheduleSession> sessions = [];
      for (final sched in schedulesResponse as List) {
        sessions.add(
          ScheduleSession(
            id: sched['id']?.toString() ?? '',
            subjectId: sched['course_id']?.toString() ?? '',
            subjectName: response['courses']?['name'] ?? '',
            teacherId: sched['teacher_id']?.toString() ?? '',
            teacherName: teacherName ?? '',
            roomId: sched['classroom_id']?.toString() ?? '',
            roomName: sched['classrooms']?['name'] ?? '',
            dayOfWeek: _dayFromString(sched['day_of_week']),
            startTime: sched['start_time']?.toString() ?? '',
            endTime: sched['end_time']?.toString() ?? '',
            status: SessionStatus.scheduled,
            groupName: response['group_name'],
          ),
        );
      }

      return Group.fromJson({
        ...response,
        'course_name': response['courses']?['name'],
        'teacher_name': teacherName,
      }).copyWith(sessions: sessions);
    } catch (e) {
      debugPrint('❌ [GroupsRemote] Error: $e');
      rethrow;
    }
  }

  int _dayFromString(dynamic day) {
    if (day is int) return day;
    if (day == null) return 0;
    switch (day.toString().toLowerCase()) {
      case 'saturday':
        return 0;
      case 'sunday':
        return 1;
      case 'monday':
        return 2;
      case 'tuesday':
        return 3;
      case 'wednesday':
        return 4;
      case 'thursday':
        return 5;
      case 'friday':
        return 6;
      default:
        return 0;
    }
  }

  Future<Group> addGroup(Group group) async {
    final centerId = await _getCenterId();
    if (centerId == null || centerId.isEmpty) {
      throw Exception('Center ID غير موجود');
    }

    String? newGroupId;

    try {
      final data = group.toJson();
      data.remove('id'); // Let DB generate ID if UUID is standard
      if (group.id.isEmpty) {
        data.remove('id');
      }
      data['center_id'] = centerId;
      data.remove('course_name');
      data.remove('teacher_name');
      data.remove('scheduled_sessions');
      data.remove('sessions');

      // 1. Insert the group first
      final response = await SupabaseClientManager.client
          .from('groups')
          .insert(data)
          .select('*')
          .single();

      newGroupId = response['id'] as String;
      debugPrint('✅ [GroupsRemote] Group created with ID: $newGroupId');

      // 2. Save sessions to schedules table if any
      if (group.sessions.isNotEmpty) {
        debugPrint(
          '📅 [GroupsRemote] Saving ${group.sessions.length} sessions to schedules...',
        );

        String dayToStr(int day) {
          switch (day) {
            case 0:
              return 'saturday';
            case 1:
              return 'sunday';
            case 2:
              return 'monday';
            case 3:
              return 'tuesday';
            case 4:
              return 'wednesday';
            case 5:
              return 'thursday';
            case 6:
              return 'friday';
            default:
              return 'saturday';
          }
        }

        try {
          for (final session in group.sessions) {
            final sessionData = {
              'course_id': group.courseId,
              'teacher_id': group.teacherId,
              'classroom_id': session.roomId.isNotEmpty ? session.roomId : null,
              'day_of_week': dayToStr(session.dayOfWeek),
              'start_time': session.startTime,
              'end_time': session.endTime,
              'center_id': centerId,
              'grade_level': group.gradeLevel,
              'group_id': newGroupId,
              'status': 'scheduled',
            };

            await SupabaseClientManager.client
                .from('schedules')
                .insert(sessionData);
          }

          debugPrint(
            '✅ [GroupsRemote] ${group.sessions.length} sessions saved to schedules',
          );
        } catch (sessionError) {
          // ⚠️ ROLLBACK: Delete the group if session creation fails
          debugPrint(
            '❌ [GroupsRemote] Session creation failed, rolling back group...',
          );
          try {
            await SupabaseClientManager.client
                .from('groups')
                .delete()
                .eq('id', newGroupId);
            debugPrint('🔄 [GroupsRemote] Group rolled back successfully');
          } catch (rollbackError) {
            debugPrint('⚠️ [GroupsRemote] Rollback failed: $rollbackError');
          }
          rethrow; // Re-throw the original session error
        }
      }

      String? teacherName;
      try {
        // Fetch teacher name separately if needed
        if (group.teacherId != null && group.teacherId!.isNotEmpty) {
          final teacherData = await SupabaseClientManager.client
              .from('teachers')
              .select('users(full_name)')
              .eq('id', group.teacherId!)
              .maybeSingle();
          teacherName = teacherData?['users']?['full_name'] as String?;
        }
      } catch (_) {}

      // Fetch course name
      String? courseName;
      try {
        final courseData = await SupabaseClientManager.client
            .from('courses')
            .select('name')
            .eq('id', group.courseId)
            .maybeSingle();
        courseName = courseData?['name'] as String?;
      } catch (_) {}

      return Group.fromJson({
        ...response,
        'course_name': courseName,
        'teacher_name': teacherName,
      });
    } catch (e) {
      debugPrint('❌ [GroupsRemote] Error: $e');
      if (e.toString().contains('23505')) {
        throw Exception('اسم المجموعة مستخدم بالفعل لهذه المادة');
      }
      rethrow;
    }
  }

  Future<void> updateGroup(Group group) async {
    final centerId = await _getCenterId();
    if (centerId == null || centerId.isEmpty) {
      throw Exception('Center ID غير موجود');
    }

    try {
      final data = group.toJson();
      data.remove('id');
      data.remove('center_id');
      data.remove('created_at');
      data.remove('course_name');
      data.remove('teacher_name');
      data.remove('scheduled_sessions');
      data.remove('sessions');

      // 1. Update group data
      await SupabaseClientManager.client
          .from('groups')
          .update(data)
          .eq('id', group.id);

      debugPrint('✅ [GroupsRemote] Group updated: ${group.id}');

      // 2. Sync sessions to schedules table
      // Delete existing schedules for this group
      await SupabaseClientManager.client
          .from('schedules')
          .delete()
          .eq('group_id', group.id);

      debugPrint(
        '🗑️ [GroupsRemote] Old schedules deleted for group: ${group.id}',
      );

      // 3. Insert new sessions
      if (group.sessions.isNotEmpty) {
        debugPrint(
          '📅 [GroupsRemote] Saving ${group.sessions.length} sessions...',
        );

        String dayToStr(int day) {
          switch (day) {
            case 0:
              return 'saturday';
            case 1:
              return 'sunday';
            case 2:
              return 'monday';
            case 3:
              return 'tuesday';
            case 4:
              return 'wednesday';
            case 5:
              return 'thursday';
            case 6:
              return 'friday';
            default:
              return 'saturday';
          }
        }

        for (final session in group.sessions) {
          final sessionData = {
            'course_id': group.courseId,
            'teacher_id': group.teacherId,
            'classroom_id': session.roomId.isNotEmpty ? session.roomId : null,
            'day_of_week': dayToStr(session.dayOfWeek),
            'start_time': session.startTime,
            'end_time': session.endTime,
            'center_id': centerId,
            'grade_level': group.gradeLevel,
            'group_id': group.id,
            'status': 'scheduled',
          };

          await SupabaseClientManager.client
              .from('schedules')
              .insert(sessionData);
        }

        debugPrint('✅ [GroupsRemote] ${group.sessions.length} sessions saved');
      }
    } catch (e) {
      debugPrint('❌ [GroupsRemote] Error updating group: $e');
      rethrow;
    }
  }

  Future<void> deleteGroup(String id) async {
    try {
      final centerId = await _getCenterId();
      if (centerId == null) throw Exception('Center ID غير موجود');

      final user = SupabaseClientManager.currentUser;
      if (user == null) throw Exception('User not authenticated');

      // NOTE: Using the safe_delete_group RPC to cascade:
      // 1. Drop all students from group
      // 2. Cancel future schedules
      // 3. Soft delete + audit log
      await SupabaseClientManager.client.rpc(
        'safe_delete_group',
        params: {
          'p_group_id': id,
          'p_center_id': centerId,
          'p_deleted_by': user.id,
        },
      );
    } catch (e) {
      debugPrint('❌ [GroupsRemote] Error: $e');
      rethrow;
    }
  }

  Future<List<StudentGroupEnrollment>> getGroupEnrollments(
    String groupId,
  ) async {
    try {
      final response = await SupabaseClientManager.client
          .from('student_group_enrollments')
          .select('''
            *,
            students(full_name),
            groups!student_group_enrollments_group_id_fkey(group_name)
          ''')
          .eq('group_id', groupId)
          .eq('status', 'active')
          .order('enrollment_date', ascending: false);

      return (response as List).map((data) {
        return StudentGroupEnrollment.fromJson({
          ...data,
          'student_name': data['students']?['full_name'],
          'group_name': data['groups']?['group_name'],
        });
      }).toList();
    } catch (e) {
      debugPrint('❌ [getGroupEnrollments] Error: $e');
      return [];
    }
  }

  Future<String> enrollStudentInGroup({
    required String studentId,
    required String groupId,
    String? notes,
  }) async {
    try {
      final centerId = await _getCenterId();
      if (centerId == null) throw Exception('Center ID not found');

      debugPrint('');
      debugPrint(
        '═══════════════════════════════════════════════════════════════',
      );
      debugPrint('📝 [Enrollment] تسجيل طالب في مجموعة');
      debugPrint(
        '═══════════════════════════════════════════════════════════════',
      );
      debugPrint('   🆔 Student ID: $studentId');
      debugPrint('   📦 Group ID: $groupId');

      // 1. Check if Group Exists and is Active
      final groupData = await SupabaseClientManager.client
          .from('groups')
          .select(
            'id, group_name, status, max_students, course_id, monthly_fee',
          )
          .eq('id', groupId)
          .single();

      debugPrint('   📦 اسم المجموعة: ${groupData['group_name']}');
      debugPrint('   💰 الرسوم الشهرية: ${groupData['monthly_fee'] ?? 0} جنيه');
      debugPrint('   📌 الحالة: ${groupData['status']}');

      if (groupData['status'] != 'active') {
        throw Exception(
          'لا يمكن التسجيل في مجموعة غير نشطة (${groupData['group_name']})',
        );
      }

      // 2. Check Capacity
      final countResponse = await SupabaseClientManager.client
          .from('student_group_enrollments')
          .count(CountOption.exact)
          .eq('group_id', groupId)
          .eq('status', 'active');

      final currentCount = countResponse;
      final max = groupData['max_students'] as int? ?? 30;

      debugPrint('   👥 السعة: $currentCount / $max');

      if (currentCount >= max) {
        throw Exception(
          'عذراً، المجموعة ممتلئة ($currentCount/$max). يرجى اختيار مجموعة أخرى.',
        );
      }

      // 3. Check Duplicate Enrollment (Same Group)
      final existing = await SupabaseClientManager.client
          .from('student_group_enrollments')
          .select('id')
          .eq('student_id', studentId)
          .eq('group_id', groupId)
          .eq('status', 'active')
          .maybeSingle();

      if (existing != null) {
        throw Exception('الطالب مسجل بالفعل في هذه المجموعة.');
      }

      final data = {
        'student_id': studentId,
        'group_id': groupId,
        'center_id': centerId,
        'enrollment_date': DateTime.now().toIso8601String().split('T')[0],
        'status': 'active',
        'notes': notes,
      };

      final response = await SupabaseClientManager.client
          .from('student_group_enrollments')
          .insert(data)
          .select()
          .single();

      // 4. Create Initial Invoice if fee > 0
      final double monthlyFee =
          (groupData['monthly_fee'] as num?)?.toDouble() ?? 0.0;
      if (monthlyFee > 0.0) {
        final now = DateTime.now();
        final invoiceData = {
          'student_id': studentId,
          'center_id': centerId,
          'month': now.month,
          'year': now.year,
          'total_amount': monthlyFee,
          'paid_amount': 0,
          'discount_amount': 0,
          'status': 'pending',
          'due_date': now
              .add(const Duration(days: 7))
              .toIso8601String()
              .split('T')[0],
          'notes': 'تلقائي عند التسجيل في مجموعة ${groupData['group_name']}',
        };
        try {
          await SupabaseClientManager.client
              .from('student_invoices')
              .insert(invoiceData);
          debugPrint('   💰 فاتورة تم إنشاؤها بنجاح!');
        } catch (invoiceError) {
          debugPrint('   ⚠️ فشل إنشاء فاتورة: $invoiceError');
          // Non-fatal, we don't throw!
        }
      }

      debugPrint('');
      debugPrint('✅ [Enrollment] تم التسجيل بنجاح!');
      debugPrint('   🎟️ Enrollment ID: ${response['id']}');
      debugPrint('   📅 تاريخ التسجيل: ${response['enrollment_date']}');
      debugPrint(
        '═══════════════════════════════════════════════════════════════',
      );
      debugPrint('');

      // NOTE: Notifications are fire-and-forget — don't block enrollment on failure.
      try {
        // Get student user_id and name for notification
        final studentRes = await SupabaseClientManager.client
            .from('students')
            .select('user_id, full_name')
            .eq('id', studentId)
            .maybeSingle();

        final studentUserId = studentRes?['user_id'] as String?;
        final studentName = studentRes?['full_name'] as String? ?? 'طالب';
        final groupName = groupData['group_name'] as String? ?? 'مجموعة';

        // Get course name
        final courseId = groupData['course_id'] as String?;
        String courseName = 'مادة';
        if (courseId != null) {
          final courseRes = await SupabaseClientManager.client
              .from('courses')
              .select('name')
              .eq('id', courseId)
              .maybeSingle();
          courseName = courseRes?['name'] as String? ?? 'مادة';
        }

        // 1. Notify student about group enrollment
        if (studentUserId != null) {
          await NotificationHelper.notifyStudentAddedToGroup(
            studentUserId: studentUserId,
            groupName: groupName,
            courseName: courseName,
            centerId: centerId,
          );
        }

        // 2. Notify teacher about new student in their group
        final groupTeacherId = await _getTeacherUserIdFromGroup(groupId);
        if (groupTeacherId != null) {
          await NotificationHelper.notifyTeacherNewStudent(
            teacherUserId: groupTeacherId,
            studentName: studentName,
            groupName: groupName,
            centerId: centerId,
          );
        }
      } catch (e) {
        debugPrint('⚠️ [Enrollment] Notification failed (non-fatal): $e');
      }

      return response['id'] as String;
    } catch (e) {
      debugPrint('❌ [enrollStudentInGroup] Error: $e');
      if (e.toString().contains('unique constraint')) {
        throw Exception('الطالب مسجل بالفعل في هذه المجموعة.');
      }
      if (e.toString().startsWith('Exception:')) rethrow;
      throw Exception('فشل في تسجيل الطالب: $e');
    }
  }

  Future<void> transferStudentToGroup({
    required String studentId,
    required String fromGroupId,
    required String toGroupId,
    String? notes,
  }) async {
    try {
      await SupabaseClientManager.client
          .from('student_group_enrollments')
          .update({
            'status': 'transferred',
            'withdrawal_date': DateTime.now().toIso8601String().split('T')[0],
            'withdrawal_reason': 'Transferred to group $toGroupId',
          })
          .eq('student_id', studentId)
          .eq('group_id', fromGroupId)
          .eq('status', 'active');

      await enrollStudentInGroup(
        studentId: studentId,
        groupId: toGroupId,
        notes: notes ?? 'Transferred from group $fromGroupId',
      );
    } catch (e) {
      debugPrint('❌ [transferStudentToGroup] Error: $e');
      rethrow;
    }
  }

  Future<void> withdrawStudentFromGroup({
    required String studentId,
    required String groupId,
    String? reason,
  }) async {
    try {
      // Get group name before withdrawal for notification
      String groupName = 'مجموعة';
      String? centerId;
      try {
        final groupRes = await SupabaseClientManager.client
            .from('groups')
            .select('group_name, center_id')
            .eq('id', groupId)
            .maybeSingle();
        groupName = groupRes?['group_name'] as String? ?? 'مجموعة';
        centerId = groupRes?['center_id'] as String?;
      } catch (_) {}

      await SupabaseClientManager.client
          .from('student_group_enrollments')
          .update({
            'status': 'withdrawn',
            'withdrawal_date': DateTime.now().toIso8601String().split('T')[0],
            'withdrawal_reason': reason,
          })
          .eq('student_id', studentId)
          .eq('group_id', groupId)
          .eq('status', 'active');

      // NOTE: Notify student about removal — fire-and-forget.
      try {
        final studentRes = await SupabaseClientManager.client
            .from('students')
            .select('user_id')
            .eq('id', studentId)
            .maybeSingle();
        final studentUserId = studentRes?['user_id'] as String?;
        if (studentUserId != null && centerId != null) {
          await NotificationHelper.notifyStudentRemovedFromGroup(
            studentUserId: studentUserId,
            groupName: groupName,
            centerId: centerId,
          );
        }
      } catch (e) {
        debugPrint('⚠️ [Withdraw] Notification failed (non-fatal): $e');
      }
    } catch (e) {
      debugPrint('❌ [withdrawStudentFromGroup] Error: $e');
      rethrow;
    }
  }

  Future<SmartEnrollmentResult> bulkEnrollStudents({
    required List<String> studentIds,
    required String groupId,
  }) async {
    int success = 0;
    int failed = 0;
    List<String> errors = [];

    try {
      final centerId = await _getCenterId();
      if (centerId == null) throw Exception('Center ID required');

      // Fallback to individual to capture successes/failures reliably and handle duplicates gracefully
      for (var sid in studentIds) {
        try {
          await enrollStudentInGroup(studentId: sid, groupId: groupId);
          success++;
        } catch (err) {
          failed++;
          errors.add('Failed $sid: $err');
        }
      }
    } catch (e) {
      errors.add('System Error: $e');
    }

    return SmartEnrollmentResult(
      totalAttempted: studentIds.length,
      successCount: success,
      failureCount: failed,
      errors: errors,
    );
  }

  Future<SmartEnrollmentResult> autoEnrollCourseStudents({
    required String groupId,
    int sessionsPerStudent = 1,
    bool avoidTimeConflicts = true,
    bool fairDistribution = true,
  }) async {
    final centerId = await _getCenterId();
    if (centerId == null) throw Exception('Center ID required');

    final response = await SupabaseClientManager.client.rpc(
      'auto_enroll_course_students',
      params: {
        'p_group_id': groupId,
        'p_center_id': centerId,
        'p_sessions_per_student': sessionsPerStudent,
        'p_avoid_conflicts': avoidTimeConflicts,
        'p_fair_distribution': fairDistribution,
      },
    );

    final data = response as Map<String, dynamic>;
    return SmartEnrollmentResult(
      totalAttempted: data['total_attempted'] ?? 0,
      successCount: data['success_count'] ?? 0,
      failureCount: data['failure_count'] ?? 0,
      errors: List<String>.from(data['errors'] ?? []),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // SMART STUDENT FETCHING
  // ═══════════════════════════════════════════════════════════════════════════

  /// الحصول على الطلاب المتاحين للتسجيل في مجموعة معينة
  /// مع معلومات ذكية عن كل طالب
  Future<List<SmartStudentOption>> getAvailableStudentsForGroup({
    required String groupId,
    String? filterByStage,
    String? filterByCourse,
    StudentFilterType filterType = StudentFilterType.all,
    String? searchQuery,
  }) async {
    try {
      debugPrint('🧠 [SmartGroups] Fetching students for group: $groupId');

      final centerId = await _getCenterId();
      if (centerId == null) return [];

      // 1. Get group info first
      debugPrint('🔍 [SmartGroups] 1. Getting group info...');
      final groupData = await SupabaseClientManager.client
          .from('groups')
          .select(
            'id, group_name, grade_level, course_id, day_of_week, start_time, end_time, max_students',
          )
          .eq('id', groupId)
          .single();

      final groupStage = groupData['grade_level'] as String?;
      final groupCourseId = groupData['course_id'] as String?;
      final groupDay = groupData['day_of_week'] as int?;
      final groupStartTime = groupData['start_time'] as String?;
      final groupEndTime = groupData['end_time'] as String?;

      // 2. Get already enrolled students in this group
      debugPrint('🔍 [SmartGroups] 2. Getting enrolled students...');
      final enrolledResponse = await SupabaseClientManager.client
          .from('student_group_enrollments')
          .select('student_id')
          .eq('group_id', groupId)
          .eq('status', 'active');

      final enrolledIds = (enrolledResponse as List)
          .map((e) => e['student_id'] as String)
          .toSet();

      // 3. Build student query based on filter
      debugPrint('🔍 [SmartGroups] 3. Building student query...');
      var query = SupabaseClientManager.client
          .from('student_enrollments')
          .select('''
            student_id,
            grade_level,
            students!inner(
              id,
              full_name,
              phone
            )
          ''')
          .eq('center_id', centerId)
          .eq('status', 'accepted');

      final studentsResponse = await query;
      debugPrint(
        '✅ [SmartGroups] 3. Students fetched: ${(studentsResponse as List).length}',
      );

      Set<String> allowedCourseStudentIds = {};
      if (filterType == StudentFilterType.sameCourse && groupCourseId != null) {
        try {
          final courseStudentsResp = await SupabaseClientManager.client
              .from('student_courses')
              .select('student_id')
              .eq('course_id', groupCourseId)
              .eq('status', 'active');
          allowedCourseStudentIds = (courseStudentsResp as List)
              .map((e) => e['student_id'] as String)
              .toSet();
          debugPrint(
            '✅ [SmartGroups] course filter list: ${allowedCourseStudentIds.length} students',
          );
        } catch (e) {
          debugPrint('⚠️ [SmartGroups] Could not fetch student_courses: $e');
        }
      }

      // 4. Get all group enrollments for conflict checking (wrap in try-catch for RLS issues)
      Map<String, List<StudentGroupInfo>> studentGroupsMap = {};
      try {
        debugPrint(
          '🔍 [SmartGroups] 4. Getting all enrollments (fallback no-join)...',
        );
        final enrollments = await SupabaseClientManager.client
            .from('student_group_enrollments')
            .select('student_id, group_id')
            .eq('status', 'active');

        final groupIds = <String>{};
        final tempMap = <String, List<String>>{};
        for (final e in enrollments as List) {
          final sid = e['student_id'] as String;
          final gid = e['group_id'] as String;
          tempMap.putIfAbsent(sid, () => []);
          tempMap[sid]!.add(gid);
          groupIds.add(gid);
        }

        Map<String, Map<String, dynamic>> groupsDetails = {};
        if (groupIds.isNotEmpty) {
          final groupsResp = await SupabaseClientManager.client
              .from('groups')
              .select('id, group_name, day_of_week, start_time, end_time')
              .inFilter('id', groupIds.toList());
          for (final g in groupsResp as List) {
            groupsDetails[g['id'] as String] = g as Map<String, dynamic>;
          }
        }

        tempMap.forEach((sid, gids) {
          for (final gid in gids) {
            final info = groupsDetails[gid];
            if (info != null) {
              studentGroupsMap.putIfAbsent(sid, () => []);
              studentGroupsMap[sid]!.add(
                StudentGroupInfo(
                  groupId: gid,
                  groupName: info['group_name'] as String? ?? '',
                  dayOfWeek: info['day_of_week'] as int?,
                  startTime: info['start_time'] as String?,
                  endTime: info['end_time'] as String?,
                ),
              );
            }
          }
        });
        debugPrint(
          '✅ [SmartGroups] 4. Conflict map built for ${studentGroupsMap.length} students (fallback)',
        );
      } catch (e) {
        debugPrint('⚠️ [SmartGroups] 4. Skipping conflict check due to: $e');
        // Continue without conflict checking - not critical
      }

      // 5. Process students
      final List<SmartStudentOption> result = [];

      for (final enrollment in studentsResponse as List) {
        final student = enrollment['students'] as Map<String, dynamic>;
        final studentId = student['id'] as String;

        // Skip already enrolled students
        if (enrolledIds.contains(studentId)) continue;

        final name = student['full_name'] as String? ?? 'طالب';
        final phone = student['phone'] as String?;
        final stage =
            enrollment['grade_level']
                as String?; // Get grade_level from enrollment
        final school = null; // school column doesn't exist

        // Apply filters - with smart stage matching
        if (filterType == StudentFilterType.sameStage && groupStage != null) {
          if (!_stagesMatch(stage, groupStage)) continue;
        }

        // Apply search query
        if (searchQuery != null && searchQuery.isNotEmpty) {
          final query = searchQuery.toLowerCase();
          final matchesName = name.toLowerCase().contains(query);
          final matchesPhone = phone?.contains(query) ?? false;
          if (!matchesName && !matchesPhone) continue;
        }

        if (filterType == StudentFilterType.sameCourse &&
            groupCourseId != null) {
          // 1. Check if enrolled in course
          if (allowedCourseStudentIds.isNotEmpty &&
              !allowedCourseStudentIds.contains(studentId)) {
            continue;
          }
          // 2. Check if same stage (User Request: Filter by BOTH course and stage)
          if (groupStage != null && !_stagesMatch(stage, groupStage)) {
            continue;
          }
        }

        // Check for conflicts
        final studentGroups = studentGroupsMap[studentId] ?? [];
        bool hasConflict = false;
        String? conflictReason;

        // Check time conflict
        if (groupDay != null && groupStartTime != null) {
          for (final existingGroup in studentGroups) {
            if (existingGroup.dayOfWeek == groupDay) {
              // Same day - check time overlap
              if (existingGroup.startTime != null) {
                hasConflict = true;
                conflictReason =
                    'تعارض: ${existingGroup.groupName} (${existingGroup.timeSlot})';
                break;
              }
            }
          }
        }

        // Filter by no groups
        if (filterType == StudentFilterType.noGroups &&
            studentGroups.isNotEmpty) {
          continue;
        }

        result.add(
          SmartStudentOption(
            id: studentId,
            name: name,
            phone: phone,
            stage: stage,
            school: school,
            currentGroupsCount: studentGroups.length,
            hasConflict: hasConflict,
            conflictReason: conflictReason,
            currentGroups: studentGroups,
          ),
        );
      }

      // Sort: non-conflicting first, then by name
      result.sort((a, b) {
        if (a.hasConflict != b.hasConflict) {
          return a.hasConflict ? 1 : -1;
        }
        return a.name.compareTo(b.name);
      });

      debugPrint('✅ [SmartGroups] Found ${result.length} available students');
      return result;
    } catch (e) {
      debugPrint('❌ [SmartGroups] Error: $e');
      return [];
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // CONFLICT DETECTION
  // ═══════════════════════════════════════════════════════════════════════════

  /// فحص تعارضات الجدول للطالب قبل التسجيل
  Future<List<ScheduleConflict>> checkStudentConflicts({
    required String studentId,
    required String groupId,
  }) async {
    try {
      final conflicts = <ScheduleConflict>[];

      // Get target group info
      final groupData = await SupabaseClientManager.client
          .from('groups')
          .select('*, courses(name)')
          .eq('id', groupId)
          .single();

      final targetDay = groupData['day_of_week'] as int?;
      final targetStart = groupData['start_time'] as String?;
      final maxStudents = groupData['max_students'] as int? ?? 30;

      // Check if already enrolled
      final existingEnrollment = await SupabaseClientManager.client
          .from('student_group_enrollments')
          .select('id')
          .eq('student_id', studentId)
          .eq('group_id', groupId)
          .eq('status', 'active')
          .maybeSingle();

      if (existingEnrollment != null) {
        conflicts.add(
          const ScheduleConflict(
            type: ConflictType.duplicate,
            message: 'الطالب مسجل بالفعل في هذه المجموعة',
          ),
        );
      }

      // Check capacity
      final currentCount = await SupabaseClientManager.client
          .from('student_group_enrollments')
          .count(CountOption.exact)
          .eq('group_id', groupId)
          .eq('status', 'active');

      if (currentCount >= maxStudents) {
        conflicts.add(
          ScheduleConflict(
            type: ConflictType.capacity,
            message: 'المجموعة ممتلئة ($currentCount/$maxStudents)',
          ),
        );
      }

      // Check time conflicts with other groups
      if (targetDay != null && targetStart != null) {
        final studentGroups = await SupabaseClientManager.client
            .from('student_group_enrollments')
            .select('''
              groups!student_group_enrollments_group_id_fkey(
                group_name,
                day_of_week,
                start_time,
                end_time
              )
            ''')
            .eq('student_id', studentId)
            .eq('status', 'active');

        for (final enrollment in studentGroups as List) {
          final group = enrollment['groups'] as Map<String, dynamic>?;
          if (group == null) continue;

          final day = group['day_of_week'] as int?;
          final start = group['start_time'] as String?;

          if (day == targetDay && start != null) {
            conflicts.add(
              ScheduleConflict(
                type: ConflictType.time,
                message: 'تعارض في الجدول مع ${group['group_name']}',
                groupName: group['group_name'] as String?,
                conflictingTime: start,
              ),
            );
          }
        }
      }

      return conflicts;
    } catch (e) {
      debugPrint('❌ [checkStudentConflicts] Error: $e');
      return [];
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // SMART SUGGESTIONS
  // ═══════════════════════════════════════════════════════════════════════════

  /// اقتراح اسم ذكي للمجموعة
  String suggestGroupName({
    required String courseName,
    String? gradeLevel,
    int? dayOfWeek,
  }) {
    final parts = <String>[courseName];

    if (gradeLevel != null && gradeLevel.isNotEmpty) {
      parts.add(gradeLevel);
    }

    if (dayOfWeek != null && dayOfWeek >= 0 && dayOfWeek <= 6) {
      const days = [
        'السبت',
        'الأحد',
        'الإثنين',
        'الثلاثاء',
        'الأربعاء',
        'الخميس',
        'الجمعة',
      ];
      parts.add(days[dayOfWeek]);
    }

    return parts.join(' - ');
  }

  /// اقتراح وقت الانتهاء (90 دقيقة من البداية)
  String? suggestEndTime(String? startTime, {int durationMinutes = 90}) {
    if (startTime == null) return null;

    try {
      final parts = startTime.split(':');
      if (parts.length < 2) return null;

      int hours = int.parse(parts[0]);
      int minutes = int.parse(parts[1]);

      minutes += durationMinutes;
      hours += minutes ~/ 60;
      minutes = minutes % 60;

      if (hours >= 24) hours -= 24;

      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}';
    } catch (e) {
      return null;
    }
  }

  /// الحصول على إحصائيات المجموعة
  Future<Map<String, dynamic>> getGroupStats(String groupId) async {
    try {
      // Get enrollment count
      final count = await SupabaseClientManager.client
          .from('student_group_enrollments')
          .count(CountOption.exact)
          .eq('group_id', groupId)
          .eq('status', 'active');

      // Get group info
      final group = await SupabaseClientManager.client
          .from('groups')
          .select('max_students, monthly_fee')
          .eq('id', groupId)
          .single();

      final maxStudents = group['max_students'] as int? ?? 30;
      final monthlyFee = (group['monthly_fee'] as num?)?.toDouble() ?? 0;

      return {
        'current_students': count,
        'max_students': maxStudents,
        'available_slots': maxStudents - count,
        'occupancy_rate': count / maxStudents * 100,
        'is_full': count >= maxStudents,
        'expected_revenue': count * monthlyFee,
      };
    } catch (e) {
      debugPrint('❌ [getGroupStats] Error: $e');
      return {};
    }
  }

  /// Smart stage matching - handles different format comparisons
  /// e.g., '1ث' matches 'الصف الأول الثانوي', '2ث' matches 'الصف الثاني الثانوي'
  bool _stagesMatch(String? studentStage, String? groupStage) {
    if (studentStage == null || groupStage == null) return false;

    // Direct match
    if (studentStage == groupStage) return true;

    // Protect against mixing different types of stages
    bool studentIsPrep =
        studentStage.contains('إعدادي') || studentStage.contains('إ');
    bool groupIsPrep =
        groupStage.contains('إعدادي') || groupStage.contains('إ');
    if (studentIsPrep != groupIsPrep) return false;

    bool studentIsSec =
        studentStage.contains('ثانوي') || studentStage.contains('ث');
    bool groupIsSec = groupStage.contains('ثانوي') || groupStage.contains('ث');
    if (studentIsSec != groupIsSec) return false;

    bool studentIsPri =
        studentStage.contains('ابتدائي') || studentStage.contains('ب');
    bool groupIsPri =
        groupStage.contains('ابتدائي') || groupStage.contains('ب');
    if (studentIsPri != groupIsPri) return false;

    // Normalize both to a common format for comparison
    final studentNormalized = _normalizeStage(studentStage);
    final groupNormalized = _normalizeStage(groupStage);

    return studentNormalized == groupNormalized;
  }

  /// Normalize stage to a number (1, 2, 3) for comparison
  int _normalizeStage(String stage) {
    final lowerStage = stage.toLowerCase();

    // Check for short format: 1ث, 2ث, 3ث
    if (lowerStage.contains('1') || lowerStage.contains('١')) return 1;
    if (lowerStage.contains('2') || lowerStage.contains('٢')) return 2;
    if (lowerStage.contains('3') || lowerStage.contains('٣')) return 3;

    // Check for Arabic ordinal words
    if (lowerStage.contains('الأول') || lowerStage.contains('أول')) return 1;
    if (lowerStage.contains('الثاني') || lowerStage.contains('ثاني')) return 2;
    if (lowerStage.contains('الثالث') || lowerStage.contains('ثالث')) return 3;

    return 0; // Unknown
  }
}
