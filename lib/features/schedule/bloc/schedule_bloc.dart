import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart'; // Added for debugPrint
import '../../../shared/models/models.dart';
import '../logic/schedule_validator.dart';
import '../data/repositories/schedule_repository.dart';
import '../../subjects/data/repositories/subjects_repository.dart';
import '../../teachers/data/repositories/teachers_repository.dart';
import '../../rooms/data/repositories/rooms_repository.dart';
import '../../groups/data/repositories/groups_repository.dart';

// ═══════════════════════════════════════════════════════════════════════════
// EVENTS
// ═══════════════════════════════════════════════════════════════════════════

abstract class ScheduleEvent extends Equatable {
  const ScheduleEvent();

  @override
  List<Object?> get props => [];
}

class LoadSchedule extends ScheduleEvent {
  final bool forceRefresh;

  const LoadSchedule({this.forceRefresh = false});

  @override
  List<Object?> get props => [forceRefresh];
}

class AddSession extends ScheduleEvent {
  final ScheduleSession session;

  const AddSession(this.session);

  @override
  List<Object?> get props => [session];
}

class UpdateSession extends ScheduleEvent {
  final ScheduleSession session;

  const UpdateSession(this.session);

  @override
  List<Object?> get props => [session];
}

class DeleteSession extends ScheduleEvent {
  final String id;

  const DeleteSession(this.id);

  @override
  List<Object?> get props => [id];
}

class CreateGroupAndSession extends ScheduleEvent {
  final Group group;
  final ScheduleSession session;

  const CreateGroupAndSession({required this.group, required this.session});

  @override
  List<Object?> get props => [group, session];
}

// ═══════════════════════════════════════════════════════════════════════════
// STATE
// ═══════════════════════════════════════════════════════════════════════════

enum ScheduleStatus { initial, loading, success, failure }

class ScheduleState extends Equatable {
  final ScheduleStatus status;
  final List<ScheduleSession> sessions;
  final List<Subject> subjects;
  final List<Teacher> teachers;
  final List<Room> rooms;
  final List<Group> groups;
  final String? errorMessage;

  const ScheduleState({
    this.status = ScheduleStatus.initial,
    this.sessions = const [],
    this.subjects = const [],
    this.teachers = const [],
    this.rooms = const [],
    this.groups = const [],
    this.errorMessage,
  });

