import 'dart:ui' show VoidCallback;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../../shared/models/models.dart';
import '../data/repositories/students_repository.dart';

// ═══════════════════════════════════════════════════════════════════════════
// EVENTS - أحداث الطلاب
// ═══════════════════════════════════════════════════════════════════════════

abstract class StudentsEvent extends Equatable {
  const StudentsEvent();

  @override
  List<Object?> get props => [];
}

class LoadStudents extends StudentsEvent {
  final bool refresh;
  const LoadStudents({this.refresh = false});
  @override
  List<Object?> get props => [refresh];
}

class LoadMoreStudents extends StudentsEvent {}

class SearchStudents extends StudentsEvent {
  final String query;
  const SearchStudents(this.query);

  @override
  List<Object?> get props => [query];
}

class FilterStudents extends StudentsEvent {
  final StudentStatus? status;
  final String? stage;
  final String? subjectId;

  const FilterStudents({this.status, this.stage, this.subjectId});

  @override
  List<Object?> get props => [status, stage, subjectId];
}

class SortStudents extends StudentsEvent {
  final String sortKey;
  final bool ascending;

  const SortStudents(this.sortKey, {this.ascending = true});

  @override
  List<Object?> get props => [sortKey, ascending];
}

class AddStudent extends StudentsEvent {
  final Student student;
  const AddStudent(this.student);

  @override
  List<Object?> get props => [student];
}

class UpdateStudent extends StudentsEvent {
  final Student student;
  const UpdateStudent(this.student);

  @override
  List<Object?> get props => [student];
}

class DeleteStudent extends StudentsEvent {
  final String studentId;
  const DeleteStudent(this.studentId);

  @override
  List<Object?> get props => [studentId];
}

// ═══════════════════════════════════════════════════════════════════════════
// STATE - حالة الطلاب
// ═══════════════════════════════════════════════════════════════════════════

enum StudentsStatus { initial, loading, success, failure }

class StudentsState extends Equatable {
  final StudentsStatus status;
  final List<Student> students;
  final List<Student> filteredStudents;
  final String searchQuery;
  final StudentStatus? statusFilter;
  final String? stageFilter;
  final String? subjectFilter;
  final String? errorMessage;
  final String? sortKey;
  final bool sortAscending;

  const StudentsState({
    this.status = StudentsStatus.initial,
    this.students = const [],
    this.filteredStudents = const [],
    this.searchQuery = '',
    this.statusFilter,
    this.stageFilter,
    this.subjectFilter,
    this.errorMessage,
    this.sortKey,
    this.sortAscending = true,
    this.hasReachedMax = false,
    this.currentPage = 1,
    this.isLoadingMore = false,
  });

  final bool hasReachedMax;
  final int currentPage;
  final bool isLoadingMore;

  StudentsState copyWith({
    StudentsStatus? status,
    List<Student>? students,
    List<Student>? filteredStudents,
    String? searchQuery,
    StudentStatus? statusFilter,
    String? stageFilter,
    String? subjectFilter,
    String? errorMessage,
    String? sortKey,
    bool? sortAscending,
    bool? hasReachedMax,
    int? currentPage,
    bool? isLoadingMore,
  }) {
    return StudentsState(
      status: status ?? this.status,
      students: students ?? this.students,
      filteredStudents: filteredStudents ?? this.filteredStudents,
      searchQuery: searchQuery ?? this.searchQuery,
      statusFilter: statusFilter,
      stageFilter: stageFilter,
      subjectFilter: subjectFilter,
      errorMessage: errorMessage ?? this.errorMessage,
      sortKey: sortKey ?? this.sortKey,
      sortAscending: sortAscending ?? this.sortAscending,
      hasReachedMax: hasReachedMax ?? this.hasReachedMax,
      currentPage: currentPage ?? this.currentPage,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    );
  }

  @override
  List<Object?> get props => [
    status,
    students,
    filteredStudents,
    searchQuery,
    statusFilter,
    stageFilter,
    subjectFilter,
    sortKey,
    sortAscending,
    hasReachedMax,
    currentPage,
    isLoadingMore,
  ];

  int get activeCount =>
      students.where((s) => s.status == StudentStatus.active).length;
  int get suspendedCount =>
      students.where((s) => s.status == StudentStatus.suspended).length;
  int get overdueCount =>
      students.where((s) => s.status == StudentStatus.overdue).length;
}

// ═══════════════════════════════════════════════════════════════════════════
// BLOC - Students Bloc
// ═══════════════════════════════════════════════════════════════════════════

