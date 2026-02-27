/// Authentication Service - مع حل شامل لمشكلة التخزين المحلي
library;

import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../monitoring/app_logger.dart';
import '../database/app_database.dart';
import 'supabase_client.dart';
import '../offline/local_cache_service.dart';

/// نتيجة عملية المصادقة
class AuthResult {
  final bool success;
  final String? errorMessage;
  final User? user;
  final Map<String, dynamic>? userData;

  const AuthResult({
    required this.success,
    this.errorMessage,
    this.user,
    this.userData,
  });

  factory AuthResult.success(User user, [Map<String, dynamic>? userData]) {
    return AuthResult(success: true, user: user, userData: userData);
  }

  factory AuthResult.failure(String message) {
    return AuthResult(success: false, errorMessage: message);
  }
}

/// خدمة المصادقة للتطبيق
class AuthService {
  AuthService._();

  // مفاتيح التخزين المحلي
  static const String _centerIdKey = 'selected_center_id';
  static const String _userIdKey = 'current_user_id';

  // ✅ مرجع لقاعدة البيانات المحلية (سيتم تمريره من الخارج)
  static AppDatabase? _database;

  /// تعيين مرجع قاعدة البيانات (يتم استدعاؤه عند بدء التطبيق)
  static void setDatabase(AppDatabase database) {
    _database = database;
  }