  ScheduleState copyWith({
    ScheduleStatus? status,
    List<ScheduleSession>? sessions,
    List<Subject>? subjects,
    List<Teacher>? teachers,
    List<Room>? rooms,
    List<Group>? groups,
    String? errorMessage,
  }) {
    return ScheduleState(
      status: status ?? this.status,
      sessions: sessions ?? this.sessions,
      subjects: subjects ?? this.subjects,
      teachers: teachers ?? this.teachers,
      rooms: rooms ?? this.rooms,
      groups: groups ?? this.groups,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  @override
  List<Object?> get props => [
    status,
    sessions,
    subjects,
    teachers,
    rooms,
    groups,
    errorMessage,
  ];
}

// ═══════════════════════════════════════════════════════════════════════════
// BLOC
// ═══════════════════════════════════════════════════════════════════════════

class ScheduleBloc extends Bloc<ScheduleEvent, ScheduleState> {
  final ScheduleRepository _scheduleRepo;
  final SubjectsRepository _subjectsRepo;
  final TeachersRepository _teachersRepo;
  final RoomsRepository _roomsRepo;
  final GroupsRepository _groupsRepo;

  ScheduleBloc({
    required ScheduleRepository scheduleRepo,
    required SubjectsRepository subjectsRepo,
    required TeachersRepository teachersRepo,
    required RoomsRepository roomsRepo,
    required GroupsRepository groupsRepo,
  }) : _scheduleRepo = scheduleRepo,
       _subjectsRepo = subjectsRepo,
       _teachersRepo = teachersRepo,
       _roomsRepo = roomsRepo,
       _groupsRepo = groupsRepo,
       super(const ScheduleState()) {
    on<LoadSchedule>(_onLoadSchedule);
    on<AddSession>(_onAddSession);
    on<UpdateSession>(_onUpdateSession);
    on<DeleteSession>(_onDeleteSession);
    on<CreateGroupAndSession>(_onCreateGroupAndSession);
  }

  Future<void> _onLoadSchedule(
    LoadSchedule event,
    Emitter<ScheduleState> emit,
  ) async {
    debugPrint(
      '📅 [ScheduleBloc] _onLoadSchedule started (forceRefresh: ${event.forceRefresh})',
    );
    emit(state.copyWith(status: ScheduleStatus.loading));

    try {
      debugPrint('📅 [ScheduleBloc] Fetching sessions...');
      // Run fetches in parallel
      final results = await Future.wait([
        _scheduleRepo.getSessions(forceRefresh: event.forceRefresh),
        _subjectsRepo.getSubjects(),
        _teachersRepo.getTeachers(),
        _roomsRepo.getRooms(),
        _groupsRepo.getGroups(forceRefresh: event.forceRefresh),
      ]);

      final sessions = results[0] as List<ScheduleSession>;
      final subjects = results[1] as List<Subject>;
      final teachers = results[2] as List<Teacher>;
      final rooms = results[3] as List<Room>;
      final groups = results[4] as List<Group>;

      debugPrint('📅 [ScheduleBloc] Sessions fetched: ${sessions.length}');
      debugPrint('📅 [ScheduleBloc] Subjects fetched: ${subjects.length}');
      debugPrint('📅 [ScheduleBloc] Teachers fetched: ${teachers.length}');
      debugPrint('📅 [ScheduleBloc] Rooms fetched: ${rooms.length}');
      debugPrint('📅 [ScheduleBloc] Groups fetched: ${groups.length}');

      emit(
        state.copyWith(
          status: ScheduleStatus.success,
          sessions: sessions,
          subjects: subjects,
          teachers: teachers,
          rooms: rooms,
          groups: groups,
        ),
      );
    } catch (e) {
      debugPrint('❌ [ScheduleBloc] LoadSchedule Error: $e');
      emit(
        state.copyWith(
          status: ScheduleStatus.failure,
          errorMessage: e.toString(),
        ),
      );
    }
  }

  Future<void> _onAddSession(
    AddSession event,
    Emitter<ScheduleState> emit,
  ) async {
    debugPrint('➕ [ScheduleBloc] _onAddSession started');

    // 1. Validate Session before adding
    final validation = ScheduleValidator.validateSession(
      newSession: event.session,
      existingSessions: state.sessions,
    );

    if (validation.isBlocking) {
      debugPrint('❌ [ScheduleBloc] Validation Failed: ${validation.message}');
      emit(
        state.copyWith(
          status: ScheduleStatus.failure,
          errorMessage: validation.message,
        ),
      );
      // Reset status to success/loaded so UI can try again without sticking in failure
      emit(state.copyWith(status: ScheduleStatus.success, errorMessage: null));
      return;
    }

    if (validation.isWarning) {
      debugPrint('⚠️ [ScheduleBloc] Validation Warning: ${validation.message}');
    }

    emit(state.copyWith(status: ScheduleStatus.loading));
    try {
      debugPrint('➕ [ScheduleBloc] Calling _scheduleRepo.addSession...');
      await _scheduleRepo.addSession(event.session);
      debugPrint(
        '✅ [ScheduleBloc] Session added successfully! Reloading schedule...',
      );
      add(LoadSchedule());
    } catch (e) {
      debugPrint('❌ [ScheduleBloc] AddSession Error: $e');
      emit(
        state.copyWith(
          status: ScheduleStatus.failure,
          errorMessage: e.toString(),
        ),
      );
    }
  }

  Future<void> _onUpdateSession(
    UpdateSession event,
    Emitter<ScheduleState> emit,
  ) async {
    debugPrint('📥 [ScheduleBloc] UpdateSession event received');

    emit(state.copyWith(status: ScheduleStatus.loading));
    try {
      debugPrint('🔄 [ScheduleBloc] Calling _scheduleRepo.updateSession...');
      await _scheduleRepo.updateSession(event.session);
      debugPrint('✅ [ScheduleBloc] Update successful, reloading schedule...');
      add(LoadSchedule());
    } catch (e) {
      emit(
        state.copyWith(
          status: ScheduleStatus.failure,
          errorMessage: e.toString(),
        ),
      );
    }
  }

  Future<void> _onDeleteSession(
    DeleteSession event,
    Emitter<ScheduleState> emit,
  ) async {
    debugPrint('🗑️ [ScheduleBloc] _onDeleteSession started');

    emit(state.copyWith(status: ScheduleStatus.loading));
    try {
      debugPrint('🗑️ [ScheduleBloc] Calling _scheduleRepo.deleteSession...');
      await _scheduleRepo.deleteSession(event.id);
      debugPrint('✅ [ScheduleBloc] Session deleted! Reloading schedule...');
      add(const LoadSchedule());
    } catch (e) {
      debugPrint('❌ [ScheduleBloc] DeleteSession Error: $e');
      emit(
        state.copyWith(
          status: ScheduleStatus.failure,
          errorMessage: e.toString(),
        ),
      );
    }
  }

  Future<void> _onCreateGroupAndSession(
    CreateGroupAndSession event,
    Emitter<ScheduleState> emit,
  ) async {
    debugPrint('✨ [ScheduleBloc] _onCreateGroupAndSession started');
    emit(state.copyWith(status: ScheduleStatus.loading));

    try {
      // 1. Create Group
      debugPrint(
        '🆕 [ScheduleBloc] Creating new group: ${event.group.groupName}...',
      );
      final createdGroup = await _groupsRepo.addGroup(event.group);
      debugPrint('✅ [ScheduleBloc] Group created with ID: ${createdGroup.id}');

      // 2. Link Session to Group
      final sessionWithGroup = event.session.copyWith(
        groupId: createdGroup.id,
        groupName: createdGroup.groupName,
      );

      // 3. Add Session
      debugPrint('➕ [ScheduleBloc] Adding session linked to group...');
      await _scheduleRepo.addSession(sessionWithGroup);

      debugPrint(
        '✅ [ScheduleBloc] Group & Session created successfully! Reloading...',
      );
      add(const LoadSchedule(forceRefresh: true));
    } catch (e) {
      debugPrint('❌ [ScheduleBloc] CreateGroupAndSession Error: $e');
      emit(
        state.copyWith(
          status: ScheduleStatus.failure,
          errorMessage: e.toString(),
        ),
      );
    }
  }
}
