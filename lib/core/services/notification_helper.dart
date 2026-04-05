import 'package:flutter/foundation.dart';

import '../supabase/supabase_client.dart';

/// NotificationHelper — Admin App
///
/// فئة مساعدة تُسهّل إنشاء إشعارات من أي مكان في التطبيق.
/// كل دالة تقوم بـ INSERT في جدول notifications
/// والـ Trigger يتكفل بإرسال Push عبر Edge Function.
class NotificationHelper {
  NotificationHelper._();

  static final _client = SupabaseClientManager.client;

  // ═══════════════════════════════════════════════════════════════════════════
  // إشعارات تسجيل الطلاب والمجموعات
  // ═══════════════════════════════════════════════════════════════════════════

  /// إشعار: تم تسجيل طالب في سنتر
  static Future<void> notifyStudentEnrolled({
    required String studentUserId,
    required String centerName,
    required String centerId,
  }) async {
    await _createNotification(
      userId: studentUserId,
      centerId: centerId,
      title: 'تم تسجيلك في سنتر $centerName',
      body: 'مرحباً بك! تم تسجيلك بنجاح في $centerName',
      type: 'enrollment',
      targetApp: 'student',
    );
  }

  /// إشعار: تم إضافة طالب لمجموعة
  static Future<void> notifyStudentAddedToGroup({
    required String studentUserId,
    required String groupName,
    required String courseName,
    required String centerId,
  }) async {
    await _createNotification(
      userId: studentUserId,
      centerId: centerId,
      title: 'تم إضافتك لمجموعة $groupName',
      body: 'تم إضافتك لمجموعة $groupName في مادة $courseName',
      type: 'group',
      targetApp: 'student',
      data: {'route': '/groups'},
    );
  }

