import 'package:flutter/foundation.dart';
import '../../../../core/supabase/supabase_client.dart';
import '../../../../shared/models/models.dart';
import '../../../../shared/data/mappers.dart';
import '../../../../core/supabase/auth_service.dart';

class ExpensesRemoteSource {
  Future<String?> _getCenterId() async {
    final savedCenterId = await AuthService.getSavedCenterId();
    if (savedCenterId != null) return savedCenterId;

    final user = SupabaseClientManager.currentUser;
    if (user == null) return null;
    return user.userMetadata?['center_id'] ??
        user.userMetadata?['default_center_id'];
  }

  Future<List<Expense>> getExpenses() async {
    final centerId = await _getCenterId();
    if (centerId == null) throw Exception('Center ID not found');

    try {
      final response = await SupabaseClientManager.client
          .from('expenses')
          .select()
          .eq('center_id', centerId)
          .order('date', ascending: false);

      return (response as List).map((json) {
        return ExpenseMapper.fromSupabase(json);
      }).toList();
    } catch (e) {
      debugPrint('❌ [ExpensesRemote] Error: $e');
      rethrow;
    }
  }

  Future<List<Expense>> getExpensesByMonth(int month, int year) async {
    final centerId = await _getCenterId();
    if (centerId == null) throw Exception('Center ID not found');

    try {
      // Calculate start and end date for the month
      final startDate = DateTime(year, month, 1);
      final endDate = DateTime(year, month + 1, 0, 23, 59, 59);

      final response = await SupabaseClientManager.client
          .from('expenses')
          .select()
          .eq('center_id', centerId)
          .gte('date', startDate.toIso8601String())
          .lte('date', endDate.toIso8601String())
          .order('date', ascending: false);

      return (response as List).map((json) {
        return ExpenseMapper.fromSupabase(json);
      }).toList();
    } catch (e) {
      debugPrint('❌ [ExpensesRemote] getExpensesByMonth Error: $e');
      return [];
    }
  }

  Future<Expense> addExpense(Expense expense) async {
    final centerId = await _getCenterId();
    if (centerId == null) throw Exception('Center ID not found');

    try {
      final data = ExpenseMapper.toSupabase(expense, centerId: centerId);
      // Let DB generate ID if empty
      if (expense.id.isEmpty) {
        data.remove('id');
      }

      final response = await SupabaseClientManager.client
          .from('expenses')
          .insert(data)
          .select()
          .single();

      return ExpenseMapper.fromSupabase(response);
    } catch (e) {
      debugPrint('❌ [ExpensesRemote] Add Error: $e');
      rethrow;
    }
  }

  Future<void> deleteExpense(String id) async {
    try {
      await SupabaseClientManager.client
          .from('expenses')
          .delete()
          .eq('id', id);
    } catch (e) {
      debugPrint('❌ [ExpensesRemote] Delete Error: $e');
      rethrow;
    }
  }
}


