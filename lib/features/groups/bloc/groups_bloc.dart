import 'dart:ui' show VoidCallback;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../../shared/models/models.dart';
import '../data/repositories/groups_repository.dart';

// ═══════════════════════════════════════════════════════════════════════════
// EVENTS
// ═══════════════════════════════════════════════════════════════════════════

abstract class GroupsEvent extends Equatable {
  const GroupsEvent();
  @override
  List<Object?> get props => [];
}

class LoadGroups extends GroupsEvent {}

class SearchGroups extends GroupsEvent {
  final String query;
  const SearchGroups(this.query);
  @override
  List<Object?> get props => [query];
}

class AddGroup extends GroupsEvent {
  final Group group;
  const AddGroup(this.group);
  @override
  List<Object?> get props => [group];
}

class UpdateGroup extends GroupsEvent {
  final Group group;
  const UpdateGroup(this.group);
  @override
  List<Object?> get props => [group];
}

class DeleteGroup extends GroupsEvent {
  final String groupId;
  const DeleteGroup(this.groupId);
  @override
  List<Object?> get props => [groupId];
}

// ═══════════════════════════════════════════════════════════════════════════
// STATE
// ═══════════════════════════════════════════════════════════════════════════

enum GroupsStatus { initial, loading, success, failure }

class GroupsState extends Equatable {
  final GroupsStatus status;
  final List<Group> groups;
  final List<Group> filteredGroups;
  final String searchQuery;
  final String? errorMessage;

  const GroupsState({
    this.status = GroupsStatus.initial,
    this.groups = const [],
    this.filteredGroups = const [],
    this.searchQuery = '',
    this.errorMessage,
  });

  GroupsState copyWith({
    GroupsStatus? status,
    List<Group>? groups,
    List<Group>? filteredGroups,
    String? searchQuery,
    String? errorMessage,
  }) {
    return GroupsState(
      status: status ?? this.status,
      groups: groups ?? this.groups,
      filteredGroups: filteredGroups ?? this.filteredGroups,
      searchQuery: searchQuery ?? this.searchQuery,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  @override
  List<Object?> get props => [
    status,
    groups,
    filteredGroups,
    searchQuery,
    errorMessage,
  ];
}

// ═══════════════════════════════════════════════════════════════════════════
// BLOC
// ═══════════════════════════════════════════════════════════════════════════

class GroupsBloc extends Bloc<GroupsEvent, GroupsState> {
  final GroupsRepository _repository;
  final String centerId;
  final VoidCallback? onDataChanged;
  List<Group> _allGroups = [];

  GroupsBloc({
    required GroupsRepository groupsRepository,
    required this.centerId,
    this.onDataChanged,
  }) : _repository = groupsRepository,
       super(const GroupsState()) {
    on<LoadGroups>(_onLoadGroups);
    on<SearchGroups>(_onSearchGroups);
    on<AddGroup>(_onAddGroup);
    on<UpdateGroup>(_onUpdateGroup);
    on<DeleteGroup>(_onDeleteGroup);
  }

  void _onLoadGroups(LoadGroups event, Emitter<GroupsState> emit) async {
    emit(state.copyWith(status: GroupsStatus.loading));
    try {
      _allGroups = await _repository.getGroups();
      emit(
        state.copyWith(
          status: GroupsStatus.success,
          groups: _allGroups,
          filteredGroups: _allGroups,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          status: GroupsStatus.failure,
          errorMessage: e.toString(),
        ),
      );
    }
  }

  void _onSearchGroups(SearchGroups event, Emitter<GroupsState> emit) {
    final query = event.query.toLowerCase();
    final filtered = _allGroups.where((group) {
      return group.groupName.toLowerCase().contains(query) ||
          (group.teacherName?.toLowerCase().contains(query) ?? false) ||
          (group.courseName?.toLowerCase().contains(query) ?? false);
    }).toList();

    emit(state.copyWith(searchQuery: event.query, filteredGroups: filtered));
  }

  void _onAddGroup(AddGroup event, Emitter<GroupsState> emit) async {
    try {
      await _repository.addGroup(event.group);
      add(LoadGroups());
      onDataChanged?.call(); // إخطار CenterProvider
    } catch (e) {
      emit(
        state.copyWith(
          status: GroupsStatus.failure,
          errorMessage: e.toString(),
        ),
      );
    }
  }

  void _onUpdateGroup(UpdateGroup event, Emitter<GroupsState> emit) async {
    try {
      await _repository.updateGroup(event.group);
      add(LoadGroups());
    } catch (e) {
      emit(
        state.copyWith(
          status: GroupsStatus.failure,
          errorMessage: e.toString(),
        ),
      );
    }
  }

  void _onDeleteGroup(DeleteGroup event, Emitter<GroupsState> emit) async {
    try {
      await _repository.deleteGroup(event.groupId);
      add(LoadGroups());
      onDataChanged?.call(); // إخطار CenterProvider
    } catch (e) {
      emit(
        state.copyWith(
          status: GroupsStatus.failure,
          errorMessage: e.toString(),
        ),
      );
    }
  }
}


