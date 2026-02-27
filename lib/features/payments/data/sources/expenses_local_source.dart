import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../shared/models/models.dart';

class ExpensesLocalSource {
  static const String _storageKey = 'cached_expenses';
  static const String _lastCacheTimeKey = 'expenses_cache_time';

  Future<List<Expense>> getExpenses() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_storageKey);
    if (jsonString == null) return [];

    try {
      final List<dynamic> jsonList = json.decode(jsonString);
      return jsonList
          .map((json) => _ExpenseLocalMapper.fromJson(json))
          .toList();
    } catch (e) {
      debugPrint('❌ [ExpensesLocal] Parse Error: $e');
      return [];
    }
  }

  Future<void> saveExpenses(List<Expense> expenses) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = expenses
        .map((e) => _ExpenseLocalMapper.toJson(e))
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

class _ExpenseLocalMapper {
  static Expense fromJson(Map<String, dynamic> json) {
    return Expense(
      id: json['id'],
      title: json['title'],
      amount: json['amount'],
      category: ExpenseCategory.values.firstWhere(
        (e) => e.name == json['category'],
        orElse: () => ExpenseCategory.other,
      ),
      date: DateTime.parse(json['date']),
      method: PaymentMethod.values.firstWhere(
        (e) => e.name == json['method'],
        orElse: () => PaymentMethod.cash,
      ),
      description: json['description'],
      createdAt: DateTime.parse(json['createdAt']),
    );
  }

  static Map<String, dynamic> toJson(Expense e) {
    return {
      'id': e.id,
      'title': e.title,
      'amount': e.amount,
      'category': e.category.name,
      'date': e.date.toIso8601String(),
      'method': e.method.name,
      'description': e.description,
      'createdAt': e.createdAt.toIso8601String(),
    };
  }
}


