import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../shared/models/models.dart';

class PaymentsLocalSource {
  static const String _storageKey = 'cached_payments';
  static const String _lastCacheTimeKey = 'payments_cache_time';

  Future<List<Payment>> getPayments() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_storageKey);
    if (jsonString == null) return [];

    try {
      final List<dynamic> jsonList = json.decode(jsonString);
      return jsonList
          .map((json) => _PaymentLocalMapper.fromJson(json))
          .toList();
    } catch (e) {
      debugPrint('❌ [PaymentsLocal] Parse Error: $e');
      return [];
    }
  }

  Future<void> savePayments(List<Payment> payments) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = payments
        .map((p) => _PaymentLocalMapper.toJson(p))
        .toList();
    await prefs.setString(_storageKey, json.encode(jsonList));
    await prefs.setString(_lastCacheTimeKey, DateTime.now().toIso8601String());
  }

  Future<DateTime?> getLastCacheTime() async {
    final prefs = await SharedPreferences.getInstance();
    final timeStr = prefs.getString(_lastCacheTimeKey);
    if (timeStr == null) return null;
    return DateTime.tryParse(timeStr);
  }

  Future<void> clearCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_storageKey);
    await prefs.remove(_lastCacheTimeKey);
  }
}

class _PaymentLocalMapper {
  static Payment fromJson(Map<String, dynamic> json) {
    return Payment(
      id: json['id'],
      studentId: json['studentId'],
      studentName: json['studentName'],
      amount: json['amount'],
      paidAmount: json['paidAmount'],
      method: PaymentMethod.values.firstWhere(
        (e) => e.name == json['method'],
        orElse: () => PaymentMethod.cash,
      ),
      status: PaymentStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => PaymentStatus.pending,
      ),
      month: json['month'],
      dueDate: json['dueDate'] != null ? DateTime.parse(json['dueDate']) : null,
      paidDate: json['paidDate'] != null ? DateTime.parse(json['paidDate']) : null,
      notes: json['notes'],
      receiptNumber: json['receiptNumber'],
      monthYear: json['monthYear'],
      isOverdue: json['isOverdue'] ?? false,
    );
  }

  static Map<String, dynamic> toJson(Payment p) {
    return {
      'id': p.id,
      'studentId': p.studentId,
      'studentName': p.studentName,
      'amount': p.amount,
      'paidAmount': p.paidAmount,
      'method': p.method.name,
      'status': p.status.name,
      'month': p.month,
      'dueDate': p.dueDate?.toIso8601String(),
      'paidDate': p.paidDate?.toIso8601String(),
      'notes': p.notes,
      'receiptNumber': p.receiptNumber,
      'monthYear': p.monthYear,
      'isOverdue': p.isOverdue,
    };
  }
}


