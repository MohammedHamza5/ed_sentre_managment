/// Student Account Statement Screen - EdSentre
/// شاشة كشف حساب الطالب - UI مودرن
library;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';
import '../../../payments/data/repositories/payment_repository.dart';

class StudentAccountStatementScreen extends StatefulWidget {
  final String studentId;
  final String studentName;

  const StudentAccountStatementScreen({
    super.key,
    required this.studentId,
    required this.studentName,
  });

  @override
  State<StudentAccountStatementScreen> createState() =>
      _StudentAccountStatementScreenState();
}

class _StudentAccountStatementScreenState
    extends State<StudentAccountStatementScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animationController;
  late final Animation<double> _fadeAnimation;

  bool _isLoading = true;
  Map<String, dynamic>? _accountData;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );

    _loadAccountStatement();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadAccountStatement() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final repository = context.read<PaymentRepository>();
      final data = await repository.getStudentAccountStatement(
        widget.studentId,
      );

      if (mounted) {
        setState(() {
          _accountData = data;
          _isLoading = false;
        });
        _animationController.forward();
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // Modern App Bar with Gradient
          SliverAppBar.large(
            expandedHeight: 200,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                'كشف الحساب',
                style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
              ),
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: isDark
                        ? [Colors.teal.shade900, Colors.teal.shade700]
                        : [Colors.teal.shade400, Colors.teal.shade600],
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        const SizedBox(height: 80),
                        Text(
                          widget.studentName,
                          style: GoogleFonts.cairo(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            color: Colors.white.withValues(alpha: 0.9),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_rounded),
              onPressed: () => Navigator.pop(context),
            ),
            actions: [
              // Export button
              IconButton(
                icon: const Icon(Icons.picture_as_pdf_rounded),
                onPressed: _exportPDF,
                tooltip: 'تصدير PDF',
              ),
              IconButton(
                icon: const Icon(Icons.share_rounded),
                onPressed: _share,
                tooltip: 'مشاركة',
              ),
            ],
          ),

          // Content
          if (_isLoading)
            const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_errorMessage != null)
            SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.error_outline_rounded,
                      size: 64,
                      color: Colors.red.shade300,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'حدث خطأ',
                      style: GoogleFonts.cairo(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _errorMessage!,
                      style: TextStyle(color: Colors.red.shade300),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      onPressed: _loadAccountStatement,
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('إعادة المحاولة'),
                    ),
                  ],
                ),
              ),
            )
          else
            SliverToBoxAdapter(
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Summary Cards
                      _buildSummarySection(),

                      const SizedBox(height: 24),

                      // Enrolled Subjects
                      _buildEnrolledSubjectsSection(),

                      const SizedBox(height: 24),

                      // Payment History
                      _buildPaymentHistorySection(),

                      const SizedBox(height: 100),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSummarySection() {
    final totalPaid = _accountData?['total_paid'] as double? ?? 0.0;
    final totalDue = _accountData?['total_due'] as double? ?? 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'الملخص المالي',
          style: GoogleFonts.cairo(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),

        // Cards Row
        Row(
          children: [
            // Total Paid Card
            Expanded(
              child: _buildSummaryCard(
                title: 'المدفوع',
                amount: totalPaid,
                icon: Icons.check_circle_rounded,
                gradient: LinearGradient(
                  colors: [Colors.green.shade400, Colors.green.shade600],
                ),
              ),
            ),
            const SizedBox(width: 12),

            // Total Due Card
            Expanded(
              child: _buildSummaryCard(
                title: 'المتبقي',
                amount: totalDue,
                icon: Icons.pending_rounded,
                gradient: LinearGradient(
                  colors: totalDue > 0
                      ? [Colors.orange.shade400, Colors.orange.shade600]
                      : [Colors.grey.shade400, Colors.grey.shade600],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSummaryCard({
    required String title,
    required double amount,
    required IconData icon,
    required LinearGradient gradient,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: gradient.colors.first.withValues(alpha: 0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.white, size: 32),
          const SizedBox(height: 12),
          Text(
            title,
            style: GoogleFonts.cairo(
              fontSize: 14,
              color: Colors.white.withValues(alpha: 0.9),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${amount.toStringAsFixed(2)} ج',
            style: GoogleFonts.cairo(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEnrolledSubjectsSection() {
    final enrollments = _accountData?['enrollments'] as List? ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.class_rounded, color: Colors.blue.shade700),
            const SizedBox(width: 8),
            Text(
              'المواد المسجلة',
              style: GoogleFonts.cairo(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        if (enrollments.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.inbox_rounded,
                      size: 48,
                      color: Colors.grey.shade400,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'لا توجد مواد مسجلة',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
            ),
          )
        else
          ...enrollments.map((enrollment) {
            final enrollmentMap = enrollment as Map<String, dynamic>;
            final group = enrollmentMap['groups'] as Map<String, dynamic>?;
            final course = group?['courses'] as Map<String, dynamic>?;
            final groupName = group?['group_name'] as String? ?? '';
            final courseName = course?['name'] as String? ?? 'مادة غير معروفة';
            // استخدام السعر المحسوب من نظام التسعير الذكي
            final displayFee =
                (enrollmentMap['calculated_fee'] as num?)?.toDouble() ?? 0.0;
            final priceSource =
                enrollmentMap['price_source'] as String? ?? 'default';
            final displayName = groupName.isNotEmpty ? groupName : courseName;

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.blue.shade50,
                  child: Icon(Icons.book_rounded, color: Colors.blue.shade700),
                ),
                title: Text(
                  displayName,
                  style: GoogleFonts.cairo(fontWeight: FontWeight.w600),
                ),
                subtitle: Text('${displayFee.toStringAsFixed(0)} ج / شهر'),
                trailing: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'نشط',
                    style: TextStyle(
                      color: Colors.green.shade700,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            );
          }),
      ],
    );
  }

  Widget _buildPaymentHistorySection() {
    final payments = _accountData?['payments'] as List? ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.history_rounded, color: Colors.purple.shade700),
            const SizedBox(width: 8),
            Text(
              'سجل المدفوعات',
              style: GoogleFonts.cairo(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        if (payments.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.receipt_long_rounded,
                      size: 48,
                      color: Colors.grey.shade400,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'لا توجد مدفوعات',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
            ),
          )
        else
          ...payments.map((payment) {
            // TODO: Build payment cards from actual data
            return const SizedBox.shrink();
          }),
      ],
    );
  }

  Future<void> _exportPDF() async {
    try {
      final pdf = await _generatePdf(PdfPageFormat.a4);
      await Printing.sharePdf(
        bytes: await pdf.save(),
        filename: 'statement_${widget.studentId}.pdf',
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('فشل التصدير: $e')));
    }
  }

  Future<void> _share() async {
    // Sharing is effectively same as export pdf for now
    await _exportPDF();
  }

  Future<pw.Document> _generatePdf(PdfPageFormat format) async {
    final pdf = pw.Document();
    final font = await PdfGoogleFonts.cairoRegular();
    final boldFont = await PdfGoogleFonts.cairoBold();
    final totalPaid = _accountData?['total_paid'] as double? ?? 0.0;
    final totalDue = _accountData?['total_due'] as double? ?? 0.0;

    pdf.addPage(
      pw.Page(
        pageTheme: pw.PageTheme(
          pageFormat: format,
          theme: pw.ThemeData.withFont(base: font, bold: boldFont),
          textDirection: pw.TextDirection.rtl,
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
                          'كشف حساب طالب',
                          style: const pw.TextStyle(fontSize: 16),
                        ),
                      ],
                    ),
                    pw.Text(
                      widget.studentName,
                      style: pw.TextStyle(
                        fontSize: 20,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 20),

              // Summary
              pw.Container(
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey100,
                  borderRadius: pw.BorderRadius.circular(4),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                  children: [
                    pw.Column(
                      children: [
                        pw.Text(
                          'المدفوع',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                        ),
                        pw.Text(
                          '$totalPaid ج',
                          style: const pw.TextStyle(
                            color: PdfColors.green700,
                            fontSize: 18,
                          ),
                        ),
                      ],
                    ),
                    pw.Column(
                      children: [
                        pw.Text(
                          'المتبقي',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                        ),
                        pw.Text(
                          '$totalDue ج',
                          style: pw.TextStyle(
                            color: totalDue > 0
                                ? PdfColors.red700
                                : PdfColors.grey700,
                            fontSize: 18,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 20),

              // Payment Items Table (Simplified)
              // Note: _accountData['payments'] is a List<dynamic>
              if ((_accountData?['payments'] as List?)?.isNotEmpty ??
                  false) ...[
                pw.Text(
                  'آخر المعاملات',
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
                            'التاريخ',
                            textAlign: pw.TextAlign.center,
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(5),
                          child: pw.Text(
                            'المبلغ',
                            textAlign: pw.TextAlign.center,
                          ),
                        ),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(5),
                          child: pw.Text(
                            'المدفوع',
                            textAlign: pw.TextAlign.center,
                          ),
                        ),
                      ],
                    ),
                    ...(_accountData!['payments'] as List).take(10).map((p) {
                      final total = (p['amount'] as num?)?.toDouble() ?? 0.0;
                      final paid =
                          (p['paid_amount'] as num?)?.toDouble() ?? 0.0;
                      final date = DateTime.parse(
                        p['created_at'],
                      ).toString().substring(0, 10);
                      return pw.TableRow(
                        children: [
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(5),
                            child: pw.Text(date),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(5),
                            child: pw.Text('$total'),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(5),
                            child: pw.Text('$paid'),
                          ),
                        ],
                      );
                    }),
                  ],
                ),
              ],
            ],
          );
        },
      ),
    );
    return pdf;
  }
}


