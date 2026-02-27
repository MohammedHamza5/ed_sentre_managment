import 'package:flutter/foundation.dart';
import '../../../../core/offline/network_monitor.dart';
import '../../../../shared/models/models.dart';
import '../sources/expenses_local_source.dart';
import '../sources/expenses_remote_source.dart';

class ExpensesRepository {
  final ExpensesRemoteSource _remoteSource;
  final ExpensesLocalSource _localSource;
  final NetworkMonitor _networkMonitor;

  static const Duration _cacheTTL = Duration(minutes: 5);

  ExpensesRepository({
    ExpensesRemoteSource? remoteSource,
    ExpensesLocalSource? localSource,
    NetworkMonitor? networkMonitor,
  }) : _remoteSource = remoteSource ?? ExpensesRemoteSource(),
       _localSource = localSource ?? ExpensesLocalSource(),
       _networkMonitor = networkMonitor ?? NetworkMonitor();

  Future<List<Expense>> getExpenses({bool forceRefresh = false}) async {
    final lastCacheTime = await _localSource.getLastCacheTime();
    final isCacheValid = lastCacheTime != null &&
        DateTime.now().difference(lastCacheTime) < _cacheTTL;

    if (!forceRefresh && isCacheValid) {
      final localData = await _localSource.getExpenses();
      if (localData.isNotEmpty) {
        debugPrint('⚡ [ExpensesRepo] Returning cached data (${localData.length})');
        return localData;
      }
    }

    if (!_networkMonitor.isOnline) {
      debugPrint('📴 [ExpensesRepo] Offline: Returning local data');
      return await _localSource.getExpenses();
    }

    try {
      final remoteData = await _remoteSource.getExpenses();
      await _localSource.saveExpenses(remoteData);
      return remoteData;
    } catch (e) {
      debugPrint('❌ [ExpensesRepo] Remote fetch failed: $e');
      return await _localSource.getExpenses();
    }
  }

  Future<List<Expense>> getExpensesByMonth(int month, int year) async {
    if (!_networkMonitor.isOnline) {
      return []; // Return empty for now, or filter local
    }
    return await _remoteSource.getExpensesByMonth(month, year);
  }

  Future<Expense> addExpense(Expense expense) async {
    if (!_networkMonitor.isOnline) {
      throw Exception('Adding expenses is only available online');
    }

    final newExpense = await _remoteSource.addExpense(expense);

    // Optimistic Update
    final currentList = await _localSource.getExpenses();
    currentList.add(newExpense);
    await _localSource.saveExpenses(currentList);

    return newExpense;
  }

  Future<void> deleteExpense(String id) async {
    if (!_networkMonitor.isOnline) {
      throw Exception('Deleting expenses is only available online');
    }

    await _remoteSource.deleteExpense(id);

    // Optimistic Update
    final currentList = await _localSource.getExpenses();
    currentList.removeWhere((e) => e.id == id);
    await _localSource.saveExpenses(currentList);
  }
}


