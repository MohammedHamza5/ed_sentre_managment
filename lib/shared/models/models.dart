/// EdSentre Domain Models
/// نماذج البيانات الأساسية
library;

import 'package:equatable/equatable.dart';

// Export enhanced payment models
export 'payment_models.dart';

// Export groups models
export 'group_models.dart';

// Export salary models
export 'salary_models.dart';

// Export billing models (نظام الاشتراكات والدفع)
export 'billing_models.dart';

// Export pricing models (نظام التسعير الذكي)
// Export pricing models (نظام التسعير الذكي)
export 'pricing_models.dart';

// Export auth models (أدوار وصلاحيات)
// Export auth models (أدوار وصلاحيات)
export 'auth_models.dart';

// Export schedule models
export 'schedule_models.dart';

// ═══════════════════════════════════════════════════════════════════════════
// STUDENT - نموذج الطالب
// ═══════════════════════════════════════════════════════════════════════════

/// حالة الطالب
enum StudentStatus { active, suspended, overdue, inactive }

/// نموذج الطالب
class Student extends Equatable {
  final String id;
  final String name;
  final String phone;
  final String? studentNumber;
  final String? email;
  final String? imageUrl;
  final DateTime birthDate;
  final String address;
  final String stage;
  final List<String> subjectIds;
  final String? parentId;
  final StudentStatus status;
  final DateTime createdAt;
  final DateTime? lastAttendance;
  final String? gradeLevel;

  const Student({
    required this.id,
    required this.name,
    required this.phone,
    this.studentNumber,
    this.email,
    this.imageUrl,
    required this.birthDate,
    required this.address,
    required this.stage,
    required this.subjectIds,
    this.parentId,
    required this.status,
    required this.createdAt,
    this.lastAttendance,
    this.gradeLevel,
  });

  @override
  List<Object?> get props => [id, name, phone, status];

  Student copyWith({
    String? name,
    String? phone,
    String? email,
    String? imageUrl,
    DateTime? birthDate,
    String? address,
    String? stage,
    List<String>? subjectIds,
    String? parentId,
    StudentStatus? status,
    DateTime? lastAttendance,
    String? gradeLevel,
  }) {
    return Student(
      id: id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      imageUrl: imageUrl ?? this.imageUrl,
      birthDate: birthDate ?? this.birthDate,
      address: address ?? this.address,
      stage: stage ?? this.stage,
      subjectIds: subjectIds ?? this.subjectIds,
      parentId: parentId ?? this.parentId,
      status: status ?? this.status,
      createdAt: createdAt,
      lastAttendance: lastAttendance ?? this.lastAttendance,
      gradeLevel: gradeLevel ?? this.gradeLevel,
    );
  }
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'student_code': studentNumber,
      'email': email,
      'image_url': imageUrl,
      'birth_date': birthDate.toIso8601String(),
      'address': address,
      'stage': stage,
      'subject_ids': subjectIds,
      'parent_id': parentId,
      'status': status.name,
      'created_at': createdAt.toIso8601String(),
      'last_attendance': lastAttendance?.toIso8601String(),
      'grade_level': gradeLevel,
    };
  }

  factory Student.fromJson(Map<String, dynamic> json) {
    // Helper for safe Date parsing
    DateTime? parseDate(dynamic v) {
      if (v == null) return null;
      if (v is DateTime) return v;
      try {
        return DateTime.parse(v.toString());
      } catch (_) {
        return null;
      }
    }

    // Helper for safe List parsing
    List<String> parseList(dynamic v) {
      if (v == null) return [];
      if (v is List) return v.map((e) => e.toString()).toList();
      return [];
    }

    return Student(
      id: (json['id'] ?? json['student_id'] ?? '').toString(),
      name: (json['name'] ?? json['full_name'] ?? '').toString(),
      phone: (json['phone'] ?? '').toString(),
      studentNumber: json['student_code'] as String? ?? json['studentNumber'] as String?,
      email: json['email'] as String?,
      imageUrl: json['image_url'] as String? ?? json['avatar_url'] as String?, // Supabase often uses avatar_url
      birthDate: parseDate(json['birth_date']) ?? DateTime(2000, 1, 1),
      address: (json['address'] ?? '').toString(),
      stage: (json['stage'] ?? json['grade_level'] ?? '').toString(),
      subjectIds: parseList(json['subject_ids'] ?? json['subjectIds']),
      parentId: json['parent_id'] as String? ?? json['guardian_id'] as String?,
      status: _parseStatus(json['status']),
      createdAt: parseDate(json['created_at']) ?? DateTime.now(),
      lastAttendance: parseDate(json['last_attendance']),
      gradeLevel: json['grade_level'] as String?,
    );
  }

  static StudentStatus _parseStatus(dynamic v) {
    if (v == null) return StudentStatus.active; // Default to active
    final statusStr = v.toString().toLowerCase();
    switch (statusStr) {
      case 'active':
      case 'accepted': // Supabase View compatibility
        return StudentStatus.active;
      case 'suspended':
        return StudentStatus.suspended;
      case 'overdue':
        return StudentStatus.overdue;
      case 'inactive':
      case 'rejected':
      default:
        return StudentStatus.inactive;
    }
  }
}
// ═══════════════════════════════════════════════════════════════════════════
// TEACHER - نموذج المعلم //
// ═══════════════════════════════════════════════════════════════════════════

