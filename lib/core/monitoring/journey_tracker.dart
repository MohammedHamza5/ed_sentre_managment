/// ═══════════════════════════════════════════════════════════════════════════
/// lib/core/monitoring/journey_tracker.dart
/// تتبع رحلة المستخدم من أول تسجيل حساب حتى جميع الصفحات
/// ═══════════════════════════════════════════════════════════════════════════
library;

import 'package:flutter/material.dart';
import 'app_logger.dart';

/// مرحلة من رحلة المستخدم
enum JourneyStep {
  // Auth Journey
  signupStarted,
  signupDataValidation,
  signupAuthCreation,
  signupDatabaseInsertion,
  signupProviderInit,
  signupCompleted,

  signinStarted,
  signinAuthCheck,
  signinDataFetch,
  signinProviderInit,
  signinCompleted,

  signoutStarted,
  signoutCompleted,

  // Navigation Journey
  navigationToDashboard,
  navigationToStudents,
  navigationToTeachers,
  navigationToSubjects,
  navigationToRooms,
  navigationToSchedule,
  navigationToPayments,
  navigationToAttendance,

  // Data Loading Journey
  dataLoadingStarted,
  dataLoadingCompleted,
  dataLoadingFailed,

  // CRUD Journey
  createStarted,
  createCompleted,
  updateStarted,
  updateCompleted,
  deleteStarted,
  deleteCompleted,
}

/// حدث في رحلة المستخدم
class JourneyEvent {
  final DateTime timestamp;
  final JourneyStep step;
  final String description;
  final Map<String, dynamic>? data;
  final bool success;
  final String? error;
  final ErrorSource? errorSource;

  JourneyEvent({
    required this.timestamp,
    required this.step,
    required this.description,
    this.data,
    this.success = true,
    this.error,
    this.errorSource,
  });

  Duration? durationFrom(JourneyEvent? previousEvent) {
    if (previousEvent == null) return null;
    return timestamp.difference(previousEvent.timestamp);
  }
}

/// متتبع رحلة المستخدم
class JourneyTracker {
  static final List<JourneyEvent> _journey = [];
  static JourneyEvent? _currentStep;

  /// بدء خطوة جديدة
  static void startStep(JourneyStep step, String description, {Map<String, dynamic>? data}) {
    _currentStep = JourneyEvent(
      timestamp: DateTime.now(),
      step: step,
      description: description,
      data: data,
      success: true,
    );

    _journey.add(_currentStep!);

    AppLogger.info(
      '🚶 بدء خطوة: ${step.name} - $description',
      data: data,
    );
  }

  /// إكمال الخطوة الحالية بنجاح
  static void completeStep({Map<String, dynamic>? additionalData}) {
    if (_currentStep == null) return;

    final duration = DateTime.now().difference(_currentStep!.timestamp);

    AppLogger.success(
      '✅ اكتمل: ${_currentStep!.step.name} (${duration.inMilliseconds}ms)',
      data: {
        ...?_currentStep!.data,
        ...?additionalData,
        'duration_ms': duration.inMilliseconds,
      },
    );
  }

  /// فشل الخطوة الحالية
  static void failStep(String error, {ErrorSource? errorSource, StackTrace? stackTrace}) {
    if (_currentStep == null) return;

    final failedEvent = JourneyEvent(
      timestamp: DateTime.now(),
      step: _currentStep!.step,
      description: _currentStep!.description,
      data: _currentStep!.data,
      success: false,
      error: error,
      errorSource: errorSource,
    );

    // استبدال الحدث الحالي بالحدث الفاشل
    _journey[_journey.length - 1] = failedEvent;

    final duration = DateTime.now().difference(_currentStep!.timestamp);

    AppLogger.error(
      '❌ فشل: ${_currentStep!.step.name} (${duration.inMilliseconds}ms)',
      error: error,
      stackTrace: stackTrace,
      source: errorSource,
    );

    _currentStep = null;
  }

  /// الحصول على الرحلة الكاملة
  static List<JourneyEvent> getJourney() => List.unmodifiable(_journey);

