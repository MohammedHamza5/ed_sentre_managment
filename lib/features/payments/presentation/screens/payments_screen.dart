import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/l10n/app_strings.dart';
import '../../../../core/routing/route_names.dart';
import '../../../../core/utils/responsive_utils.dart';
import '../../../../core/utils/form_validators.dart';
import '../../../../core/providers/center_provider.dart';
import '../../../../shared/widgets/charts/charts.dart';
import '../../../../shared/models/models.dart';
import '../../data/repositories/payment_repository.dart';
import '../../data/repositories/expenses_repository.dart';
import '../../../students/data/repositories/students_repository.dart';
import '../../bloc/payments_bloc.dart';

class PaymentsScreen extends StatelessWidget {
  const PaymentsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final centerProvider = context.watch<CenterProvider>();

    if (!centerProvider.hasCenter) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.business_center, size: 64),
            SizedBox(height: 16),
            Text('لم يتم العثور على بيانات السنتر'),
          ],
        ),
      );
    }

    return BlocProvider(
      create: (context) => PaymentsBloc(
        paymentRepo: context.read<PaymentRepository>(),
        studentsRepo: context.read<StudentsRepository>(),
        expensesRepo: context.read<ExpensesRepository>(),
        centerId: centerProvider.centerId!,
      )..add(const LoadPayments()),
      child: const _PaymentsView(),
    );
  }
}

class _PaymentsView extends StatefulWidget {
  const _PaymentsView();

  @override
  State<_PaymentsView> createState() => _PaymentsViewState();
}

