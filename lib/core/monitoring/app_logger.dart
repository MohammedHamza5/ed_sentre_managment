/// ═══════════════════════════════════════════════════════════════════════════
/// lib/core/monitoring/app_logger.dart
/// نظام تتبع مركزي واحد - لا تكرار
/// ═══════════════════════════════════════════════════════════════════════════
library;

import 'package:flutter/foundation.dart';
import 'dart:convert';

/// نوع السجل
enum LogType {
  auth,       // 🔐 مصادقة
  database,   // 💾 قاعدة بيانات
  navigation, // 🧭 تنقل
  ui,         // 🎨 واجهة
  error,      // ❌ خطأ
  success,    // ✅ نجاح
  info,       // ℹ️ معلومات
  warning,    // ⚠️ تحذير
  network,    // 🌐 شبكة
  performance,// ⚡ أداء
}

/// مستوى السجل
enum LogLevel {
  debug,    // 🐛 تصحيح
  info,     // ℹ️ معلومات
  warning,  // ⚠️ تحذير
  error,    // ❌ خطأ
  critical, // 🔴 حرج
}

/// مصدر الخطأ
enum ErrorSource {
  frontend,  // مشكلة في Flutter
  backend,   // مشكلة في Supabase
  network,   // مشكلة في الاتصال
  unknown,   // غير محدد
}

/// سجل واحد
class LogEntry {
  final DateTime timestamp;
  final LogType type;
  final LogLevel level;
  final ErrorSource? errorSource;
  final String message;
  final Map<String, dynamic>? data;
  final String? stackTrace;
  final String? function;

  LogEntry({
    required this.timestamp,
    required this.type,
    required this.level,
    this.errorSource,
    required this.message,
    this.data,
    this.stackTrace,
    this.function,
  });

  Map<String, dynamic> toJson() => {
    'timestamp': timestamp.toIso8601String(),
    'type': type.name,
    'level': level.name,
    'errorSource': errorSource?.name,
    'message': message,
    'data': data,
    'stackTrace': stackTrace,
    'function': function,
  };
}

/// أداة تتبع مركزية واحدة فقط
class AppLogger {
  static final List<LogEntry> _logs = [];
  static bool _enabled = true;
  static final int _maxLogs = 1000; // حد أقصى للسجلات

  /// تفعيل/تعطيل السجلات
  static void setEnabled(bool enabled) {
    _enabled = enabled;
  }

  /// تسجيل رسالة
  static void log(
      String message, {
        LogType type = LogType.info,
        LogLevel level = LogLevel.info,
        ErrorSource? errorSource,
        dynamic data,
        StackTrace? stackTrace,
        String? function,
      }) {
    if (!_enabled) return;

    final entry = LogEntry(
      timestamp: DateTime.now(),
      type: type,
      level: level,
      errorSource: errorSource,
      message: message,
      data: data is Map<String, dynamic> ? data : {'value': data},
      stackTrace: stackTrace?.toString(),
      function: function,
    );

    // حفظ السجل
    _logs.add(entry);

    // إزالة السجلات القديمة
    if (_logs.length > _maxLogs) {
      _logs.removeRange(0, _logs.length - _maxLogs);
    }

    // طباعة السجل
    _printLog(entry);
  }

  /// طباعة السجل بشكل منسق
  static void _printLog(LogEntry entry) {
    if (!kDebugMode) return;

    final icon = _getTypeIcon(entry.type);
    final levelText = _getLevelText(entry.level);
    final sourceText = entry.errorSource != null
        ? '[${entry.errorSource!.name.toUpperCase()}]'
        : '';
    final functionText = entry.function != null ? '[${entry.function}]' : '';

    final timestamp = entry.timestamp.toString().split('.')[0];

    debugPrint('$timestamp $icon $levelText $sourceText$functionText: ${entry.message}');

    // طباعة البيانات الإضافية
    if (entry.data != null && entry.data!.isNotEmpty) {
      try {
        final prettyData = const JsonEncoder.withIndent('  ').convert(entry.data);
        debugPrint('  📦 Data:\n$prettyData');
      } catch (e) {
        debugPrint('  📦 Data: ${entry.data}');
      }
    }

    // طباعة Stack Trace في حالة الأخطاء
    if (entry.stackTrace != null &&
        (entry.level == LogLevel.error || entry.level == LogLevel.critical)) {
      debugPrint('  📍 Stack Trace:');
      final lines = entry.stackTrace!.split('\n').take(5);
      for (var line in lines) {
        debugPrint('    $line');
      }
    }
  }

  /// أيقونة نوع السجل
  static String _getTypeIcon(LogType type) {
    return switch (type) {
      LogType.auth => '🔐',
      LogType.database => '💾',
      LogType.navigation => '🧭',
      LogType.ui => '🎨',
      LogType.error => '❌',
      LogType.success => '✅',
      LogType.info => 'ℹ️',
      LogType.warning => '⚠️',
      LogType.network => '🌐',
      LogType.performance => '⚡',
    };
  }

  /// نص مستوى السجل
  static String _getLevelText(LogLevel level) {
    return switch (level) {
      LogLevel.debug => '[DEBUG]',
      LogLevel.info => '[INFO]',
      LogLevel.warning => '[WARN]',
      LogLevel.error => '[ERROR]',
      LogLevel.critical => '[CRITICAL]',
    };
  }

  // ═══════════════════════════════════════════════════════════════
  // Shorthand Methods - طرق مختصرة
  // ═══════════════════════════════════════════════════════════════

