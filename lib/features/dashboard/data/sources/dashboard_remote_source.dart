import 'package:flutter/foundation.dart';
import '../../../../core/supabase/supabase_client.dart';
import '../../../../core/supabase/auth_service.dart';

class DashboardRemoteSource {
  Future<String?> _getCenterId() async {
    final savedCenterId = await AuthService.getSavedCenterId();
    if (savedCenterId != null) return savedCenterId;

    final user = SupabaseClientManager.currentUser;
    if (user == null) return null;
    return user.userMetadata?['center_id'] ??
        user.userMetadata?['default_center_id'];
  }

  Future<Map<String, dynamic>> getDashboardSummary({String? centerId}) async {
    final effectiveCenterId = centerId ?? await _getCenterId();
    if (effectiveCenterId == null) throw Exception('Center ID not found');

    try {
      final response = await SupabaseClientManager.client.rpc(
        'get_dashboard_summary',
        params: {'p_center_id': effectiveCenterId},
      );
      return response as Map<String, dynamic>;
    } catch (e) {
      debugPrint('❌ [DashboardRemote] Error: $e');
      // If RPC fails, we might want to throw or return empty map?
      // Throwing is better to handle in Repo/Bloc
      rethrow;
    }
  }
}


