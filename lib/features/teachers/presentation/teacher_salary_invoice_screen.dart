/// Teacher Salary Invoice Screen - EdSentre
/// شاشة فاتورة راتب المعلم
library;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../../../core/providers/center_provider.dart';
import '../data/repositories/teachers_repository.dart';

class TeacherSalaryInvoiceScreen extends StatefulWidget {
  final String teacherId;
  final int month;
  final int year;

  const TeacherSalaryInvoiceScreen({
    super.key,
    required this.teacherId,
    required this.month,
    required this.year,
  });

  @override
  State<TeacherSalaryInvoiceScreen> createState() =>
      _TeacherSalaryInvoiceScreenState();
}

class _TeacherSalaryInvoiceScreenState
    extends State<TeacherSalaryInvoiceScreen> {
  bool _isLoading = true;
  bool _isSaving = false;
  Map<String, dynamic>? _salaryData;
  String? _errorMessage;

  // Local state for edits
  List<Map<String, dynamic>> _bonuses = [];
  List<Map<String, dynamic>> _deductions = [];

  @override
  void initState() {
    super.initState();
    _loadSalaryData();
  }

  Future<void> _loadSalaryData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final repository = context.read<TeachersRepository>();
      final data = await repository.getTeacherSalary(
        teacherId: widget.teacherId,
        month: widget.month,
        year: widget.year,
      );

      if (mounted) {
        setState(() {
          _salaryData = data;
          _bonuses = List<Map<String, dynamic>>.from(data['bonuses'] ?? []);
          _deductions = List<Map<String, dynamic>>.from(
            data['deductions'] ?? [],
          );
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  String get monthName {
    const months = [
      '',
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
    return months[widget.month];
  }

  double get _currentGross {
    if (_salaryData == null) return 0;
    final base = (_salaryData!['base_salary'] as num).toDouble();
    final sessions = (_salaryData!['sessions_total'] as num).toDouble();
    final percentage = (_salaryData!['percentage_total'] as num).toDouble();
    final bonuses = _bonuses.fold(
      0.0,
      (sum, item) => sum + (item['amount'] as num).toDouble(),
    );

    return base + sessions + percentage + bonuses;
  }

  double get _currentNet {
    final deductions = _deductions.fold(
      0.0,
      (sum, item) => sum + (item['amount'] as num).toDouble(),
    );
    return _currentGross - deductions;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'فاتورة راتب $monthName ${widget.year}',
          style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
        ),
        actions: [
          // عرض نظام الدفع الحالي ✨
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 8),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.deepPurple.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.deepPurple.withValues(alpha: 0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Builder(
                  builder: (ctx) {
                    final config = ctx.watch<CenterProvider>().billingConfig;
                    return Row(
                      children: [
                        Icon(
                          config.isPerSession
                              ? Icons.confirmation_number
                              : Icons.calendar_month,
                          size: 14,
                          color: Colors.deepPurple,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          config.billingTypeArabic,
                          style: TextStyle(
                            color: Colors.deepPurple.shade700,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.print_rounded),
            onPressed: _printInvoice,
            tooltip: 'طباعة',
          ),
          IconButton(
            icon: const Icon(Icons.file_download_rounded),
            onPressed: _exportPDF,
            tooltip: 'تصدير PDF',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
          ? Center(
              child: Text(
                _errorMessage!,
                style: const TextStyle(color: Colors.red),
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header with teacher info
                  _buildSmartHeader(),
                  const SizedBox(height: 24),

                  // Groups Details (NEW!)
                  if ((_salaryData?['groups'] as List?)?.isNotEmpty ??
                      false) ...[
                    _buildGroupsSection(),
                    const SizedBox(height: 24),
                  ],

                  // By Grade Analysis (NEW!)
                  if ((_salaryData?['by_grade'] as List?)?.isNotEmpty ??
                      false) ...[
                    _buildByGradeSection(),
                    const SizedBox(height: 24),
                  ],

                  // Insights (NEW!)
                  if ((_salaryData?['insights'] as List?)?.isNotEmpty ??
                      false) ...[
                    _buildInsightsSection(),
                    const SizedBox(height: 24),
                  ],

                  // Comparison with last month (NEW!)
                  if (_salaryData?['comparison'] != null) ...[
                    _buildComparisonSection(),
                    const SizedBox(height: 24),
                  ],

                  // Bonuses
                  _buildEditableCard(
                    title: 'المكافآت',
                    icon: Icons.stars_rounded,
                    color: Colors.green,
                    items: _bonuses,
                    onAdd: () => _showAddItemDialog('bonus'),
                    onRemove: (index) =>
                        setState(() => _bonuses.removeAt(index)),
                  ),
                  const SizedBox(height: 16),

                  // Deductions
                  _buildEditableCard(
                    title: 'الخصومات',
                    icon: Icons.remove_circle_rounded,
                    color: Colors.red,
                    items: _deductions,
                    onAdd: () => _showAddItemDialog('deduction'),
                    onRemove: (index) =>
                        setState(() => _deductions.removeAt(index)),
                    isDeduction: true,
                  ),
                  const SizedBox(height: 24),

                  // Total Card
                  _buildTotalCard(),
                  const SizedBox(height: 24),

                  // Actions
                  _buildActionsRow(),
                ],
              ),
            ),
    );
  }

  /// Smart Header with summary stats
  Widget _buildSmartHeader() {
    final status = _salaryData?['status'] ?? 'draft';
    final summary = _salaryData?['summary'] as Map<String, dynamic>? ?? {};
    final teacher = _salaryData?['teacher'] as Map<String, dynamic>? ?? {};

    final isDraft = status == 'draft';
    final isPaid = status == 'paid';
    Color statusColor = isDraft
        ? Colors.grey
        : (isPaid ? Colors.green : Colors.orange);
    String statusText = isDraft ? 'مسودة' : (isPaid ? 'مدفوع' : 'معتمد');

    final totalStudents = summary['total_students'] ?? 0;
    final paidStudents = summary['paid_students'] ?? 0;
    final totalCollected =
        (summary['total_collected'] as num?)?.toDouble() ?? 0.0;
    final teacherShare = (summary['teacher_share'] as num?)?.toDouble() ?? 0.0;
    final collectionRate = summary['collection_rate'] ?? 0;
    final salaryType = teacher['salary_type'] ?? 'fixed';
    final percentage = teacher['percentage'] ?? 0;

    String salaryTypeText = salaryType == 'fixed'
        ? 'راتب ثابت'
        : salaryType == 'percentage'
        ? 'نسبة $percentage%'
        : 'بالحصة';

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.blue.shade600, Colors.blue.shade900],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // Top Row - Teacher Name & Status
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.person,
                    size: 32,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _salaryData?['teacher_name'] ?? 'معلم',
                        style: GoogleFonts.cairo(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        '$monthName ${widget.year} • $salaryTypeText',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.8),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.5)),
                  ),
                  child: Text(
                    statusText,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),
            const Divider(color: Colors.white24),
            const SizedBox(height: 16),

            // Stats Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem('👥', 'الطلاب', '$paidStudents/$totalStudents'),
                _buildStatItem('📊', 'التحصيل', '$collectionRate%'),
                _buildStatItem(
                  '💰',
                  'الإيرادات',
                  '${totalCollected.toStringAsFixed(0)} ج',
                ),
                _buildStatItem(
                  '🎯',
                  'نصيبك',
                  '${teacherShare.toStringAsFixed(0)} ج',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String emoji, String label, String value) {
    return Column(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 24)),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 12),
        ),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ],
    );
  }

  /// Groups Section - تفصيل المجموعات
  Widget _buildGroupsSection() {
    final groups = (_salaryData?['groups'] as List?) ?? [];

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.purple.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.purple.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.groups_rounded,
                    color: Colors.purple.shade700,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'المجموعات (${groups.length})',
                  style: GoogleFonts.cairo(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            ...groups.map((group) => _buildGroupCard(group)),
          ],
        ),
      ),
    );
  }

  Widget _buildGroupCard(Map<String, dynamic> group) {
    final students = group['students'] as Map<String, dynamic>? ?? {};
    final totalStudents = students['total'] ?? 0;
    final paidStudents = students['paid'] ?? 0;
    final collectionRate = group['collection_rate'] ?? 0;
    final collected = (group['collected'] as num?)?.toDouble() ?? 0.0;
    final teacherShare = (group['teacher_share'] as num?)?.toDouble() ?? 0.0;
    final fee = (group['fee'] as num?)?.toDouble() ?? 0.0;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final isFullCollection = collectionRate >= 100;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isFullCollection
              ? (isDark ? Colors.green.shade700 : Colors.green.shade300)
              : (isDark ? Colors.grey.shade700 : Colors.grey.shade200),
          width: isFullCollection ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (isFullCollection) ...[
                          const Icon(Icons.star, color: Colors.amber, size: 18),
                          const SizedBox(width: 4),
                        ],
                        Expanded(
                          child: Text(
                            group['name'] ?? '',
                            style: GoogleFonts.cairo(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${group['grade_level'] ?? ''} • ${fee.toStringAsFixed(0)} ج/طالب',
                      style: TextStyle(
                        color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: collectionRate >= 80
                      ? (isDark ? Colors.green.shade900 : Colors.green.shade50)
                      : (isDark ? Colors.orange.shade900 : Colors.orange.shade50),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$collectionRate%',
                  style: TextStyle(
                    color: collectionRate >= 80
                        ? (isDark ? Colors.green.shade300 : Colors.green.shade700)
                        : (isDark ? Colors.orange.shade300 : Colors.orange.shade700),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '👥 $paidStudents/$totalStudents دفعوا',
                style: TextStyle(color: isDark ? Colors.grey.shade400 : Colors.grey.shade700),
              ),
              Text(
                '${collected.toStringAsFixed(0)} ج → ${teacherShare.toStringAsFixed(0)} ج',
                style: GoogleFonts.cairo(
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.purple.shade300 : Colors.purple.shade700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// By Grade Section - تحليل حسب المرحلة
  Widget _buildByGradeSection() {
    final byGrade = (_salaryData?['by_grade'] as List?) ?? [];
    if (byGrade.isEmpty) return const SizedBox.shrink();

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.orange.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.bar_chart_rounded,
                    color: Colors.orange.shade700,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'التحليل حسب المرحلة',
                  style: GoogleFonts.cairo(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            ...byGrade.map((grade) {
              final percentage =
                  (grade['percentage'] as num?)?.toDouble() ?? 0.0;
              final share = (grade['share'] as num?)?.toDouble() ?? 0.0;

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '📚 ${grade['grade'] ?? 'غير محدد'}',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        Text(
                          '${share.toStringAsFixed(0)} ج (${percentage.toStringAsFixed(0)}%)',
                          style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: percentage / 100,
                        backgroundColor: Colors.grey.shade200,
                        valueColor: AlwaysStoppedAnimation(
                          Colors.orange.shade400,
                        ),
                        minHeight: 8,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  /// Insights Section - الرؤى الذكية
  Widget _buildInsightsSection() {
    final insights = (_salaryData?['insights'] as List?) ?? [];
    if (insights.isEmpty) return const SizedBox.shrink();

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.teal.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.teal.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.lightbulb_rounded,
                    color: Colors.teal.shade700,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'رؤى ذكية',
                  style: GoogleFonts.cairo(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            ...insights.map((insight) {
              final type = insight['type'] ?? 'info';
              final icon = insight['icon'] ?? '💡';
              final message = insight['message'] ?? '';

              Color bgColor = type == 'success'
                  ? Colors.green.shade50
                  : type == 'warning'
                  ? Colors.orange.shade50
                  : Colors.blue.shade50;
              Color textColor = type == 'success'
                  ? Colors.green.shade700
                  : type == 'warning'
                  ? Colors.orange.shade700
                  : Colors.blue.shade700;

              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Text(icon, style: const TextStyle(fontSize: 20)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(message, style: TextStyle(color: textColor)),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  /// Comparison Section - مقارنة مع الشهر السابق
  Widget _buildComparisonSection() {
    final comparison =
        _salaryData?['comparison'] as Map<String, dynamic>? ?? {};
    final lastMonth = comparison['last_month'] as Map<String, dynamic>? ?? {};
    final current = comparison['current'] as Map<String, dynamic>? ?? {};
    final changeAmount =
        (comparison['change_amount'] as num?)?.toDouble() ?? 0.0;
    final changePercentage =
        (comparison['change_percentage'] as num?)?.toDouble() ?? 0.0;

    final lastShare = (lastMonth['share'] as num?)?.toDouble() ?? 0.0;
    final currentShare = (current['share'] as num?)?.toDouble() ?? 0.0;

    if (lastShare == 0 && currentShare == 0) return const SizedBox.shrink();

    final isPositive = changeAmount >= 0;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isPositive ? Colors.green.shade200 : Colors.red.shade200,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isPositive
                        ? Colors.green.shade50
                        : Colors.red.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    isPositive
                        ? Icons.trending_up_rounded
                        : Icons.trending_down_rounded,
                    color: isPositive
                        ? Colors.green.shade700
                        : Colors.red.shade700,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'مقارنة مع الشهر السابق',
                  style: GoogleFonts.cairo(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Column(
                  children: [
                    Text(
                      'الشهر السابق',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                    Text(
                      '${lastShare.toStringAsFixed(0)} ج',
                      style: GoogleFonts.cairo(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                Icon(Icons.arrow_forward_rounded, color: Colors.grey.shade400),
                Column(
                  children: [
                    Text(
                      'هذا الشهر',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                    Text(
                      '${currentShare.toStringAsFixed(0)} ج',
                      style: GoogleFonts.cairo(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: isPositive ? Colors.green : Colors.red,
                      ),
                    ),
                  ],
                ),
              ],
            ),

            if (changeAmount != 0) ...[
              const SizedBox(height: 12),
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: isPositive
                        ? Colors.green.shade50
                        : Colors.red.shade50,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${isPositive ? "+" : ""}${changeAmount.toStringAsFixed(0)} ج (${changePercentage.toStringAsFixed(0)}%)',
                    style: TextStyle(
                      color: isPositive
                          ? Colors.green.shade700
                          : Colors.red.shade700,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBaseSalaryCard() {
    return _buildSectionCard(
      title: 'الراتب الأساسي',
      icon: Icons.account_balance_wallet_rounded,
      color: Colors.blue,
      child: _buildAmountRow(
        'الراتب الأساسي الشهري',
        (_salaryData?['base_salary'] as num?)?.toDouble() ?? 0.0,
      ),
    );
  }

  Widget _buildSessionsCard() {
    final sessions = _salaryData?['sessions'] as List;
    final total = (_salaryData?['sessions_total'] as num?)?.toDouble() ?? 0.0;

    return _buildSectionCard(
      title: 'الحصص الدراسية',
      icon: Icons.school_rounded,
      color: Colors.purple,
      child: Column(
        children: [
          ...sessions.map(
            (session) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          session['group'],
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        Text(
                          '${session['count']} حصة × ${session['rate']} ج',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '${session['total']} ج',
                    style: GoogleFonts.cairo(
                      fontWeight: FontWeight.bold,
                      color: Colors.purple.shade700,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Divider(),
          _buildAmountRow('إجمالي الحصص', total, isBold: true),
        ],
      ),
    );
  }

  Widget _buildPercentageCard() {
    final items = _salaryData?['percentage_items'] as List;
    final total = (_salaryData?['percentage_total'] as num?)?.toDouble() ?? 0.0;

    return _buildSectionCard(
      title: 'نسب الحصص',
      icon: Icons.percent_rounded,
      color: Colors.orange,
      child: Column(
        children: [
          ...items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item['group'],
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        Text(
                          '${item['percentage']}% من ${item['collected']} ج (${item['students']} طلاب)',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '${item['total']} ج',
                    style: GoogleFonts.cairo(
                      fontWeight: FontWeight.bold,
                      color: Colors.orange.shade700,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Divider(),
          _buildAmountRow('إجمالي النسب', total, isBold: true),
        ],
      ),
    );
  }

  Widget _buildEditableCard({
    required String title,
    required IconData icon,
    required Color color,
    required List<Map<String, dynamic>> items,
    required VoidCallback onAdd,
    required Function(int) onRemove,
    bool isDeduction = false,
  }) {
    final total = items.fold(
      0.0,
      (sum, item) => sum + (item['amount'] as num).toDouble(),
    );

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: color.withValues(alpha: 0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(icon, color: color, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      title,
                      style: GoogleFonts.cairo(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  onPressed: onAdd,
                  icon: const Icon(Icons.add_circle_outline),
                  color: color,
                  tooltip: 'إضافة',
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (items.isEmpty)
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(
                  'لا توجد عناصر مضافة',
                  style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
                ),
              ),
            ...items.asMap().entries.map((entry) {
              final idx = entry.key;
              final item = entry.value;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Expanded(child: Text(item['description'])),
                    Text(
                      '${isDeduction ? "-" : ""}${item['amount']} ج',
                      style: GoogleFonts.cairo(
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                    const SizedBox(width: 8),
                    InkWell(
                      onTap: () => onRemove(idx),
                      child: Icon(
                        Icons.delete_outline,
                        size: 18,
                        color: Colors.grey.shade400,
                      ),
                    ),
                  ],
                ),
              );
            }),
            if (items.isNotEmpty) ...[
              const Divider(),
              _buildAmountRow(
                'الإجمالي',
                total,
                isBold: true,
                isNegative: isDeduction,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTotalCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.blue.shade700, Colors.blue.shade900],
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'إجمالي الراتب',
                  style: GoogleFonts.cairo(color: Colors.white70, fontSize: 16),
                ),
                Text(
                  '${_currentGross.toStringAsFixed(2)} ج',
                  style: GoogleFonts.cairo(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(color: Colors.white24),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'صافي الراتب',
                  style: GoogleFonts.cairo(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '${_currentNet.toStringAsFixed(2)} ج',
                  style: GoogleFonts.cairo(
                    color: Colors.greenAccent,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionsRow() {
    final status = _salaryData?['status'] ?? 'draft';
    final isDraft = status == 'draft' || status == 'pending';
    final isApproved = status == 'approved';
    final isPaid = status == 'paid';

    return Row(
      children: [
        // زر إغلاق
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close_rounded),
            label: const Text('إغلاق'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.all(16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),

        // الأزرار حسب الحالة
        if (isPaid) ...[
          // مدفوع - عرض فقط
          Expanded(
            flex: 2,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle, color: Colors.green.shade700),
                  const SizedBox(width: 8),
                  Text(
                    'تم دفع الراتب ✓',
                    style: TextStyle(
                      color: Colors.green.shade700,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ] else if (isApproved) ...[
          // معتمد - زر تسجيل الدفع
          Expanded(
            flex: 2,
            child: FilledButton.icon(
              onPressed: _isSaving ? null : () => _showPaymentDialog(),
              icon: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.payments_rounded),
              label: const Text('تسجيل الدفع'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.all(16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                backgroundColor: Colors.blue,
              ),
            ),
          ),
        ] else ...[
          // مسودة - زر الاعتماد
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _isSaving ? null : () => _saveSalary('draft'),
              icon: const Icon(Icons.save_outlined),
              label: const Text('حفظ كمسودة'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.all(16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: FilledButton.icon(
              onPressed: _isSaving ? null : () => _saveSalary('approved'),
              icon: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.check_circle_rounded),
              label: const Text('اعتماد الراتب'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.all(16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                backgroundColor: Colors.green,
              ),
            ),
          ),
        ],
      ],
    );
  }

  /// Dialog لتسجيل الدفع
  Future<void> _showPaymentDialog() async {
    String selectedMethod = 'cash';
    final referenceController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.payments_rounded, color: Colors.blue.shade700),
              const SizedBox(width: 12),
              const Text('تسجيل دفع الراتب'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'صافي الراتب: ${_currentNet.toStringAsFixed(2)} ج',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              const Text('طريقة الدفع:'),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: selectedMethod,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                ),
                items: const [
                  DropdownMenuItem(value: 'cash', child: Text('نقدي')),
                  DropdownMenuItem(
                    value: 'bank_transfer',
                    child: Text('تحويل بنكي'),
                  ),
                  DropdownMenuItem(
                    value: 'vodafone_cash',
                    child: Text('فودافون كاش'),
                  ),
                  DropdownMenuItem(value: 'instapay', child: Text('إنستا باي')),
                ],
                onChanged: (v) => setDialogState(() => selectedMethod = v!),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: referenceController,
                decoration: const InputDecoration(
                  labelText: 'رقم المرجع (اختياري)',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('إلغاء'),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.pop(context, true),
              icon: const Icon(Icons.check),
              label: const Text('تأكيد الدفع'),
            ),
          ],
        ),
      ),
    );

    if (confirmed == true) {
      await _markAsPaid(selectedMethod, referenceController.text);
    }
  }

  /// تسجيل الراتب كمدفوع
  Future<void> _markAsPaid(String paymentMethod, String? reference) async {
    setState(() => _isSaving = true);

    try {
      final repository = context.read<TeachersRepository>();

      final dataToSave = Map<String, dynamic>.from(_salaryData!);
      dataToSave['bonuses'] = _bonuses;
      dataToSave['deductions'] = _deductions;
      dataToSave['status'] = 'paid';
      dataToSave['payment_method'] = paymentMethod;
      dataToSave['payment_reference'] = reference;
      dataToSave['payment_date'] = DateTime.now().toIso8601String();

      await repository.saveTeacherSalary(
        teacherId: widget.teacherId,
        month: widget.month,
        year: widget.year,
        salaryData: dataToSave,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✓ تم تسجيل دفع الراتب بنجاح'),
            backgroundColor: Colors.green,
          ),
        );
        _loadSalaryData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('حدث خطأ: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required Color color,
    required Widget child,
  }) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: color.withValues(alpha: 0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: GoogleFonts.cairo(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }

  Widget _buildAmountRow(
    String label,
    double amount, {
    Color? color,
    bool isBold = false,
    bool isNegative = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            '${isNegative ? "-" : ""}${amount.toStringAsFixed(2)} ج',
            style: GoogleFonts.cairo(
              fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showAddItemDialog(String type) async {
    final controller = TextEditingController();
    final amountController = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(type == 'bonus' ? 'إضافة مكافأة' : 'إضافة خصم'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: controller,
              decoration: const InputDecoration(labelText: 'الوصف'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: amountController,
              decoration: const InputDecoration(labelText: 'المبلغ'),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () {
              final amount = double.tryParse(amountController.text);
              if (amount != null && controller.text.isNotEmpty) {
                setState(() {
                  final list = type == 'bonus' ? _bonuses : _deductions;
                  list.add({'description': controller.text, 'amount': amount});
                });
                Navigator.pop(context);
              }
            },
            child: const Text('إضافة'),
          ),
        ],
      ),
    );
  }

  Future<void> _saveSalary(String status) async {
    setState(() => _isSaving = true);

    try {
      final repository = context.read<TeachersRepository>();

      // Merge current data with local edits
      final dataToSave = Map<String, dynamic>.from(_salaryData!);
      dataToSave['bonuses'] = _bonuses;
      dataToSave['deductions'] = _deductions;
      dataToSave['status'] = status;

      await repository.saveTeacherSalary(
        teacherId: widget.teacherId,
        month: widget.month,
        year: widget.year,
        salaryData: dataToSave,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'تم ${status == 'approved' ? 'اعتماد' : 'حفظ'} الراتب بنجاح',
            ),
            backgroundColor: Colors.green,
          ),
        );
        // Refresh data to get new status
        _loadSalaryData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('حدث خطأ: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _printInvoice() async {
    try {
      final pdf = await _generatePdf(PdfPageFormat.a4);
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save(),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('فشل الطباعة: $e')));
    }
  }

  Future<void> _exportPDF() async {
    try {
      final pdf = await _generatePdf(PdfPageFormat.a4);
      await Printing.sharePdf(
        bytes: await pdf.save(),
        filename:
            'salary_${widget.teacherId}_${widget.month}_${widget.year}.pdf',
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('فشل التصدير: $e')));
    }
  }

  Future<pw.Document> _generatePdf(PdfPageFormat format) async {
    final pdf = pw.Document();
    final font = await PdfGoogleFonts.cairoRegular();
    final boldFont = await PdfGoogleFonts.cairoBold();

    pdf.addPage(
      pw.Page(
        pageTheme: pw.PageTheme(
          pageFormat: format,
          theme: pw.ThemeData.withFont(base: font, bold: boldFont),
          textDirection: pw.TextDirection.rtl, // Important for Arabic
        ),
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header
              pw.Header(
                level: 0,
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'EdSentre',
                          style: pw.TextStyle(
                            fontSize: 24,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.blue800,
                          ),
                        ),
                        pw.Text(
                          'نظام إدارة المركز التعليمي',
                          style: const pw.TextStyle(
                            fontSize: 12,
                            color: PdfColors.grey600,
                          ),
                        ),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text(
                          'فاتورة راتب',
                          style: pw.TextStyle(
                            fontSize: 20,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                        pw.Text(
                          '$monthName ${widget.year}',
                          style: const pw.TextStyle(fontSize: 16),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 20),

              // Teacher Info
              pw.Container(
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey100,
                  borderRadius: pw.BorderRadius.circular(4),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'اسم المعلم: ${_salaryData!['teacher_name']}',
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                    ),
                    pw.Text('الراتب الأساسي: ${_salaryData!['base_salary']} ج'),
                  ],
                ),
              ),
              pw.SizedBox(height: 20),

              // Sessions
              if ((_salaryData!['sessions'] as List? ?? []).isNotEmpty) ...[
                pw.Text(
                  'الحصص الدراسية',
                  style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 5),
                pw.Table(
                  border: pw.TableBorder.all(color: PdfColors.grey300),
                  children: [
                    pw.TableRow(
                      decoration: const pw.BoxDecoration(
                        color: PdfColors.blue50,
                      ),
                      children: [
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(5),
                          child: pw.Text(
                            'المجموعة',
                            textAlign: pw.TextAlign.center,
                            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(5),
                          child: pw.Text(
                            'عدد الحصص',
                            textAlign: pw.TextAlign.center,
                            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(5),
                          child: pw.Text(
                            'سعر الحصة',
                            textAlign: pw.TextAlign.center,
                            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(5),
                          child: pw.Text(
                            'الإجمالي',
                            textAlign: pw.TextAlign.center,
                            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    ...(_salaryData!['sessions'] as List).map(
                      (s) => pw.TableRow(
                        children: [
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(5),
                            child: pw.Text(s['group'] ?? ''),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(5),
                            child: pw.Text('${s['count']}'),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(5),
                            child: pw.Text('${s['rate']}'),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(5),
                            child: pw.Text('${s['total']}'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                pw.SizedBox(height: 10),
              ],

              // Totals
              pw.Divider(),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('إجمالي الراتب:', style: pw.TextStyle(fontSize: 14)),
                  pw.Text(
                    '${_currentGross.toStringAsFixed(2)} ج',
                    style: pw.TextStyle(fontSize: 14),
                  ),
                ],
              ),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'صافي الراتب:',
                    style: pw.TextStyle(
                      fontSize: 18,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.Text(
                    '${_currentNet.toStringAsFixed(2)} ج',
                    style: pw.TextStyle(
                      fontSize: 18,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.green700,
                    ),
                  ),
                ],
              ),

              pw.SizedBox(height: 30),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'توقيع المحاسب',
                    style: const pw.TextStyle(fontSize: 12),
                  ),
                  pw.Text(
                    'توقيع المعلم',
                    style: const pw.TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
    return pdf;
  }
}


