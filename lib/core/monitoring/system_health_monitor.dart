
/// ═══════════════════════════════════════════════════════════════════════════
/// lib/core/monitoring/system_health_monitor.dart
/// مراقبة صحة النظام والأداء
/// ═══════════════════════════════════════════════════════════════════════════
library;

import 'package:flutter/foundation.dart';

import 'dart:async';
import 'app_logger.dart';
import 'journey_tracker.dart';
import 'error_classifier.dart';

/// حالة صحة النظام
enum SystemHealth {
  healthy,    // ✅ صحي
  warning,    // ⚠️ تحذير
  critical,   // 🔴 حرج
}

/// تقرير صحة النظام
class HealthReport {
  final SystemHealth overallHealth;
  final int totalErrors;
  final int backendErrors;
  final int frontendErrors;
  final int networkErrors;
  final double errorRate;
  final Duration averageOperationTime;
  final List<String> warnings;
  final List<String> criticalIssues;

  HealthReport({
    required this.overallHealth,
    required this.totalErrors,
    required this.backendErrors,
    required this.frontendErrors,
    required this.networkErrors,
    required this.errorRate,
    required this.averageOperationTime,
    required this.warnings,
    required this.criticalIssues,
  });
}

/// مراقب صحة النظام
class SystemHealthMonitor {
  static Timer? _monitoringTimer;
  static final List<HealthReport> _healthHistory = [];

  /// بدء المراقبة المستمرة
  static void startMonitoring({Duration interval = const Duration(minutes: 5)}) {
    _monitoringTimer?.cancel();

    _monitoringTimer = Timer.periodic(interval, (_) {
      final report = generateHealthReport();
      _healthHistory.add(report);

      // الاحتفاظ بآخر 20 تقرير فقط
      if (_healthHistory.length > 20) {
        _healthHistory.removeAt(0);
      }

      _logHealthStatus(report);
    });

    AppLogger.info('🏥 بدء مراقبة صحة النظام (كل ${interval.inMinutes} دقائق)');
  }

  /// إيقاف المراقبة
  static void stopMonitoring() {
    _monitoringTimer?.cancel();
    _monitoringTimer = null;
    AppLogger.info('🏥 إيقاف مراقبة صحة النظام');
  }

  /// توليد تقرير صحة فوري
  static HealthReport generateHealthReport() {
    final allLogs = AppLogger.getAllLogs();
    final errors = allLogs.where((log) =>
    log.level == LogLevel.error || log.level == LogLevel.critical
    ).toList();

    final backendErrors = errors.where((e) => e.errorSource == ErrorSource.backend).length;
    final frontendErrors = errors.where((e) => e.errorSource == ErrorSource.frontend).length;
    final networkErrors = errors.where((e) => e.errorSource == ErrorSource.network).length;

    final errorRate = allLogs.isNotEmpty ? (errors.length / allLogs.length) * 100 : 0.0;

    // حساب متوسط وقت العمليات
    final performanceLogs = allLogs.where((log) =>
    log.data?['duration_ms'] != null
    ).toList();

    final avgDuration = performanceLogs.isNotEmpty
        ? Duration(milliseconds:
    (performanceLogs
        .map((log) => log.data!['duration_ms'] as int)
        .reduce((a, b) => a + b) / performanceLogs.length)
        .round())
        : Duration.zero;

    // تحديد التحذيرات والمشاكل الحرجة
    final warnings = <String>[];
    final criticalIssues = <String>[];

    if (errorRate > 10) {
      warnings.add('معدل الأخطاء مرتفع: ${errorRate.toStringAsFixed(1)}%');
    }

    if (errorRate > 30) {
      criticalIssues.add('معدل الأخطاء حرج: ${errorRate.toStringAsFixed(1)}%');
    }

    if (backendErrors > 5) {
      criticalIssues.add('أخطاء Backend متعددة: $backendErrors');
    }

    if (networkErrors > 3) {
      warnings.add('مشاكل في الاتصال: $networkErrors خطأ');
    }

    if (avgDuration.inMilliseconds > 5000) {
      warnings.add('الأداء بطيء: متوسط ${avgDuration.inMilliseconds}ms');
    }

    // تحديد الحالة العامة
    final overallHealth = criticalIssues.isNotEmpty
        ? SystemHealth.critical
        : warnings.isNotEmpty
        ? SystemHealth.warning
        : SystemHealth.healthy;

    return HealthReport(
      overallHealth: overallHealth,
      totalErrors: errors.length,
      backendErrors: backendErrors,
      frontendErrors: frontendErrors,
      networkErrors: networkErrors,
      errorRate: errorRate,
      averageOperationTime: avgDuration,
      warnings: warnings,
      criticalIssues: criticalIssues,
    );
  }

