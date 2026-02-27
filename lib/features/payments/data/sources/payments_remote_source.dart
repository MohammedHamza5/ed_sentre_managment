import 'package:flutter/foundation.dart';
import '../../../../core/supabase/supabase_client.dart';
import '../../../../shared/models/models.dart';
import '../../../../shared/data/mappers.dart';
import '../../../../core/supabase/auth_service.dart';

class PaymentsRemoteSource {
  Future<String?> _getCenterId() async {
    final savedCenterId = await AuthService.getSavedCenterId();
    if (savedCenterId != null) return savedCenterId;

    final user = SupabaseClientManager.currentUser;
    if (user == null) return null;
    return user.userMetadata?['center_id'] ??
        user.userMetadata?['default_center_id'];
  }

  /// Fetch all payments from invoice_payments via student_invoices
  Future<List<Payment>> getPayments() async {
    final centerId = await _getCenterId();
    if (centerId == null) throw Exception('Center ID not found');

    try {
      // Query invoice_payments joined with student_invoices
      final response = await SupabaseClientManager.client
          .from('invoice_payments')
          .select(
            '*, student_invoices!inner(id, student_id, center_id, month, year, total_amount, status)',
          )
          .eq('student_invoices.center_id', centerId)
          .order('paid_at', ascending: false);

      final paymentsData = response as List;

      // Fetch student names for client-side join
      final studentIds = paymentsData
          .map((p) => (p['student_invoices'] as Map?)?['student_id'] as String?)
          .where((id) => id != null)
          .toSet()
          .toList();

      Map<String, String> studentNames = {};
      if (studentIds.isNotEmpty) {
        try {
          final studentsResponse = await SupabaseClientManager.client
              .from('students')
              .select('id, full_name')
              .inFilter('id', studentIds);
          for (var s in (studentsResponse as List)) {
            studentNames[s['id']] = s['full_name'];
          }
        } catch (e) {
          debugPrint('⚠️ Failed to fetch student names: $e');
        }
      }

      return paymentsData.map((json) {
        return PaymentMapper.fromInvoicePayment(json, studentNames);
      }).toList();
    } catch (e) {
      debugPrint('❌ [PaymentsRemote] Error: $e');
      rethrow;
    }
  }

  /// Fetch payments for a specific month from invoice_payments
  Future<List<Payment>> getPaymentsByMonth(int month, int year) async {
    final centerId = await _getCenterId();
    if (centerId == null) throw Exception('Center ID not found');

    try {
      final response = await SupabaseClientManager.client
          .from('invoice_payments')
          .select(
            '*, student_invoices!inner(id, student_id, center_id, month, year, total_amount, status)',
          )
          .eq('student_invoices.center_id', centerId)
          .eq('student_invoices.month', month)
          .eq('student_invoices.year', year)
          .order('paid_at', ascending: false);

      final paymentsData = response as List;

      final studentIds = paymentsData
          .map((p) => (p['student_invoices'] as Map?)?['student_id'] as String?)
          .where((id) => id != null)
          .toSet()
          .toList();

      Map<String, String> studentNames = {};
      if (studentIds.isNotEmpty) {
        try {
          final studentsResponse = await SupabaseClientManager.client
              .from('students')
              .select('id, full_name')
              .inFilter('id', studentIds);
          for (var s in (studentsResponse as List)) {
            studentNames[s['id']] = s['full_name'];
          }
        } catch (e) {
          debugPrint('⚠️ Failed to fetch student names: $e');
        }
      }

      return paymentsData.map((json) {
        return PaymentMapper.fromInvoicePayment(json, studentNames);
      }).toList();
    } catch (e) {
      debugPrint('❌ [PaymentsRemote] getPaymentsByMonth Error: $e');
      return [];
    }
  }

  /// Fetch payments for a specific student from invoice_payments
  Future<List<Payment>> getPaymentsByStudent(String studentId) async {
    final centerId = await _getCenterId();
    if (centerId == null) return [];

    try {
      final response = await SupabaseClientManager.client
          .from('invoice_payments')
          .select(
            '*, student_invoices!inner(id, student_id, center_id, month, year)',
          )
          .eq('student_invoices.student_id', studentId)
          .eq('student_invoices.center_id', centerId)
          .order('paid_at', ascending: false);

      return (response as List).map((json) {
        return PaymentMapper.fromInvoicePayment(json, {});
      }).toList();
    } catch (e) {
      debugPrint('Error getting student payments: $e');
      return [];
    }
  }

