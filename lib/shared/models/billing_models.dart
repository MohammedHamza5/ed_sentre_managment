// ═══════════════════════════════════════════════════════════════════════════
// 🎯 نظام الاشتراكات والدفع الذكي - Models
// Smart Billing System Models
// ═══════════════════════════════════════════════════════════════════════════

/// نوع الدفع الأساسي للمركز
enum BillingType {
  monthly,      // شهري
  perSession,   // بالحصة
  mixed,        // مختلط
  disabled,     // معطّل
}

/// طريقة حساب الشهر
enum MonthlyPaymentMode {
  calendarMonth,  // شهر ميلادي (30 يوم)
  sessionCount,   // عدد حصص معين
}

/// حالة الدفع للطالب
enum PaymentWarningStatus {
  ok,       // كل شيء جيد
  grace,    // في فترة المهلة
  warning,  // تحذير - تجاوز المهلة
  blocked,  // ممنوع - تجاوز الحد الأقصى
}

/// إعدادات نظام الدفع للمركز
class BillingConfig {
  final BillingType billingType;
  final MonthlyPaymentMode monthlyPaymentMode;
  final int sessionsPerCycle;
  final bool allowMixedBilling;
  final int graceSessions;
  final int maxDebtSessions;
  final bool requirePrepayment;

  const BillingConfig({
    this.billingType = BillingType.monthly,
    this.monthlyPaymentMode = MonthlyPaymentMode.calendarMonth,
    this.sessionsPerCycle = 8,
    this.allowMixedBilling = false,
    this.graceSessions = 2,
    this.maxDebtSessions = 4,
    this.requirePrepayment = false,
  });

  factory BillingConfig.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const BillingConfig();
    
    return BillingConfig(
      billingType: _parseBillingType(json['billing_type']),
      monthlyPaymentMode: _parseMonthlyMode(json['monthly_payment_mode']),
      sessionsPerCycle: (json['sessions_per_cycle'] as int?) ?? 8,
      allowMixedBilling: (json['allow_mixed_billing'] as bool?) ?? false,
      graceSessions: (json['grace_sessions'] as int?) ?? 2,
      maxDebtSessions: (json['max_debt_sessions'] as int?) ?? 4,
      requirePrepayment: (json['require_prepayment'] as bool?) ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
    'billing_type': billingType.name == 'perSession' ? 'per_session' : billingType.name,
    'monthly_payment_mode': monthlyPaymentMode == MonthlyPaymentMode.calendarMonth 
        ? 'calendar_month' 
        : 'session_count',
    'sessions_per_cycle': sessionsPerCycle,
    'allow_mixed_billing': allowMixedBilling,
    'grace_sessions': graceSessions,
    'max_debt_sessions': maxDebtSessions,
    'require_prepayment': requirePrepayment,
  };

  static BillingType _parseBillingType(String? value) {
    switch (value) {
      case 'per_session': return BillingType.perSession;
      case 'mixed': return BillingType.mixed;
      case 'disabled': return BillingType.disabled;
      case 'monthly':
      default: return BillingType.monthly;
    }
  }

  static MonthlyPaymentMode _parseMonthlyMode(String? value) {
    switch (value) {
      case 'session_count': return MonthlyPaymentMode.sessionCount;
      case 'calendar_month':
      default: return MonthlyPaymentMode.calendarMonth;
    }
  }

