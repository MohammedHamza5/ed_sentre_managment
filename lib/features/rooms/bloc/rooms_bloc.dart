import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../../shared/models/models.dart';
import '../data/repositories/rooms_repository.dart';

// ═══════════════════════════════════════════════════════════════════════════
// EVENTS
// ═══════════════════════════════════════════════════════════════════════════

abstract class RoomsEvent extends Equatable {
  const RoomsEvent();
  @override
  List<Object?> get props => [];
}

class LoadRooms extends RoomsEvent {}

class AddRoom extends RoomsEvent {
  final Room room;
  const AddRoom(this.room);
  @override
  List<Object?> get props => [room];
}

class UpdateRoom extends RoomsEvent {
  final Room room;
  const UpdateRoom(this.room);
  @override
  List<Object?> get props => [room];
}

class DeleteRoom extends RoomsEvent {
  final String roomId;
  const DeleteRoom(this.roomId);
  @override
  List<Object?> get props => [roomId];
}

// ═══════════════════════════════════════════════════════════════════════════
// STATE
// ═══════════════════════════════════════════════════════════════════════════

enum RoomsStatus { initial, loading, success, failure }

class RoomsState extends Equatable {
  final RoomsStatus status;
  final List<Room> rooms;
  final String? errorMessage;

  const RoomsState({
    this.status = RoomsStatus.initial,
    this.rooms = const [],
    this.errorMessage,
  });

  RoomsState copyWith({
    RoomsStatus? status,
    List<Room>? rooms,
    String? errorMessage,
  }) {
    return RoomsState(
      status: status ?? this.status,
      rooms: rooms ?? this.rooms,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  @override
  List<Object?> get props => [status, rooms, errorMessage];
}

// ═══════════════════════════════════════════════════════════════════════════
// BLOC
// ═══════════════════════════════════════════════════════════════════════════

class RoomsBloc extends Bloc<RoomsEvent, RoomsState> {
  final RoomsRepository _repository;
  final String centerId;

  RoomsBloc({required RoomsRepository repository, required this.centerId})
      : _repository = repository,
        super(const RoomsState()) {
    on<LoadRooms>(_onLoadRooms);
    on<AddRoom>(_onAddRoom);
    on<UpdateRoom>(_onUpdateRoom);
    on<DeleteRoom>(_onDeleteRoom);
  }

  void _onLoadRooms(LoadRooms event, Emitter<RoomsState> emit) async {
    emit(state.copyWith(status: RoomsStatus.loading));
    try {
      final rooms = await _repository.getRooms();
      emit(state.copyWith(status: RoomsStatus.success, rooms: rooms));
    } catch (e) {
      emit(
        state.copyWith(status: RoomsStatus.failure, errorMessage: e.toString()),
      );
    }
  }

  void _onAddRoom(AddRoom event, Emitter<RoomsState> emit) async {
    try {
      await _repository.addRoom(event.room);
      add(LoadRooms());
    } catch (e) {
      emit(
        state.copyWith(status: RoomsStatus.failure, errorMessage: e.toString()),
      );
    }
  }

  void _onUpdateRoom(UpdateRoom event, Emitter<RoomsState> emit) async {
    try {
      await _repository.updateRoom(event.room);
      add(LoadRooms());
    } catch (e) {
      emit(
        state.copyWith(status: RoomsStatus.failure, errorMessage: e.toString()),
      );
    }
  }

  void _onDeleteRoom(DeleteRoom event, Emitter<RoomsState> emit) async {
    try {
      await _repository.deleteRoom(event.roomId);
      add(LoadRooms());
    } catch (e) {
      emit(
        state.copyWith(status: RoomsStatus.failure, errorMessage: e.toString()),
      );
    }
  }
}