enum SalaryType { fixed, percentage, perSession }

class Teacher extends Equatable {
  final String id;
  final String name;
  final String phone;
  final String? email;
  final String? imageUrl;
  final List<String> subjectIds;
  final SalaryType salaryType;
  final double salaryAmount;
  final bool isActive;
  final DateTime createdAt;
  final double rating;
  final int courseCount;
  final int studentCount;

  const Teacher({
    required this.id,
    required this.name,
    required this.phone,
    this.email,
    this.imageUrl,
    required this.subjectIds,
    required this.salaryType,
    required this.salaryAmount,
    required this.isActive,
    required this.createdAt,
    this.rating = 0.0,
    this.courseCount = 0,
    this.studentCount = 0,
  });

  @override
  List<Object?> get props => [id, name, phone, rating, salaryType, salaryAmount];

  Teacher copyWith({
    String? name,
    String? phone,
    String? email,
    String? imageUrl,
    List<String>? subjectIds,
    SalaryType? salaryType,
    double? salaryAmount,
    bool? isActive,
    double? rating,
    int? courseCount,
    int? studentCount,
  }) {
    return Teacher(
      id: id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      imageUrl: imageUrl ?? this.imageUrl,
      subjectIds: subjectIds ?? this.subjectIds,
      salaryType: salaryType ?? this.salaryType,
      salaryAmount: salaryAmount ?? this.salaryAmount,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt,
      rating: rating ?? this.rating,
      courseCount: courseCount ?? this.courseCount,
      studentCount: studentCount ?? this.studentCount,
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// SUBJECT - نموذج المادة
// ═══════════════════════════════════════════════════════════════════════════

class Subject extends Equatable {
  final String id;
  final String name;
  final String? description;
  final double monthlyFee;
  final List<String> teacherIds;
  final bool isActive;
  final int studentCount;
  final String? gradeLevel;

  const Subject({
    required this.id,
    required this.name,
    this.description,
    required this.monthlyFee,
    required this.teacherIds,
    required this.isActive,
    this.studentCount = 0,
    this.gradeLevel,
  });

  @override
  List<Object?> get props => [id, name, studentCount, gradeLevel];

  Subject copyWith({
    String? name,
    String? description,
    double? monthlyFee,
    List<String>? teacherIds,
    bool? isActive,
    int? studentCount,
    String? gradeLevel,
  }) {
    return Subject(
      id: id,
      name: name ?? this.name,
      description: description ?? this.description,
      monthlyFee: monthlyFee ?? this.monthlyFee,
      teacherIds: teacherIds ?? this.teacherIds,
      isActive: isActive ?? this.isActive,
      studentCount: studentCount ?? this.studentCount,
      gradeLevel: gradeLevel ?? this.gradeLevel,
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// ROOM - نموذج القاعة
// ═══════════════════════════════════════════════════════════════════════════

enum RoomStatus { available, occupied, maintenance }

class Room extends Equatable {
  final String id;
  final String number;
  final String name;
  final int capacity;
  final List<String> equipment;
  final RoomStatus status;

  const Room({
    required this.id,
    required this.number,
    required this.name,
    required this.capacity,
    required this.equipment,
    required this.status,
  });

  @override
  List<Object?> get props => [id, number, name];

  /// Create from JSON map
  factory Room.fromJson(Map<String, dynamic> json) {
    return Room(
      id: json['id'] ?? '',
      number: json['number']?.toString() ?? json['room_number']?.toString() ?? '',
      name: json['name'] ?? '',
      capacity: json['capacity'] ?? 0,
      equipment: (json['equipment'] as List?)?.map((e) => e.toString()).toList() ?? [],
      status: _parseRoomStatus(json['status']),
    );
  }

  static RoomStatus _parseRoomStatus(dynamic value) {
    switch (value?.toString()) {
      case 'occupied':
        return RoomStatus.occupied;
      case 'maintenance':
        return RoomStatus.maintenance;
      default:
        return RoomStatus.available;
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// PAYMENT - نموذج الدفعة
// ═══════════════════════════════════════════════════════════════════════════

enum PaymentMethod { cash, vodafoneCash, bankTransfer, instaPay }
enum PaymentStatus { paid, partial, pending, overdue }

enum ExpenseCategory { rent, utilities, salary, maintenance, supplies, other }

extension PaymentMethodExtension on PaymentMethod {
  String get arabicName {
    switch (this) {
      case PaymentMethod.cash:
        return 'نقدي';
      case PaymentMethod.vodafoneCash:
        return 'فودافون كاش';
      case PaymentMethod.bankTransfer:
        return 'تحويل بنكي';
      case PaymentMethod.instaPay:
        return 'إنستا باي';
    }
  }
}

class Payment extends Equatable {
  final String id;
  final String studentId;
  final String studentName;
  final double amount;
  final double paidAmount;
  final PaymentMethod method;
  final PaymentStatus status;
  final String month;
  final DateTime? dueDate;  // Made optional for backward compatibility
  final DateTime? paidDate;
  final String? notes;
  final String? receiptNumber;  // NEW: رقم الإيصال
  final String? monthYear;      // NEW: YYYY-MM format
  final bool isOverdue;         // NEW: متأخر؟

  const Payment({
    required this.id,
    required this.studentId,
    required this.studentName,
    required this.amount,
    required this.paidAmount,
    required this.method,
    required this.status,
    required this.month,
    this.dueDate,
    this.paidDate,
    this.notes,
    this.receiptNumber,
    this.monthYear,
    this.isOverdue = false,
  });

  @override
  List<Object?> get props => [id, studentId, month];

  double get remaining => amount - paidAmount;
  bool get isFullyPaid => paidAmount >= amount;

  Payment copyWith({
    String? id,
    String? studentId,
    String? studentName,
    double? amount,
    double? paidAmount,
    PaymentMethod? method,
    PaymentStatus? status,
    String? month,
    DateTime? dueDate,
    DateTime? paidDate,
    String? notes,
    String? receiptNumber,
    String? monthYear,
    bool? isOverdue,
  }) {
    return Payment(
      id: id ?? this.id,
      studentId: studentId ?? this.studentId,
      studentName: studentName ?? this.studentName,
      amount: amount ?? this.amount,
      paidAmount: paidAmount ?? this.paidAmount,
      method: method ?? this.method,
      status: status ?? this.status,
      month: month ?? this.month,
      dueDate: dueDate ?? this.dueDate,
      paidDate: paidDate ?? this.paidDate,
      notes: notes ?? this.notes,
      receiptNumber: receiptNumber ?? this.receiptNumber,
      monthYear: monthYear ?? this.monthYear,
      isOverdue: isOverdue ?? this.isOverdue,
    );
  }
}

class Expense extends Equatable {
  final String id;
  final String title;
  final double amount;
  final ExpenseCategory category;
  final DateTime date;
  final PaymentMethod method;
  final String? description;
  final DateTime createdAt;

  const Expense({
    required this.id,
    required this.title,
    required this.amount,
    required this.category,
    required this.date,
    required this.method,
    this.description,
    required this.createdAt,
  });

  Expense copyWith({
    String? id,
    String? title,
    double? amount,
    ExpenseCategory? category,
    DateTime? date,
    PaymentMethod? method,
    String? description,
    DateTime? createdAt,
  }) {
    return Expense(
      id: id ?? this.id,
      title: title ?? this.title,
      amount: amount ?? this.amount,
      category: category ?? this.category,
      date: date ?? this.date,
      method: method ?? this.method,
      description: description ?? this.description,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        title,
        amount,
        category,
        date,
        method,
        description,
        createdAt,
      ];
}

// Export schedule models


// ═══════════════════════════════════════════════════════════════════════════
// ATTENDANCE - نموذج الحضور
// ═══════════════════════════════════════════════════════════════════════════

enum AttendanceStatus { present, absent, late, excused }

class AttendanceRecord extends Equatable {
  final String id;
  final String studentId;
  final String studentName;
  final String? sessionId;
  final String? sessionName;
  final DateTime date;
  final AttendanceStatus status;
  final String? notes;
  final DateTime? checkInTime;
  final DateTime? checkOutTime;

  const AttendanceRecord({
    required this.id,
    required this.studentId,
    required this.studentName,
    this.sessionId,
    this.sessionName,
    required this.date,
    required this.status,
    this.notes,
    this.checkInTime,
    this.checkOutTime,
  });

  @override
  List<Object?> get props => [id, studentId, date, status];

  AttendanceRecord copyWith({
    String? studentName,
    String? sessionId,
    String? sessionName,
    DateTime? date,
    AttendanceStatus? status,
    String? notes,
    DateTime? checkInTime,
    DateTime? checkOutTime,
  }) {
    return AttendanceRecord(
      id: id,
      studentId: studentId,
      studentName: studentName ?? this.studentName,
      sessionId: sessionId ?? this.sessionId,
      sessionName: sessionName ?? this.sessionName,
      date: date ?? this.date,
      status: status ?? this.status,
      notes: notes ?? this.notes,
      checkInTime: checkInTime ?? this.checkInTime,
      checkOutTime: checkOutTime ?? this.checkOutTime,
    );
  }

  bool get isPresent => status == AttendanceStatus.present || status == AttendanceStatus.late;

  factory AttendanceRecord.empty() {
    return AttendanceRecord(
      id: '',
      studentId: '',
      studentName: '',
      date: DateTime.now(),
      status: AttendanceStatus.absent,
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// PARENT - نموذج ولي الأمر
// ═══════════════════════════════════════════════════════════════════════════

class Parent extends Equatable {
  final String id;
  final String name;
  final String phone;
  final String? email;
  final String relation;
  final String? occupation;

  const Parent({
    required this.id,
    required this.name,
    required this.phone,
    this.email,
    required this.relation,
    this.occupation,
  });

  @override
  List<Object?> get props => [id, name, phone];
}

// ═══════════════════════════════════════════════════════════════════════════
// NOTIFICATION - نموذج الإشعار
// ═══════════════════════════════════════════════════════════════════════════

enum NotificationType { payment, attendance, schedule, system, alert }

class AppNotification extends Equatable {
  final String id;
  final String title;
  final String body;
  final NotificationType type;
  final DateTime createdAt;
  final bool isRead;

  const AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    required this.createdAt,
    required this.isRead,
  });

  @override
  List<Object?> get props => [id, title, createdAt];
}

// ═══════════════════════════════════════════════════════════════════════════
// DASHBOARD STATS - إحصائيات لوحة التحكم
// ═══════════════════════════════════════════════════════════════════════════

class DashboardStats extends Equatable {
  final int totalStudents;
  final double totalStudentsChange;
  final int activeStudents;
  final int totalTeachers;
  final double totalTeachersChange;
  final int totalSubjects;
  final double todayRevenue;
  final double todayRevenueChange;
  final double monthlyRevenue;
  final int todaySessions;
  final int completedSessions;
  final double attendanceRate;
  final double attendanceRateChange;
  
  // Group Stats
  final int totalGroups;
  final int activeGroups;
  final int fullGroups;
  
  // Next Session
  final String? nextSessionTime;
  final String? nextSessionName;

  const DashboardStats({
    required this.totalStudents,
    this.totalStudentsChange = 0,
    required this.activeStudents,
    required this.totalTeachers,
    this.totalTeachersChange = 0,
    required this.totalSubjects,
    required this.todayRevenue,
    this.todayRevenueChange = 0,
    required this.monthlyRevenue,
    required this.todaySessions,
    required this.completedSessions,
    required this.attendanceRate,
    this.attendanceRateChange = 0,
    this.totalGroups = 0,
    this.activeGroups = 0,
    this.fullGroups = 0,
    this.nextSessionTime,
    this.nextSessionName,
  });

  @override
  List<Object?> get props => [
    totalStudents,
    totalTeachers,
    monthlyRevenue,
    totalStudentsChange,
    totalTeachersChange,
    todayRevenueChange,
    attendanceRateChange,
    nextSessionTime,
    nextSessionName,
  ];
}



