import 'package:flutter/foundation.dart';
import '../../../../core/supabase/supabase_client.dart';
import '../../../../shared/models/models.dart';
import '../../../../shared/data/mappers.dart';
import '../../../../core/supabase/auth_service.dart';

class RoomsRemoteSource {
  Future<String?> _getCenterId() async {
    final savedCenterId = await AuthService.getSavedCenterId();
    if (savedCenterId != null) return savedCenterId;

    final user = SupabaseClientManager.currentUser;
    if (user == null) return null;
    return user.userMetadata?['center_id'] ??
        user.userMetadata?['default_center_id'];
  }

  Future<List<Room>> getRooms() async {
    final centerId = await _getCenterId();
    if (centerId == null) throw Exception('Center ID not found');

    try {
      final response = await SupabaseClientManager.client
          .from('classrooms')
          .select()
          .eq('center_id', centerId);

      return (response as List).map((json) {
        return RoomMapper.fromSupabase(json);
      }).toList();
    } catch (e) {
      debugPrint('❌ [RoomsRemote] Error: $e');
      rethrow;
    }
  }

  Future<Room> addRoom(Room room) async {
    final centerId = await _getCenterId();
    if (centerId == null) throw Exception('Center ID not found');

    try {
      final data = {
        'name': room.name,
        'number': room.number,
        'capacity': room.capacity,
        'equipment': room.equipment,
        'status': room.status.name,
        'center_id': centerId,
      };

      final response = await SupabaseClientManager.client
          .from('classrooms')
          .insert(data)
          .select()
          .single();

      return RoomMapper.fromSupabase(response);
    } catch (e) {
      debugPrint('❌ [RoomsRemote] Add Error: $e');
      rethrow;
    }
  }

  Future<void> updateRoom(Room room) async {
    try {
      final data = {
        'name': room.name,
        'number': room.number,
        'capacity': room.capacity,
        'equipment': room.equipment,
        'status': room.status.name,
      };

      await SupabaseClientManager.client
          .from('classrooms')
          .update(data)
          .eq('id', room.id);
    } catch (e) {
      debugPrint('❌ [RoomsRemote] Update Error: $e');
      rethrow;
    }
  }

  Future<void> deleteRoom(String id) async {
    try {
      await SupabaseClientManager.client
          .from('classrooms')
          .delete()
          .eq('id', id);
    } catch (e) {
      debugPrint('❌ [RoomsRemote] Delete Error: $e');
      rethrow;
    }
  }
}


