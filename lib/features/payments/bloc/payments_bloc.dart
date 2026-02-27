import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart'; // Added for debugPrint
import '../../../shared/models/models.dart';
import '../data/repositories/payment_repository.dart';
import '../data/repositories/expenses_repository.dart';
import '../../students/data/repositories/students_repository.dart';

// ═══════════════════════════════════════════════════════════════════════════
// EVENTS - أحداث المدفوعات
// ═══════════════════════════════════════════════════════════════════════════

abstract class PaymentsEvent extends Equatable {
  const PaymentsEvent();

  @override
  List<Object?> get props => [];
}

class LoadPayments extends PaymentsEvent {
  const LoadPayments();
}

class FilterPayments extends PaymentsEvent {
  final PaymentStatus? status;
  final String? month;

  const FilterPayments({this.status, this.month});

  @override
  List<Object?> get props => [status, month];
}

class RecordPayment extends PaymentsEvent {
  final String? paymentId; // Optional for new payments
  final String? studentId; // Required for new payments
  final double amount;
  final PaymentMethod method;
  final String? month; // Optional month

  const RecordPayment({
    this.paymentId,
    this.studentId,
    required this.amount,
    required this.method,
    this.month,
  });

  @override
  List<Object?> get props => [paymentId, studentId, amount, method, month];
}

class RecordExpense extends PaymentsEvent {
  final String title;
  final double amount;
  final ExpenseCategory category;
  final PaymentMethod method;
  final String? description;

  const RecordExpense({
    required this.title,
    required this.amount,
    required this.category,
    required this.method,
    this.description,
  });

  @override
  List<Object?> get props => [title, amount, category, method, description];
}

// ═══════════════════════════════════════════════════════════════════════════
// STATE - حالة المدفوعات
// ═══════════════════════════════════════════════════════════════════════════

enum PaymentsLoadingStatus { initial, loading, success, failure }

class PaymentsState extends Equatable {
  final PaymentsLoadingStatus status;
  final List<Payment> payments;
  final List<Payment> filteredPayments;
  final List<Student> students; // Added students list
  final List<Expense> expenses; // Added expenses list
  final PaymentStatus? statusFilter;
  final String? monthFilter;
  final String? errorMessage;

  // Stats
  final double monthlyRevenue;
  final double monthlyExpenses;
  final double netProfit;
  final int overdueCount;
  final List<Map<String, dynamic>> monthlyRevenueChart;

  const PaymentsState({
    this.status = PaymentsLoadingStatus.initial,
    this.payments = const [],
    this.filteredPayments = const [],
    this.students = const [],
    this.expenses = const [],
    this.statusFilter,
    this.monthFilter,
    this.errorMessage,
    this.monthlyRevenue = 0,
    this.monthlyExpenses = 0,
    this.netProfit = 0,
    this.overdueCount = 0,
    this.monthlyRevenueChart = const [],
  });

  PaymentsState copyWith({
    PaymentsLoadingStatus? status,
    List<Payment>? payments,
    List<Payment>? filteredPayments,
    List<Student>? students,
    List<Expense>? expenses,
    PaymentStatus? statusFilter,
    String? monthFilter,
    String? errorMessage,
    double? monthlyRevenue,
    double? monthlyExpenses,
    double? netProfit,
    int? overdueCount,
    List<Map<String, dynamic>>? monthlyRevenueChart,
  }) {
    return PaymentsState(
      status: status ?? this.status,
      payments: payments ?? this.payments,
      filteredPayments: filteredPayments ?? this.filteredPayments,
      students: students ?? this.students,
      expenses: expenses ?? this.expenses,
      statusFilter: statusFilter,
      monthFilter: monthFilter,
      errorMessage: errorMessage ?? this.errorMessage,
      monthlyRevenue: monthlyRevenue ?? this.monthlyRevenue,
      monthlyExpenses: monthlyExpenses ?? this.monthlyExpenses,
      netProfit: netProfit ?? this.netProfit,
      overdueCount: overdueCount ?? this.overdueCount,
      monthlyRevenueChart: monthlyRevenueChart ?? this.monthlyRevenueChart,
    );
  }

