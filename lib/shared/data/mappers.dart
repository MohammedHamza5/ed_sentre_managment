import 'package:flutter/foundation.dart';
// DTO/Mappers - UPDATED FOR NEW SCHEMA

import '../models/models.dart';

class _Parse {
  static DateTime? dt(dynamic v) {
    if (v == null) return null;
    try {
      return v is DateTime ? v : DateTime.parse(v.toString());
    } catch (_) {
      return null;
    }
  }

  static double d(dynamic v) {
    if (v == null) return 0.0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0.0;
  }
}

class StudentMapper {
  /// تحويل من Supabase إلى Student Model
  /// يدعم البنية الجديدة مع student_enrollments + users + students
  static Student fromSupabase(Map<String, dynamic> data) {
    // 1. Flatten Subject IDs from nested `student_courses` if present
    List<String> subjectIds = [];
    if (data['student_courses'] != null) {
      subjectIds = (data['student_courses'] as List)
          .map((e) => (e['course_id'] ?? e['courses']?['id'])?.toString())
          .whereType<String>()
          .toList();
    } else if (data['subjectIds'] != null) {
      subjectIds = (data['subjectIds'] as List)
          .map((e) => e.toString())
          .toList();
    }

    // 2. Prepare data for strict fromJson
    final preparedData = {
      ...data,
      'subject_ids': subjectIds,
      'grade_level': data['grade_level'] ?? data['stage'], // Normalizing keys
      'created_at':
          data['created_at'] ?? data['enrolled_at'], // Normalizing keys
    };

    return Student.fromJson(preparedData);
  }

  /// تحويل من Student Model إلى Supabase format (للإدراج/التحديث)
  /// NOTE: في البنية الجديدة، نحتاج تقسيم البيانات على ثلاث جداول
  static Map<String, dynamic> toSupabaseUser(Student s) {
    return {
      'full_name': s.name,
      'email': s.email,
      'phone': s.phone,
      'avatar_url': s.imageUrl,
      'updated_at': DateTime.now().toIso8601String(),
    };
  }

  static Map<String, dynamic> toSupabaseStudent(Student s) {
    return {
      'birth_date': s.birthDate.toIso8601String().split('T')[0],
      'address': s.address,
      'updated_at': DateTime.now().toIso8601String(),
    };
  }

  static Map<String, dynamic> toSupabaseEnrollment(
    Student s, {
    required String centerId,
  }) {
    return {
      'center_id': centerId,
      'status': _toEnrollmentStatus(s.status),
      'grade_level': s.stage,
      'updated_at': DateTime.now().toIso8601String(),
    };
  }

  /// تحويل enrollment status إلى StudentStatus
  static StudentStatus _parseStatus(dynamic v) {
    final statusStr = v.toString().toLowerCase();
    switch (statusStr) {
      case 'accepted':
      case 'active':
        return StudentStatus.active;
      case 'suspended':
        return StudentStatus.suspended;
      case 'overdue':
        return StudentStatus.overdue;
      case 'rejected':
      case 'inactive':
      case 'pending':
      default:
        return StudentStatus.inactive;
    }
  }

  /// تحويل StudentStatus إلى enrollment status
  static String _toEnrollmentStatus(StudentStatus status) {
    switch (status) {
      case StudentStatus.active:
        return 'accepted';
      case StudentStatus.suspended:
        return 'suspended';
      case StudentStatus.overdue:
        return 'suspended'; // أو 'accepted' حسب المنطق
      case StudentStatus.inactive:
        return 'rejected';
    }
  }
}

class SubjectMapper {
  static Subject fromSupabase(Map<String, dynamic> c) {
    // Use teacher_courses instead of teacher_enrollments
    final teachersRel = (c['teacher_courses'] as List?) ?? const [];
    final teacherIds = teachersRel
        .map((e) => (e['teacher_id'] ?? e['teachers']?['id'])?.toString())
        .whereType<String>()
        .toList();

    // Schema uses 'fee' not 'monthly_fee', and no 'is_active' column
    return Subject(
      id: (c['id'] ?? '').toString(),
      name: (c['name'] ?? '').toString(),
      description: c['description'] as String?,
      monthlyFee: _Parse.d(c['fee'] ?? c['monthly_fee']),
      teacherIds: teacherIds,
      isActive: true, // No is_active column in schema
      studentCount: (c['student_count'] ?? 0) as int,
      gradeLevel: c['grade_level']?.toString(), // Changed level to grade_level
    );
  }