class _PaymentsViewState extends State<_PaymentsView>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final padding = ResponsiveUtils.getPagePadding(context);
    final strings = AppStrings.of(context);

    return BlocListener<PaymentsBloc, PaymentsState>(
      listenWhen: (previous, current) =>
          previous.errorMessage != current.errorMessage &&
          current.errorMessage != null,
      listener: (context, state) {
        if (state.errorMessage != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.errorMessage!),
              backgroundColor: AppColors.error,
            ),
          );
        }
      },
      child: BlocBuilder<PaymentsBloc, PaymentsState>(
        builder: (context, state) {
          if (state.status == PaymentsLoadingStatus.loading) {
            return const Center(child: CircularProgressIndicator());
          }

          return RefreshIndicator(
            onRefresh: () async {
              context.read<PaymentsBloc>().add(const LoadPayments());
            },
            child: SingleChildScrollView(
              padding: padding,
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Modern Header
                  _buildModernHeader(context, isDark, strings, state),

                  const SizedBox(height: AppSpacing.xl),

                  // Stats Cards Row
                  _buildStatsRow(state, strings, isDark),

                  const SizedBox(height: AppSpacing.xl),

                  // Charts Row (only on desktop)
                  if (!ResponsiveUtils.isMobile(context)) ...[
                    MonthlyRevenueChart(data: state.monthlyRevenueChart),
                    const SizedBox(height: AppSpacing.xl),
                  ],

                  // Tabs Container
                  _buildTabsContainer(context, state, isDark, strings),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildModernHeader(
    BuildContext context,
    bool isDark,
    AppStrings strings,
    PaymentsState state,
  ) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF10B981), Color(0xFF059669)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF10B981).withValues(alpha: 0.4),
            blurRadius: 25,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.account_balance_wallet_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    strings.paymentsAndExpenses,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${state.payments.length} ${strings.isArabic ? 'دفعة' : 'Payments'} | ${state.expenses.length} ${strings.isArabic ? 'مصروف' : 'Expenses'}',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  // عرض نظام الدفع الحالي ✨
                  Builder(
                    builder: (ctx) {
                      final centerProvider = ctx.watch<CenterProvider>();
                      final billingConfig = centerProvider.billingConfig;
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              billingConfig.isPerSession
                                  ? Icons.confirmation_number
                                  : billingConfig.isMonthly
                                  ? Icons.calendar_month
                                  : Icons.payment,
                              size: 12,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              billingConfig.billingTypeArabic,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
          Row(
            children: [
              // Record Expense Button
              _buildActionButton(
                icon: Icons.remove_circle_outline_rounded,
                label: strings.recordExpense,
                color: Colors.white.withValues(alpha: 0.15),
                textColor: Colors.white,
                onTap: () => _showRecordExpenseDialog(context, strings),
              ),
              const SizedBox(width: 12),
              // Record Payment Button
              _buildActionButton(
                icon: Icons.add_circle_outline_rounded,
                label: strings.recordPayment,
                color: Colors.white,
                textColor: const Color(0xFF10B981),
                onTap: () => context.go(RouteNames.recordPayment),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required Color textColor,
    required VoidCallback onTap,
  }) {
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Icon(icon, color: textColor, size: 20),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(color: textColor, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatsRow(PaymentsState state, AppStrings strings, bool isDark) {
    return Row(
      children: [
        Expanded(
          child: _buildModernStatCard(
            title: strings.monthlyRevenue,
            value: FormUtils.formatFullCurrency(state.monthlyRevenue),
            icon: Icons.trending_up_rounded,
            color: const Color(0xFF10B981),
            isDark: isDark,
          ),
        ),
        const SizedBox(width: AppSpacing.lg),
        Expanded(
          child: _buildModernStatCard(
            title: strings.monthlyExpenses,
            value: FormUtils.formatFullCurrency(state.monthlyExpenses),
            icon: Icons.trending_down_rounded,
            color: const Color(0xFFEF4444),
            isDark: isDark,
          ),
        ),
        const SizedBox(width: AppSpacing.lg),
        Expanded(
          child: _buildModernStatCard(
            title: strings.netProfit,
            value: FormUtils.formatFullCurrency(state.netProfit),
            icon: Icons.account_balance_rounded,
            color: const Color(0xFF6366F1),
            isDark: isDark,
          ),
        ),
        const SizedBox(width: AppSpacing.lg),
        Expanded(
          child: _buildModernStatCard(
            title: strings.overduePayments,
            value: state.overdueCount.toString(),
            subtitle: strings.needsFollowUp,
            icon: Icons.warning_amber_rounded,
            color: const Color(0xFFF59E0B),
            isDark: isDark,
          ),
        ),
      ],
    );
  }

  Widget _buildModernStatCard({
    required String title,
    required String value,
    String? subtitle,
    required IconData icon,
    required Color color,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.2), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white60 : Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.grey[900],
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 11,
                      color: color,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabsContainer(
    BuildContext context,
    PaymentsState state,
    bool isDark,
    AppStrings strings,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          // Tab Header
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.05)
                  : Colors.grey.withValues(alpha: 0.1),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20),
              ),
            ),
            child: TabBar(
              controller: _tabController,
              labelColor: Colors.white,
              unselectedLabelColor: isDark ? Colors.white60 : Colors.grey[700],
              indicator: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF10B981), Color(0xFF059669)],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              tabs: [
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.payments_outlined, size: 18),
                      const SizedBox(width: 8),
                      Text(strings.payments),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${state.filteredPayments.length}',
                          style: const TextStyle(fontSize: 11),
                        ),
                      ),
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.receipt_long_outlined, size: 18),
                      const SizedBox(width: 8),
                      Text(strings.expenses),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${state.expenses.length}',
                          style: const TextStyle(fontSize: 11),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Tab Content
          SizedBox(
            height: 500,
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildPaymentsTab(context, state, isDark, strings),
                _buildExpensesTab(context, state, isDark, strings),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentsTab(
    BuildContext context,
    PaymentsState state,
    bool isDark,
    AppStrings strings,
  ) {
    return Column(
      children: [
        // Filters Row
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Icon(Icons.filter_list_rounded, size: 18),
              const SizedBox(width: 8),
              Text(strings.isArabic ? 'فلتر:' : 'Filter:'),
              const SizedBox(width: 12),
              _buildFilterChip(
                label: strings.all,
                isSelected: state.statusFilter == null,
                onTap: () =>
                    context.read<PaymentsBloc>().add(const FilterPayments()),
              ),
              const SizedBox(width: 8),
              _buildFilterChip(
                label: strings.paid,
                isSelected: state.statusFilter == PaymentStatus.paid,
                color: const Color(0xFF10B981),
                onTap: () => context.read<PaymentsBloc>().add(
                  const FilterPayments(status: PaymentStatus.paid),
                ),
              ),
              const SizedBox(width: 8),
              _buildFilterChip(
                label: strings.partial,
                isSelected: state.statusFilter == PaymentStatus.partial,
                color: const Color(0xFFF59E0B),
                onTap: () => context.read<PaymentsBloc>().add(
                  const FilterPayments(status: PaymentStatus.partial),
                ),
              ),
              const SizedBox(width: 8),
              _buildFilterChip(
                label: strings.overdue,
                isSelected: state.statusFilter == PaymentStatus.overdue,
                color: const Color(0xFFEF4444),
                onTap: () => context.read<PaymentsBloc>().add(
                  const FilterPayments(status: PaymentStatus.overdue),
                ),
              ),
            ],
          ),
        ),

        const Divider(height: 1),

        // Table Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          color: isDark
              ? Colors.white.withValues(alpha: 0.03)
              : Colors.grey.withValues(alpha: 0.05),
          child: Row(
            children: [
              Expanded(
                flex: 3,
                child: Text(strings.student, style: _headerStyle(isDark)),
              ),
              SizedBox(
                width: 100,
                child: Text(strings.amount, style: _headerStyle(isDark)),
              ),
              SizedBox(
                width: 100,
                child: Text(strings.month, style: _headerStyle(isDark)),
              ),
              SizedBox(
                width: 120,
                child: Text(strings.paymentMethod, style: _headerStyle(isDark)),
              ),
              SizedBox(
                width: 100,
                child: Text(strings.status, style: _headerStyle(isDark)),
              ),
              const SizedBox(width: 80),
            ],
          ),
        ),

        // Table Body
        Expanded(
          child: state.filteredPayments.isEmpty
              ? _buildEmptyState(
                  strings.isArabic ? 'لا توجد مدفوعات' : 'No payments',
                  Icons.payments_outlined,
                )
              : ListView.builder(
                  itemCount: state.filteredPayments.length,
                  itemBuilder: (context, index) {
                    final payment = state.filteredPayments[index];
                    return _buildPaymentRow(
                      payment,
                      isDark,
                      strings,
                      context,
                      state,
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildExpensesTab(
    BuildContext context,
    PaymentsState state,
    bool isDark,
    AppStrings strings,
  ) {
    return Column(
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Icon(Icons.receipt_long_outlined, size: 18),
              const SizedBox(width: 8),
              Text(
                strings.isArabic ? 'سجل المصروفات' : 'Expenses Log',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),

        const Divider(height: 1),

        // Table Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          color: isDark
              ? Colors.white.withValues(alpha: 0.03)
              : Colors.grey.withValues(alpha: 0.05),
          child: Row(
            children: [
              Expanded(
                flex: 2,
                child: Text(strings.expenseTitle, style: _headerStyle(isDark)),
              ),
              SizedBox(
                width: 100,
                child: Text(strings.amount, style: _headerStyle(isDark)),
              ),
              SizedBox(
                width: 120,
                child: Text(
                  strings.expenseCategory,
                  style: _headerStyle(isDark),
                ),
              ),
              SizedBox(
                width: 120,
                child: Text(strings.paymentMethod, style: _headerStyle(isDark)),
              ),
              SizedBox(
                width: 100,
                child: Text(
                  strings.isArabic ? 'التاريخ' : 'Date',
                  style: _headerStyle(isDark),
                ),
              ),
            ],
          ),
        ),

        // Table Body
        Expanded(
          child: state.expenses.isEmpty
              ? _buildEmptyState(
                  strings.isArabic ? 'لا توجد مصروفات' : 'No expenses',
                  Icons.receipt_long_outlined,
                )
              : ListView.builder(
                  itemCount: state.expenses.length,
                  itemBuilder: (context, index) {
                    final expense = state.expenses[index];
                    return _buildExpenseRow(expense, isDark, strings);
                  },
                ),
        ),
      ],
    );
  }

  TextStyle _headerStyle(bool isDark) {
    return TextStyle(
      fontWeight: FontWeight.w600,
      fontSize: 12,
      color: isDark ? Colors.white70 : Colors.grey[700],
    );
  }

  Widget _buildEmptyState(String message, IconData icon) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 48, color: Colors.grey[400]),
          const SizedBox(height: 12),
          Text(
            message,
            style: TextStyle(color: Colors.grey[500], fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool isSelected,
    Color? color,
    required VoidCallback onTap,
  }) {
    final chipColor = color ?? const Color(0xFF6366F1);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? chipColor : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? chipColor : Colors.grey.withValues(alpha: 0.3),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.grey[600],
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildPaymentRow(
    Payment payment,
    bool isDark,
    AppStrings strings,
    BuildContext context,
    PaymentsState state,
  ) {
    final statusColor = _getStatusColor(payment.status);
    final statusText = _getStatusText(payment.status, strings);
    final methodText = _getMethodText(payment.method, strings);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: isDark
                ? Colors.white.withValues(alpha: 0.05)
                : Colors.grey.withValues(alpha: 0.1),
          ),
        ),
      ),
      child: Row(
        children: [
          // Student
          Expanded(
            flex: 3,
            child: Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: const Color(
                    0xFF6366F1,
                  ).withValues(alpha: 0.1),
                  child: Text(
                    payment.studentName.isNotEmpty
                        ? payment.studentName.substring(
                            0,
                            payment.studentName.length > 1 ? 2 : 1,
                          )
                        : '?',
                    style: const TextStyle(
                      color: Color(0xFF6366F1),
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  payment.studentName.isEmpty ? 'Unknown' : payment.studentName,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
          // Amount
          SizedBox(
            width: 100,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${payment.paidAmount.toInt()}/${payment.amount.toInt()}',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: statusColor,
                  ),
                ),
                if (payment.remaining > 0)
                  Text(
                    '${strings.remaining}: ${payment.remaining.toInt()}',
                    style: TextStyle(fontSize: 10, color: Colors.grey[500]),
                  ),
              ],
            ),
          ),
          // Month
          SizedBox(width: 100, child: Text(payment.month)),
          // Method
          SizedBox(width: 120, child: Text(methodText)),
          // Status
          SizedBox(
            width: 100,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                statusText,
                style: TextStyle(
                  color: statusColor,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
          // Actions
          SizedBox(
            width: 80,
            child: payment.status != PaymentStatus.paid
                ? IconButton(
                    onPressed: () => _showRecordPaymentDialog(
                      context,
                      strings,
                      state,
                      existingPayment: payment,
                    ),
                    icon: const Icon(Icons.add_circle_outline, size: 20),
                    color: const Color(0xFF10B981),
                    tooltip: strings.recordPayment,
                  )
                : null,
          ),
        ],
      ),
    );
  }

  Widget _buildExpenseRow(Expense expense, bool isDark, AppStrings strings) {
    final categoryText = _getCategoryText(expense.category, strings);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: isDark
                ? Colors.white.withValues(alpha: 0.05)
                : Colors.grey.withValues(alpha: 0.1),
          ),
        ),
      ),
      child: Row(
        children: [
          // Title
          Expanded(
            flex: 2,
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.receipt_outlined,
                    size: 18,
                    color: Color(0xFFEF4444),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  expense.title,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
          // Amount
          SizedBox(
            width: 100,
            child: Text(
              '${expense.amount.toInt()} ${strings.isArabic ? 'ج' : 'LE'}',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Color(0xFFEF4444),
              ),
            ),
          ),
          // Category
          SizedBox(
            width: 120,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                categoryText,
                style: const TextStyle(fontSize: 11),
                textAlign: TextAlign.center,
              ),
            ),
          ),
          // Method
          SizedBox(
            width: 120,
            child: Text(_getMethodText(expense.method, strings)),
          ),
          // Date
          SizedBox(
            width: 100,
            child: Text(
              '${expense.date.day}/${expense.date.month}/${expense.date.year}',
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(PaymentStatus status) {
    switch (status) {
      case PaymentStatus.paid:
        return const Color(0xFF10B981);
      case PaymentStatus.partial:
        return const Color(0xFFF59E0B);
      case PaymentStatus.pending:
        return const Color(0xFF6366F1);
      case PaymentStatus.overdue:
        return const Color(0xFFEF4444);
    }
  }

  String _getStatusText(PaymentStatus status, AppStrings strings) {
    switch (status) {
      case PaymentStatus.paid:
        return strings.paid;
      case PaymentStatus.partial:
        return strings.partial;
      case PaymentStatus.pending:
        return strings.pending;
      case PaymentStatus.overdue:
        return strings.overdue;
    }
  }

  String _getMethodText(PaymentMethod method, AppStrings strings) {
    switch (method) {
      case PaymentMethod.cash:
        return strings.cash;
      case PaymentMethod.vodafoneCash:
        return strings.vodafoneCash;
      case PaymentMethod.bankTransfer:
        return strings.bankTransfer;
      case PaymentMethod.instaPay:
        return strings.instaPay;
    }
  }

  String _getCategoryText(ExpenseCategory category, AppStrings strings) {
    switch (category) {
      case ExpenseCategory.rent:
        return strings.rent;
      case ExpenseCategory.utilities:
        return strings.utilities;
      case ExpenseCategory.salary:
        return strings.salary;
      case ExpenseCategory.supplies:
        return strings.supplies;
      case ExpenseCategory.maintenance:
        return strings.maintenance;
      case ExpenseCategory.other:
        return strings.other;
    }
  }

  void _showRecordPaymentDialog(
    BuildContext context,
    AppStrings strings,
    PaymentsState state, {
    Payment? existingPayment,
  }) {
    final paymentsBloc = context.read<PaymentsBloc>();
    final amountController = TextEditingController();
    PaymentMethod selectedMethod = PaymentMethod.cash;
    String? selectedStudentId = existingPayment?.studentId;

    // Check if we have students
    if (existingPayment == null && state.students.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            strings.isArabic
                ? 'لا يوجد طلاب. قم بإضافة طلاب أولاً'
                : 'No students. Please add students first',
          ),
          backgroundColor: const Color(0xFFF59E0B),
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) {
          return Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: Container(
              width: 450,
              padding: EdgeInsets.zero,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF10B981), Color(0xFF059669)],
                      ),
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(20),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.payments_rounded,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                existingPayment != null
                                    ? '${strings.recordPaymentFor} ${existingPayment.studentName}'
                                    : strings.recordNewPayment,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              if (existingPayment != null)
                                Text(
                                  '${strings.remaining}: ${existingPayment.remaining.toInt()} ${strings.isArabic ? 'ج' : 'LE'}',
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.9),
                                    fontSize: 13,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(dialogContext),
                          icon: const Icon(Icons.close, color: Colors.white),
                        ),
                      ],
                    ),
                  ),

                  // Form
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Student Dropdown (only for new payment)
                        if (existingPayment == null) ...[
                          DropdownButtonFormField<String>(
                            value: selectedStudentId,
                            decoration: InputDecoration(
                              labelText: strings.selectStudent,
                              prefixIcon: const Icon(Icons.person_rounded),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            items: state.students.map((student) {
                              return DropdownMenuItem(
                                value: student.id,
                                child: Text(student.name),
                              );
                            }).toList(),
                            onChanged: (val) =>
                                setState(() => selectedStudentId = val),
                          ),
                          const SizedBox(height: 16),
                        ],

                        // Amount
                        TextFormField(
                          controller: amountController,
                          decoration: InputDecoration(
                            labelText: '${strings.paidAmount} *',
                            prefixIcon: const Icon(Icons.attach_money_rounded),
                            suffixText: strings.isArabic ? 'ج' : 'LE',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            hintText: existingPayment != null
                                ? '${existingPayment.remaining.toInt()}'
                                : '',
                          ),
                          keyboardType: TextInputType.number,
                        ),
                        const SizedBox(height: 20),

                        // Payment Method
                        Text(
                          '${strings.paymentMethod}:',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: PaymentMethod.values.map((method) {
                            final isSelected = selectedMethod == method;
                            return InkWell(
                              onTap: () =>
                                  setState(() => selectedMethod = method),
                              borderRadius: BorderRadius.circular(10),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? const Color(
                                          0xFF10B981,
                                        ).withValues(alpha: 0.1)
                                      : Colors.grey.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: isSelected
                                        ? const Color(0xFF10B981)
                                        : Colors.grey.withValues(alpha: 0.3),
                                    width: isSelected ? 2 : 1,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      _getMethodIcon(method),
                                      size: 16,
                                      color: isSelected
                                          ? const Color(0xFF10B981)
                                          : Colors.grey[600],
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      _getMethodText(method, strings),
                                      style: TextStyle(
                                        color: isSelected
                                            ? const Color(0xFF10B981)
                                            : Colors.grey[700],
                                        fontWeight: isSelected
                                            ? FontWeight.w600
                                            : FontWeight.normal,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),

                  // Actions
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey.withValues(alpha: 0.05),
                      borderRadius: const BorderRadius.vertical(
                        bottom: Radius.circular(20),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(dialogContext),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Text(strings.cancel),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton(
                            onPressed: () {
                              final amount = double.tryParse(
                                amountController.text,
                              );
                              if (amount == null || amount <= 0) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(strings.enterValidAmount),
                                  ),
                                );
                                return;
                              }

                              if (existingPayment == null &&
                                  selectedStudentId == null) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(strings.selectStudent),
                                  ),
                                );
                                return;
                              }

                              paymentsBloc.add(
                                RecordPayment(
                                  paymentId: existingPayment?.id,
                                  studentId: selectedStudentId,
                                  amount: amount,
                                  method: selectedMethod,
                                ),
                              );

                              Navigator.pop(dialogContext);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Row(
                                    children: [
                                      const Icon(
                                        Icons.check_circle,
                                        color: Colors.white,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        '${strings.paymentRecorded}: ${amount.toInt()} ${strings.isArabic ? 'ج' : 'LE'}',
                                      ),
                                    ],
                                  ),
                                  backgroundColor: const Color(0xFF10B981),
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF10B981),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.add_rounded, size: 20),
                                const SizedBox(width: 8),
                                Text(
                                  strings.recordPayment,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  IconData _getMethodIcon(PaymentMethod method) {
    switch (method) {
      case PaymentMethod.cash:
        return Icons.money_rounded;
      case PaymentMethod.vodafoneCash:
        return Icons.phone_android_rounded;
      case PaymentMethod.bankTransfer:
        return Icons.account_balance_rounded;
      case PaymentMethod.instaPay:
        return Icons.qr_code_rounded;
    }
  }

  void _showRecordExpenseDialog(BuildContext context, AppStrings strings) {
    final paymentsBloc = context.read<PaymentsBloc>();
    final titleController = TextEditingController();
    final amountController = TextEditingController();
    final descriptionController = TextEditingController();
    ExpenseCategory selectedCategory = ExpenseCategory.other;
    PaymentMethod selectedMethod = PaymentMethod.cash;
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) {
          return Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: Container(
              width: 450,
              padding: EdgeInsets.zero,
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFFEF4444), Color(0xFFDC2626)],
                        ),
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(20),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.receipt_long_rounded,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              strings.recordExpense,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.pop(dialogContext),
                            icon: const Icon(Icons.close, color: Colors.white),
                          ),
                        ],
                      ),
                    ),

                    // Form
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          // Title
                          TextFormField(
                            controller: titleController,
                            decoration: InputDecoration(
                              labelText: '${strings.expenseTitle} *',
                              prefixIcon: const Icon(Icons.title_rounded),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            validator: (v) => v?.isEmpty ?? true
                                ? strings.fillAllFields
                                : null,
                          ),
                          const SizedBox(height: 16),

                          // Amount
                          TextFormField(
                            controller: amountController,
                            decoration: InputDecoration(
                              labelText: '${strings.amount} *',
                              prefixIcon: const Icon(
                                Icons.attach_money_rounded,
                              ),
                              suffixText: strings.isArabic ? 'ج' : 'LE',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            keyboardType: TextInputType.number,
                            validator: (v) =>
                                (double.tryParse(v ?? '') ?? 0) <= 0
                                ? strings.enterValidAmount
                                : null,
                          ),
                          const SizedBox(height: 16),
                          // Category
                          DropdownButtonFormField<ExpenseCategory>(
                            value: selectedCategory,
                            decoration: InputDecoration(
                              labelText: strings.expenseCategory,
                              prefixIcon: const Icon(Icons.category_rounded),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            isExpanded: true,
                            items: ExpenseCategory.values.map((c) {
                              return DropdownMenuItem(
                                value: c,
                                child: Text(_getCategoryText(c, strings)),
                              );
                            }).toList(),
                            onChanged: (v) =>
                                setState(() => selectedCategory = v!),
                          ),
                          const SizedBox(height: 16),

                          // Payment Method
                          DropdownButtonFormField<PaymentMethod>(
                            value: selectedMethod,
                            decoration: InputDecoration(
                              labelText: strings.paymentMethod,
                              prefixIcon: const Icon(Icons.payment_rounded),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            items: PaymentMethod.values.map((m) {
                              return DropdownMenuItem(
                                value: m,
                                child: Row(
                                  children: [
                                    Icon(_getMethodIcon(m), size: 18),
                                    const SizedBox(width: 8),
                                    Text(_getMethodText(m, strings)),
                                  ],
                                ),
                              );
                            }).toList(),
                            onChanged: (v) =>
                                setState(() => selectedMethod = v!),
                          ),
                          const SizedBox(height: 16),

                          // Description
                          TextFormField(
                            controller: descriptionController,
                            decoration: InputDecoration(
                              labelText: strings.description,
                              prefixIcon: const Icon(Icons.notes_rounded),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            maxLines: 2,
                          ),
                        ],
                      ),
                    ),

                    // Actions
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey.withValues(alpha: 0.05),
                        borderRadius: const BorderRadius.vertical(
                          bottom: Radius.circular(20),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(dialogContext),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: Text(strings.cancel),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 2,
                            child: ElevatedButton(
                              onPressed: () {
                                if (formKey.currentState?.validate() ?? false) {
                                  paymentsBloc.add(
                                    RecordExpense(
                                      title: titleController.text,
                                      amount: double.parse(
                                        amountController.text,
                                      ),
                                      category: selectedCategory,
                                      method: selectedMethod,
                                      description: descriptionController.text,
                                    ),
                                  );
                                  Navigator.pop(dialogContext);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Row(
                                        children: [
                                          const Icon(
                                            Icons.check_circle,
                                            color: Colors.white,
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            strings.isArabic
                                                ? 'تم تسجيل المصروف بنجاح'
                                                : 'Expense recorded successfully',
                                          ),
                                        ],
                                      ),
                                      backgroundColor: const Color(0xFFEF4444),
                                      behavior: SnackBarBehavior.floating,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                    ),
                                  );
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFEF4444),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.add_rounded, size: 20),
                                  const SizedBox(width: 8),
                                  Text(
                                    strings.save,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}


