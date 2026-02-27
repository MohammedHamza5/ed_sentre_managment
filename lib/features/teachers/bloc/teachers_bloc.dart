import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../../core/providers/center_provider.dart';
import '../../../shared/models/models.dart';
import '../data/repositories/teachers_repository.dart';
import '../../subjects/data/repositories/subjects_repository.dart';

// ═══════════════════════════════════════════════════════════════════════════
// EVENTS
// ═══════════════════════════════════════════════════════════════════════════

abstract class TeachersEvent extends Equatable {
  const TeachersEvent();
  @override
  List<Object?> get props => [];
}

class LoadTeachers extends TeachersEvent {}

class AddTeacher extends TeachersEvent {
  final Teacher teacher;
  final bool force;
  const AddTeacher(this.teacher, {this.force = false});
  @override
  List<Object?> get props => [teacher, force];
}

class UpdateTeacher extends TeachersEvent {
  final Teacher teacher;
  const UpdateTeacher(this.teacher);
  @override
  List<Object?> get props => [teacher];
}

class DeleteTeacher extends TeachersEvent {
  final String teacherId;
  const DeleteTeacher(this.teacherId);
  @override
  List<Object?> get props => [teacherId];
}

class SearchTeachers extends TeachersEvent {
  final String query;
  const SearchTeachers(this.query);
  @override
  List<Object?> get props => [query];
}

class FilterTeachers extends TeachersEvent {
  final String? subjectId;
  const FilterTeachers({this.subjectId});
  @override
  List<Object?> get props => [subjectId];
}

class SortTeachers extends TeachersEvent {
  final String sortKey;
  final bool ascending;
  const SortTeachers(this.sortKey, {this.ascending = true});
  @override
  List<Object?> get props => [sortKey, ascending];
}

class DeactivateTeacher extends TeachersEvent {
  final String teacherId;
  const DeactivateTeacher(this.teacherId);
  @override
  List<Object?> get props => [teacherId];
}

class ReactivateTeacher extends TeachersEvent {
  final String teacherId;
  const ReactivateTeacher(this.teacherId);
  @override
  List<Object?> get props => [teacherId];
}

class ReassignAndDeactivate extends TeachersEvent {
  final String oldId;
  final String newId;
  const ReassignAndDeactivate(this.oldId, this.newId);
  @override
  List<Object?> get props => [oldId, newId];
}

class CheckDependencies extends TeachersEvent {
  final String teacherId;
  const CheckDependencies(this.teacherId);
  @override
  List<Object?> get props => [teacherId];
}

// ═══════════════════════════════════════════════════════════════════════════
// STATE
// ═══════════════════════════════════════════════════════════════════════════

enum TeachersStatus { initial, loading, success, failure, duplicateWarning }

class TeachersState extends Equatable {
  final TeachersStatus status;
  final List<Teacher> teachers;
  final List<Teacher> filteredTeachers;
  final List<Subject> allSubjects;
  final String searchQuery;
  final String? subjectFilter;
  final String? errorMessage;
  final String? sortKey;
  final bool sortAscending;

  const TeachersState({
    this.status = TeachersStatus.initial,
    this.teachers = const [],
    this.filteredTeachers = const [],
    this.allSubjects = const [],
    this.searchQuery = '',
    this.subjectFilter,
    this.errorMessage,
    this.sortKey,
    this.sortAscending = true,
    this.similarTeachers = const [],
    this.pendingTeacher,
    this.lastAction,
    this.teacherDependencies,
    this.addTeacherResult,
  });

  final List<Map<String, dynamic>> similarTeachers;
  final Teacher? pendingTeacher;
  final String? lastAction; // 'load', 'add', 'update', 'delete', 'check_deps'
  final Map<String, int>? teacherDependencies;
  final Map<String, dynamic>?
  addTeacherResult; // Contains teacher_code, teacher_id, phone

  TeachersState copyWith({
    TeachersStatus? status,
    List<Teacher>? teachers,
    List<Teacher>? filteredTeachers,
    List<Subject>? allSubjects,
    String? searchQuery,
    String? subjectFilter,
    String? errorMessage,
    String? sortKey,
    bool? sortAscending,
    List<Map<String, dynamic>>? similarTeachers,
    Teacher? pendingTeacher,
    String? lastAction,
    Map<String, int>? teacherDependencies,
    Map<String, dynamic>? addTeacherResult,
  }) {
    return TeachersState(
      status: status ?? this.status,
      teachers: teachers ?? this.teachers,
      filteredTeachers: filteredTeachers ?? this.filteredTeachers,
      allSubjects: allSubjects ?? this.allSubjects,
      searchQuery: searchQuery ?? this.searchQuery,
      subjectFilter: subjectFilter ?? this.subjectFilter,
      errorMessage: errorMessage,
      sortKey: sortKey ?? this.sortKey,
      sortAscending: sortAscending ?? this.sortAscending,
      similarTeachers: similarTeachers ?? this.similarTeachers,
      pendingTeacher: pendingTeacher ?? this.pendingTeacher,
      lastAction: lastAction ?? this.lastAction,
      teacherDependencies: teacherDependencies ?? this.teacherDependencies,
      addTeacherResult: addTeacherResult,
    );
  }

