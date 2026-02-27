import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/supabase/supabase_client.dart';
import '../../../../shared/models/models.dart';

class ReportsRepository {
  Future<String?> _getCenterId() async {
    final user = SupabaseClientManager.currentUser;
    return user?.userMetadata?['center_id'] ??
        user?.userMetadata?['default_center_id'];
  }
  // ═══════════════════════════════════════════════════════════════════════════
  // General Stats
  // ═══════════════════════════════════════════════════════════════════════════

  Future<Map<String, dynamic>> getGeneralSummary(String centerId) async {
    try {
      // Parallel fetching for performance
      final results = await Future.wait([
        SupabaseClientManager.client
            .from('student_enrollments')
            .select()
            .eq('center_id', centerId)
            .count(CountOption.exact),
        SupabaseClientManager.client
            .from('teacher_enrollments')
            .select()
            .eq('center_id', centerId)
            .count(CountOption.exact),
        SupabaseClientManager.client
            .from('courses')
            .select()
            .eq('center_id', centerId)
            .count(CountOption.exact),
        SupabaseClientManager.client
            .from('classrooms')
            .select()
            .eq('center_id', centerId)
            .count(CountOption.exact),
      ]);

      final studentCount = results[0].count;
      final teacherCount = results[1].count;
      final courseCount = results[2].count;
      final roomCount = results[3].count;

      return {
        'totalStudents': studentCount,
        'totalTeachers': teacherCount,
        'totalSubjects': courseCount,
        'totalRooms': roomCount,
      };
    } catch (e) {
      debugPrint('Error getting general summary: $e');
      throw Exception('Failed to fetch summary');
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Attendance Reports
  // ═══════════════════════════════════════════════════════════════════════════

  Future<Map<String, dynamic>> getAttendanceReport(
    String centerId,
    DateTime start,
    DateTime end,
  ) async {
    final startStr = start.toIso8601String().split('T')[0];
    final endStr = end.toIso8601String().split('T')[0];

    try {
      // Determine columns to fetch. We need status for stats.
      final response = await SupabaseClientManager.client
          .from('attendance')
          .select(
            'id, date, status, student_id, students(full_name, users(full_name))',
          )
          .eq('center_id', centerId)
          .gte('date', startStr)
          .lte('date', endStr);

      final List<dynamic> data = response;

      int present = 0;
      int absent = 0;
      int late = 0;
      int excused = 0;

      for (var record in data) {
        final status = record['status'];
        if (status == 'present') {
          present++;
        } else if (status == 'absent')
          absent++;
        else if (status == 'late')
          late++;
        else if (status == 'excused')
          excused++;
      }

      final total = data.length;

      return {
        'total': total,
        'present': present,
        'absent': absent,
        'late': late,
        'excused': excused,
        'rate': total > 0 ? (present + late) / total * 100 : 0.0,
        // Optional: Return raw records for list view
        'records': data.map((r) {
          final studentNode = r['students'];
          final userNode = studentNode?['users'];
          final studentName =
              userNode?['full_name'] ?? studentNode?['full_name'] ?? 'Unknown';

          return {
            'date': r['date'],
            'status': r['status'],
            'studentName': studentName,
          };
        }).toList(),
      };
    } catch (e) {
      debugPrint('Error fetching attendance report: $e');
      rethrow;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Financial Reports
  // ═══════════════════════════════════════════════════════════════════════════

  Future<Map<String, dynamic>> getFinancialReport(
    String centerId,
    DateTime start,
    DateTime end,
  ) async {
    try {
      final response = await SupabaseClientManager.client
          .from('invoice_payments')
          .select(
            'id, amount, paid_at, payment_method, student_invoices!inner(center_id)',
          )
          .eq('student_invoices.center_id', centerId)
          .gte('paid_at', start.toIso8601String())
          .lte('paid_at', end.toIso8601String());

      final List<dynamic> payments = response;
      double totalRevenue = 0;
      final byMethod = <String, double>{};

      for (var p in payments) {
        final amount = (p['amount'] as num).toDouble();
        totalRevenue += amount;

        final method = p['payment_method'] as String? ?? 'cash';
        byMethod[method] = (byMethod[method] ?? 0) + amount;
      }

      return {
        'totalRevenue': totalRevenue,
        'count': payments.length,
        'byMethod': byMethod,
      };
    } catch (e) {
      rethrow;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Teacher Salary Reports
  // ═══════════════════════════════════════════════════════════════════════════

  Future<Map<String, dynamic>> getTeacherSalaryReport(
    String centerId,
    DateTime month,
  ) async {
    final monthStr = '${month.year}-${month.month.toString().padLeft(2, '0')}';

    try {
      // Fetch teacher salaries for the given month
      final response = await SupabaseClientManager.client
          .from('teacher_salaries')
          .select('''
            id, 
            total_salary, 
            status,
            teacher:teachers(id, users(full_name)),
            items:teacher_salary_items(amount, item_type, description)
          ''')
          .eq('center_id', centerId)
          .eq('month_year', monthStr);

      final List<dynamic> salaries = response;

      double totalSalaries = 0;
      int approvedCount = 0;
      int pendingCount = 0;

      for (var salary in salaries) {
        totalSalaries += (salary['total_salary'] as num?)?.toDouble() ?? 0;
        if (salary['status'] == 'approved') {
          approvedCount++;
        } else if (salary['status'] == 'pending')
          pendingCount++;
      }

      return {
        'totalSalaries': totalSalaries,
        'teacherCount': salaries.length,
        'approved': approvedCount,
        'pending': pendingCount,
        'salaries': salaries
            .map(
              (s) => {
                'teacherName':
                    s['teacher']?['users']?['full_name'] ?? 'Unknown',
                'amount': s['total_salary'],
                'status': s['status'],
              },
            )
            .toList(),
      };
    } catch (e) {
      debugPrint('Error fetching teacher salary report: $e');
      rethrow;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Group Statistics Reports
  // ═══════════════════════════════════════════════════════════════════════════

  Future<Map<String, dynamic>> getGroupsReport(String centerId) async {
    try {
      // Fetch all groups with student counts
      final response = await SupabaseClientManager.client
          .from('groups')
          .select('''
            id, 
            group_name, 
            capacity,
            monthly_fee,
            course:courses(name),
            teacher:teachers(users(full_name))
          ''')
          .eq('center_id', centerId)
          .isFilter('deleted_at', null);

      final List<dynamic> groups = response;

      // For each group, get student count
      final groupsWithCounts = <Map<String, dynamic>>[];

      for (var group in groups) {
        final groupId = group['id'];
        final enrollmentCount = await SupabaseClientManager.client
            .from('student_group_enrollments')
            .select('id')
            .eq('group_id', groupId)
            .eq('status', 'active')
            .count(CountOption.exact);

        groupsWithCounts.add({
          'name': group['group_name'],
          'subject': group['course']?['name'] ?? 'Unknown',
          'teacher': group['teacher']?['users']?['full_name'] ?? 'Unassigned',
          'capacity': group['capacity'],
          'enrolled': enrollmentCount.count,
          'monthlyFee': group['monthly_fee'],
        });
      }

      return {'totalGroups': groups.length, 'groups': groupsWithCounts};
    } catch (e) {
      debugPrint('Error fetching groups report: $e');
      rethrow;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Students Report
  // ═══════════════════════════════════════════════════════════════════════════

  Future<List<Student>> getStudentsReport({
    required String centerId,
    String? gradeLevel,
    StudentStatus? status,
    String? searchQuery,
  }) async {
    try {
      // 1. Fetch Enrollments
      var query = SupabaseClientManager.client
          .from('student_enrollments')
          .select('''
            student_user_id,
            student_id,
            status,
            enrolled_at,
            grade_level
          ''')
          .eq('center_id', centerId)
          .isFilter('deleted_at', null);

      if (status != null) {
        query = query.eq('status', _mapStudentStatusToEnrollment(status));
      }

      final enrollments = await query;
      final enrollmentList = enrollments as List;

      if (enrollmentList.isEmpty) return [];

      // 2. Fetch Users
      final userIds = enrollmentList
          .map((e) => e['student_user_id'] as String?)
          .where((id) => id != null)
          .toList();

      List<dynamic> users = [];
      if (userIds.isNotEmpty) {
        final idsFilter = '(${userIds.map((id) => '"$id"').join(',')})';
        users = await SupabaseClientManager.client
            .from('users')
            .select('id, full_name, email, phone, avatar_url')
            .filter('id', 'in', idsFilter);
      }

      // 3. Fetch Student Details
      final studentIds = enrollmentList
          .map((e) => e['student_id'] as String?)
          .where((id) => id != null)
          .toList();

      Map<String, dynamic> studentsMap = {};
      if (studentIds.isNotEmpty) {
        final idsFilter = '(${studentIds.map((id) => '"$id"').join(',')})';
        final studentsList = await SupabaseClientManager.client
            .from('students')
            .select('*')
            .filter('id', 'in', idsFilter);

        for (var s in studentsList) {
          studentsMap[s['id']] = s;
        }
      }

      // 4. Merge Data
      List<Student> students = [];
      for (var enrollment in enrollmentList) {
        final userId = enrollment['student_user_id'] as String?;
        final studentId = enrollment['student_id'] as String?;

        Map<String, dynamic>? userMap;
        if (userId != null && users.isNotEmpty) {
          try {
            userMap = users.firstWhere(
              (u) => u['id'] == userId,
              orElse: () => null,
            );
          } catch (_) {}
        }

        final studentMap = studentId != null ? studentsMap[studentId] : null;

        String name = 'Unknown Student';
        String phone = '';
        String? email;
        String? avatarUrl;

        if (userMap != null) {
          name = userMap['full_name'] ?? name;
          phone = userMap['phone'] ?? phone;
          email = userMap['email'];
          avatarUrl = userMap['avatar_url'];
        } else if (studentMap != null) {
          name = studentMap['full_name'] ?? name;
          phone = studentMap['phone'] ?? phone;
          email = studentMap['email'];
          avatarUrl = studentMap['avatar_url'];
        }

        if (name == 'Unknown Student' &&
            studentMap == null &&
            userMap == null) {
          continue;
        }

        students.add(
          Student(
            id: studentId ?? userId ?? '',
            name: name,
            phone: phone,
            email: email,
            imageUrl: avatarUrl,
            birthDate: studentMap != null && studentMap['birth_date'] != null
                ? DateTime.parse(studentMap['birth_date'])
                : DateTime.now(),
            address: studentMap?['address'] ?? '',
            stage: enrollment['grade_level'] ?? '',
            subjectIds: const [],
            status: _parseStudentStatus(enrollment['status']),
            gradeLevel: enrollment['grade_level'],
            createdAt: enrollment['enrolled_at'] != null
                ? DateTime.tryParse(enrollment['enrolled_at']) ?? DateTime.now()
                : DateTime.now(),
          ),
        );
      }

      // 5. Apply Local Filters
      if (searchQuery != null && searchQuery.isNotEmpty) {
        final query = searchQuery.toLowerCase();
        students = students
            .where(
              (s) =>
                  s.name.toLowerCase().contains(query) ||
                  (s.phone.toLowerCase().contains(query) ?? false),
            )
            .toList();
      }

      if (gradeLevel != null) {
        students = students.where((s) => s.gradeLevel == gradeLevel).toList();
      }

      // Sort by name
      students.sort((a, b) => a.name.compareTo(b.name));

      return students;
    } catch (e) {
      debugPrint('Error fetching students report: $e');
      rethrow;
    }
  }

  String _mapStudentStatusToEnrollment(StudentStatus status) {
    switch (status) {
      case StudentStatus.active:
        return 'accepted';
      case StudentStatus.suspended:
        return 'suspended';
      case StudentStatus.inactive:
        return 'rejected';
      default:
        return 'accepted';
    }
  }

  StudentStatus _parseStudentStatus(String? status) {
    switch (status) {
      case 'active':
        return StudentStatus.active;
      case 'inactive':
        return StudentStatus.inactive;
      case 'suspended':
        return StudentStatus.suspended;
      case 'overdue':
        return StudentStatus.overdue;
      default:
        return StudentStatus.active;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Audit Logs
  // ═══════════════════════════════════════════════════════════════════════════

  Future<List<Map<String, dynamic>>> getRecentAuditLogs(String centerId) async {
    try {
      final response = await SupabaseClientManager.client
          .from('audit_logs')
          .select('*, users(full_name)')
          .eq('center_id', centerId)
          .order('created_at', ascending: false)
          .limit(50);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error fetching audit logs: $e');
      return [];
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Profitability Reports
  // ═══════════════════════════════════════════════════════════════════════════

  Future<List<Map<String, dynamic>>> getStudentProfitabilityReport(
    String centerId,
  ) async {
    try {
      // Try to call RPC first
      try {
        final response = await SupabaseClientManager.client.rpc(
          'get_student_profitability',
          params: {'p_center_id': centerId},
        );
        return List<Map<String, dynamic>>.from(response);
      } catch (rpcError) {
        debugPrint(
          'RPC get_student_profitability failed: $rpcError. Fallback to local calculation.',
        );

        // Fallback: Fetch students and their payment stats locally (simplified)
        // This is a placeholder to prevent crash. Real implementation should use proper SQL/RPC.
        return [];
      }
    } catch (e) {
      debugPrint('Error fetching profitability report: $e');
      return [];
    }
  }
}
