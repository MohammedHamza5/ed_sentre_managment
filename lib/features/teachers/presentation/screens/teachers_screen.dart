import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter/services.dart'; // Added for Clipboard
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/l10n/app_strings.dart';
import '../../../../core/utils/form_validators.dart';
import '../../../../core/providers/center_provider.dart';
import '../../../../shared/models/models.dart';
import '../../../schedule/data/repositories/schedule_repository.dart';
import '../../data/repositories/teachers_repository.dart';
import '../../bloc/teachers_bloc.dart';
import 'teacher_salaries_screen.dart';
import 'teacher_financial_settings_screen.dart';
import 'teacher_statistics_screen.dart';

/// شاشة إدارة المعلمين
class TeachersScreen extends StatelessWidget {
  const TeachersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final centerProvider = context.watch<CenterProvider>();

    if (!centerProvider.hasCenter) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.business_center, size: 64),
            SizedBox(height: 16.h),
            Text('لم يتم العثور على بيانات السنتر'),
          ],
        ),
      );
    }

    return const _TeachersView();
  }
}

class _TeachersView extends StatelessWidget {
  const _TeachersView();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final padding = EdgeInsets.all(AppSpacing.pagePadding.w);
    final strings = AppStrings.of(context);

    return BlocListener<TeachersBloc, TeachersState>(
      listener: (context, state) {
        if (state.status == TeachersStatus.failure) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.errorMessage ?? strings.errorOccurred),
              backgroundColor: AppColors.error,
            ),
          );
        } else if (state.status == TeachersStatus.duplicateWarning) {
          // Show Duplicate Warning Dialog
          showDialog(
            context: context,
            builder: (dialogContext) => AlertDialog(
              title: Row(
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    color: Colors.orange,
                    size: 28.sp,
                  ),
                  SizedBox(width: 8.w),
                  Text(
                    strings.isArabic
                        ? 'تنبيه تشابه أسماء'
                        : 'Duplicate Warning',
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    strings.isArabic
                        ? 'يوجد معلمين بأسماء مشابهة. هل أنت متأكد من أن هذا شخص مختلف؟'
                        : 'Similar teacher names found. are you sure this is a different person?',
                  ),
                  SizedBox(height: 12.h),
                  ...state.similarTeachers.map(
                    (t) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      leading: const Icon(Icons.person, color: Colors.grey),
                      title: Text(t['name'] ?? ''),
                      subtitle: Text(t['phone'] ?? ''),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () =>
                      Navigator.pop(dialogContext), // Close warning
                  child: Text(strings.cancel),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                  ),
                  onPressed: () {
                    Navigator.pop(dialogContext); // Close warning

                    if (state.pendingTeacher != null) {
                      context.read<TeachersBloc>().add(
                        AddTeacher(state.pendingTeacher!, force: true),
                      );

                      // Also close the original Add Dialog if it's still open?
                      // The previous AddTeacher closed it. But here we are in a new dialog.
                      // We need to ensure the original dialog is closed OR we treat this as the final step.
                      // If we trigger AddTeacher(force: true), the Bloc will emit Loading -> Success.
                      // We can listen for Success to close everything?
                      // The original dialog is technically still open under this alert?
                      // No, showDialog pushes a new route.
                      // If we pop this alert, we are back to the Add Dialog (or the screen if Add Dialog was popped).
                      // In the original code: Navigator.pop(dialogContext); was called BEFORE adding.
                      // Wait, let's check original code.
                    }
                  },
                  child: Text(
                    strings.isArabic ? 'تأكيد الإضافة' : 'Confirm Add',
                  ),
                ),
              ],
            ),
          );
        } else if (state.status == TeachersStatus.success) {
          // عرض ديالوج الكود فقط عند إضافة معلم (الديالوج يُغلق نفسه عبر BlocListener الداخلي)
          if (state.lastAction == 'add') {
            debugPrint('[TEACHER_UI] تم استلام حالة النجاح من BLoC');
            debugPrint(
              '[TEACHER_UI] addTeacherResult: ${state.addTeacherResult}',
            );

            // Show invitation code dialog if available
            if (state.addTeacherResult != null) {
              final teacherCode =
                  state.addTeacherResult!['teacher_code'] as String?;
              final phone = state.addTeacherResult!['phone'] as String?;

              debugPrint('[TEACHER_UI] كود الدعوة المستلم: $teacherCode');

              if (teacherCode != null) {
                // استخدام اسم المعلم من النتيجة مباشرة
                final teacherName =
                    state.addTeacherResult!['teacher_name'] as String? ??
                    'المعلم';

                debugPrint(
                  '[TEACHER_UI] جاري عرض ديالوج كود الدعوة للمعلم: $teacherName',
                );

                Future.delayed(const Duration(milliseconds: 300), () {
                  showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder: (dialogCtx) => _InvitationCodeDialog(
                      teacherName: teacherName,
                      teacherCode: teacherCode,
                      phone: phone,
                    ),
                  );
                });
              } else {
                debugPrint('[TEACHER_UI] ⚠️ كود الدعوة فارغ!');
              }
            } else {
              debugPrint('[TEACHER_UI] ⚠️ لا توجد نتيجة إضافة معلم');
              // Fallback to generic success message
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(strings.success),
                  backgroundColor: AppColors.success,
                ),
              );
            }
          }
        }
      },
      child: BlocBuilder<TeachersBloc, TeachersState>(
        builder: (context, state) {
          if (state.status == TeachersStatus.loading &&
              state.teachers.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          return RefreshIndicator(
            onRefresh: () async {
              context.read<TeachersBloc>().add(LoadTeachers());
            },
            child: SingleChildScrollView(
              padding: padding,
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Modern Header
                  _buildModernHeader(context, isDark, strings, state),
                  SizedBox(height: AppSpacing.xl.h),

                  // Teachers Table
                  _buildTeachersTable(context, isDark, strings, state),
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
    TeachersState state,
  ) {
    return Container(
      padding: EdgeInsets.all(AppSpacing.xl.w),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF8B5CF6), Color(0xFFA855F7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppSpacing.radiusXl.r),
        boxShadow: [
          BoxShadow(
            color: AppColors.secondary.withValues(alpha: 0.3),
            blurRadius: 20.r,
            offset: Offset(0, 8.h),
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
                strings.teacherManagement,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: AppSpacing.md.w,
                  vertical: AppSpacing.xs.h,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusFull.r),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.people, size: 16.sp, color: Colors.white),
                    SizedBox(width: AppSpacing.xs.w),
                    Text(
                      '${state.teachers.length} ${strings.teachers}',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 13.sp,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          // أزرار الإجراءات
          Row(
            children: [
              // زر الإحصائيات
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd.r),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd.r),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const TeacherStatisticsScreen(),
                        ),
                      );
                    },
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: AppSpacing.md.w,
                        vertical: AppSpacing.sm.h,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.bar_chart_rounded,
                            color: Color(0xFF22C55E),
                          ),
                          SizedBox(width: AppSpacing.xs.w),
                          const Text(
                            '📊 إحصائيات',
                            style: TextStyle(
                              color: Color(0xFF22C55E),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(width: AppSpacing.sm.w),
              // زر إضافة معلم
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd.r),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd.r),
                    onTap: () => _showAddTeacherDialog(
                      context,
                      strings,
                      state.allSubjects,
                    ),
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: AppSpacing.md.w,
                        vertical: AppSpacing.sm.h,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.add_rounded,
                            color: Color(0xFF8B5CF6),
                          ),
                          SizedBox(width: AppSpacing.xs.w),
                          Text(
                            '+ ${strings.addTeacher}',
                            style: const TextStyle(
                              color: Color(0xFF8B5CF6),
                              fontWeight: FontWeight.bold,
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

  Widget _buildTeachersTable(
    BuildContext context,
    bool isDark,
    AppStrings strings,
    TeachersState state,
  ) {
    if (state.teachers.isEmpty) {
      return Container(
        width: double.infinity,
        padding: EdgeInsets.all(32.w),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : Colors.white,
          borderRadius: BorderRadius.circular(16.r),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(Icons.people_outline, size: 48.sp, color: Colors.grey),
            SizedBox(height: 16.h),
            Text(
              strings.noTeachers,
              style: TextStyle(
                fontSize: 16.sp,
                color: Colors.grey,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          // Table Header
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
            decoration: BoxDecoration(
              color: isDark
                  ? AppColors.darkSurfaceVariant
                  : const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.vertical(top: Radius.circular(16.r)),
              border: Border(
                bottom: BorderSide(
                  color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
                ),
              ),
            ),
            child: Row(
              children: [
                _TableCol(
                  flex: 2, // Reduced from 3 for better balance
                  child: Text(strings.teacherName, style: _headerStyle(isDark)),
                ),
                _TableCol(
                  flex: 2, // Use flex instead of fixed width
                  // alignment: Alignment.center, // Removed to match row alignment (Start)
                  child: Text(strings.phone, style: _headerStyle(isDark)),
                ),
                _TableCol(
                  flex: 2, // Subjects column flexible
                  child: Text(
                    strings.isArabic ? 'المواد' : 'Subjects',
                    style: _headerStyle(isDark),
                  ),
                ),
                _TableCol(
                  flex: 1,
                  alignment: Alignment.center,
                  child: Text(
                    strings.isArabic ? 'الطلاب' : 'Students',
                    style: _headerStyle(isDark),
                  ),
                ),
                _TableCol(
                  flex: 1,
                  alignment: Alignment.center,
                  child: Text(strings.salary, style: _headerStyle(isDark)),
                ),
                _TableCol(
                  flex: 1,
                  alignment: Alignment.center,
                  child: Text(strings.rating, style: _headerStyle(isDark)),
                ),
                _TableCol(
                  flex: 1,
                  alignment: Alignment.center,
                  child: Text(strings.status, style: _headerStyle(isDark)),
                ),
                _TableCol(
                  flex: 1,
                  alignment: Alignment.center,
                  child: Text(strings.actions, style: _headerStyle(isDark)),
                ),
              ],
            ),
          ),

          // Table Rows
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: state.teachers.length,
            separatorBuilder: (context, index) => Divider(
              height: 1,
              thickness: 1,
              color: isDark ? Colors.grey[800] : Colors.grey[100],
            ),
            itemBuilder: (context, index) {
              final teacher = state.teachers[index];
              return _TeacherRow(
                key: ValueKey(teacher.id),
                teacher: teacher,
                allSubjects: state.allSubjects,
                allTeachers: state.teachers,
                isDark: isDark,
                strings: strings,
                onEdit: () => _showEditTeacherDialog(
                  context,
                  teacher,
                  strings,
                  state.allSubjects,
                ),
                onDelete: () => _showDeleteDialog(context, teacher, strings),
                onDeactivate: () => _showSmartDeactivateDialog(
                  context,
                  teacher,
                  strings,
                  state.teachers,
                ),
                onReactivate: () =>
                    _showReactivateDialog(context, teacher, strings),
                onViewSchedule: () =>
                    _showTeacherSchedule(context, teacher, strings),
                onViewSalaries: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => TeacherSalariesScreen(
                        teacherId: teacher.id,
                        teacherName: teacher.name,
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  TextStyle _headerStyle(bool isDark) {
    return TextStyle(
      fontSize: 12.sp,
      fontWeight: FontWeight.w600,
      color: isDark ? Colors.grey[400] : Colors.grey[600],
    );
  }

  void _showAddTeacherDialog(
    BuildContext context,
    AppStrings strings,
    List<Subject> allSubjects,
  ) {
    final teachersBloc = context.read<TeachersBloc>();
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final emailController = TextEditingController();
    final specialtyController = TextEditingController();
    SalaryType salaryType = SalaryType.fixed;
    final salaryController = TextEditingController();
    List<String> selectedSubjectIds = [];

    showDialog(
      context: context,
      builder: (dialogContext) => BlocListener<TeachersBloc, TeachersState>(
        listener: (ctx, state) {
          if (state.status == TeachersStatus.success &&
              state.lastAction == 'add') {
            Navigator.of(dialogContext).pop();
          }
        },
        child: BlocBuilder<TeachersBloc, TeachersState>(
          builder: (context, state) {
            return StatefulBuilder(
              builder: (context, setState) => AlertDialog(
                title: Row(
                  children: [
                    const Icon(Icons.person_add, color: AppColors.primary),
                    const SizedBox(width: AppSpacing.sm),
                    Text(strings.addTeacher),
                  ],
                ),
                content: SizedBox(
                  width: 500,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: nameController,
                                decoration: InputDecoration(
                                  labelText: '${strings.teacherName} *',
                                  prefixIcon: const Icon(Icons.person_outline),
                                ),
                              ),
                            ),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(
                              child: TextFormField(
                                controller: phoneController,
                                decoration: InputDecoration(
                                  labelText: '${strings.phone} *',
                                  prefixIcon: const Icon(Icons.phone_outlined),
                                ),
                                keyboardType: TextInputType.phone,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: emailController,
                                decoration: InputDecoration(
                                  labelText: strings.email,
                                  prefixIcon: const Icon(Icons.email_outlined),
                                ),
                              ),
                            ),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(
                              child: TextFormField(
                                controller: specialtyController,
                                decoration: InputDecoration(
                                  labelText: strings.specialty,
                                  prefixIcon: const Icon(Icons.school_outlined),
                                  hintText: 'e.g. Math, Physics',
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          strings.subjects,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(AppSpacing.sm),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: Colors.grey.withOpacity(0.3),
                            ),
                            borderRadius: BorderRadius.circular(
                              AppSpacing.radiusMd,
                            ),
                          ),
                          child: allSubjects.isEmpty
                              ? Text(
                                  strings.isArabic
                                      ? 'لا توجد مواد'
                                      : 'No subjects found',
                                )
                              : Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: allSubjects.map((subject) {
                                    final isSelected = selectedSubjectIds
                                        .contains(subject.id);
                                    return FilterChip(
                                      label: Text(subject.name),
                                      selected: isSelected,
                                      onSelected: (selected) {
                                        setState(() {
                                          if (selected) {
                                            selectedSubjectIds.add(subject.id);
                                          } else {
                                            selectedSubjectIds.remove(
                                              subject.id,
                                            );
                                          }
                                        });
                                      },
                                      selectedColor: AppColors.primary
                                          .withOpacity(0.2),
                                      checkmarkColor: AppColors.primary,
                                    );
                                  }).toList(),
                                ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<SalaryType>(
                                value: salaryType,
                                decoration: InputDecoration(
                                  labelText: '${strings.salaryType} *',
                                  prefixIcon: const Icon(
                                    Icons.payments_outlined,
                                  ),
                                ),
                                items: [
                                  DropdownMenuItem(
                                    value: SalaryType.fixed,
                                    child: Text(strings.fixedSalary),
                                  ),
                                  DropdownMenuItem(
                                    value: SalaryType.percentage,
                                    child: Text(strings.percentage),
                                  ),
                                  DropdownMenuItem(
                                    value: SalaryType.perSession,
                                    child: Text(strings.perSession),
                                  ),
                                ],
                                onChanged: (value) =>
                                    setState(() => salaryType = value!),
                              ),
                            ),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(
                              child: TextFormField(
                                controller: salaryController,
                                decoration: InputDecoration(
                                  labelText: salaryType == SalaryType.percentage
                                      ? '${strings.percentage} (%)'
                                      : '${strings.amount} (${strings.isArabic ? "ج" : "LE"})',
                                  prefixIcon: const Icon(Icons.attach_money),
                                ),
                                keyboardType: TextInputType.number,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    child: Text(strings.cancel),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      if (nameController.text.isEmpty ||
                          phoneController.text.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(strings.fillRequiredFields)),
                        );
                        return;
                      }
                      final newTeacher = Teacher(
                        id: '',
                        name: nameController.text,
                        phone: phoneController.text,
                        email: emailController.text.isEmpty
                            ? null
                            : emailController.text,
                        subjectIds: selectedSubjectIds,
                        salaryType: salaryType,
                        salaryAmount:
                            double.tryParse(salaryController.text) ?? 0,
                        isActive: true,
                        createdAt: DateTime.now(),
                      );
                      teachersBloc.add(AddTeacher(newTeacher));
                    },
                    child: state.status == TeachersStatus.loading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(strings.add),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  void _showEditTeacherDialog(
    BuildContext context,
    Teacher teacher,
    AppStrings strings,
    List<Subject> allSubjects,
  ) {
    final teachersBloc = context.read<TeachersBloc>();
    final nameController = TextEditingController(text: teacher.name);
    final phoneController = TextEditingController(text: teacher.phone);
    final emailController = TextEditingController(text: teacher.email ?? '');
    final salaryController = TextEditingController(
      text: teacher.salaryAmount.toString(),
    );
    SalaryType salaryType = teacher.salaryType;
    List<String> selectedSubjectIds = List.from(teacher.subjectIds);

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.edit, color: AppColors.primary),
              const SizedBox(width: AppSpacing.sm),
              Text('${strings.editTeacher}: ${teacher.name}'),
            ],
          ),
          content: SizedBox(
            width: 500,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextFormField(
                    controller: nameController,
                    decoration: InputDecoration(
                      labelText: strings.teacherName,
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
                    controller: emailController,
                    decoration: InputDecoration(
                      labelText: strings.email,
                      prefixIcon: const Icon(Icons.email_outlined),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    strings.subjects,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.withOpacity(0.3)),
                      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                    ),
                    child: allSubjects.isEmpty
                        ? Text(
                            strings.isArabic
                                ? 'لا توجد مواد'
                                : 'No subjects found',
                          )
                        : Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: allSubjects.map((subject) {
                              final isSelected = selectedSubjectIds.contains(
                                subject.id,
                              );
                              return FilterChip(
                                label: Text(subject.name),
                                selected: isSelected,
                                onSelected: (selected) {
                                  setState(() {
                                    if (selected) {
                                      selectedSubjectIds.add(subject.id);
                                    } else {
                                      selectedSubjectIds.remove(subject.id);
                                    }
                                  });
                                },
                                selectedColor: AppColors.primary.withOpacity(
                                  0.2,
                                ),
                                checkmarkColor: AppColors.primary,
                              );
                            }).toList(),
                          ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<SalaryType>(
                          value: salaryType,
                          decoration: InputDecoration(
                            labelText: strings.salaryType,
                          ),
                          items: [
                            DropdownMenuItem(
                              value: SalaryType.fixed,
                              child: Text(strings.fixedSalary),
                            ),
                            DropdownMenuItem(
                              value: SalaryType.percentage,
                              child: Text(strings.percentage),
                            ),
                            DropdownMenuItem(
                              value: SalaryType.perSession,
                              child: Text(strings.perSession),
                            ),
                          ],
                          onChanged: (value) =>
                              setState(() => salaryType = value!),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: TextFormField(
                          controller: salaryController,
                          decoration: InputDecoration(
                            labelText: salaryType == SalaryType.percentage
                                ? '${strings.percentage} (%)'
                                : '${strings.amount} (${strings.isArabic ? "ج" : "LE"})',
                          ),
                          keyboardType: TextInputType.number,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(strings.cancel),
            ),
            ElevatedButton(
              onPressed: () {
                final updatedTeacher = teacher.copyWith(
                  name: nameController.text,
                  phone: phoneController.text,
                  email: emailController.text.isEmpty
                      ? null
                      : emailController.text,
                  subjectIds: selectedSubjectIds,
                  salaryType: salaryType,
                  salaryAmount:
                      double.tryParse(salaryController.text) ??
                      teacher.salaryAmount,
                );
                teachersBloc.add(UpdateTeacher(updatedTeacher));
                Navigator.pop(dialogContext);
              },
              child: Text(strings.save),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteDialog(
    BuildContext context,
    Teacher teacher,
    AppStrings strings,
  ) {
    final teachersBloc = context.read<TeachersBloc>();
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(strings.delete),
        content: Text(
          '${strings.isArabic ? "هل أنت متأكد من حذف المعلم" : "Are you sure you want to delete teacher"} "${teacher.name}"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(strings.cancel),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () {
              teachersBloc.add(DeleteTeacher(teacher.id));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('${strings.delete}: ${teacher.name}')),
              );
              Navigator.pop(dialogContext);
            },
            child: Text(strings.delete),
          ),
        ],
      ),
    );
  }

  void _showReactivateDialog(
    BuildContext context,
    Teacher teacher,
    AppStrings strings,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.check_circle_outline, color: AppColors.success),
            const SizedBox(width: 8),
            Text('تنشيط المعلم'),
          ],
        ),
        content: Text(
          'هل أنت متأكد من إعادة تنشيط المعلم "${teacher.name}"؟\nسيظهر المعلم مرة أخرى في القوائم ويمكن إسناد المجموعات له.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(strings.cancel),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.success),
            onPressed: () {
              Navigator.pop(context);
              context.read<TeachersBloc>().add(ReactivateTeacher(teacher.id));
            },
            child: const Text('تنشيط'),
          ),
        ],
      ),
    );
  }

  void _showSmartDeactivateDialog(
    BuildContext context,
    Teacher teacher,
    AppStrings strings,
    List<Teacher> allTeachers,
  ) {
    final bloc = context.read<TeachersBloc>();
    // Trigger dependency check immediately
    bloc.add(CheckDependencies(teacher.id));

    showDialog(
      context: context,
      builder: (dialogContext) => BlocProvider.value(
        value: bloc,
        child: BlocBuilder<TeachersBloc, TeachersState>(
          builder: (context, state) {
            final isLoading = state.status == TeachersStatus.loading;
            final deps = state.teacherDependencies;
            final hasDeps =
                deps != null && (deps['groups']! > 0 || deps['sessions']! > 0);

            return AlertDialog(
              title: Row(
                children: [
                  const Icon(Icons.pause_circle_outline, color: Colors.orange),
                  const SizedBox(width: 8),
                  Text('إيقاف المعلم: ${teacher.name}'),
                ],
              ),
              content: SizedBox(
                width: 500,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (isLoading && deps == null)
                      const Center(child: CircularProgressIndicator())
                    else if (deps != null) ...[
                      // Status Audit Card
                      Container(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        decoration: BoxDecoration(
                          color: hasDeps
                              ? AppColors.error.withOpacity(0.1)
                              : AppColors.success.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(
                            AppSpacing.radiusMd,
                          ),
                          border: Border.all(
                            color: hasDeps
                                ? AppColors.error.withOpacity(0.3)
                                : AppColors.success.withOpacity(0.3),
                          ),
                        ),
                        child: Column(
                          children: [
                            Text(
                              hasDeps
                                  ? '⚠️ توجد التزامات نشطة'
                                  : '✅ لا توجد التزامات نشطة',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: hasDeps
                                    ? AppColors.error
                                    : AppColors.success,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                _buildStatBadge(
                                  'المجموعات النشطة',
                                  deps['groups'].toString(),
                                  Icons.groups,
                                ),
                                _buildStatBadge(
                                  'الحصص القادمة',
                                  deps['sessions'].toString(),
                                  Icons.calendar_today,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: AppSpacing.lg),

                      if (hasDeps) ...[
                        const Text(
                          'لا يمكن إيقاف المعلم مباشرة لوجود التزامات.',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        const Text('ماذا تريد أن تفعل بالمجموعات الحالية؟'),
                        const SizedBox(height: 16),

                        // Action: Transfer
                        _ReassignmentForm(
                          currentTeacherId: teacher.id,
                          allTeachers: allTeachers
                              .where((t) => t.id != teacher.id && t.isActive)
                              .toList(),
                          onConfirm: (newTeacherId) {
                            Navigator.pop(dialogContext);
                            bloc.add(
                              ReassignAndDeactivate(teacher.id, newTeacherId),
                            );
                          },
                        ),
                      ] else ...[
                        const Text(
                          'المعلم ليس لديه أي التزامات نشطة حالياً. يمكنك إيقافه بأمان.',
                        ),
                      ],
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: Text(strings.cancel),
                ),
                if (!isLoading && !hasDeps)
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                    ),
                    onPressed: () {
                      Navigator.pop(dialogContext);
                      bloc.add(DeactivateTeacher(teacher.id));
                    },
                    child: const Text('تأكيد الإيقاف'),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildStatBadge(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, size: 20, color: AppColors.textSecondary),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
        ),
      ],
    );
  }

  void _showTeacherSchedule(
    BuildContext context,
    Teacher teacher,
    AppStrings strings,
  ) {
    showDialog(
      context: context,
      builder: (dialogContext) =>
          _TeacherScheduleDialog(teacher: teacher, strings: strings),
    );
  }
}

class _TeacherScheduleDialog extends StatelessWidget {
  final Teacher teacher;
  final AppStrings strings;

  const _TeacherScheduleDialog({required this.teacher, required this.strings});

  @override
  Widget build(BuildContext context) {
    // Fetch schedule asynchronously
    return FutureBuilder<List<ScheduleSession>>(
      future: context.read<ScheduleRepository>().getSessions(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const AlertDialog(
            content: SizedBox(
              height: 100,
              child: Center(child: CircularProgressIndicator()),
            ),
          );
        }

        final teacherSessions = snapshot.data!
            .where((s) => s.teacherId == teacher.id)
            .toList();

        final isDark = Theme.of(context).brightness == Brightness.dark;
        final days = strings.daysList;

        return AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.calendar_month, color: AppColors.primary),
              const SizedBox(width: AppSpacing.sm),
              Text('${strings.teacherSchedule}: ${teacher.name}'),
            ],
          ),
          content: SizedBox(
            width: 500,
            height: 400,
            child: teacherSessions.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.event_busy,
                          size: 64,
                          color: AppColors.gray400,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Text(strings.noSessionsForTeacher),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: teacherSessions.length,
                    itemBuilder: (context, index) {
                      final session = teacherSessions[index];
                      // Safety check for dayOfWeek index
                      final dayName =
                          (session.dayOfWeek >= 0 &&
                              session.dayOfWeek < days.length)
                          ? days[session.dayOfWeek]
                          : 'Day ${session.dayOfWeek}';

                      return Container(
                        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                        padding: const EdgeInsets.all(AppSpacing.md),
                        decoration: BoxDecoration(
                          color: isDark
                              ? AppColors.darkSurfaceVariant
                              : AppColors.lightSurfaceVariant,
                          borderRadius: BorderRadius.circular(
                            AppSpacing.radiusMd,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(
                                  AppSpacing.radiusSm,
                                ),
                              ),
                              child: const Icon(
                                Icons.schedule,
                                color: AppColors.primary,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    session.subjectName,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Text(
                                    '$dayName - ${session.startTime} ${strings.to} ${session.endTime}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isDark
                                          ? AppColors.darkTextSecondary
                                          : AppColors.lightTextSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.info.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(
                                  AppSpacing.radiusFull,
                                ),
                              ),
                              child: Text(
                                session.roomName,
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: AppColors.info,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: Text(strings.close),
            ),
          ],
        );
      },
    );
  }
}

/// Dialog widget to show invitation code after successfully adding a teacher
class _InvitationCodeDialog extends StatelessWidget {
  final String teacherName;
  final String teacherCode;
  final String? phone;

  const _InvitationCodeDialog({
    required this.teacherName,
    required this.teacherCode,
    this.phone,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final strings = AppStrings.of(context);

    return AlertDialog(
      backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusXl.r),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: EdgeInsets.all(16.w),
            decoration: BoxDecoration(
              color: AppColors.success.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.check_circle,
              color: AppColors.success,
              size: 48.sp,
            ),
          ),
          SizedBox(height: AppSpacing.lg.h),
          Text(
            strings.isArabic
                ? 'تمت إضافة المعلم بنجاح'
                : 'Teacher Added Successfully',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: AppSpacing.sm.h),
          Text(
            teacherName,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: AppSpacing.xl.h),
          Container(
            padding: EdgeInsets.all(AppSpacing.lg.w),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd.r),
              border: Border.all(
                color: Colors.blue.withOpacity(0.3),
                width: 1.5,
              ),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.vpn_key, color: Colors.blue, size: 20.sp),
                    SizedBox(width: 8.w),
                    Text(
                      strings.isArabic ? 'كود الدعوة' : 'Invitation Code',
                      style: TextStyle(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w600,
                        color: Colors.blue,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: AppSpacing.sm.h),
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 16.w,
                    vertical: 12.h,
                  ),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkSurfaceVariant : Colors.white,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusSm.r),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Directionality(
                        textDirection: TextDirection.ltr,
                        child: Text(
                          teacherCode,
                          style: TextStyle(
                            fontSize: 24.sp,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 2,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ),
                      SizedBox(width: 12.w),
                      IconButton(
                        icon: const Icon(Icons.copy),
                        iconSize: 20.sp,
                        color: Colors.blue,
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: teacherCode));
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                strings.isArabic
                                    ? 'تم نسخ الكود'
                                    : 'Code copied',
                              ),
                              duration: const Duration(seconds: 1),
                              backgroundColor: AppColors.success,
                            ),
                          );
                        },
                        tooltip: strings.isArabic ? 'نسخ' : 'Copy',
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: AppSpacing.md.h),
          Container(
            padding: EdgeInsets.all(AppSpacing.md.w),
            decoration: BoxDecoration(
              color: AppColors.info.withOpacity(0.1),
              borderRadius: BorderRadius.circular(AppSpacing.radiusSm.r),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: AppColors.info, size: 20.sp),
                SizedBox(width: 8.w),
                Expanded(
                  child: Text(
                    strings.isArabic
                        ? 'يرجى مشاركة هذا الكود مع المعلم للانضمام إلى النظام'
                        : 'Please share this code with the teacher to join the system',
                    style: TextStyle(fontSize: 12.sp, color: AppColors.info),
                  ),
                ),
              ],
            ),
          ),
          if (phone != null) ...[
            SizedBox(height: AppSpacing.sm.h),
            Text(
              '${strings.phone}: $phone',
              style: TextStyle(
                fontSize: 12.sp,
                color: isDark
                    ? AppColors.darkTextSecondary
                    : AppColors.lightTextSecondary,
              ),
            ),
          ],
        ],
      ),
      actions: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              padding: EdgeInsets.symmetric(vertical: 14.h),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd.r),
              ),
            ),
            onPressed: () {
              Navigator.pop(context);
            },
            child: Text(
              strings.close,
              style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ],
    );
  }
}

