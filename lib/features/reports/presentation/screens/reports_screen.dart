import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/l10n/app_strings.dart';
import '../../../../core/providers/center_provider.dart';
import '../../../../shared/widgets/buttons/app_button.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/routing/route_names.dart';
import '../../bloc/reports_bloc.dart';
import '../../../attendance/data/repositories/attendance_repository.dart';
import '../../../groups/data/repositories/groups_repository.dart';
import '../../../payments/data/repositories/payment_repository.dart';
import '../../../rooms/data/repositories/rooms_repository.dart';
import '../../../students/data/repositories/students_repository.dart';
import '../../../subjects/data/repositories/subjects_repository.dart';
import '../../../teachers/data/repositories/teachers_repository.dart';

/// شاشة التقارير المحسّنة
class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});

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
      create: (context) => ReportsBloc(
        studentsRepo: context.read<StudentsRepository>(),
        teachersRepo: context.read<TeachersRepository>(),
        subjectsRepo: context.read<SubjectsRepository>(),
        paymentsRepo: context.read<PaymentRepository>(),
        attendanceRepo: context.read<AttendanceRepository>(),
        groupsRepo: context.read<GroupsRepository>(),
        roomsRepo: context.read<RoomsRepository>(),
        centerId: centerProvider.centerId!,
      )..add(LoadReportData()),
      child: const _ReportsView(),
    );
  }
}

class _ReportsView extends StatefulWidget {
  const _ReportsView();

  @override
  State<_ReportsView> createState() => _ReportsViewState();
}

enum PresetPeriod { today, thisWeek, thisMonth, lastMonth, custom }

class _ReportsViewState extends State<_ReportsView> {
  String? _selectedReportType;
  DateTimeRange? _dateRange;
  PresetPeriod _selectedPeriod = PresetPeriod.today;

  // Report colors
  final Map<String, Color> _reportColors = {
    'general': const Color(0xFF2196F3), // Blue
    'students': const Color(0xFF4CAF50), // Green
    'payments': const Color(0xFFFFB300), // Golden
    'attendance': const Color(0xFF9C27B0), // Purple
    'teachers': const Color(0xFFFF9800), // Orange
    'subjects': const Color(0xFFF44336), // Red
  };

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final padding = EdgeInsets.all(AppSpacing.pagePadding.w);
    final strings = AppStrings.of(context);

    final List<Map<String, dynamic>> reports = [
      {
        'id': 'general',
        'title': strings.generalReport,
        'icon': Icons.assessment,
        'description': strings.generalReportDesc,
      },
      {
        'id': 'students',
        'title': strings.studentsReport,
        'icon': Icons.school,
        'description': strings.studentsReportDesc,
      },
      {
        'id': 'payments',
        'title': strings.financialReport,
        'icon': Icons.payments,
        'description': strings.financialReportDesc,
      },
      {
        'id': 'attendance',
        'title': strings.attendanceReport,
        'icon': Icons.how_to_reg,
        'description': strings.attendanceReportDesc,
      },
      {
        'id': 'teachers',
        'title': strings.teachersReport,
        'icon': Icons.person,
        'description': strings.teachersReportDesc,
      },
      {
        'id': 'subjects',
        'title': strings.subjectsReport,
        'icon': Icons.menu_book,
        'description': strings.subjectsReportDesc,
      },
    ];

