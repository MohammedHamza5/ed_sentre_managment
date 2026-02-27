/// Course Pricing Models - EdSentre
/// نماذج التسعير الذكي
library;

import 'package:equatable/equatable.dart';

// ═══════════════════════════════════════════════════════════════════════════
// COURSE PRICE MODEL - نموذج سعر المادة
// ═══════════════════════════════════════════════════════════════════════════

/// نموذج سعر المادة (المادة + المدرس + المرحلة)
class CoursePrice extends Equatable {
  final String id;
  final String centerId;
  
  /// الثالوث المقدس
  final String subjectName;      // اسم المادة (مطلوب)
  final String? teacherId;       // المدرس (اختياري)
  final String? teacherName;     // اسم المدرس (من JOIN)
  final String? gradeLevel;      // المرحلة الدراسية (اختياري)
  
  /// التسعير
  final double sessionPrice;     // سعر الحصة
  final double? monthlyPrice;    // السعر الشهري
  final int sessionsPerMonth;    // عدد الحصص في الشهر
  
  /// معلومات إضافية
  final String? notes;
  final bool isActive;
  final DateTime? validFrom;
  final DateTime? validUntil;
  
  final DateTime createdAt;
  final DateTime updatedAt;
  
  const CoursePrice({
    required this.id,
    required this.centerId,
    required this.subjectName,
    this.teacherId,
    this.teacherName,
    this.gradeLevel,
    required this.sessionPrice,
    this.monthlyPrice,
    this.sessionsPerMonth = 8,
    this.notes,
    this.isActive = true,
    this.validFrom,
    this.validUntil,
    required this.createdAt,
    required this.updatedAt,
  });
  
  @override
  List<Object?> get props => [
    id, centerId, subjectName, teacherId, gradeLevel,
    sessionPrice, monthlyPrice, sessionsPerMonth,
  ];
  
  /// السعر الشهري المحسوب
  double get calculatedMonthlyPrice => 
      monthlyPrice ?? (sessionPrice * sessionsPerMonth);
  
  /// وصف السعر
  String get priceDescription {
    final parts = <String>[subjectName];
    if (teacherName != null) parts.add(teacherName!);
    if (gradeLevel != null) parts.add(gradeLevel!);
    return parts.join(' - ');
  }
  
  /// مستوى التحديد (1=أدق, 3=عام)
  int get specificityLevel {
    if (teacherId != null && gradeLevel != null) return 1;
    if (teacherId != null || gradeLevel != null) return 2;
    return 3;
  }
  
  /// هل السعر صالح الآن؟
  bool get isCurrentlyValid {
    if (!isActive) return false;
    final now = DateTime.now();
    if (validFrom != null && now.isBefore(validFrom!)) return false;
    if (validUntil != null && now.isAfter(validUntil!)) return false;
    return true;
  }
  
  factory CoursePrice.fromJson(Map<String, dynamic> json) {
    return CoursePrice(
      id: json['id'] as String? ?? '',
      centerId: json['center_id'] as String? ?? '',
      subjectName: json['subject_name'] as String? ?? '',
      teacherId: json['teacher_id'] as String?,
      teacherName: json['teacher_name'] as String?,
      gradeLevel: json['grade_level'] as String?,
      sessionPrice: (json['session_price'] as num?)?.toDouble() ?? 0.0,
      monthlyPrice: (json['monthly_price'] as num?)?.toDouble(),
      sessionsPerMonth: json['sessions_per_month'] as int? ?? 8,
      notes: json['notes'] as String?,
      isActive: json['is_active'] as bool? ?? true,
      validFrom: json['valid_from'] != null 
          ? DateTime.tryParse(json['valid_from'].toString()) 
          : null,
      validUntil: json['valid_until'] != null 
          ? DateTime.tryParse(json['valid_until'].toString()) 
          : null,
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(json['updated_at']?.toString() ?? '') ?? DateTime.now(),
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'center_id': centerId,
      'subject_name': subjectName,
      'teacher_id': teacherId,
      'grade_level': gradeLevel,
      'session_price': sessionPrice,
      'monthly_price': monthlyPrice,
      'sessions_per_month': sessionsPerMonth,
      'notes': notes,
      'is_active': isActive,
      'valid_from': validFrom?.toIso8601String().split('T')[0],
      'valid_until': validUntil?.toIso8601String().split('T')[0],
    };
  }
  
