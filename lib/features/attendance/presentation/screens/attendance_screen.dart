import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/l10n/app_strings.dart';
import '../../../../core/utils/responsive_utils.dart';
import '../../../../core/providers/center_provider.dart';
import '../../../../shared/models/models.dart';
import '../../bloc/attendance_bloc.dart';
import '../../data/repositories/attendance_repository.dart';
import '../../../schedule/data/repositories/schedule_repository.dart';
import '../../../students/data/repositories/students_repository.dart';
import '../../../groups/data/repositories/groups_repository.dart';

/// شاشة الحضور الرئيسية
class AttendanceScreen extends StatelessWidget {
  const AttendanceScreen({super.key});

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
      create: (context) => AttendanceBloc(
        attendanceRepo: context.read<AttendanceRepository>(),
        scheduleRepo: context.read<ScheduleRepository>(),
        studentsRepo: context.read<StudentsRepository>(),
        groupsRepo: context.read<GroupsRepository>(),
      )..add(LoadAttendance()),
      child: const _AttendanceView(),
    );
  }
}

class _AttendanceView extends StatelessWidget {
  const _AttendanceView();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final padding = ResponsiveUtils.getPagePadding(context);
    final strings = AppStrings.of(context);

    return BlocBuilder<AttendanceBloc, AttendanceState>(
      builder: (context, state) {
        return RefreshIndicator(
          onRefresh: () async {
            context.read<AttendanceBloc>().add(LoadAttendance());
          },
          child: SingleChildScrollView(
            padding: padding,
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header with title and actions
                _buildHeader(context, isDark, strings, state),

                const SizedBox(height: AppSpacing.xl),

                // Stats Cards
                _buildStatsCards(context, isDark, state, strings),

                const SizedBox(height: AppSpacing.xl),

                // Attendance List
                if (state.status == AttendanceLoadingStatus.loading)
                   const Center(child: CircularProgressIndicator())
                else if (state.records.isEmpty)
                  _buildEmptyState(context, isDark, strings)
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: state.records.length,
                    separatorBuilder: (context, index) => const SizedBox(height: AppSpacing.md),
                    itemBuilder: (context, index) {
                      final record = state.records[index];
                      return _AttendanceRow(
                        key: ValueKey(record.id),
                        record: record,
                        isDark: isDark,
                        strings: strings,
                      );
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(BuildContext context, bool isDark, AppStrings strings) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xxxl),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          width: 0.5,
        ),
      ),
      child: Center(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.xl),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.event_note_rounded, size: 64, color: AppColors.primary),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              strings.noAttendanceRecords,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: isDark
                    ? AppColors.darkTextSecondary
                    : AppColors.lightTextSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Container(
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  onTap: () => context.go('/attendance/take'),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.xl,
                      vertical: AppSpacing.md,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.how_to_reg, color: Colors.white),
                        const SizedBox(width: AppSpacing.sm),
                        Text(
                          strings.takeAttendance,
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
          ],
        ),
      ),
    );
  }

  void _showEditDialog(BuildContext context, AttendanceRecord record, AppStrings strings) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(strings.edit),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: AttendanceStatus.values.map((status) {
            return ListTile(
              title: Text(_getStatusString(status, strings)),
              leading: Icon(_getStatusIconSimple(status)),
              onTap: () {
                context.read<AttendanceBloc>().add(
                  UpdateSavedAttendanceRecord(
                    id: record.id,
                    status: status,
                  ),
                );
                Navigator.pop(dialogContext);
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  String _getStatusString(AttendanceStatus status, AppStrings strings) {
    return switch (status) {
      AttendanceStatus.present => strings.present,
      AttendanceStatus.absent => strings.absent,
      AttendanceStatus.late => strings.late,
      AttendanceStatus.excused => strings.excused,
    };
  }

  IconData _getStatusIconSimple(AttendanceStatus status) {
    return switch (status) {
      AttendanceStatus.present => Icons.check_circle_outline,
      AttendanceStatus.absent => Icons.cancel_outlined,
      AttendanceStatus.late => Icons.schedule,
      AttendanceStatus.excused => Icons.info_outline,
    };
  }

  Widget _buildHeader(
    BuildContext context,
    bool isDark,
    AppStrings strings,
    AttendanceState state,
  ) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark 
            ? [const Color(0xFF1F2937), const Color(0xFF111827)]
            : [Colors.white, const Color(0xFFF9FAFB)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
        boxShadow: [
           BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                strings.attendance,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.calendar_today_rounded,
                      size: 14,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${state.selectedDate.day}/${state.selectedDate.month}/${state.selectedDate.year}',
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          Row(
            children: [
              // Date Picker
              Container(
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurface : Colors.white,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  border: Border.all(
                    color: isDark ? AppColors.darkBorder : AppColors.lightBorder, 
                    width: 1
                  ),
                ),
                child: IconButton(
                  onPressed: () => _selectDate(context, state.selectedDate),
                  icon: Icon(Icons.edit_calendar_rounded, 
                    color: isDark ? Colors.white70 : Colors.grey[700]),
                  tooltip: strings.selectDate,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              // Take Attendance Button
              Container(
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                    onTap: () => context.go('/attendance/take'),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.lg,
                        vertical: AppSpacing.md,
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.how_to_reg,
                            color: Colors.white,
                            size: 20,
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Text(
                            strings.takeAttendance,
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
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _selectDate(BuildContext context, DateTime currentDate) async {
    final date = await showDatePicker(
      context: context,
      initialDate: currentDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (date != null && context.mounted) {
      context.read<AttendanceBloc>().add(ChangeSelectedDate(date));
    }
  }

  Widget _buildStatsCards(
    BuildContext context,
    bool isDark,
    AttendanceState state,
    AppStrings strings,
  ) {
    final stats = [
      _StatItem(
        title: strings.present,
        value: state.presentCount.toString(),
        color: AppColors.success,
        icon: Icons.check_circle_rounded,
      ),
      _StatItem(
        title: strings.absent,
        value: state.absentCount.toString(),
        color: AppColors.error,
        icon: Icons.cancel_rounded,
      ),
      _StatItem(
        title: strings.late,
        value: state.lateCount.toString(),
        color: AppColors.warning,
        icon: Icons.access_time_filled_rounded,
      ),
      _StatItem(
        title: strings.excused,
        value: state.excusedCount.toString(),
        color: AppColors.info,
        icon: Icons.info_rounded,
      ),
      _StatItem(
        title: strings.attendanceRate,
        value: '${state.attendanceRate.toStringAsFixed(1)}%',
        color: AppColors.primary,
        icon: Icons.trending_up_rounded,
      ),
    ];

    return Row(
      children: stats
          .asMap()
          .entries
          .map(
            (entry) => Expanded(
              child: Padding(
                padding: EdgeInsets.only(
                  right: entry.key < stats.length - 1 ? AppSpacing.md : 0,
                ),
                child: _StatCard(stat: entry.value, isDark: isDark),
              ),
            ),
          )
          .toList(),
    );
  }
}

class _StatItem {
  final String title;
  final String value;
  final Color color;
  final IconData icon;

  const _StatItem({
    required this.title,
    required this.value,
    required this.color,
    required this.icon,
  });
}

class _StatCard extends StatelessWidget {
  final _StatItem stat;
  final bool isDark;

  const _StatCard({required this.stat, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border(
           top: BorderSide(color: stat.color, width: 3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                stat.title,
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Icon(stat.icon, color: stat.color, size: 20),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            stat.value,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}

class _AttendanceRow extends StatelessWidget {
  final AttendanceRecord record;
  final bool isDark;
  final AppStrings strings;

  const _AttendanceRow({
    super.key,
    required this.record,
    required this.isDark,
    required this.strings,
  });

  Color _getStatusColor() => switch (record.status) {
    AttendanceStatus.present => AppColors.success,
    AttendanceStatus.absent => AppColors.error,
    AttendanceStatus.late => AppColors.warning,
    AttendanceStatus.excused => AppColors.info,
  };

  String _getStatusText() => switch (record.status) {
    AttendanceStatus.present => strings.present,
    AttendanceStatus.absent => strings.absent,
    AttendanceStatus.late => strings.late,
    AttendanceStatus.excused => strings.excused,
  };

  @override
  Widget build(BuildContext context) {
    final statusColor = _getStatusColor();
    
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          width: 0.5,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            // Avatar
            CircleAvatar(
              radius: 20,
              backgroundColor: AppColors.primary.withValues(alpha: 0.1),
              child: Text(
                record.studentName.isNotEmpty ? record.studentName[0] : '?',
                style: const TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
            const SizedBox(width: 16),
            
            // Name & Info
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    record.studentName,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                   if (record.checkInTime != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Row(
                        children: [
                           Icon(Icons.access_time, size: 12, color: isDark ? Colors.white54 : Colors.grey[500]),
                           const SizedBox(width: 4),
                           Text(
                            '${record.checkInTime!.hour.toString().padLeft(2, '0')}:${record.checkInTime!.minute.toString().padLeft(2, '0')}',
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
                ],
              ),
            ),

            // Status Badge
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 6,
              ),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                border: Border.all(color: statusColor.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  Icon(
                     _getStatusIcon(record.status),
                     size: 14,
                     color: statusColor,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _getStatusText(),
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),

            // Actions
            Material(
              color: Colors.transparent,
              child: PopupMenuButton<String>(
                icon: Icon(
                  Icons.more_vert,
                  color: isDark
                      ? AppColors.darkTextSecondary
                      : AppColors.lightTextSecondary,
                ),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                onSelected: (value) {
                  if (value == 'edit') {
                    // TODO: Edit
                  } else if (value == 'delete') {
                    context.read<AttendanceBloc>().add(
                      DeleteAttendanceRecord(record.id),
                    );
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'edit', 
                    child: Row(
                      children: [
                        const Icon(Icons.edit_outlined, size: 18),
                        const SizedBox(width: 8),
                        Text(strings.edit),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        const Icon(Icons.delete_outline, size: 18, color: AppColors.error),
                        const SizedBox(width: 8),
                        Text(
                          strings.delete,
                          style: const TextStyle(color: AppColors.error),
                        ),
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

  IconData _getStatusIcon(AttendanceStatus status) {
     switch (status) {
      case AttendanceStatus.present: return Icons.check_circle_outline;
      case AttendanceStatus.absent: return Icons.cancel_outlined;
      case AttendanceStatus.late: return Icons.schedule;
      case AttendanceStatus.excused: return Icons.info_outline;
    }
  }
}


