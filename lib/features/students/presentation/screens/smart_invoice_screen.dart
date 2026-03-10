/// Smart Student Invoice Screen - EdSentre
/// شاشة فاتورة الطالب الذكية
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../payments/data/repositories/payment_repository.dart';

class SmartInvoiceScreen extends StatefulWidget {
  final String studentId;
  final String studentName;
  final int? month;
  final int? year;

  const SmartInvoiceScreen({
    super.key,
    required this.studentId,
    required this.studentName,
    this.month,
    this.year,
  });

  @override
  State<SmartInvoiceScreen> createState() => _SmartInvoiceScreenState();
}

class _SmartInvoiceScreenState extends State<SmartInvoiceScreen> {
  Map<String, dynamic>? _invoice;
  Map<String, double>? _balance;
  bool _isLoading = true;
  String? _error;
  late PaymentRepository _repository;

  late int _selectedMonth;
  late int _selectedYear;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedMonth = widget.month ?? now.month;
    _selectedYear = widget.year ?? now.year;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _repository = context.read<PaymentRepository>();
    _loadInvoice();
  }

  Future<void> _loadInvoice() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final invoice = await _repository.getOrCreateStudentInvoice(
        studentId: widget.studentId,
        month: _selectedMonth,
        year: _selectedYear,
      );

      final balance = await _repository.getStudentBalance(widget.studentId);

      if (!mounted) return;
      setState(() {
        _invoice = invoice;
        _balance = balance;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark
          ? AppColors.darkBackground
          : AppColors.lightBackground,
      appBar: AppBar(
        title: Text(
          'فاتورة ${widget.studentName}',
          style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadInvoice),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? _buildErrorWidget()
          : _buildContent(isDark),
    );
  }

  Widget _buildErrorWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 64, color: AppColors.error),
          const SizedBox(height: 16),
          Text(
            _error ?? 'حدث خطأ',
            style: const TextStyle(color: AppColors.error),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _loadInvoice,
            icon: const Icon(Icons.refresh),
            label: const Text('إعادة المحاولة'),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(bool isDark) {
    return RefreshIndicator(
      onRefresh: _loadInvoice,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Month Selector
            _buildMonthSelector(isDark),
            const SizedBox(height: AppSpacing.lg),

            // Balance Summary Card
            _buildBalanceSummary(isDark),
            const SizedBox(height: AppSpacing.lg),

            // Invoice Details Card
            _buildInvoiceCard(isDark),
            const SizedBox(height: AppSpacing.lg),

            // Payment Actions
            _buildPaymentActions(isDark),
            const SizedBox(height: AppSpacing.lg),

            // Payment History
            _buildPaymentHistory(isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildMonthSelector(bool isDark) {
    final months = [
      'يناير',
      'فبراير',
      'مارس',
      'أبريل',
      'مايو',
      'يونيو',
      'يوليو',
      'أغسطس',
      'سبتمبر',
      'أكتوبر',
      'نوفمبر',
      'ديسمبر',
    ];

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
          ),
        ],
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: () {
              setState(() {
                if (_selectedMonth == 1) {
                  _selectedMonth = 12;
                  _selectedYear--;
                } else {
                  _selectedMonth--;
                }
              });
              _loadInvoice();
            },
          ),
          Expanded(
            child: Text(
              '${months[_selectedMonth - 1]} $_selectedYear',
              textAlign: TextAlign.center,
              style: GoogleFonts.cairo(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: () {
              setState(() {
                if (_selectedMonth == 12) {
                  _selectedMonth = 1;
                  _selectedYear++;
                } else {
                  _selectedMonth++;
                }
              });
              _loadInvoice();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildBalanceSummary(bool isDark) {
    // الـ API يُرجع: total_due, total_paid, balance
    final total = _balance?['total_due'] ?? 0.0;
    final paid = _balance?['total_paid'] ?? 0.0;
    final remaining = _balance?['balance'] ?? 0.0;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: remaining > 0
              ? [Colors.orange.shade600, Colors.orange.shade400]
              : [Colors.green.shade600, Colors.green.shade400],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        boxShadow: [
          BoxShadow(
            color: (remaining > 0 ? Colors.orange : Colors.green).withValues(
              alpha: 0.3,
            ),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'الرصيد الإجمالي',
                style: GoogleFonts.cairo(
                  color: Colors.white.withValues(alpha: 0.9),
                  fontSize: 14,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  remaining > 0 ? 'مستحق' : 'مدفوع بالكامل',
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: _buildBalanceItem('الإجمالي', total, Colors.white),
              ),
              Container(
                height: 40,
                width: 1,
                color: Colors.white.withValues(alpha: 0.3),
              ),
              Expanded(child: _buildBalanceItem('المدفوع', paid, Colors.white)),
              Container(
                height: 40,
                width: 1,
                color: Colors.white.withValues(alpha: 0.3),
              ),
              Expanded(
                child: _buildBalanceItem('المتبقي', remaining, Colors.white),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBalanceItem(String label, double amount, Color color) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(color: color.withValues(alpha: 0.8), fontSize: 12),
        ),
        const SizedBox(height: 4),
        Text(
          '${amount.toInt()} ج',
          style: GoogleFonts.cairo(
            color: color,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildInvoiceCard(bool isDark) {
    final items = (_invoice?['items'] as List?) ?? [];
    final totalAmount = (_invoice?['total_amount'] as num?)?.toDouble() ?? 0;
    final paidAmount = (_invoice?['paid_amount'] as num?)?.toDouble() ?? 0;
    // الـ API يُرجع 'remaining' وليس 'remaining_amount'
    final remainingAmount = (_invoice?['remaining'] as num?)?.toDouble() ?? 0;
    final status = _invoice?['status'] ?? 'pending';

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(AppSpacing.radiusLg),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.receipt_long, color: AppColors.primary),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    'تفاصيل الفاتورة',
                    style: GoogleFonts.cairo(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                _buildStatusBadge(status),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.refresh, color: AppColors.primary),
                  tooltip: 'إعادة حساب الفاتورة',
                  onPressed: _recalculateInvoice,
                ),
              ],
            ),
          ),

          // Items
          if (items.isEmpty)
            Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.inbox_outlined,
                      size: 48,
                      color: isDark
                          ? Colors.grey.shade600
                          : Colors.grey.shade400,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'لا توجد مواد مسجلة',
                      style: TextStyle(
                        color: isDark
                            ? Colors.grey.shade400
                            : Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: items.length,
              separatorBuilder: (_, __) => Divider(
                height: 1,
                color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
              ),
              itemBuilder: (context, index) {
                final item = items[index] as Map<String, dynamic>;
                return ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.secondary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.book,
                      color: AppColors.secondary,
                      size: 20,
                    ),
                  ),
                  title: Text(
                    item['course_name'] ?? 'مادة',
                    style: GoogleFonts.cairo(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    item['description'] ?? '',
                    style: const TextStyle(fontSize: 12),
                  ),
                  trailing: Text(
                    '${(item['amount'] as num?)?.toInt() ?? 0} ج',
                    style: GoogleFonts.cairo(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: AppColors.primary,
                    ),
                  ),
                );
              },
            ),

          // Footer with totals
          Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: isDark
                  ? AppColors.darkSurfaceVariant
                  : Colors.grey.shade50,
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(AppSpacing.radiusLg),
              ),
            ),
            child: Column(
              children: [
                _buildTotalRow('إجمالي الفاتورة', totalAmount, isDark),
                const SizedBox(height: 8),
                _buildTotalRow('المدفوع', paidAmount, isDark, isPositive: true),
                const Divider(),
                _buildTotalRow(
                  'المتبقي',
                  remainingAmount,
                  isDark,
                  isHighlighted: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color;
    String text;
    IconData icon;

    switch (status) {
      case 'paid':
        color = Colors.green;
        text = 'مدفوع';
        icon = Icons.check_circle;
        break;
      case 'partial':
        color = Colors.orange;
        text = 'جزئي';
        icon = Icons.timelapse;
        break;
      case 'overdue':
        color = Colors.red;
        text = 'متأخر';
        icon = Icons.warning;
        break;
      default:
        color = Colors.grey;
        text = 'معلق';
        icon = Icons.pending;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTotalRow(
    String label,
    double amount,
    bool isDark, {
    bool isPositive = false,
    bool isHighlighted = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontWeight: isHighlighted ? FontWeight.bold : FontWeight.normal,
            fontSize: isHighlighted ? 16 : 14,
          ),
        ),
        Text(
          '${isPositive && amount > 0 ? '-' : ''}${amount.toInt()} ج',
          style: GoogleFonts.cairo(
            fontWeight: FontWeight.bold,
            fontSize: isHighlighted ? 18 : 14,
            color: isHighlighted
                ? (amount > 0 ? Colors.red : Colors.green)
                : (isPositive ? Colors.green : null),
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentActions(bool isDark) {
    final remainingAmount = (_invoice?['remaining'] as num?)?.toDouble() ?? 0;

    if (remainingAmount <= 0) return const SizedBox.shrink();

    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () => _showPaymentDialog(remainingAmount),
            icon: const Icon(Icons.payment),
            label: const Text('دفع كامل'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => _showPaymentDialog(null),
            icon: const Icon(Icons.money),
            label: const Text('دفع جزئي'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _showPaymentDialog(double? fullAmount) {
    final amountController = TextEditingController(
      text: fullAmount?.toInt().toString() ?? '',
    );
    String selectedMethod = 'cash';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.payment, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(
                'تسجيل دفعة',
                style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Amount
              TextField(
                controller: amountController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  labelText: 'المبلغ',
                  suffixText: 'ج',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Payment Method
              Text(
                'طريقة الدفع:',
                style: GoogleFonts.cairo(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildMethodChip(
                    'cash',
                    'نقدي',
                    Icons.money,
                    selectedMethod,
                    (v) {
                      setDialogState(() => selectedMethod = v);
                    },
                  ),
                  _buildMethodChip(
                    'wallet',
                    'محفظة',
                    Icons.account_balance_wallet,
                    selectedMethod,
                    (v) {
                      setDialogState(() => selectedMethod = v);
                    },
                  ),
                  _buildMethodChip(
                    'visa',
                    'فيزا',
                    Icons.credit_card,
                    selectedMethod,
                    (v) {
                      setDialogState(() => selectedMethod = v);
                    },
                  ),
                  _buildMethodChip(
                    'vodafone_cash',
                    'فودافون',
                    Icons.phone_android,
                    selectedMethod,
                    (v) {
                      setDialogState(() => selectedMethod = v);
                    },
                  ),
                  _buildMethodChip(
                    'instapay',
                    'إنستا باي',
                    Icons.qr_code,
                    selectedMethod,
                    (v) {
                      setDialogState(() => selectedMethod = v);
                    },
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء'),
            ),
            ElevatedButton.icon(
              onPressed: () async {
                final amount = double.tryParse(amountController.text) ?? 0;
                if (amount <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('أدخل مبلغ صحيح')),
                  );
                  return;
                }

                Navigator.pop(context);
                await _processPayment(amount, selectedMethod);
              },
              icon: const Icon(Icons.check),
              label: const Text('تأكيد الدفع'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMethodChip(
    String value,
    String label,
    IconData icon,
    String selected,
    Function(String) onSelect,
  ) {
    final isSelected = value == selected;
    return FilterChip(
      selected: isSelected,
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [Icon(icon, size: 16), const SizedBox(width: 4), Text(label)],
      ),
      onSelected: (_) => onSelect(value),
      selectedColor: AppColors.primary.withValues(alpha: 0.2),
      checkmarkColor: AppColors.primary,
    );
  }

  Future<void> _processPayment(double amount, String method) async {
    try {
      setState(() => _isLoading = true);

      debugPrint('🔌 [UI] _processPayment called');
      debugPrint('   💰 Amount: $amount');
      debugPrint('   💳 Method: $method');
      debugPrint('   📄 Invoice ID: ${_invoice!['invoice_id']}');

      await _repository.addPaymentToInvoice(
        invoiceId: _invoice!['invoice_id'],
        amount: amount,
        paymentMethod: method,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 8),
                Text('تم تسجيل دفعة ${amount.toInt()} ج بنجاح'),
              ],
            ),
            backgroundColor: Colors.green,
          ),
        );
      }

      await _loadInvoice();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('فشل تسجيل الدفعة: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      setState(() => _isLoading = false);
    }
  }

  Future<void> _recalculateInvoice() async {
    try {
      setState(() => _isLoading = true);

      await _repository.recalculateInvoice(_invoice!['invoice_id']);
      await _loadInvoice();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم إعادة حساب الفاتورة بنجاح وتحديث الأسعار'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('فشل تحديث الفاتورة: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildPaymentHistory(bool isDark) {
    final payments = (_invoice?['payments'] as List?) ?? [];

    if (payments.isEmpty) return const SizedBox.shrink();

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Row(
              children: [
                const Icon(Icons.history, color: AppColors.secondary),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  'سجل المدفوعات',
                  style: GoogleFonts.cairo(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: payments.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final payment = payments[index] as Map<String, dynamic>;
              final amount = (payment['amount'] as num?)?.toDouble() ?? 0;
              final method = payment['method'] ?? 'cash';
              final paidAt = DateTime.tryParse(payment['paid_at'] ?? '');

              return ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    _getMethodIcon(method),
                    color: Colors.green,
                    size: 20,
                  ),
                ),
                title: Text(
                  '${amount.toInt()} ج',
                  style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  _getMethodName(method),
                  style: const TextStyle(fontSize: 12),
                ),
                trailing: Text(
                  paidAt != null ? DateFormat('yyyy/MM/dd').format(paidAt) : '',
                  style: TextStyle(
                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                    fontSize: 12,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  IconData _getMethodIcon(String method) {
    switch (method) {
      case 'wallet':
        return Icons.account_balance_wallet;
      case 'visa':
        return Icons.credit_card;
      case 'vodafone_cash':
        return Icons.phone_android;
      case 'instapay':
        return Icons.qr_code;
      case 'bank_transfer':
        return Icons.account_balance;
      default:
        return Icons.money;
    }
  }

  String _getMethodName(String method) {
    switch (method) {
      case 'wallet':
        return 'محفظة';
      case 'visa':
        return 'فيزا';
      case 'vodafone_cash':
        return 'فودافون كاش';
      case 'instapay':
        return 'إنستا باي';
      case 'bank_transfer':
        return 'تحويل بنكي';
      default:
        return 'نقدي';
    }
  }
}
