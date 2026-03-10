import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter/foundation.dart'; // For setEquals
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/providers/center_provider.dart';
import '../../../../shared/models/models.dart';
import '../../data/repositories/students_repository.dart';
import '../../../subjects/data/repositories/subjects_repository.dart';
import '../../../attendance/data/repositories/attendance_repository.dart';
import '../../../payments/data/repositories/payment_repository.dart';
import '../../../../shared/widgets/loading/loading_indicator.dart';
import 'package:printing/printing.dart';
import '../../services/student_export_service.dart';

/// شاشة تفاصيل الطالب
class StudentDetailsScreen extends StatefulWidget {
  final String studentId;

  const StudentDetailsScreen({super.key, required this.studentId});

  @override
  State<StudentDetailsScreen> createState() => _StudentDetailsScreenState();
}

class _StudentDetailsScreenState extends State<StudentDetailsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  bool _isLoading = true;
  String? _error;

  Student? _student;
  List<Map<String, dynamic>> _subjectsWithTeachers =
      []; // Subject + teacher names
  List<AttendanceRecord> _attendance = [];
  List<Payment> _payments = [];
  double _attendanceRate = 0.0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final studentsRepo = context.read<StudentsRepository>();
      final attendanceRepo = context.read<AttendanceRepository>();
      final paymentsRepo = context.read<PaymentRepository>();

      // 1. Fetch Student
      _student = await studentsRepo.getStudent(widget.studentId);

      // 2. Fetch Subjects with Teacher names
      _subjectsWithTeachers = await studentsRepo.getStudentSubjectsWithTeachers(
        widget.studentId,
      );

      // 3. Fetch Attendance
      _attendance = await attendanceRepo.getAttendanceByStudent(
        widget.studentId,
      );

      // 4. Calculate attendance rate
      if (_attendance.isNotEmpty) {
        final presentCount = _attendance.where((a) => a.isPresent).length;
        _attendanceRate = (presentCount / _attendance.length) * 100;
      }

      // 5. Fetch Payments
      _payments = await paymentsRepo.getPaymentsByStudent(widget.studentId);

      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading student details: $e');
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = 'فشل تحميل بيانات الطالب: $e';
      });
    }
  }

  Future<void> _exportProfile() async {
    if (_student == null) return;
    try {
      final pdfBytes = await StudentExportService.generateStudentProfilePdf(
        student: _student!,
        subjects: _subjectsWithTeachers,
        attendanceRate: _attendanceRate,
        attendance: _attendance,
      );
      await Printing.sharePdf(
        bytes: pdfBytes,
        filename: 'profile_${_student!.id}.pdf',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('فشل التصدير: $e')));
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: LoadingIndicator()));
    }

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text(_error!),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadData,
                child: const Text('إعادة المحاولة'),
              ),
            ],
          ),
        ),
      );
    }

    if (_student == null) {
      return const Scaffold(body: Center(child: Text('الطالب غير موجود')));
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('تفاصيل الطالب'),
        actions: [
          // Smart Invoice Button
          IconButton(
            icon: const Icon(Icons.account_balance_wallet_outlined),
            tooltip: 'الفاتورة الذكية',
            onPressed: () {
              context.pushNamed(
                'smartInvoice',
                pathParameters: {'studentId': widget.studentId},
                extra: {'studentName': _student?.name},
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.print_rounded),
            tooltip: 'تصدير الملف',
            onPressed: _exportProfile,
          ),
          IconButton(
            icon: const Icon(Icons.receipt_long_outlined),
            onPressed: () {
              context.pushNamed(
                'studentAccountStatement',
                pathParameters: {'id': widget.studentId},
                extra: {'name': _student?.name ?? 'الطالب'},
              );
            },
            tooltip: 'كشف حساب',
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: () {
              context.pushNamed('addStudent', extra: _student);
            },
            tooltip: 'تعديل',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(AppSpacing.pagePadding.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            _buildHeader(context, isDark),

            const SizedBox(height: AppSpacing.xxl),

            // Main Content
            Container(
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                borderRadius: BorderRadius.circular(AppSpacing.radiusLg.r),
                border: Border.all(
                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                ),
              ),
              child: Column(
                children: [
                  // Tabs
                  TabBar(
                    controller: _tabController,
                    isScrollable: true,
                    tabs: const [
                      Tab(text: 'المعلومات'),
                      Tab(text: 'المواد'),
                      Tab(text: 'الحضور'),
                      Tab(text: 'الدرجات'),
                      Tab(text: 'المدفوعات'),
                    ],
                  ),

                  // Tab Content
                  SizedBox(
                    height: 500.h, // Fixed height for tab view content
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        _InfoTab(
                          student: _student!,
                          attendanceRate: _attendanceRate,
                          isDark: isDark,
                        ),
                        _SubjectsTab(
                          subjectsWithTeachers: _subjectsWithTeachers,
                          isDark: isDark,
                          studentId: widget.studentId,
                          onSubjectsUpdated: _loadData,
                        ),
                        _AttendanceTab(attendance: _attendance, isDark: isDark),
                        _GradesTab(isDark: isDark),
                        _PaymentsTab(payments: _payments, isDark: isDark),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, bool isDark) {
    return Row(
      children: [
        CircleAvatar(
          radius: 32.r,
          backgroundImage: _student!.imageUrl != null
              ? NetworkImage(_student!.imageUrl!)
              : null,
          backgroundColor: AppColors.primary,
          child: _student!.imageUrl == null
              ? Text(
                  _student!.name.isNotEmpty ? _student!.name[0] : '?',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 24.sp,
                  ),
                )
              : null,
        ),

        const SizedBox(width: AppSpacing.lg),

        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _student!.name,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                _student!.stage,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: isDark
                      ? AppColors.darkTextSecondary
                      : AppColors.lightTextSecondary,
                ),
              ),
            ],
          ),
        ),

        Container(
          padding: EdgeInsets.symmetric(
            horizontal: AppSpacing.md.w,
            vertical: AppSpacing.sm.h,
          ),
          decoration: BoxDecoration(
            color: _student!.status == StudentStatus.active
                ? AppColors.successSurface
                : Colors.grey.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(AppSpacing.radiusFull.r),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8.w,
                height: 8.w,
                decoration: BoxDecoration(
                  color: _student!.status == StudentStatus.active
                      ? AppColors.success
                      : Colors.grey,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                _student!.status.name,
                style: TextStyle(
                  color: _student!.status == StudentStatus.active
                      ? AppColors.success
                      : Colors.grey,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _InfoTab extends StatelessWidget {
  final Student student;
  final double attendanceRate;
  final bool isDark;

  const _InfoTab({
    required this.student,
    required this.attendanceRate,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    // جلب إعدادات نظام الدفع
    final centerProvider = context.watch<CenterProvider>();
    final billingConfig = centerProvider.billingConfig;

    return SingleChildScrollView(
      padding: EdgeInsets.all(AppSpacing.lg.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // بطاقة حالة الدفع - العنصر الجديد
          _BillingStatusCard(billingConfig: billingConfig),
          const SizedBox(height: AppSpacing.xl),

          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Student Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'معلومات الطالب',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    _InfoRow(
                      icon: Icons.phone,
                      label: 'الهاتف',
                      value: student.phone,
                      isLtr: true,
                      onTap: () {
                        Clipboard.setData(ClipboardData(text: student.phone));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('تم نسخ رقم الهاتف')),
                        );
                      },
                      showCopyIcon: true,
                    ),
                    if (student.email != null)
                      _InfoRow(
                        icon: Icons.email,
                        label: 'البريد',
                        value: student.email!,
                        isLtr: true,
                      ),
                    _InfoRow(
                      icon: Icons.cake,
                      label: 'تاريخ الميلاد',
                      value: student.birthDate.toString().split(' ')[0],
                      isLtr: true,
                    ),
                    if (student.address.isNotEmpty)
                      _InfoRow(
                        icon: Icons.location_on,
                        label: 'العنوان',
                        value: student.address,
                      ),
                  ],
                ),
              ),

              const SizedBox(width: AppSpacing.xxl),

              // Stats
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'إحصائيات سريعة',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    _StatBox(
                      label: 'معدل الحضور',
                      value: '${attendanceRate.toStringAsFixed(1)}%',
                      color: attendanceRate >= 75
                          ? AppColors.success
                          : attendanceRate >= 50
                          ? AppColors.warning
                          : AppColors.error,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// بطاقة عرض حالة الدفع
class _BillingStatusCard extends StatelessWidget {
  final BillingConfig billingConfig;

  const _BillingStatusCard({required this.billingConfig});

  @override
  Widget build(BuildContext context) {
    final isPerSession = billingConfig.isPerSession;
    final isMonthly = billingConfig.isMonthly;

    IconData icon;
    Color color;
    String title;
    String subtitle;

    if (isPerSession) {
      icon = Icons.confirmation_number;
      color = Colors.orange;
      title = 'نظام الحصص';
      subtitle = 'رصيد الحصص: -- | مهلة: ${billingConfig.graceSessions} حصص';
    } else if (isMonthly) {
      icon = Icons.calendar_month;
      color = Colors.deepPurple;
      title = 'نظام شهري';
      subtitle = billingConfig.monthlyModeArabic;
    } else {
      icon = Icons.payment;
      color = Colors.grey;
      title = 'نظام مختلط';
      subtitle = 'حسب إعدادات المجموعة';
    }

    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withValues(alpha: 0.1), color.withValues(alpha: 0.05)],
        ),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(12.w),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 28.sp),
          ),
          SizedBox(width: 16.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16.sp,
                    color: color,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 13.sp, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          // زر شراء حصص إذا كان النظام بالحصة
          if (isPerSession)
            FilledButton.icon(
              onPressed: () {
                // TODO: الانتقال لشراء حصص
              },

              icon: Icon(Icons.add, size: 18.sp),
              label: const Text('شراء حصص'),
              style: FilledButton.styleFrom(backgroundColor: color),
            ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool isLtr;
  final VoidCallback? onTap;
  final bool showCopyIcon;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.isLtr = false,
    this.onTap,
    this.showCopyIcon = false,
  });

  @override
  Widget build(BuildContext context) {
    Widget content = Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        children: [
          Icon(icon, size: 18.sp, color: AppColors.lightTextTertiary),
          SizedBox(width: AppSpacing.sm.w),
          Text(
            '$label: ',
            style: const TextStyle(color: AppColors.lightTextSecondary),
          ),
          Expanded(
            child: Directionality(
              textDirection: isLtr ? TextDirection.ltr : TextDirection.rtl,
              child: Text(
                value,
                style: const TextStyle(fontWeight: FontWeight.w500),
                textAlign: isLtr ? TextAlign.end : TextAlign.start,
              ),
            ),
          ),
          if (showCopyIcon) ...[
            const SizedBox(width: AppSpacing.sm),
            const Icon(Icons.copy, size: 14, color: AppColors.primary),
          ],
        ],
      ),
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        child: content,
      );
    }
    return content;
  }
}

class _StatBox extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatBox({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(AppSpacing.lg.w),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd.r),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 18.sp,
            ),
          ),
        ],
      ),
    );
  }
}

