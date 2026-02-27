/// Sync Models for Offline-First Architecture
///
/// This file contains models that support the offline synchronization system
/// including sync queues, conflict resolution strategies, and sync operations.
library;

import 'package:equatable/equatable.dart';

/// Priority levels for sync operations
enum SyncPriority {
  /// High priority - critical data that should sync immediately
  high,

  /// Normal priority - standard data operations
  normal,

  /// Low priority - non-critical data that can sync later
  low,
}

/// Types of sync operations
enum SyncOperationType {
  /// Create a new record
  create,

  /// Update an existing record
  update,

  /// Delete a record
  delete,

  /// Sync all data (full sync)
  syncAll,
}

/// Status of a sync operation
enum SyncOperationStatus {
  /// Operation is queued and waiting to be processed
  pending,

  /// Operation is currently being processed
  inProgress,

  /// Operation completed successfully
  completed,

  /// Operation failed and needs to be retried
  failed,

  /// Operation was cancelled
  cancelled,
}

/// Conflict resolution strategies
enum ConflictResolutionStrategy {
  /// Last write wins - the most recent change is kept
  lastWriteWins,

  /// Server wins - server data takes precedence
  serverWins,

  /// Client wins - client data takes precedence
  clientWins,

  /// Manual resolution required
  manual,
}

/// Represents a single sync operation in the queue
class SyncOperation extends Equatable {
  /// Unique identifier for this operation
  final String id;

  /// Type of operation (create, update, delete)
  final SyncOperationType type;

  /// Table/entity being synchronized
  final String tableName;

  /// Record ID being operated on
  final String recordId;

  /// The data to be synced (serialized as JSON)
  final Map<String, dynamic> data;

  /// Priority of this operation
  final SyncPriority priority;

  /// Current status of the operation
  final SyncOperationStatus status;

  /// Number of retry attempts
  final int retryCount;

  /// Timestamp when the operation was created
  final DateTime createdAt;

  /// Timestamp when the operation was last attempted
  final DateTime? lastAttemptedAt;

  /// Timestamp when the operation was completed
  final DateTime? completedAt;

  /// Error message if the operation failed
  final String? errorMessage;

  const SyncOperation({
    required this.id,
    required this.type,
    required this.tableName,
    required this.recordId,
    required this.data,
    this.priority = SyncPriority.normal,
    this.status = SyncOperationStatus.pending,
    this.retryCount = 0,
    required this.createdAt,
    this.lastAttemptedAt,
    this.completedAt,
    this.errorMessage,
  });

  /// Create a copy of this operation with updated values
  SyncOperation copyWith({
    String? id,
    SyncOperationType? type,
    String? tableName,
    String? recordId,
    Map<String, dynamic>? data,
    SyncPriority? priority,
    SyncOperationStatus? status,
    int? retryCount,
    DateTime? createdAt,
    DateTime? lastAttemptedAt,
    DateTime? completedAt,
    String? errorMessage,
  }) {
    return SyncOperation(
      id: id ?? this.id,
      type: type ?? this.type,
      tableName: tableName ?? this.tableName,
      recordId: recordId ?? this.recordId,
      data: data ?? this.data,
      priority: priority ?? this.priority,
      status: status ?? this.status,
      retryCount: retryCount ?? this.retryCount,
      createdAt: createdAt ?? this.createdAt,
      lastAttemptedAt: lastAttemptedAt ?? this.lastAttemptedAt,
      completedAt: completedAt ?? this.completedAt,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  @override
  List<Object?> get props => [
    id,
    type,
    tableName,
    recordId,
    data,
    priority,
    status,
    retryCount,
    createdAt,
    lastAttemptedAt,
    completedAt,
    errorMessage,
  ];
}

/// Sync Queue Manager
///
/// Manages a queue of sync operations with priority-based processing
/// and retry mechanisms
class SyncQueue {
  final List<SyncOperation> _operations = [];

  /// Add a new operation to the queue
  void addOperation(SyncOperation operation) {
    _operations.add(operation);
    // Sort by priority (high to low) and then by creation time (oldest first)
    _operations.sort((a, b) {
      if (a.priority.index != b.priority.index) {
        return a.priority.index.compareTo(b.priority.index);
      }
      return a.createdAt.compareTo(b.createdAt);
    });
  }

  /// Get the next operation to process
  SyncOperation? getNextOperation() {
    final pendingOperations = _operations.where(
      (op) =>
          op.status == SyncOperationStatus.pending ||
          op.status == SyncOperationStatus.failed,
    );

    if (pendingOperations.isEmpty) return null;

    // Return the highest priority operation
    return pendingOperations.first;
  }

  /// Update an operation in the queue
  void updateOperation(SyncOperation updatedOperation) {
    final index = _operations.indexWhere((op) => op.id == updatedOperation.id);
    if (index != -1) {
      _operations[index] = updatedOperation;
    }
  }

  /// Remove a completed operation from the queue
  void removeOperation(String operationId) {
    _operations.removeWhere((op) => op.id == operationId);
  }

  /// Get all pending operations
  List<SyncOperation> getPendingOperations() {
    return _operations
        .where(
          (op) =>
              op.status == SyncOperationStatus.pending ||
              op.status == SyncOperationStatus.failed,
        )
        .toList();
  }

  /// Get count of pending operations
  int get pendingCount => _operations
      .where(
        (op) =>
            op.status == SyncOperationStatus.pending ||
            op.status == SyncOperationStatus.failed,
      )
      .length;

  /// Clear all completed operations
  void clearCompletedOperations() {
    _operations.removeWhere((op) => op.status == SyncOperationStatus.completed);
  }
}


