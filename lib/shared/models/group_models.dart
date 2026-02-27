/// Groups Models - EdSentre
/// نماذج بيانات المجموعات
library;

import 'package:equatable/equatable.dart';
import 'package:ed_sentre/shared/models/schedule_models.dart'; // Ensure correct path or use relative if in same folder

// ═══════════════════════════════════════════════════════════════════════════
// GROUP MODELS
// ═══════════════════════════════════════════════════════════════════════════

/// Group Status
enum GroupStatus {
  active, // قبول طلاب جدد
  full, // ممتلئة
  suspended, // موقوفة مؤقتاً
  archived, // مؤرشفة
}

/// Group Model
class Group extends Equatable {
  final String id;
  final String centerId;
  final String courseId;
  final String? teacherId;

  // Group Info
  final String groupName;
  final String? groupCode;
  final String? gradeLevel;
  final String? description;

  // Capacity
  final int maxStudents;
  final int currentStudents;

  // Schedule
  final int? dayOfWeek; // 0=السبت, 6=الجمعة
  final String? startTime; // HH:mm format
  final String? endTime;

  // Fees
  final double? monthlyFee;

  // Status
  final GroupStatus status;
  final bool isActive;

  // Related data (not in DB, populated by joins)
  final String? courseName;
  final String? teacherName;
  final int? scheduledSessions;

  // Metadata
  final DateTime createdAt;
  final DateTime updatedAt;

  // 🧠 GENIUS: Multiple Sessions per Group
  final List<ScheduleSession> sessions;

  const Group({
    required this.id,
    required this.centerId,
    required this.courseId,
    this.teacherId,
    required this.groupName,
    this.groupCode,
    this.gradeLevel,
    this.description,
    required this.maxStudents,
    required this.currentStudents,
    this.dayOfWeek,
    this.startTime,
    this.endTime,
    this.monthlyFee,
    required this.status,
    required this.isActive,
    this.courseName,
    this.teacherName,
    this.scheduledSessions,
    required this.createdAt,
    required this.updatedAt,
    this.sessions = const [], // Default empty list
  });

  @override
  List<Object?> get props => [
    id,
    centerId,
    courseId,
    teacherId,
    groupName,
    groupCode,
    gradeLevel,
    description,
    maxStudents,
    currentStudents,
    dayOfWeek,
    startTime,
    endTime,
    monthlyFee,
    status,
    isActive,
    courseName,
    teacherName,
    scheduledSessions,
    createdAt,
    updatedAt,
    sessions,
  ];

  // Computed properties
  int get availableSlots => maxStudents - currentStudents;
  bool get isFull => currentStudents >= maxStudents;
  double get occupancyRate =>
      maxStudents > 0 ? (currentStudents / maxStudents) * 100 : 0.0;

  String get dayName {
    // If sessions exist, use them. Otherwise fallback to legacy.
    if (sessions.isNotEmpty) {
      return sessions.map((s) => _dayNameFromInt(s.dayOfWeek)).join(' & ');
    }
    if (dayOfWeek == null) return 'غير محدد';
    return _dayNameFromInt(dayOfWeek!);
  }

  String _dayNameFromInt(int day) {
    const days = [
      'السبت',
      'الأحد',
      'الإثنين',
      'الثلاثاء',
      'الأربعاء',
      'الخميس',
      'الجمعة',
    ];
    if (day >= 0 && day < days.length) return days[day];
    return 'Unknown';
  }

  String get scheduleText {
    String formatTime(String? time) {
      if (time == null || time.isEmpty) return '';
      try {
        final parts = time.split(':');
        final hour = int.parse(parts[0]);
        final minute = int.parse(parts[1]);
        final period = hour >= 12 ? 'م' : 'ص';
        final h = hour > 12
            ? hour - 12
            : hour == 0
            ? 12
            : hour;
        return '$h:${minute.toString().padLeft(2, '0')} $period';
      } catch (_) {
        return time;
      }
    }

    if (sessions.isNotEmpty) {
      return sessions
          .map(
            (s) => '${_dayNameFromInt(s.dayOfWeek)} ${formatTime(s.startTime)}',
          )
          .join(' | ');
    }
    if (dayOfWeek == null || startTime == null || endTime == null) {
      return 'غير محدد';
    }
    return '$dayName ${formatTime(startTime)} - ${formatTime(endTime)}';
  }

