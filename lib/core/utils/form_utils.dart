/// Utility functions for form handling
/// دوال مساعدة للتعامل مع النماذج
library;

import '../constants/educational_consts.dart';

class FormUtils {
  /// List of educational stages
  static List<String> get stages => EducationalStages.allGrades;

  /// Format phone number for display
  static String formatPhone(String phone) {
    if (phone.isEmpty) return '';

    // Remove all non-digit characters
    final digits = phone.replaceAll(RegExp(r'\D'), '');

    // Format as +966 50 000 0000
    // Format safely based on length
    if (digits.length >= 12) {
      return '+${digits.substring(0, 3)} ${digits.substring(3, 5)} ${digits.substring(5, 8)} ${digits.substring(8, 12)}';
    } else if (digits.length >= 9) {
      // Simple formatting for shorter numbers
      return '${digits.substring(0, 3)} ${digits.substring(3)}';
    }

    return phone;
  }

  /// Calculate time ago from a date
  static String timeAgo(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 365) {
      return '${(difference.inDays / 365).floor()} سنة';
    } else if (difference.inDays > 30) {
      return '${(difference.inDays / 30).floor()} شهر';
    } else if (difference.inDays > 0) {
      return '${difference.inDays} يوم';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} ساعة';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} دقيقة';
    } else {
      return 'الآن';
    }
  }
}