  @override
  List<Object?> get props => [
    status,
    teachers,
    filteredTeachers,
    allSubjects,
    searchQuery,
    subjectFilter,
    errorMessage,
    sortKey,
    sortAscending,
    similarTeachers,
    pendingTeacher,
    lastAction,
    teacherDependencies,
    addTeacherResult,
  ];
}

// ═══════════════════════════════════════════════════════════════════════════
// BLOC
// ═══════════════════════════════════════════════════════════════════════════

class TeachersBloc extends Bloc<TeachersEvent, TeachersState> {
  final TeachersRepository _repository;
  final SubjectsRepository _subjectsRepository;
  final CenterProvider _centerProvider;
  List<Teacher> _allTeachers = [];

  TeachersBloc({
    required TeachersRepository teachersRepository,
    required SubjectsRepository subjectsRepository,
    required CenterProvider centerProvider,
  }) : _repository = teachersRepository,
       _subjectsRepository = subjectsRepository,
       _centerProvider = centerProvider,
       super(const TeachersState()) {
    on<LoadTeachers>(_onLoadTeachers);
    on<SearchTeachers>(_onSearchTeachers);
    on<FilterTeachers>(_onFilterTeachers);
    on<SortTeachers>(_onSortTeachers);
    on<AddTeacher>(_onAddTeacher);
    on<UpdateTeacher>(_onUpdateTeacher);
    on<DeleteTeacher>(_onDeleteTeacher);
    on<DeactivateTeacher>(_onDeactivateTeacher);
    on<ReactivateTeacher>(_onReactivateTeacher);
    on<ReassignAndDeactivate>(_onReassignAndDeactivate);
    on<CheckDependencies>(_onCheckDependencies);

    // Listen to Center Changes
    _centerProvider.addListener(_onCenterChanged);

    // تحميل البيانات إذا كان المركز موجوداً بالفعل
    if (_centerProvider.hasCenter) {
      add(LoadTeachers());
    }
  }

  @override
  Future<void> close() {
    _centerProvider.removeListener(_onCenterChanged);
    return super.close();
  }

  void _onCenterChanged() {
    if (_centerProvider.hasCenter) {
      add(LoadTeachers());
    }
  }

  void _onLoadTeachers(LoadTeachers event, Emitter<TeachersState> emit) async {
    if (!_centerProvider.hasCenter) {
      emit(
        state.copyWith(status: TeachersStatus.initial),
      ); // Or specific "No Center" status
      return;
    }

    emit(state.copyWith(status: TeachersStatus.loading));
    try {
      final results = await Future.wait([
        _repository.getTeachers(),
        _subjectsRepository.getSubjects(),
      ]);
      _allTeachers = results[0] as List<Teacher>;
      final subjects = results[1] as List<Subject>;

      emit(
        state.copyWith(
          status: TeachersStatus.success,
          teachers: _allTeachers,
          filteredTeachers: _allTeachers,
          allSubjects: subjects,
          lastAction: 'load',
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          status: TeachersStatus.failure,
          errorMessage: e.toString(),
        ),
      );
    }
  }

  void _onSearchTeachers(SearchTeachers event, Emitter<TeachersState> emit) {
    final query = event.query.toLowerCase();
    final filtered = _applyFilters(
      query: query,
      subjectId: state.subjectFilter,
    );
    final sorted = _sortTeachers(filtered, state.sortKey, state.sortAscending);

    emit(state.copyWith(searchQuery: event.query, filteredTeachers: sorted));
  }

  void _onFilterTeachers(FilterTeachers event, Emitter<TeachersState> emit) {
    final filtered = _applyFilters(
      query: state.searchQuery.toLowerCase(),
      subjectId: event.subjectId,
    );
    final sorted = _sortTeachers(filtered, state.sortKey, state.sortAscending);

    emit(
      state.copyWith(subjectFilter: event.subjectId, filteredTeachers: sorted),
    );
  }

