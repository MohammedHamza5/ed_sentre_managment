/// Form validation utilities
/// أدوات التحقق من صحة النماذج
library;

class FormValidators {
  /// Validate email format
  static String? validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'البريد الإلكتروني مطلوب';
    }

    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(value)) {
      return 'البريد الإلكتروني غير صحيح';
    }

    return null;
  }

  /// Validate password strength
  static String? validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'كلمة المرور مطلوبة';
    }

    if (value.length < 6) {
      return 'كلمة المرور يجب أن تكون 6 أحرف على الأقل';
    }

    return null;
  }

  /// Validate phone number
  static String? validatePhone(String? value) {
    if (value == null || value.isEmpty) {
      return 'رقم الهاتف مطلوب';
    }

    // Simple phone validation (can be enhanced for specific country codes)
    final phoneRegex = RegExp(r'^[\+]?[0-9]{10,15}$');
    if (!phoneRegex.hasMatch(value)) {
      return 'رقم الهاتف غير صحيح';
    }

    return null;
  }

  /// Validate required field
  static String? validateRequired(String? value, String fieldName) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName مطلوب';
    }

    return null;
  }

  /// Validate numeric value
  static String? validateNumeric(String? value, String fieldName) {
    if (value == null || value.isEmpty) {
      return '$fieldName مطلوب';
    }

    final numRegex = RegExp(r'^[0-9]+$');
    if (!numRegex.hasMatch(value)) {
      return '$fieldName يجب أن يكون رقماً';
    }

    return null;
  }

  /// Validate decimal value
  static String? validateDecimal(String? value, String fieldName) {
    if (value == null || value.isEmpty) {
      return '$fieldName مطلوب';
    }

    final decimalRegex = RegExp(r'^[0-9]+(\.[0-9]+)?$');
    if (!decimalRegex.hasMatch(value)) {
      return '$fieldName يجب أن يكون رقماً عشرياً';
    }

    return null;
  }

  /// Validate date format
  static String? validateDate(String? value) {
    if (value == null || value.isEmpty) {
      return 'التاريخ مطلوب';
    }

    try {
      DateTime.parse(value);
      return null;
    } catch (e) {
      return 'التاريخ غير صحيح';
    }
  }

  /// Validate URL format
  static String? validateUrl(String? value) {
    if (value == null || value.isEmpty) {
      return 'الرابط مطلوب';
    }

    final urlRegex = RegExp(
      r'^https?:\/\/(?:www\.|(?!www))[a-zA-Z0-9][a-zA-Z0-9-]*[a-zA-Z0-9]\.(?:[^\s]{2,}|www\.[^\s]{2,})',
    );

    if (!urlRegex.hasMatch(value)) {
      return 'الرابط غير صحيح';
    }

    return null;
  }
}


