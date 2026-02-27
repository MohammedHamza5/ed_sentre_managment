import 'package:flutter/foundation.dart';
import '../../../../core/offline/network_monitor.dart';
import '../../../../shared/models/models.dart';
import '../sources/payments_local_source.dart';
import '../sources/payments_remote_source.dart';

class PaymentRepository {
  final PaymentsRemoteSource _remoteSource;
  final PaymentsLocalSource _localSource;
  final NetworkMonitor _networkMonitor;

  static const Duration _cacheTTL = Duration(minutes: 5);

  PaymentRepository({
    PaymentsRemoteSource? remoteSource,
    PaymentsLocalSource? localSource,
    NetworkMonitor? networkMonitor,
  }) : _remoteSource = remoteSource ?? PaymentsRemoteSource(),
       _localSource = localSource ?? PaymentsLocalSource(),
       _networkMonitor = networkMonitor ?? NetworkMonitor();

  Future<List<Payment>> getPayments({bool forceRefresh = false}) async {
    final lastCacheTime = await _localSource.getLastCacheTime();
    final isCacheValid =
        lastCacheTime != null &&
        DateTime.now().difference(lastCacheTime) < _cacheTTL;

    if (!forceRefresh && isCacheValid) {
      final localData = await _localSource.getPayments();
      if (localData.isNotEmpty) {
        debugPrint(
          '⚡ [PaymentRepo] Returning cached data (${localData.length})',
        );
        return localData;
      }
    }

    if (!_networkMonitor.isOnline) {
      debugPrint('📴 [PaymentRepo] Offline: Returning local data');
      return await _localSource.getPayments();
    }

    try {
      final remoteData = await _remoteSource.getPayments();
      await _localSource.savePayments(remoteData);
      return remoteData;
    } catch (e) {
      debugPrint('❌ [PaymentRepo] Remote fetch failed: $e');
      return await _localSource.getPayments();
    }
  }

  Future<List<Payment>> getPaymentsByMonth(int month, int year) async {
    if (!_networkMonitor.isOnline) {
      return []; // Or try to filter from local source? For now, empty or local filter
    }
    return await _remoteSource.getPaymentsByMonth(month, year);
  }

  Future<Payment> addPayment(Payment payment) async {
    if (!_networkMonitor.isOnline) {
      throw Exception('Adding payments is only available online');
    }

    final newPayment = await _remoteSource.addPayment(payment);

    // Optimistic Update
    final currentList = await _localSource.getPayments();
    currentList.add(newPayment);
    await _localSource.savePayments(currentList);

    return newPayment;
  }

  Future<void> updatePayment(Payment payment) async {
    if (!_networkMonitor.isOnline) {
      throw Exception('Updating payments is only available online');
    }

    await _remoteSource.updatePayment(payment);

    // Optimistic Update
    final currentList = await _localSource.getPayments();
    final index = currentList.indexWhere((p) => p.id == payment.id);
    if (index != -1) {
      currentList[index] = payment;
      await _localSource.savePayments(currentList);
    }
  }

  Future<void> deletePayment(String id) async {
    if (!_networkMonitor.isOnline) {
      throw Exception('Deleting payments is only available online');
    }

    await _remoteSource.deletePayment(id);

    // Optimistic Update
    final currentList = await _localSource.getPayments();
    currentList.removeWhere((p) => p.id == id);
    await _localSource.savePayments(currentList);
  }

  /// Records a new payment with associated smart items (Legacy support & Complex logic)
  Future<String> recordComplexPayment({
    required String studentId,
    required double totalAmount,
    required String method,
    required List<PaymentItem> items,
    String? notes,
  }) async {
    if (!_networkMonitor.isOnline) {
      throw Exception('Payment recording is only available online');
    }
    return await _remoteSource.recordComplexPayment(
      studentId: studentId,
      totalAmount: totalAmount,
      method: method,
      items: items,
      notes: notes,
    );
  }

  Future<List<Payment>> getPaymentsByStudent(String studentId) async {
    if (!_networkMonitor.isOnline) {
      return [];
    }
    return await _remoteSource.getPaymentsByStudent(studentId);
  }

  Future<Map<String, dynamic>> getOrCreateStudentInvoice({
    required String studentId,
    required int month,
    required int year,
  }) async {
    if (!_networkMonitor.isOnline) return {};
    return await _remoteSource.getOrCreateStudentInvoice(
      studentId: studentId,
      month: month,
      year: year,
    );
  }

  Future<Map<String, double>> getStudentBalance(String studentId) async {
    if (!_networkMonitor.isOnline) {
      return {'total_due': 0.0, 'total_paid': 0.0, 'balance': 0.0};
    }
    return await _remoteSource.getStudentBalance(studentId);
  }

  Future<Map<String, dynamic>> getStudentAccountStatement(
    String studentId,
  ) async {
    if (!_networkMonitor.isOnline) return {};
    return await _remoteSource.getStudentAccountStatement(studentId);
  }

  Future<void> addPaymentToInvoice({
    required String invoiceId,
    required double amount,
    required String paymentMethod,
    String? notes,
  }) async {
    if (!_networkMonitor.isOnline) {
      throw Exception('Payment operations are only available online');
    }

    debugPrint('⚡ [PaymentRepo] calling addPaymentToInvoice');
    debugPrint('   Amount: $amount, Method: $paymentMethod');

    await _remoteSource.addPaymentToInvoice(
      invoiceId: invoiceId,
      amount: amount,
      paymentMethod: paymentMethod,
      notes: notes,
    );
  }

  Future<void> recalculateInvoice(String invoiceId) async {
    if (!_networkMonitor.isOnline) return;
    await _remoteSource.recalculateInvoice(invoiceId);
  }

  /// جلب تقرير الإيرادات الذكي للمركز
  Future<Map<String, dynamic>> getCenterRevenueReport({
    int? month,
    int? year,
  }) async {
    if (!_networkMonitor.isOnline) return {};
    return await _remoteSource.getCenterRevenueReport(month: month, year: year);
  }
}