  /// إشعار: تم إزالة طالب من مجموعة
  static Future<void> notifyStudentRemovedFromGroup({
    required String studentUserId,
    required String groupName,
    required String centerId,
  }) async {
    await _createNotification(
      userId: studentUserId,
      centerId: centerId,
      title: 'تم إزالتك من مجموعة $groupName',
      body: 'تم إزالتك من المجموعة. تواصل مع الإدارة للمزيد.',
      type: 'group',
      targetApp: 'student',
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // إشعارات المدفوعات والفواتير
  // ═══════════════════════════════════════════════════════════════════════════

  /// إشعار: فاتورة جديدة
  static Future<void> notifyNewInvoice({
    required String parentUserId,
    required String studentName,
    required double amount,
    required String centerId,
    String? invoiceId,
  }) async {
    await _createNotification(
      userId: parentUserId,
      centerId: centerId,
      title: '💰 فاتورة جديدة',
      body: 'فاتورة جديدة لـ $studentName بقيمة $amount جنيه',
      type: 'payment',
      priority: 'high',
      targetApp: 'parent',
      data: {'route': '/payments', 'invoice_id': invoiceId},
    );
  }

  /// إشعار: تم تسجيل دفعة
  static Future<void> notifyPaymentRecorded({
    required String parentUserId,
    required double amount,
    required String centerId,
  }) async {
    await _createNotification(
      userId: parentUserId,
      centerId: centerId,
      title: '✅ تم تسجيل دفعة',
      body: 'تم تسجيل دفعة بقيمة $amount جنيه بنجاح',
      type: 'payment',
      targetApp: 'parent',
      data: {'route': '/payments'},
    );
  }

  /// إشعار: فاتورة متأخرة
  static Future<void> notifyOverdueInvoice({
    required String parentUserId,
    required double amount,
    required int daysOverdue,
    required String centerId,
  }) async {
    await _createNotification(
      userId: parentUserId,
      centerId: centerId,
      title: '⚠️ فاتورة متأخرة',
      body: 'لديك فاتورة متأخرة بقيمة $amount جنيه ($daysOverdue يوم)',
      type: 'payment',
      priority: 'critical',
      targetApp: 'parent',
      data: {'route': '/payments'},
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // إشعارات الجدول والحصص
  // ═══════════════════════════════════════════════════════════════════════════

  /// إشعار: تغيير جدول حصة (لعدة مستخدمين)
  static Future<void> notifyScheduleChanged({
    required List<String> userIds,
    required String courseName,
    required String centerId,
  }) async {
    if (userIds.isEmpty) return;
    await _createNotificationForUsers(
      userIds: userIds,
      centerId: centerId,
      title: '📅 تغيير في الجدول',
      body: 'تم تغيير موعد حصة $courseName',
      type: 'schedule',
      data: {'route': '/schedule'},
    );
  }

  /// إشعار: إلغاء حصة
  static Future<void> notifyClassCancelled({
    required List<String> userIds,
    required String courseName,
    required String centerId,
  }) async {
    if (userIds.isEmpty) return;
    await _createNotificationForUsers(
      userIds: userIds,
      centerId: centerId,
      title: '🚨 حصة ملغاة',
      body: 'تم إلغاء حصة $courseName اليوم',
      type: 'schedule',
      priority: 'high',
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // إشعارات المعلمين
  // ═══════════════════════════════════════════════════════════════════════════

  /// إشعار: تعيين معلم لمادة
  static Future<void> notifyTeacherAssigned({
    required String teacherUserId,
    required String courseName,
    required String centerId,
  }) async {
    await _createNotification(
      userId: teacherUserId,
      centerId: centerId,
      title: '📚 تم تعيينك لمادة $courseName',
      body: 'تم تعيينك لتدريس $courseName',
      type: 'assignment_role',
      targetApp: 'teacher',
    );
  }

  /// إشعار: تسجيل راتب معلم
  static Future<void> notifyTeacherSalary({
    required String teacherUserId,
    required double amount,
    required String month,
    required String centerId,
  }) async {
    await _createNotification(
      userId: teacherUserId,
      centerId: centerId,
      title: '💰 تم تسجيل راتبك',
      body: 'تم تسجيل راتبك لشهر $month بقيمة $amount جنيه',
      type: 'payment',
      targetApp: 'teacher',
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // إشعارات عامة
  // ═══════════════════════════════════════════════════════════════════════════

  /// إعلان عام لكل السنتر
  static Future<void> sendCenterAnnouncement({
    required String centerId,
    required String title,
    required String body,
  }) async {
    try {
      await _client.rpc(
        'create_notification_for_center',
        params: {
          'p_center_id': centerId,
          'p_title': '📢 $title',
          'p_body': body,
          'p_type': 'announcement',
          'p_target_app': 'all',
        },
      );
    } catch (e) {
      debugPrint('⚠️ [NotificationHelper] Failed to send announcement: $e');
    }
  }

  /// إشعار لمجموعة طلاب
  static Future<void> notifyGroup({
    required String groupId,
    required String title,
    required String body,
    required String type,
    Map<String, dynamic>? data,
  }) async {
    try {
      await _client.rpc(
        'create_notification_for_group',
        params: {
          'p_group_id': groupId,
          'p_title': title,
          'p_body': body,
          'p_type': type,
          'p_data': data ?? {},
          'p_target_app': 'student',
        },
      );
    } catch (e) {
      debugPrint('⚠️ [NotificationHelper] Failed to notify group: $e');
    }
  }

  /// إشعار لأولياء أمور طالب معين
  static Future<void> notifyStudentParents({
    required String studentId,
    required String centerId,
    required String title,
    required String body,
    required String type,
    Map<String, dynamic>? data,
  }) async {
    try {
      await _client.rpc(
        'create_notification_for_student_parents',
        params: {
          'p_student_id': studentId,
          'p_center_id': centerId,
          'p_title': title,
          'p_body': body,
          'p_type': type,
          'p_data': data ?? {},
        },
      );
    } catch (e) {
      debugPrint('⚠️ [NotificationHelper] Failed to notify parents: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // PRIVATE: دوال أساسية
  // ═══════════════════════════════════════════════════════════════════════════

  /// إنشاء إشعار واحد لمستخدم واحد
  static Future<void> _createNotification({
    required String userId,
    required String centerId,
    required String title,
    required String body,
    required String type,
    String priority = 'normal',
    String targetApp = 'all',
    Map<String, dynamic>? data,
  }) async {
    try {
      await _client.from('notifications').insert({
        'user_id': userId,
        'center_id': centerId,
        'sender_id': _client.auth.currentUser?.id,
        'title': title,
        'body': body,
        'type': type,
        'priority': priority,
        'target_app': targetApp,
        'data': data ?? {},
        'is_read': false,
      });
    } catch (e) {
      debugPrint('⚠️ [NotificationHelper] Failed to create notification: $e');
    }
  }

  /// إنشاء إشعار لعدة مستخدمين
  static Future<void> _createNotificationForUsers({
    required List<String> userIds,
    required String centerId,
    required String title,
    required String body,
    required String type,
    String priority = 'normal',
    String targetApp = 'all',
    Map<String, dynamic>? data,
  }) async {
    try {
      await _client.rpc(
        'create_notification_for_users',
        params: {
          'p_user_ids': userIds,
          'p_center_id': centerId,
          'p_title': title,
          'p_body': body,
          'p_type': type,
          'p_priority': priority,
          'p_target_app': targetApp,
          'p_data': data ?? {},
        },
      );
    } catch (e) {
      debugPrint(
        '⚠️ [NotificationHelper] Failed to create bulk notification: $e',
      );
    }
  }
}