  /// تسجيل الدخول بالبريد الإلكتروني وكلمة المرور
  static Future<AuthResult> signInWithEmail({
    required String email,
    required String password,
  }) async {
    AppLogger.info(
      '═══════════════════════════════════════════════════════════════',
    );
    AppLogger.info('🔵 بدء عملية تسجيل الدخول');
    AppLogger.info(
      '═══════════════════════════════════════════════════════════════',
    );

    try {
      // ─────────────────────────────────────────────────────────────
      // 🔥 خطوة إضافية: مسح أي بيانات قديمة قبل تسجيل الدخول
      // ─────────────────────────────────────────────────────────────
      AppLogger.auth('📍 الخطوة 0/8: تنظيف البيانات القديمة');
      await _clearAllLocalData(fullCleanup: false);

      // ─────────────────────────────────────────────────────────────
      // الخطوة 1: محاولة تسجيل الدخول
      // ─────────────────────────────────────────────────────────────
      AppLogger.auth('📍 الخطوة 1/8: محاولة تسجيل الدخول');
      AppLogger.database('📧 البريد الإلكتروني: $email');

      final response = await SupabaseClientManager.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (response.user == null) {
        AppLogger.error('❌ فشل تسجيل الدخول - لا يوجد مستخدم');
        return AuthResult.failure('فشل تسجيل الدخول');
      }

      AppLogger.success('✅ تم تسجيل الدخول في Auth');
      AppLogger.database('👤 User ID: ${response.user!.id}');
      AppLogger.database('📧 Email: ${response.user!.email}');
      AppLogger.database('📦 Metadata:', data: response.user!.userMetadata);

      // ─────────────────────────────────────────────────────────────
      // الخطوة 2: جلب بيانات المستخدم من قاعدة البيانات
      // ─────────────────────────────────────────────────────────────
      AppLogger.auth('📍 الخطوة 2/8: جلب بيانات المستخدم من Database');

      final userData = await _fetchUserData(response.user!.id);

      // ─────────────────────────────────────────────────────────────
      // الخطوة 3: التحقق من وجود المستخدم
      // ─────────────────────────────────────────────────────────────
      AppLogger.auth('📍 الخطوة 3/8: التحقق من وجود المستخدم في النظام');

      if (userData == null) {
        AppLogger.error('❌ المستخدم غير موجود في قاعدة البيانات');
        await signOut();
        return AuthResult.failure('المستخدم غير موجود في النظام');
      }

      AppLogger.success('✅ تم العثور على المستخدم في Database');

      // ─────────────────────────────────────────────────────────────
      // الخطوة 4: التحقق من وجود السنتر
      // ─────────────────────────────────────────────────────────────
      AppLogger.auth('📍 الخطوة 4/8: التحقق من وجود السنتر');

      if (userData['center_id'] == null) {
        AppLogger.error('❌ لم يتم العثور على سنتر مرتبط بالمستخدم');
        await signOut();
        return AuthResult.failure(
          'لم يتم العثور على سنتر مرتبط بحسابك. تواصل مع الدعم.',
        );
      }

      AppLogger.success('✅ تم العثور على السنتر: ${userData['center_id']}');

      // ─────────────────────────────────────────────────────────────
      // الخطوة 5: التحقق من الدور
      // ─────────────────────────────────────────────────────────────
      AppLogger.auth('📍 الخطوة 5/8: التحقق من صلاحية الدور');

      final userRole = userData['role'] as String?;
      AppLogger.database('🎭 الدور: $userRole');

      if (userRole != 'center_admin' &&
          userRole != 'super_admin' &&
          userRole != 'teacher' &&
          userRole != 'student') {
        AppLogger.error('❌ الدور غير مصرح به: $userRole');
        await signOut();
        return AuthResult.failure(
          'هذا التطبيق مخصص لمديري السناتر والمعلمين والطلاب فقط',
        );
      }

      AppLogger.success('✅ الدور صالح للوصول');

      // ─────────────────────────────────────────────────────────────
      // الخطوة 6: حفظ البيانات في التخزين المحلي
      // ─────────────────────────────────────────────────────────────
      AppLogger.auth('📍 الخطوة 6/8: حفظ البيانات في التخزين المحلي');

      await _saveCenterIdToLocalStorage(
        userId: response.user!.id,
        centerId: userData['center_id'] as String,
      );

      // ─────────────────────────────────────────────────────────────
      // 🔥 الخطوة 7: مسح أي بيانات من سنتر آخر في قاعدة البيانات المحلية
      // ─────────────────────────────────────────────────────────────
      AppLogger.auth('📍 الخطوة 7/8: تنظيف قاعدة البيانات المحلية');
      await _cleanupLocalDatabaseForNewCenter(userData['center_id'] as String);

      // ─────────────────────────────────────────────────────────────
      // الخطوة 8: اكتمال تسجيل الدخول
      // ─────────────────────────────────────────────────────────────
      AppLogger.auth('📍 الخطوة 8/8: اكتمال تسجيل الدخول');

      AppLogger.info(
        '═══════════════════════════════════════════════════════════════',
      );
      AppLogger.success('✅ اكتملت عملية تسجيل الدخول بنجاح');
      AppLogger.success('👤 الاسم: ${userData['full_name']}');
      AppLogger.success('📧 البريد: ${userData['email']}');
      AppLogger.success('🎭 الدور: ${userData['role']}');
      AppLogger.success('🏢 السنتر: ${userData['center_id']}');
      AppLogger.info(
        '═══════════════════════════════════════════════════════════════',
      );

      return AuthResult.success(response.user!, userData);
    } on AuthException catch (e) {
      AppLogger.error('❌ AuthException في تسجيل الدخول', error: e);
      return AuthResult.failure(_translateAuthError(e.message));
    } catch (e, stackTrace) {
      AppLogger.error(
        '❌ خطأ غير متوقع في تسجيل الدخول',
        error: e,
        stackTrace: stackTrace,
      );
      return AuthResult.failure('حدث خطأ غير متوقع: $e');
    }
  }

