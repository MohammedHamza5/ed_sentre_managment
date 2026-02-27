import 'package:flutter/foundation.dart';
import '../../../../core/supabase/supabase_client.dart';
import '../../../../shared/models/auth_models.dart';
import '../../../../shared/models/pricing_models.dart';
import '../../../../core/monitoring/app_logger.dart';
import '../../../../core/supabase/auth_service.dart';

class SettingsRemoteSource {
  Future<String?> _getCenterId() async {
    final savedCenterId = await AuthService.getSavedCenterId();
    if (savedCenterId != null) return savedCenterId;

    final user = SupabaseClientManager.currentUser;
    if (user == null) return null;
    return user.userMetadata?['center_id'] ??
        user.userMetadata?['default_center_id'];
  }

  Future<List<CenterUser>> getCenterUsers() async {
    try {
      final centerId = await _getCenterId();
      if (centerId == null) throw Exception('السنتر غير معرف');

      final response = await SupabaseClientManager.client
          .from('users')
          .select('id, full_name, email, phone, role, is_active')
          .eq('default_center_id', centerId)
          .neq('role', 'teacher') // Exclude teachers
          .neq('role', 'student') // Exclude students
          .order('created_at', ascending: false);

      return (response as List).map((e) => CenterUser.fromJson(e)).toList();
    } catch (e) {
      debugPrint('❌ [getCenterUsers] Error: $e');
      rethrow;
    }
  }

  Future<void> addCenterUser({
    required String fullName,
    required String phone,
    required String role,
    String? email,
  }) async {
    try {
      final centerId = await _getCenterId();
      if (centerId == null) throw Exception('السنتر غير معرف');

      await SupabaseClientManager.client.from('users').insert({
        'full_name': fullName.trim(),
        'phone': phone.trim(),
        'email': email?.trim(),
        'role': role,
        'default_center_id': centerId,
        'is_active': true,
      });
    } catch (e) {
      debugPrint('❌ [addCenterUser] Error: $e');
      rethrow;
    }
  }

  Future<List<AppRole>> getCenterRoles() async {
    try {
      final centerId = await _getCenterId();
      if (centerId == null) return [];

      final response = await SupabaseClientManager.client
          .from('app_roles')
          .select('*, role_permissions(permission_code)')
          .eq('center_id', centerId)
          .order('created_at');

      return (response as List).map((e) => AppRole.fromJson(e)).toList();
    } catch (e) {
      debugPrint('❌ [getCenterRoles] Error: $e');
      rethrow;
    }
  }

  Future<void> createRole({
    required String name,
    required String description,
  }) async {
    try {
      final centerId = await _getCenterId();
      if (centerId == null) throw Exception('السنتر غير معرف');

      await SupabaseClientManager.client.from('app_roles').insert({
        'name': name,
        'name_ar': name,
        'description': description,
        'center_id': centerId,
      });
    } catch (e) {
      debugPrint('❌ [createRole] Error: $e');
      rethrow;
    }
  }

  Future<List<CoursePrice>> getCoursePrices(String centerId) async {
    try {
      final response = await SupabaseClientManager.client
          .from('course_prices_view')
          .select()
          .eq('center_id', centerId)
          .eq('is_active', true)
          .order('subject_name');

      return (response as List)
          .map((json) => CoursePrice.fromJson(json))
          .toList();
    } catch (e) {
      debugPrint('❌ [getCoursePrices] Error: $e');
      // Fallback
      try {
        final response = await SupabaseClientManager.client
            .from('course_prices')
            .select('*, teachers!left(id, user_id, users!left(full_name))')
            .eq('center_id', centerId)
            .eq('is_active', true)
            .order('subject_name');

        return (response as List).map((json) {
          final teacherData = json['teachers'];
          String? teacherName;
          if (teacherData != null) {
            final userData = teacherData['users'];
            teacherName = userData?['full_name'];
          }

          return CoursePrice.fromJson({
            ...json,
            'teacher_name': teacherName ?? 'أي مدرس',
          });
        }).toList();
      } catch (e2) {
        debugPrint('❌ [getCoursePrices] Fallback Error: $e2');
        return [];
      }
    }
  }