  Group copyWith({
    String? id,
    String? centerId,
    String? courseId,
    String? teacherId,
    String? groupName,
    String? groupCode,
    String? gradeLevel,
    String? description,
    int? maxStudents,
    int? currentStudents,
    int? dayOfWeek,
    String? startTime,
    String? endTime,
    double? monthlyFee,
    GroupStatus? status,
    bool? isActive,
    String? courseName,
    String? teacherName,
    int? scheduledSessions,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<ScheduleSession>? sessions,
  }) {
    return Group(
      id: id ?? this.id,
      centerId: centerId ?? this.centerId,
      courseId: courseId ?? this.courseId,
      teacherId: teacherId ?? this.teacherId,
      groupName: groupName ?? this.groupName,
      groupCode: groupCode ?? this.groupCode,
      gradeLevel: gradeLevel ?? this.gradeLevel,
      description: description ?? this.description,
      maxStudents: maxStudents ?? this.maxStudents,
      currentStudents: currentStudents ?? this.currentStudents,
      dayOfWeek: dayOfWeek ?? this.dayOfWeek,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      monthlyFee: monthlyFee ?? this.monthlyFee,
      status: status ?? this.status,
      isActive: isActive ?? this.isActive,
      courseName: courseName ?? this.courseName,
      teacherName: teacherName ?? this.teacherName,
      scheduledSessions: scheduledSessions ?? this.scheduledSessions,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      sessions: sessions ?? this.sessions,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'center_id': centerId,
      'course_id': courseId,
      'teacher_id': teacherId,
      'group_name': groupName,
      'group_code': groupCode,
      'grade_level': gradeLevel,
      'description': description,
      'max_students': maxStudents,
      'current_students': currentStudents,
      'day_of_week': dayOfWeek,
      'start_time': startTime,
      'end_time': endTime,
      'monthly_fee': monthlyFee,
      'status': status.name,
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'course_name': courseName,
      'teacher_name': teacherName,
      'scheduled_sessions': scheduledSessions,
      // We should also serialize sessions if possible, or at least the fields we rely on.
      // Assuming ScheduleSession has toJson or we act carefully.
      // For now, names are the priority fix.
    };
  }

  factory Group.fromJson(Map<String, dynamic> json) {
    DateTime safeDate(dynamic v) {
      if (v == null) return DateTime.now();
      if (v is DateTime) return v;
      return DateTime.tryParse(v.toString()) ?? DateTime.now();
    }

    return Group(
      id: (json['id'] ?? '').toString(),
      centerId: (json['center_id'] ?? '').toString(),
      courseId: (json['course_id'] ?? '').toString(),
      teacherId: json['teacher_id']?.toString(),
      groupName: (json['group_name'] ?? '').toString(),
      groupCode: json['group_code']?.toString(),
      gradeLevel: json['grade_level']?.toString(),
      description: json['description']?.toString(),
      maxStudents: (json['max_students'] as num?)?.toInt() ?? 0,
      currentStudents: (json['current_students'] as num?)?.toInt() ?? 0,
      dayOfWeek: (json['day_of_week'] as num?)?.toInt(),
      startTime: json['start_time']?.toString(),
      endTime: json['end_time']?.toString(),
      monthlyFee: (json['monthly_fee'] as num?)?.toDouble(),
      status: _parseStatus(json['status']?.toString()),
      isActive: json['is_active'] ?? true,
      courseName: json['course_name']?.toString(),
      teacherName: json['teacher_name']?.toString(),
      scheduledSessions: (json['scheduled_sessions'] as num?)?.toInt(),
      createdAt: safeDate(json['created_at']),
      updatedAt: safeDate(json['updated_at']),
      sessions:
          (json['sessions'] as List?)?.cast<ScheduleSession>() ?? const [],
    );
  }

