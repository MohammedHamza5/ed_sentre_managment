/// Teacher Salaries History Screen
/// شاشة سجل رواتب المعلم
library;

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../data/repositories/teachers_repository.dart';
import '../teacher_salary_invoice_screen.dart';

class TeacherSalariesScreen extends StatefulWidget {
  final String teacherId;
  final String teacherName;

  const TeacherSalariesScreen({
    super.key,
    required this.teacherId,
    required this.teacherName,
  });

  @override
  State<TeacherSalariesScreen> createState() => _TeacherSalariesScreenState();
}

class _TeacherSalariesScreenState extends State<TeacherSalariesScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _history = [];
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final repository = context.read<TeachersRepository>();
      final data = await repository.getTeacherSalaryHistory(widget.teacherId);

      if (mounted) {
        setState(() {
          _history = data;
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

  void _generateNewSalary() async {
    // Show dialog to pick month/year
    final now = DateTime.now();
    int selectedMonth = now.month;
    int selectedYear = now.year;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('إنشاء راتب جديد'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    const Text('الشهر: '),
                    DropdownButton<int>(
                      value: selectedMonth,
                      items: List.generate(12, (i) => i + 1)
                          .map(
                            (m) => DropdownMenuItem(
                              value: m,
                              child: Text(_getMonthName(m)),
                            ),
                          )
                          .toList(),
                      onChanged: (v) =>
                          setDialogState(() => selectedMonth = v!),
                    ),
                  ],
                ),
                Row(
                  children: [
                    const Text('السنة: '),
                    DropdownButton<int>(
                      value: selectedYear,
                      items: List.generate(5, (i) => now.year - 2 + i)
                          .map(
                            (y) =>
                                DropdownMenuItem(value: y, child: Text('$y')),
                          )
                          .toList(),
                      onChanged: (v) => setDialogState(() => selectedYear = v!),
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
              FilledButton(
                onPressed: () {
                  Navigator.pop(context);
                  _navigateToInvoice(selectedMonth, selectedYear);
                },
                child: const Text('إنشاء'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _navigateToInvoice(int month, int year) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TeacherSalaryInvoiceScreen(
          teacherId: widget.teacherId,
          month: month,
          year: year,
        ),
      ),
    );
    if (!mounted) return;
    _loadHistory(); // Refresh after return
  }

  String _getMonthName(int month) {
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
    return months[month];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.teacherName} - الرواتب'),
        actions: [
          IconButton(
            onPressed: _generateNewSalary,
            icon: const Icon(Icons.add_circle_outline),
            tooltip: 'راتب جديد',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _history.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.history_toggle_off,
                    size: 64.sp,
                    color: Colors.grey,
                  ),
                  SizedBox(height: 16.h),
                  const Text('لا يوجد سجل رواتب'),
                  SizedBox(height: 16.h),
                  FilledButton.icon(
                    onPressed: _generateNewSalary,
                    icon: const Icon(Icons.add),
                    label: const Text('إنشاء أول راتب'),
                  ),
                ],
              ),
            )
          : ListView.separated(
              padding: EdgeInsets.all(16.w),
              itemCount: _history.length,
              separatorBuilder: (c, i) => SizedBox(height: 12.h),
              itemBuilder: (context, index) {
                final item = _history[index];
                final status = item['status'] ?? 'draft';
                final isPaid = status == 'paid';
                final isDark = Theme.of(context).brightness == Brightness.dark;

                return Card(
                  elevation: 0,
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.r),
                    side: BorderSide(
                      color: isDark
                          ? Colors.grey.shade700
                          : Colors.grey.shade300,
                    ),
                  ),
                  child: ListTile(
                    onTap: () =>
                        _navigateToInvoice(item['month'], item['year']),
                    leading: CircleAvatar(
                      backgroundColor: isPaid
                          ? (isDark
                                ? Colors.green.shade900
                                : Colors.green.shade100)
                          : (isDark
                                ? Colors.orange.shade900
                                : Colors.orange.shade100),
                      child: Icon(
                        isPaid ? Icons.check : Icons.access_time_filled,
                        color: isPaid
                            ? (isDark ? Colors.green.shade300 : Colors.green)
                            : (isDark ? Colors.orange.shade300 : Colors.orange),
                      ),
                    ),
                    title: Text(
                      '${_getMonthName(item['month'])} ${item['year']}',
                      style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      'صافي: ${(item['net_salary'] as num).toDouble()} ج',
                    ),
                    trailing: Icon(Icons.arrow_forward_ios, size: 16.sp),
                  ),
                );
              },
            ),
    );
  }
}
