/// Enhanced Students Report Screen - EdSentre
/// شاشة تقارير الطلاب المحسّنة
library;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';
import '../../../../core/providers/center_provider.dart';
import '../../../../shared/models/models.dart';
import '../services/report_export_service.dart';
import '../data/reports_repository.dart';

class StudentsReportScreen extends StatefulWidget {
  const StudentsReportScreen({super.key});

  @override
  State<StudentsReportScreen> createState() => _StudentsReportScreenState();
}

class _StudentsReportScreenState extends State<StudentsReportScreen> {
  final _reportsRepo = ReportsRepository();

  bool _isLoading = false;
  List<Student> _students = [];
  String? _errorMessage;

  // Filters
  String? _selectedGrade;
  StudentStatus? _selectedStatus;
  String _searchQuery = '';
  bool _isInit = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_isInit) {
      _loadReport();
      _isInit = false;
    }
  }

  Future<void> _loadReport() async {
    final centerId = context.read<CenterProvider>().centerId;
    if (centerId == null) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final students = await _reportsRepo.getStudentsReport(
        centerId: centerId,
        gradeLevel: _selectedGrade,
        status: _selectedStatus,
        searchQuery: _searchQuery.isEmpty ? null : _searchQuery,
      );

      if (!mounted) return;

      setState(() {
        _students = students;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _exportReport() async {
    if (_students.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('لا توجد بيانات للتصدير')));
      return;
    }

    try {
      final pdfBytes = await ReportExportService.generateStudentListPdf(
        _students,
      );
      await Printing.sharePdf(
        bytes: pdfBytes,
        filename:
            'students_report_${DateTime.now().millisecondsSinceEpoch}.pdf',
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('فشل التصدير: $e')));
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
            expandedHeight: 180,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                'تقرير الطلاب',
                style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
              ),
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: isDark
                        ? [Colors.cyan.shade900, Colors.cyan.shade700]
                        : [Colors.cyan.shade400, Colors.cyan.shade600],
                  ),
                ),
              ),
            ),
            actions: [
              // Export button
              IconButton(
                icon: const Icon(Icons.download_rounded),
                onPressed: _exportReport,
                tooltip: 'تصدير PDF',
              ),
            ],
          ),

          // Content
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Filters Card
                  _buildFiltersCard(),

                  const SizedBox(height: 20),

                  // Statistics Card
                  if (!_isLoading && _students.isNotEmpty)
                    _buildStatisticsCard(),

                  const SizedBox(height: 20),

                  // Students List
                  if (_isLoading)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(40),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  else if (_errorMessage != null)
                    _buildErrorCard()
                  else if (_students.isEmpty)
                    _buildEmptyState()
                  else
                    _buildStudentsList(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFiltersCard() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'الفلاتر',
              style: GoogleFonts.cairo(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),

            // Search
            TextField(
              decoration: InputDecoration(
                hintText: 'بحث بالاسم أو الهاتف...',
                prefixIcon: const Icon(Icons.search_rounded),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
              ),
              onChanged: (value) {
                setState(() => _searchQuery = value);
                _loadReport();
              },
            ),

            const SizedBox(height: 12),

            Row(
              children: [
                // Grade Filter
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _selectedGrade,
                    decoration: InputDecoration(
                      labelText: 'المرحلة',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                    ),
                    items: const [
                      DropdownMenuItem(value: null, child: Text('الكل')),
                      DropdownMenuItem(value: '1ثانوي', child: Text('1ث')),
                      DropdownMenuItem(value: '2ثانوي', child: Text('2ث')),
                      DropdownMenuItem(value: '3ثانوي', child: Text('3ث')),
                    ],
                    onChanged: (value) {
                      setState(() => _selectedGrade = value);
                      _loadReport();
                    },
                  ),
                ),

                const SizedBox(width: 12),

                // Status Filter
                Expanded(
                  child: DropdownButtonFormField<StudentStatus>(
                    value: _selectedStatus,
                    decoration: InputDecoration(
                      labelText: 'الحالة',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                    ),
                    items: const [
                      DropdownMenuItem(value: null, child: Text('الكل')),
                      DropdownMenuItem(
                        value: StudentStatus.active,
                        child: Text('نشط'),
                      ),
                      DropdownMenuItem(
                        value: StudentStatus.inactive,
                        child: Text('غير نشط'),
                      ),
                      DropdownMenuItem(
                        value: StudentStatus.suspended,
                        child: Text('موقوف'),
                      ),
                      DropdownMenuItem(
                        value: StudentStatus.overdue,
                        child: Text('متأخر'),
                      ),
                    ],
                    onChanged: (value) {
                      setState(() => _selectedStatus = value);
                      _loadReport();
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatisticsCard() {
    final activeCount = _students
        .where((s) => s.status == StudentStatus.active)
        .length;
    final inactiveCount = _students
        .where((s) => s.status == StudentStatus.inactive)
        .length;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'الإحصائيات',
              style: GoogleFonts.cairo(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    label: 'الإجمالي',
                    value: '${_students.length}',
                    icon: Icons.people_rounded,
                    color: Colors.blue,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatItem(
                    label: 'نشط',
                    value: '$activeCount',
                    icon: Icons.check_circle_rounded,
                    color: Colors.green,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatItem(
                    label: 'غير نشط',
                    value: '$inactiveCount',
                    icon: Icons.pause_circle_rounded,
                    color: Colors.orange,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.cairo(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(label, style: TextStyle(fontSize: 12, color: color)),
        ],
      ),
    );
  }

  Widget _buildStudentsList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'قائمة الطلاب (${_students.length})',
          style: GoogleFonts.cairo(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),

        ..._students.map((student) {
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: _getStatusColor(
                  student.status,
                ).withValues(alpha: 0.1),
                child: Text(
                  _getInitials(student.name),
                  style: TextStyle(
                    color: _getStatusColor(student.status),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              title: Text(
                student.name,
                style: GoogleFonts.cairo(fontWeight: FontWeight.w600),
              ),
              subtitle: Text(student.gradeLevel ?? 'غير محدد'),
              trailing: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: _getStatusColor(student.status).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _getStatusText(student.status),
                  style: TextStyle(
                    color: _getStatusColor(student.status),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.inbox_rounded, size: 64, color: Colors.grey.shade400),
              const SizedBox(height: 16),
              Text(
                'لا توجد بيانات',
                style: GoogleFonts.cairo(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'جرّب تغيير الفلاتر',
                style: TextStyle(color: Colors.grey.shade500),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Center(
          child: Column(
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
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _errorMessage ?? 'خطأ غير معروف',
                style: TextStyle(color: Colors.red.shade300),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _loadReport,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('إعادة المحاولة'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getInitials(String name) {
    final parts = name.trim().split(' ');
    if (parts.isEmpty) return '؟';
    if (parts.length == 1) return parts[0][0];
    return '${parts[0][0]}${parts[parts.length - 1][0]}';
  }

  Color _getStatusColor(StudentStatus status) {
    switch (status) {
      case StudentStatus.active:
        return Colors.green;
      case StudentStatus.inactive:
        return Colors.grey;
      case StudentStatus.suspended:
        return Colors.red;
      case StudentStatus.overdue:
        return Colors.orange;
    }
  }

  String _getStatusText(StudentStatus status) {
    switch (status) {
      case StudentStatus.active:
        return 'نشط';
      case StudentStatus.inactive:
        return 'غير نشط';
      case StudentStatus.suspended:
        return 'موقوف';
      case StudentStatus.overdue:
        return 'متأخر';
    }
  }
}