class _SubjectsTab extends StatefulWidget {
  final List<Map<String, dynamic>> subjectsWithTeachers;
  final bool isDark;
  final String studentId;
  final VoidCallback onSubjectsUpdated;

  const _SubjectsTab({
    required this.subjectsWithTeachers,
    required this.isDark,
    required this.studentId,
    required this.onSubjectsUpdated,
  });

  @override
  State<_SubjectsTab> createState() => _SubjectsTabState();
}

class _SubjectsTabState extends State<_SubjectsTab> {
  bool _isUpdating = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Header with Manage Button
        Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'المواد المسجلة (${widget.subjectsWithTeachers.length})',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
              ElevatedButton.icon(
                onPressed: _isUpdating
                    ? null
                    : () => _showManageSubjectsDialog(context),
                icon: Icon(Icons.edit, size: 18.sp),
                label: const Text('إدارة المواد'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),

        // Subjects List
        Expanded(
          child: widget.subjectsWithTeachers.isEmpty
              ? const Center(child: Text('لا توجد مواد مسجلة'))
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                  ),
                  itemCount: widget.subjectsWithTeachers.length,
                  itemBuilder: (context, index) {
                    final data = widget.subjectsWithTeachers[index];
                    // البيانات تأتي من API كـ 'courses' وليس 'subject'
                    final courseData = data['courses'] as Map<String, dynamic>?;

                    if (courseData == null) return const SizedBox.shrink();

                    final courseName =
                        courseData['name'] as String? ?? 'غير محدد';
                    final courseFee =
                        (courseData['fee'] as num?)?.toDouble() ?? 0;

                    return _SubjectRow(
                      name: courseName,
                      teacher:
                          'غير محدد', // المعلم غير متاح في البيانات الحالية
                      sessions: '--',
                      fee: courseFee > 0
                          ? '${courseFee.toStringAsFixed(0)} ج'
                          : 'حسب جدول الأسعار',
                      status: data['status'] == 'active' ? 'نشط' : 'غير نشط',
                    );
                  },
                ),
        ),
      ],
    );
  }

  Future<void> _showManageSubjectsDialog(BuildContext context) async {
    final subjectsRepo = context.read<SubjectsRepository>();

    // Fetch all subjects for the center
    final allSubjects = await subjectsRepo.getSubjects();

    // Get currently enrolled subject IDs - البيانات تأتي كـ 'courses'
    final enrolledIds = widget.subjectsWithTeachers
        .map(
          (data) =>
              (data['courses'] as Map<String, dynamic>?)?['id'] as String?,
        )
        .whereType<String>()
        .toSet();

    // Create a mutable copy for the dialog state
    final selectedIds = Set<String>.from(enrolledIds);

    if (!mounted) return;

    final result = await showDialog<Set<String>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('إدارة المواد'),
          content: SizedBox(
            width: 400,
            height: 400,
            child: ListView.builder(
              itemCount: allSubjects.length,
              itemBuilder: (context, index) {
                final subject = allSubjects[index];
                final isSelected = selectedIds.contains(subject.id);

                return CheckboxListTile(
                  title: Text(subject.name),
                  subtitle: const Text(
                    'حسب جدول الأسعار',
                  ), // التسعير من course_prices
                  value: isSelected,
                  onChanged: (value) {
                    setDialogState(() {
                      if (value == true) {
                        selectedIds.add(subject.id);
                      } else {
                        selectedIds.remove(subject.id);
                      }
                    });
                  },
                  activeColor: AppColors.primary,
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, selectedIds),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
              child: const Text('حفظ'),
            ),
          ],
        ),
      ),
    );

    if (result != null && !setEquals(result, enrolledIds)) {
      setState(() => _isUpdating = true);
      try {
        await context.read<StudentsRepository>().updateStudentSubjects(
          widget.studentId,
          result.toList(),
        );
        widget.onSubjectsUpdated(); // Trigger data reload
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('تم تحديث المواد بنجاح'),
              backgroundColor: AppColors.success,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('فشل تحديث المواد: $e'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      } finally {
        if (mounted) setState(() => _isUpdating = false);
      }
    }
  }
}

