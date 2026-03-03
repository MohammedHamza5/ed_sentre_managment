/// 🚀 Environment Configuration
/// إدارة إعدادات البيئة
library;

import 'package:flutter/foundation.dart';

/// إعدادات البيئة
class EnvironmentConfig {
  EnvironmentConfig._();

  // ─────────────────────────────────────────────────────────────────────────
  // 🌐 Supabase Configuration
  // يمكن تمرير القيم عبر --dart-define أثناء البناء للإنتاج:
  //   flutter build apk \
  //     --dart-define=SUPABASE_URL=https://xxx.supabase.co \
  //     --dart-define=SUPABASE_ANON_KEY=eyJ...
  // ─────────────────────────────────────────────────────────────────────────

  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://mbmqrmgdgygznbqvvfqi.supabase.co',
  );

  static const String anonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9'
        '.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1ibXFybWdkZ3lnem5icXZ2ZnFpIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTQ2ODM5MjYsImV4cCI6MjA3MDI1OTkyNn0'
        '.S9cGzmAzAsKLfVQz58a-g1dj9Bm8_xeFbpG5LlH5PRs',
  );

  // ─────────────────────────────────────────────────────────────────────────
  // 🛠️  Debug / Production flags
  // كلا الإعدادين يتبعان kDebugMode تلقائياً —
  //   في Debug build  → true  (logging + banner مفعّلان)
  //   في Release build → false (بدون تسريب معلومات)
  // ─────────────────────────────────────────────────────────────────────────

  /// تفعيل اللوق — يُفعَّل تلقائياً في Debug ويُعطَّل في Release
  static const bool enableLogging = kDebugMode;

  /// شريط Debug Banner في الزاوية — يُظهَر في Debug فقط
  static const bool enableDebugBanner = kDebugMode;

  // ─────────────────────────────────────────────────────────────────────────
  // 📊 معلومات البيئة (للـ UI فقط)
  // ─────────────────────────────────────────────────────────────────────────

  static bool get isDevelopment => enableLogging;
  static bool get isProduction => !enableLogging;
  static String get environmentName =>
      isDevelopment ? 'Development' : 'Production';

  /// التحقق من صحة الإعدادات
  static void validate() {
    if (supabaseUrl.isEmpty) {
      throw Exception('❌ Error: Supabase URL is empty');
    }
    if (anonKey.isEmpty) {
      throw Exception('❌ Error: Supabase Anon Key is empty');
    }
  }

  /// طباعة معلومات البيئة (في Debug فقط)
  static void printEnvironmentInfo() {
    if (!enableLogging) return;
    debugPrint('═══════════════════════════════════════════');
    debugPrint('🔧 Environment: $environmentName');
    debugPrint('🔑 Using: Anon Key (Secure)');
    debugPrint('🔍 Logging: Enabled (Debug Mode)');
    debugPrint('═══════════════════════════════════════════');
  }
}