  /// Add a payment via the invoice system
  Future<Payment> addPayment(Payment payment) async {
    final centerId = await _getCenterId();
    if (centerId == null) throw Exception('Center ID not found');

    try {
      // Get or create invoice for the current month
      final now = DateTime.now();
      final invoiceData = await getOrCreateStudentInvoice(
        studentId: payment.studentId,
        month: now.month,
        year: now.year,
      );
      final invoiceId = invoiceData['id'] as String;

      // Add payment to invoice via RPC
      await addPaymentToInvoice(
        invoiceId: invoiceId,
        amount: payment.amount,
        paymentMethod: payment.method.name,
        notes: payment.notes,
      );

      // Return the payment with updated info
      return payment.copyWith(id: invoiceId, status: PaymentStatus.paid);
    } catch (e) {
      debugPrint('❌ [PaymentsRemote] Add Error: $e');
      rethrow;
    }
  }

  /// Update a payment in invoice_payments
  Future<void> updatePayment(Payment payment) async {
    try {
      await SupabaseClientManager.client
          .from('invoice_payments')
          .update({
            'amount': payment.amount,
            'payment_method': payment.method.name,
            'notes': payment.notes,
          })
          .eq('id', payment.id);
    } catch (e) {
      debugPrint('❌ [PaymentsRemote] Update Error: $e');
      rethrow;
    }
  }

  /// Delete a payment from invoice_payments
  Future<void> deletePayment(String id) async {
    try {
      await SupabaseClientManager.client
          .from('invoice_payments')
          .delete()
          .eq('id', id);
    } catch (e) {
      debugPrint('❌ [PaymentsRemote] Delete Error: $e');
      rethrow;
    }
  }

  /// Record a payment through the invoice system (replaces legacy complex payment)
  Future<String> recordComplexPayment({
    required String studentId,
    required double totalAmount,
    required String method,
    required List<PaymentItem> items,
    String? notes,
  }) async {
    final centerId = await _getCenterId();
    if (centerId == null) throw Exception('Center ID not found');

    // Get or create invoice for current month
    final now = DateTime.now();
    final invoiceData = await getOrCreateStudentInvoice(
      studentId: studentId,
      month: now.month,
      year: now.year,
    );
    final invoiceId = invoiceData['id'] as String;

    // Build description from items
    final description = items
        .map((item) => '${item.description}: ${item.amount}')
        .join(', ');

    // Add payment to invoice
    await addPaymentToInvoice(
      invoiceId: invoiceId,
      amount: totalAmount,
      paymentMethod: method,
      notes: notes ?? description,
    );

    return invoiceId;
  }

  Future<Map<String, dynamic>> getOrCreateStudentInvoice({
    required String studentId,
    required int month,
    required int year,
  }) async {
    final centerId = await _getCenterId();
    if (centerId == null) throw Exception('Center ID not found');

    try {
      debugPrint('');
      debugPrint(
        '═══════════════════════════════════════════════════════════════',
      );
      debugPrint('📄 [Invoice] جلب فاتورة الطالب');
      debugPrint(
        '═══════════════════════════════════════════════════════════════',
      );
      debugPrint('   🆔 Student ID: $studentId');
      debugPrint('   📅 Period: $month/$year');
      debugPrint('   🏢 Center ID: $centerId');

      final data = await SupabaseClientManager.client.rpc(
        'get_or_create_student_invoice',
        params: {
          'p_student_id': studentId,
          'p_center_id': centerId,
          'p_month': month,
          'p_year': year,
        },
      );

      final invoice = Map<String, dynamic>.from(data as Map);

      // Ensure items is a list
      invoice['items'] =
          (invoice['items'] as List?)
              ?.map((e) => Map<String, dynamic>.from(e as Map))
              .toList() ??
          [];

      debugPrint('');
      debugPrint('📊 [Invoice] === نتيجة الفاتورة ===');
      debugPrint('   👤 اسم الطالب: ${invoice['student_name']}');
      debugPrint('   💰 إجمالي المطلوب: ${invoice['total_amount']} جنيه');
      debugPrint('   💵 المدفوع: ${invoice['paid_amount']} جنيه');
      debugPrint('   📉 المتبقي: ${invoice['remaining']} جنيه');
      debugPrint('   📌 الحالة: ${invoice['status']}');
      debugPrint('');
      debugPrint('   📦 المواد/المجموعات المسجل بها:');
      final items = invoice['items'] as List;
      if (items.isEmpty) {
        debugPrint('      ⚠️ لا توجد مواد مسجل بها!');
      } else {
        for (final item in items) {
          debugPrint(
            '      📖 ${item['group_name']} (${item['course_name']}): ${item['amount']} جنيه',
          );
        }
      }
      debugPrint(
        '═══════════════════════════════════════════════════════════════',
      );
      debugPrint('');

      return invoice;
    } catch (e) {
      debugPrint('❌ [Invoice] Error: $e');
      rethrow;
    }
  }