  static Map<String, dynamic> toSupabase(
    Subject s, {
    required String centerId,
  }) {
    return {
      'id': s.id,
      'name': s.name,
      'code': _generateCode(s.name),
      'description': s.description,
      'fee': s.monthlyFee,
      'center_id': centerId,
      'updated_at': DateTime.now().toIso8601String(),
    };
  }

  static String _generateCode(String name) {
    final nameSlug = name.trim().toUpperCase().replaceAll(
      RegExp(r'[^A-Z0-9]'),
      '',
    );
    final shortName = nameSlug.length > 3 ? nameSlug.substring(0, 3) : nameSlug;
    return '$shortName-${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}';
  }
}

class ScheduleMapper {
  // يدعم مفاتيح schedules/classrooms وكذلك sessions/rooms للتوافق
  static ScheduleSession fromSupabase(Map<String, dynamic> r) {
    final rawStatus = r['status'];
    final statusStr = (rawStatus ?? 'scheduled').toString();
    final parsedStatus = _sessionStatus(statusStr);

    debugPrint('🔍 [ScheduleMapper] Parsing session ${r['id']}');
    debugPrint('   -> Raw status from DB: $rawStatus');
    debugPrint('   -> Status string to parse: $statusStr');
    debugPrint('   -> Parsed SessionStatus enum: $parsedStatus');

    // Helper to normalize time: "08:00:00" -> "08:00"
    String normalizeTime(String? time) {
      if (time == null || time.isEmpty) return '';
      final parts = time.split(':');
      if (parts.length >= 2) {
        return '${parts[0]}:${parts[1]}';
      }
      return time;
    }

    return ScheduleSession(
      id: (r['id'] ?? '').toString(),
      subjectId: (r['course_id'] ?? r['subject_id'] ?? '').toString(),
      subjectName: (r['courses']?['name'] ?? r['subject_name'] ?? '')
          .toString(),
      teacherId: (r['teacher_id'] ?? '').toString(),
      teacherName: (r['teachers']?['full_name'] ?? r['teacher_name'] ?? '')
          .toString(),
      roomId: (r['classroom_id'] ?? r['room_id'] ?? '').toString(),
      roomName:
          (r['classrooms']?['name'] ??
                  r['rooms']?['name'] ??
                  r['room_name'] ??
                  '')
              .toString(),
      dayOfWeek: _parseDayOfWeek(r['day_of_week']),
      startTime: normalizeTime((r['start_time'] ?? '').toString()),
      endTime: normalizeTime((r['end_time'] ?? '').toString()),
      status: parsedStatus,
      gradeLevel: (r['grade_level'] ?? '').toString(),
      groupId: r['group_id']?.toString(),
      groupName:
          r['groups']?['group_name']?.toString() ?? r['group_name']?.toString(),
    );
  }

  static Map<String, dynamic> toSupabase(
    ScheduleSession s, {
    required String centerId,
    String? groupId,
  }) {
    return {
      'course_id': s.subjectId,
      'teacher_id': s.teacherId,
      'classroom_id': s.roomId,
      'day_of_week': _dayToStr(s.dayOfWeek),
      'start_time': s.startTime,
      'end_time': s.endTime,
      'center_id': centerId,
      'grade_level': s.gradeLevel,
      'status': _statusToStr(s.status),
      if (groupId != null || s.groupId != null)
        'group_id': groupId ?? s.groupId,
    };
  }

  static String _statusToStr(SessionStatus status) {
    switch (status) {
      case SessionStatus.scheduled:
        return 'scheduled';
      case SessionStatus.ongoing:
        return 'ongoing';
      case SessionStatus.completed:
        return 'completed';
      case SessionStatus.cancelled:
        return 'cancelled';
    }
  }

