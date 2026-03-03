import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../supabase/supabase_client.dart';
import '../../shared/models/billing_models.dart';

/// Center Provider - manages current center data
/// يدير بيانات المركز الحالي المسجل
class CenterProvider extends ChangeNotifier {
  String? _centerId;
  Map<String, dynamic>? _centerData;
  bool _isLoading = false;
  String? _error;
  bool _isInitialized = false;
  BillingConfig _billingConfig = const BillingConfig();
  StreamSubscription<AuthState>? _authSubscription;
  String? _lastUserId; // لتتبع تغيير المستخدم

  String? get centerId => _centerId;
  Map<String, dynamic>? get centerData => _centerData;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasCenter => _centerId != null && _centerId!.isNotEmpty;
  bool get isInitialized => _isInitialized;

  // Center Information Getters
  String get centerName => _centerData?['name'] ?? 'السنتر';
  String get centerAddress => _centerData?['address'] ?? '';
  String get centerCity => _centerData?['city'] ?? '';
  String get centerPhone => _centerData?['phone'] ?? '';
  String get centerEmail => _centerData?['email'] ?? '';
  String get licenseNumber => _centerData?['license_number'] ?? '';
  String get subscriptionType => _centerData?['subscription_type'] ?? 'basic';
  bool get isActive => _centerData?['is_active'] ?? false;

  int get studentCount => _centerData?['student_count'] ?? 0;
  int get teacherCount => _centerData?['teacher_count'] ?? 0;
  int get courseCount => _centerData?['course_count'] ?? 0;
  int get groupCount => _centerData?['group_count'] ?? 0;

  // Lifecycle & Status Getters
  String get approvalStatus =>
      _centerData?['approval_status'] ??
      (_centerData?['is_active'] == true ? 'approved' : 'rejected');
  String get freezeReason => _centerData?['freeze_reason'] ?? '';
  String get rejectionReason => _centerData?['rejection_reason'] ?? '';
  String get terminationDeletionDate =>
      _centerData?['termination_data_deletion_date'] ?? '';

