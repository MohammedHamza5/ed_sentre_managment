import 'package:flutter/foundation.dart';
import '../../../../core/supabase/supabase_client.dart';
import '../../../../core/supabase/auth_service.dart';

class SupportRemoteSource {
  Future<String?> _getCenterId() async {
    final savedCenterId = await AuthService.getSavedCenterId();
    if (savedCenterId != null) return savedCenterId;

    final user = SupabaseClientManager.currentUser;
    if (user == null) return null;
    return user.userMetadata?['center_id'] ??
        user.userMetadata?['default_center_id'];
  }

  Future<String> openSupportTicket({
    required String subject,
    required String description,
    required String category,
    required String priority,
  }) async {
    try {
      final centerId = await _getCenterId();
      if (centerId == null) throw Exception('Center not found');

      final result = await SupabaseClientManager.client.rpc(
        'open_support_ticket',
        params: {
          'p_center_id': centerId,
          'p_subject': subject,
          'p_description': description,
          'p_priority': priority,
          'p_category': category,
        },
      );

      debugPrint('✅ [openSupportTicket] Created ticket: $result');
      return result.toString();
    } catch (e) {
      debugPrint('❌ [openSupportTicket] Error: $e');
      throw Exception('فشل في إنشاء التذكرة: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getCenterTickets() async {
    try {
      final centerId = await _getCenterId();
      if (centerId == null) return [];

      final result = await SupabaseClientManager.client
          .from('support_tickets')
          .select()
          .eq('center_id', centerId)
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(result);
    } catch (e) {
      debugPrint('❌ [getCenterTickets] Error: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>> getTicketDetails(String ticketId) async {
    try {
      final result = await SupabaseClientManager.client.rpc(
        'get_ticket_details',
        params: {'p_ticket_id': ticketId},
      );

      if (result == null || (result as List).isEmpty) {
        throw Exception('Ticket not found');
      }

      return result[0] as Map<String, dynamic>;
    } catch (e) {
      debugPrint('❌ [getTicketDetails] Error: $e');
      throw Exception('فشل في جلب تفاصيل التذكرة: $e');
    }
  }

  Future<void> addTicketReply({
    required String ticketId,
    required String message,
  }) async {
    try {
      final currentUser = SupabaseClientManager.currentUser;
      if (currentUser == null) throw Exception('User not logged in');

      await SupabaseClientManager.client.from('support_messages').insert({
        'ticket_id': ticketId,
        'sender_id': currentUser.id,
        'message': message,
        'is_admin_reply': false,
      });

      debugPrint('✅ [addTicketReply] Reply added');
    } catch (e) {
      debugPrint('❌ [addTicketReply] Error: $e');
      throw Exception('فشل في إرسال الرد: $e');
    }
  }
}


