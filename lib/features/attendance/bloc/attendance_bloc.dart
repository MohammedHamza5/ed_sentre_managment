import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../../shared/models/models.dart';
import '../../students/data/repositories/students_repository.dart';
import '../../groups/data/repositories/groups_repository.dart';
import '../../schedule/data/repositories/schedule_repository.dart';
import '../data/repositories/attendance_repository.dart';

// ═══════════════════════════════════════════════════════════════════════════
// EVENTS
// ═══════════════════════════════════════════════════════════════════════════

abstract class AttendanceEvent extends Equatable {
  const AttendanceEvent();

  @override
  List<Object?> get props => [];
}

// --- NEW SMART FLOW EVENTS ---
class SetAttendanceContext extends AttendanceEvent {
  final DateTime date;
  final String? subjectId;
  const SetAttendanceContext({required this.date, this.subjectId});
  @override
  List<Object?> get props => [date, subjectId];
}

class SelectSession extends AttendanceEvent {
  final ScheduleSession session;
  const SelectSession(this.session);
  @override
  List<Object?> get props => [session];
}

class UpdateStudentStatus extends AttendanceEvent {
  final String studentId;
  final AttendanceStatus status;
  const UpdateStudentStatus(this.studentId, this.status);
  @override
  List<Object?> get props => [studentId, status];
}

class MarkAllStudents extends AttendanceEvent {
  final AttendanceStatus status;
  const MarkAllStudents(this.status);
  @override
  List<Object?> get props => [status];
}

class SubmitAttendance extends AttendanceEvent {}

class ResetAttendance extends AttendanceEvent {}

// --- LEGACY / HISTORY EVENTS (For AttendanceScreen) ---
class LoadAttendance extends AttendanceEvent {}

class LoadAttendanceByDate extends AttendanceEvent {
  final DateTime date;
  const LoadAttendanceByDate(this.date);
  @override
  List<Object?> get props => [date];
}

class ChangeSelectedDate extends AttendanceEvent {
  final DateTime date;
  const ChangeSelectedDate(this.date);
  @override
  List<Object?> get props => [date];
}

class DeleteAttendanceRecord extends AttendanceEvent {
  final String id;
  const DeleteAttendanceRecord(this.id);
  @override
  List<Object?> get props => [id];
}

class UpdateSavedAttendanceRecord extends AttendanceEvent {
  final String id;
  final AttendanceStatus status;
  const UpdateSavedAttendanceRecord({required this.id, required this.status});
  @override
  List<Object?> get props => [id, status];
}

// ═══════════════════════════════════════════════════════════════════════════
// STATE
// ═══════════════════════════════════════════════════════════════════════════

enum AttendanceStep {
  selectingContext,
  selectingSession,
  marking,
  submitting,
  success,
  failure,
}

enum AttendanceLoadingStatus { initial, loading, success, failure }

class AttendanceState extends Equatable {
  // Smart Flow State
  final AttendanceStep step;
  final String? selectedSubjectId;
  final ScheduleSession? selectedSession;
  final List<ScheduleSession> availableSessions;
  final List<Student> students;
  final Map<String, AttendanceStatus> attendanceMap;

  // Legacy/History State
  final AttendanceLoadingStatus status;
  final DateTime selectedDate;
  final List<AttendanceRecord> records;
  final Map<String, dynamic> stats;

  // Shared
  final String? errorMessage;

  const AttendanceState({
    // Smart Flow
    this.step = AttendanceStep.selectingContext,
    this.selectedSubjectId,
    this.selectedSession,
    this.availableSessions = const [],
    this.students = const [],
    this.attendanceMap = const {},

    // Legacy
    this.status = AttendanceLoadingStatus.initial,
    required this.selectedDate,
    this.records = const [],
    this.stats = const {},

    this.errorMessage,
  });

  factory AttendanceState.initial() {
    return AttendanceState(
      selectedDate: DateTime.now(),
      attendanceMap: const {},
    );
  }