class _ReassignmentForm extends StatefulWidget {
  final String currentTeacherId;
  final List<Teacher> allTeachers;
  final Function(String) onConfirm;

  const _ReassignmentForm({
    required this.allTeachers,
    required this.onConfirm,
    required this.currentTeacherId,
  });

  @override
  State<_ReassignmentForm> createState() => _ReassignmentFormState();
}

class _ReassignmentFormState extends State<_ReassignmentForm> {
  String? _selectedTeacherId;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        DropdownButtonFormField<String>(
          decoration: const InputDecoration(
            labelText: 'اختر معلماً بديلاً لنقل المجموعات',
            prefixIcon: Icon(Icons.person_outline),
            border: OutlineInputBorder(),
          ),
          items: widget.allTeachers
              .map((t) => DropdownMenuItem(value: t.id, child: Text(t.name)))
              .toList(),
          onChanged: (val) => setState(() => _selectedTeacherId = val),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.all(16),
            ),
            icon: const Icon(Icons.swap_horiz_rounded),
            label: const Text('نقل المجموعات وإيقاف المعلم'),
            onPressed: _selectedTeacherId == null
                ? null
                : () {
                    widget.onConfirm(_selectedTeacherId!);
                  },
          ),
        ),
      ],
    );
  }
}

// Helper Widget for Columns to ensure alignment
class _TableCol extends StatelessWidget {
  final Widget child;
  final double? width;
  final int? flex;
  final Alignment alignment;

