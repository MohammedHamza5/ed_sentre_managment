import 'package:equatable/equatable.dart';

enum SalaryStatus { draft, pending, approved, paid, cancelled }
enum SalaryItemType { session, percentage, bonus, deduction }

class TeacherSalary extends Equatable {
  final String id;
  final String teacherId;
  final String teacherName;
  final int month;
  final int year;
  final String salaryType; // 'fixed', 'percentage', 'per_session'
  final double baseSalary;
  final double sessionsTotal;
  final double percentageTotal;
  final double bonusesTotal;
  final double deductionsTotal;
  final double grossSalary;
  final double netSalary;
  final SalaryStatus status;
  final DateTime? paymentDate;
  final DateTime createdAt;
  final List<SalaryItem> items;

  // Calculated helper
  bool get isPaid => status == SalaryStatus.paid;
  bool get isApproved => status == SalaryStatus.approved || status == SalaryStatus.paid;

  const TeacherSalary({
    required this.id,
    required this.teacherId,
    required this.teacherName,
    required this.month,
    required this.year,
    required this.salaryType,
    required this.baseSalary,
    required this.sessionsTotal,
    required this.percentageTotal,
    required this.bonusesTotal,
    required this.deductionsTotal,
    required this.grossSalary,
    required this.netSalary,
    required this.status,
    this.paymentDate,
    required this.createdAt,
    this.items = const [],
  });

  @override
  List<Object?> get props => [
        id,
        teacherId,
        month,
        year,
        status,
        netSalary,
        items,
      ];

  TeacherSalary copyWith({
    String? statusString, // Helper to update status from string
    SalaryStatus? status,
    List<SalaryItem>? items,
  }) {
    return TeacherSalary(
      id: id,
      teacherId: teacherId,
      teacherName: teacherName,
      month: month,
      year: year,
      salaryType: salaryType,
      baseSalary: baseSalary,
      sessionsTotal: sessionsTotal,
      percentageTotal: percentageTotal,
      bonusesTotal: bonusesTotal,
      deductionsTotal: deductionsTotal,
      grossSalary: grossSalary,
      netSalary: netSalary,
      status: status ?? this.status,
      paymentDate: paymentDate,
      createdAt: createdAt,
      items: items ?? this.items,
    );
  }
}

class SalaryItem extends Equatable {
  final String? id; // Null for new items
  final SalaryItemType type;
  final String description;
  final double amount;
  final int count;
  final double rate;

  const SalaryItem({
    this.id,
    required this.type,
    required this.description,
    required this.amount,
    this.count = 0,
    this.rate = 0.0,
  });

  @override
  List<Object?> get props => [id, type, description, amount];

  Map<String, dynamic> toJson() {
    return {
      'type': type.name,
      'description': description,
      'amount': amount,
      'count': count,
      'rate': rate,
    };
  }
}


