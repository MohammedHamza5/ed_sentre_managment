
/// 🚀 Environment Configuration - Simplified
/// إدارة إعدادات البيئة بشكل مبسط
library;

import 'package:flutter/foundation.dart';

/// إعدادات البيئة
class EnvironmentConfig {
  EnvironmentConfig._();

  // 🌐 Supabase Configuration
  static const String supabaseUrl = 'https://mbmqrmgdgygznbqvvfqi.supabase.co';

  // 🔑 Anon Key (للاستخدام الآمن في Flutter)
  static const String anonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im1ibXFybWdkZ3lnem5icXZ2ZnFpIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTQ2ODM5MjYsImV4cCI6MjA3MDI1OTkyNn0.S9cGzmAzAsKLfVQz58a-g1dj9Bm8_xeFbpG5LlH5PRs';

  // 🛠️ Debug Settings
  static const bool enableLogging = true; // غيّرها إلى false في Production
  static const bool enableDebugBanner = true;

  // 📊 معلومات البيئة (اختياري - للـ UI فقط)
  static bool get isDevelopment => enableLogging;
  static bool get isProduction => !enableLogging;
  static String get environmentName => isDevelopment ? 'Development' : 'Production';

  /// التحقق من صحة الإعدادات
  static void validate() {
    if (supabaseUrl.isEmpty) {
      throw Exception('❌ Error: Supabase URL is empty');
    }
    if (anonKey.isEmpty) {
      throw Exception('❌ Error: Supabase Anon Key is empty');
    }
  }

  /// طباعة معلومات البيئة
  static void printEnvironmentInfo() {
    if (enableLogging) {
      debugPrint('═══════════════════════════════════════════');
      debugPrint('🔧 Environment: $environmentName');
      debugPrint('🔑 Using: Anon Key (Secure)');
      debugPrint('🔍 Logging: ${enableLogging ? "Enabled" : "Disabled"}');
      debugPrint('═══════════════════════════════════════════');
    }
  }
}



