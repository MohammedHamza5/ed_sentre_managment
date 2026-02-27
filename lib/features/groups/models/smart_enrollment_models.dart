/// Smart Enrollment Models - EdSentre
/// موديلات التسجيل الذكي للمجموعات
library;

import 'package:flutter/material.dart';

/// خيار طالب مع معلومات إضافية للتسجيل الذكي
class SmartStudentOption {
  final String id;
  final String name;
  final String? phone;
  final String? stage;
  final String? school;
  final int currentGroupsCount;
  final bool hasConflict;
  final String? conflictReason;
  final List<StudentGroupInfo> currentGroups;
  
  const SmartStudentOption({
    required this.id,
    required this.name,
    this.phone,
    this.stage,
    this.school,
    this.currentGroupsCount = 0,
    this.hasConflict = false,
    this.conflictReason,
    this.currentGroups = const [],
  });

  /// الحرف الأول من الاسم للـ Avatar
  String get initials => name.isNotEmpty ? name[0] : '?';
  
  /// لون الـ Avatar بناءً على الـ ID
  Color get avatarColor {
    const colors = [
      Color(0xFF6366F1), // Indigo
      Color(0xFF8B5CF6), // Purple
      Color(0xFFEC4899), // Pink
      Color(0xFF14B8A6), // Teal
      Color(0xFFF59E0B), // Amber
      Color(0xFF10B981), // Emerald
    ];
    return colors[id.hashCode.abs() % colors.length];
  }
}

/// معلومات مجموعة الطالب الحالية
class StudentGroupInfo {
  final String groupId;
  final String groupName;
  final String? courseName;
  final int? dayOfWeek;
  final String? startTime;
  final String? endTime;
  
  const StudentGroupInfo({
    required this.groupId,
    required this.groupName,
    this.courseName,
    this.dayOfWeek,
    this.startTime,
    this.endTime,
  });

  /// اسم اليوم بالعربية
  String get dayName {
    const days = ['السبت', 'الأحد', 'الإثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة'];
    if (dayOfWeek == null || dayOfWeek! < 0 || dayOfWeek! > 6) return '';
    return days[dayOfWeek!];
  }

  /// الوقت بشكل مختصر
  String get timeSlot {
    if (startTime == null) return '';
    return '$dayName $startTime';
  }
}

/// تعارض في الجدول
class ScheduleConflict {
  final ConflictType type;
  final String message;
  final String? groupName;
  final String? conflictingTime;
  
  const ScheduleConflict({
    required this.type,
    required this.message,
    this.groupName,
    this.conflictingTime,
  });

  /// أيقونة التعارض
  IconData get icon {
    switch (type) {
      case ConflictType.time:
        return Icons.schedule_rounded;
      case ConflictType.room:
        return Icons.meeting_room_rounded;
      case ConflictType.teacher:
        return Icons.person_rounded;
      case ConflictType.capacity:
        return Icons.group_rounded;
      case ConflictType.duplicate:
        return Icons.content_copy_rounded;
    }
  }

  /// لون التعارض
  Color get color {
    switch (type) {
      case ConflictType.time:
      case ConflictType.teacher:
      case ConflictType.room:
        return Colors.orange;
      case ConflictType.capacity:
      case ConflictType.duplicate:
        return Colors.red;
    }
  }
}

/// أنواع التعارضات
enum ConflictType {
  time,      // تعارض في الوقت
  room,      // تعارض في القاعة
  teacher,   // تعارض في المعلم
  capacity,  // المجموعة ممتلئة
  duplicate, // مسجل بالفعل
}

/// نتيجة التسجيل الجماعي
class BulkEnrollmentResult {
  final int successCount;
  final int failedCount;
  final List<EnrollmentError> errors;
  final List<String> successfulStudentIds;
  
  const BulkEnrollmentResult({
    required this.successCount,
    required this.failedCount,
    this.errors = const [],
    this.successfulStudentIds = const [],
  });

  /// هل كل التسجيلات نجحت؟
  bool get isFullSuccess => failedCount == 0 && successCount > 0;
  
  /// هل كل التسجيلات فشلت؟
  bool get isFullFailure => successCount == 0 && failedCount > 0;
  
  /// نسبة النجاح
  double get successRate {
    final total = successCount + failedCount;
    if (total == 0) return 0;
    return successCount / total;
  }
}

/// خطأ في التسجيل
class EnrollmentError {
  final String studentId;
  final String studentName;
  final String errorMessage;
  
  const EnrollmentError({
    required this.studentId,
    required this.studentName,
    required this.errorMessage,
  });
}

/// فلتر البحث عن الطلاب
enum StudentFilterType {
  all,        // كل الطلاب
  sameStage,  // نفس المرحلة
  sameCourse, // نفس المادة
  noGroups,   // بدون مجموعات
}

extension StudentFilterTypeExtension on StudentFilterType {
  String get arabicName {
    switch (this) {
      case StudentFilterType.all:
        return 'كل الطلاب';
      case StudentFilterType.sameStage:
        return 'نفس المرحلة';
      case StudentFilterType.sameCourse:
        return 'نفس المادة';
      case StudentFilterType.noGroups:
        return 'بدون مجموعات';
    }
  }

  IconData get icon {
    switch (this) {
      case StudentFilterType.all:
        return Icons.people_rounded;
      case StudentFilterType.sameStage:
        return Icons.school_rounded;
      case StudentFilterType.sameCourse:
        return Icons.menu_book_rounded;
      case StudentFilterType.noGroups:
        return Icons.person_add_rounded;
    }
  }
}

/// نتيجة التسجيل الذكي
class SmartEnrollmentResult {
  final int totalAttempted;
  final int successCount;
  final int failureCount;
  final List<String> errors;

  const SmartEnrollmentResult({
    required this.totalAttempted,
    required this.successCount,
    required this.failureCount,
    this.errors = const [],
  });

  /// هل كل التسجيلات نجحت؟
  bool get isFullSuccess => failureCount == 0 && successCount > 0;
  
  /// هل يوجد أخطاء؟
  bool get hasErrors => errors.isNotEmpty;
  
  /// نسبة النجاح
  double get successRate {
    if (totalAttempted == 0) return 0;
    return successCount / totalAttempted;
  }
}