  /// الحصول على الخطوات الفاشلة
  static List<JourneyEvent> getFailedSteps() {
    return _journey.where((e) => !e.success).toList();
  }

  /// مسح الرحلة
  static void clearJourney() {
    _journey.clear();
    _currentStep = null;
    AppLogger.info('تم مسح رحلة المستخدم');
  }

  /// طباعة ملخص الرحلة
  static void printJourneySummary() {
    final totalSteps = _journey.length;
    final successfulSteps = _journey.where((e) => e.success).length;
    final failedSteps = _journey.where((e) => !e.success).length;

    final backendErrors = _journey.where((e) => e.errorSource == ErrorSource.backend).length;
    final frontendErrors = _journey.where((e) => e.errorSource == ErrorSource.frontend).length;
    final networkErrors = _journey.where((e) => e.errorSource == ErrorSource.network).length;

    final summary = '''
═══════════════════════════════════════════════════════════════
🚶 ملخص رحلة المستخدم (User Journey Summary)
═══════════════════════════════════════════════════════════════
إجمالي الخطوات: $totalSteps
الخطوات الناجحة: $successfulSteps
الخطوات الفاشلة: $failedSteps
───────────────────────────────────────────────────────────────
📍 مصادر الأخطاء في الرحلة:
  • Backend Errors: $backendErrors
  • Frontend Errors: $frontendErrors
  • Network Errors: $networkErrors
───────────────────────────────────────────────────────────────
الوقت: ${DateTime.now()}
═══════════════════════════════════════════════════════════════
''';
    debugPrint(summary);

    if (failedSteps > 0) {
      debugPrint('\n❌ الخطوات الفاشلة:');
      for (var step in getFailedSteps()) {
        debugPrint('  • ${step.step.name}: ${step.error}');
        if (step.errorSource != null) {
          debugPrint('    المصدر: ${step.errorSource!.name}');
        }
      }
    }
  }

  /// طباعة الرحلة الكاملة بالتفصيل
  static void printDetailedJourney() {
    debugPrint('\n═══════════════════════════════════════════════════════════════');
    debugPrint('🚶 الرحلة الكاملة للمستخدم (Detailed User Journey)');
    debugPrint('═══════════════════════════════════════════════════════════════\n');

    JourneyEvent? previousEvent;
    for (var event in _journey) {
      final duration = event.durationFrom(previousEvent);
      final durationText = duration != null ? '(+${duration.inMilliseconds}ms)' : '';

      final status = event.success ? '✅' : '❌';
      final source = event.errorSource != null ? '[${event.errorSource!.name}]' : '';

      debugPrint('$status ${event.timestamp} $durationText $source');
      debugPrint('   ${event.step.name}: ${event.description}');

      if (!event.success && event.error != null) {
        debugPrint('   ❌ خطأ: ${event.error}');
      }

      if (event.data != null && event.data!.isNotEmpty) {
        debugPrint('   📦 Data: ${event.data}');
      }

      debugPrint('');
      previousEvent = event;
    }

    debugPrint('═══════════════════════════════════════════════════════════════\n');
  }
}

/// Widget لتتبع التنقل بين الصفحات
class JourneyAwareNavigator extends StatelessWidget {
  final Widget child;

  const JourneyAwareNavigator({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Navigator(
      observers: [JourneyNavigatorObserver()],
      onGenerateRoute: (settings) {
        return MaterialPageRoute(builder: (_) => child);
      },
    );
  }
}

/// Observer لتتبع التنقل
class JourneyNavigatorObserver extends NavigatorObserver {
  @override
  void didPush(Route route, Route? previousRoute) {
    final routeName = route.settings.name ?? 'Unknown';
    JourneyTracker.startStep(
      JourneyStep.navigationToDashboard, // يمكن تخصيصه حسب الصفحة
      'الانتقال إلى: $routeName',
      data: {'route': routeName},
    );
    JourneyTracker.completeStep();
    super.didPush(route, previousRoute);
  }
}