class StudentsBloc extends Bloc<StudentsEvent, StudentsState> {
  final StudentsRepository _repo;
  final String centerId;
  final VoidCallback? onDataChanged;
  List<Student> _allStudents = [];

  StudentsBloc(this._repo, this.centerId, {this.onDataChanged})
    : super(const StudentsState()) {
    on<LoadStudents>(_onLoadStudents);
    on<LoadMoreStudents>(_onLoadMoreStudents);
    on<SearchStudents>(_onSearchStudents);
    on<FilterStudents>(_onFilterStudents);
    on<SortStudents>(_onSortStudents);
    on<AddStudent>(_onAddStudent);
    on<UpdateStudent>(_onUpdateStudent);
    on<DeleteStudent>(_onDeleteStudent);
  }

  static const int _pageSize = 20;

  void _onLoadStudents(LoadStudents event, Emitter<StudentsState> emit) async {
    if (event.refresh) {
      emit(
        state.copyWith(
          status: StudentsStatus.loading,
          hasReachedMax: false,
          currentPage: 1,
          students: [],
        ),
      );
      _allStudents = [];
    } else {
      emit(state.copyWith(status: StudentsStatus.loading));
    }

    try {
      final students = await _repo.getStudents(
        page: 1,
        limit: _pageSize,
        searchQuery: state.searchQuery,
        status: state.statusFilter?.name,
        gradeLevel: state.stageFilter == 'الكل' ? null : state.stageFilter,
      );
      _allStudents = students;

      // Local sort of the fetched page
      final sorted = _sortStudents(
        _allStudents,
        state.sortKey,
        state.sortAscending,
      );

      emit(
        state.copyWith(
          status: StudentsStatus.success,
          students: sorted,
          filteredStudents: sorted,
          hasReachedMax: students.length < _pageSize,
          currentPage: 1,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          status: StudentsStatus.failure,
          errorMessage: e.toString(),
        ),
      );
    }
  }

  void _onLoadMoreStudents(
    LoadMoreStudents event,
    Emitter<StudentsState> emit,
  ) async {
    if (state.hasReachedMax || state.isLoadingMore) return;

    emit(state.copyWith(isLoadingMore: true));

    try {
      final nextPage = state.currentPage + 1;
      final newStudents = await _repo.getStudents(
        page: nextPage,
        limit: _pageSize,
        searchQuery: state.searchQuery,
        status: state.statusFilter?.name,
        gradeLevel: state.stageFilter == 'الكل' ? null : state.stageFilter,
      );

      if (newStudents.isEmpty) {
        emit(state.copyWith(hasReachedMax: true, isLoadingMore: false));
      } else {
        _allStudents.addAll(newStudents);

        final sorted = _sortStudents(
          _allStudents,
          state.sortKey,
          state.sortAscending,
        );

        emit(
          state.copyWith(
            students: sorted,
            filteredStudents: sorted,
            hasReachedMax: newStudents.length < _pageSize,
            currentPage: nextPage,
            isLoadingMore: false,
          ),
        );
      }
    } catch (e) {
      emit(
        state.copyWith(
          isLoadingMore: false,
          errorMessage: "Failed to load more students: $e",
        ),
      );
    }
  }

  // Remove _applyAndSort usage as we now fetch filtered data
  // Only sort is local

  void _onSearchStudents(
    SearchStudents event,
    Emitter<StudentsState> emit,
  ) async {
    // Search triggers a new server fetch to reset pagination
    emit(
      state.copyWith(
        status: StudentsStatus.loading,
        searchQuery: event.query,
        currentPage: 1,
        hasReachedMax: false,
      ),
    );

    try {
      final students = await _repo.getStudents(
        page: 1,
        limit: _pageSize,
        searchQuery: event.query,
        status: state.statusFilter?.name,
        gradeLevel: state.stageFilter == 'الكل' ? null : state.stageFilter,
      );
      _allStudents = students;

      final sorted = _sortStudents(
        _allStudents,
        state.sortKey,
        state.sortAscending,
      );

      emit(
        state.copyWith(
          status: StudentsStatus.success,
          students: sorted,
          filteredStudents: sorted,
          hasReachedMax: students.length < _pageSize,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          status: StudentsStatus.failure,
          errorMessage: e.toString(),
        ),
      );
    }
  }