  void _onSortTeachers(SortTeachers event, Emitter<TeachersState> emit) {
    final sorted = _sortTeachers(
      state.filteredTeachers,
      event.sortKey,
      event.ascending,
    );

    emit(
      state.copyWith(
        sortKey: event.sortKey,
        sortAscending: event.ascending,
        filteredTeachers: sorted,
      ),
    );
  }

  List<Teacher> _applyFilters({required String query, String? subjectId}) {
    return _allTeachers.where((teacher) {
      // Search filter (name, phone, email)
      if (query.isNotEmpty) {
        if (!teacher.name.toLowerCase().contains(query) &&
            !teacher.phone.contains(query) &&
            !(teacher.email?.toLowerCase().contains(query) ?? false)) {
          return false;
        }
      }

      // Subject filter
      if (subjectId != null && subjectId.isNotEmpty) {
        if (!teacher.subjectIds.contains(subjectId)) {
          return false;
        }
      }

      return true;
    }).toList();
  }

  List<Teacher> _sortTeachers(
    List<Teacher> teachers,
    String? sortKey,
    bool ascending,
  ) {
    if (sortKey == null || sortKey.isEmpty) return teachers;

    var sorted = List<Teacher>.from(teachers);

    switch (sortKey) {
      case 'name':
        sorted.sort((a, b) => a.name.compareTo(b.name));
        break;
      case 'email':
        sorted.sort((a, b) => (a.email ?? '').compareTo(b.email ?? ''));
        break;
      case 'phone':
        sorted.sort((a, b) => a.phone.compareTo(b.phone));
        break;
    }

    return ascending ? sorted : sorted.reversed.toList();
  }

  void _onAddTeacher(AddTeacher event, Emitter<TeachersState> emit) async {
    debugPrint('\n${'=' * 60}');
    debugPrint('[TEACHER_FLOW] بدء عملية إضافة معلم جديد');
    debugPrint('[TEACHER_FLOW] اسم المعلم: ${event.teacher.name}');
    debugPrint('[TEACHER_FLOW] رقم الهاتف: ${event.teacher.phone}');
    debugPrint('[TEACHER_FLOW] المواد: ${event.teacher.subjectIds}');
    debugPrint('[TEACHER_FLOW] force: ${event.force}');
    debugPrint('${'=' * 60}\n');

    try {
      // TODO: Re-enable duplicate check when findSimilarTeachers is implemented in TeachersRepository
      // if (!event.force) {
      //   debugPrint('[TEACHER_FLOW] جاري التحقق من الأسماء المشابهة...');
      //   final similar = await _repository.findSimilarTeachers(
      //     event.teacher.name,
      //   );
      //   if (similar.isNotEmpty) {
      //     debugPrint(
      //       '[TEACHER_FLOW] ⚠️ تم العثور على ${similar.length} أسماء مشابهة',
      //     );
      //     emit(
      //       state.copyWith(
      //         status: TeachersStatus.duplicateWarning,
      //         similarTeachers: similar,
      //         pendingTeacher: event.teacher,
      //       ),
      //     );
      //     return;
      //   }
      //   debugPrint('[TEACHER_FLOW] ✅ لا توجد أسماء مشابهة');
      // }

      debugPrint('[TEACHER_FLOW] جاري إضافة المعلم إلى قاعدة البيانات...');
      emit(
        state.copyWith(status: TeachersStatus.loading, pendingTeacher: null),
      );

      final result = await _repository.addTeacher(event.teacher);

      debugPrint('\n${'=' * 60}');
      debugPrint('[TEACHER_FLOW] ✅ تمت إضافة المعلم بنجاح!');
      debugPrint('[TEACHER_FLOW] النتيجة المرجعة:');
      debugPrint('[TEACHER_FLOW]   - teacher_id: ${result['teacher_id']}');
      debugPrint('[TEACHER_FLOW]   - teacher_code: ${result['teacher_code']}');
      debugPrint('[TEACHER_FLOW]   - phone: ${result['phone']}');
      debugPrint('${'=' * 60}\n');

      // إرسال حالة النجاح أولاً لإغلاق الديالوج وعرض الكود
      emit(
        state.copyWith(
          status: TeachersStatus.success,
          lastAction: 'add',
          addTeacherResult: result,
        ),
      );
      debugPrint('[TEACHER_FLOW] تم إرسال النتيجة إلى UI لعرض كود الدعوة');

      // تحديث قائمة المعلمين في الخلفية (بعد تأخير قصير)
      Future.delayed(const Duration(milliseconds: 500), () {
        add(LoadTeachers());
      });

      _centerProvider.refreshCounts(); // إخطار CenterProvider
    } catch (e) {
      emit(
        state.copyWith(
          status: TeachersStatus.failure,
          errorMessage: e.toString(),
        ),
      );
    }
  }

