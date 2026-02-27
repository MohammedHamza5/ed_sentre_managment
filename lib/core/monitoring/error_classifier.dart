
/// ═══════════════════════════════════════════════════════════════════════════
/// lib/core/monitoring/error_classifier.dart
/// تصنيف الأخطاء لتحديد مصدرها بدقة
/// ═══════════════════════════════════════════════════════════════════════════
library;

import 'package:flutter/foundation.dart';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'app_logger.dart';

/// مصنف الأخطاء
class ErrorClassifier {

  /// تصنيف أي خطأ وتحديد مصدره
  static ErrorSource classifyError(dynamic error) {
    // Backend Errors (Supabase)
    if (error is AuthException) {
      return ErrorSource.backend;
    }

    if (error is PostgrestException) {
      return ErrorSource.backend;
    }

    if (error is StorageException) {
      return ErrorSource.backend;
    }

    // Network Errors
    if (error.toString().contains('SocketException') ||
        error.toString().contains('NetworkException') ||
        error.toString().contains('TimeoutException') ||
        error.toString().contains('Failed host lookup') ||
        error.toString().contains('Connection refused') ||
        error.toString().contains('No internet')) {
      return ErrorSource.network;
    }

    // Frontend Errors (Flutter)
    if (error is TypeError ||
        error is RangeError ||
        error is ArgumentError ||
        error is StateError ||
        error is FormatException) {
      return ErrorSource.frontend;
    }

    // تحليل النص للكشف عن المصدر
    final errorText = error.toString().toLowerCase();

    if (errorText.contains('supabase') ||
        errorText.contains('database') ||
        errorText.contains('rls') ||
        errorText.contains('policy') ||
        errorText.contains('auth') ||
        errorText.contains('jwt') ||
        errorText.contains('invalid login') ||
        errorText.contains('user not found')) {
      return ErrorSource.backend;
    }

    if (errorText.contains('widget') ||
        errorText.contains('context') ||
        errorText.contains('null') ||
        errorText.contains('type') ||
        errorText.contains('invalid') ||
        errorText.contains('unmounted')) {
      return ErrorSource.frontend;
    }

    return ErrorSource.unknown;
  }

  /// تسجيل خطأ مع تصنيف تلقائي
  static void logClassifiedError(
      String message,
      dynamic error, {
        StackTrace? stackTrace,
        Map<String, dynamic>? additionalData,
      }) {
    final source = classifyError(error);

    AppLogger.error(
      message,
      error: {
        'error': error.toString(),
        'classified_as': source.name,
        ...?additionalData,
      },
      stackTrace: stackTrace,
      source: source,
    );
  }

  /// توليد تقرير الأخطاء
  static String generateErrorReport() {
    final allLogs = AppLogger.getAllLogs();
    final errors = allLogs.where((log) =>
    log.level == LogLevel.error || log.level == LogLevel.critical
    ).toList();

    final backendErrors = errors.where((e) => e.errorSource == ErrorSource.backend).length;
    final frontendErrors = errors.where((e) => e.errorSource == ErrorSource.frontend).length;
    final networkErrors = errors.where((e) => e.errorSource == ErrorSource.network).length;
    final unknownErrors = errors.where((e) => e.errorSource == ErrorSource.unknown).length;

    final report = '''
═══════════════════════════════════════════════════════════════
🔍 تقرير تصنيف الأخطاء (Error Classification Report)
═══════════════════════════════════════════════════════════════
إجمالي الأخطاء: ${errors.length}
───────────────────────────────────────────────────────────────
📍 التصنيف حسب المصدر:
  🔴 Backend (Supabase):  $backendErrors (${_percentage(backendErrors, errors.length)}%)
  🔵 Frontend (Flutter):  $frontendErrors (${_percentage(frontendErrors, errors.length)}%)
  🟡 Network:             $networkErrors (${_percentage(networkErrors, errors.length)}%)
  ⚪ Unknown:             $unknownErrors (${_percentage(unknownErrors, errors.length)}%)
───────────────────────────────────────────────────────────────
💡 التوصيات:
${_generateRecommendations(backendErrors, frontendErrors, networkErrors)}
═══════════════════════════════════════════════════════════════
الوقت: ${DateTime.now()}
═══════════════════════════════════════════════════════════════
''';

    return report;
  }

  static double _percentage(int part, int total) {
    if (total == 0) return 0.0;
    return (part / total * 100).roundToDouble();
  }

  static String _generateRecommendations(int backend, int frontend, int network) {
    final recommendations = <String>[];

    if (backend > frontend && backend > network) {
      recommendations.add('  • المشكلة الرئيسية في Backend (Supabase)');
      recommendations.add('  • تحقق من: RLS Policies, Database Triggers, Auth Settings');
    }

    if (frontend > backend && frontend > network) {
      recommendations.add('  • المشكلة الرئيسية في Frontend (Flutter)');
      recommendations.add('  • تحقق من: Null Safety, State Management, Widget Lifecycle');
    }

    if (network > backend && network > frontend) {
      recommendations.add('  • المشكلة الرئيسية في Network');
      recommendations.add('  • تحقق من: Internet Connection, API Endpoints, Timeouts');
    }

    if (recommendations.isEmpty) {
      recommendations.add('  • لا توجد أخطاء كافية للتحليل');
    }

    return recommendations.join('\n');
  }

  /// طباعة تقرير الأخطاء
  static void printErrorReport() {
    debugPrint(generateErrorReport());
  }
}