  static void auth(String message, {dynamic data, ErrorSource? source}) {
    log(message, type: LogType.auth, level: LogLevel.info, data: data, errorSource: source);
  }

  static void database(String message, {dynamic data, LogLevel level = LogLevel.info, ErrorSource? source}) {
    log(message, type: LogType.database, level: level, data: data, errorSource: source);
  }

  static void navigation(String message, {dynamic data}) {
    log(message, type: LogType.navigation, level: LogLevel.info, data: data);
  }

  static void ui(String message, {dynamic data}) {
    log(message, type: LogType.ui, level: LogLevel.info, data: data);
  }

  static void success(String message, {dynamic data}) {
    log(message, type: LogType.success, level: LogLevel.info, data: data);
  }

  static void error(String message, {dynamic error, StackTrace? stackTrace, ErrorSource? source}) {
    log(
      message,
      type: LogType.error,
      level: LogLevel.error,
      data: error,
      stackTrace: stackTrace,
      errorSource: source,
    );
  }

  static void warning(String message, {dynamic data, ErrorSource? source}) {
    log(message, type: LogType.warning, level: LogLevel.warning, data: data, errorSource: source);
  }

  static void info(String message, {dynamic data}) {
    log(message, type: LogType.info, level: LogLevel.info, data: data);
  }

  static void network(String message, {dynamic data, ErrorSource? source}) {
    log(message, type: LogType.network, level: LogLevel.info, data: data, errorSource: source);
  }

  static void performance(String message, {dynamic data}) {
    log(message, type: LogType.performance, level: LogLevel.info, data: data);
  }

  // ═══════════════════════════════════════════════════════════════
  // تصدير واستعلام السجلات
  // ═══════════════════════════════════════════════════════════════

  /// الحصول على جميع السجلات
  static List<LogEntry> getAllLogs() => List.unmodifiable(_logs);

  /// الحصول على سجلات حسب النوع
  static List<LogEntry> getLogsByType(LogType type) {
    return _logs.where((log) => log.type == type).toList();
  }

  /// الحصول على سجلات حسب المستوى
  static List<LogEntry> getLogsByLevel(LogLevel level) {
    return _logs.where((log) => log.level == level).toList();
  }

  /// الحصول على سجلات حسب مصدر الخطأ
  static List<LogEntry> getLogsByErrorSource(ErrorSource source) {
    return _logs.where((log) => log.errorSource == source).toList();
  }

  /// مسح السجلات
  static void clearLogs() {
    _logs.clear();
    info('تم مسح جميع السجلات');
  }

  /// تصدير السجلات كـ JSON
  static String exportLogsAsJson() {
    final logsJson = _logs.map((log) => log.toJson()).toList();
    return const JsonEncoder.withIndent('  ').convert(logsJson);
  }

  /// تصدير السجلات كـ نص
  static String exportLogsAsText() {
    return _logs.map((log) {
      final icon = _getTypeIcon(log.type);
      final level = _getLevelText(log.level);
      final source = log.errorSource != null ? '[${log.errorSource!.name}]' : '';
      return '${log.timestamp} $icon $level $source: ${log.message}';
    }).join('\n');
  }

  /// طباعة ملخص
  static void printSummary() {
    final totalLogs = _logs.length;
    final errorLogs = _logs.where((l) => l.level == LogLevel.error || l.level == LogLevel.critical).length;
    final warningLogs = _logs.where((l) => l.level == LogLevel.warning).length;
    final backendErrors = _logs.where((l) => l.errorSource == ErrorSource.backend).length;
    final frontendErrors = _logs.where((l) => l.errorSource == ErrorSource.frontend).length;
    final networkErrors = _logs.where((l) => l.errorSource == ErrorSource.network).length;

    final summary = '''
═══════════════════════════════════════════════════════════════
📊 ملخص السجلات (Logs Summary)
═══════════════════════════════════════════════════════════════
إجمالي السجلات: $totalLogs
الأخطاء: $errorLogs
التحذيرات: $warningLogs
───────────────────────────────────────────────────────────────
📍 مصادر الأخطاء:
  • Backend (Supabase): $backendErrors
  • Frontend (Flutter): $frontendErrors
  • Network: $networkErrors
───────────────────────────────────────────────────────────────
الوقت: ${DateTime.now()}
═══════════════════════════════════════════════════════════════
''';
    debugPrint(summary);
  }
}

/// Extension لتسجيل العمليات
extension LoggableFuture<T> on Future<T> {
  Future<T> withLogging(
      String operationName, {
        LogType type = LogType.info,
        ErrorSource? errorSource,
      }) async {
    final stopwatch = Stopwatch()..start();
    AppLogger.log('🚀 بدء: $operationName', type: type);

    try {
      final result = await this;
      stopwatch.stop();
      AppLogger.log(
        '✅ نجح: $operationName (${stopwatch.elapsedMilliseconds}ms)',
        type: type,
        data: {'duration_ms': stopwatch.elapsedMilliseconds},
      );
      return result;
    } catch (e, stackTrace) {
      stopwatch.stop();
      AppLogger.log(
        '❌ فشل: $operationName (${stopwatch.elapsedMilliseconds}ms)',
        type: LogType.error,
        level: LogLevel.error,
        errorSource: errorSource ?? ErrorSource.unknown,
        data: {
          'error': e.toString(),
          'duration_ms': stopwatch.elapsedMilliseconds,
        },
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }
}


