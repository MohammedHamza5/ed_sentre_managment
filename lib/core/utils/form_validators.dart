/// Form Validation Utilities
/// أدوات التحقق من صحة البيانات
library;

import '../constants/educational_consts.dart';

class FormValidators {
  FormValidators._();

  /// التحقق من الحقل المطلوب
  static String? required(String? value, [String? fieldName]) {
    if (value == null || value.trim().isEmpty) {
      return fieldName != null ? '$fieldName مطلوب' : 'هذا الحقل مطلوب';
    }
    return null;
  }

  /// التحقق من رقم الهاتف المصري
  static String? phone(String? value) {
    if (value == null || value.isEmpty) {
      return 'رقم الهاتف مطلوب';
    }
    // Egyptian phone: 01XXXXXXXXX (11 digits)
    final phoneRegex = RegExp(r'^01[0125][0-9]{8}$');
    if (!phoneRegex.hasMatch(value)) {
      return 'رقم الهاتف غير صالح (مثال: 01012345678)';
    }
    return null;
  }

  /// التحقق من البريد الإلكتروني
  static String? email(String? value) {
    if (value == null || value.isEmpty) {
      return null; // Email is optional
    }
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(value)) {
      return 'البريد الإلكتروني غير صالح';
    }
    return null;
  }

  /// التحقق من طول النص
  static String? minLength(String? value, int min, [String? fieldName]) {
    if (value == null || value.length < min) {
      return '${fieldName ?? 'النص'} يجب أن يكون $min أحرف على الأقل';
    }
    return null;
  }

  /// التحقق من الاسم
  static String? name(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'الاسم مطلوب';
    }
    if (value.length < 3) {
      return 'الاسم يجب أن يكون 3 أحرف على الأقل';
    }
    if (value.length > 100) {
      return 'الاسم طويل جداً';
    }
    return null;
  }

  /// التحقق من المبلغ
  static String? amount(String? value) {
    if (value == null || value.isEmpty) {
      return 'المبلغ مطلوب';
    }
    final amount = double.tryParse(value);
    if (amount == null) {
      return 'المبلغ غير صالح';
    }
    if (amount <= 0) {
      return 'المبلغ يجب أن يكون أكبر من صفر';
    }
    return null;
  }

  /// التحقق من التاريخ
  static String? date(DateTime? value) {
    if (value == null) {
      return 'التاريخ مطلوب';
    }
    return null;
  }

  /// دمج عدة validators
  static String? Function(String?) combine(
    List<String? Function(String?)> validators,
  ) {
    return (String? value) {
      for (final validator in validators) {
        final result = validator(value);
        if (result != null) {
          return result;
        }
      }
      return null;
    };
  }
}

/// Form Utilities
/// أدوات مساعدة للنماذج
class FormUtils {
  FormUtils._();

  /// تنسيق رقم الهاتف للعرض
  static String formatPhone(String phone) {
    if (phone.length == 11) {
      return '${phone.substring(0, 4)} ${phone.substring(4, 7)} ${phone.substring(7)}';
    }
    return phone;
  }

  /// تنسيق المبلغ
  static String formatCurrency(double amount) {
    if (amount >= 1000) {
      return '${(amount / 1000).toStringAsFixed(amount % 1000 == 0 ? 0 : 1)} ألف ج';
    }
    return '${amount.toStringAsFixed(amount % 1 == 0 ? 0 : 2)} ج';
  }

  /// تنسيق المبلغ الكامل
  static String formatFullCurrency(double amount) {
    final formatted = amount
        .toStringAsFixed(0)
        .replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]},',
        );
    return '$formatted ج';
  }

  /// تنسيق التاريخ
  static String formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  /// تنسيق التاريخ المختصر
  static String formatShortDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year % 100}';
  }

  /// الوقت المنقضي
  static String timeAgo(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inMinutes < 1) {
      return 'الآن';
    } else if (diff.inMinutes < 60) {
      return 'منذ ${diff.inMinutes} دقيقة';
    } else if (diff.inHours < 24) {
      return 'منذ ${diff.inHours} ساعة';
    } else if (diff.inDays < 7) {
      return 'منذ ${diff.inDays} يوم';
    } else {
      return formatDate(date);
    }
  }

  /// المراحل الدراسية
  static List<String> get stages => EducationalStages.allGrades;

  /// صلات القرابة
  static List<String> get relations => [
    'والد',
    'والدة',
    'أخ',
    'أخت',
    'عم',
    'خال',
    'أخرى',
  ];

  /// طرق الدفع
  static List<String> get paymentMethods => [
    'نقدي',
    'فودافون كاش',
    'تحويل بنكي',
    'انستاباي',
  ];

  /// أنواع الاشتراك
  static List<String> get subscriptionTypes => ['شهري', 'فصلي', 'سنوي'];
}
