import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../monitoring/app_logger.dart';

/// Error Handler Utility
/// أداة معالجة الأخطاء
class ErrorHandler {
  /// Parse exception to user-friendly message
  static String getErrorMessage(dynamic error) {
    if (error is PostgrestException) {
      return error.message;
    } else if (error is AuthException) {
      return error.message;
    } else if (error is Exception) {
      return error.toString();
    } else {
      return 'حدث خطأ غير متوقع';
    }
  }

  static void handleError(
      dynamic error, {
        String? context,
        StackTrace? stackTrace,
      }) {
    final errorMessage = getErrorMessage(error);
    final errorContext = context != null ? ' in $context' : '';

    // تصحيح: استخدام named parameters
    AppLogger.error(
      'ERROR$errorContext: $errorMessage',
      error: error,
      stackTrace: stackTrace,
    );

    // Send to Sentry
    /*
    Sentry.captureException(
      error,
      stackTrace: stackTrace,
      withScope: (scope) {
        scope.setExtra('context', context ?? 'Unknown');
        scope.setTag('error_type', error.runtimeType.toString());
      },
    );
    */
  }

  /// Show error snackbar
  static void showErrorSnackBar(
      BuildContext context,
      dynamic error, {
        Duration duration = const Duration(seconds: 3),
      }) {
    final message = getErrorMessage(error);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: duration,
        action: SnackBarAction(
          label: 'حسناً',
          textColor: Colors.white,
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          },
        ),
      ),
    );
  }

  /// Show success snackbar
  static void showSuccessSnackBar(
      BuildContext context,
      String message, {
        Duration duration = const Duration(seconds: 2),
      }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: duration,
      ),
    );
  }

  /// Show info snackbar
  static void showInfoSnackBar(
      BuildContext context,
      String message, {
        Duration duration = const Duration(seconds: 2),
      }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.blue,
        duration: duration,
      ),
    );
  }
}

