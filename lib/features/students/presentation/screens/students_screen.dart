import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter/services.dart'; // Added for Clipboard
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:printing/printing.dart'; // Added
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/l10n/app_strings.dart';

import '../../../../core/utils/form_utils.dart' as formUtils;
import '../../../../core/providers/center_provider.dart';

import '../../../../shared/models/models.dart';
import '../../data/repositories/students_repository.dart';
import '../../../../shared/widgets/search/filter_panel.dart';
import '../../../../shared/widgets/search/search_filter_bar.dart';
import '../../../../shared/widgets/search/sort_widget.dart';
import '../../../reports/services/report_export_service.dart';
import '../../bloc/students_bloc.dart';
import '../../../../shared/widgets/empty_state.dart'; // Added

/// شاشة إدارة الطلاب
class StudentsScreen extends StatelessWidget {
  const StudentsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final centerProvider = context.watch<CenterProvider>();

    if (!centerProvider.hasCenter) {
      return const Center(child: Text('لم يتم العثور على بيانات السنتر'));
    }

    return BlocProvider(
      create: (context) => StudentsBloc(
        context.read<StudentsRepository>(),
        centerProvider.centerId!,
        onDataChanged: () => centerProvider.refreshCounts(),
      )..add(const LoadStudents()),
      child: const _StudentsView(),
    );
  }
}

class _StudentsView extends StatelessWidget {
  const _StudentsView();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final strings = AppStrings.of(context);