    return BlocConsumer<ReportsBloc, ReportsState>(
      listener: (context, state) {
        if (state.status == ReportsStatus.success &&
            state.currentReport != null) {
          final report = state.currentReport!;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.white, size: 24.sp),
                  SizedBox(width: AppSpacing.sm.w),
                  Expanded(
                    child: Text('${strings.reportGenerated}: ${report.title}'),
                  ),
                ],
              ),
              backgroundColor: AppColors.success,
              action: SnackBarAction(
                label: strings.download,
                textColor: Colors.white,
                onPressed: () => _downloadReport(context, report, strings),
              ),
            ),
          );
        } else if (state.status == ReportsStatus.failure) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${strings.error}: ${state.errorMessage}'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      },
      builder: (context, state) {
        return RefreshIndicator(
          onRefresh: () async {
            context.read<ReportsBloc>().add(LoadReportData());
          },
          child: SingleChildScrollView(
            padding: padding,
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header with stats
                _buildHeader(context, isDark, strings, state),

                SizedBox(height: AppSpacing.xl.h),

                // 🚀 NEW: Analytics Dashboard Button
                _buildAnalyticsButton(context, isDark),

                SizedBox(height: AppSpacing.xl.h),

                // ⚡ NEW: Quick Actions
                _buildQuickActions(context, isDark, strings, state),

                SizedBox(height: AppSpacing.xl.h),

                // 🎯 Section Title
                Text(
                  'اختر نوع التقرير',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: 22.sp,
                  ),
                ),
                SizedBox(height: AppSpacing.md.h),

                // Reports Grid with Enhanced Cards
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 280.w,
                    crossAxisSpacing: AppSpacing.lg.w,
                    mainAxisSpacing: AppSpacing.lg.h,
                    childAspectRatio: 1.3,
                  ),
                  itemCount: reports.length,
                  itemBuilder: (context, index) {
                    final report = reports[index];
                    final isSelected = _selectedReportType == report['id'];
                    return _EnhancedReportCard(
                      title: report['title'],
                      description: report['description'],
                      icon: report['icon'],
                      isSelected: isSelected,
                      isDark: isDark,
                      color: _reportColors[report['id']]!,
                      lastValue: _getLastValue(state, report['id']),
                      onTap: () {
                        if (report['id'] == 'students') {
                          context.go(RouteNames.studentsReport);
                          return;
                        }
                        setState(() {
                          _selectedReportType = report['id'];
                          // Auto-set period to today when selecting
                          _selectedPeriod = PresetPeriod.today;
                          _updateDateRangeFromPreset(_selectedPeriod);
                        });
                      },
                    );
                  },
                ),

                // NEW: Preset Periods (only show when report type selected)
                if (_selectedReportType != null) ...[
                  SizedBox(height: AppSpacing.xxl.h),
                  _buildPresetPeriods(context, isDark, strings),
                ],

                // Generate Button
                if (_selectedReportType != null && _dateRange != null) ...[
                  SizedBox(height: AppSpacing.xl.h),
                  Center(
                    child: AppButton(
                      text: state.status == ReportsStatus.generating
                          ? strings.loading
                          : strings.generateReport,
                      icon: Icons.play_arrow,
                      isLoading: state.status == ReportsStatus.generating,
                      onPressed: state.status == ReportsStatus.generating
                          ? null
                          : () => _generateReport(context),
                    ),
                  ),
                ],

                // Report Preview
                if (state.currentReport != null) ...[
                  SizedBox(height: AppSpacing.xxl.h),
                  _buildReportPreview(
                    context,
                    isDark,
                    strings,
                    state.currentReport!,
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(
    BuildContext context,
    bool isDark,
    AppStrings strings,
    ReportsState state,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              strings.reportsAndStatistics,
              style: Theme.of(
                context,
              ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              '${state.totalStudents} ${strings.students} • ${state.totalTeachers} ${strings.teachers} • ${state.totalSubjects} ${strings.subjects}',
              style: TextStyle(
                color: isDark
                    ? AppColors.darkTextSecondary
                    : AppColors.lightTextSecondary,
              ),
            ),
          ],
        ),
      ],
    );
  }

  // 🚀 NEW: Analytics Dashboard Button
  Widget _buildAnalyticsButton(BuildContext context, bool isDark) {
    return GestureDetector(
      onTap: () => context.go(RouteNames.financialInsights),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.xl),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF1A2980), Color(0xFF26D0CE)], // Genius Blue/Teal
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF1A2980).withValues(alpha: 0.4),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.auto_graph_rounded,
                color: Colors.white,
                size: 32,
              ),
            ),
            const SizedBox(width: AppSpacing.lg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '🧠 لوحة الذكاء المالي',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'تحليل الإيرادات، كفاءة التحصيل، ودوري المعلمين',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.arrow_forward_ios,
                color: Colors.white,
                size: 20,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ⚡ NEW: Quick Actions
  Widget _buildQuickActions(
    BuildContext context,
    bool isDark,
    AppStrings strings,
    ReportsState state,
  ) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withValues(alpha: 0.1),
            AppColors.primary.withValues(alpha: 0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.bolt, color: AppColors.primary, size: 24),
              const SizedBox(width: AppSpacing.sm),
              Text(
                'تقارير سريعة',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.md,
            runSpacing: AppSpacing.md,
            children: [
              _QuickActionButton(
                label: 'تقرير اليوم',
                icon: Icons.today,
                color: AppColors.info,
                onPressed: () =>
                    _quickGenerate(context, PresetPeriod.today, 'general'),
              ),
              _QuickActionButton(
                label: 'تقرير الأسبوع',
                icon: Icons.date_range,
                color: AppColors.success,
                onPressed: () =>
                    _quickGenerate(context, PresetPeriod.thisWeek, 'general'),
              ),
              _QuickActionButton(
                label: 'تقرير الشهر',
                icon: Icons.calendar_month,
                color: AppColors.warning,
                onPressed: () =>
                    _quickGenerate(context, PresetPeriod.thisMonth, 'general'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // NEW: Preset Periods
  Widget _buildPresetPeriods(
    BuildContext context,
    bool isDark,
    AppStrings strings,
  ) {
    return Container(
      padding: EdgeInsets.all(AppSpacing.lg.w),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg.r),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.date_range, color: AppColors.primary, size: 24.sp),
              SizedBox(width: AppSpacing.md.w),
              Text(
                'اختر الفترة الزمنية:',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16.sp),
              ),
            ],
          ),
          SizedBox(height: AppSpacing.md.h),
          Wrap(
            spacing: AppSpacing.sm.w,
            runSpacing: AppSpacing.sm.h,
            children: [
              _PeriodChip(
                label: 'اليوم',
                isSelected: _selectedPeriod == PresetPeriod.today,
                onSelected: () => _selectPresetPeriod(PresetPeriod.today),
              ),
              _PeriodChip(
                label: 'الأسبوع',
                isSelected: _selectedPeriod == PresetPeriod.thisWeek,
                onSelected: () => _selectPresetPeriod(PresetPeriod.thisWeek),
              ),
              _PeriodChip(
                label: 'الشهر الحالي',
                isSelected: _selectedPeriod == PresetPeriod.thisMonth,
                onSelected: () => _selectPresetPeriod(PresetPeriod.thisMonth),
              ),
              _PeriodChip(
                label: 'الشهر الماضي',
                isSelected: _selectedPeriod == PresetPeriod.lastMonth,
                onSelected: () => _selectPresetPeriod(PresetPeriod.lastMonth),
              ),
              _PeriodChip(
                label: 'مخصص',
                icon: Icons.calendar_today,
                isSelected: _selectedPeriod == PresetPeriod.custom,
                onSelected: () => _selectCustomPeriod(strings),
              ),
            ],
          ),
          if (_dateRange != null) ...[
            SizedBox(height: AppSpacing.md.h),
            Container(
              padding: EdgeInsets.all(AppSpacing.sm.w),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd.r),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 16.sp,
                    color: AppColors.primary,
                  ),
                  SizedBox(width: AppSpacing.xs.w),
                  Text(
                    'الفترة: ${_dateRange!.start.day}/${_dateRange!.start.month}/${_dateRange!.start.year} - ${_dateRange!.end.day}/${_dateRange!.end.month}/${_dateRange!.end.year}',
                    style: TextStyle(fontSize: 13.sp, color: AppColors.primary),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildReportPreview(
    BuildContext context,
    bool isDark,
    AppStrings strings,
    ReportData report,
  ) {
    final color = _reportColors[report.type] ?? AppColors.primary;

    return Container(
      padding: EdgeInsets.all(AppSpacing.lg.w),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg.r),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(8.w),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd.r),
                ),
                child: Icon(Icons.description, color: color, size: 24.sp),
              ),
              SizedBox(width: AppSpacing.md.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      report.title,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18.sp,
                        color: color,
                      ),
                    ),
                    Text(
                      '${report.generatedAt.hour}:${report.generatedAt.minute.toString().padLeft(2, '0')}',
                      style: TextStyle(
                        fontSize: 12.sp,
                        color: isDark
                            ? AppColors.darkTextTertiary
                            : AppColors.lightTextTertiary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: AppSpacing.md.h),
          const Divider(),
          SizedBox(height: AppSpacing.md.h),

          // Display summary based on report type
          _buildReportSummary(isDark, strings, report),
        ],
      ),
    );
  }

  Widget _buildReportSummary(
    bool isDark,
    AppStrings strings,
    ReportData report,
  ) {
    final data = report.data;

    switch (report.type) {
      case 'general':
        final summary = data['summary'] as Map<String, dynamic>? ?? {};
        return Wrap(
          spacing: AppSpacing.xl.w,
          runSpacing: AppSpacing.md.h,
          children: [
            _InfoChip(
              label: strings.students,
              value: '${summary['totalStudents'] ?? 0}',
              isDark: isDark,
            ),
            _InfoChip(
              label: strings.teachers,
              value: '${summary['totalTeachers'] ?? 0}',
              isDark: isDark,
            ),
            _InfoChip(
              label: strings.subjects,
              value: '${summary['totalSubjects'] ?? 0}',
              isDark: isDark,
            ),
            _InfoChip(
              label: strings.attendanceRate,
              value:
                  '${(summary['attendanceRate'] as num?)?.toStringAsFixed(1) ?? 0}%',
              isDark: isDark,
            ),
          ],
        );
      case 'attendance':
        return Wrap(
          spacing: AppSpacing.xl.w,
          runSpacing: AppSpacing.md.h,
          children: [
            _InfoChip(
              label: strings.present,
              value: '${data['present'] ?? 0}',
              isDark: isDark,
              color: AppColors.success,
            ),
            _InfoChip(
              label: strings.absent,
              value: '${data['absent'] ?? 0}',
              isDark: isDark,
              color: AppColors.error,
            ),
            _InfoChip(
              label: strings.late,
              value: '${data['late'] ?? 0}',
              isDark: isDark,
              color: AppColors.warning,
            ),
            _InfoChip(
              label: strings.attendanceRate,
              value: '${(data['rate'] as num?)?.toStringAsFixed(1) ?? 0}%',
              isDark: isDark,
            ),
          ],
        );
      case 'payments':
        return Wrap(
          spacing: AppSpacing.xl.w,
          runSpacing: AppSpacing.md.h,
          children: [
            _InfoChip(
              label: 'عدد المدفوعات',
              value: '${data['totalPayments'] ?? 0}',
              isDark: isDark,
            ),
            _InfoChip(
              label: 'إجمالي المبالغ',
              value:
                  '${(data['totalAmount'] as num?)?.toStringAsFixed(0) ?? 0} EGP',
              isDark: isDark,
              color: AppColors.success,
            ),
          ],
        );
      default:
        return Text('${data['total'] ?? 0} ${strings.noData}');
    }
  }

  // Helper methods
  void _selectPresetPeriod(PresetPeriod period) {
    setState(() {
      _selectedPeriod = period;
      _updateDateRangeFromPreset(period);
    });
  }

  void _updateDateRangeFromPreset(PresetPeriod period) {
    final now = DateTime.now();
    switch (period) {
      case PresetPeriod.today:
        _dateRange = DateTimeRange(
          start: DateTime(now.year, now.month, now.day),
          end: DateTime(now.year, now.month, now.day, 23, 59, 59),
        );
        break;
      case PresetPeriod.thisWeek:
        final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
        _dateRange = DateTimeRange(
          start: DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day),
          end: DateTime(now.year, now.month, now.day, 23, 59, 59),
        );
        break;
      case PresetPeriod.thisMonth:
        _dateRange = DateTimeRange(
          start: DateTime(now.year, now.month, 1),
          end: DateTime(now.year, now.month, now.day, 23, 59, 59),
        );
        break;
      case PresetPeriod.lastMonth:
        final lastMonth = DateTime(now.year, now.month - 1);
        final lastDayOfLastMonth = DateTime(now.year, now.month, 0);
        _dateRange = DateTimeRange(
          start: DateTime(lastMonth.year, lastMonth.month, 1),
          end: DateTime(
            lastDayOfLastMonth.year,
            lastDayOfLastMonth.month,
            lastDayOfLastMonth.day,
            23,
            59,
            59,
          ),
        );
        break;
      case PresetPeriod.custom:
        // Will be set by date picker
        break;
    }
  }

  Future<void> _selectCustomPeriod(AppStrings strings) async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _dateRange,
      locale: strings.locale,
    );
    if (range != null) {
      if (!mounted) return;
      setState(() {
        _selectedPeriod = PresetPeriod.custom;
        _dateRange = range;
      });
    }
  }

  void _quickGenerate(
    BuildContext context,
    PresetPeriod period,
    String reportType,
  ) {
    setState(() {
      _selectedReportType = reportType;
      _selectedPeriod = period;
      _updateDateRangeFromPreset(period);
    });

    // Auto-generate after a short delay for UX
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        _generateReport(context);
      }
    });
  }

  void _generateReport(BuildContext context) {
    if (_selectedReportType != null && _dateRange != null) {
      context.read<ReportsBloc>().add(
        GenerateReport(
          reportType: _selectedReportType!,
          startDate: _dateRange!.start,
          endDate: _dateRange!.end,
        ),
      );
    }
  }

  void _downloadReport(
    BuildContext context,
    ReportData report,
    AppStrings strings,
  ) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(strings.downloadingReport)));
    // TODO: Implement actual file download (PDF/Excel)
  }

  String? _getLastValue(ReportsState state, String reportId) {
    // Return last known value for the report type
    switch (reportId) {
      case 'students':
        return state.totalStudents > 0 ? '${state.totalStudents}' : null;
      case 'teachers':
        return state.totalTeachers > 0 ? '${state.totalTeachers}' : null;
      case 'subjects':
        return state.totalSubjects > 0 ? '${state.totalSubjects}' : null;
      case 'payments':
        return state.totalRevenue > 0
            ? '${state.totalRevenue.toStringAsFixed(0)} EGP'
            : null;
      default:
        return null;
    }
  }
}

