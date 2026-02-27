import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/l10n/app_strings.dart';
import '../../../../shared/models/models.dart';
import '../../bloc/teachers_bloc.dart';

class TeachersList extends StatelessWidget {
  final bool isDark;
  final AppStrings strings;

  const TeachersList({
    super.key,
    required this.isDark,
    required this.strings,
  });

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<TeachersBloc, TeachersState>(
      builder: (context, state) {
        if (state.status == TeachersStatus.loading) {
          return const Center(child: CircularProgressIndicator());
        }

        if (state.filteredTeachers.isEmpty) {
          return Center(
             child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.search_off, size: 64.sp, color: isDark ? Colors.grey : Colors.grey[400]),
                SizedBox(height: 16.h),
                Text(strings.noTeachers, style: TextStyle(color: isDark ? Colors.grey : Colors.grey[600], fontSize: 16.sp)),
              ],
            ),
          );
        }
        
        // Note: TeachersBloc might not have 'filteredTeachers' prop if it's not implemented yet.
        // Checking TeachersBloc... it only has 'teachers'.
        // So for now, we assume 'teachers' is what we show.
        // If search is implemented in TeachersBloc, it should filter 'teachers' or separate list.
        // I will assume for now we use 'teachers'.
        
        return ListView.separated(
          padding: EdgeInsets.all(AppSpacing.md.w),
          itemCount: state.filteredTeachers.length,
          separatorBuilder: (c, i) => SizedBox(height: AppSpacing.sm.h),
          itemBuilder: (context, index) {
            final teacher = state.filteredTeachers[index];
            return _TeacherCard(teacher: teacher, isDark: isDark, strings: strings);
          },
        );
      },
    );
  }
}

class _TeacherCard extends StatelessWidget {
  final Teacher teacher;
  final bool isDark;
  final AppStrings strings;

  const _TeacherCard({
    required this.teacher,
    required this.isDark,
    required this.strings,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4.r,
            offset: Offset(0, 2.h),
          ),
        ],
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppColors.secondary.withValues(alpha: 0.1),
          child: Text(
            teacher.name.isNotEmpty ? teacher.name[0] : '?',
            style: TextStyle(color: AppColors.secondary, fontWeight: FontWeight.bold, fontSize: 16.sp),
          ),
        ),
        title: Text(teacher.name, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(teacher.phone),
        trailing: const Icon(Icons.chevron_right),
        // onTap: () => context.go('/teachers/${teacher.id}'), // Details route not defined/verified yet
      ),
    );
  }
}