    return BlocListener<StudentsBloc, StudentsState>(
      listener: (context, state) {
        if (state.status == StudentsStatus.failure) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.errorMessage ?? strings.errorOccurred),
              backgroundColor: AppColors.error,
            ),
          );
        }
      },
      child: BlocBuilder<StudentsBloc, StudentsState>(
        builder: (context, state) {
          if (state.status == StudentsStatus.loading &&
              state.students.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          return NotificationListener<ScrollNotification>(
            onNotification: (scrollInfo) {
              if (scrollInfo.metrics.pixels >=
                      scrollInfo.metrics.maxScrollExtent - 200 &&
                  !state.hasReachedMax &&
                  !state.isLoadingMore) {
                context.read<StudentsBloc>().add(LoadMoreStudents());
              }
              return false;
            },
            child: RefreshIndicator(
              onRefresh: () async {
                context.read<StudentsBloc>().add(
                  const LoadStudents(refresh: true),
                );
              },
              child: SingleChildScrollView(
                padding: EdgeInsets.all(AppSpacing.pagePadding.w),
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    _buildHeader(context, state, isDark, strings),
                    const SizedBox(height: AppSpacing.xl),

                    // Search and Filters
                    _buildSearchAndFilters(context, state, isDark, strings),
                    const SizedBox(height: AppSpacing.lg),

                    // Students Table
                    _buildStudentsTable(context, state, isDark, strings),
                    const SizedBox(height: AppSpacing.lg),

                    // Loading More Indicator
                    if (state.isLoadingMore)
                      const Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Center(child: CircularProgressIndicator()),
                      ),

                    if (state.hasReachedMax && state.students.isNotEmpty)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 24.0),
                          child: Text(
                            strings.isArabic
                                ? 'ظهرت جميع النتائج'
                                : 'All results shown',
                            style: const TextStyle(color: Colors.grey),
                          ),
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

  Widget _buildHeader(
    BuildContext context,
    StudentsState state,
    bool isDark,
    AppStrings strings,
  ) {
    return Container(
      padding: EdgeInsets.all(AppSpacing.xl.w),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF3B82F6), Color(0xFF8B5CF6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppSpacing.radiusXl.r),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                strings.studentManagement,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: AppSpacing.md.w,
                      vertical: AppSpacing.xs.h,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(
                        AppSpacing.radiusFull.r,
                      ),
                    ),
                    child: Text(
                      '${state.students.length} ${strings.students}',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 13,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: AppSpacing.md.w,
                      vertical: AppSpacing.xs.h,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.success.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(
                        AppSpacing.radiusFull.r,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.check_circle,
                          size: 14,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${state.activeCount} ${strings.active}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: AppSpacing.md.w,
                      vertical: AppSpacing.xs.h,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(
                        AppSpacing.radiusFull.r,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.warning,
                          size: 14,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${state.overdueCount} ${strings.overdue}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          Row(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd.r),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd.r),
                    onTap: () async {
                      if (state.filteredStudents.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(strings.noStudents)),
                        );
                        return;
                      }

                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(SnackBar(content: Text(strings.loading)));

                      try {
                        final pdfBytes =
                            await ReportExportService.generateStudentListPdf(
                              state.filteredStudents,
                            );
                        await Printing.sharePdf(
                          bytes: pdfBytes,
                          filename:
                              'students_list_${DateTime.now().millisecondsSinceEpoch}.pdf',
                        );
                      } catch (e) {
                        ScaffoldMessenger.of(context).hideCurrentSnackBar();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('${strings.errorOccurred}: $e'),
                          ),
                        );
                      }
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.lg,
                        vertical: AppSpacing.md,
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.download_rounded,
                            color: Colors.white,
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Text(
                            strings.export,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd.r),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                    onTap: () => context.pushNamed('addStudent'),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.lg,
                        vertical: AppSpacing.md,
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.add_rounded,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Text(
                            strings.addStudent,
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilters(
    BuildContext context,
    StudentsState state,
    bool isDark,
    AppStrings strings,
  ) {
    final filters = [
      FilterOption(
        key: 'stage',
        label: strings.stage,
        type: FilterType.dropdown,
        options: [
          FilterOptionItem(value: '', label: strings.all),
          ...formUtils.FormUtils.stages.map(
            (stage) => FilterOptionItem(value: stage, label: stage),
          ),
        ],
      ),
      FilterOption(
        key: 'status',
        label: strings.status,
        type: FilterType.dropdown,
        options: [
          FilterOptionItem(value: '', label: strings.all),
          FilterOptionItem(value: 'active', label: strings.active),
          FilterOptionItem(value: 'suspended', label: strings.suspended),
          FilterOptionItem(value: 'overdue', label: strings.overdue),
        ],
      ),
    ];

    final sortOptions = [
      SortOption(key: 'name', label: strings.studentName),
      SortOption(key: 'stage', label: strings.stage),
      SortOption(key: 'created_at', label: strings.registrationDate),
    ];

    return BlocBuilder<StudentsBloc, StudentsState>(
      builder: (context, state) {
        return SearchFilterBar(
          searchHintText: strings.searchByNameOrPhone,
          onSearch: (query) {
            context.read<StudentsBloc>().add(SearchStudents(query));
          },
          filters: filters,
          sortOptions: sortOptions,
          filterValues: {
            'status': state.statusFilter?.name ?? '',
            'stage': state.stageFilter ?? '',
          },
          onApplyFilters: (filterValues) {
            // Parse filter values
            final statusStr = filterValues['status'] as String?;
            final stage = filterValues['stage'] as String?;

            // Convert status string to enum
            StudentStatus? status;
            if (statusStr != null && statusStr.isNotEmpty) {
              switch (statusStr) {
                case 'active':
                  status = StudentStatus.active;
                  break;
                case 'suspended':
                  status = StudentStatus.suspended;
                  break;
                case 'overdue':
                  status = StudentStatus.overdue;
                  break;
              }
            }

            // Dispatch filter event to Bloc
            context.read<StudentsBloc>().add(
              FilterStudents(status: status, stage: stage),
            );
          },
          onResetFilters: () {
            context.read<StudentsBloc>().add(
              FilterStudents(status: null, stage: null),
            );
          },
          onSortChanged: (sortOption) {
            context.read<StudentsBloc>().add(
              SortStudents(sortOption.key, ascending: sortOption.ascending),
            );
          },
        );
      },
    );
  }

  Widget _buildStudentsTable(
    BuildContext context,
    StudentsState state,
    bool isDark,
    AppStrings strings,
  ) {
    if (state.filteredStudents.isEmpty) {
      return EmptyState(
        title: strings.noStudents,
        message: strings.isArabic
            ? 'ابدأ بإضافة طلاب جدد لسنترك'
            : 'Start by adding new students to your center',
        buttonText: strings.addStudent,
        onButtonPressed: () => context.pushNamed('addStudent'),
      );
    }

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusXl.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Table Header
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xl,
              vertical: AppSpacing.lg,
            ),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark
                    ? [AppColors.darkSurfaceVariant, AppColors.darkSurface]
                    : [AppColors.lightSurfaceVariant, AppColors.lightSurface],
              ),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(AppSpacing.radiusXl),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Text(
                    strings.studentName,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  flex: 2,
                  child: Text(
                    strings.stage,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                SizedBox(
                  width: 120,
                  child: Text(
                    strings.phone,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                SizedBox(
                  width: 140,
                  child: Text(
                    strings.lastAttendance,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                SizedBox(
                  width: 100,
                  child: Text(
                    strings.status,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                SizedBox(
                  width: 160,
                  child: Text(
                    strings.actions,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),

          // Table Body
          ...state.filteredStudents.map(
            (student) => _StudentRow(
              key: ValueKey(student.id),
              student: student,
              isDark: isDark,
              strings: strings,
              onView: () => context.pushNamed(
                'studentDetails',
                pathParameters: {'id': student.id},
              ),
              onEdit: () => _showEditDialog(context, student, strings),
              onDelete: () => _showDeleteDialog(context, student, strings),
            ),
          ),
        ],
      ),
    );
  }

  void _showEditDialog(
    BuildContext context,
    Student student,
    AppStrings strings,
  ) {
    final studentsBloc = context.read<StudentsBloc>();
    final nameController = TextEditingController(text: student.name);
    final phoneController = TextEditingController(text: student.phone);
    final addressController = TextEditingController(text: student.address);

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.edit, color: AppColors.primary),
            const SizedBox(width: AppSpacing.sm),
            Text('${strings.editStudent}: ${student.name}'),
          ],
        ),
        content: SizedBox(
          width: 450,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: strings.studentName,
                  prefixIcon: const Icon(Icons.person_outline),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: phoneController,
                decoration: InputDecoration(
                  labelText: strings.phone,
                  prefixIcon: const Icon(Icons.phone_outlined),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: addressController,
                decoration: InputDecoration(
                  labelText: strings.address,
                  prefixIcon: const Icon(Icons.location_on_outlined),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(strings.cancel),
          ),
          ElevatedButton(
            onPressed: () {
              final updatedStudent = student.copyWith(
                name: nameController.text,
                phone: phoneController.text,
                address: addressController.text,
              );
              studentsBloc.add(UpdateStudent(updatedStudent));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(strings.studentUpdated),
                  backgroundColor: AppColors.success,
                ),
              );
              Navigator.pop(dialogContext);
            },
            child: Text(strings.save),
          ),
        ],
      ),
    );
  }

  void _showDeleteDialog(
    BuildContext context,
    Student student,
    AppStrings strings,
  ) {
    final studentsBloc = context.read<StudentsBloc>();
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(strings.deleteStudent),
        content: Text('${strings.confirmDeleteStudent} "${student.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(strings.cancel),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () {
              studentsBloc.add(DeleteStudent(student.id));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('${strings.studentDeleted}: ${student.name}'),
                ),
              );
              Navigator.pop(dialogContext);
            },
            child: Text(strings.delete),
          ),
        ],
      ),
    );
  }
}

