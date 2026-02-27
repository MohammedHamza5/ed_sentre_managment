// /// نظام تتبع شامل لتطبيق EdSentre
// /// Comprehensive Logging System for EdSentre
// library;
//
// import 'package:flutter/foundation.dart';
//
// /// نوع السجل
// enum LogType {
//   auth, // مصادقة
//   database, // قاعدة بيانات
//   navigation, // تنقل
//   ui, // واجهة
//   error, // خطأ
//   success, // نجاح
//   info, // معلومات
//   warning, // تحذير
// }
//
// /// مستوى السجل
// enum LogLevel {
//   debug, // تصحيح
//   info, // معلومات
//   warning, // تحذير
//   error, // خطأ
//   critical, // حرج
// }
//
// /// أداة تتبع شاملة
// class AppLogger {
//   static final List<String> _logs = [];
//   static bool _enabled = true;
//
//   /// تفعيل/تعطيل السجلات
//   static void setEnabled(bool enabled) {
//     _enabled = enabled;
//   }
//
//   /// تسجيل رسالة
//   static void log(
//     String message, {
//     LogType type = LogType.info,
//     LogLevel level = LogLevel.info,
//     dynamic data,
//     StackTrace? stackTrace,
//     String? function,
//   }) {
//     if (!_enabled) return;
//
//     final timestamp = DateTime.now().toIso8601String();
//     final typeIcon = _getTypeIcon(type);
//     final levelText = _getLevelText(level);
//     final functionText = function != null ? ' [$function]' : '';
//
//     final logMessage = '$timestamp $typeIcon $levelText$functionText: $message';
//
//     // حفظ السجل
//     _logs.add(logMessage);
//
//     // طباعة السجل
//     if (kDebugMode) {
//       debugPrint(logMessage);
//
//       // طباعة البيانات الإضافية
//       if (data != null) {
//         debugPrint('  📦 Data: $data');
//       }
//
//       // طباعة Stack Trace في حالة الأخطاء
//       if (stackTrace != null && (level == LogLevel.error || level == LogLevel.critical)) {
//         debugPrint('  📍 Stack Trace:');
//         debugPrint(stackTrace.toString().split('\n').take(5).join('\n'));
//       }
//     }
//   }
//
//   /// أيقونة نوع السجل
//   static String _getTypeIcon(LogType type) {
//     switch (type) {
//       case LogType.auth:
//         return '🔐';
//       case LogType.database:
//         return '💾';
//       case LogType.navigation:
//         return '🧭';
//       case LogType.ui:
//         return '🎨';
//       case LogType.error:
//         return '❌';
//       case LogType.success:
//         return '✅';
//       case LogType.info:
//         return 'ℹ️';
//       case LogType.warning:
//         return '⚠️';
//     }
//   }
//
//   /// نص مستوى السجل
//   static String _getLevelText(LogLevel level) {
//     switch (level) {
//       case LogLevel.debug:
//         return '[DEBUG]';
//       case LogLevel.info:
//         return '[INFO]';
//       case LogLevel.warning:
//         return '[WARN]';
//       case LogLevel.error:
//         return '[ERROR]';
//       case LogLevel.critical:
//         return '[CRITICAL]';
//     }
//   }
//
//   /// سجلات المصادقة
//   static void auth(String message, {dynamic data}) {
//     log(message, type: LogType.auth, level: LogLevel.info, data: data);
//   }
//
//   /// سجلات قاعدة البيانات
//   static void database(String message, {dynamic data, LogLevel level = LogLevel.info}) {
//     log(message, type: LogType.database, level: level, data: data);
//   }
//
//   /// سجلات التنقل
//   static void navigation(String message, {dynamic data}) {
//     log(message, type: LogType.navigation, level: LogLevel.info, data: data);
//   }
//
//   /// سجلات الواجهة
//   static void ui(String message, {dynamic data}) {
//     log(message, type: LogType.ui, level: LogLevel.info, data: data);
//   }
//
//   /// سجلات النجاح
//   static void success(String message, {dynamic data}) {
//     log(message, type: LogType.success, level: LogLevel.info, data: data);
//   }
//
//   /// سجلات الأخطاء
//   static void error(String message, {dynamic error, StackTrace? stackTrace}) {
//     log(
//       message,
//       type: LogType.error,
//       level: LogLevel.error,
//       data: error,
//       stackTrace: stackTrace,
//     );
//   }
//
//   /// سجلات التحذيرات
//   static void warning(String message, {dynamic data}) {
//     log(message, type: LogType.warning, level: LogLevel.warning, data: data);
//   }
//
//   /// معلومات عامة
//   static void info(String message, {dynamic data}) {
//     log(message, type: LogType.info, level: LogLevel.info, data: data);
//   }
//
//   /// الحصول على جميع السجلات
//   static List<String> getAllLogs() => List.unmodifiable(_logs);
//
//   /// مسح السجلات
//   static void clearLogs() {
//     _logs.clear();
//   }
//
//   /// حفظ السجلات في ملف (للاستخدام المستقبلي)
//   static String exportLogs() {
//     return _logs.join('\n');
//   }
//
//   /// طباعة ملخص
//   static void printSummary() {
//     final summary = '''
// ═══════════════════════════════════════════════════════════════
// 📊 ملخص السجلات (Logs Summary)
// ═══════════════════════════════════════════════════════════════
// إجمالي السجلات: ${_logs.length}
// الوقت: ${DateTime.now()}
// ═══════════════════════════════════════════════════════════════
// ''';
//     debugPrint(summary);
//   }
// }
//
// /// Extension لتسجيل العمليات
// extension LoggableFuture<T> on Future<T> {
//   Future<T> withLogging(String operationName, {LogType type = LogType.info}) async {
//     AppLogger.log('🚀 بدء: $operationName', type: type);
//     try {
//       final result = await this;
//       AppLogger.log('✅ نجح: $operationName', type: type);
//       return result;
//     } catch (e, stackTrace) {
//       AppLogger.log(
//         '❌ فشل: $operationName',
//         type: LogType.error,
//         level: LogLevel.error,
//         data: e,
//         stackTrace: stackTrace,
//       );
//       rethrow;
//     }
//   }
// }


