import 'package:flutter/foundation.dart';
import '../supabase/supabase_client.dart';

/// ═══════════════════════════════════════════════════════════════════════════
/// Activity Log Service - خدمة تسجيل النشاطات
/// ═══════════════════════════════════════════════════════════════════════════
/// 
/// تسجل كل العمليات المهمة في النظام لأغراض:
/// - المراجعة والتدقيق
/// - تتبع التغييرات
/// - الأمان
/// ═══════════════════════════════════════════════════════════════════════════

class ActivityLogService {
  static final ActivityLogService _instance = ActivityLogService._internal();
  factory ActivityLogService() => _instance;
  ActivityLogService._internal();

  /// ═══════════════════════════════════════════════════════════════════════
  /// تسجيل نشاط
  /// ═══════════════════════════════════════════════════════════════════════
  Future<void> log({
    required String action,
    required String entityType,
    String? entityId,
    String? entityName,
    Map<String, dynamic>? details,
  }) async {
    try {
      await SupabaseClientManager.client.rpc('log_activity', params: {
        'p_action': action,
        'p_entity_type': entityType,
        'p_entity_id': entityId,
        'p_entity_name': entityName,
        'p_details': details,
      });
      
      debugPrint('📝 [ActivityLog] $action $entityType: $entityName');
    } catch (e) {
      // Don't throw - logging should not break the app
      debugPrint('⚠️ [ActivityLog] Failed to log: $e');
    }
  }

  /// ═══════════════════════════════════════════════════════════════════════
  /// Helper Methods - طرق مساعدة
  /// ═══════════════════════════════════════════════════════════════════════

  // Students
  Future<void> logStudentCreated(String id, String name) => log(
    action: ActivityActions.create,
    entityType: EntityTypes.student,
    entityId: id,
    entityName: name,
  );

  Future<void> logStudentUpdated(String id, String name, Map<String, dynamic>? changes) => log(
    action: ActivityActions.update,
    entityType: EntityTypes.student,
    entityId: id,
    entityName: name,
    details: changes,
  );

  Future<void> logStudentDeleted(String id, String name) => log(
    action: ActivityActions.delete,
    entityType: EntityTypes.student,
    entityId: id,
    entityName: name,
  );

  // Teachers
  Future<void> logTeacherCreated(String id, String name) => log(
    action: ActivityActions.create,
    entityType: EntityTypes.teacher,
    entityId: id,
    entityName: name,
  );

  Future<void> logTeacherUpdated(String id, String name) => log(
    action: ActivityActions.update,
    entityType: EntityTypes.teacher,
    entityId: id,
    entityName: name,
  );

  Future<void> logTeacherDeleted(String id, String name) => log(
    action: ActivityActions.delete,
    entityType: EntityTypes.teacher,
    entityId: id,
    entityName: name,
  );

  // Payments
  Future<void> logPaymentRecorded(String id, String studentName, double amount) => log(
    action: ActivityActions.create,
    entityType: EntityTypes.payment,
    entityId: id,
    entityName: studentName,
    details: {'amount': amount},
  );

  Future<void> logPaymentRefunded(String id, String studentName, double amount) => log(
    action: 'refund',
    entityType: EntityTypes.payment,
    entityId: id,
    entityName: studentName,
    details: {'amount': amount},
  );

  // Groups
  Future<void> logGroupCreated(String id, String name) => log(
    action: ActivityActions.create,
    entityType: EntityTypes.group,
    entityId: id,
    entityName: name,
  );

  Future<void> logGroupDeleted(String id, String name) => log(
    action: ActivityActions.delete,
    entityType: EntityTypes.group,
    entityId: id,
    entityName: name,
  );

  // Attendance
  Future<void> logAttendanceTaken(String groupId, String groupName, int count) => log(
    action: 'take',
    entityType: EntityTypes.attendance,
    entityId: groupId,
    entityName: groupName,
    details: {'students_count': count},
  );

  // Auth
  Future<void> logLogin() => log(
    action: ActivityActions.login,
    entityType: EntityTypes.auth,
  );

  Future<void> logLogout() => log(
    action: ActivityActions.logout,
    entityType: EntityTypes.auth,
  );

  // Users & Roles
  Future<void> logUserInvited(String name, String role) => log(
    action: 'invite',
    entityType: EntityTypes.user,
    entityName: name,
    details: {'role': role},
  );

  Future<void> logRoleChanged(String userId, String userName, String oldRole, String newRole) => log(
    action: 'role_change',
    entityType: EntityTypes.user,
    entityId: userId,
    entityName: userName,
    details: {'old_role': oldRole, 'new_role': newRole},
  );

  // Backup
  Future<void> logBackupCreated() => log(
    action: ActivityActions.create,
    entityType: EntityTypes.backup,
  );

  Future<void> logBackupRestored() => log(
    action: 'restore',
    entityType: EntityTypes.backup,
  );

  /// ═══════════════════════════════════════════════════════════════════════
  /// جلب سجل النشاطات
  /// ═══════════════════════════════════════════════════════════════════════
  Future<List<Map<String, dynamic>>> getRecentLogs({
    String? centerId,
    int limit = 50,
  }) async {
    try {
      final response = await SupabaseClientManager.client
          .from('activity_logs')
          .select('*')
          .order('created_at', ascending: false)
          .limit(limit);
      
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('❌ [ActivityLog] Failed to fetch logs: $e');
      return [];
    }
  }
}

/// ═══════════════════════════════════════════════════════════════════════════
/// Activity Actions - أنواع الأنشطة
/// ═══════════════════════════════════════════════════════════════════════════

class ActivityActions {
  static const create = 'create';
  static const update = 'update';
  static const delete = 'delete';
  static const login = 'login';
  static const logout = 'logout';
}

/// ═══════════════════════════════════════════════════════════════════════════
/// Entity Types - أنواع الكيانات
/// ═══════════════════════════════════════════════════════════════════════════

class EntityTypes {
  static const student = 'student';
  static const teacher = 'teacher';
  static const group = 'group';
  static const payment = 'payment';
  static const attendance = 'attendance';
  static const user = 'user';
  static const role = 'role';
  static const backup = 'backup';
  static const auth = 'auth';
}