class _StudentRow extends StatefulWidget {
  final Student student;
  final bool isDark;
  final AppStrings strings;
  final VoidCallback onView;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _StudentRow({
    super.key,
    required this.student,
    required this.isDark,
    required this.strings,
    required this.onView,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  State<_StudentRow> createState() => _StudentRowState();
}

class _StudentRowState extends State<_StudentRow> {
  bool _isHovered = false;

  Future<void> _showInvitationCodes() async {
    // جلب أكواد الدعوة من student_enrollments
    final repo = context.read<StudentsRepository>();

    try {
      final codes = await repo.getInvitationCodes(widget.student.id);

      if (!mounted) return;

      final studentCode = codes['student_code'];
      final parentCode = codes['parent_code'];

      if (studentCode != null || parentCode != null) {
        showDialog(
          context: context,
          builder: (ctx) =>
              _buildInvitationCodesDialog(studentCode, parentCode),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('لا توجد أكواد دعوة لهذا الطالب'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('خطأ في جلب أكواد الدعوة: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildInvitationCodesDialog(String? studentCode, String? parentCode) {
    return AlertDialog(
      title: Text('أكواد الدعوة'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (studentCode != null) ...[
            Text('كود الطالب:', style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            _buildCodeItem(
              code: studentCode,
              label: 'كود الدعوة للطالب',
              icon: Icons.school,
              color: Colors.blue,
            ),
            SizedBox(height: 16),
          ],
          if (parentCode != null) ...[
            Text(
              'كود ولي الأمر:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            _buildCodeItem(
              code: parentCode,
              label: 'كود دعوة ولي الأمر',
              icon: Icons.family_restroom,
              color: Colors.green,
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('إغلاق'),
        ),
      ],
    );
  }

  Widget _buildCodeItem({
    required String code,
    required String label,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: color.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(8),
        color: color.withValues(alpha: 0.1),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              code,
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
          IconButton(
            icon: Icon(Icons.copy, size: 16, color: color),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: code));
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text('تم نسخ $label')));
            },
          ),
        ],
      ),
    );
  }

  Color _getStatusColor() {
    switch (widget.student.status) {
      case StudentStatus.active:
        return AppColors.success;
      case StudentStatus.suspended:
        return AppColors.warning;
      case StudentStatus.overdue:
        return AppColors.error;
      case StudentStatus.inactive:
        return AppColors.gray400;
    }
  }

  String _getStatusText() {
    switch (widget.student.status) {
      case StudentStatus.active:
        return widget.strings.active;
      case StudentStatus.suspended:
        return widget.strings.suspended;
      case StudentStatus.overdue:
        return widget.strings.overdue;
      case StudentStatus.inactive:
        return widget.strings.inactive;
    }
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: EdgeInsets.symmetric(
          horizontal: AppSpacing.xl.w,
          vertical: AppSpacing.lg.h,
        ),
        decoration: BoxDecoration(
          color: _isHovered
              ? (widget.isDark
                    ? AppColors.primary.withValues(alpha: 0.08)
                    : AppColors.primary.withValues(alpha: 0.04))
              : Colors.transparent,
          border: Border(
            bottom: BorderSide(
              color: widget.isDark
                  ? AppColors.darkBorder
                  : AppColors.lightBorder,
              width: 0.5,
            ),
          ),
        ),
        child: Row(
          children: [
            // Student Info
            Expanded(
              flex: 3,
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      gradient: AppColors.primaryGradient,
                      borderRadius: BorderRadius.circular(
                        AppSpacing.radiusMd.r,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        widget.student.name.length > 2
                            ? widget.student.name.substring(0, 2)
                            : widget.student.name,
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16.sp,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.student.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                        // Only show email if it exists, never show ID
                        if (widget.student.email != null &&
                            widget.student.email!.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              widget.student.email!,
                              style: TextStyle(
                                fontSize: 12,
                                color: widget.isDark
                                    ? AppColors.darkTextTertiary
                                    : AppColors.lightTextTertiary,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Stage
            Expanded(
              flex: 2,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.xs,
                ),
                decoration: BoxDecoration(
                  color: AppColors.info.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusFull.r),
                ),
                child: Text(
                  widget.student.stage,
                  style: const TextStyle(
                    color: AppColors.info,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),

            const SizedBox(width: AppSpacing.md),
            // Phone - LTR direction + Copy on tap
            SizedBox(
              width: 120,
              child: InkWell(
                onTap: () {
                  Clipboard.setData(ClipboardData(text: widget.student.phone));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        widget.strings.isArabic
                            ? 'تم نسخ الرقم'
                            : 'Phone copied',
                      ),
                      duration: const Duration(seconds: 1),
                    ),
                  );
                },
                borderRadius: BorderRadius.circular(4),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Icon(
                        Icons.copy_rounded,
                        size: 14,
                        color: widget.isDark
                            ? AppColors.darkTextTertiary
                            : AppColors.lightTextTertiary,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Directionality(
                          textDirection: TextDirection.ltr,
                          child: Text(
                            formUtils.FormUtils.formatPhone(
                              widget.student.phone,
                            ),
                            style: TextStyle(
                              color: widget.isDark
                                  ? AppColors.darkTextSecondary
                                  : AppColors.lightTextSecondary,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(width: AppSpacing.md),
            // Last Attendance
            SizedBox(
              width: 140,
              child: Text(
                widget.student.lastAttendance != null
                    ? formUtils.FormUtils.timeAgo(
                        widget.student.lastAttendance!,
                      )
                    : (widget.strings.isArabic ? 'لم يحضر' : 'No attendance'),
                style: TextStyle(
                  color: widget.isDark
                      ? AppColors.darkTextSecondary
                      : AppColors.lightTextSecondary,
                ),
              ),
            ),

            // Status
            SizedBox(
              width: 100,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.xs,
                ),
                decoration: BoxDecoration(
                  color: _getStatusColor().withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusFull.r),
                ),
                child: Text(
                  _getStatusText(),
                  style: TextStyle(
                    color: _getStatusColor(),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),

            // Actions
            SizedBox(
              width: 160,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildActionButton(
                    Icons.vpn_key,
                    AppColors.primary,
                    'أكواد الدعوة',
                    _showInvitationCodes,
                  ),
                  _buildActionButton(
                    Icons.visibility_outlined,
                    AppColors.primary,
                    widget.strings.isArabic ? 'عرض' : 'View',
                    widget.onView,
                  ),
                  _buildActionButton(
                    Icons.edit_outlined,
                    AppColors.warning,
                    widget.strings.edit,
                    widget.onEdit,
                  ),
                  _buildActionButton(
                    Icons.delete_outline,
                    AppColors.error,
                    widget.strings.delete,
                    widget.onDelete,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(
    IconData icon,
    Color color,
    String tooltip,
    VoidCallback onPressed,
  ) {
    return Container(
      width: 32,
      height: 32,
      margin: const EdgeInsets.symmetric(horizontal: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm.r),
      ),
      child: IconButton(
        icon: Icon(icon, size: 16.sp, color: color),
        tooltip: tooltip,
        onPressed: onPressed,
        padding: EdgeInsets.zero,
      ),
    );
  }
}