// ══════════════════════════════════════════════════════════════════
// NEW WIDGETS
// ══════════════════════════════════════════════════════════════════

class _QuickActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onPressed;

  const _QuickActionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 20),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: EdgeInsets.symmetric(
          horizontal: AppSpacing.lg.w,
          vertical: AppSpacing.md.h,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd.r),
        ),
      ),
    );
  }
}

class _PeriodChip extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool isSelected;
  final VoidCallback onSelected;

  const _PeriodChip({
    required this.label,
    this.icon,
    required this.isSelected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 16.sp), SizedBox(width: 4.w)],
          Text(label),
        ],
      ),
      selected: isSelected,
      onSelected: (_) => onSelected(),
      selectedColor: AppColors.primary,
      checkmarkColor: Colors.white,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : null,
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
      ),
    );
  }
}

class _EnhancedReportCard extends StatefulWidget {
  final String title;
  final String description;
  final IconData icon;
  final bool isSelected;
  final bool isDark;
  final Color color;
  final String? lastValue;
  final VoidCallback onTap;

  const _EnhancedReportCard({
    required this.title,
    required this.description,
    required this.icon,
    required this.isSelected,
    required this.isDark,
    required this.color,
    this.lastValue,
    required this.onTap,
  });

  @override
  State<_EnhancedReportCard> createState() => _EnhancedReportCardState();
}

