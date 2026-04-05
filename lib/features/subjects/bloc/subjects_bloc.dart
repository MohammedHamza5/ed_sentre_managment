import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../../shared/models/models.dart';
import '../data/repositories/subjects_repository.dart';
import '../../teachers/data/repositories/teachers_repository.dart';
import '../../settings/data/sources/settings_remote_source.dart';

// ═══════════════════════════════════════════════════════════════════════════
// EVENTS
// ═══════════════════════════════════════════════════════════════════════════

abstract class SubjectsEvent extends Equatable {
  const SubjectsEvent();
  @override
  List<Object?> get props => [];
}

class LoadSubjects extends SubjectsEvent {}

class AddSubject extends SubjectsEvent {
  final Subject subject;
  const AddSubject(this.subject);
  @override
  List<Object?> get props => [subject];
}

class UpdateSubject extends SubjectsEvent {
  final Subject subject;
  const UpdateSubject(this.subject);
  @override
  List<Object?> get props => [subject];
}

class DeleteSubject extends SubjectsEvent {
  final String subjectId;
  const DeleteSubject(this.subjectId);
  @override
  List<Object?> get props => [subjectId];
}

// ═══════════════════════════════════════════════════════════════════════════
// STATE
// ═══════════════════════════════════════════════════════════════════════════

enum SubjectsStatus { initial, loading, success, failure }

class SubjectsState extends Equatable {
  final SubjectsStatus status;
  final List<Subject> subjects;
  final List<Teacher> allTeachers;
  final List<CoursePrice> coursePrices;
  final String? errorMessage;

  const SubjectsState({
    this.status = SubjectsStatus.initial,
    this.subjects = const [],
    this.allTeachers = const [],
    this.coursePrices = const [],
    this.errorMessage,
  });

  /// Get prices for a specific subject
  List<CoursePrice> pricesForSubject(String subjectName) {
    return coursePrices
        .where((p) => p.subjectName.toLowerCase() == subjectName.toLowerCase())
        .toList();
  }

  SubjectsState copyWith({
    SubjectsStatus? status,
    List<Subject>? subjects,
    List<Teacher>? allTeachers,
    List<CoursePrice>? coursePrices,
    String? errorMessage,
  }) {
    return SubjectsState(
      status: status ?? this.status,
      subjects: subjects ?? this.subjects,
      allTeachers: allTeachers ?? this.allTeachers,
      coursePrices: coursePrices ?? this.coursePrices,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  @override
  List<Object?> get props => [
    status,
    subjects,
    allTeachers,
    coursePrices,
    errorMessage,
  ];
}

// ═══════════════════════════════════════════════════════════════════════════
// BLOC
// ═══════════════════════════════════════════════════════════════════════════

class SubjectsBloc extends Bloc<SubjectsEvent, SubjectsState> {
  final SubjectsRepository _subjectsRepository;
  final TeachersRepository _teachersRepository;
  final String centerId;

  SubjectsBloc({
    required SubjectsRepository subjectsRepository,
    required TeachersRepository teachersRepository,
    required this.centerId,
  }) : _subjectsRepository = subjectsRepository,
       _teachersRepository = teachersRepository,
       super(const SubjectsState()) {
    on<LoadSubjects>(_onLoadSubjects);
    on<AddSubject>(_onAddSubject);
    on<UpdateSubject>(_onUpdateSubject);
    on<DeleteSubject>(_onDeleteSubject);
  }

  void _onLoadSubjects(LoadSubjects event, Emitter<SubjectsState> emit) async {
    emit(state.copyWith(status: SubjectsStatus.loading));
    try {
      final settingsRemote = SettingsRemoteSource();

      // Execute in parallel
      final results = await Future.wait([
        _subjectsRepository.getSubjects(),
        _teachersRepository.getTeachers(),
        settingsRemote.getCoursePrices(centerId),
      ]);

      final subjects = results[0] as List<Subject>;
      final teachers = results[1] as List<Teacher>;
      final prices = results[2] as List<CoursePrice>;

      emit(
        state.copyWith(
          status: SubjectsStatus.success,
          subjects: subjects,
          allTeachers: teachers,
          coursePrices: prices,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          status: SubjectsStatus.failure,
          errorMessage: e.toString(),
        ),
      );
    }
  }

  void _onAddSubject(AddSubject event, Emitter<SubjectsState> emit) async {
    try {
      await _subjectsRepository.addSubject(event.subject);
      add(LoadSubjects());
    } catch (e) {
      emit(
        state.copyWith(
          status: SubjectsStatus.failure,
          errorMessage: e.toString(),
        ),
      );
    }
  }

  void _onUpdateSubject(
    UpdateSubject event,
    Emitter<SubjectsState> emit,
  ) async {
    try {
      await _subjectsRepository.updateSubject(event.subject);
      add(LoadSubjects());
    } catch (e) {
      emit(
        state.copyWith(
          status: SubjectsStatus.failure,
          errorMessage: e.toString(),
        ),
      );
    }
  }

  void _onDeleteSubject(
    DeleteSubject event,
    Emitter<SubjectsState> emit,
  ) async {
    try {
      await _subjectsRepository.deleteSubject(event.subjectId);
      add(LoadSubjects());
    } catch (e) {
      emit(
        state.copyWith(
          status: SubjectsStatus.failure,
          errorMessage: e.toString(),
        ),
      );
    }
  }
}