  /// تسجيل حساب جديد
  static Future<AuthResult> signUp({
    required String email,
    required String password,
    required String fullName,
    required String phone,
  }) async {
    AppLogger.info(
      '═══════════════════════════════════════════════════════════════',
    );
    AppLogger.info('🔵 بدء عملية إنشاء حساب جديد');
    AppLogger.info(
      '═══════════════════════════════════════════════════════════════',
    );

    try {
      // ─────────────────────────────────────────────────────────────
      // الخطوة 1: تجهيز البيانات
      // ─────────────────────────────────────────────────────────────
      AppLogger.auth('📍 الخطوة 1/11: تجهيز بيانات التسجيل');
      AppLogger.database('📧 البريد الإلكتروني: $email');
      AppLogger.database('👤 الاسم الكامل: $fullName');
      AppLogger.database('📱 رقم الهاتف: $phone');

      final metadata = {
        'full_name': fullName,
        'phone': phone,
        'role': 'center_admin',
        'user_type': 'center_admin',
      };

      AppLogger.database('📦 Metadata المرسل:', data: metadata);

      // ─────────────────────────────────────────────────────────────
      // الخطوة 2: إنشاء حساب Auth
      // ─────────────────────────────────────────────────────────────
      AppLogger.auth('📍 الخطوة 2/11: إنشاء حساب في Supabase Auth');

      final response = await SupabaseClientManager.auth.signUp(
        email: email,
        password: password,
        data: metadata,
      );

      if (response.user == null) {
        AppLogger.error('❌ فشل إنشاء حساب Auth');
        return AuthResult.failure('فشل إنشاء الحساب');
      }

      final userId = response.user!.id;
      AppLogger.success('✅ تم إنشاء حساب Auth بنجاح');
      AppLogger.database('🆔 User ID: $userId');
      AppLogger.database('📧 Email: ${response.user!.email}');
      AppLogger.database(
        '📦 User Metadata:',
        data: response.user!.userMetadata,
      );

      // ─────────────────────────────────────────────────────────────
      // الخطوة 3: انتظار Database Trigger
      // ─────────────────────────────────────────────────────────────
      AppLogger.auth('📍 الخطوة 3/11: انتظار Database Trigger (1.5 ثانية)');
      AppLogger.info('⏳ سيقوم Trigger بإنشاء:');
      AppLogger.info('   1️⃣ سجل في جدول users');
      AppLogger.info('   2️⃣ سنتر جديد في جدول centers');
      AppLogger.info('   3️⃣ ربط admin_user_id بالـ center');

      await Future.delayed(const Duration(milliseconds: 1500));
      AppLogger.success('✅ انتهى وقت الانتظار الأولي');

      // ─────────────────────────────────────────────────────────────
      // الخطوة 4-9: محاولات جلب البيانات
      // ─────────────────────────────────────────────────────────────
      AppLogger.auth('📍 الخطوة 4/11: بدء محاولات جلب بيانات المستخدم والسنتر');

      Map<String, dynamic>? userData;
      int attempts = 0;
      const maxAttempts = 5;

      while (attempts < maxAttempts) {
        attempts++;
        final currentStep = 4 + attempts - 1;

        AppLogger.auth(
          '📍 الخطوة $currentStep/11: محاولة رقم $attempts من $maxAttempts',
        );
        AppLogger.info('⏳ انتظار ${500 * attempts} ms قبل المحاولة...');

        await Future.delayed(Duration(milliseconds: 500 * attempts));

        AppLogger.database('🔍 محاولة جلب البيانات من Database...');
        userData = await _fetchUserData(userId);

        if (userData == null) {
          AppLogger.warning(
            '⚠️ المحاولة $attempts: لم يتم العثور على بيانات المستخدم بعد',
          );
          continue;
        }

        AppLogger.success(
          '✅ المحاولة $attempts: تم العثور على بيانات المستخدم',
        );
        AppLogger.database('📦 User Data:', data: userData);

        if (userData['center_id'] != null) {
          AppLogger.success('✅ المحاولة $attempts: تم العثور على السنتر!');
          AppLogger.database('🏢 Center ID: ${userData['center_id']}');
          AppLogger.database('🏢 Center Data:', data: userData['center']);
          break;
        } else {
          AppLogger.warning(
            '⚠️ المحاولة $attempts: بيانات المستخدم موجودة لكن لا يوجد center_id',
          );
        }
      }

      // ─────────────────────────────────────────────────────────────
      // الخطوة 10: التحقق النهائي
      // ─────────────────────────────────────────────────────────────
      AppLogger.auth('📍 الخطوة 10/11: التحقق النهائي من اكتمال العملية');

      if (userData == null || userData['center_id'] == null) {
        AppLogger.error('❌ فشلت جميع المحاولات - لم يتم إنشاء السنتر');
        AppLogger.error('📊 حالة البيانات:');
        AppLogger.error(
          '   - userData: ${userData != null ? "موجود" : "غير موجود"}',
        );
        AppLogger.error(
          '   - center_id: ${userData?['center_id'] ?? "غير موجود"}',
        );

        return AuthResult.failure(
          'تم إنشاء الحساب لكن فشل إنشاء السنتر. جرب تسجيل الدخول بعد دقيقة.',
        );
      }

      // ─────────────────────────────────────────────────────────────
      // 🔥 الخطوة 11: حفظ Center ID في SharedPreferences (الحل!)
      // ─────────────────────────────────────────────────────────────
      AppLogger.auth('📍 الخطوة 11/11: حفظ Center ID للحساب الجديد');

      await _saveCenterIdToLocalStorage(
        userId: userId,
        centerId: userData['center_id'] as String,
      );

      // ─────────────────────────────────────────────────────────────
      // النجاح النهائي
      // ─────────────────────────────────────────────────────────────
      AppLogger.info(
        '═══════════════════════════════════════════════════════════════',
      );
      AppLogger.success('✅ اكتملت عملية إنشاء الحساب بنجاح!');
      AppLogger.success('👤 الاسم: ${userData['full_name']}');
      AppLogger.success('📧 البريد: ${userData['email']}');
      AppLogger.success('📱 الهاتف: ${userData['phone']}');
      AppLogger.success('🎭 الدور: ${userData['role']}');
      AppLogger.success('🏢 السنتر: ${userData['center_id']}');

      if (userData['center'] != null) {
        AppLogger.success('🏢 اسم السنتر: ${userData['center']['name']}');
        AppLogger.success(
          '✅ حالة السنتر: ${userData['center']['is_active'] ? "نشط" : "غير نشط"}',
        );
        AppLogger.success(
          '📦 خطة الاشتراك: ${userData['center']['subscription_plan']}',
        );
      }

      AppLogger.info(
        '═══════════════════════════════════════════════════════════════',
      );

      return AuthResult.success(response.user!, userData);
    } on AuthException catch (e) {
      AppLogger.error('❌ AuthException في التسجيل', error: e);
      return AuthResult.failure(_translateAuthError(e.message));
    } catch (e, stackTrace) {
      AppLogger.error(
        '❌ خطأ غير متوقع في التسجيل',
        error: e,
        stackTrace: stackTrace,
      );
      return AuthResult.failure('حدث خطأ غير متوقع: $e');
    }
  }