class _EnhancedReportCardState extends State<_EnhancedReportCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          decoration: BoxDecoration(
            color: widget.isSelected
                ? widget.color.withValues(alpha: 0.1)
                : (widget.isDark
                      ? AppColors.darkSurface
                      : AppColors.lightSurface),
            borderRadius: BorderRadius.circular(AppSpacing.radiusLg.r),
            border: Border.all(
              color: widget.isSelected
                  ? widget.color
                  : (_isHovered
                        ? widget.color.withValues(alpha: 0.5)
                        : (widget.isDark
                              ? AppColors.darkBorder
                              : AppColors.lightBorder)),
              width: widget.isSelected ? 2.w : 1.w,
            ),
            boxShadow: _isHovered || widget.isSelected
                ? [
                    BoxShadow(
                      color: widget.color.withValues(alpha: 0.2),
                      blurRadius: 12.r,
                      offset: Offset(0, 4.h),
                    ),
                  ]
                : null,
          ),
          child: Padding(
            padding: EdgeInsets.all(AppSpacing.lg.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(10.w),
                      decoration: BoxDecoration(
                        color: widget.isSelected
                            ? widget.color
                            : widget.color.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(
                          AppSpacing.radiusMd.r,
                        ),
                      ),
                      child: Icon(
                        widget.icon,
                        color: widget.isSelected ? Colors.white : widget.color,
                        size: 24.sp,
                      ),
                    ),
                    const Spacer(),
                    if (widget.isSelected)
                      Icon(
                        Icons.check_circle,
                        color: widget.color,
                        size: 20.sp,
                      ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15.sp,
                        color: widget.isSelected ? widget.color : null,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.description,
                      style: TextStyle(
                        fontSize: 11,
                        color: widget.isDark
                            ? AppColors.darkTextSecondary
                            : AppColors.lightTextSecondary,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (widget.lastValue != null) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: widget.color.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(
                            AppSpacing.radiusSm,
                          ),
                        ),
                        child: Text(
                          widget.lastValue!,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: widget.color,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final String label;
  final String value;
  final bool isDark;
  final Color? color;

  const _InfoChip({
    required this.label,
    required this.value,
    required this.isDark,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: (color ?? AppColors.primary).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: color ?? AppColors.primary,
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: isDark
                  ? AppColors.darkTextSecondary
                  : AppColors.lightTextSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
