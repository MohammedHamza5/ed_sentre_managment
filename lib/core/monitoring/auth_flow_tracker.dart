import 'package:flutter/cupertino.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/monitoring/app_logger.dart';
import '../../../core/monitoring/journey_tracker.dart';
import '../../../core/monitoring/error_classifier.dart';
import '../auth/role_provider.dart';
import '../supabase/auth_service.dart';

class AuthFlowManager {
  static Future<AuthResult> completeSignUpFlow({
    required BuildContext context,
    required String email,
    required String password,
    required String fullName,
    required String phone,
  }) async {
    // بدء تتبع رحلة التسجيل
    JourneyTracker.startStep(
      JourneyStep.signupStarted,
      'بدء عملية إنشاء حساب جديد',
      data: {'email': email, 'full_name': fullName},
    );

    try {
      // المرحلة 1: التحقق من البيانات
      JourneyTracker.startStep(
        JourneyStep.signupDataValidation,
        'التحقق من صحة البيانات المدخلة',
      );

      if (!_isValidEmail(email)) {
        JourneyTracker.failStep(
          'البريد الإلكتروني غير صحيح',
          errorSource: ErrorSource.frontend,
        );
        return AuthResult.failure('البريد الإلكتروني غير صحيح');
      }

      JourneyTracker.completeStep();

      // المرحلة 2: إنشاء Auth
      JourneyTracker.startStep(
        JourneyStep.signupAuthCreation,
        'إنشاء حساب في Supabase Auth',
      );

      final result = await AuthService.signUp(
        email: email,
        password: password,
        fullName: fullName,
        phone: phone,
      );

      if (!result.success) {
        JourneyTracker.failStep(
          result.errorMessage ?? 'Unknown error',
          errorSource: ErrorSource.backend,
        );
        return result;
      }

      JourneyTracker.completeStep(additionalData: {'user_id': result.user?.id});

      // المرحلة 3: تهيئة Provider
      JourneyTracker.startStep(
        JourneyStep.signupProviderInit,
        'تهيئة RoleProvider',
      );

      if (!context.mounted) {
        JourneyTracker.failStep('Context غير متاح', errorSource: ErrorSource.frontend);
        return AuthResult.failure('حدث خطأ في التطبيق');
      }

      final roleProvider = context.read<RoleProvider>();
      await roleProvider.initialize(result.userData);

      JourneyTracker.completeStep();

      // اكتمال التسجيل
      JourneyTracker.startStep(
        JourneyStep.signupCompleted,
        'اكتملت عملية التسجيل بنجاح',
      );
      JourneyTracker.completeStep();

      return result;

    } catch (e, stackTrace) {
      ErrorClassifier.logClassifiedError(
        'خطأ فادح في عملية التسجيل',
        e,
        stackTrace: stackTrace,
      );

      JourneyTracker.failStep(
        e.toString(),
        errorSource: ErrorClassifier.classifyError(e),
        stackTrace: stackTrace,
      );

      return AuthResult.failure('حدث خطأ غير متوقع: $e');
    }
  }

  /// التحقق من صحة البريد الإلكتروني
  static bool _isValidEmail(String email) {
    // نمط بسيط للتحقق من البريد الإلكتروني
    final emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    );
    return emailRegex.hasMatch(email);
  }
}

