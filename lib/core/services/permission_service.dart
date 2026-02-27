import 'package:flutter/foundation.dart';
import '../supabase/supabase_client.dart';

/// ═══════════════════════════════════════════════════════════════════════════
/// Permission Service - خدمة الصلاحيات
/// ═══════════════════════════════════════════════════════════════════════════
/// 
/// مسؤولة عن:
/// - جلب صلاحيات المستخدم الحالي
/// - التحقق من الصلاحيات
/// - جلب المجموعات المتاحة للمستخدم
/// ═══════════════════════════════════════════════════════════════════════════

class PermissionService extends ChangeNotifier {
  static final PermissionService _instance = PermissionService._internal();
  factory PermissionService() => _instance;
  PermissionService._internal();

  // State
  String _role = 'guest';
  List<String> _permissions = [];
  List<String> _groupIds = [];
  String? _centerId;
  bool _isLoaded = false;

  // Getters
  String get role => _role;
  List<String> get permissions => List.unmodifiable(_permissions);
  List<String> get groupIds => List.unmodifiable(_groupIds);
  bool get isLoaded => _isLoaded;
  
  // Role checks
  bool get isOwner => _role == 'owner';
  bool get isManager => _role == 'manager' || isOwner;
  bool get isAccountant => _role == 'accountant';
  bool get isCoordinator => _role == 'coordinator';
  bool get isReceptionist => _role == 'receptionist';
  bool get hasAnyRole => _role != 'guest';

  /// ═══════════════════════════════════════════════════════════════════════
  /// تحميل الصلاحيات
  /// ═══════════════════════════════════════════════════════════════════════
  Future<void> loadPermissions(String centerId) async {
    if (_centerId == centerId && _isLoaded) {
      debugPrint('🔐 [PermissionService] Already loaded for center: $centerId');
      return;
    }

    debugPrint('🔐 [PermissionService] Loading permissions for center: $centerId');
    _centerId = centerId;

    try {
      // 1. Get Role
      final roleResult = await SupabaseClientManager.client
          .rpc('get_my_role', params: {'p_center_id': centerId});
      _role = roleResult as String? ?? 'guest';
      debugPrint('🔐 [PermissionService] Role: $_role');

      // 2. Get Permissions
      final permsResult = await SupabaseClientManager.client
          .rpc('get_my_permissions', params: {'p_center_id': centerId});
      _permissions = List<String>.from(permsResult ?? []);
      debugPrint('🔐 [PermissionService] Permissions: ${_permissions.length}');

      // 3. Get Accessible Groups
      final groupsResult = await SupabaseClientManager.client
          .rpc('get_my_groups', params: {'p_center_id': centerId});
      _groupIds = List<String>.from((groupsResult as List?)?.map((e) => e.toString()) ?? []);
      debugPrint('🔐 [PermissionService] Groups: ${_groupIds.length}');

      _isLoaded = true;
      notifyListeners();

    } catch (e) {
      debugPrint('❌ [PermissionService] Error loading permissions: $e');
      // Fallback to owner for legacy users
      _role = 'owner';
      _permissions = [];
      _groupIds = [];
      _isLoaded = true;
      notifyListeners();
    }
  }

  /// ═══════════════════════════════════════════════════════════════════════
  /// التحقق من صلاحية معينة
  /// ═══════════════════════════════════════════════════════════════════════
  bool hasPermission(String permission) {
    // Owner has all permissions
    if (isOwner) return true;
    
    // Check if permission exists
    return _permissions.contains(permission);
  }

  /// التحقق من أي صلاحية من قائمة
  bool hasAnyPermission(List<String> perms) {
    if (isOwner) return true;
    return perms.any((p) => _permissions.contains(p));
  }

  /// التحقق من كل الصلاحيات
  bool hasAllPermissions(List<String> perms) {
    if (isOwner) return true;
    return perms.every((p) => _permissions.contains(p));
  }

  /// ═══════════════════════════════════════════════════════════════════════
  /// التحقق من الوصول لمجموعة معينة
  /// ═══════════════════════════════════════════════════════════════════════
  bool canAccessGroup(String groupId) {
    // Owner/Manager can access all
    if (isOwner || isManager) return true;
    
    // Empty means full access
    if (_groupIds.isEmpty) return true;
    
    return _groupIds.contains(groupId);
  }

  /// فلترة قائمة بناءً على المجموعات المتاحة
  List<T> filterByGroups<T>(List<T> items, String Function(T) getGroupId) {
    if (isOwner || isManager || _groupIds.isEmpty) return items;
    return items.where((item) => _groupIds.contains(getGroupId(item))).toList();
  }

  /// ═══════════════════════════════════════════════════════════════════════
  /// مسح البيانات (عند تسجيل الخروج)
  /// ═══════════════════════════════════════════════════════════════════════
  void clear() {
    debugPrint('🔐 [PermissionService] Clearing...');
    _role = 'guest';
    _permissions = [];
    _groupIds = [];
    _centerId = null;
    _isLoaded = false;
    notifyListeners();
  }

  /// إعادة تحميل
  Future<void> refresh() async {
    if (_centerId != null) {
      _isLoaded = false;
      await loadPermissions(_centerId!);
    }
  }
}

/// ═══════════════════════════════════════════════════════════════════════════
/// Permission Codes - أكواد الصلاحيات
/// ═══════════════════════════════════════════════════════════════════════════

class Permissions {
  // Students
  static const studentsView = 'students.view';
  static const studentsAdd = 'students.add';
  static const studentsEdit = 'students.edit';
  static const studentsDelete = 'students.delete';

  // Teachers
  static const teachersView = 'teachers.view';
  static const teachersAdd = 'teachers.add';
  static const teachersEdit = 'teachers.edit';
  static const teachersDelete = 'teachers.delete';
  static const teachersSalary = 'teachers.salary';

  // Groups
  static const groupsView = 'groups.view';
  static const groupsAdd = 'groups.add';
  static const groupsEdit = 'groups.edit';
  static const groupsDelete = 'groups.delete';

  // Attendance
  static const attendanceView = 'attendance.view';
  static const attendanceTake = 'attendance.take';

  // Schedule
  static const scheduleView = 'schedule.view';
  static const scheduleManage = 'schedule.manage';

  // Payments
  static const paymentsView = 'payments.view';
  static const paymentsAdd = 'payments.add';
  static const paymentsRefund = 'payments.refund';

  // Reports
  static const reportsView = 'reports.view';
  static const reportsExport = 'reports.export';
  static const reportsFinancial = 'reports.financial';

  // Settings
  static const settingsView = 'settings.view';
  static const settingsManage = 'settings.manage';

  // Users & Roles
  static const usersView = 'users.view';
  static const usersInvite = 'users.invite';
  static const usersManage = 'users.manage';
  static const rolesManage = 'roles.manage';

  // Backup
  static const backupCreate = 'backup.create';
  static const backupRestore = 'backup.restore';

  // Messages
  static const messagesView = 'messages.view';
  static const messagesSend = 'messages.send';
}