  static int _parseDayOfWeek(dynamic v) {
    if (v is int) return v;
    final str = v.toString().toLowerCase();
    switch (str) {
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

  static String _dayToStr(int day) {
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

  static SessionStatus _sessionStatus(String v) {
    switch (v) {
      case 'ongoing':
        return SessionStatus.ongoing;
      case 'completed':
        return SessionStatus.completed;
      case 'cancelled':
        return SessionStatus.cancelled;
      case 'scheduled':
      default:
        return SessionStatus.scheduled;
    }
  }
}

class AttendanceMapper {
  static AttendanceRecord fromSupabase(Map<String, dynamic> a) {
    return AttendanceRecord(
      id: (a['id'] ?? '').toString(),
      studentId: (a['student_id'] ?? '').toString(),
      studentName: (a['students']?['full_name'] ?? a['student_name'] ?? '')
          .toString(),
      sessionId:
          (a['schedule_id'] ??
                  a['session_id'] ??
                  a['lesson_id'] ??
                  a['group_id'])
              ?.toString(),
      sessionName:
          (a['schedules']?['name'] ??
                  a['session_name'] ??
                  a['lessons']?['title'] ??
                  a['groups']?['group_name'] ??
                  a['groups']?['courses']?['name'])
              ?.toString(),
      date: _Parse.dt(a['date']) ?? DateTime.now(),
      status: _attendanceStatus((a['status'] ?? 'present').toString()),
      notes: a['notes'] as String?,
      checkInTime: _Parse.dt(a['check_in_time']),
      checkOutTime: _Parse.dt(a['check_out_time']),
    );
  }

  static Map<String, dynamic> toSupabase(
    AttendanceRecord r, {
    required String centerId,
  }) {
    return {
      'id': r.id,
      'student_id': r.studentId,
      'schedule_id': r.sessionId,
      'date': r.date.toIso8601String(),
      'status': r.status.name,
      'notes': r.notes,
      'check_in_time': r.checkInTime?.toIso8601String(),
      'check_out_time': r.checkOutTime?.toIso8601String(),
      'center_id': centerId,
      'updated_at': DateTime.now().toIso8601String(),
    };
  }

  static AttendanceStatus _attendanceStatus(String v) {
    switch (v) {
      case 'absent':
        return AttendanceStatus.absent;
      case 'late':
        return AttendanceStatus.late;
      case 'excused':
        return AttendanceStatus.excused;
      case 'present':
      default:
        return AttendanceStatus.present;
    }
  }
}

class PaymentMapper {
  /// Map from invoice_payments (with student_invoices join) to Payment model
  static Payment fromInvoicePayment(
    Map<String, dynamic> ip,
    Map<String, String> studentNames,
  ) {
    final invoice = ip['student_invoices'] as Map<String, dynamic>? ?? {};
    final studentId = (invoice['student_id'] ?? '').toString();
    final studentName = studentNames[studentId] ?? '';
    final amount = _Parse.d(ip['amount']);
    final methodStr = (ip['payment_method'] ?? 'cash').toString();
    final month = invoice['month'] ?? DateTime.now().month;
    final year = invoice['year'] ?? DateTime.now().year;

    const arabicMonths = [
      'يناير',
      'فبراير',
      'مارس',
      'أبريل',
      'مايو',
      'يونيو',
      'يوليو',
      'أغسطس',
      'سبتمبر',
      'أكتوبر',
      'نوفمبر',
      'ديسمبر',
    ];
    final monthName = (month is int && month >= 1 && month <= 12)
        ? arabicMonths[month - 1]
        : 'غير محدد';

    return Payment(
      id: (ip['id'] ?? '').toString(),
      studentId: studentId,
      studentName: studentName,
      amount: amount,
      paidAmount:
          amount, // invoice_payments entries are always actual paid amounts
      method: _paymentMethod(methodStr),
      status: PaymentStatus.paid,
      month: monthName,
      dueDate: _Parse.dt(ip['paid_at']),
      paidDate: _Parse.dt(ip['paid_at']),
      notes: ip['notes'] as String?,
      monthYear: '$year-${month.toString().padLeft(2, '0')}',
    );
  }

  static Payment fromSupabase(Map<String, dynamic> p) {
    final methodStr = (p['payment_method'] ?? p['method'] ?? 'cash').toString();
    final statusStr = (p['status'] ?? 'pending').toString();
    final amount = _Parse.d(p['amount']);

    // إذا كانت الحالة paid ولا يوجد paid_amount، استخدم amount
    double paidAmount = _Parse.d(p['paid_amount']);
    if (statusStr == 'paid' && paidAmount == 0 && amount > 0) {
      paidAmount = amount;
    }

    return Payment(
      id: (p['id'] ?? '').toString(),
      studentId: (p['student_id'] ?? '').toString(),
      studentName: (p['students']?['full_name'] ?? p['student_name'] ?? '')
          .toString(),
      amount: amount,
      paidAmount: paidAmount,
      method: _paymentMethod(methodStr),
      status: _paymentStatus(statusStr),
      month: (p['month'] ?? _getArabicMonthName(p['created_at'])).toString(),
      dueDate:
          _Parse.dt(p['due_date']) ??
          _Parse.dt(p['created_at']) ??
          DateTime.now(),
      paidDate:
          _Parse.dt(p['paid_date']) ??
          (statusStr == 'paid' ? _Parse.dt(p['created_at']) : null),
      notes: p['description'] as String? ?? p['notes'] as String?,
    );
  }

  static String _getArabicMonthName(dynamic createdAt) {
    final date = _Parse.dt(createdAt) ?? DateTime.now();
    const months = [
      'يناير',
      'فبراير',
      'مارس',
      'أبريل',
      'مايو',
      'يونيو',
      'يوليو',
      'أغسطس',
      'سبتمبر',
      'أكتوبر',
      'نوفمبر',
      'ديسمبر',
    ];
    return months[date.month - 1];
  }

  static Map<String, dynamic> toSupabase(
    Payment p, {
    required String centerId,
  }) {
    return {
      'id': p.id,
      'student_id': p.studentId,
      'amount': p.amount,
      'paid_amount': p.paidAmount,
      'payment_method': p.method.name,
      'status': p.status.name,
      'month': p.month,
      'due_date':
          p.dueDate?.toIso8601String() ?? DateTime.now().toIso8601String(),
      'paid_date': p.paidDate?.toIso8601String(),
      'description': p.notes,
      'center_id': centerId,
      'updated_at': DateTime.now().toIso8601String(),
    };
  }

  static PaymentMethod _paymentMethod(String v) {
    switch (v) {
      case 'vodafoneCash':
        return PaymentMethod.vodafoneCash;
      case 'bankTransfer':
        return PaymentMethod.bankTransfer;
      case 'instaPay':
        return PaymentMethod.instaPay;
      case 'cash':
      default:
        return PaymentMethod.cash;
    }
  }

  static PaymentStatus _paymentStatus(String v) {
    switch (v) {
      case 'paid':
        return PaymentStatus.paid;
      case 'partial':
        return PaymentStatus.partial;
      case 'overdue':
        return PaymentStatus.overdue;
      case 'pending':
      default:
        return PaymentStatus.pending;
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// TeacherMapper
// ═══════════════════════════════════════════════════════════════════════════

class TeacherMapper {
  static Teacher fromSupabase(Map<String, dynamic> t) {
    // Determine which level the teacher object is at (flexible for joins)
    final bool isEnrollmentLevel = t.containsKey('teachers');
    final Map<String, dynamic> teacherData = isEnrollmentLevel
        ? (t['teachers'] as Map<String, dynamic>? ?? t)
        : t;

    // FIX: Read from teacher_courses (not teacher_enrollments)
    // The query joins teacher_courses inside teachers node
    final teacherCourses =
        (teacherData['teacher_courses'] as List?) ?? const [];

    final subjectIds = teacherCourses
        .map((ct) => (ct['course_id'])?.toString())
        .whereType<String>()
        .toList();

    final userData =
        (teacherData['users'] as Map<String, dynamic>?) ??
        (t['users'] as Map<String, dynamic>?);

    return Teacher(
      id: (teacherData['id'] ?? '').toString(),
      name:
          (userData?['full_name'] ??
                  teacherData['full_name'] ??
                  teacherData['name'] ??
                  '')
              .toString(),
      phone: (userData?['phone'] ?? teacherData['phone'] ?? '').toString(),
      email: (userData?['email'] ?? teacherData['email']) as String?,
      imageUrl:
          (userData?['avatar_url'] ??
                  teacherData['profile_image'] ??
                  teacherData['avatar_url'])
              as String?,
      subjectIds: subjectIds,
      salaryType: _parseSalaryType(
        t['salary_type'] ?? teacherData['salary_type'],
      ),
      salaryAmount: (t['salary_amount'] ?? teacherData['salary_amount'] ?? 0.0)
          .toDouble(),
      isActive:
          (t['employment_status'] ??
              t['status'] ??
              teacherData['isActive'] ??
              'active') ==
          'active',
      createdAt: _Parse.dt(teacherData['created_at']) ?? DateTime.now(),
      rating: (teacherData['rating'] ?? 0.0).toDouble(),
      courseCount:
          (t['course_count'] ?? teacherData['courseCount'] ?? 0) as int,
      studentCount:
          (t['student_count'] ?? teacherData['studentCount'] ?? 0) as int,
    );
  }

  static SalaryType _parseSalaryType(dynamic value) {
    final strValue = value?.toString().toLowerCase();
    switch (strValue) {
      case 'percentage':
        return SalaryType.percentage;
      case 'persession':
      case 'per_session':
        return SalaryType.perSession;
      case 'fixed':
      default:
        return SalaryType.fixed;
    }
  }
}

class RoomMapper {
  static Room fromSupabase(Map<String, dynamic> r) {
    final statusStr = (r['status'] ?? 'available').toString();
    final equipmentRaw = r['equipment'];

    return Room(
      id: (r['id'] ?? '').toString(),
      number: (r['room_number'] ?? r['code'] ?? r['number'] ?? '').toString(),
      name: (r['name'] ?? '').toString(),
      capacity:
          (r['capacity'] as int?) ?? int.tryParse('${r['capacity']}') ?? 0,
      equipment: equipmentRaw is List
          ? equipmentRaw.map((e) => e.toString()).toList()
          : <String>[],
      status: _roomStatus(statusStr),
    );
  }

  static RoomStatus _roomStatus(String status) {
    switch (status) {
      case 'available':
        return RoomStatus.available;
      case 'occupied':
        return RoomStatus.occupied;
      case 'maintenance':
      default:
        return RoomStatus.maintenance;
    }
  }
}

class ExpenseMapper {
  static Expense fromSupabase(Map<String, dynamic> data) {
    return Expense(
      id: (data['id'] ?? '').toString(),
      // expense_type is the "title" in DB schema
      title: (data['expense_type'] ?? '').toString(),
      amount: _Parse.d(data['amount']),
      category: _parseCategory((data['category'] ?? 'other').toString()),
      date: _Parse.dt(data['date']) ?? DateTime.now(),
      method: PaymentMethod.cash, // No payment_method in expenses table
      description: data['description'] as String?,
      createdAt: _Parse.dt(data['created_at']) ?? DateTime.now(),
    );
  }

  static Map<String, dynamic> toSupabase(
    Expense e, {
    required String centerId,
  }) {
    // expense_type must be one of: fixed, educational, technical, promotional, administrative, other
    // Map our ExpenseCategory to a valid expense_type
    String expenseType;
    switch (e.category) {
      case ExpenseCategory.rent:
      case ExpenseCategory.utilities:
      case ExpenseCategory.maintenance:
        expenseType = 'fixed';
      case ExpenseCategory.salary:
        expenseType = 'administrative';
      case ExpenseCategory.supplies:
        expenseType = 'educational';
      case ExpenseCategory.other:
        expenseType = 'other';
    }

    return {
      'expense_type': expenseType,
      'amount': e.amount,
      'category': e.category.name,
      'date': e.date.toIso8601String().split(
        'T',
      )[0], // Only date part (YYYY-MM-DD)
      'description':
          '${e.title}${e.description != null && e.description!.isNotEmpty ? ' - ${e.description}' : ''}',
      'center_id': centerId,
    };
  }

  static ExpenseCategory _parseCategory(String v) {
    switch (v.toLowerCase()) {
      case 'rent':
        return ExpenseCategory.rent;
      case 'utilities':
        return ExpenseCategory.utilities;
      case 'salary':
        return ExpenseCategory.salary;
      case 'maintenance':
        return ExpenseCategory.maintenance;
      case 'supplies':
        return ExpenseCategory.supplies;
      case 'other':
      default:
        return ExpenseCategory.other;
    }
  }
}

class GroupMapper {
  static Group fromSupabase(Map<String, dynamic> data) {
    // Check for joins and extract names
    String? courseName = data['course_name'] as String?;
    if (courseName == null && data['courses'] != null) {
      courseName = data['courses']['name'] as String?;
    }

    String? teacherName = data['teacher_name'] as String?;
    if (teacherName == null && data['teachers'] != null) {
      final teacherData = data['teachers'];
      if (teacherData is Map) {
        teacherName =
            teacherData['full_name'] ?? teacherData['users']?['full_name'];
      }
    }

    // 🧠 GENIUS: Map Schedules to Sessions
    List<ScheduleSession> sessions = [];
    if (data['schedules'] != null && data['schedules'] is List) {
      sessions = (data['schedules'] as List)
          .map((s) => ScheduleMapper.fromSupabase(s as Map<String, dynamic>))
          .toList();
    }

    return Group.fromJson({
      ...data,
      'course_name': courseName,
      'teacher_name': teacherName,
      'sessions': sessions,
    });
  }

  static Map<String, dynamic> toSupabase(Group g) {
    // Remove computed/read-only fields that shouldn't be sent to DB
    final json = g.toJson();
    json.remove('id');
    json.remove('course_name');
    json.remove('teacher_name');
    json.remove('scheduled_sessions');
    return json;
  }
}
