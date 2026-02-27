import 'package:flutter/foundation.dart';
import '../monitoring/app_logger.dart';
import '../supabase/supabase_client.dart';

/// User Role Types
enum UserRole {
  superAdmin,
  centerAdmin,
  accountant,
  coordinator,
  teacher,
  student,
  parent,
  guest,
}

/// RoleProvider - مع نظام تتبع شامل
class RoleProvider extends ChangeNotifier {
  UserRole _currentRole = UserRole.guest;
  String? _currentCenterId;
  Map<String, dynamic>? _userMetadata;
  Map<String, dynamic>? _userData;

  UserRole get currentRole => _currentRole;
  String? get currentCenterId => _currentCenterId;
  Map<String, dynamic>? get userMetadata => _userMetadata;
  Map<String, dynamic>? get userData => _userData;

  String get userFullName => _userData?['full_name'] as String? ?? 'مستخدم';
  String? get userEmail => _userData?['email'] as String?;
  String? get userPhone => _userData?['phone'] as String?;
  bool get isAuthenticated => _currentRole != UserRole.guest;
  bool get isSuperAdmin => _currentRole == UserRole.superAdmin;
  bool get isCenterAdmin => _currentRole == UserRole.centerAdmin;

  /// ═══════════════════════════════════════════════════════════════
  /// تهيئة الدور من بيانات المستخدم
  /// Initialize Role from User Data
  /// ═══════════════════════════════════════════════════════════════
  Future<void> initialize([Map<String, dynamic>? userData]) async {
    AppLogger.info('═════════════════════════════════════════════════════');
    AppLogger.info('🔵 بدء تهيئة RoleProvider');
    AppLogger.info('═════════════════════════════════════════════════════');

    try {
      // ─────────────────────────────────────────────────────────────
      // الخطوة 1: الحصول على المستخدم الحالي
      // ─────────────────────────────────────────────────────────────
      AppLogger.info('📍 الخطوة 1/5: الحصول على المستخدم الحالي');

      final user = SupabaseClientManager.currentUser;
      if (user == null) {
        AppLogger.warning('⚠️ لا يوجد مستخدم مسجل دخول');
        _currentRole = UserRole.guest;
        _currentCenterId = null;
        _userMetadata = null;
        _userData = null;
        notifyListeners();
        return;
      }

      AppLogger.success('✅ وجد مستخدم: ${user.id}');

      // ─────────────────────────────────────────────────────────────
      // الخطوة 2: حفظ Metadata
      // ─────────────────────────────────────────────────────────────
      AppLogger.info('📍 الخطوة 2/5: حفظ User Metadata');

      _userMetadata = user.userMetadata;
      _userData = userData;

      AppLogger.database('📦 User Metadata:', data: _userMetadata);
      AppLogger.database('📦 User Data:', data: _userData);

      // ─────────────────────────────────────────────────────────────
      // الخطوة 3: استخراج الدور (Role)
      // ─────────────────────────────────────────────────────────────
      AppLogger.info('📍 الخطوة 3/5: استخراج الدور من البيانات');

      final roleStr =
          _userData?['role'] as String? ??
          _userMetadata?['role'] as String? ??
          _userMetadata?['user_type'] as String?;

      AppLogger.info('📝 Role String: $roleStr');

      _currentRole = _parseRole(roleStr);
      AppLogger.success('✅ تم تحديد الدور: $_currentRole');

      // ─────────────────────────────────────────────────────────────
      // الخطوة 4: استخراج معرف المركز (Center ID)
      // ─────────────────────────────────────────────────────────────
      AppLogger.info('📍 الخطوة 4/5: استخراج معرف المركز');

      _currentCenterId =
          _userData?['center_id'] as String? ??
          _userMetadata?['center_id'] as String? ??
          _userMetadata?['default_center_id'] as String?;

      if (_currentCenterId != null) {
        AppLogger.success('✅ وجد Center ID: $_currentCenterId');
      } else {
        AppLogger.warning('⚠️ لا يوجد Center ID');
      }

      // ─────────────────────────────────────────────────────────────
      // الخطوة 5: إخطار المستمعين
      // ─────────────────────────────────────────────────────────────
      AppLogger.info('📍 الخطوة 5/5: إخطار المستمعين');

      notifyListeners();
      AppLogger.success('✅ تم إخطار المستمعين بنجاح');

      // ─────────────────────────────────────────────────────────────
      // ملخص النتائج
      // ─────────────────────────────────────────────────────────────
      AppLogger.info('═════════════════════════════════════════════════════');
      AppLogger.success('✅ تهيئة RoleProvider نجحت');
      AppLogger.success('👤 المستخدم: $userFullName');
      AppLogger.success('📧 البريد: $userEmail');
      AppLogger.success('🎭 الدور: $_currentRole');
      AppLogger.success('🏢 المركز: $_currentCenterId');
      AppLogger.info('═════════════════════════════════════════════════════');

    } catch (e, stackTrace) {
      AppLogger.error(
        '❌ خطأ في تهيئة RoleProvider',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  /// Parse role string to UserRole enum
  UserRole _parseRole(String? roleStr) {
    AppLogger.info('🔍 تحليل الدور: $roleStr');

    if (roleStr == null) {
      AppLogger.warning('⚠️ الدور null، استخدام guest');
      return UserRole.guest;
    }

    final role = switch (roleStr.toLowerCase()) {
      'super_admin' || 'superadmin' => UserRole.superAdmin,
      'center_admin' || 'centeradmin' || 'admin' => UserRole.centerAdmin,
      'accountant' => UserRole.accountant,
      'academic_coordinator' || 'coordinator' => UserRole.coordinator,
      'teacher' => UserRole.teacher,
      'student' => UserRole.student,
      'parent' => UserRole.parent,
      _ => UserRole.guest,
    };

    AppLogger.success('✅ الدور المحلل: $role');
    return role;
  }

  /// ═══════════════════════════════════════════════════════════════
  /// مسح الدور (عند تسجيل الخروج)
  /// ═══════════════════════════════════════════════════════════════
  void clear() {
    AppLogger.info('🔵 مسح بيانات RoleProvider');

    _currentRole = UserRole.guest;
    _currentCenterId = null;
    _userMetadata = null;
    _userData = null;

    notifyListeners();
    AppLogger.success('✅ تم مسح بيانات RoleProvider');
  }

  /// التحقق من إمكانية الوصول لمركز معين
  bool canAccessCenter(String centerId) {
    if (isSuperAdmin) {
      AppLogger.info('✅ Super Admin يمكنه الوصول لجميع المراكز');
      return true;
    }

    final canAccess = _currentCenterId == centerId;
    AppLogger.info(
      canAccess
        ? '✅ يمكن الوصول للمركز: $centerId'
        : '❌ لا يمكن الوصول للمركز: $centerId (المركز الحالي: $_currentCenterId)'
    );

    return canAccess;
  }

  /// الحصول على دور المستخدم في مركز معين
  String? getUserRoleInCenter(String centerId) {
    if (_currentCenterId == centerId) {
      final role = _userData?['role'] as String? ??
                  _userMetadata?['role'] as String? ??
                  _userMetadata?['user_type'] as String?;

      AppLogger.info('ℹ️ دور المستخدم في المركز $centerId: $role');
      return role;
    }

    AppLogger.warning('⚠️ المستخدم ليس في المركز $centerId');
    return null;
  }
}