  void _onUpdateTeacher(
    UpdateTeacher event,
    Emitter<TeachersState> emit,
  ) async {
    try {
      await _repository.updateTeacher(event.teacher);
      add(LoadTeachers());
    } catch (e) {
      emit(
        state.copyWith(
          status: TeachersStatus.failure,
          errorMessage: e.toString(),
        ),
      );
    }
  }

  Future<void> _onDeleteTeacher(
    DeleteTeacher event,
    Emitter<TeachersState> emit,
  ) async {
    try {
      await _repository.deleteTeacher(event.teacherId);
      add(LoadTeachers());
      emit(
        state.copyWith(status: TeachersStatus.success, lastAction: 'delete'),
      );
    } catch (e) {
      emit(
        state.copyWith(
          status: TeachersStatus.failure,
          errorMessage: e.toString(),
        ),
      );
    }
  }

  Future<void> _onDeactivateTeacher(
    DeactivateTeacher event,
    Emitter<TeachersState> emit,
  ) async {
    debugPrint('\n${'=' * 60}');
    debugPrint('[TEACHER_FLOW] 🛑 طلب إيقاف المعلم');
    debugPrint('[TEACHER_FLOW] Teacher ID: ${event.teacherId}');
    try {
      await _repository.deactivateTeacher(event.teacherId);
      debugPrint('[TEACHER_FLOW] ✅ تم إيقاف المعلم بنجاح (Backend Updated)');
      add(LoadTeachers());
      emit(
        state.copyWith(
          status: TeachersStatus.success,
          lastAction: 'deactivate',
        ),
      );
      debugPrint('${'=' * 60}\n');
    } catch (e) {
      emit(
        state.copyWith(
          status: TeachersStatus.failure,
          errorMessage: e.toString(),
        ),
      );
    }
  }

  Future<void> _onReactivateTeacher(
    ReactivateTeacher event,
    Emitter<TeachersState> emit,
  ) async {
    debugPrint('\n${'=' * 60}');
    debugPrint('[TEACHER_FLOW] ▶️ طلب تنشيط المعلم');
    debugPrint('[TEACHER_FLOW] Teacher ID: ${event.teacherId}');
    try {
      await _repository.reactivateTeacher(event.teacherId);
      debugPrint('[TEACHER_FLOW] ✅ تم تنشيط المعلم بنجاح (Backend Updated)');
      add(LoadTeachers());
      emit(
        state.copyWith(
          status: TeachersStatus.success,
          lastAction: 'reactivate',
        ),
      );
      debugPrint('${'=' * 60}\n');
    } catch (e) {
      emit(
        state.copyWith(
          status: TeachersStatus.failure,
          errorMessage: e.toString(),
        ),
      );
    }
  }

  Future<void> _onReassignAndDeactivate(
    ReassignAndDeactivate event,
    Emitter<TeachersState> emit,
  ) async {
    debugPrint('\n${'=' * 60}');
    debugPrint('[TEACHER_FLOW] 🔄 طلب نقل مجموعات وإيقاف المعلم');
    debugPrint('[TEACHER_FLOW] Old ID: ${event.oldId}');
    debugPrint('[TEACHER_FLOW] New ID: ${event.newId}');
    try {
      emit(state.copyWith(status: TeachersStatus.loading));
      await _repository.reassignTeacherGroups(event.oldId, event.newId);
      debugPrint('[TEACHER_FLOW] ✅ تم نقل المجموعات');
      
      await _repository.deactivateTeacher(event.oldId);
      debugPrint('[TEACHER_FLOW] ✅ تم إيقاف المعلم القديم');
      
      add(LoadTeachers());
      emit(
        state.copyWith(
          status: TeachersStatus.success,
          lastAction: 'reassign_deactivate',
        ),
      );
      debugPrint('${'=' * 60}\n');
    } catch (e) {
      emit(
        state.copyWith(
          status: TeachersStatus.failure,
          errorMessage: e.toString(),
        ),
      );
    }
  }

  Future<void> _onCheckDependencies(
    CheckDependencies event,
    Emitter<TeachersState> emit,
  ) async {
    try {
      emit(state.copyWith(status: TeachersStatus.loading));
      final deps = await _repository.getTeacherDependencies(event.teacherId);
      emit(
        state.copyWith(
          status: TeachersStatus.success,
          teacherDependencies: deps,
          lastAction: 'check_deps',
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          status: TeachersStatus.failure,
          errorMessage: e.toString(),
        ),
      );
    }
  }
}