  Future<String> upsertCoursePrice({
    required String centerId,
    required String subjectName,
    required double sessionPrice,
    String? teacherId,
    String? gradeLevel,
    double? monthlyPrice,
    int sessionsPerMonth = 8,
    String? notes,
  }) async {
    AppLogger.database(
      '💰 [upsertCoursePrice] Request',
      data: {
        'subjectName': subjectName,
        'sessionPrice': sessionPrice,
        'teacherId': teacherId,
      },
    );

    try {
      // Replacing broken RPC with direct DB operations to avoid 'group_id' error
      final data = {
        'center_id': centerId,
        'subject_name': subjectName,
        'session_price': sessionPrice,
        'teacher_id': teacherId,
        'grade_level': gradeLevel,
        'monthly_price': monthlyPrice,
        'sessions_per_month': sessionsPerMonth,
        'notes': notes,
        'is_active': true,
        'updated_at': DateTime.now().toIso8601String(),
      };

      // Check existence first to decide Insert vs Update (Manual Upsert)
      // because Supabase upsert requires unique constraint index which might differ
      final query = SupabaseClientManager.client
          .from('course_prices')
          .select('id')
          .eq('center_id', centerId)
          .eq('subject_name', subjectName);

      if (teacherId != null) {
        query.eq('teacher_id', teacherId);
      } else {
        query.filter('teacher_id', 'is', null);
      }

      if (gradeLevel != null) {
        query.eq('grade_level', gradeLevel);
      } else {
        query.filter('grade_level', 'is', null);
      }

      final existing = await query.maybeSingle();

      if (existing != null) {
         await SupabaseClientManager.client
            .from('course_prices')
            .update(data)
            .eq('id', existing['id']);
         return existing['id'].toString();
      } else {
        final res = await SupabaseClientManager.client
            .from('course_prices')
            .insert(data)
            .select('id')
            .single();
        return res['id'].toString();
      }

    } catch (e) {
      debugPrint('❌ [upsertCoursePrice] Error: $e');
      throw Exception('فشل في حفظ السعر: $e');
    }
  }

  /// يحسب عدد "الاشتراكات النشطة" للمحاسبة عليها
  Future<int> getBillableActiveEnrollmentsCount() async {
    try {
      final centerId = await _getCenterId();
      if (centerId == null) return 0;

      final thirtyDaysAgo = DateTime.now()
          .subtract(const Duration(days: 30))
          .toIso8601String();

      // 1. Get students active via Attendance (The main driver)
      final activeAttendanceResponse = await SupabaseClientManager.client
          .from('attendance')
          .select('student_id, session_id, group_id')
          .eq('status', 'present')
          .gte('created_at', thirtyDaysAgo);

      final activeEnrollments = <String>{}; // Set of "studentId_groupId"
      final sessionIdsToResolve = <String>{};
      final attendanceRecordsNeededResolution = <Map<String, dynamic>>[];

      for (var record in activeAttendanceResponse) {
        final studentId = record['student_id'] as String;
        final groupId = record['group_id'] as String?;
        final sessionId = record['session_id'] as String?;

        if (groupId != null) {
          activeEnrollments.add('${studentId}_$groupId');
        } else if (sessionId != null) {
          sessionIdsToResolve.add(sessionId);
          attendanceRecordsNeededResolution.add(record);
        }
      }

      // 2. Resolve missing group_ids from sessions table
      if (sessionIdsToResolve.isNotEmpty) {
        try {
          final sessionsResponse = await SupabaseClientManager.client
              .from('sessions')
              .select('id, group_id')
              .inFilter('id', sessionIdsToResolve.toList());

          final sessionGroupMap = {
            for (var s in sessionsResponse)
              s['id'] as String: s['group_id'] as String,
          };

          for (var record in attendanceRecordsNeededResolution) {
            final studentId = record['student_id'] as String;
            final sessionId = record['session_id'] as String;
            final groupId = sessionGroupMap[sessionId];

            if (groupId != null) {
              activeEnrollments.add('${studentId}_$groupId');
            }
          }
        } catch (e) {
          debugPrint('⚠️ [Billing] Failed to resolve sessions: $e');
        }
      }

      debugPrint(
        '💰 [Billing] Active Enrollments (last 30 days): ${activeEnrollments.length}',
      );
      return activeEnrollments.length;
    } catch (e) {
      debugPrint('❌ [Billing] Error calculating billable count: $e');
      return 0; // Fail safe
    }
  }