  /// للإنشاء/التحديث (بدون id و timestamps)
  Map<String, dynamic> toInsertJson() {
    return {
      'center_id': centerId,
      'subject_name': subjectName,
      'teacher_id': teacherId,
      'grade_level': gradeLevel,
      'session_price': sessionPrice,
      'monthly_price': monthlyPrice,
      'sessions_per_month': sessionsPerMonth,
      'notes': notes,
      'is_active': isActive,
    };
  }
  
  CoursePrice copyWith({
    String? subjectName,
    String? teacherId,
    String? teacherName,
    String? gradeLevel,
    double? sessionPrice,
    double? monthlyPrice,
    int? sessionsPerMonth,
    String? notes,
    bool? isActive,
  }) {
    return CoursePrice(
      id: id,
      centerId: centerId,
      subjectName: subjectName ?? this.subjectName,
      teacherId: teacherId ?? this.teacherId,
      teacherName: teacherName ?? this.teacherName,
      gradeLevel: gradeLevel ?? this.gradeLevel,
      sessionPrice: sessionPrice ?? this.sessionPrice,
      monthlyPrice: monthlyPrice ?? this.monthlyPrice,
      sessionsPerMonth: sessionsPerMonth ?? this.sessionsPerMonth,
      notes: notes ?? this.notes,
      isActive: isActive ?? this.isActive,
      validFrom: validFrom,
      validUntil: validUntil,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// SMART PRICE RESULT - نتيجة البحث عن السعر
// ═══════════════════════════════════════════════════════════════════════════

/// نتيجة البحث الذكي عن السعر
class SmartPriceResult {
  final String? priceId;
  final double sessionPrice;
  final double monthlyPrice;
  final int matchLevel;        // 1=أدق, 2=متوسط, 3=عام, 4=افتراضي
  final String matchDescription;
  
  const SmartPriceResult({
    this.priceId,
    required this.sessionPrice,
    required this.monthlyPrice,
    required this.matchLevel,
    required this.matchDescription,
  });
  
  factory SmartPriceResult.fromJson(Map<String, dynamic> json) {
    return SmartPriceResult(
      priceId: json['price_id'] as String?,
      sessionPrice: (json['session_price'] as num).toDouble(),
      monthlyPrice: (json['monthly_price'] as num).toDouble(),
      matchLevel: json['match_level'] as int,
      matchDescription: json['match_description'] as String,
    );
  }
  
  /// هل هذا سعر محدد أم افتراضي؟
  bool get isSpecificPrice => matchLevel <= 2;
  bool get isDefaultPrice => matchLevel >= 3;
  
  /// أيقونة حسب المستوى
  String get levelEmoji {
    switch (matchLevel) {
      case 1: return '🎯';  // أدق سعر
      case 2: return '📊';  // سعر متوسط
      case 3: return '📋';  // سعر عام
      default: return '⚙️'; // افتراضي
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// PRICE OVERRIDE - تجاوز السعر للمجموعة
// ═══════════════════════════════════════════════════════════════════════════

/// تجاوز السعر لمجموعة معينة
class PriceOverride {
  final double sessionPrice;
  final String? reason;
  final DateTime? validUntil;
  
  const PriceOverride({
    required this.sessionPrice,
    this.reason,
    this.validUntil,
  });
  
  factory PriceOverride.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return const PriceOverride(sessionPrice: 0);
    }
    return PriceOverride(
      sessionPrice: (json['session_price'] as num).toDouble(),
      reason: json['reason'] as String?,
      validUntil: json['valid_until'] != null 
          ? DateTime.parse(json['valid_until'] as String) 
          : null,
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'session_price': sessionPrice,
      if (reason != null) 'reason': reason,
      if (validUntil != null) 'valid_until': validUntil!.toIso8601String().split('T')[0],
    };
  }
  
  /// هل التجاوز صالح الآن؟
  bool get isValid {
    if (validUntil == null) return true;
    return DateTime.now().isBefore(validUntil!);
  }
  
  double get monthlyPrice => sessionPrice * 8;
}