  /// تسجيل الخروج - مع تنظيف شامل لكل البيانات المحلية
  static Future<void> signOut() async {
    AppLogger.auth('🔵 بدء عملية تسجيل الخروج');
    try {
      // 1. تسجيل الخروج من Supabase
      await SupabaseClientManager.auth.signOut();

      // 🔥 2. مسح كل البيانات المحلية (SharedPreferences + Database)
      await _clearAllLocalData(fullCleanup: true);

      AppLogger.success('✅ تم تسجيل الخروج بنجاح وتنظيف جميع البيانات');
    } catch (e) {
      AppLogger.warning('⚠️ خطأ في تسجيل الخروج (تم التجاهل)', data: e);
    }
  }

  /// إعادة تعيين كلمة المرور
  static Future<AuthResult> resetPassword(String email) async {
    AppLogger.auth('🔵 بدء عملية إعادة تعيين كلمة المرور');
    AppLogger.database('📧 البريد: $email');

    try {
      await SupabaseClientManager.auth.resetPasswordForEmail(email);
      AppLogger.success('✅ تم إرسال رابط إعادة تعيين كلمة المرور');
      return AuthResult.success(SupabaseClientManager.currentUser!);
    } on AuthException catch (e) {
      AppLogger.error('❌ فشلت عملية إعادة تعيين كلمة المرور', error: e);
      return AuthResult.failure(_translateAuthError(e.message));
    } catch (e, stackTrace) {
      AppLogger.error('❌ خطأ غير متوقع', error: e, stackTrace: stackTrace);
      return AuthResult.failure('حدث خطأ غير متوقع: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // 🔥 دوال جديدة لحل مشكلة Center ID
  // ═══════════════════════════════════════════════════════════════

  /// مسح البيانات المحلية عند تسجيل الخروج
  static Future<void> _clearLocalStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // مسح Center ID و User ID
      await prefs.remove(_centerIdKey);
      await prefs.remove(_userIdKey);

      // مسح أي بيانات مؤقتة أخرى
      await prefs.remove('cached_user_data');
      await prefs.remove('last_sync_time');

      AppLogger.success('🗑️ تم مسح البيانات المحلية');
      AppLogger.database('   - تم مسح Center ID');
      AppLogger.database('   - تم مسح User ID');
      AppLogger.database('   - تم مسح البيانات المؤقتة');
    } catch (e) {
      AppLogger.error('❌ خطأ في مسح البيانات المحلية', error: e);
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // دوال مساعدة
  // ═══════════════════════════════════════════════════════════════

  ///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
  // ═══════════════════════════════════════════════════════════════
  // 🔥 دوال التنظيف الشاملة
  // ═══════════════════════════════════════════════════════════════

  /// مسح جميع البيانات المحلية (SharedPreferences + Drift Database)
  static Future<void> _clearAllLocalData({required bool fullCleanup}) async {
    try {
      AppLogger.info('🧹 بدء تنظيف البيانات المحلية...');

      // 1. مسح SharedPreferences
      await _clearSharedPreferences(fullCleanup: fullCleanup);

      // 2. مسح قاعدة البيانات المحلية (Drift)
      if (_database != null && fullCleanup) {
        AppLogger.database('🗑️ مسح قاعدة البيانات المحلية (Drift)...');
        await _database!.clearAllData();
        AppLogger.success('✅ تم مسح قاعدة البيانات المحلية بالكامل');
      }

      if (fullCleanup) {
        try {
          final cache = LocalCacheService();
          await cache.initialize();
          await cache.clearAll();
          AppLogger.success('✅ تم مسح Cache المحلي بالكامل');
        } catch (e) {
          AppLogger.warning('⚠️ فشل مسح Cache المحلي', data: e);
        }
      }

      AppLogger.success('✅ اكتمل تنظيف البيانات المحلية');
    } catch (e) {
      AppLogger.error('❌ خطأ في تنظيف البيانات المحلية', error: e);
    }
  }

  /// مسح SharedPreferences
  static Future<void> _clearSharedPreferences({
    required bool fullCleanup,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      if (fullCleanup) {
        // 🔥 مسح شامل لكل البيانات - لضمان عدم بقاء أي cache قديم
        AppLogger.database('🗑️ مسح SharedPreferences بالكامل...');

        // مسح كل المفاتيح لضمان تنظيف كامل
        await prefs.clear();

        AppLogger.success('🗑️ تم مسح جميع بيانات SharedPreferences');
      } else {
        // مسح جزئي (فقط المفاتيح الأساسية)
        await prefs.remove(_centerIdKey);
        await prefs.remove(_userIdKey);
        await prefs.remove('cached_user_data');

        AppLogger.database('🗑️ تم مسح المفاتيح الأساسية من SharedPreferences');
      }

      AppLogger.database('   ✓ مسح Center ID');
      AppLogger.database('   ✓ مسح User ID');
      AppLogger.database('   ✓ مسح البيانات المؤقتة');
    } catch (e) {
      AppLogger.error('❌ خطأ في مسح SharedPreferences', error: e);
    }
  }

  /// تنظيف قاعدة البيانات المحلية عند تسجيل الدخول بحساب جديد
  static Future<void> _cleanupLocalDatabaseForNewCenter(
    String newCenterId,
  ) async {
    try {
      if (_database == null) {
        AppLogger.warning('⚠️ قاعدة البيانات المحلية غير متاحة');
        return;
      }

      // الحصول على آخر Center ID محفوظ
      final prefs = await SharedPreferences.getInstance();
      final lastCenterId = prefs.getString('last_center_id');

      if (lastCenterId != null && lastCenterId != newCenterId) {
        // يوجد سنتر قديم مختلف - نمسح بياناته
        AppLogger.info('🗑️ تم اكتشاف سنتر مختلف - مسح البيانات القديمة');
        AppLogger.database('   📦 السنتر القديم: $lastCenterId');
        AppLogger.database('   📦 السنتر الجديد: $newCenterId');

        // مسح كل البيانات (لأننا لا نعرف أي سنتر تنتمي إليه البيانات الحالية)
        await _database!.clearAllData();

        AppLogger.success('✅ تم مسح بيانات السنتر القديم');
      } else if (lastCenterId == null) {
        // أول تسجيل دخول أو لا توجد بيانات محفوظة
        AppLogger.info('🆕 أول تسجيل دخول - تنظيف قاعدة البيانات');
        await _database!.clearAllData();
      } else {
        // نفس السنتر - لا حاجة للمسح
        AppLogger.info('✅ نفس السنتر - لا حاجة للتنظيف');
      }

      try {
        final cache = LocalCacheService();
        await cache.initialize();
        final cachedCenterId = await cache.getCenterId();
        if (cachedCenterId == null || cachedCenterId != newCenterId) {
          await cache.clearAll();
          AppLogger.success('✅ تم مسح Cache المرتبط بسنتر مختلف');
        }
        await cache.saveCenterId(newCenterId);
      } catch (e) {
        AppLogger.warning('⚠️ فشل تحديث Cache للمركز الجديد', data: e);
      }

      // حفظ السنتر الحالي كـ "last_center_id"
      await prefs.setString('last_center_id', newCenterId);
    } catch (e) {
      AppLogger.error('❌ خطأ في تنظيف قاعدة البيانات المحلية', error: e);
    }
  }

  /// حفظ Center ID في SharedPreferences
  static Future<void> _saveCenterIdToLocalStorage({
    required String userId,
    required String centerId,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // حفظ Center ID و User ID
      await prefs.setString(_centerIdKey, centerId);
      await prefs.setString(_userIdKey, userId);

      AppLogger.success('💾 تم حفظ البيانات في التخزين المحلي');
      AppLogger.database('   🆔 User ID: $userId');
      AppLogger.database('   🏢 Center ID: $centerId');
    } catch (e) {
      AppLogger.error('❌ خطأ في حفظ البيانات المحلية', error: e);
    }
  }

  /// جلب Center ID المحفوظ محلياً
  static Future<String?> getSavedCenterId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final centerId = prefs.getString(_centerIdKey);

      if (centerId != null) {
        AppLogger.info('📥 تم جلب Center ID من التخزين المحلي: $centerId');
      } else {
        AppLogger.warning('⚠️ لا يوجد Center ID محفوظ محلياً');
      }

      return centerId;
    } catch (e) {
      AppLogger.error('❌ خطأ في جلب Center ID', error: e);
      return null;
    }
  }

  /// جلب User ID المحفوظ محلياً
  static Future<String?> getSavedUserId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_userIdKey);
    } catch (e) {
      AppLogger.error('❌ خطأ في جلب User ID', error: e);
      return null;
    }
  }

  /// التحقق من تطابق المستخدم الحالي مع المستخدم المحفوظ
  static Future<bool> isCurrentUserSaved() async {
    try {
      final currentUser = SupabaseClientManager.currentUser;
      if (currentUser == null) return false;

      final savedUserId = await getSavedUserId();
      final isMatch = currentUser.id == savedUserId;

      if (!isMatch && savedUserId != null) {
        AppLogger.warning('⚠️ المستخدم الحالي لا يطابق المستخدم المحفوظ');
        AppLogger.database('   - Current User: ${currentUser.id}');
        AppLogger.database('   - Saved User: $savedUserId');

        // مسح البيانات القديمة
        await _clearAllLocalData(fullCleanup: true);
      }

      return isMatch;
    } catch (e) {
      AppLogger.error('❌ خطأ في التحقق من المستخدم', error: e);
      return false;
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // دوال مساعدة (باقي الدوال كما هي)
  // ═══════════════════════════════════════════════════════════════

  /// جلب بيانات المستخدم من قاعدة البيانات مع تحديد السنتر
  static Future<Map<String, dynamic>?> _fetchUserData(String userId) async {
    // ... نفس الكود الموجود حالياً
    AppLogger.database(
      '═══════════════════════════════════════════════════════════════',
    );
    AppLogger.database('🔍 بدء عملية جلب بيانات المستخدم');
    AppLogger.database('🆔 User ID: $userId');
    AppLogger.database(
      '═══════════════════════════════════════════════════════════════',
    );

    try {
      AppLogger.database('📍 الخطوة 1/4: البحث في جدول users');

      Map<String, dynamic>? userRecord;
      try {
        userRecord = await SupabaseClientManager.client
            .from('users')
            .select('*')
            .eq('id', userId)
            .maybeSingle();

        if (userRecord != null) {
          AppLogger.success('✅ تم العثور على السجل في جدول users');
          AppLogger.database('📦 User Record:', data: userRecord);
        } else {
          AppLogger.warning('⚠️ لم يتم العثور على السجل في جدول users');
        }
      } catch (e) {
        AppLogger.error('❌ خطأ في الاستعلام عن جدول users', error: e);
      }

      if (userRecord == null) {
        AppLogger.database('📍 Fallback: استخدام Auth Metadata');
        final authUser = SupabaseClientManager.auth.currentUser;

        if (authUser != null) {
          userRecord = {
            'id': userId,
            'email': authUser.email,
            'full_name': authUser.userMetadata?['full_name'] ?? 'User',
            'phone': authUser.userMetadata?['phone'],
            'user_type': authUser.userMetadata?['user_type'] ?? 'guest',
          };
          AppLogger.success('✅ تم إنشاء user record من Auth Metadata');
          AppLogger.database('📦 Generated Record:', data: userRecord);
        } else {
          AppLogger.error('❌ لا يوجد مستخدم في Auth');
          return null;
        }
      }

      AppLogger.database('📍 الخطوة 2/4: تحديد دور المستخدم');

      String? centerId;
      String? role = userRecord['user_type'] as String?;
      Map<String, dynamic>? centerData;

      AppLogger.database('🎭 الدور الأولي: $role');

      AppLogger.database('📍 الخطوة 3/4: البحث عن السنتر المرتبط');

      // أ. البحث كـ Admin
      AppLogger.database('🔍 البحث في centers (كـ admin)...');
      try {
        final centerAsAdmin = await SupabaseClientManager.client
            .from('centers')
            .select('id, name, is_active, subscription_plan')
            .eq('admin_user_id', userId)
            .eq('is_active', true)
            .maybeSingle();

        if (centerAsAdmin != null) {
          centerId = centerAsAdmin['id'] as String;
          role = 'center_admin';
          centerData = centerAsAdmin;
          AppLogger.success('✅ تم العثور على السنتر كـ center_admin');
          AppLogger.database('🏢 Center ID: $centerId');
          AppLogger.database('🏢 Center Name: ${centerAsAdmin['name']}');
          AppLogger.database('📦 Center Data:', data: centerData);
        } else {
          AppLogger.info('ℹ️ لم يتم العثور على سنتر كـ admin');
        }
      } catch (e) {
        AppLogger.error('❌ خطأ في البحث في centers', error: e);
      }

      // ب. البحث كـ Student
      if (centerId == null && (role == 'student' || role == null)) {
        AppLogger.database('🔍 البحث في student_enrollments (كـ student)...');
        try {
          final studentEnrollment = await SupabaseClientManager.client
              .from('student_enrollments')
              .select('''
                center_id,
                status,
                centers:center_id (id, name, is_active, subscription_plan)
              ''')
              .eq('student_user_id', userId)
              .eq('status', 'accepted')
              .isFilter('deleted_at', null)
              .limit(1)
              .maybeSingle();

          if (studentEnrollment != null) {
            centerId = studentEnrollment['center_id'] as String;
            role = 'student';
            centerData = studentEnrollment['centers'] as Map<String, dynamic>?;
            AppLogger.success('✅ تم العثور على السنتر كـ student');
            AppLogger.database('🏢 Center ID: $centerId');
            AppLogger.database('📦 Enrollment Data:', data: studentEnrollment);
          } else {
            AppLogger.info('ℹ️ لم يتم العثور على enrollment للطالب');
          }
        } catch (e) {
          AppLogger.error('❌ خطأ في البحث في student_enrollments', error: e);
        }
      }

      // ج. Fallback: Metadata
      if (centerId == null) {
        AppLogger.database('🔍 محاولة الحصول على center_id من Metadata...');
        final user = SupabaseClientManager.auth.currentUser;

        if (user != null) {
          final metadata = user.userMetadata;
          centerId =
              (metadata?['center_id'] ?? metadata?['default_center_id'])
                  as String?;
          role =
              (metadata?['role'] ?? metadata?['user_type'] ?? role) as String?;

          if (centerId != null) {
            AppLogger.success(
              '✅ تم العثور على center_id في Metadata: $centerId',
            );

            try {
              centerData = await SupabaseClientManager.client
                  .from('centers')
                  .select('id, name, is_active, subscription_plan')
                  .eq('id', centerId)
                  .single();
              AppLogger.success('✅ تم جلب بيانات السنتر من Metadata');
              AppLogger.database('📦 Center Data:', data: centerData);
            } catch (e) {
              AppLogger.warning('⚠️ لم يتم جلب بيانات السنتر', data: e);
            }
          } else {
            AppLogger.warning('⚠️ لا يوجد center_id في Metadata');
          }
        }
      }

      AppLogger.database('📍 الخطوة 4/4: إعداد النتيجة النهائية');

      final result = {
        ...userRecord,
        'center_id': centerId,
        'role': role ?? 'guest',
        'center': centerData,
      };

      AppLogger.database(
        '═══════════════════════════════════════════════════════════════',
      );
      if (centerId != null) {
        AppLogger.success('✅ اكتملت عملية جلب البيانات بنجاح');
        AppLogger.success('👤 المستخدم: ${result['full_name']}');
        AppLogger.success('🎭 الدور: ${result['role']}');
        AppLogger.success('🏢 السنتر: $centerId');
      } else {
        AppLogger.warning('⚠️ اكتملت عملية جلب البيانات لكن بدون سنتر');
        AppLogger.warning('👤 المستخدم: ${result['full_name']}');
        AppLogger.warning('🎭 الدور: ${result['role']}');
      }
      AppLogger.database(
        '═══════════════════════════════════════════════════════════════',
      );

      return result;
    } catch (e, stackTrace) {
      AppLogger.error(
        '❌ خطأ في جلب بيانات المستخدم',
        error: e,
        stackTrace: stackTrace,
      );
      return null;
    }
  }

  /// ترجمة رسائل الخطأ
  static String _translateAuthError(String message) {
    if (message.contains('Invalid login credentials')) {
      return 'البريد الإلكتروني أو كلمة المرور غير صحيحة';
    }
    if (message.contains('Email not confirmed')) {
      return 'لم يتم تأكيد البريد الإلكتروني. تحقق من بريدك الإلكتروني';
    }
    if (message.contains('User already registered')) {
      return 'هذا البريد الإلكتروني مسجل بالفعل';
    }
    if (message.contains('Password should be')) {
      return 'كلمة المرور يجب أن تكون 6 أحرف على الأقل';
    }
    if (message.contains('network')) {
      return 'خطأ في الاتصال بالإنترنت';
    }
    return message;
  }

  /// الحصول على المستخدم الحالي مع بياناته
  static Future<Map<String, dynamic>?> getCurrentUserData() async {
    AppLogger.auth('🔍 جلب بيانات المستخدم الحالي');
    final user = SupabaseClientManager.currentUser;

    if (user == null) {
      AppLogger.warning('⚠️ لا يوجد مستخدم مسجل دخول');
      return null;
    }

    // التحقق من تطابق المستخدم المحفوظ
    await isCurrentUserSaved();

    return _fetchUserData(user.id);
  }

  /////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
}