  Future<Map<String, int>> getAiUsageStats() async {
    try {
      final response = await SupabaseClientManager.client
          .from('ai_analytics')
          .select('id');

      final total = (response as List).length;

      return {
        'questions': 0, // No specific table for questions yet
        'exams': 0, // No specific flag for AI exams yet
        'reports': total,
      };
    } catch (e) {
      debugPrint('⚠️ [Stats] Failed to fetch AI stats: $e');
      return {'questions': 0, 'exams': 0, 'reports': 0};
    }
  }

  /// Simulate the impact of a price change on existing invoices
  Future<Map<String, dynamic>> simulatePriceImpact({
    required String centerId,
    required String subjectName,
    String? teacherId,
    String? gradeLevel,
    required double newPrice,
  }) async {
    try {
      // Call RPC to simulate price impact
      final result = await SupabaseClientManager.client.rpc(
        'simulate_price_impact',
        params: {
          'p_center_id': centerId,
          'p_subject_name': subjectName,
          'p_teacher_id': teacherId,
          'p_grade_level': gradeLevel,
          'p_new_price': newPrice,
        },
      );

      if (result == null) {
        return {
          'impacted_invoices': 0,
          'revenue_difference': 0.0,
          'sample_students': <String>[],
        };
      }

      return {
        'impacted_invoices': result['impacted_invoices'] ?? 0,
        'revenue_difference': (result['revenue_difference'] as num?)?.toDouble() ?? 0.0,
        'sample_students': (result['sample_students'] as List?)?.cast<String>() ?? <String>[],
      };
    } catch (e) {
      debugPrint('⚠️ [simulatePriceImpact] Error: $e');
      // Return empty result on error
      return {
        'impacted_invoices': 0,
        'revenue_difference': 0.0,
        'sample_students': <String>[],
      };
    }
  }

  /// Delete a course price
  Future<void> deleteCoursePrice(String priceId) async {
    try {
      await SupabaseClientManager.client
          .from('course_prices')
          .update({'is_active': false})
          .eq('id', priceId);
    } catch (e) {
      debugPrint('❌ [deleteCoursePrice] Error: $e');
      rethrow;
    }
  }

  /// Update a role
  Future<void> updateRole({
    required String roleId,
    required String name,
    String? description,
  }) async {
    try {
      await SupabaseClientManager.client
          .from('app_roles')
          .update({
            'name_ar': name,
            'description': description,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', roleId);
    } catch (e) {
      debugPrint('❌ [updateRole] Error: $e');
      rethrow;
    }
  }

  /// Delete a role
  Future<void> deleteRole(String roleId) async {
    try {
      // First delete role permissions
      await SupabaseClientManager.client
          .from('role_permissions')
          .delete()
          .eq('role_id', roleId);

      // Then delete the role itself
      await SupabaseClientManager.client
          .from('app_roles')
          .delete()
          .eq('id', roleId);
    } catch (e) {
      debugPrint('❌ [deleteRole] Error: $e');
      rethrow;
    }
  }
}