  AttendanceState copyWith({
    AttendanceStep? step,
    String? selectedSubjectId,
    ScheduleSession? selectedSession,
    List<ScheduleSession>? availableSessions,
    List<Student>? students,
    Map<String, AttendanceStatus>? attendanceMap,
    AttendanceLoadingStatus? status,
    DateTime? selectedDate,
    List<AttendanceRecord>? records,
    Map<String, dynamic>? stats,
    String? errorMessage,
  }) {
    return AttendanceState(
      step: step ?? this.step,
      selectedSubjectId: selectedSubjectId ?? this.selectedSubjectId,
      selectedSession: selectedSession ?? this.selectedSession,
      availableSessions: availableSessions ?? this.availableSessions,
      students: students ?? this.students,
      attendanceMap: attendanceMap ?? this.attendanceMap,
      status: status ?? this.status,
      selectedDate: selectedDate ?? this.selectedDate,
      records: records ?? this.records,
      stats: stats ?? this.stats,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  // Smart Flow & History Helpers
  int get presentCount {
    if (records.isNotEmpty) {
      return records.where((r) => r.status == AttendanceStatus.present).length;
    }
    return attendanceMap.values
        .where((s) => s == AttendanceStatus.present)
        .length;
  }

  int get absentCount {
    if (records.isNotEmpty) {
      return records.where((r) => r.status == AttendanceStatus.absent).length;
    }
    return attendanceMap.values
        .where((s) => s == AttendanceStatus.absent)
        .length;
  }

  int get lateCount {
    if (records.isNotEmpty) {
      return records.where((r) => r.status == AttendanceStatus.late).length;
    }
    return attendanceMap.values.where((s) => s == AttendanceStatus.late).length;
  }

  int get excusedCount {
    if (records.isNotEmpty) {
      return records.where((r) => r.status == AttendanceStatus.excused).length;
    }
    return attendanceMap.values
        .where((s) => s == AttendanceStatus.excused)
        .length;
  }

  bool get canSubmit =>
      attendanceMap.isNotEmpty && step == AttendanceStep.marking;

  // Legacy Helpers
  double get attendanceRate => records.isEmpty
      ? 0
      : (records.where((r) => r.status == AttendanceStatus.present).length) /
            records.length *
            100;

  @override
  List<Object?> get props => [
    step,
    selectedSubjectId,
    selectedSession,
    availableSessions,
    students,
    attendanceMap,
    status,
    selectedDate,
    records,
    stats,
    errorMessage,
  ];
}

// ═══════════════════════════════════════════════════════════════════════════
// BLOC
// ═══════════════════════════════════════════════════════════════════════════

class AttendanceBloc extends Bloc<AttendanceEvent, AttendanceState> {
  final AttendanceRepository _attendanceRepo;
  final ScheduleRepository _scheduleRepo;
  final StudentsRepository _studentsRepo;
  final GroupsRepository _groupsRepo;

  AttendanceBloc({
    required AttendanceRepository attendanceRepo,
    required ScheduleRepository scheduleRepo,
    required StudentsRepository studentsRepo,
    required GroupsRepository groupsRepo,
  }) : _attendanceRepo = attendanceRepo,
       _scheduleRepo = scheduleRepo,
       _studentsRepo = studentsRepo,
       _groupsRepo = groupsRepo,
       super(AttendanceState.initial()) {
    // Smart Flow
    on<SetAttendanceContext>(_onSetContext);
    on<SelectSession>(_onSelectSession);
    on<UpdateStudentStatus>(_onUpdateStudentStatus);
    on<MarkAllStudents>(_onMarkAll);
    on<SubmitAttendance>(_onSubmit);
    on<ResetAttendance>((event, emit) => emit(AttendanceState.initial()));

    // Legacy / History
    on<LoadAttendance>(_onLoadAttendance);
    on<LoadAttendanceByDate>(_onLoadAttendanceByDate);
    on<ChangeSelectedDate>(_onChangeSelectedDate);
    on<DeleteAttendanceRecord>(_onDeleteAttendance);
    on<UpdateSavedAttendanceRecord>(_onUpdateSavedRecord);
  }

  // --- SMART FLOW HANDLERS ---

  Future<void> _onSetContext(
    SetAttendanceContext event,
    Emitter<AttendanceState> emit,
  ) async {
    try {
      debugPrint(
        '═══════════════════════════════════════════════════════════════',
      );
      debugPrint('🧠 [AttendanceBloc] _onSetContext STARTED');
      debugPrint('   📅 Date: ${event.date}');
      debugPrint('   📚 SubjectId: ${event.subjectId}');
      debugPrint(
        '═══════════════════════════════════════════════════════════════',
      );

      emit(
        state.copyWith(
          step: AttendanceStep.selectingContext,
          selectedDate: event.date,
          selectedSubjectId: event.subjectId,
          selectedSession: null,
          attendanceMap: {},
          errorMessage: null,
        ),
      );

      debugPrint('📡 [AttendanceBloc] Calling _scheduleRepo.getSessions()...');
      final allSessions = await _scheduleRepo.getSessions();
      debugPrint('✅ [AttendanceBloc] Got ${allSessions.length} total sessions');

      // Log all sessions for debugging
      for (int i = 0; i < allSessions.length; i++) {
        final s = allSessions[i];
        debugPrint(
          '   📋 Session[$i]: day=${s.dayOfWeek}, subject=${s.subjectName}, group=${s.groupName}, time=${s.startTime}',
        );
      }

      // Convert Dart weekday (1=Mon, 7=Sun) to our system (0=Sat, 1=Sun, ..., 6=Fri)
      final dartWeekday = event.date.weekday;
      final sysDayIndex = (dartWeekday % 7 + 1) % 7;
      debugPrint(
        '📅 [AttendanceBloc] Dart weekday: $dartWeekday -> System day index: $sysDayIndex',
      );

      final relevantSessions = allSessions.where((s) {
        final dayMatch = s.dayOfWeek == sysDayIndex;
        final subjectMatch =
            event.subjectId == null || s.subjectId == event.subjectId;
        debugPrint(
          '   🔍 Session ${s.subjectName}: dayOfWeek=${s.dayOfWeek}, dayMatch=$dayMatch, subjectMatch=$subjectMatch',
        );
        return dayMatch && subjectMatch;
      }).toList();

      debugPrint(
        '✅ [AttendanceBloc] Found ${relevantSessions.length} relevant sessions for today',
      );
      for (final s in relevantSessions) {
        debugPrint('   ✓ ${s.subjectName} (${s.groupName}) @ ${s.startTime}');
      }

      emit(state.copyWith(availableSessions: relevantSessions));

      if (relevantSessions.length == 1) {
        debugPrint('🎯 [AttendanceBloc] Auto-selecting single session');
        add(SelectSession(relevantSessions.first));
      } else if (relevantSessions.isEmpty) {
        debugPrint('⚠️ [AttendanceBloc] NO SESSIONS found for today!');
      }

      debugPrint(
        '═══════════════════════════════════════════════════════════════',
      );
      debugPrint('🧠 [AttendanceBloc] _onSetContext COMPLETED');
      debugPrint(
        '═══════════════════════════════════════════════════════════════',
      );
    } catch (e, stack) {
      debugPrint('❌ [AttendanceBloc] _onSetContext ERROR: $e');
      debugPrint('   Stack: $stack');
      emit(state.copyWith(errorMessage: 'Error loading sessions: $e'));
    }
  }

  Future<void> _onSelectSession(
    SelectSession event,
    Emitter<AttendanceState> emit,
  ) async {
    try {
      debugPrint(
        '═══════════════════════════════════════════════════════════════',
      );
      debugPrint('🎯 [AttendanceBloc] _onSelectSession STARTED');
      debugPrint('   📋 Session: ${event.session.subjectName}');
      debugPrint('   👥 Group: ${event.session.groupName}');
      debugPrint('   🎓 Grade: ${event.session.gradeLevel}');
      debugPrint('   🆔 Session ID: ${event.session.id}');
      debugPrint(
        '═══════════════════════════════════════════════════════════════',
      );

      emit(
        state.copyWith(
          step: AttendanceStep.selectingSession,
          selectedSession: event.session,
        ),
      );

      debugPrint('📡 [AttendanceBloc] Fetching all students...');
      final allStudents = await _studentsRepo.getStudents();
      debugPrint('✅ [AttendanceBloc] Got ${allStudents.length} total students');

      List<Student> eligibleStudents = [];

      // 1. If it's a GROUP session (has groupName), check group enrollment
      if (event.session.groupName != null &&
          event.session.groupName!.isNotEmpty) {
        debugPrint(
          '🔍 [AttendanceBloc] Session has groupName: ${event.session.groupName}',
        );
        try {
          debugPrint(
            '📡 [AttendanceBloc] Fetching groups with gradeLevel: ${event.session.gradeLevel}',
          );
          final groups = await _groupsRepo.getGroups(
            gradeLevel: event.session.gradeLevel,
          );
          debugPrint('✅ [AttendanceBloc] Got ${groups.length} groups');

          final group = groups
              .where((g) => g.groupName == event.session.groupName)
              .firstOrNull;

          if (group != null) {
            debugPrint(
              '✅ [AttendanceBloc] Found matching group: ${group.groupName} (ID: ${group.id})',
            );
            debugPrint('📡 [AttendanceBloc] Fetching group enrollments...');
            final enrollments = await _groupsRepo.getGroupEnrollments(group.id);
            debugPrint(
              '✅ [AttendanceBloc] Got ${enrollments.length} enrollments',
            );

            final enrolledIds = enrollments.map((e) => e.studentId).toSet();
            debugPrint('   Enrolled student IDs: $enrolledIds');

            eligibleStudents = allStudents
                .where((s) => enrolledIds.contains(s.id))
                .toList();
            debugPrint(
              '✅ [AttendanceBloc] Matched ${eligibleStudents.length} students from enrollments',
            );
          } else {
            debugPrint(
              '⚠️ [AttendanceBloc] No matching group found, falling back to grade level',
            );
            // Fallback to Grade Level
            if (event.session.gradeLevel != null &&
                event.session.gradeLevel!.isNotEmpty) {
              eligibleStudents = allStudents
                  .where(
                    (s) =>
                        s.gradeLevel == event.session.gradeLevel ||
                        s.gradeLevel == null,
                  )
                  .toList();
              debugPrint(
                '✅ [AttendanceBloc] Matched ${eligibleStudents.length} students by grade level',
              );
            } else {
              eligibleStudents = allStudents;
              debugPrint(
                '⚠️ [AttendanceBloc] No grade level, using all students',
              );
            }
          }
        } catch (e) {
          debugPrint('❌ [AttendanceBloc] Error fetching group data: $e');
          eligibleStudents = allStudents;
        }
      } else {
        debugPrint(
          '⚠️ [AttendanceBloc] No groupName, falling back to grade level',
        );
        // Not a group session or no group name, fallback to all or grade
        if (event.session.gradeLevel != null &&
            event.session.gradeLevel!.isNotEmpty) {
          eligibleStudents = allStudents
              .where(
                (s) =>
                    s.gradeLevel == event.session.gradeLevel ||
                    s.gradeLevel == null,
              )
              .toList();
          debugPrint(
            '✅ [AttendanceBloc] Matched ${eligibleStudents.length} students by grade level',
          );
        } else {
          eligibleStudents = allStudents;
          debugPrint(
            '⚠️ [AttendanceBloc] No grade level filter, using all students',
          );
        }
      }

      // Fallback or explicit filtering
      if (eligibleStudents.isEmpty) {
        debugPrint(
          '⚠️ [AttendanceBloc] No eligible students found, using ALL students as fallback',
        );
        eligibleStudents = allStudents;
      }

      debugPrint(
        '📡 [AttendanceBloc] Fetching existing attendance records for ${state.selectedDate}...',
      );
      final existingRecords = await _attendanceRepo.getAttendanceByDate(
        state.selectedDate,
      );
      debugPrint(
        '✅ [AttendanceBloc] Got ${existingRecords.length} existing records',
      );

      final Map<String, AttendanceStatus> initialMap = {};

      for (var student in eligibleStudents) {
        final record = existingRecords.firstWhere(
          (r) => r.studentId == student.id && r.sessionId == event.session.id,
          orElse: () => AttendanceRecord.empty(),
        );
        initialMap[student.id] = record.id.isNotEmpty
            ? record.status
            : AttendanceStatus.present;
      }

      debugPrint(
        '✅ [AttendanceBloc] Initialized attendance map for ${initialMap.length} students',
      );

      emit(
        state.copyWith(
          step: AttendanceStep.marking,
          students: eligibleStudents,
          attendanceMap: initialMap,
        ),
      );

      debugPrint(
        '═══════════════════════════════════════════════════════════════',
      );
      debugPrint('🎯 [AttendanceBloc] _onSelectSession COMPLETED');
      debugPrint(
        '   📊 Final: ${eligibleStudents.length} students ready for marking',
      );
      debugPrint(
        '═══════════════════════════════════════════════════════════════',
      );
    } catch (e, stack) {
      debugPrint('❌ [AttendanceBloc] _onSelectSession ERROR: $e');
      debugPrint('   Stack: $stack');
      emit(state.copyWith(errorMessage: 'Error loading students: $e'));
    }
  }

  void _onUpdateStudentStatus(
    UpdateStudentStatus event,
    Emitter<AttendanceState> emit,
  ) {
    final newMap = Map<String, AttendanceStatus>.from(state.attendanceMap);
    newMap[event.studentId] = event.status;
    emit(state.copyWith(attendanceMap: newMap));
  }

  void _onMarkAll(MarkAllStudents event, Emitter<AttendanceState> emit) {
    final newMap = Map<String, AttendanceStatus>.from(state.attendanceMap);
    for (var s in state.students) {
      newMap[s.id] = event.status;
    }
    emit(state.copyWith(attendanceMap: newMap));
  }

  Future<void> _onSubmit(
    SubmitAttendance event,
    Emitter<AttendanceState> emit,
  ) async {
    debugPrint(
      '═══════════════════════════════════════════════════════════════',
    );
    debugPrint('💾 [AttendanceBloc] _onSubmit STARTED');
    debugPrint(
      '═══════════════════════════════════════════════════════════════',
    );

    if (state.selectedSession == null) {
      debugPrint('❌ [AttendanceBloc] No session selected, aborting');
      return;
    }

    debugPrint('   📋 Session: ${state.selectedSession!.subjectName}');
    debugPrint('   📅 Date: ${state.selectedDate}');
    debugPrint('   👥 Students to save: ${state.attendanceMap.length}');

    emit(state.copyWith(step: AttendanceStep.submitting));
    try {
      final List<AttendanceRecord> recordsToSave = [];
      state.attendanceMap.forEach((studentId, status) {
        final studentName = state.students
            .firstWhere((s) => s.id == studentId)
            .name;
        debugPrint('   📝 $studentName: $status');
        recordsToSave.add(
          AttendanceRecord(
            id: '',
            studentId: studentId,
            sessionId: state.selectedSession!.id,
            date: state.selectedDate,
            status: status,
            studentName: studentName,
            checkInTime: DateTime.now(),
          ),
        );
      });

      debugPrint(
        '📡 [AttendanceBloc] Calling addBulkAttendance with ${recordsToSave.length} records...',
      );
      await _attendanceRepo.addBulkAttendance(recordsToSave);
      debugPrint('✅ [AttendanceBloc] Attendance saved successfully!');

      emit(state.copyWith(step: AttendanceStep.success));

      debugPrint(
        '═══════════════════════════════════════════════════════════════',
      );
      debugPrint('💾 [AttendanceBloc] _onSubmit COMPLETED');
      debugPrint(
        '═══════════════════════════════════════════════════════════════',
      );
    } catch (e, stack) {
      debugPrint('❌ [AttendanceBloc] _onSubmit ERROR: $e');
      debugPrint('   Stack: $stack');
      emit(
        state.copyWith(
          step: AttendanceStep.marking,
          errorMessage: 'Failed to save: $e',
        ),
      );
    }
  }

  // --- LEGACY HANDLERS ---

  Future<void> _onLoadAttendance(
    LoadAttendance event,
    Emitter<AttendanceState> emit,
  ) async {
    add(LoadAttendanceByDate(state.selectedDate));
  }

  Future<void> _onLoadAttendanceByDate(
    LoadAttendanceByDate event,
    Emitter<AttendanceState> emit,
  ) async {
    emit(
      state.copyWith(
        status: AttendanceLoadingStatus.loading,
        selectedDate: event.date,
      ),
    );
    try {
      final records = await _attendanceRepo.getAttendanceByDate(event.date);
      final stats = await _attendanceRepo.getAttendanceStats(date: event.date);
      emit(
        state.copyWith(
          status: AttendanceLoadingStatus.success,
          records: records,
          stats: stats,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          status: AttendanceLoadingStatus.failure,
          errorMessage: e.toString(),
        ),
      );
    }
  }

  void _onChangeSelectedDate(
    ChangeSelectedDate event,
    Emitter<AttendanceState> emit,
  ) {
    add(LoadAttendanceByDate(event.date));
  }

  Future<void> _onDeleteAttendance(
    DeleteAttendanceRecord event,
    Emitter<AttendanceState> emit,
  ) async {
    try {
      await _attendanceRepo.deleteAttendance(event.id);
      add(LoadAttendanceByDate(state.selectedDate));
    } catch (e) {
      emit(state.copyWith(errorMessage: 'Failed to delete: $e'));
    }
  }

  Future<void> _onUpdateSavedRecord(
    UpdateSavedAttendanceRecord event,
    Emitter<AttendanceState> emit,
  ) async {
    try {
      // Find the record to update generically, or just send update command
      // We need a method in repo to update just status.
      // Assuming updateAttendance(record) exists in IDataRepository

      final record = state.records.firstWhere((r) => r.id == event.id);
      final updatedRecord = record.copyWith(status: event.status);

      await _attendanceRepo.updateAttendance(updatedRecord);
      add(LoadAttendanceByDate(state.selectedDate)); // Reload
    } catch (e) {
      emit(state.copyWith(errorMessage: 'Failed to update: $e'));
    }
  }
}