  void _onFilterStudents(
    FilterStudents event,
    Emitter<StudentsState> emit,
  ) async {
    emit(
      state.copyWith(
        status: StudentsStatus.loading,
        statusFilter: event.status, // Update filters in state FIRST
        stageFilter: event.stage,
        subjectFilter: event.subjectId,
        currentPage: 1,
        hasReachedMax: false,
      ),
    );

    try {
      // Fetch with NEW filters from event
      final students = await _repo.getStudents(
        page: 1,
        limit: _pageSize,
        searchQuery: state.searchQuery,
        status: event.status?.name,
        gradeLevel: (event.stage == 'الكل') ? null : event.stage,
      );
      _allStudents = students;

      final sorted = _sortStudents(
        _allStudents,
        state.sortKey,
        state.sortAscending,
      );

      emit(
        state.copyWith(
          status: StudentsStatus.success,
          students: sorted,
          filteredStudents: sorted,
          hasReachedMax: students.length < _pageSize,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          status: StudentsStatus.failure,
          errorMessage: e.toString(),
        ),
      );
    }
  }

  void _onSortStudents(SortStudents event, Emitter<StudentsState> emit) {
    final sorted = _sortStudents(
      state.filteredStudents,
      event.sortKey,
      event.ascending,
    );

    emit(
      state.copyWith(
        sortKey: event.sortKey,
        sortAscending: event.ascending,
        filteredStudents: sorted,
      ),
    );
  }

  List<Student> _applyFilters({
    required String query,
    StudentStatus? status,
    String? stage,
  }) {
    return _allStudents.where((student) {
      // Search filter
      if (query.isNotEmpty) {
        if (!student.name.toLowerCase().contains(query) &&
            !student.phone.contains(query)) {
          return false;
        }
      }

      // Status filter
      if (status != null && student.status != status) {
        return false;
      }

      // Stage filter
      if (stage != null && stage != 'الكل' && student.stage != stage) {
        return false;
      }

      return true;
    }).toList();
  }

  List<Student> _sortStudents(
    List<Student> students,
    String? sortKey,
    bool ascending,
  ) {
    if (sortKey == null || sortKey.isEmpty) return students;

    var sorted = List<Student>.from(students);

    switch (sortKey) {
      case 'name':
        sorted.sort((a, b) => a.name.compareTo(b.name));
        break;
      case 'stage':
        sorted.sort((a, b) => a.stage.compareTo(b.stage));
        break;
      case 'created_at':
        sorted.sort((a, b) => a.id.compareTo(b.id));
        break;
    }

    return ascending ? sorted : sorted.reversed.toList();
  }

  Future<void> _onAddStudent(
    AddStudent event,
    Emitter<StudentsState> emit,
  ) async {
    try {
      await _repo.addStudent(event.student);
      _allStudents = await _repo
          .getStudents(); // Refresh from DB to get ID/Dates correct

      final filtered = _applyFilters(
        query: state.searchQuery.toLowerCase(),
        status: state.statusFilter,
        stage: state.stageFilter,
      );

      emit(
        state.copyWith(
          students: dbListToMutable(_allStudents),
          filteredStudents: filtered,
        ),
      );

      // إخطار CenterProvider لتحديث العدادات
      onDataChanged?.call();
    } catch (e) {
      // Handle error
    }
  }

  Future<void> _onUpdateStudent(
    UpdateStudent event,
    Emitter<StudentsState> emit,
  ) async {
    try {
      await _repo.updateStudent(event.student);
      // Update local list
      final index = _allStudents.indexWhere((s) => s.id == event.student.id);
      if (index != -1) {
        _allStudents[index] = event.student;
      }

      final filtered = _applyFilters(
        query: state.searchQuery.toLowerCase(),
        status: state.statusFilter,
        stage: state.stageFilter,
      );

      emit(
        state.copyWith(
          students: dbListToMutable(_allStudents),
          filteredStudents: filtered,
        ),
      );
    } catch (e) {
      // Handle error
    }
  }

  Future<void> _onDeleteStudent(
    DeleteStudent event,
    Emitter<StudentsState> emit,
  ) async {
    try {
      await _repo.deleteStudent(event.studentId);
      _allStudents.removeWhere((s) => s.id == event.studentId);

      final filtered = _applyFilters(
        query: state.searchQuery.toLowerCase(),
        status: state.statusFilter,
        stage: state.stageFilter,
      );

      emit(
        state.copyWith(
          students: dbListToMutable(_allStudents),
          filteredStudents: filtered,
        ),
      );

      // إخطار CenterProvider لتحديث العدادات
      onDataChanged?.call();
    } catch (e) {
      // Handle error
    }
  }

  List<Student> dbListToMutable(List<Student> list) {
    return List.from(list);
  }
}
