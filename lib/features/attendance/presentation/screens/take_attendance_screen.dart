import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/l10n/app_strings.dart';
import '../../../../core/providers/center_provider.dart';
import '../../data/repositories/attendance_repository.dart';
import '../../../../features/schedule/data/repositories/schedule_repository.dart';
import '../../../../features/students/data/repositories/students_repository.dart';
import '../../../../features/groups/data/repositories/groups_repository.dart';
import '../../../../shared/models/models.dart';
import '../../../../shared/widgets/buttons/app_button.dart';
import '../../bloc/attendance_bloc.dart';

class TakeAttendanceScreen extends StatelessWidget {
  const TakeAttendanceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => AttendanceBloc(
        attendanceRepo: context.read<AttendanceRepository>(),
        scheduleRepo: context.read<ScheduleRepository>(),
        studentsRepo: context.read<StudentsRepository>(),
        groupsRepo: context.read<GroupsRepository>(),
      )..add(SetAttendanceContext(date: DateTime.now())),
      child: const _TakeAttendanceContent(),
    );
  }
}

class _TakeAttendanceContent extends StatelessWidget {
  const _TakeAttendanceContent();

  @override
  Widget build(BuildContext context) {
    // ✅ BlocConsumer يفصل بين:
    //    - listener: للـ side effects (SnackBar، Navigation) — يُشغَّل مرة واحدة
    //    - builder:  لبناء الـ UI — يُعاد بناؤه عند كل تغيير في الـ state
    return BlocConsumer<AttendanceBloc, AttendanceState>(
      // listenWhen يضمن تشغيل الـ listener فقط عند تغيير الـ step أو errorMessage
      listenWhen: (previous, current) =>
          previous.step != current.step ||
          previous.errorMessage != current.errorMessage,
      listener: (context, state) {
        final strings = AppStrings.of(context);

        if (state.step == AttendanceStep.success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(strings.attendanceSaved),
              backgroundColor: AppColors.success,
            ),
          );
          context.go('/attendance');
        }

        if (state.errorMessage != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.errorMessage!),
              backgroundColor: AppColors.error,
            ),
          );
        }
      },
      builder: (context, state) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final strings = AppStrings.of(context);

        return Scaffold(
          appBar: AppBar(
            title: Text(strings.takeAttendance),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: () {
                  context.read<AttendanceBloc>().add(
                    SetAttendanceContext(date: state.selectedDate),
                  );
                },
              ),
            ],
          ),
          body: Column(
            children: [
              // 1. Context Section (Date & Session)
              _buildContextCard(context, state, strings, isDark),

              // 2. Stats Summary (Only if marking)
              if (state.step == AttendanceStep.marking)
                _buildStatsBar(context, state, isDark),

              // 3. Main Content (Session Selector OR Student List)
              Expanded(
                  child: _buildMainContent(context, state, strings, isDark)),

              // 4. Floating Action / Bottom Bar for Submit
              if (state.step == AttendanceStep.marking)
                _buildBottomBar(context, state, strings),
            ],
          ),
        );
      },
    );
  }

  Widget _buildContextCard(
    BuildContext context,
    AttendanceState state,
    AppStrings strings,
    bool isDark,
  ) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.darkSurfaceVariant
            : AppColors.lightSurfaceVariant,
        border: Border(
          bottom: BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
        ),
      ),
      child: Column(
        children: [
          // Date Picker Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_ios, size: 16),
                onPressed: () {
                  final newDate = state.selectedDate.subtract(
                    const Duration(days: 1),
                  );
                  context.read<AttendanceBloc>().add(
                    SetAttendanceContext(date: newDate),
                  );
                },
              ),
              GestureDetector(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: state.selectedDate,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2030),
                  );
                  if (picked != null) {
                    context.read<AttendanceBloc>().add(
                      SetAttendanceContext(date: picked),
                    );
                  }
                },
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      "${state.selectedDate.day}/${state.selectedDate.month}/${state.selectedDate.year}",
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    if (isToday(state.selectedDate))
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 8),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          strings.today,
                          style: const TextStyle(
                            fontSize: 10,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.arrow_forward_ios, size: 16),
                onPressed: () {
                  final newDate = state.selectedDate.add(
                    const Duration(days: 1),
                  );
                  context.read<AttendanceBloc>().add(
                    SetAttendanceContext(date: newDate),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  bool isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }

  Widget _buildStatsBar(
    BuildContext context,
    AttendanceState state,
    bool isDark,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      color: isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF5F5F5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem('✅ ${state.presentCount}', Colors.green),
          _buildStatItem('❌ ${state.absentCount}', Colors.red),
          _buildStatItem('⏳ ${state.lateCount}', Colors.orange),
        ],
      ),
    );
  }

  Widget _buildStatItem(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        text,
        style: TextStyle(color: color, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildMainContent(
    BuildContext context,
    AttendanceState state,
    AppStrings strings,
    bool isDark,
  ) {
    // LOADING
    if (state.step == AttendanceStep.submitting) {
      return const Center(child: CircularProgressIndicator());
    }

    // LIST EMPTY (No Sessions)
    if (state.availableSessions.isEmpty &&
        state.step == AttendanceStep.selectingContext) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.event_busy, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              strings.noSessionsToday,
              style: TextStyle(color: Colors.grey[600], fontSize: 16),
            ),
          ],
        ),
      );
    }

    // SELECT SESSION
    if (state.step == AttendanceStep.selectingContext ||
        state.step == AttendanceStep.selectingSession) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            strings.selectSession,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          const SizedBox(height: 16),
          ...state.availableSessions.map(
            (session) => GestureDetector(
              onTap: () =>
                  context.read<AttendanceBloc>().add(SelectSession(session)),
              child: Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurface : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: state.selectedSession?.id == session.id
                        ? AppColors.primary
                        : Colors.grey.withValues(alpha: 0.2),
                    width: state.selectedSession?.id == session.id ? 2 : 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 4,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          session.subjectName,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          "${session.startTime} - ${session.roomName}",
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    if (state.step == AttendanceStep.selectingSession &&
                        state.selectedSession?.id == session.id)
                      const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    else
                      const Icon(
                        Icons.arrow_forward_ios,
                        size: 16,
                        color: Colors.grey,
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      );
    }

    // MARKING
    if (state.step == AttendanceStep.marking) {
      if (state.students.isEmpty) {
        return Center(child: Text(strings.noStudents));
      }
      return Column(
        children: [
          // Quick Actions
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                TextButton.icon(
                  icon: const Icon(Icons.check_circle_outline, size: 16),
                  label: Text(strings.markAllPresent),
                  onPressed: () => context.read<AttendanceBloc>().add(
                    const MarkAllStudents(AttendanceStatus.present),
                  ),
                ),
                const Spacer(),
                TextButton.icon(
                  icon: const Icon(
                    Icons.cancel_outlined,
                    size: 16,
                    color: Colors.red,
                  ),
                  label: Text(
                    strings.markAllAbsent,
                    style: const TextStyle(color: Colors.red),
                  ),
                  onPressed: () => context.read<AttendanceBloc>().add(
                    const MarkAllStudents(AttendanceStatus.absent),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.only(bottom: 100),
              itemCount: state.students.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final student = state.students[index];
                final status = state.attendanceMap[student.id];
                return _StudentRow(
                  student: student,
                  status: status,
                  strings: strings,
                  onStatusChanged: (s) => context.read<AttendanceBloc>().add(
                    UpdateStudentStatus(student.id, s),
                  ),
                );
              },
            ),
          ),
        ],
      );
    }

    return const SizedBox();
  }

  Widget _buildBottomBar(
    BuildContext context,
    AttendanceState state,
    AppStrings strings,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: AppButton(
        text: strings.saveAttendance,
        icon: Icons.save,
        isLoading: state.step == AttendanceStep.submitting,
        onPressed: state.canSubmit
            ? () => context.read<AttendanceBloc>().add(SubmitAttendance())
            : null,
      ),
    );
  }
}

