/// Enhanced Payment Models for EdSentre
/// نماذج المدفوعات المحسّنة
library;

import 'package:equatable/equatable.dart';
import 'models.dart';

// ═══════════════════════════════════════════════════════════════════════════
// Payment Item Type - نوع بند الدفع
// ═══════════════════════════════════════════════════════════════════════════

enum PaymentItemType {
  session,      // حصة
  monthlySubscription, // اشتراك شهري
  materials,    // مواد/ملزمات
  books,        // كتب
  registration, // رسوم تسجيل
  other;        // أخرى

  String get arabicName {
    switch (this) {
      case PaymentItemType.session:
        return 'حصة';
      case PaymentItemType.monthlySubscription:
        return 'اشتراك شهري';
      case PaymentItemType.materials:
        return 'ملزمات';
      case PaymentItemType.books:
        return 'كتب';
      case PaymentItemType.registration:
        return 'رسوم تسجيل';
      case PaymentItemType.other:
        return 'أخرى';
    }
  }

  String get icon {
    switch (this) {
      case PaymentItemType.session:
        return '📝';
      case PaymentItemType.monthlySubscription:
        return '📅';
      case PaymentItemType.materials:
        return '📄';
      case PaymentItemType.books:
        return '📖';
      case PaymentItemType.registration:
        return '✍️';
      case PaymentItemType.other:
        return '💰';
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Payment Item - بند الدفعة
// ═══════════════════════════════════════════════════════════════════════════

class PaymentItem extends Equatable {
  final String id;
  final String paymentId;
  final PaymentItemType itemType;
  final String? teacherId; // New: Link to teacher
  final String? relatedEntityId; // New: Session ID, Group ID, etc.
  final String? relatedEntityType; // New: 'session', 'month', etc.
  final DateTime? coverageDate; // New: Which month/session date
  
  // Missing fields restored
  final String? subjectId;
  final String? subjectName;
  final String? groupId;
  final double amount;
  final String? description;
  final DateTime createdAt;

  const PaymentItem({
    required this.id,
    required this.paymentId,
    required this.itemType,
    this.subjectId,
    this.subjectName,
    this.groupId,
    this.teacherId, // New
    this.relatedEntityId, // New
    this.relatedEntityType, // New
    this.coverageDate, // New
    required this.amount,
    this.description,
    required this.createdAt,
  });

  @override
  List<Object?> get props => [
        id,
        paymentId,
        itemType,
        subjectId,
        teacherId, // New
        amount,
      ];

  PaymentItem copyWith({
    String? id,
    String? paymentId,
    PaymentItemType? itemType,
    String? subjectId,
    String? subjectName,
    String? groupId,
    String? teacherId, // New
    String? relatedEntityId, // New
    String? relatedEntityType, // New
    DateTime? coverageDate, // New
    double? amount,
    String? description,
    DateTime? createdAt,
  }) {
    return PaymentItem(
      id: id ?? this.id,
      paymentId: paymentId ?? this.paymentId,
      itemType: itemType ?? this.itemType,
      subjectId: subjectId ?? this.subjectId,
      subjectName: subjectName ?? this.subjectName,
      groupId: groupId ?? this.groupId,
      teacherId: teacherId ?? this.teacherId,
      relatedEntityId: relatedEntityId ?? this.relatedEntityId,
      relatedEntityType: relatedEntityType ?? this.relatedEntityType,
      coverageDate: coverageDate ?? this.coverageDate,
      amount: amount ?? this.amount,
      description: description ?? this.description,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  factory PaymentItem.empty() {
    return PaymentItem(
      id: '',
      paymentId: '',
      itemType: PaymentItemType.session,
      amount: 0.0,
      createdAt: DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    String typeStr;
    switch (itemType) {
      case PaymentItemType.monthlySubscription:
        typeStr = 'monthly_subscription';
        break;
      default:
        typeStr = itemType.name;
    }
    
    return {
      'id': id,
      'payment_id': paymentId,
      'item_type': typeStr,
      'subject_id': subjectId,
      'group_id': groupId,
      'amount': amount,
      'description': description,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory PaymentItem.fromJson(Map<String, dynamic> json) {
    PaymentItemType type;
    final typeStr = json['item_type'] as String?;
    
    if (typeStr == 'monthly_subscription') {
      type = PaymentItemType.monthlySubscription;
    } else {
      type = PaymentItemType.values.firstWhere(
        (e) => e.name == typeStr,
        orElse: () {
          // Backward compatibility for 'tuition' -> 'session'
          if (typeStr == 'tuition') return PaymentItemType.session;
          return PaymentItemType.other;
        },
      );
    }

    return PaymentItem(
      id: json['id'] as String,
      paymentId: json['payment_id'] as String,
      itemType: type,
      subjectId: json['subject_id'] as String?,
      subjectName: json['subject_name'] as String?,
      groupId: json['group_id'] as String?,
      amount: (json['amount'] as num).toDouble(),
      description: json['description'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Payment Details - تفاصيل الدفعة الكاملة
// ═══════════════════════════════════════════════════════════════════════════

class PaymentDetails extends Equatable {
  final Payment payment;
  final List<PaymentItem> items;

  const PaymentDetails({
    required this.payment,
    required this.items,
  });

  double get totalAmount => payment.amount;
  double get paidAmount => payment.paidAmount;
  double get remainingAmount => totalAmount - paidAmount;
  bool get isFullyPaid => remainingAmount <= 0;
  bool get isOverdue => payment.dueDate != null && 
                        DateTime.now().isAfter(payment.dueDate!) &&
                        !isFullyPaid;

  // Group items by type for better display
  Map<PaymentItemType, List<PaymentItem>> get itemsByType {
    final Map<PaymentItemType, List<PaymentItem>> grouped = {};
    for (final item in items) {
      grouped.putIfAbsent(item.itemType, () => []).add(item);
    }
    return grouped;
  }

  // Total amount per type
  Map<PaymentItemType, double> get amountByType {
    final Map<PaymentItemType, double> amounts = {};
    for (final item in items) {
      amounts.update(
        item.itemType,
        (value) => value + item.amount,
        ifAbsent: () => item.amount,
      );
    }
    return amounts;
  }

  @override
  List<Object?> get props => [payment, items];

  PaymentDetails copyWith({
    Payment? payment,
    List<PaymentItem>? items,
  }) {
    return PaymentDetails(
      payment: payment ?? this.payment,
      items: items ?? this.items,
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Monthly Revenue - الإيرادات الشهرية
// ═══════════════════════════════════════════════════════════════════════════

class MonthlyRevenue extends Equatable {
  final String id;
  final String centerId;
  final String monthYear; // YYYY-MM
  final double tuitionRevenue;
  final double materialsRevenue;
  final double booksRevenue;
  final double registrationRevenue;
  final double otherRevenue;
  final double totalRevenue;
  final int totalStudents;
  final int totalPayments;
  final double averagePayment;
  final DateTime createdAt;
  final DateTime updatedAt;

  const MonthlyRevenue({
    required this.id,
    required this.centerId,
    required this.monthYear,
    required this.tuitionRevenue,
    required this.materialsRevenue,
    required this.booksRevenue,
    required this.registrationRevenue,
    required this.otherRevenue,
    required this.totalRevenue,
    required this.totalStudents,
    required this.totalPayments,
    required this.averagePayment,
    required this.createdAt,
    required this.updatedAt,
  });

  @override
  List<Object?> get props => [id, monthYear, totalRevenue];

  // Revenue breakdown as percentages
  Map<PaymentItemType, double> get revenuePercentages {
    if (totalRevenue == 0) return {};
    
    return {
      PaymentItemType.session: (tuitionRevenue / totalRevenue) * 100,
      PaymentItemType.monthlySubscription: 0.0, // Not tracked separately
      PaymentItemType.materials: (materialsRevenue / totalRevenue) * 100,
      PaymentItemType.books: (booksRevenue / totalRevenue) * 100,
      PaymentItemType.registration: (registrationRevenue / totalRevenue) * 100,
      PaymentItemType.other: (otherRevenue / totalRevenue) * 100,
    };
  }

  // Get revenue for specific type
  double getRevenueForType(PaymentItemType type) {
    switch (type) {
      case PaymentItemType.session:
      case PaymentItemType.monthlySubscription:
        return tuitionRevenue;
      case PaymentItemType.materials:
        return materialsRevenue;
      case PaymentItemType.books:
        return booksRevenue;
      case PaymentItemType.registration:
        return registrationRevenue;
      case PaymentItemType.other:
        return otherRevenue;
    }
  }

  factory MonthlyRevenue.fromJson(Map<String, dynamic> json) {
    return MonthlyRevenue(
      id: json['id'] as String,
      centerId: json['center_id'] as String,
      monthYear: json['month_year'] as String,
      tuitionRevenue: (json['tuition_revenue'] as num?)?.toDouble() ?? 0.0,
      materialsRevenue: (json['materials_revenue'] as num?)?.toDouble() ?? 0.0,
      booksRevenue: (json['books_revenue'] as num?)?.toDouble() ?? 0.0,
      registrationRevenue: (json['registration_revenue'] as num?)?.toDouble() ?? 0.0,
      otherRevenue: (json['other_revenue'] as num?)?.toDouble() ?? 0.0,
      totalRevenue: (json['total_revenue'] as num?)?.toDouble() ?? 0.0,
      totalStudents: (json['total_students'] as int?) ?? 0,
      totalPayments: (json['total_payments'] as int?) ?? 0,
      averagePayment: (json['average_payment'] as num?)?.toDouble() ?? 0.0,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'center_id': centerId,
      'month_year': monthYear,
      'tuition_revenue': tuitionRevenue,
      'materials_revenue': materialsRevenue,
      'books_revenue': booksRevenue,
      'registration_revenue': registrationRevenue,
      'other_revenue': otherRevenue,
      'total_revenue': totalRevenue,
      'total_students': totalStudents,
      'total_payments': totalPayments,
      'average_payment': averagePayment,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Student Account Statement - كشف حساب الطالب
// ═══════════════════════════════════════════════════════════════════════════

class StudentAccountStatement extends Equatable {
  final Student student;
  final List<PaymentDetails> payments;
  final Map<String, SubjectFees> subjectFees; // subject_id -> fees info

  const StudentAccountStatement({
    required this.student,
    required this.payments,
    required this.subjectFees,
  });

  double get totalPaid {
    return payments.fold(0.0, (sum, p) => sum + p.paidAmount);
  }

  double get totalDue {
    return payments.fold(0.0, (sum, p) => sum + p.remainingAmount);
  }

  double get totalAmount {
    return payments.fold(0.0, (sum, p) => sum + p.totalAmount);
  }

  bool get hasOverduePayments {
    return payments.any((p) => p.isOverdue);
  }

  List<PaymentDetails> get overduePayments {
    return payments.where((p) => p.isOverdue).toList();
  }

  @override
  List<Object?> get props => [student, payments, subjectFees];
}

class SubjectFees extends Equatable {
  final String subjectId;
  final String subjectName;
  final double monthlyFee;
  final double totalPaid;
  final double totalDue;

  const SubjectFees({
    required this.subjectId,
    required this.subjectName,
    required this.monthlyFee,
    required this.totalPaid,
    required this.totalDue,
  });

  bool get isFullyPaid => totalDue <= 0;

  @override
  List<Object?> get props => [subjectId, totalPaid, totalDue];
}