  /// تسجيل حالة الصحة
  static void _logHealthStatus(HealthReport report) {
    final icon = switch (report.overallHealth) {
      SystemHealth.healthy => '✅',
      SystemHealth.warning => '⚠️',
      SystemHealth.critical => '🔴',
    };

    AppLogger.info(
      '$icon حالة النظام: ${report.overallHealth.name.toUpperCase()}',
      data: {
        'total_errors': report.totalErrors,
        'error_rate': '${report.errorRate.toStringAsFixed(1)}%',
        'avg_operation_time': '${report.averageOperationTime.inMilliseconds}ms',
      },
    );

    if (report.criticalIssues.isNotEmpty) {
      AppLogger.error('🔴 مشاكل حرجة:', error: report.criticalIssues.join(', '));
    }

    if (report.warnings.isNotEmpty) {
      AppLogger.warning('⚠️ تحذيرات:', data: report.warnings.join(', '));
    }
  }

  /// طباعة تقرير صحة مفصل
  static void printHealthReport() {
    final report = generateHealthReport();

    final healthIcon = switch (report.overallHealth) {
      SystemHealth.healthy => '✅',
      SystemHealth.warning => '⚠️',
      SystemHealth.critical => '🔴',
    };

    final healthText = switch (report.overallHealth) {
      SystemHealth.healthy => 'صحي (Healthy)',
      SystemHealth.warning => 'تحذير (Warning)',
      SystemHealth.critical => 'حرج (Critical)',
    };

    debugPrint('''
═══════════════════════════════════════════════════════════════
🏥 تقرير صحة النظام (System Health Report)
═══════════════════════════════════════════════════════════════
الحالة العامة: $healthIcon $healthText
───────────────────────────────────────────────────────────────
📊 الإحصائيات:
  • إجمالي الأخطاء: ${report.totalErrors}
  • معدل الأخطاء: ${report.errorRate.toStringAsFixed(1)}%
  • متوسط وقت العمليات: ${report.averageOperationTime.inMilliseconds}ms
───────────────────────────────────────────────────────────────
📍 الأخطاء حسب المصدر:
  • Backend: ${report.backendErrors}
  • Frontend: ${report.frontendErrors}
  • Network: ${report.networkErrors}
───────────────────────────────────────────────────────────────
${report.criticalIssues.isNotEmpty ? '🔴 مشاكل حرجة:\n${report.criticalIssues.map((i) => '  • $i').join('\n')}\n───────────────────────────────────────────────────────────────\n' : ''}${report.warnings.isNotEmpty ? '⚠️ تحذيرات:\n${report.warnings.map((w) => '  • $w').join('\n')}\n───────────────────────────────────────────────────────────────\n' : ''}الوقت: ${DateTime.now()}
═══════════════════════════════════════════════════════════════
''');
  }

  /// طباعة تقرير شامل (All-in-One)
  static void printComprehensiveReport() {
    debugPrint('\n\n');
    debugPrint('═══════════════════════════════════════════════════════════════');
    debugPrint('📊 التقرير الشامل لنظام EdSentre (Comprehensive Report)');
    debugPrint('═══════════════════════════════════════════════════════════════\n');

    // 1. صحة النظام
    printHealthReport();

    debugPrint('\n');

    // 2. ملخص السجلات
    AppLogger.printSummary();

    debugPrint('\n');

    // 3. ملخص رحلة المستخدم
    JourneyTracker.printJourneySummary();

    debugPrint('\n');

    // 4. تصنيف الأخطاء
    ErrorClassifier.printErrorReport();

    debugPrint('\n');
    debugPrint('═══════════════════════════════════════════════════════════════');
    debugPrint('✅ انتهى التقرير الشامل');
    debugPrint('═══════════════════════════════════════════════════════════════\n\n');
  }
}