class _SubjectRow extends StatelessWidget {
  final String name;
  final String teacher;
  final String sessions;
  final String fee;
  final String status;

  const _SubjectRow({
    required this.name,
    required this.teacher,
    required this.sessions,
    required this.fee,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.lightBorder),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.primarySurface,
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            ),
            child: const Icon(Icons.menu_book, color: AppColors.primary),
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
                Text(
                  teacher,
                  style: const TextStyle(
                    color: AppColors.lightTextSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Text(sessions),
          const SizedBox(width: AppSpacing.xxl),
          Text(fee, style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(width: AppSpacing.xxl),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.xs,
            ),
            decoration: BoxDecoration(
              color: AppColors.successSurface,
              borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
            ),
            child: Text(
              status,
              style: const TextStyle(color: AppColors.success, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

class _AttendanceTab extends StatelessWidget {
  final List<AttendanceRecord> attendance;
  final bool isDark;

  const _AttendanceTab({required this.attendance, required this.isDark});

  @override
  Widget build(BuildContext context) {
    if (attendance.isEmpty) {
      return const Center(child: Text('لا توجد سجلات حضور'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(AppSpacing.lg),
      itemCount: attendance.length,
      itemBuilder: (context, index) {
        final record = attendance[index];
        return ListTile(
          leading: Icon(
            record.status == AttendanceStatus.present
                ? Icons.check_circle
                : Icons.cancel,
            color: record.status == AttendanceStatus.present
                ? Colors.green
                : Colors.red,
          ),
          title: Text(record.date.toString().split(' ')[0]),
          subtitle: Text(record.notes ?? ''),
          trailing: Text(record.status.name),
        );
      },
    );
  }
}

class _GradesTab extends StatelessWidget {
  final bool isDark;

  const _GradesTab({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('الدرجات والتقييمات (قريبا)'));
  }
}

class _PaymentsTab extends StatelessWidget {
  final List<Payment> payments;
  final bool isDark;

  const _PaymentsTab({required this.payments, required this.isDark});

  @override
  Widget build(BuildContext context) {
    if (payments.isEmpty) {
      return const Center(child: Text('لا توجد سجلات مدفوعات'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(AppSpacing.lg),
      itemCount: payments.length,
      itemBuilder: (context, index) {
        final payment = payments[index];
        return Container(
          margin: const EdgeInsets.only(bottom: AppSpacing.md),
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.lightBorder),
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: _getStatusColor(payment.status).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                ),
                child: Icon(
                  _getStatusIcon(payment.status),
                  color: _getStatusColor(payment.status),
                ),
              ),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      payment.month,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    Text(
                      'استحقاق: ${payment.dueDate.toString().split(' ')[0]}',
                      style: const TextStyle(
                        color: AppColors.lightTextSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${payment.amount.toStringAsFixed(0)} ج',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                  if (payment.paidAmount > 0)
                    Text(
                      'مدفوع: ${payment.paidAmount.toStringAsFixed(0)} ج',
                      style: const TextStyle(
                        color: AppColors.success,
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
              const SizedBox(width: AppSpacing.lg),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.xs,
                ),
                decoration: BoxDecoration(
                  color: _getStatusColor(payment.status).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                ),
                child: Text(
                  _getStatusText(payment.status),
                  style: TextStyle(
                    color: _getStatusColor(payment.status),
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Color _getStatusColor(PaymentStatus status) {
    switch (status) {
      case PaymentStatus.paid:
        return AppColors.success;
      case PaymentStatus.partial:
        return AppColors.warning;
      case PaymentStatus.pending:
        return AppColors.info;
      case PaymentStatus.overdue:
        return AppColors.error;
    }
  }

  IconData _getStatusIcon(PaymentStatus status) {
    switch (status) {
      case PaymentStatus.paid:
        return Icons.check_circle;
      case PaymentStatus.partial:
        return Icons.timelapse;
      case PaymentStatus.pending:
        return Icons.schedule;
      case PaymentStatus.overdue:
        return Icons.warning;
    }
  }

  String _getStatusText(PaymentStatus status) {
    switch (status) {
      case PaymentStatus.paid:
        return 'مدفوع';
      case PaymentStatus.partial:
        return 'جزئي';
      case PaymentStatus.pending:
        return 'منتظر';
      case PaymentStatus.overdue:
        return 'متأخر';
    }
  }
}