  static GroupStatus _parseStatus(String? status) {
    switch (status) {
      case 'active':
        return GroupStatus.active;
      case 'full':
        return GroupStatus.full;
      case 'suspended':
        return GroupStatus.suspended;
      case 'archived':
        return GroupStatus.archived;
      default:
        return GroupStatus.active;
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// STUDENT GROUP ENROLLMENT
// ═══════════════════════════════════════════════════════════════════════════

/// Enrollment Status
enum EnrollmentStatus {
  active, // نشط
  withdrawn, // منسحب
  transferred, // محوّل
  suspended, // موقوف
}

/// Student Group Enrollment Model
class StudentGroupEnrollment extends Equatable {
  final String id;
  final String studentId;
  final String groupId;
  final String centerId;

  // Enrollment Info
  final DateTime enrollmentDate;
  final DateTime? withdrawalDate;

  // Status
  final EnrollmentStatus status;

  // Transfer tracking
  final String? transferredFromGroupId;
  final String? transferredToGroupId;
  final DateTime? transferDate;

  // Notes
  final String? notes;
  final String? withdrawalReason;

  // Related data (populated by joins)
  final String? studentName;
  final String? groupName;

  // Metadata
  final DateTime createdAt;
  final DateTime updatedAt;

  const StudentGroupEnrollment({
    required this.id,
    required this.studentId,
    required this.groupId,
    required this.centerId,
    required this.enrollmentDate,
    this.withdrawalDate,
    required this.status,
    this.transferredFromGroupId,
    this.transferredToGroupId,
    this.transferDate,
    this.notes,
    this.withdrawalReason,
    this.studentName,
    this.groupName,
    required this.createdAt,
    required this.updatedAt,
  });

  @override
  List<Object?> get props => [
    id,
    studentId,
    groupId,
    centerId,
    enrollmentDate,
    withdrawalDate,
    status,
    transferredFromGroupId,
    transferredToGroupId,
    transferDate,
    notes,
    withdrawalReason,
    studentName,
    groupName,
    createdAt,
    updatedAt,
  ];

  StudentGroupEnrollment copyWith({
    String? id,
    String? studentId,
    String? groupId,
    String? centerId,
    DateTime? enrollmentDate,
    DateTime? withdrawalDate,
    EnrollmentStatus? status,
    String? transferredFromGroupId,
    String? transferredToGroupId,
    DateTime? transferDate,
    String? notes,
    String? withdrawalReason,
    String? studentName,
    String? groupName,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return StudentGroupEnrollment(
      id: id ?? this.id,
      studentId: studentId ?? this.studentId,
      groupId: groupId ?? this.groupId,
      centerId: centerId ?? this.centerId,
      enrollmentDate: enrollmentDate ?? this.enrollmentDate,
      withdrawalDate: withdrawalDate ?? this.withdrawalDate,
      status: status ?? this.status,
      transferredFromGroupId:
          transferredFromGroupId ?? this.transferredFromGroupId,
      transferredToGroupId: transferredToGroupId ?? this.transferredToGroupId,
      transferDate: transferDate ?? this.transferDate,
      notes: notes ?? this.notes,
      withdrawalReason: withdrawalReason ?? this.withdrawalReason,
      studentName: studentName ?? this.studentName,
      groupName: groupName ?? this.groupName,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'student_id': studentId,
      'group_id': groupId,
      'center_id': centerId,
      'enrollment_date': enrollmentDate.toIso8601String().split('T')[0],
      'withdrawal_date': withdrawalDate?.toIso8601String().split('T')[0],
      'status': status.name,
      'transferred_from_group_id': transferredFromGroupId,
      'transferred_to_group_id': transferredToGroupId,
      'transfer_date': transferDate?.toIso8601String().split('T')[0],
      'notes': notes,
      'withdrawal_reason': withdrawalReason,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory StudentGroupEnrollment.fromJson(Map<String, dynamic> json) {
    return StudentGroupEnrollment(
      id: json['id'] as String,
      studentId: json['student_id'] as String,
      groupId: json['group_id'] as String,
      centerId: json['center_id'] as String,
      enrollmentDate: DateTime.parse(json['enrollment_date'] as String),
      withdrawalDate: json['withdrawal_date'] != null
          ? DateTime.parse(json['withdrawal_date'] as String)
          : null,
      status: _parseEnrollmentStatus(json['status'] as String?),
      transferredFromGroupId: json['transferred_from_group_id'] as String?,
      transferredToGroupId: json['transferred_to_group_id'] as String?,
      transferDate: json['transfer_date'] != null
          ? DateTime.parse(json['transfer_date'] as String)
          : null,
      notes: json['notes'] as String?,
      withdrawalReason: json['withdrawal_reason'] as String?,
      studentName: json['student_name'] as String?,
      groupName: json['group_name'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  static EnrollmentStatus _parseEnrollmentStatus(String? status) {
    switch (status) {
      case 'active':
        return EnrollmentStatus.active;
      case 'withdrawn':
        return EnrollmentStatus.withdrawn;
      case 'transferred':
        return EnrollmentStatus.transferred;
      case 'suspended':
        return EnrollmentStatus.suspended;
      default:
        return EnrollmentStatus.active;
    }
  }
}
