
/// Supabase Client Manager
/// مدير عميل Supabase
library;

import 'package:flutter/foundation.dart';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_config.dart';
import 'environment.dart';
import '../storage/secure_local_storage.dart'; // Added

/// إدارة الاتصال بـ Supabase
class SupabaseClientManager {
  SupabaseClientManager._();

  static bool _initialized = false;

  /// تهيئة Supabase
  static Future<void> initialize() async {
    if (_initialized) return;

    // التحقق من الإعدادات
    SupabaseConfig.ensureConfigured();

    await Supabase.initialize(
      url: SupabaseConfig.url,
      anonKey: SupabaseConfig.anonKey, // ✅ Anon Key فقط
      authOptions: FlutterAuthClientOptions(
        authFlowType: AuthFlowType.pkce,
        autoRefreshToken: true,
        pkceAsyncStorage: SecureLocalStorage(), // ✅ Secure Storage
      ),
      storageOptions: StorageClientOptions(
        retryAttempts: 3,
      ),
      debug: EnvironmentConfig.enableLogging,
    );

    _initialized = true;

    // طباعة معلومات الاتصال
    _printConnectionInfo();
  }

  /// طباعة معلومات الاتصال
  static void _printConnectionInfo() {
    if (EnvironmentConfig.enableLogging) {
      debugPrint('');
      debugPrint('╔════════════════════════════════════════════╗');
      debugPrint('║  ✅ Supabase Connected                     ║');
      debugPrint('║  🔑 Anon Key Active                        ║');
      debugPrint('║  🛡️ RLS Enabled (Secure)                   ║');
      debugPrint('╚════════════════════════════════════════════╝');
      debugPrint('');
    }
  }

  /// الحصول على عميل Supabase
  static SupabaseClient get client {
    if (!_initialized) {
      throw Exception(
        '❌ Supabase not initialized. Call SupabaseClientManager.initialize() first.',
      );
    }
    return Supabase.instance.client;
  }

  /// الحصول على مدير المصادقة
  static GoTrueClient get auth => client.auth;

  /// الحصول على قاعدة البيانات
  static SupabaseQueryBuilder Function(String table) get from => client.from;

  /// الحصول على مخزن الملفات
  static SupabaseStorageClient get storage => client.storage;

  /// الحصول على المستخدم الحالي
  static User? get currentUser => auth.currentUser;

  /// الحصول على الجلسة الحالية
  static Session? get currentSession => auth.currentSession;

  /// التحقق من تسجيل الدخول
  static bool get isAuthenticated => currentUser != null;

  /// الاستماع لتغييرات المصادقة
  static Stream<AuthState> get onAuthStateChange => auth.onAuthStateChange;

  /// تنفيذ استعلام مع معلومات Debug في بيئة التطوير
  static Future<T> executeQuery<T>(
      String queryName,
      Future<T> Function() query,
      ) async {
    if (EnvironmentConfig.enableLogging) {
      debugPrint('🔍 Executing Query: $queryName');
      final stopwatch = Stopwatch()..start();

      try {
        final result = await query();
        stopwatch.stop();
        debugPrint('✅ Query Success: $queryName (${stopwatch.elapsedMilliseconds}ms)');
        return result;
      } catch (e) {
        stopwatch.stop();
        debugPrint('❌ Query Failed: $queryName (${stopwatch.elapsedMilliseconds}ms)');
        debugPrint('   Error: $e');
        rethrow;
      }
    } else {
      return await query();
    }
  }
}



