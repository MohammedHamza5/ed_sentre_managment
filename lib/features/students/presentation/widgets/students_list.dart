import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/l10n/app_strings.dart';
import '../../../../shared/models/models.dart';
import '../../bloc/students_bloc.dart';

class StudentsList extends StatelessWidget {
  final bool isDark;
  final AppStrings strings;

  const StudentsList({
    super.key,
    required this.isDark,
    required this.strings,
  });

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<StudentsBloc, StudentsState>(
      builder: (context, state) {
        if (state.status == StudentsStatus.loading) {
          return const Center(child: CircularProgressIndicator());
        }
        
        if (state.filteredStudents.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.search_off, size: 64, color: isDark ? Colors.grey : Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  strings.noStudents,
                  style: TextStyle(color: isDark ? Colors.grey : Colors.grey[600]),
                ),
              ],
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(AppSpacing.md),
          itemCount: state.filteredStudents.length,
          separatorBuilder: (c, i) => const SizedBox(height: AppSpacing.sm),
          itemBuilder: (context, index) {
            final student = state.filteredStudents[index];
            return _StudentCard(student: student, isDark: isDark, strings: strings);
          },
        );
      },
    );
  }
}

class _StudentCard extends StatelessWidget {
  final Student student;
  final bool isDark;
  final AppStrings strings;

  const _StudentCard({
    required this.student,
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
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppColors.primary.withValues(alpha: 0.1),
          child: Text(
            student.name.isNotEmpty ? student.name[0] : '?',
            style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold),
          ),
        ),
        title: Text(student.name, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text('${student.stage} • ${student.phone}'),
        trailing: _StatusBadge(status: student.status, strings: strings),
        onTap: () => context.go('/students/${student.id}'),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final StudentStatus status;
  final AppStrings strings;

  const _StatusBadge({required this.status, required this.strings});

  @override
  Widget build(BuildContext context) {
    Color color;
    String text;

    switch (status) {
      case StudentStatus.active:
        color = AppColors.success;
        text = strings.active;
        break;
      case StudentStatus.suspended:
        color = AppColors.warning;
        text = strings.suspended;
        break;
      case StudentStatus.overdue:
        color = AppColors.error;
        text = strings.overdue;
        break;
      case StudentStatus.inactive:
        color = Colors.grey;
        text = strings.inactive;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Text(
        text,
        style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold),
      ),
    );
  }
}


