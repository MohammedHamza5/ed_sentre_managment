import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_spacing.dart';
import '../../../../core/constants/educational_consts.dart';
import '../../../../core/l10n/app_strings.dart';
import '../../../../core/utils/responsive_utils.dart';
import '../../../../core/providers/center_provider.dart';
import '../../../../shared/models/models.dart';
import '../../logic/schedule_validator.dart';
import '../../bloc/schedule_bloc.dart';
import '../../../../shared/models/group_models.dart'; // Ensure Group models are imported
import '../../data/repositories/schedule_repository.dart';
import '../../../groups/data/repositories/groups_repository.dart'; // Added missing import
import '../../../subjects/data/repositories/subjects_repository.dart';
import '../../../teachers/data/repositories/teachers_repository.dart';
import '../../../rooms/data/repositories/rooms_repository.dart';

// 🎨 Premium Color Palette for Subjects
class SubjectColors {
  static const List<Color> palette = [
    Color(0xFF6366F1), // Indigo
    Color(0xFFEC4899), // Pink
    Color(0xFF14B8A6), // Teal
    Color(0xFFF59E0B), // Amber
    Color(0xFF8B5CF6), // Violet
    Color(0xFF06B6D4), // Cyan
    Color(0xFFEF4444), // Red
    Color(0xFF10B981), // Emerald
    Color(0xFFF97316), // Orange
    Color(0xFF3B82F6), // Blue
    Color(0xFFA855F7), // Purple
    Color(0xFF84CC16), // Lime
  ];

  static Color getColor(String subjectId) {
    final hash = subjectId.hashCode.abs();
    return palette[hash % palette.length];
  }

  static Color getColorDark(String subjectId) {
    final color = getColor(subjectId);
    return HSLColor.fromColor(color).withLightness(0.35).toColor();
  }

  static Color getColorLight(String subjectId) {
    final color = getColor(subjectId);
    return HSLColor.fromColor(color).withLightness(0.85).toColor();
  }
}

/// شاشة إدارة الجداول - Enhanced Version
class ScheduleScreen extends StatelessWidget {
  const ScheduleScreen({super.key});

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
      create: (context) => ScheduleBloc(
        scheduleRepo: context.read<ScheduleRepository>(),
        subjectsRepo: context.read<SubjectsRepository>(),
        teachersRepo: context.read<TeachersRepository>(),
        roomsRepo: context.read<RoomsRepository>(),
        groupsRepo: context.read<GroupsRepository>(),
      )..add(const LoadSchedule()),
      child: const _ScheduleView(),
    );
  }
}

class _ScheduleView extends StatefulWidget {
  const _ScheduleView();

  @override
  State<_ScheduleView> createState() => _ScheduleViewState();
}

class _ScheduleViewState extends State<_ScheduleView> {
  int _currentWeekOffset = 0;
  String? _selectedGradeLevel; // For filtering

  final List<String> _timeSlots = [
    '08:00',
    '09:00',
    '10:00',
    '11:00',
    '12:00',
    '13:00',
    '14:00',
    '15:00',
    '16:00',
    '17:00',
    '18:00',
    '19:00',
    '20:00',
    '21:00',
    '22:00',
  ];