  /// تحديث العدادات فقط (أسرع من reload كامل)
  Future<void> refreshCounts() async {
    if (_centerId == null) return;

    try {
      // 🚀 تنفيذ متوازي بدلاً من تسلسلي - أسرع 4 مرات!
      final results = await Future.wait([
        SupabaseClientManager.client
            .from('student_enrollments')
            .select('id')
            .eq('center_id', _centerId!)
            .count(CountOption.exact),
        SupabaseClientManager.client
            .from('teacher_enrollments')
            .select('id')
            .eq('center_id', _centerId!)
            .eq('employment_status', 'active')
            .count(CountOption.exact),
        SupabaseClientManager.client
            .from('courses')
            .select('id')
            .eq('center_id', _centerId!)
            .count(CountOption.exact),
        SupabaseClientManager.client
            .from('groups')
            .select('id')
            .eq('center_id', _centerId!)
            .eq('is_active', true)
            .count(CountOption.exact),
      ]);

      _centerData ??= {};
      _centerData!['student_count'] = results[0].count;
      _centerData!['teacher_count'] = results[1].count;
      _centerData!['course_count'] = results[2].count;
      _centerData!['group_count'] = results[3].count;

      debugPrint(
        '✅ [CenterProvider] Counts refreshed: S=$studentCount, T=$teacherCount, C=$courseCount, G=$groupCount',
      );
      notifyListeners();
    } catch (e) {
      debugPrint('⚠️ [CenterProvider] Failed to refresh counts: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Billing Configuration Getters (نظام الدفع)
  // ═══════════════════════════════════════════════════════════════════════════

  BillingConfig get billingConfig => _billingConfig;
  BillingType get billingType => _billingConfig.billingType;
  MonthlyPaymentMode get monthlyPaymentMode =>
      _billingConfig.monthlyPaymentMode;
  int get sessionsPerCycle => _billingConfig.sessionsPerCycle;
  int get graceSessions => _billingConfig.graceSessions;
  int get maxDebtSessions => _billingConfig.maxDebtSessions;
  bool get isPerSessionBilling => _billingConfig.isPerSession;
  bool get isMonthlyBilling => _billingConfig.isMonthly;
  bool get isMixedBilling => _billingConfig.isMixed;

  /// Initialize center from current user
  Future<void> initialize() async {
    // إعداد listener للـ Auth مرة واحدة فقط
    _authSubscription ??= SupabaseClientManager.onAuthStateChange.listen((
      data,
    ) {
      final event = data.event;
      if (event == AuthChangeEvent.signedOut) {
        // عند تسجيل الخروج: امسح كل البيانات
        debugPrint('🔴 [CenterProvider] Auth SignedOut - clearing data');
        clear();
      } else if (event == AuthChangeEvent.signedIn) {
        // عند تسجيل الدخول: تحقق من تغيير المستخدم
        final newUserId = data.session?.user.id;
        if (newUserId != null && newUserId != _lastUserId) {
          debugPrint(
            '🟢 [CenterProvider] New user detected: $newUserId (was: $_lastUserId)',
          );
          reinitialize();
        }
      }
    });

    if (_isInitialized && _centerId != null) return;

    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final user = SupabaseClientManager.currentUser;
      if (user == null) {
        _error = 'User not authenticated';
        _isLoading = false;
        _isInitialized = true;
        notifyListeners();
        return;
      }

      final userId = user.id;
      _lastUserId = userId; // تتبع المستخدم الحالي
      debugPrint('🔍 Looking for center for user: $userId');

      // Step 1: Try to get center_id from centers table (user is admin)
      try {
        final centerAsAdmin = await SupabaseClientManager.client
            .from('centers')
            .select('id')
            .eq('admin_user_id', userId)
            .eq('is_active', true)
            .limit(1)
            .maybeSingle();

        if (centerAsAdmin != null) {
          _centerId = centerAsAdmin['id'] as String?;
          debugPrint('✅ Found center as admin: $_centerId');
        }
      } catch (e) {
        debugPrint('⚠️ centers query failed: $e');
      }

      // Step 2: If not admin, try to get from teacher_enrollments
      if (_centerId == null || _centerId!.isEmpty) {
        try {
          final teacherEnrollment = await SupabaseClientManager.client
              .from('teacher_enrollments')
              .select('center_id')
              .eq('teacher_user_id', userId)
              .eq('employment_status', 'active')
              .limit(1)
              .maybeSingle();

          if (teacherEnrollment != null) {
            _centerId = teacherEnrollment['center_id'] as String?;
            debugPrint('✅ Found center as teacher: $_centerId');
          }
        } catch (e) {
          debugPrint('⚠️ teacher_enrollments query failed: $e');
        }
      }

      // Step 3: If still not found, try student_enrollments
      if (_centerId == null || _centerId!.isEmpty) {
        try {
          final studentEnrollment = await SupabaseClientManager.client
              .from('student_enrollments')
              .select('center_id')
              .eq('student_user_id', userId)
              .limit(1)
              .maybeSingle();

          if (studentEnrollment != null) {
            _centerId = studentEnrollment['center_id'] as String?;
            debugPrint('✅ Found center as student: $_centerId');
          }
        } catch (e) {
          debugPrint('⚠️ student_enrollments query failed: $e');
        }
      }

      // Step 4: Try user metadata as fallback
      if (_centerId == null || _centerId!.isEmpty) {
        final metadata = user.userMetadata;
        _centerId = metadata?['center_id'] ?? metadata?['default_center_id'];
        if (_centerId != null && _centerId!.isNotEmpty) {
          debugPrint('✅ Found center from metadata: $_centerId');
        }
      }

      // Step 4: Load center data if we have a center_id
      if (_centerId != null && _centerId!.isNotEmpty) {
        await loadCenterData();
      } else {
        debugPrint('❌ No center assigned to user');
        _error = 'No center assigned to user';
      }

      _isLoading = false;
      _isInitialized = true;
      notifyListeners();
    } catch (e) {
      debugPrint('❌ Error initializing center: $e');
      _error = e.toString();
      _isLoading = false;
      _isInitialized = true;
      notifyListeners();
    }
  }

  // Notifications
  int _unreadNotificationsCount = 0;
  int get unreadNotificationsCount => _unreadNotificationsCount;

  Future<void> loadUnreadNotificationsCount() async {
    if (_centerId == null) return;
    try {
      final userId = SupabaseClientManager.currentUser?.id;
      if (userId == null) return;

      final result = await SupabaseClientManager.client.rpc(
        'get_unread_notifications_count',
      );
      _unreadNotificationsCount = result as int;
      notifyListeners();
    } catch (e) {
      debugPrint('⚠️ Error loading notification count: $e');
    }
  }

  void updateUnreadCount(int count) {
    _unreadNotificationsCount = count;
    notifyListeners();
  }

  // Permissions & Roles
  List<String> _permissions = [];
  String _role = 'owner'; // Default to owner for now

  List<String> get permissions => _permissions;
  String get role => _role;
  bool get isOwner => _role == 'owner';
  bool get isManager => _role == 'manager' || _role == 'owner';

  bool hasPermission(String permissionCode) {
    if (_role == 'owner') return true; // Owner has all permissions
    if (_permissions.isEmpty) return false;
    return _permissions.contains(permissionCode);
  }

  /// Load user role and permissions for this center
  Future<void> _loadRoleAndPermissions() async {
    if (_centerId == null) return;

    try {
      final userId = SupabaseClientManager.currentUser?.id;
      if (userId == null) return;

      // 1. Get Role using RPC
      try {
        final roleResult = await SupabaseClientManager.client.rpc(
          'get_my_role',
          params: {'p_center_id': _centerId!},
        );

        if (roleResult != null) {
          _role = roleResult as String;
          debugPrint('🔐 Loaded User Role: $_role');
        }
      } catch (e) {
        debugPrint('⚠️ Error loading role (fallback to owner): $e');
        _role = 'owner'; // Fallback for legacy users
      }

      // 2. Get Permissions using RPC
      try {
        final permsResult = await SupabaseClientManager.client.rpc(
          'get_my_permissions',
          params: {'p_center_id': _centerId!},
        );

        if (permsResult != null) {
          _permissions = List<String>.from(permsResult);
          debugPrint('🔐 Loaded ${_permissions.length} permissions');
        }
      } catch (e) {
        debugPrint('⚠️ Error loading permissions: $e');
        _permissions = [];
      }
    } catch (e) {
      debugPrint('⚠️ Error loading role/permissions: $e');
      _role = 'owner';
      _permissions = [];
    }
  }

  /// Load center data from database
  Future<void> loadCenterData() async {
    if (_centerId == null || _centerId!.isEmpty) return;

    try {
      _isLoading = true;
      notifyListeners();

      final response = await SupabaseClientManager.client
          .from('centers')
          .select('*')
          .eq('id', _centerId!)
          .maybeSingle();

      if (response != null) {
        _centerData = response;

        // Load Billing Config
        if (response['billing_config'] != null) {
          _billingConfig = BillingConfig.fromJson(
            response['billing_config'] as Map<String, dynamic>,
          );
          debugPrint(
            '✅ Billing config loaded: ${_billingConfig.billingTypeArabic}',
          );
        }

        // Load Permissions in parallel with counts
        await _loadRoleAndPermissions();
        // Load Notifications Count
        loadUnreadNotificationsCount();

        // Fetch live counts
        try {
          final studentCountResponse = await SupabaseClientManager.client
              .from('student_enrollments')
              .select('id')
              .eq('center_id', _centerId!)
              .count(CountOption.exact);

          final teacherCountResponse = await SupabaseClientManager.client
              .from('teacher_enrollments')
              .select('id')
              .eq('center_id', _centerId!)
              .eq('employment_status', 'active') // Only active teachers
              .count(CountOption.exact);

          final courseCountResponse = await SupabaseClientManager.client
              .from('courses')
              .select('id')
              .eq('center_id', _centerId!)
              .count(CountOption.exact);

          _centerData!['student_count'] = studentCountResponse.count;
          _centerData!['teacher_count'] = teacherCountResponse.count;
          _centerData!['course_count'] = courseCountResponse.count;

          debugPrint(
            '✅ Live counts loaded: Students=${studentCountResponse.count}, Teachers=${teacherCountResponse.count}',
          );
        } catch (e) {
          debugPrint('⚠️ Failed to fetch live counts: $e');
        }

        _error = null;
        debugPrint('✅ Center data loaded: ${_centerData?['name']}');
      } else {
        debugPrint('⚠️ Center not found with id: $_centerId');
        _error = 'Center not found';
      }
    } catch (e) {
      debugPrint('❌ Error loading center data: $e');
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Update center information
  Future<bool> updateCenterInfo({
    String? name,
    String? address,
    String? city,
    String? phone,
    String? email,
    String? licenseNumber,
    String? subscriptionType,
  }) async {
    if (_centerId == null) {
      _error = 'No center ID';
      return false;
    }

    try {
      _isLoading = true;
      notifyListeners();

      final updates = <String, dynamic>{};
      if (name != null) updates['name'] = name;
      if (address != null) updates['address'] = address;
      if (city != null) updates['city'] = city;
      if (phone != null) updates['phone'] = phone;
      if (email != null) updates['email'] = email;
      if (licenseNumber != null) updates['license_number'] = licenseNumber;
      if (subscriptionType != null)
        updates['subscription_type'] = subscriptionType;

      if (updates.isNotEmpty) {
        updates['updated_at'] = DateTime.now().toIso8601String();

        await SupabaseClientManager.client
            .from('centers')
            .update(updates)
            .eq('id', _centerId!);

        // Reload data
        await loadCenterData();

        debugPrint('✅ Center info updated successfully');
        return true;
      }

      return false;
    } catch (e) {
      debugPrint('❌ Error updating center: $e');
      _error = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Refresh center data
  Future<void> refresh() async {
    await loadCenterData();
  }

  /// Reinitialize center (call when user changes)
  /// إعادة تهيئة المركز (يُستدعى عند تغيير المستخدم)
  Future<void> reinitialize() async {
    _isInitialized = false;
    _centerId = null;
    _centerData = null;
    _error = null;
    _permissions = [];
    _billingConfig = const BillingConfig();
    await initialize();
  }

  /// Clear center data (on logout)
  void clear() {
    _centerId = null;
    _centerData = null;
    _permissions = [];
    _billingConfig = const BillingConfig();
    _error = null;
    _isLoading = false;
    _isInitialized = false;
    notifyListeners();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Billing Configuration Methods (نظام الدفع)
  // ═══════════════════════════════════════════════════════════════════════════

  /// تحديث إعدادات نظام الدفع
  Future<bool> updateBillingConfig(BillingConfig newConfig) async {
    if (_centerId == null) {
      _error = 'No center ID';
      return false;
    }

    try {
      _isLoading = true;
      notifyListeners();

      // استخدام RPC إذا كانت متوفرة، وإلا تحديث مباشر
      try {
        await SupabaseClientManager.client.rpc(
          'update_center_billing_config',
          params: {
            'p_center_id': _centerId!,
            'p_billing_type': newConfig.billingType.name == 'perSession'
                ? 'per_session'
                : newConfig.billingType.name,
            'p_monthly_payment_mode':
                newConfig.monthlyPaymentMode == MonthlyPaymentMode.calendarMonth
                ? 'calendar_month'
                : 'session_count',
            'p_sessions_per_cycle': newConfig.sessionsPerCycle,
            'p_grace_sessions': newConfig.graceSessions,
            'p_max_debt_sessions': newConfig.maxDebtSessions,
          },
        );
      } catch (e) {
        // Fallback: تحديث مباشر
        debugPrint('⚠️ RPC failed, using direct update: $e');
        await SupabaseClientManager.client
            .from('centers')
            .update({
              'billing_config': newConfig.toJson(),
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('id', _centerId!);
      }

      _billingConfig = newConfig;

      // Reload data
      await loadCenterData();

      debugPrint('✅ Billing config updated: ${newConfig.billingTypeArabic}');
      return true;
    } catch (e) {
      debugPrint('❌ Error updating billing config: $e');
      _error = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    _authSubscription = null;
    super.dispose();
  }
}