class _StudentRow extends StatelessWidget {
  final Student student;
  final AttendanceStatus? status;
  final AppStrings strings;
  final ValueChanged<AttendanceStatus> onStatusChanged;

  const _StudentRow({
    required this.student,
    required this.status,
    required this.strings,
    required this.onStatusChanged,
  });

  @override
  Widget build(BuildContext context) {
    // جلب إعدادات نظام الدفع
    final centerProvider = context.watch<CenterProvider>();
    final billingConfig = centerProvider.billingConfig;
    final isPerSession = billingConfig.isPerSession;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          CircleAvatar(child: Text(student.name[0])),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  student.name,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                // عرض حالة الدفع إذا كان النظام بالحصة
                if (isPerSession) _BillingStatusBadge(studentId: student.id),
              ],
            ),
          ),
          _StatusChip(
            icon: Icons.check,
            color: Colors.green,
            isSelected: status == AttendanceStatus.present,
            onTap: () => onStatusChanged(AttendanceStatus.present),
          ),
          const SizedBox(width: 8),
          _StatusChip(
            icon: Icons.close,
            color: Colors.red,
            isSelected: status == AttendanceStatus.absent,
            onTap: () => onStatusChanged(AttendanceStatus.absent),
          ),
          const SizedBox(width: 8),
          _StatusChip(
            icon: Icons.access_time,
            color: Colors.orange,
            isSelected: status == AttendanceStatus.late,
            onTap: () => onStatusChanged(AttendanceStatus.late),
          ),
        ],
      ),
    );
  }
}

// Widget لعرض حالة الدفع للطالب
class _BillingStatusBadge extends StatelessWidget {
  final String studentId;

  const _BillingStatusBadge({required this.studentId});

  @override
  Widget build(BuildContext context) {
    // TODO: جلب حالة الدفع الفعلية من القاعدة
    // للآن سنعرض placeholder
    final centerProvider = context.watch<CenterProvider>();
    final graceSessions = centerProvider.graceSessions;
    final maxDebt = centerProvider.maxDebtSessions;

    // Mock data - سيتم استبداله ببيانات حقيقية
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.blue.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.confirmation_number,
                size: 12,
                color: Colors.blue.shade700,
              ),
              const SizedBox(width: 4),
              Text(
                'رصيد: --',
                style: TextStyle(fontSize: 10, color: Colors.blue.shade700),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StatusChip extends StatelessWidget {
  final IconData icon;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  const _StatusChip({
    required this.icon,
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isSelected ? color : Colors.transparent,
          shape: BoxShape.circle,
          border: Border.all(
            color: isSelected ? color : Colors.grey.withValues(alpha: 0.3),
          ),
        ),
        child: Icon(
          icon,
          color: isSelected ? Colors.white : Colors.grey,
          size: 20,
        ),
      ),
    );
  }
}
