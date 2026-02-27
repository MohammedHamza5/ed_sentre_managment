import 'package:flutter/foundation.dart';
import '../../../../core/supabase/supabase_client.dart';

class NotificationsRemoteSource {
  Future<List<Map<String, dynamic>>> getNotifications({int limit = 50}) async {
    try {
      final result = await SupabaseClientManager.client.rpc(
        'get_my_notifications',
        params: {'p_limit': limit},
      );

      return List<Map<String, dynamic>>.from(result);
    } catch (e) {
      debugPrint('❌ [getNotifications] Error: $e');
      return [];
    }
  }

  Future<void> markNotificationRead(String id) async {
    try {
      await SupabaseClientManager.client.rpc(
        'mark_notification_read',
        params: {'p_notification_id': id},
      );
    } catch (e) {
      debugPrint('❌ [markNotificationRead] Error: $e');
    }
  }

  Future<void> markAllNotificationsRead() async {
    try {
      await SupabaseClientManager.client.rpc('mark_all_notifications_read');
    } catch (e) {
      debugPrint('❌ [markAllNotificationsRead] Error: $e');
    }
  }

  Future<int> getUnreadNotificationsCount() async {
    try {
      final result = await SupabaseClientManager.client.rpc(
        'get_unread_notifications_count',
      );
      return result as int;
    } catch (e) {
      debugPrint('❌ [getUnreadNotificationsCount] Error: $e');
      return 0;
    }
  }

  Future<void> runSmartNotificationChecks() async {
    try {
      // Check overdue payments
      await SupabaseClientManager.client.rpc('check_overdue_payments');
      debugPrint(
        '✅ [runSmartNotificationChecks] Overdue payments check completed',
      );

      // Check consecutive absences
      await SupabaseClientManager.client.rpc('check_consecutive_absences');
      debugPrint(
        '✅ [runSmartNotificationChecks] Consecutive absences check completed',
      );
    } catch (e) {
      debugPrint('⚠️ [runSmartNotificationChecks] Warning: $e');
    }
  }
}