  String _getWeekRange() {
    final now = DateTime.now();
    // 0=Sat, 1=Sun, ..., 5=Thu, 6=Fri
    final daysFromSat = (now.weekday + 1) % 7;
    final startOfWeek = now
        .subtract(Duration(days: daysFromSat))
        .add(Duration(days: _currentWeekOffset * 7));
    final endOfWeek = startOfWeek.add(const Duration(days: 5));
    return '${startOfWeek.day}/${startOfWeek.month} - ${endOfWeek.day}/${endOfWeek.month}';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final padding = ResponsiveUtils.getPagePadding(context);
    final strings = AppStrings.of(context);
    final days = strings.daysList;

    return BlocListener<ScheduleBloc, ScheduleState>(
      listener: (context, state) {
        if (state.status == ScheduleStatus.failure) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.errorMessage ?? strings.errorOccurred),
              backgroundColor: AppColors.error,
            ),
          );
        }
      },
      child: BlocBuilder<ScheduleBloc, ScheduleState>(
        builder: (context, state) {
          if (state.status == ScheduleStatus.loading) {
            return const Center(child: CircularProgressIndicator());
          }

          final sessions = state.sessions;

          // Filter Logic
          final gradeLevels = sessions
              .map((s) => s.gradeLevel)
              .where((l) => l != null && l.isNotEmpty)
              .toSet()
              .toList();
          gradeLevels.sort();

          final filteredSessions = _selectedGradeLevel == null
              ? sessions
              : sessions
                    .where((s) => s.gradeLevel == _selectedGradeLevel)
                    .toList();

          return RefreshIndicator(
            onRefresh: () async {
              // Force refresh to get latest data from backend
              context.read<ScheduleBloc>().add(
                const LoadSchedule(forceRefresh: true),
              );
            },
            child: SingleChildScrollView(
              padding: padding,
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Modern Header Card
                  _buildModernHeader(context, isDark, strings, state),

                  const SizedBox(height: AppSpacing.lg),

                  // Grade Level Filter Chips
                  if (gradeLevels.isNotEmpty)
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildFilterChip(context, 'الكل', null, isDark),
                          const SizedBox(width: 8),
                          ...gradeLevels.map(
                            (level) => Padding(
                              padding: const EdgeInsets.only(right: 8.0),
                              child: _buildFilterChip(
                                context,
                                level!,
                                level,
                                isDark,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                  const SizedBox(height: AppSpacing.md),

                  // Full-width Schedule Grid
                  _buildModernScheduleGrid(
                    context,
                    isDark,
                    strings,
                    days,
                    filteredSessions, // Use filtered list
                    state.subjects,
                  ),

                  // Subject Legend with Colors
                  const SizedBox(height: AppSpacing.lg),
                  _buildSubjectLegend(state.subjects, isDark),
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
    ScheduleState state,
  ) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF667EEA).withValues(alpha: 0.4),
            blurRadius: 25,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.calendar_month_rounded,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        strings.sessionSchedule,
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${state.sessions.length} ${strings.isArabic ? 'حصة مجدولة' : 'Sessions'}',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.9),
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          Row(
            children: [
              // Week Navigation
              Container(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.2),
                  ),
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(
                        Icons.chevron_right,
                        color: Colors.white,
                      ),
                      onPressed: () => setState(() => _currentWeekOffset--),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'الأسبوع',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 10,
                            ),
                          ),
                          Text(
                            _getWeekRange(),
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.chevron_left, color: Colors.white),
                      onPressed: () => setState(() => _currentWeekOffset++),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.lg),
              // Add Session Button
              _buildAddButton(strings, state),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(
    BuildContext context,
    String label,
    String? value,
    bool isDark,
  ) {
    final isSelected = _selectedGradeLevel == value;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _selectedGradeLevel = selected ? value : null;
        });
      },
      selectedColor: const Color(0xFF667EEA),
      labelStyle: TextStyle(
        color: isSelected
            ? Colors.white
            : (isDark ? Colors.white70 : Colors.black87),
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      backgroundColor: isDark
          ? Colors.white.withValues(alpha: 0.05)
          : Colors.grey[200],
      side: BorderSide.none,
      checkmarkColor: Colors.white,
    );
  }

  Widget _buildAddButton(AppStrings strings, ScheduleState state) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      elevation: 4,
      shadowColor: Colors.black26,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        onTap: () => _showAddSessionDialog(
          strings,
          state,
          initialGradeLevel: _selectedGradeLevel, // Smart default
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.add_rounded,
                  color: Colors.white,
                  size: 18,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                strings.addSession,
                style: const TextStyle(
                  color: Color(0xFF667EEA),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModernScheduleGrid(
    BuildContext context,
    bool isDark,
    AppStrings strings,
    List<String> days,
    List<ScheduleSession> sessions,
    List<Subject> subjects,
  ) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header Row
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.md,
            ),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark
                    ? [const Color(0xFF2D2D3A), const Color(0xFF1F1F2E)]
                    : [const Color(0xFFF8FAFC), const Color(0xFFEDF2F7)],
              ),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(AppSpacing.radiusXl),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 70,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.access_time_rounded,
                        size: 14,
                        color: isDark ? Colors.white60 : Colors.grey[600],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        strings.time,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                          color: isDark ? Colors.white70 : Colors.grey[700],
                        ),
                      ),
                    ],
                  ),
                ),
                ...days.asMap().entries.map(
                  (entry) => Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Column(
                        children: [
                          Text(
                            entry.value,
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                              color: isDark ? Colors.white : Colors.grey[800],
                            ),
                          ),
                          const SizedBox(height: 2),
                          Container(
                            width: 24,
                            height: 3,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  SubjectColors.palette[entry.key %
                                      SubjectColors.palette.length],
                                  SubjectColors.palette[(entry.key + 1) %
                                      SubjectColors.palette.length],
                                ],
                              ),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Time Slots
          ..._timeSlots.map(
            (time) => Container(
              padding: const EdgeInsets.symmetric(
                vertical: AppSpacing.xs,
                horizontal: AppSpacing.lg,
              ),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: isDark
                        ? AppColors.darkBorder.withValues(alpha: 0.3)
                        : AppColors.lightBorder.withValues(alpha: 0.5),
                    width: 0.5,
                  ),
                ),
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 70,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.05)
                            : Colors.grey.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        time,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? AppColors.darkTextSecondary
                              : Colors.grey[700],
                        ),
                      ),
                    ),
                  ),
                  ...days.asMap().entries.map((entry) {
                    final dayIndex = entry.key;
                    // Find all sessions starting in this hour (e.g., 08:xx)
                    final cellSessions = sessions.where((s) {
                      if (s.dayOfWeek != dayIndex) return false;
                      final sessionHour =
                          int.tryParse(s.startTime.split(':')[0]) ?? -1;
                      final slotHour = int.tryParse(time.split(':')[0]) ?? -1;
                      return sessionHour == slotHour;
                    }).toList();

                    return Expanded(
                      child: _buildSessionCell(
                        context,
                        isDark,
                        strings,
                        cellSessions,
                        dayIndex,
                        time,
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),

          const SizedBox(height: AppSpacing.sm),
        ],
      ),
    );
  }

  Widget _buildSessionCell(
    BuildContext context,
    bool isDark,
    AppStrings strings,
    List<ScheduleSession> cellSessions,
    int dayIndex,
    String time,
  ) {
    final state = context.read<ScheduleBloc>().state;

    if (cellSessions.isEmpty) {
      // Empty cell
      return GestureDetector(
        onTap: () {
          _showAddSessionDialog(
            strings,
            state,
            dayIndex: dayIndex,
            startTime: time,
            initialGradeLevel: _selectedGradeLevel, // Smart default
          );
        },
        child: Container(
          margin: const EdgeInsets.all(4),
          height: 85,
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withValues(alpha: 0.03)
                : Colors.grey.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.05)
                  : Colors.grey.withValues(alpha: 0.15),
              width: 1.5,
              strokeAlign: BorderSide.strokeAlignInside,
            ),
          ),
          child: Center(
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.05)
                    : Colors.grey.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.add_rounded,
                size: 18,
                color: isDark
                    ? Colors.white.withValues(alpha: 0.3)
                    : Colors.grey.withValues(alpha: 0.5),
              ),
            ),
          ),
        ),
      );
    }

    // Session cell with subject color
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: cellSessions.map((session) {
        debugPrint('🎨 [UI] Building card for session: ${session.id}');
        debugPrint('   -> Subject: ${session.subjectName}');
        debugPrint('   -> Status: ${session.status}');

        final isCancelled = session.status == SessionStatus.cancelled;
        debugPrint('   -> Is Cancelled: $isCancelled');

        final subjectColor = isCancelled
            ? Colors.grey
            : SubjectColors.getColor(session.subjectId);

        return GestureDetector(
          onTap: () => _showSessionDetails(session, strings),
          child: Container(
            margin: const EdgeInsets.only(bottom: 4, left: 2, right: 2),
            height: 85,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isCancelled
                    ? [Colors.grey[700]!, Colors.grey[600]!]
                    : [subjectColor, subjectColor.withValues(alpha: 0.85)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: subjectColor.withValues(
                    alpha: isCancelled ? 0.1 : 0.4,
                  ),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Stack(
              children: [
                // Decorative pattern
                if (!isCancelled)
                  Positioned(
                    right: -20,
                    top: -20,
                    child: Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.1),
                      ),
                    ),
                  ),
                // Content
                // Content
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Header: Subject + Time
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                session.subjectName,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                  decoration: isCancelled
                                      ? TextDecoration.lineThrough
                                      : null,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                          if (isCancelled)
                            const Icon(
                              Icons.cancel_outlined,
                              color: Colors.white70,
                              size: 14,
                            ),
                        ],
                      ),
                      const SizedBox(height: 2),

                      // Teacher & Grade
                      Row(
                        children: [
                          Icon(
                            Icons.person_outline_rounded,
                            size: 11,
                            color: Colors.white.withValues(alpha: 0.9),
                          ),
                          const SizedBox(width: 2),
                          Expanded(
                            child: Text(
                              session.teacherName,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                                color: Colors.white.withValues(alpha: 0.95),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 2),

                      // Room & Grade Level Badge
                      Row(
                        children: [
                          // Grade Level Badge
                          if (session.gradeLevel != null) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 1,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(3),
                              ),
                              child: Text(
                                session.gradeLevel!,
                                style: const TextStyle(
                                  fontSize: 9,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                          ],

                          Icon(
                            Icons.door_back_door_outlined,
                            size: 11,
                            color: Colors.white.withValues(alpha: 0.8),
                          ),
                          const SizedBox(width: 2),
                          Flexible(
                            child: Text(
                              session.roomName,
                              style: TextStyle(
                                fontSize: 9,
                                color: Colors.white.withValues(alpha: 0.85),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 2),
                      // Time Badge
                      Row(
                        children: [
                          Icon(
                            Icons.access_time_filled,
                            size: 10,
                            color: Colors.white.withValues(alpha: 0.9),
                          ),
                          const SizedBox(width: 2),
                          Text(
                            '${_formatTime(session.startTime)} - ${_formatTime(session.endTime)}',
                            style: const TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
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
        );
      }).toList(),
    );
  }

  String _getDurationString(String start, String end, AppStrings strings) {
    try {
      final startParts = start.split(':');
      final endParts = end.split(':');

      final startMinutes =
          int.parse(startParts[0]) * 60 + int.parse(startParts[1]);
      final endMinutes = int.parse(endParts[0]) * 60 + int.parse(endParts[1]);

      final diffMinutes = endMinutes - startMinutes;
      final hours = diffMinutes / 60;

      if (!strings.isArabic) {
        return '${hours.toString().replaceAll(".0", "")}h';
      }

      // Arabic Localization
      if (hours == 1) return 'ساعة';
      if (hours == 2) return 'ساعتين';
      if (hours >= 3 && hours <= 10) return '${hours.toInt()} ساعات';
      return '${hours.toString().replaceAll(".0", "")} ساعة';
    } catch (e) {
      return '';
    }
  }

  Widget _buildSubjectLegend(List<Subject> subjects, bool isDark) {
    if (subjects.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.palette_outlined,
                size: 18,
                color: isDark ? Colors.white70 : Colors.grey[600],
              ),
              const SizedBox(width: 8),
              Text(
                'دليل المواد',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: isDark ? Colors.white : Colors.grey[800],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.md,
            runSpacing: AppSpacing.sm,
            children: subjects.map((subject) {
              final color = SubjectColors.getColor(subject.id);
              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: color.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: color.withValues(alpha: 0.4),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      subject.name,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: isDark ? Colors.white : Colors.grey[800],
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  String _formatTime(String time) {
    if (time.isEmpty) return '';
    try {
      final parts = time.split(':');
      final hour = int.parse(parts[0]);
      // final minute = int.parse(parts[1]); // Unused
      final h = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
      final p = hour >= 12 ? 'م' : 'ص';
      return '$h:${parts[1]} $p';
    } catch (e) {
      return time;
    }
  }

  void _showAddSessionDialog(
    AppStrings strings,
    ScheduleState state, {
    int? dayIndex,
    String? startTime,
    String? initialGradeLevel, // Smart default
  }) {
    final scheduleBloc = context.read<ScheduleBloc>();
    String? selectedSubject;
    String? selectedTeacher;
    String? selectedRoom;
    String? selectedGroupId; // New
    final TextEditingController newGroupNameController =
        TextEditingController(); // New
    bool isCreatingNewGroup = false; // New
    int selectedDay = dayIndex ?? 0;
    String selectedTime = startTime ?? '08:00';
    double selectedDuration = 2.0;
    String? selectedGradeLevel =
        initialGradeLevel; // Initialize with smart default
    final days = strings.daysList;

    // Ensure we have data
    if (state.subjects.isEmpty || state.rooms.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            strings.isArabic
                ? 'الرجاء إضافة مواد وقاعات أولاً'
                : 'Please add Subjects and Rooms first',
          ),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    // Ensure valid time
    if (!_timeSlots.contains(selectedTime)) {
      selectedTime = _timeSlots.first;
    }

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) {
          // 🔍 Filter Teachers based on selected Subject
          List<Teacher> filteredTeachers = state.teachers;
          if (selectedSubject != null) {
            // Find valid teachers for this subject
            filteredTeachers = state.teachers.where((t) {
              return t.subjectIds.contains(selectedSubject);
            }).toList();

            // If selectedTeacher is no longer valid, reset it
            if (selectedTeacher != null &&
                !filteredTeachers.any((t) => t.id == selectedTeacher)) {
              // Defer setState not allowed during build?
              // Actually this logic runs during build. We should avoid side-effects here?
              // But selectedTeacher is local state variable. It's fine to check legality.
              // However, DropdownButton will crash if value is not in items.
              // So we must ensure `selectedTeacher` is null if it's not in `filteredTeachers`.

              // Better to do this in onChanged. But initial state might be inconsistent?
              // No, initially everything is null.
              // When selectedSubject changes, we reset selectedTeacher in onChanged.
            }
          }

          // 🔍 Filter Subjects based on selected Teacher
          List<Subject> filteredSubjects = state.subjects;
          if (selectedTeacher != null) {
            final teacher = state.teachers.firstWhere(
              (t) => t.id == selectedTeacher,
              orElse: () => state.teachers.first,
            );
            if (state.teachers.any((t) => t.id == selectedTeacher)) {
              filteredSubjects = state.subjects
                  .where((s) => teacher.subjectIds.contains(s.id))
                  .toList();
            }
          }

          // 🔍 Filter Groups based on selection
          // Only show active groups that match the subject/teacher if selected
          List<Group> filteredGroups = state.groups.where((g) {
            if (g.status != GroupStatus.active && g.status != GroupStatus.full)
              return false;

            bool matchesSubject =
                selectedSubject == null || g.courseId == selectedSubject;
            bool matchesTeacher =
                selectedTeacher == null || g.teacherId == selectedTeacher;

            return matchesSubject && matchesTeacher;
          }).toList();

          if (selectedGradeLevel != null) {
            filteredGroups = filteredGroups
                .where((g) => g.gradeLevel == selectedGradeLevel)
                .toList();
          }

          // Ensure selectedGroupId is valid (Fix for Crash)
          if (selectedGroupId != null && selectedGroupId != 'NEW_GROUP') {
            if (!filteredGroups.any((g) => g.id == selectedGroupId)) {
              // If currently selected group is not in filtered list, we must treat it as null for the Dropdown
              // But we can't change state during build.
              // We can just pass null to value in DropdownButtonFormField.
              // But better to handle this via state reset in onChanged of parent fields.
            }
          }

          // Auto-generate group name if creating new
          if (isCreatingNewGroup &&
              newGroupNameController.text.isEmpty &&
              selectedSubject != null) {
            final subjectName = state.subjects
                .firstWhere(
                  (s) => s.id == selectedSubject,
                  orElse: () => state.subjects.first,
                )
                .name;
            final grade = selectedGradeLevel ?? '';
            newGroupNameController.text = '$subjectName - $grade';
          }

          // Get selected subject color
          final subjectColor = selectedSubject != null
              ? SubjectColors.getColor(selectedSubject!)
              : const Color(0xFF667EEA);

          return Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 450),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header with gradient
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            subjectColor,
                            subjectColor.withValues(alpha: 0.8),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(20),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.event_note_rounded,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  strings.addSession,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                Text(
                                  '${days[selectedDay]} - ${_formatTime(selectedTime)}',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.white.withValues(alpha: 0.9),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.pop(dialogContext),
                            icon: const Icon(
                              Icons.close_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Form Content
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          // Day & Time Row
                          Row(
                            children: [
                              Expanded(
                                child: DropdownButtonFormField<int>(
                                  value: selectedDay,
                                  decoration: InputDecoration(
                                    labelText: strings.day,
                                    prefixIcon: Icon(
                                      Icons.calendar_today_rounded,
                                      color: subjectColor,
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(
                                        color: subjectColor,
                                        width: 2,
                                      ),
                                    ),
                                  ),
                                  items: days
                                      .asMap()
                                      .entries
                                      .map(
                                        (e) => DropdownMenuItem(
                                          value: e.key,
                                          child: Text(e.value),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: (value) =>
                                      setState(() => selectedDay = value!),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextFormField(
                                  readOnly: true,
                                  controller: TextEditingController(
                                    text: selectedTime,
                                  ),
                                  decoration: InputDecoration(
                                    labelText: strings.time,
                                    prefixIcon: Icon(
                                      Icons.access_time_rounded,
                                      color: subjectColor,
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(
                                        color: subjectColor,
                                        width: 2,
                                      ),
                                    ),
                                  ),
                                  onTap: () async {
                                    final timeParts = selectedTime.split(':');
                                    final initialTime = TimeOfDay(
                                      hour: int.parse(timeParts[0]),
                                      minute: int.parse(timeParts[1]),
                                    );
                                    final picked = await showTimePicker(
                                      context: context,
                                      initialTime: initialTime,
                                      builder: (context, child) {
                                        return Theme(
                                          data: Theme.of(context).copyWith(
                                            colorScheme: ColorScheme.light(
                                              primary: subjectColor,
                                              onPrimary: Colors.white,
                                              onSurface: Colors.black,
                                            ),
                                          ),
                                          child: child!,
                                        );
                                      },
                                    );
                                    if (picked != null) {
                                      if (!mounted) return;
                                      setState(() {
                                        // Format as HH:mm
                                        final hour = picked.hour
                                            .toString()
                                            .padLeft(2, '0');
                                        final minute = picked.minute
                                            .toString()
                                            .padLeft(2, '0');
                                        selectedTime = '$hour:$minute';
                                      });
                                    }
                                  },
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // Grade Level Dropdown (FIXED: Moved up to influence Subject/Group)
                          DropdownButtonFormField<String>(
                            value: selectedGradeLevel,
                            decoration: InputDecoration(
                              labelText: strings.isArabic
                                  ? 'المرحلة الدراسية *'
                                  : 'Grade Level *',
                              prefixIcon: Icon(
                                Icons.school_outlined,
                                color: subjectColor,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: subjectColor,
                                  width: 2,
                                ),
                              ),
                            ),
                            items: EducationalStages.allGrades
                                .map(
                                  (level) => DropdownMenuItem(
                                    value: level,
                                    child: Text(level),
                                  ),
                                )
                                .toList(),
                            onChanged: (value) => setState(() {
                              selectedGradeLevel = value;
                              // RESET Group when Grade Level changes to avoid Crash
                              selectedGroupId = null;
                              isCreatingNewGroup = false;
                              newGroupNameController.clear();
                            }),
                          ),
                          const SizedBox(height: 16),

                          // Subject Dropdown (Filtered)
                          DropdownButtonFormField<String>(
                            value: selectedSubject,
                            decoration: InputDecoration(
                              labelText: '${strings.subject} *',
                              prefixIcon: Icon(
                                Icons.menu_book_rounded,
                                color: subjectColor,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: subjectColor,
                                  width: 2,
                                ),
                              ),
                            ),
                            items: filteredSubjects.map((s) {
                              final color = SubjectColors.getColor(s.id);
                              return DropdownMenuItem(
                                value: s.id,
                                child: Row(
                                  children: [
                                    Container(
                                      width: 16,
                                      height: 16,
                                      decoration: BoxDecoration(
                                        color: color,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Text(s.name),
                                  ],
                                ),
                              );
                            }).toList(),
                            onChanged: (value) {
                              setState(() {
                                selectedSubject = value;
                                // If current teacher is NOT valid for this subject, reset teacher
                                if (selectedTeacher != null) {
                                  // We have a teacher selected. Check if they teach this subject.
                                  final teacher = state.teachers.firstWhere(
                                    (t) => t.id == selectedTeacher,
                                  );
                                  if (!teacher.subjectIds.contains(value)) {
                                    selectedTeacher = null;
                                  }
                                }
                                // Reset Group
                                selectedGroupId = null;
                                isCreatingNewGroup = false;
                              });
                            },
                          ),
                          const SizedBox(height: 16),

                          // Teacher Dropdown (Filtered)
                          DropdownButtonFormField<String>(
                            value: selectedTeacher,
                            decoration: InputDecoration(
                              labelText: '${strings.teacher} *',
                              prefixIcon: Icon(
                                Icons.person_rounded,
                                color: subjectColor,
                              ),
                              helperText:
                                  filteredTeachers.length <
                                      state.teachers.length
                                  ? '${strings.isArabic ? 'فلترة حسب المادة المختارة' : 'Filtered by Subject'}'
                                  : null,
                              helperStyle: TextStyle(
                                color: subjectColor,
                                fontWeight: FontWeight.w500,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: subjectColor,
                                  width: 2,
                                ),
                              ),
                            ),
                            items: filteredTeachers
                                .map(
                                  (t) => DropdownMenuItem(
                                    value: t.id,
                                    child: Text(t.name),
                                  ),
                                )
                                .toList(),
                            onChanged: (value) => setState(() {
                              selectedTeacher = value;
                              // Check if selectedSubject is valid for this teacher
                              if (selectedSubject != null) {
                                final teacher = state.teachers.firstWhere(
                                  (t) => t.id == value,
                                );
                                if (!teacher.subjectIds.contains(
                                  selectedSubject,
                                )) {
                                  // Ideally reset subject, or keep it if we support many-to-many loosely?
                                  // But if we drive "Filtered Subjects" by Teacher, then if Subject is NOT in Filtered Subjects, it will crash.
                                  // So we MUST check if selectedSubject is in filteredSubjects (derived from new teacher).
                                  if (!teacher.subjectIds.contains(
                                    selectedSubject,
                                  )) {
                                    selectedSubject = null;
                                  }
                                }
                              }
                              // Reset Group
                              selectedGroupId = null;
                              isCreatingNewGroup = false;
                            }),
                          ),
                          const SizedBox(height: 16),

                          // Group Selection Dropdown (New)
                          DropdownButtonFormField<String>(
                            value: isCreatingNewGroup
                                ? 'NEW_GROUP'
                                : (filteredGroups.any(
                                        (g) => g.id == selectedGroupId,
                                      )
                                      ? selectedGroupId
                                      : null),
                            // Protected against crash: If selectedGroupId is not in filtered list, pass null.
                            decoration: InputDecoration(
                              labelText: strings.isArabic
                                  ? 'المجموعة Study Group'
                                  : 'Group',
                              prefixIcon: Icon(
                                Icons.people_alt_rounded,
                                color: subjectColor,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: subjectColor,
                                  width: 2,
                                ),
                              ),
                            ),
                            items: [
                              ...filteredGroups.map(
                                (g) => DropdownMenuItem(
                                  value: g.id,
                                  child: Text(
                                    g.groupName,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                              DropdownMenuItem(
                                value: 'NEW_GROUP',
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.add_circle_outline,
                                      color: subjectColor,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      strings.isArabic
                                          ? 'إنشاء مجموعة جديدة'
                                          : 'Create New Group',
                                      style: TextStyle(
                                        color: subjectColor,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            onChanged: (value) {
                              setState(() {
                                if (value == 'NEW_GROUP') {
                                  isCreatingNewGroup = true;
                                  selectedGroupId = null;
                                } else {
                                  isCreatingNewGroup = false;
                                  selectedGroupId = value;
                                }
                              });
                            },
                          ),

                          const SizedBox(height: 16),

                          // Room & Duration (Always Visible)
                          Row(
                            children: [
                              // Room Dropdown
                              Expanded(
                                flex: 3,
                                child: DropdownButtonFormField<String>(
                                  isExpanded: true,
                                  value: selectedRoom,
                                  decoration: InputDecoration(
                                    labelText: '${strings.room} *',
                                    prefixIcon: Icon(
                                      Icons.meeting_room_rounded,
                                      color: subjectColor,
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(
                                        color: subjectColor,
                                        width: 2,
                                      ),
                                    ),
                                  ),
                                  items: state.rooms
                                      .map(
                                        (r) => DropdownMenuItem(
                                          value: r.id,
                                          child: Row(
                                            children: [
                                              Icon(
                                                Icons.door_back_door_outlined,
                                                size: 18,
                                                color: Colors.grey[600],
                                              ),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Text(
                                                  r.name,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                              if (r.capacity > 0) ...[
                                                const SizedBox(width: 8),
                                                Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 6,
                                                        vertical: 2,
                                                      ),
                                                  decoration: BoxDecoration(
                                                    color: Colors.grey[200],
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          4,
                                                        ),
                                                  ),
                                                  child: Text(
                                                    '${r.capacity}',
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      color: Colors.grey[700],
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: (value) =>
                                      setState(() => selectedRoom = value),
                                ),
                              ),
                              const SizedBox(width: 12),
                              // Duration Dropdown
                              Expanded(
                                flex: 2,
                                child: DropdownButtonFormField<double>(
                                  value: selectedDuration,
                                  decoration: InputDecoration(
                                    labelText: strings.isArabic
                                        ? 'المدة'
                                        : 'Duration',
                                    prefixIcon: Icon(
                                      Icons.timer_outlined,
                                      color: subjectColor,
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(
                                        color: subjectColor,
                                        width: 2,
                                      ),
                                    ),
                                  ),
                                  items: [1.0, 1.5, 2.0, 2.5, 3.0, 4.0].map((
                                    d,
                                  ) {
                                    return DropdownMenuItem(
                                      value: d,
                                      child: Text(
                                        strings.isArabic
                                            ? '${d.toString().replaceAll(".0", "")} ساعة'
                                            : '${d.toString().replaceAll(".0", "")}h',
                                        style: const TextStyle(fontSize: 13),
                                      ),
                                    );
                                  }).toList(),
                                  onChanged: (value) =>
                                      setState(() => selectedDuration = value!),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Actions
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: const BorderRadius.vertical(
                          bottom: Radius.circular(20),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(dialogContext),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: Text(strings.cancel),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 2,
                            child: ElevatedButton(
                              onPressed: () {
                                if (selectedSubject == null ||
                                    selectedTeacher == null ||
                                    selectedRoom == null ||
                                    selectedGradeLevel == null) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(strings.fillAllFields),
                                      backgroundColor: AppColors.warning,
                                    ),
                                  );
                                  return;
                                }

                                final session = ScheduleSession(
                                  id: '',
                                  subjectId: selectedSubject!,
                                  subjectName: state.subjects
                                      .firstWhere(
                                        (s) => s.id == selectedSubject,
                                      )
                                      .name,
                                  teacherId: selectedTeacher!,
                                  teacherName: state.teachers
                                      .firstWhere(
                                        (t) => t.id == selectedTeacher,
                                      )
                                      .name,
                                  roomId: selectedRoom!,
                                  roomName: state.rooms
                                      .firstWhere((r) => r.id == selectedRoom)
                                      .name,
                                  dayOfWeek: selectedDay,
                                  startTime: selectedTime,
                                  endTime: _getEndTime(
                                    selectedTime,
                                    selectedDuration,
                                  ),
                                  status: SessionStatus.scheduled,
                                  gradeLevel:
                                      selectedGradeLevel, // Added grade level
                                );

                                // Client-side Validation
                                final validation =
                                    ScheduleValidator.validateSession(
                                      newSession: session,
                                      existingSessions:
                                          scheduleBloc.state.sessions,
                                    );

                                if (validation.isBlocking) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Row(
                                        children: [
                                          const Icon(
                                            Icons.error_outline,
                                            color: Colors.white,
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              validation.message ??
                                                  'Conflict detected',
                                            ),
                                          ),
                                        ],
                                      ),
                                      backgroundColor: AppColors.error,
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                  return;
                                }

                                if (validation.isWarning) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Row(
                                        children: [
                                          const Icon(
                                            Icons.warning_amber_rounded,
                                            color: Colors.white,
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              validation.message ?? 'Warning',
                                            ),
                                          ),
                                        ],
                                      ),
                                      backgroundColor: Colors.orange,
                                      behavior: SnackBarBehavior.floating,
                                      duration: const Duration(seconds: 3),
                                    ),
                                  );
                                }

                                if (isCreatingNewGroup) {
                                  if (newGroupNameController.text.isEmpty) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          strings.isArabic
                                              ? 'يرجى إدخال اسم المجموعة'
                                              : 'Please enter group name',
                                        ),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                    return;
                                  }

                                  // Create Group Object
                                  final newGroup = Group(
                                    id: '', // DB generates
                                    centerId: '', // Repo handles
                                    courseId: selectedSubject!,
                                    teacherId: selectedTeacher!,
                                    groupName: newGroupNameController.text,
                                    gradeLevel: selectedGradeLevel,
                                    // Default values required by Group model
                                    maxStudents:
                                        state.rooms
                                                .firstWhere(
                                                  (r) => r.id == selectedRoom,
                                                )
                                                .capacity >
                                            0
                                        ? state.rooms
                                              .firstWhere(
                                                (r) => r.id == selectedRoom,
                                              )
                                              .capacity
                                        : 50, // Smart default if room capacity is 0
                                    currentStudents: 0,
                                    status: GroupStatus.active,
                                    isActive: true,
                                    createdAt: DateTime.now(),
                                    updatedAt: DateTime.now(),
                                    teacherName: state.teachers
                                        .firstWhere(
                                          (t) => t.id == selectedTeacher,
                                        )
                                        .name,
                                    // Populate Schedule info for Group Card display
                                    dayOfWeek: selectedDay,
                                    startTime: selectedTime,
                                    endTime: _getEndTime(
                                      selectedTime,
                                      selectedDuration,
                                    ),
                                  );

                                  scheduleBloc.add(
                                    CreateGroupAndSession(
                                      group: newGroup,
                                      session: session,
                                    ),
                                  );
                                } else {
                                  // Link to existing group if selected
                                  final sessionToAdd = selectedGroupId != null
                                      ? session.copyWith(
                                          groupId: selectedGroupId,
                                          groupName: state.groups
                                              .firstWhere(
                                                (g) => g.id == selectedGroupId,
                                              )
                                              .groupName,
                                        )
                                      : session;

                                  scheduleBloc.add(AddSession(sessionToAdd));
                                }

                                Navigator.pop(dialogContext);
                                ScaffoldMessenger.of(this.context).showSnackBar(
                                  SnackBar(
                                    content: Row(
                                      children: [
                                        const Icon(
                                          Icons.check_circle,
                                          color: Colors.white,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(strings.sessionAdded),
                                      ],
                                    ),
                                    backgroundColor: subjectColor,
                                    behavior: SnackBarBehavior.floating,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: subjectColor,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.add_rounded, size: 20),
                                  const SizedBox(width: 8),
                                  Text(
                                    strings.add,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
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

  String _getEndTime(String startTime, double durationHours) {
    final parts = startTime.split(':');
    final startHour = int.parse(parts[0]);
    final startMinute = int.parse(parts[1]);

    // Add duration
    final totalMinutes =
        (startHour * 60) + startMinute + (durationHours * 60).round();

    final endHour = (totalMinutes ~/ 60) % 24;
    final endMinute = totalMinutes % 60;

    return '${endHour.toString().padLeft(2, '0')}:${endMinute.toString().padLeft(2, '0')}';
  }

  void _showSessionDetails(ScheduleSession session, AppStrings strings) {
    final scheduleBloc = context.read<ScheduleBloc>();
    final days = strings.daysList;
    final subjectColor = SubjectColors.getColor(session.subjectId);

    showDialog(
      context: context,
      builder: (dialogContext) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header with subject color
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [subjectColor, subjectColor.withValues(alpha: 0.8)],
                  ),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(20),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.menu_book_rounded,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            session.subjectName,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              '${days[session.dayOfWeek]} | ${session.startTime} - ${session.endTime}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      icon: const Icon(Icons.close, color: Colors.white),
                    ),
                  ],
                ),
              ),

              // Details
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    _buildDetailTile(
                      icon: Icons.person_rounded,
                      label: strings.teacher,
                      value: session.teacherName,
                      color: subjectColor,
                    ),
                    const SizedBox(height: 12),
                    _buildDetailTile(
                      icon: Icons.meeting_room_rounded,
                      label: strings.room,
                      value: session.roomName,
                      color: subjectColor,
                    ),
                    const SizedBox(height: 12),
                    _buildDetailTile(
                      icon: Icons.repeat_rounded,
                      label: 'التكرار',
                      value: 'أسبوعياً - كل ${days[session.dayOfWeek]}',
                      color: subjectColor,
                    ),
                  ],
                ),
              ),

              // Actions
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(20),
                  ),
                ),
                child: Row(
                  children: [
                    // Delete
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pop(dialogContext);
                          scheduleBloc.add(DeleteSession(session.id));
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(strings.sessionDeleted),
                              backgroundColor: AppColors.error,
                            ),
                          );
                        },
                        icon: const Icon(
                          Icons.delete_outline_rounded,
                          size: 18,
                        ),
                        label: Text(strings.delete),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.error,
                          side: const BorderSide(color: AppColors.error),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Cancel/Restore
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pop(dialogContext); // Close options dialog

                          final isCancelled =
                              session.status == SessionStatus.cancelled;
                          final actionTitle = isCancelled
                              ? strings.confirmRestoreSession
                              : strings.confirmCancelSession;
                          final actionContent = isCancelled
                              ? strings.restoreSessionWarning
                              : strings.cancelSessionWarning;

                          // Show confirmation dialog
                          showDialog(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: Text(actionTitle),
                              content: Text(actionContent),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: Text(strings.cancel),
                                ),
                                TextButton(
                                  onPressed: () {
                                    Navigator.pop(
                                      context,
                                    ); // Close confirm dialog

                                    debugPrint(
                                      '🔄 [ScheduleScreen] Confirmed action for session: ${session.id}',
                                    );
                                    debugPrint(
                                      '   -> Current Status: ${session.status}',
                                    );

                                    final newStatus = isCancelled
                                        ? SessionStatus.scheduled
                                        : SessionStatus.cancelled;

                                    debugPrint('   -> New Status: $newStatus');

                                    final updatedSession = session.copyWith(
                                      status: newStatus,
                                    );

                                    debugPrint(
                                      '🚀 [ScheduleScreen] Dispatching UpdateSession event...',
                                    );
                                    scheduleBloc.add(
                                      UpdateSession(updatedSession),
                                    );

                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          isCancelled
                                              ? strings.sessionRestored
                                              : strings.sessionCancelled,
                                        ),
                                        backgroundColor: isCancelled
                                            ? AppColors.success
                                            : Colors.orange,
                                      ),
                                    );
                                  },
                                  child: Text(
                                    isCancelled
                                        ? strings.restoreSession
                                        : strings.cancelSession,
                                    style: TextStyle(
                                      color: isCancelled
                                          ? AppColors.success
                                          : Colors.orange,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                        icon: Icon(
                          session.status == SessionStatus.cancelled
                              ? Icons.restore_rounded
                              : Icons.cancel_outlined,
                          size: 18,
                        ),
                        label: Text(
                          session.status == SessionStatus.cancelled
                              ? strings.restoreSession
                              : strings.cancelSession,
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor:
                              session.status == SessionStatus.cancelled
                              ? AppColors.success
                              : Colors.orange,
                          side: BorderSide(
                            color: session.status == SessionStatus.cancelled
                                ? AppColors.success
                                : Colors.orange,
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
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

  Widget _buildDetailTile({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 20, color: color),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[800],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
