import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/l10n/app_strings.dart';
import '../../../../core/utils/form_validators.dart';

import '../../../../core/providers/center_provider.dart';
import '../../../../shared/widgets/buttons/app_button.dart';
import '../../../../shared/models/models.dart';
import '../../../../shared/models/pricing_models.dart';
import '../../../../shared/models/billing_models.dart';
import '../../data/repositories/subjects_repository.dart';
import '../../../../features/teachers/data/repositories/teachers_repository.dart';
import '../../bloc/subjects_bloc.dart';
import '../../../../features/settings/presentation/screens/course_prices_screen.dart';

/// شاشة إدارة المواد
class SubjectsScreen extends StatelessWidget {
  const SubjectsScreen({super.key});

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
      create: (context) => SubjectsBloc(
        subjectsRepository: context.read<SubjectsRepository>(),
        teachersRepository: context.read<TeachersRepository>(),
        centerId: centerProvider.centerId!,
      )..add(LoadSubjects()),
      child: const _SubjectsView(),
    );
  }
}

class _SubjectsView extends StatelessWidget {
  const _SubjectsView();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final padding = EdgeInsets.all(AppSpacing.pagePadding.w);
    final strings = AppStrings.of(context);

    // Dynamic Columns handled by MaxCrossAxisExtent