  BillingConfig copyWith({
    BillingType? billingType,
    MonthlyPaymentMode? monthlyPaymentMode,
    int? sessionsPerCycle,
    bool? allowMixedBilling,
    int? graceSessions,
    int? maxDebtSessions,
    bool? requirePrepayment,
  }) {
    return BillingConfig(
      billingType: billingType ?? this.billingType,
      monthlyPaymentMode: monthlyPaymentMode ?? this.monthlyPaymentMode,
      sessionsPerCycle: sessionsPerCycle ?? this.sessionsPerCycle,
      allowMixedBilling: allowMixedBilling ?? this.allowMixedBilling,
      graceSessions: graceSessions ?? this.graceSessions,
      maxDebtSessions: maxDebtSessions ?? this.maxDebtSessions,
      requirePrepayment: requirePrepayment ?? this.requirePrepayment,
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Helper Methods for UI
  // ─────────────────────────────────────────────────────────────────────────

  String get billingTypeArabic {
    switch (billingType) {
      case BillingType.monthly: return 'شهري';
      case BillingType.perSession: return 'بالحصة';
      case BillingType.mixed: return 'مختلط';
      case BillingType.disabled: return 'معطّل';
    }
  }

  String get monthlyModeArabic {
    switch (monthlyPaymentMode) {
      case MonthlyPaymentMode.calendarMonth: return 'كل شهر كامل (30 يوم)';
      case MonthlyPaymentMode.sessionCount: return 'كل $sessionsPerCycle حصص';
    }
  }

  bool get isPerSession => billingType == BillingType.perSession;
  bool get isMonthly => billingType == BillingType.monthly;
  bool get isMixed => billingType == BillingType.mixed;
  bool get isDisabled => billingType == BillingType.disabled;
}

/// حالة الدفع للطالب في مجموعة معينة
class StudentBillingStatus {
  final String enrollmentId;
  final String studentId;
  final String groupId;
  final String groupName;
  final double monthlyFee;
  final BillingType effectiveBillingType;
  
  // للدفع بالحصة
  final int sessionsPurchased;
  final int sessionsAttended;
  final int sessionsDebt;
  final int sessionsRemaining;
  
  // للدفع الشهري
  final bool currentMonthPaid;
  final DateTime? paidUntil;
  
  // حالة التحذير
  final int graceSessions;
  final int maxDebtSessions;
  final PaymentWarningStatus paymentStatus;

  const StudentBillingStatus({
    required this.enrollmentId,
    required this.studentId,
    required this.groupId,
    required this.groupName,
    required this.monthlyFee,
    required this.effectiveBillingType,
    this.sessionsPurchased = 0,
    this.sessionsAttended = 0,
    this.sessionsDebt = 0,
    this.sessionsRemaining = 0,
    this.currentMonthPaid = false,
    this.paidUntil,
    this.graceSessions = 2,
    this.maxDebtSessions = 4,
    this.paymentStatus = PaymentWarningStatus.ok,
  });

  factory StudentBillingStatus.fromJson(Map<String, dynamic> json) {
    return StudentBillingStatus(
      enrollmentId: (json['enrollment_id'] ?? '').toString(),
      studentId: (json['student_id'] ?? '').toString(),
      groupId: (json['group_id'] ?? '').toString(),
      groupName: (json['group_name'] ?? '').toString(),
      monthlyFee: (json['monthly_fee'] as num?)?.toDouble() ?? 0,
      effectiveBillingType: BillingConfig._parseBillingType(json['effective_billing_type']),
      sessionsPurchased: (json['sessions_purchased'] as int?) ?? 0,
      sessionsAttended: (json['sessions_attended'] as int?) ?? 0,
      sessionsDebt: (json['sessions_debt'] as int?) ?? 0,
      sessionsRemaining: (json['sessions_remaining'] as int?) ?? 0,
      currentMonthPaid: (json['current_month_paid'] as bool?) ?? false,
      paidUntil: json['paid_until'] != null ? DateTime.tryParse(json['paid_until'].toString()) : null,
      graceSessions: (json['grace_sessions'] as int?) ?? 2,
      maxDebtSessions: (json['max_debt_sessions'] as int?) ?? 4,
      paymentStatus: _parsePaymentStatus(json['payment_status']),
    );
  }

  static PaymentWarningStatus _parsePaymentStatus(String? value) {
    switch (value) {
      case 'grace': return PaymentWarningStatus.grace;
      case 'warning': return PaymentWarningStatus.warning;
      case 'blocked': return PaymentWarningStatus.blocked;
      case 'ok':
      default: return PaymentWarningStatus.ok;
    }
  }

  bool get canAttend => paymentStatus != PaymentWarningStatus.blocked;
  bool get needsWarning => paymentStatus == PaymentWarningStatus.warning;
  bool get isInGrace => paymentStatus == PaymentWarningStatus.grace;
  bool get isBlocked => paymentStatus == PaymentWarningStatus.blocked;

  String get statusArabic {
    switch (paymentStatus) {
      case PaymentWarningStatus.ok: return 'جيد ✅';
      case PaymentWarningStatus.grace: return 'مهلة ⏳';
      case PaymentWarningStatus.warning: return 'تحذير ⚠️';
      case PaymentWarningStatus.blocked: return 'ممنوع 🚫';
    }
  }
}