  @override
  List<Object?> get props => [
    status,
    payments,
    filteredPayments,
    students,
    expenses,
    statusFilter,
    monthFilter,
    monthlyRevenue,
    monthlyExpenses,
    netProfit,
    monthlyRevenueChart,
  ];
}

// ═══════════════════════════════════════════════════════════════════════════
// BLOC - Payments Bloc
// ═══════════════════════════════════════════════════════════════════════════

class PaymentsBloc extends Bloc<PaymentsEvent, PaymentsState> {
  final PaymentRepository _paymentRepo;
  final StudentsRepository _studentsRepo;
  final ExpensesRepository _expensesRepo;
  final String centerId;
  List<Payment> _allPayments = [];

  PaymentsBloc({
    required PaymentRepository paymentRepo,
    required StudentsRepository studentsRepo,
    required ExpensesRepository expensesRepo,
    required this.centerId,
  })  : _paymentRepo = paymentRepo,
        _studentsRepo = studentsRepo,
        _expensesRepo = expensesRepo,
        super(const PaymentsState()) {
    on<LoadPayments>(_onLoadPayments);
    on<FilterPayments>(_onFilterPayments);
    on<RecordPayment>(_onRecordPayment);
    on<RecordExpense>(_onRecordExpense);
  }

  void _onLoadPayments(LoadPayments event, Emitter<PaymentsState> emit) async {
    emit(state.copyWith(status: PaymentsLoadingStatus.loading));

    try {
      final results = await Future.wait([
        _paymentRepo.getPayments(),
        _studentsRepo.getStudents(),
        _expensesRepo.getExpenses(),
      ]);
      
      final payments = results[0] as List<Payment>;
      final students = results[1] as List<Student>;
      final expenses = results[2] as List<Expense>;

      _allPayments = payments;
      
      final stats = _calculateStats(payments, expenses);
      final chartData = _generateMonthlyRevenueChartData(payments);

      emit(
        state.copyWith(
          status: PaymentsLoadingStatus.success,
          payments: payments,
          students: students,
          expenses: expenses,
          filteredPayments: _applyCurrentFilters(),
          monthlyRevenue: stats['revenue']!,
          monthlyExpenses: stats['expenses']!,
          netProfit: stats['profit']!,
          overdueCount: stats['overdue']!.toInt(),
          monthlyRevenueChart: chartData,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          status: PaymentsLoadingStatus.failure,
          errorMessage: e.toString(),
        ),
      );
    }
  }

  void _onFilterPayments(FilterPayments event, Emitter<PaymentsState> emit) {
    final filtered = _applyCurrentFilters(
      status: event.status,
      month: event.month,
    );

    emit(
      state.copyWith(
        statusFilter: event.status,
        monthFilter: event.month,
        filteredPayments: filtered,
      ),
    );
  }

  Future<void> _onRecordPayment(
    RecordPayment event,
    Emitter<PaymentsState> emit,
  ) async {
    try {
      debugPrint('💰 [PaymentsBloc] _onRecordPayment started');
      debugPrint('   -> paymentId: ${event.paymentId}');
      debugPrint('   -> studentId: ${event.studentId}');
      debugPrint('   -> amount: ${event.amount}');
      debugPrint('   -> method: ${event.method}');
      
      if (event.paymentId != null) {
        // FLOW 1: Update existing payment
        debugPrint('💰 [PaymentsBloc] Updating existing payment...');
        final existing = _allPayments.firstWhere((p) => p.id == event.paymentId);
        
        final newPaidAmount = existing.paidAmount + event.amount;
        final newStatus = newPaidAmount >= existing.amount 
            ? PaymentStatus.paid 
            : PaymentStatus.partial;

        final updatedPayment = existing.copyWith(
          paidAmount: newPaidAmount,
          status: newStatus,
          method: event.method,
          paidDate: DateTime.now(),
        );

        await _paymentRepo.updatePayment(updatedPayment);
        debugPrint('✅ [PaymentsBloc] Payment updated successfully');
      } else if (event.studentId != null) {
        // FLOW 2: Create brand new payment
        debugPrint('💰 [PaymentsBloc] Creating new payment...');
        debugPrint('   -> Students in state: ${state.students.length}');
        
        if (state.students.isEmpty) {
          debugPrint('⚠️ [PaymentsBloc] No students available!');
          throw Exception('لا يوجد طلاب. قم بتسجيل طلاب أولاً');
        }
        
        final student = state.students.firstWhere(
          (s) => s.id == event.studentId,
          orElse: () => throw Exception('Student not found'),
        );
        final now = DateTime.now();
        
        // Create a new record
        final newPayment = Payment(
          id: '', // Will be generated by repo
          studentId: event.studentId!,
          studentName: student.name,
          amount: event.amount,
          paidAmount: event.amount,
          method: event.method,
          status: PaymentStatus.paid,
          month: event.month ?? _getMonthName(now.month),
          dueDate: now,
          paidDate: now,
        );

        debugPrint('💰 [PaymentsBloc] Payment data: ${newPayment.studentName}, ${newPayment.amount}');
        await _paymentRepo.addPayment(newPayment);
        debugPrint('✅ [PaymentsBloc] Payment added successfully');
      } else {
        throw Exception('Student ID or Payment ID is required');
      }
      
      // Reload everything
      debugPrint('🔄 [PaymentsBloc] Reloading payments...');
      add(const LoadPayments());
    } catch (e) {
      debugPrint('❌ [PaymentsBloc] RecordPayment Error: $e');
      emit(state.copyWith(errorMessage: 'فشل تسجيل الدفعة: $e'));
    }
  }