    return BlocListener<SubjectsBloc, SubjectsState>(
      listener: (context, state) {
        if (state.status == SubjectsStatus.failure) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.errorMessage ?? strings.errorOccurred),
              backgroundColor: AppColors.error,
            ),
          );
        }
      },
      child: BlocBuilder<SubjectsBloc, SubjectsState>(
        builder: (context, state) {
          if (state.status == SubjectsStatus.loading) {
            return const Center(child: CircularProgressIndicator());
          }

          // 🔧 استخدام العدد من CenterProvider بدلاً من مجموع المواد (لأن طالب في مادتين يُحسب مرتين)
          final centerProvider = context.watch<CenterProvider>();
          final totalStudents = centerProvider.studentCount;
          final activeSubjects = state.subjects.where((s) => s.isActive).length;

          return SingleChildScrollView(
            padding: padding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Region
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          strings.subjectsManagement,
                          style: Theme.of(context).textTheme.headlineMedium
                              ?.copyWith(
                                fontWeight: FontWeight.bold,
                                fontSize: 24.sp,
                              ),
                        ),
                        SizedBox(height: 4.h),
                        Text(
                          strings.subjectsManagementSubtitle,
                          style: TextStyle(
                            color: isDark
                                ? AppColors.darkTextSecondary
                                : AppColors.lightTextSecondary,
                            fontSize: 14.sp,
                          ),
                        ),
                      ],
                    ),
                    AppButton(
                      text: strings.addSubject,
                      icon: Icons.add_rounded,
                      onPressed: () => _showAddSubjectDialog(
                        context,
                        strings,
                        state.allTeachers,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: AppSpacing.xl.h),

                // Stats Overlay
                _SubjectsStats(
                  totalSubjects: state.subjects.length,
                  totalStudents: totalStudents,
                  activeSubjects: activeSubjects,
                  strings: strings,
                  isDark: isDark,
                ),
                SizedBox(height: AppSpacing.xl.h),

                // Subjects Grid
                if (state.subjects.isEmpty)
                  _buildEmptyState(context, strings, isDark)
                else
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 350.w,
                      crossAxisSpacing: AppSpacing.lg.w,
                      mainAxisSpacing: AppSpacing.lg.h,
                      childAspectRatio: 0.85, // Adjusted for prices section
                    ),
                    itemCount: state.subjects.length,
                    itemBuilder: (context, index) {
                      final subject = state.subjects[index];
                      final subjectPrices = state.pricesForSubject(
                        subject.name,
                      );
                      return _SubjectCard(
                        subject: subject,
                        allTeachers: state.allTeachers,
                        prices: subjectPrices,
                        billingType: centerProvider.billingType,
                        isDark: isDark,
                        strings: strings,
                        onEdit: () => _showEditSubjectDialog(
                          context,
                          subject,
                          strings,
                          state.allTeachers,
                        ),
                        onDelete: () =>
                            _showDeleteDialog(context, subject, strings),
                      );
                    },
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(
    BuildContext context,
    AppStrings strings,
    bool isDark,
  ) {
    return Container(
      padding: EdgeInsets.all(AppSpacing.xxxl.w),
      width: double.infinity,
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusXl.r),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          width: 0.5,
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(AppSpacing.xl.w),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.menu_book_rounded,
                size: 48.sp,
                color: AppColors.primary,
              ),
            ),
            SizedBox(height: AppSpacing.lg.h),
            Text(
              strings.noSubjects,
              style: TextStyle(
                fontSize: 18.sp,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : Colors.grey[800],
              ),
            ),
            SizedBox(height: AppSpacing.sm.h),
            Text(
              strings.isArabic
                  ? 'قم بإضافة مواد دراسية جديدة'
                  : 'Add new subjects to your curriculum',
              style: TextStyle(
                color: isDark
                    ? AppColors.darkTextSecondary
                    : AppColors.lightTextSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddSubjectDialog(
    BuildContext context,
    AppStrings strings,
    List<Teacher> teachers,
  ) {
    final subjectsBloc = context.read<SubjectsBloc>();
    final nameController = TextEditingController();
    String? selectedTeacher;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.menu_book,
                  color: AppColors.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Text(strings.addSubject),
            ],
          ),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameController,
                  decoration: InputDecoration(
                    labelText: '${strings.subjectName} *',
                    prefixIcon: const Icon(Icons.subject),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(
                        AppSpacing.radiusMd.r,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                DropdownButtonFormField<String>(
                  value: selectedTeacher,
                  decoration: InputDecoration(
                    labelText: '${strings.teacher} *',
                    prefixIcon: const Icon(Icons.person_outline),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(
                        AppSpacing.radiusMd.r,
                      ),
                    ),
                  ),
                  items: teachers
                      .map(
                        (t) =>
                            DropdownMenuItem(value: t.id, child: Text(t.name)),
                      )
                      .toList(),
                  onChanged: (value) => setState(() => selectedTeacher = value),
                ),
                const SizedBox(height: AppSpacing.md),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(strings.cancel),
            ),
            // Save Only
            TextButton(
              onPressed: () {
                if (nameController.text.isEmpty || selectedTeacher == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(strings.fillRequiredFields)),
                  );
                  return;
                }

                if (subjectsBloc.state.subjects.any(
                  (s) =>
                      s.name.trim().toLowerCase() ==
                      nameController.text.trim().toLowerCase(),
                )) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        strings.isArabic
                            ? 'هذه المادة موجودة بالفعل'
                            : 'Subject already exists',
                      ),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

                _addSubject(
                  context,
                  subjectsBloc,
                  nameController.text.trim(),
                  selectedTeacher!,
                  strings,
                );
                Navigator.pop(dialogContext);
              },
              child: const Text('حفظ فقط'),
            ),
            // Save & Set Price
            FilledButton.icon(
              icon: const Icon(Icons.price_check, size: 18),
              onPressed: () {
                if (nameController.text.isEmpty || selectedTeacher == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(strings.fillRequiredFields)),
                  );
                  return;
                }

                if (subjectsBloc.state.subjects.any(
                  (s) =>
                      s.name.trim().toLowerCase() ==
                      nameController.text.trim().toLowerCase(),
                )) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        strings.isArabic
                            ? 'هذه المادة موجودة بالفعل'
                            : 'Subject already exists',
                      ),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

                final subjectName = nameController.text.trim();
                _addSubject(
                  context,
                  subjectsBloc,
                  subjectName,
                  selectedTeacher!,
                  strings,
                );
                Navigator.pop(dialogContext);

                // Navigate to Pricing
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => CoursePricesScreen(
                      initialSubjectName: subjectName,
                      autoOpenAddDialog: true,
                    ),
                  ),
                );
              },
              label: const Text('حفظ وتحديد السعر'),
            ),
          ],
        ),
      ),
    );
  }

  void _addSubject(
    BuildContext context,
    SubjectsBloc bloc,
    String name,
    String teacherId,
    AppStrings strings,
  ) {
    final newSubject = Subject(
      id: '', // DB will assign UUID
      name: name,
      description: '',
      teacherIds: [teacherId],
      monthlyFee: 0,
      isActive: true,
    );

    bloc.add(AddSubject(newSubject));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${strings.success}: "${newSubject.name}"'),
        backgroundColor: AppColors.success,
      ),
    );
  }

  void _showEditSubjectDialog(
    BuildContext context,
    Subject subject,
    AppStrings strings,
    List<Teacher> teachers,
  ) {
    final subjectsBloc = context.read<SubjectsBloc>();
    final nameController = TextEditingController(text: subject.name);
    // Assume single teacher for simple UI, though model supports list
    String? selectedTeacher = subject.teacherIds.isNotEmpty
        ? subject.teacherIds.first
        : null;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.edit,
                  color: AppColors.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Text('${strings.edit}: ${subject.name}'),
            ],
          ),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameController,
                  decoration: InputDecoration(
                    labelText: strings.subjectName,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(
                        AppSpacing.radiusMd.r,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                DropdownButtonFormField<String>(
                  value: selectedTeacher,
                  decoration: InputDecoration(
                    labelText: strings.teacher,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(
                        AppSpacing.radiusMd.r,
                      ),
                    ),
                  ),
                  items: teachers
                      .map(
                        (t) =>
                            DropdownMenuItem(value: t.id, child: Text(t.name)),
                      )
                      .toList(),
                  onChanged: (value) => setState(() => selectedTeacher = value),
                ),
                const SizedBox(height: AppSpacing.md),
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
                final updatedSubject = Subject(
                  id: subject.id,
                  name: nameController.text,
                  description: subject.description,
                  teacherIds: selectedTeacher != null
                      ? [selectedTeacher!]
                      : subject.teacherIds,
                  monthlyFee:
                      subject.monthlyFee, // يبقى كما هو - التسعير في جدول منفصل
                  isActive: subject.isActive,
                );
                subjectsBloc.add(UpdateSubject(updatedSubject));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(strings.success),
                    backgroundColor: AppColors.success,
                  ),
                );
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
    Subject subject,
    AppStrings strings,
  ) {
    final subjectsBloc = context.read<SubjectsBloc>();
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(strings.delete),
        content: Text(
          '${strings.isArabic ? "هل أنت متأكد من حذف مادة" : "Are you sure you want to delete subject"} "${subject.name}"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(strings.cancel),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () {
              subjectsBloc.add(DeleteSubject(subject.id));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('${strings.delete}: ${subject.name}')),
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

class _SubjectsStats extends StatelessWidget {
  final int totalSubjects;
  final int totalStudents;
  final int activeSubjects;
  final AppStrings strings;
  final bool isDark;

  const _SubjectsStats({
    required this.totalSubjects,
    required this.totalStudents,
    required this.activeSubjects,
    required this.strings,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return _buildStatCards(strings, totalSubjects, totalStudents, isDark);
  }

  Widget _buildStatCards(
    AppStrings strings,
    int totalSubjects,
    int totalStudents,
    bool isDark,
  ) {
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            title: strings.subjects,
            value: totalSubjects.toString(),
            color: AppColors.primary,
            icon: Icons.library_books,
            isDark: isDark,
          ),
        ),
        SizedBox(width: AppSpacing.md.w),
        Expanded(
          child: _StatCard(
            title: strings.students,
            value: totalStudents.toString(),
            color: AppColors.secondary,
            icon: Icons.people,
            isDark: isDark,
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final Color color;
  final IconData icon;
  final bool isDark;

  const _StatCard({
    required this.title,
    required this.value,
    required this.color,
    required this.icon,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 16.h),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10.r,
            offset: Offset(0, 4.h),
          ),
        ],
        border: Border(
          left: BorderSide(color: color, width: 4.w),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(12.w),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 24.sp),
          ),
          SizedBox(width: 16.w),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 24.sp,
                  fontWeight: FontWeight.bold,
                  height: 1,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                title,
                style: TextStyle(
                  fontSize: 13.sp,
                  color: isDark
                      ? AppColors.darkTextSecondary
                      : AppColors.lightTextSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SubjectCard extends StatefulWidget {
  final Subject subject;
  final List<Teacher> allTeachers;
  final List<CoursePrice> prices;
  final BillingType billingType;
  final bool isDark;
  final AppStrings strings;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _SubjectCard({
    required this.subject,
    required this.allTeachers,
    required this.prices,
    required this.billingType,
    required this.isDark,
    required this.strings,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  State<_SubjectCard> createState() => _SubjectCardState();
}

class _SubjectCardState extends State<_SubjectCard> {
  bool _isHovered = false;

  String _getTeacherName() {
    if (widget.subject.teacherIds.isEmpty) {
      return widget.strings.isArabic ? 'غير محدد' : 'Not assigned';
    }
    final teacher = widget.allTeachers
        .where((t) => t.id == widget.subject.teacherIds.first)
        .firstOrNull;
    return teacher?.name ?? 'Unknown';
  }

  @override
  Widget build(BuildContext context) {
    // Generate a color based on subject name code unit sum for consistency without storing it
    final seed = widget.subject.name.codeUnits.fold(0, (p, c) => p + c);
    final subjectColor = Colors.primaries[seed % Colors.primaries.length];

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        transform: Matrix4.identity()
          ..translate(0.0, _isHovered ? -4.0.h : 0.0),
        decoration: BoxDecoration(
          color: widget.isDark ? AppColors.darkSurface : Colors.white,
          borderRadius: BorderRadius.circular(AppSpacing.radiusXl.r),
          boxShadow: [
            BoxShadow(
              color: _isHovered
                  ? subjectColor.withValues(alpha: 0.25)
                  : Colors.black.withValues(alpha: 0.05),
              blurRadius: _isHovered ? 20.r : 10.r,
              offset: Offset(0, 8.h),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppSpacing.radiusXl.r),
          child: Stack(
            children: [
              // Subtle Gradient Background Header
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: 80.h,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topRight,
                      end: Alignment.bottomLeft,
                      colors: [
                        subjectColor.withValues(alpha: 0.15),
                        subjectColor.withValues(alpha: 0.0),
                      ],
                    ),
                  ),
                ),
              ),

              Padding(
                padding: EdgeInsets.all(AppSpacing.lg.w),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: EdgeInsets.all(12.w),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16.r),
                            boxShadow: [
                              BoxShadow(
                                color: subjectColor.withValues(alpha: 0.2),
                                blurRadius: 10.r,
                                offset: Offset(0, 4.h),
                              ),
                            ],
                          ),
                          child: Icon(
                            Icons.menu_book_rounded,
                            color: subjectColor,
                            size: 28.sp,
                          ),
                        ),
                        Material(
                          color: Colors.transparent,
                          child: PopupMenuButton<String>(
                            icon: Icon(
                              Icons.more_horiz,
                              color: Colors.grey[400],
                            ),
                            onSelected: (value) {
                              if (value == 'price') {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => CoursePricesScreen(
                                      initialSubjectName: widget.subject.name,
                                      autoOpenAddDialog: true,
                                    ),
                                  ),
                                );
                              }
                              if (value == 'edit') widget.onEdit();
                              if (value == 'delete') widget.onDelete();
                            },
                            itemBuilder: (context) => [
                              PopupMenuItem(
                                value: 'price',
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.price_change_outlined,
                                      size: 18.sp,
                                      color: Colors.green,
                                    ),
                                    SizedBox(width: 8.w),
                                    Text(
                                      widget.strings.isArabic
                                          ? 'الأسعار'
                                          : 'Prices',
                                    ),
                                  ],
                                ),
                              ),
                              PopupMenuItem(
                                value: 'edit',
                                child: Row(
                                  children: [
                                    Icon(Icons.edit_outlined, size: 18.sp),
                                    SizedBox(width: 8.w),
                                    Text(widget.strings.edit),
                                  ],
                                ),
                              ),
                              PopupMenuItem(
                                value: 'delete',
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.delete_outline,
                                      size: 18.sp,
                                      color: AppColors.error,
                                    ),
                                    SizedBox(width: 8.w),
                                    Text(
                                      widget.strings.delete,
                                      style: const TextStyle(
                                        color: AppColors.error,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: AppSpacing.lg.h),

                    Text(
                      widget.subject.name,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18.sp,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 4.h),
                    Row(
                      children: [
                        Icon(
                          Icons.person_outline_rounded,
                          size: 14.sp,
                          color: widget.isDark
                              ? Colors.white54
                              : Colors.grey[500],
                        ),
                        SizedBox(width: 4.w),
                        Expanded(
                          child: Text(
                            _getTeacherName(),
                            style: TextStyle(
                              fontSize: 13.sp,
                              color: widget.isDark
                                  ? AppColors.darkTextSecondary
                                  : AppColors.lightTextSecondary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),

                    // 💰 PRICES SECTION
                    if (widget.prices.isNotEmpty) ...[
                      SizedBox(height: AppSpacing.sm.h),
                      _buildPricesSection(),
                    ],

                    const Spacer(),
                    Container(
                      height: 1.h,
                      color: widget.isDark ? Colors.white10 : Colors.grey[100],
                    ),
                    SizedBox(height: 12.h),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildInfoBadge(
                          Icons.people_outline,
                          '${widget.subject.studentCount}',
                          widget.isDark ? Colors.white70 : Colors.grey[700]!,
                        ),
                        if (widget.prices.isEmpty)
                          _buildInfoBadge(
                            Icons.attach_money,
                            '${widget.subject.monthlyFee.toInt()}',
                            AppColors.primary,
                          )
                        else
                          Text(
                            '${widget.prices.length} سعر',
                            style: TextStyle(
                              fontSize: 12.sp,
                              color: AppColors.success,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoBadge(IconData icon, String text, Color color) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
            color: color,
          ),
        ),
      ],
    );
  }

  /// 💰 Prices Section - Shows stage/grade prices as chips
  Widget _buildPricesSection() {
    return Wrap(
      spacing: 6.w,
      runSpacing: 4.h,
      children: widget.prices.map((price) {
        final gradeLabel = price.gradeLevel ?? 'عام';

        // Dynamic Price Logic based on Billing Type
        double displayAmount = price.sessionPrice;
        String suffix = ''; // e.g. /mo

        bool showMonthly = widget.billingType == BillingType.monthly;
        if (widget.billingType == BillingType.mixed &&
            price.monthlyPrice != null) {
          showMonthly = true;
        }

        if (showMonthly) {
          // Use monthly price if available, otherwise calculate it
          displayAmount =
              price.monthlyPrice ??
              (price.sessionPrice * price.sessionsPerMonth);
          suffix = widget.strings.isArabic ? ' / شهر' : ' / mo';
        }

        // Only format if > 0 to avoid "0.0 EGP / mo" if not set?
        // But 0 means free or unset.
        final priceFormatted = FormUtils.formatCurrency(displayAmount) + suffix;

        return Container(
          padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
          decoration: BoxDecoration(
            color: widget.isDark
                ? AppColors.success.withValues(alpha: 0.15)
                : AppColors.success.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8.r),
            border: Border.all(
              color: AppColors.success.withValues(alpha: 0.3),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                gradeLabel,
                style: TextStyle(
                  fontSize: 10.sp,
                  fontWeight: FontWeight.w600,
                  color: widget.isDark ? Colors.white70 : Colors.grey[700],
                ),
              ),
              SizedBox(width: 4.w),
              Container(
                width: 1,
                height: 12.h,
                color: AppColors.success.withValues(alpha: 0.3),
              ),
              SizedBox(width: 4.w),
              Text(
                priceFormatted,
                style: TextStyle(
                  fontSize: 10.sp,
                  fontWeight: FontWeight.bold,
                  color: AppColors.success,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