  const _TableCol({
    required this.child,
    this.width,
    this.flex,
    this.alignment = Alignment.centerLeft,
  });

  @override
  Widget build(BuildContext context) {
    if (width != null) {
      return SizedBox(
        width: width!.w,
        child: Align(alignment: alignment, child: child),
      );
    }
    return Expanded(
      flex: flex ?? 1,
      child: Align(alignment: alignment, child: child),
    );
  }
}

class _TeacherRow extends StatefulWidget {
  final Teacher teacher;
  final List<Subject> allSubjects;
  final List<Teacher> allTeachers;
  final bool isDark;
  final AppStrings strings;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onDeactivate;
  final VoidCallback onReactivate;
  final VoidCallback onViewSchedule;
  final VoidCallback onViewSalaries;

  const _TeacherRow({
    super.key,
    required this.teacher,
    required this.allSubjects,
    required this.allTeachers,
    required this.isDark,
    required this.strings,
    required this.onEdit,
    required this.onDelete,
    required this.onDeactivate,
    required this.onReactivate,
    required this.onViewSchedule,
    required this.onViewSalaries,
  });

  @override
  State<_TeacherRow> createState() => _TeacherRowState();
}

class _TeacherRowState extends State<_TeacherRow> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final rating = widget.teacher.rating;
    final isInactive = !widget.teacher.isActive;

    // Subjects Logic
    final subjectNames = widget.teacher.subjectIds.isEmpty
        ? [widget.strings.isArabic ? 'غير محدد' : 'N/A']
        : widget.teacher.subjectIds
              .map((id) {
                final s = widget.allSubjects
                    .where((sub) => sub.id == id)
                    .firstOrNull;
                return s?.name ?? '?';
              })
              .take(2)
              .toList();
    if (widget.teacher.subjectIds.length > 2)
      subjectNames.add('+${widget.teacher.subjectIds.length - 2}');

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
        decoration: BoxDecoration(
          color: _isHovered
              ? (widget.isDark
                    ? AppColors.primary.withOpacity(0.1)
                    : AppColors.primary.withOpacity(0.05))
              : Colors.transparent,
        ),
        child: Row(
          children: [
            // Teacher Name & Avatar
            _TableCol(
              flex: 2, // Match header
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 18.r,
                    backgroundColor: isInactive
                        ? Colors.grey
                        : AppColors.primary.withOpacity(0.1),
                    backgroundImage: widget.teacher.imageUrl != null
                        ? NetworkImage(widget.teacher.imageUrl!)
                        : null,
                    child: widget.teacher.imageUrl == null
                        ? Text(
                            widget.teacher.name.isNotEmpty
                                ? widget.teacher.name[0].toUpperCase()
                                : '?',
                            style: TextStyle(
                              color: isInactive
                                  ? Colors.white
                                  : AppColors.primary,
                              fontWeight: FontWeight.bold,
                              fontSize: 14.sp,
                            ),
                          )
                        : null,
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.teacher.name,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13.sp,
                            color: isInactive
                                ? Colors.grey
                                : (widget.isDark
                                      ? Colors.white
                                      : Colors.black87),
                            decoration: isInactive
                                ? TextDecoration.lineThrough
                                : null,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (widget.teacher.email != null)
                          Text(
                            widget.teacher.email!,
                            style: TextStyle(
                              fontSize: 11.sp,
                              color: Colors.grey,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Phone
            _TableCol(
              flex: 2, // Match header
              child: InkWell(
                onTap: () {
                  Clipboard.setData(ClipboardData(text: widget.teacher.phone));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Copied'),
                      duration: const Duration(seconds: 1),
                    ),
                  );
                },
                borderRadius: BorderRadius.circular(4),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 4,
                    horizontal: 4,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.copy, size: 12.sp, color: Colors.grey),
                      SizedBox(width: 4.w),
                      Text(
                        // Format phone if needed
                        widget.teacher.phone,
                        style: TextStyle(
                          fontSize: 12.sp,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Subjects
            _TableCol(
              flex: 2, // Match header
              child: Wrap(
                spacing: 4,
                runSpacing: 4,
                children: subjectNames
                    .map(
                      (name) => Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 8.w,
                          vertical: 2.h,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.secondary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4.r),
                          border: Border.all(
                            color: AppColors.secondary.withOpacity(0.2),
                          ),
                        ),
                        child: Text(
                          name,
                          style: TextStyle(
                            fontSize: 10.sp,
                            color: AppColors.secondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),

            // Student Count
            _TableCol(
              flex: 1, // Match header
              alignment: Alignment.center,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: Text(
                  '${widget.teacher.studentCount}',
                  style: TextStyle(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
              ),
            ),

            // Salary
            _TableCol(
              flex: 1, // Match header
              alignment: Alignment.center, // Center align salary
              child: Text(
                _getSalaryText(),
                style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w600),
              ),
            ),

            // Rating
            _TableCol(
              flex: 1, // Match header
              alignment: Alignment.center,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.star_rounded, color: Colors.amber, size: 16.sp),
                  SizedBox(width: 2.w),
                  Text(
                    rating.toStringAsFixed(1),
                    style: TextStyle(
                      fontSize: 12.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),

            // Status
            _TableCol(
              flex: 1, // Match header
              alignment: Alignment.center,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                decoration: BoxDecoration(
                  color: isInactive
                      ? Colors.red.withOpacity(0.1)
                      : Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12.r),
                  border: Border.all(
                    color: isInactive
                        ? Colors.red.withOpacity(0.3)
                        : Colors.green.withOpacity(0.3),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Icon removed to save space for cleaner look in small column
                    Text(
                      isInactive
                          ? (widget.strings.isArabic ? 'موقوف' : 'Inactive')
                          : (widget.strings.isArabic ? 'نشط' : 'Active'),
                      style: TextStyle(
                        fontSize: 10.sp,
                        fontWeight: FontWeight.bold,
                        color: isInactive ? Colors.red : Colors.green,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Actions
            _TableCol(
              flex: 1, // Match header
              alignment: Alignment.center,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _ActionButton(
                      icon: Icons.calendar_today_rounded,
                      color: Colors.blue,
                      tooltip: 'جدول الحصص',
                      onTap: widget.onViewSchedule,
                    ),
                    SizedBox(width: 4.w),
                    _ActionButton(
                      icon: Icons.attach_money_rounded,
                      color: Colors.green,
                      tooltip: 'الرواتب',
                      onTap: widget.onViewSalaries,
                    ),
                    SizedBox(width: 4.w),
                    // More Menu
                    PopupMenuButton<String>(
                      icon: Icon(
                        Icons.more_vert_rounded,
                        size: 20.sp,
                        color: Colors.grey,
                      ),
                      tooltip: 'المزيد',
                      onSelected: (val) {
                        if (val == 'edit') widget.onEdit();
                        if (val == 'code') _showInvitationCode();
                        if (val == 'status')
                          isInactive
                              ? widget.onReactivate()
                              : widget.onDeactivate();
                        if (val == 'delete') widget.onDelete();
                      },
                      itemBuilder: (context) => [
                        PopupMenuItem(
                          value: 'edit',
                          child: _MenuItem(
                            icon: Icons.edit,
                            text: widget.strings.edit,
                            color: Colors.blue,
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'code',
                          child: _MenuItem(
                            icon: Icons.qr_code,
                            text: 'كود الدعوة',
                            color: Colors.purple,
                          ),
                        ),
                        PopupMenuItem(
                          value: 'status',
                          child: _MenuItem(
                            icon: isInactive ? Icons.play_arrow : Icons.pause,
                            text: isInactive ? 'تنشيط' : 'إيقاف',
                            color: isInactive ? Colors.green : Colors.orange,
                          ),
                        ),
                        PopupMenuItem(
                          value: 'delete',
                          child: _MenuItem(
                            icon: Icons.delete,
                            text: widget.strings.delete,
                            color: Colors.red,
                          ),
                        ),
                      ],
                    ),
                  ],
                ), // Row closing
              ), // FittedBox closing
            ),
          ],
        ),
      ),
    );
  }

  String _getSalaryText() {
    switch (widget.teacher.salaryType) {
      case SalaryType.fixed:
        return '${widget.teacher.salaryAmount.toInt()} ${widget.strings.isArabic ? "ج" : "LE"}';
      case SalaryType.percentage:
        return '${widget.teacher.salaryAmount.toInt()}%';
      case SalaryType.perSession:
        return '${widget.teacher.salaryAmount.toInt()} ${widget.strings.isArabic ? "ج/ح" : "LE/s"}';
    }
  }

  Future<void> _showInvitationCode() async {
    final repo = context.read<TeachersRepository>();
    try {
      final code = await repo.getTeacherInvitationCode(widget.teacher.id);
      if (!mounted) return;
      if (code != null) {
        showDialog(
          context: context,
          builder: (ctx) => _InvitationCodeDialog(
            teacherName: widget.teacher.name,
            teacherCode: code,
            phone: widget.teacher.phone,
          ),
        );
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('No code found')));
      }
    } catch (e) {
      debugPrint('Error fetching code: $e');
    }
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8.r),
        child: Container(
          padding: EdgeInsets.all(6.w),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8.r),
          ),
          child: Icon(icon, size: 16.sp, color: color),
        ),
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;
  const _MenuItem({
    required this.icon,
    required this.text,
    required this.color,
  });
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        SizedBox(width: 8),
        Text(text),
      ],
    );
  }
}
