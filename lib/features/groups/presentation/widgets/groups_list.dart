import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/l10n/app_strings.dart';
import '../../../../shared/models/models.dart';
import '../../bloc/groups_bloc.dart';

class GroupsList extends StatelessWidget {
  final bool isDark;
  final AppStrings strings;

  const GroupsList({
    super.key,
    required this.isDark,
    required this.strings,
  });

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<GroupsBloc, GroupsState>(
      builder: (context, state) {
        if (state.status == GroupsStatus.loading) {
          return const Center(child: CircularProgressIndicator());
        }

        if (state.filteredGroups.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.search_off, size: 64, color: isDark ? Colors.grey : Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  strings.noGroups,
                  style: TextStyle(color: isDark ? Colors.grey : Colors.grey[600]),
                ),
              ],
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(AppSpacing.md),
          itemCount: state.filteredGroups.length,
          separatorBuilder: (c, i) => const SizedBox(height: AppSpacing.sm),
          itemBuilder: (context, index) {
            final group = state.filteredGroups[index];
            return _GroupCard(group: group, isDark: isDark, strings: strings);
          },
        );
      },
    );
  }
}

class _GroupCard extends StatelessWidget {
  final Group group;
  final bool isDark;
  final AppStrings strings;

  const _GroupCard({
    required this.group,
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
          backgroundColor: Colors.blue.withValues(alpha: 0.1),
          child: Icon(Icons.groups, color: Colors.blue),
        ),
        title: Text(group.groupName, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(
          '${group.courseName ?? 'بدون مادة'} • ${group.teacherName ?? 'بدون معلم'}\n${group.scheduleText}',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        isThreeLine: true,
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '${group.currentStudents}/${group.maxStudents}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Icon(Icons.chevron_right, size: 16, color: Colors.grey),
          ],
        ),
        // onTap: () => context.go('/groups/${group.id}'), // Route not defined yet
      ),
    );
  }
}


