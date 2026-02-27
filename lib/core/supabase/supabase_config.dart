
/// Supabase Configuration
/// إعدادات Supabase
library;

import 'package:flutter/foundation.dart';

import 'environment.dart';

/// إعدادات Supabase
class SupabaseConfig {
  SupabaseConfig._();

  /// رابط Supabase
  static String get url => EnvironmentConfig.supabaseUrl;

  /// مفتاح Supabase (Anon Key فقط)
  static String get anonKey => EnvironmentConfig.anonKey;

  /// التحقق من صحة الإعدادات
  static void ensureConfigured() {
    try {
      EnvironmentConfig.validate();
      EnvironmentConfig.printEnvironmentInfo();
    } catch (e) {
      debugPrint('❌ Configuration Error: $e');
      rethrow;
    }
  }

  /// معلومات البيئة (للـ UI فقط)
  static bool get isDevelopment => EnvironmentConfig.isDevelopment;
  static bool get isProduction => EnvironmentConfig.isProduction;
  static String get environmentName => EnvironmentConfig.environmentName;
}