  Future<void> _onRecordExpense(
    RecordExpense event,
    Emitter<PaymentsState> emit,
  ) async {
    try {
      debugPrint('💸 [PaymentsBloc] _onRecordExpense started');
      debugPrint('   -> title: ${event.title}');
      debugPrint('   -> amount: ${event.amount}');
      debugPrint('   -> category: ${event.category}');
      
      final newExpense = Expense(
        id: '',
        title: event.title,
        amount: event.amount,
        category: event.category,
        date: DateTime.now(),
        method: event.method,
        description: event.description,
        createdAt: DateTime.now(),
      );

      debugPrint('💸 [PaymentsBloc] Calling _repo.addExpense...');
      await _expensesRepo.addExpense(newExpense);
      debugPrint('✅ [PaymentsBloc] Expense added successfully');
      
      // Reload everything
      debugPrint('🔄 [PaymentsBloc] Reloading data...');
      add(const LoadPayments());
    } catch (e) {
      debugPrint('❌ [PaymentsBloc] RecordExpense Error: $e');
      emit(state.copyWith(errorMessage: 'فشل تسجيل المصروف: $e'));
    }
  }

  List<Payment> _applyCurrentFilters({PaymentStatus? status, String? month}) {
    final s = status ?? state.statusFilter;
    final m = month ?? state.monthFilter;

    return _allPayments.where((payment) {
      if (s != null && payment.status != s) {
        return false;
      }
      if (m != null && m != 'الكل' && payment.month != m) {
        return false;
      }
      return true;
    }).toList();
  }

  Map<String, double> _calculateStats(List<Payment> payments, List<Expense> expenses) {
    final revenue = payments.fold(0.0, (sum, p) => sum + p.paidAmount);
    final totalExpenses = expenses.fold(0.0, (sum, e) => sum + e.amount);

    final overdue = payments
        .where((p) => p.status == PaymentStatus.overdue)
        .length
        .toDouble();

    return {
      'revenue': revenue,
      'expenses': totalExpenses,
      'profit': revenue - totalExpenses,
      'overdue': overdue,
    };
  }

  List<Map<String, dynamic>> _generateMonthlyRevenueChartData(List<Payment> payments) {
    // Group by month
    final Map<String, double> monthlySums = {};
    
    // Sort months logically (last 6 months)
    final now = DateTime.now();
    for (int i = 5; i >= 0; i--) {
      final date = DateTime(now.year, now.month - i, 1);
      final monthName = _getMonthName(date.month);
      monthlySums[monthName] = 0.0;
    }

    for (var p in payments) {
      if (monthlySums.containsKey(p.month)) {
        monthlySums[p.month] = (monthlySums[p.month] ?? 0) + p.paidAmount;
      }
    }

    return monthlySums.entries.map((e) => {
      'month': e.key,
      'revenue': e.value,
    }).toList();
  }

  String _getMonthName(int month) {
    const months = [
      'يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو',
      'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر'
    ];
    return months[month - 1];
  }
}