  Future<Map<String, double>> getStudentBalance(String studentId) async {
    final centerId = await _getCenterId();
    if (centerId == null) {
      return {'total_due': 0.0, 'total_paid': 0.0, 'balance': 0.0};
    }

    try {
      debugPrint('💰 [getStudentBalance] Fetching for student: $studentId');

      final data = await SupabaseClientManager.client.rpc(
        'get_student_balance_summary',
        params: {'p_student_id': studentId, 'p_center_id': centerId},
      );

      debugPrint('💰 [getStudentBalance] Raw response: $data');

      final result = Map<String, dynamic>.from(data as Map);
      final balance = {
        'total_due': (result['total_due'] as num?)?.toDouble() ?? 0.0,
        'total_paid': (result['total_paid'] as num?)?.toDouble() ?? 0.0,
        'balance': (result['balance'] as num?)?.toDouble() ?? 0.0,
      };

      debugPrint('💰 [getStudentBalance] Parsed: $balance');
      return balance;
    } catch (e) {
      debugPrint('❌ [getStudentBalance] Error: $e');
      return {'total_due': 0.0, 'total_paid': 0.0, 'balance': 0.0};
    }
  }

  Future<Map<String, dynamic>> getStudentAccountStatement(
    String studentId,
  ) async {
    final centerId = await _getCenterId();
    if (centerId == null) throw Exception('Center ID not found');

    try {
      debugPrint(
        '📊 [getStudentAccountStatement] Fetching for student: $studentId',
      );

      final data = await SupabaseClientManager.client.rpc(
        'get_student_account_statement',
        params: {'p_student_id': studentId, 'p_center_id': centerId},
      );

      return Map<String, dynamic>.from(data as Map);
    } catch (e) {
      debugPrint('❌ [getStudentAccountStatement] Error: $e');
      rethrow;
    }
  }

  Future<void> addPaymentToInvoice({
    required String invoiceId,
    required double amount,
    required String paymentMethod,
    String? notes,
  }) async {
    final centerId = await _getCenterId();
    if (centerId == null) throw Exception('Center ID not found');

    try {
      debugPrint('🌍 [PaymentsRemote] DB Call: add_payment_to_invoice');
      debugPrint(
        '   Params: {invoice: $invoiceId, amount: $amount, method: $paymentMethod}',
      );

      await SupabaseClientManager.client.rpc(
        'add_payment_to_invoice',
        params: {
          'p_invoice_id': invoiceId,
          'p_amount': amount,
          'p_method': paymentMethod,
          'p_notes': notes,
          'p_center_id': centerId,
        },
      );
      debugPrint('✅ [PaymentsRemote] Payment Recorded Successfully');
    } catch (e) {
      debugPrint('❌ [PaymentsRemote] addPaymentToInvoice Error: $e');
      throw e;
    }
  }

  Future<void> recalculateInvoice(String invoiceId) async {
    try {
      await SupabaseClientManager.client.rpc(
        'recalculate_invoice',
        params: {'p_invoice_id': invoiceId},
      );
    } catch (e) {
      debugPrint('❌ [PaymentsRemote] recalculateInvoice Error: $e');
      throw e;
    }
  }

  /// جلب تقرير الإيرادات الذكي للمركز
  Future<Map<String, dynamic>> getCenterRevenueReport({
    int? month,
    int? year,
  }) async {
    final centerId = await _getCenterId();
    if (centerId == null) return {};

    try {
      debugPrint('📊 [RevenueReport] Fetching smart revenue report...');

      final data = await SupabaseClientManager.client.rpc(
        'get_center_revenue_report',
        params: {'p_center_id': centerId, 'p_month': month, 'p_year': year},
      );

      final result = Map<String, dynamic>.from(data as Map);

      debugPrint(
        '📊 [RevenueReport] Expected: ${result['expected_revenue']} جنيه',
      );
      debugPrint('📊 [RevenueReport] Actual: ${result['actual_revenue']} جنيه');
      debugPrint('📊 [RevenueReport] Rate: ${result['collection_rate']}%');

      return result;
    } catch (e) {
      debugPrint('❌ [getCenterRevenueReport] Error: $e');
      return {};
    }
  }
}
