import 'dart:async';
import 'dart:math';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:drift/drift.dart';
import '../database/app_database.dart';
import '../supabase/supabase_client.dart';
import 'sync_models.dart';
import '../../shared/models/models.dart' as domain;
import '../../features/students/data/sources/students_remote_source.dart';
import '../../features/teachers/data/sources/teachers_remote_source.dart';
import '../../features/subjects/data/sources/subjects_remote_source.dart';
import '../../features/schedule/data/sources/schedule_remote_source.dart';
import '../../features/attendance/data/sources/attendance_remote_source.dart';
import '../../features/payments/data/sources/payments_remote_source.dart';
import '../../features/rooms/data/sources/rooms_remote_source.dart';

/// Sync Status
enum SyncStatus {
  idle, // لا توجد مزامنة
  syncing, // جاري المزامنة
  success, // نجحت المزامنة
  failed, // فشلت المزامنة
  conflict, // يوجد تعارض
}

/// Sync Service - handles offline-first synchronization
class SyncService extends ChangeNotifier {
  final AppDatabase _db;
  final SyncQueue _syncQueue = SyncQueue();

  SyncStatus _status = SyncStatus.idle;
  String? _lastError;
  DateTime? _lastSyncTime;
  int _pendingChanges = 0;
  StreamSubscription? _authSubscription;
  Timer? _syncTimer;

  SyncStatus get status => _status;
  String? get lastError => _lastError;
  DateTime? get lastSyncTime => _lastSyncTime;
  int get pendingChanges => _pendingChanges;
  bool get isSyncing => _status == SyncStatus.syncing;
  bool get hasPendingChanges => _pendingChanges > 0;

  SyncService(this._db);

  /// Get current center ID from authenticated user
  Future<String?> _getCenterId() async {
    try {
      final userId = SupabaseClientManager.currentUser?.id;
      if (userId == null) return null;

      final result = await SupabaseClientManager.client
          .from('center_staff')
          .select('center_id')
          .eq('user_id', userId)
          .maybeSingle();

      return result?['center_id'] as String?;
    } catch (e) {
      debugPrint('❌ [SyncService] Error getting center ID: $e');
      return null;
    }
  }

  /// Initialize sync service
  Future<void> initialize() async {
    await _countPendingChanges();

    // Listen to auth changes - only sync once on login
    _authSubscription = SupabaseClientManager.onAuthStateChange.listen((
      authState,
    ) {
      if (authState.session != null && authState.event == 'SIGNED_IN') {
        // User just logged in - trigger initial sync
        syncAll();

        // Start periodic sync every 5 minutes
        _startPeriodicSync();
      } else if (authState.event == 'SIGNED_OUT') {
        // Stop periodic sync on logout
        _stopPeriodicSync();
      }
    });
  }

  /// Start periodic background sync
  void _startPeriodicSync() {
    _stopPeriodicSync(); // Cancel any existing timer

    _syncTimer = Timer.periodic(const Duration(minutes: 5), (timer) {
      if (SupabaseClientManager.currentUser != null &&
          _status != SyncStatus.syncing) {
        syncAll();
      }
    });
  }

  /// Stop periodic sync
  void _stopPeriodicSync() {
    _syncTimer?.cancel();
    _syncTimer = null;
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    _stopPeriodicSync();
    super.dispose();
  }

  /// Count all pending changes (not synced)
  Future<void> _countPendingChanges() async {
    try {
      // Count unsynced records from each table
      final studentCount =
          await (_db.select(_db.students)
                ..where((row) => row.isSynced.equals(false)))
              .get()
              .then((list) => list.length);

      final teacherCount =
          await (_db.select(_db.teachers)
                ..where((row) => row.isSynced.equals(false)))
              .get()
              .then((list) => list.length);

      final subjectCount =
          await (_db.select(_db.subjects)
                ..where((row) => row.isSynced.equals(false)))
              .get()
              .then((list) => list.length);

      final roomCount =
          await (_db.select(_db.rooms)
                ..where((row) => row.isSynced.equals(false)))
              .get()
              .then((list) => list.length);

      final sessionCount =
          await (_db.select(_db.sessions)
                ..where((row) => row.isSynced.equals(false)))
              .get()
              .then((list) => list.length);

      final paymentCount =
          await (_db.select(_db.payments)
                ..where((row) => row.isSynced.equals(false)))
              .get()
              .then((list) => list.length);

      final attendanceCount =
          await (_db.select(_db.attendance)
                ..where((row) => row.isSynced.equals(false)))
              .get()
              .then((list) => list.length);

      _pendingChanges =
          studentCount +
          teacherCount +
          subjectCount +
          roomCount +
          sessionCount +
          paymentCount +
          attendanceCount;

      notifyListeners();
    } catch (e) {
      debugPrint('Error counting pending changes: $e');
    }
  }

  /// Sync all tables
  Future<void> syncAll() async {
    if (_status == SyncStatus.syncing) {
      debugPrint('⚠️ Sync already in progress, skipping...');
      return;
    }

    if (SupabaseClientManager.currentUser == null) {
      debugPrint('⚠️ Cannot sync: User not logged in');
      return;
    }

    debugPrint('🔄 Starting sync...');
    _status = SyncStatus.syncing;
    _lastError = null;
    notifyListeners();

    try {
      // Pull changes from server
      await _pullChanges();

      // Push local changes to server
      await _pushChanges();

      _status = SyncStatus.success;
      _lastSyncTime = DateTime.now();
      await _countPendingChanges(); // Recount after sync

      debugPrint('✅ Sync completed successfully');
    } catch (e, stack) {
      debugPrint('❌ Sync failed: $e');
      debugPrint('Stack: $stack');
      _status = SyncStatus.failed;
      _lastError = e.toString();
    } finally {
      notifyListeners();
    }
  }

  /// Pull changes from server
  Future<void> _pullChanges() async {
    debugPrint('📥 Pulling changes from server...');

    try {
      // Pull students
      await _pullStudents();

      // Pull teachers
      await _pullTeachers();

      // Pull subjects
      await _pullSubjects();

      // Pull rooms
      await _pullRooms();

      // Pull sessions
      await _pullSessions();

      // Pull payments
      await _pullPayments();

      // Pull attendance
      await _pullAttendance();

      debugPrint('✅ Pull completed successfully');
    } catch (e) {
      debugPrint('❌ Error pulling changes: $e');
      rethrow;
    }
  }

  /// Push local changes to server
  Future<void> _pushChanges() async {
    debugPrint('📤 Pushing changes to server...');

    try {
      // Implement actual push to Supabase
      await _pushStudents();
      await _pushTeachers();
      await _pushSubjects();
      await _pushRooms();
      await _pushSessions();
      await _pushPayments();
      await _pushAttendance();

      debugPrint('✅ Push completed successfully');
    } catch (e) {
      debugPrint('❌ Error pushing changes: $e');
      rethrow;
    }
  }

  /// Add a sync operation to the queue
  void addSyncOperation(SyncOperation operation) {
    _syncQueue.addOperation(operation);
    notifyListeners();
  }

  /// Get pending operations count
  int getPendingOperationsCount() {
    return _syncQueue.pendingCount;
  }

  /// Process the sync queue
  Future<void> _processSyncQueue() async {
    if (_status == SyncStatus.syncing) {
      debugPrint('⚠️ Sync already in progress, skipping queue processing...');
      return;
    }

    final pendingOperations = _syncQueue.getPendingOperations();
    if (pendingOperations.isEmpty) {
      debugPrint('📭 No pending operations in queue');
      return;
    }

    debugPrint(
      '🔄 Processing ${pendingOperations.length} operations from queue...',
    );
    _status = SyncStatus.syncing;
    notifyListeners();

    try {
      for (final operation in pendingOperations) {
        await _processOperation(operation);
      }

      _status = SyncStatus.success;
      debugPrint('✅ Queue processing completed successfully');
    } catch (e, stack) {
      debugPrint('❌ Queue processing failed: $e');
      debugPrint('Stack: $stack');
      _status = SyncStatus.failed;
      _lastError = e.toString();
    } finally {
      notifyListeners();
    }
  }

  /// Process a single sync operation
  Future<void> _processOperation(SyncOperation operation) async {
    try {
      // Update operation status to in progress
      final updatedOperation = operation.copyWith(
        status: SyncOperationStatus.inProgress,
        lastAttemptedAt: DateTime.now(),
      );
      _syncQueue.updateOperation(updatedOperation);
      notifyListeners();

      // Process based on operation type
      switch (operation.type) {
        case SyncOperationType.create:
        case SyncOperationType.update:
          await _pushRecord(operation);
          break;
        case SyncOperationType.delete:
          await _deleteRecord(operation);
          break;
        case SyncOperationType.syncAll:
          await syncAll();
          break;
      }

      // Mark operation as completed
      final completedOperation = updatedOperation.copyWith(
        status: SyncOperationStatus.completed,
        completedAt: DateTime.now(),
      );
      _syncQueue.updateOperation(completedOperation);
      _syncQueue.removeOperation(operation.id);
    } catch (e) {
      // Handle operation failure
      final failedOperation = operation.copyWith(
        status: SyncOperationStatus.failed,
        retryCount: operation.retryCount + 1,
        errorMessage: e.toString(),
      );
      _syncQueue.updateOperation(failedOperation);

      // If retry count is less than max retries, schedule retry
      if (failedOperation.retryCount < 3) {
        debugPrint(
          '🔁 Scheduling retry for operation ${operation.id} (attempt ${failedOperation.retryCount})',
        );
        // Schedule retry with exponential backoff
        Future.delayed(
          Duration(
            milliseconds: (1000 * pow(2, failedOperation.retryCount).toInt()),
          ),
          () => _processOperation(failedOperation),
        );
      } else {
        debugPrint('❌ Max retries exceeded for operation ${operation.id}');
      }

      rethrow;
    }
  }

  /// Push a record to the server
  Future<void> _pushRecord(SyncOperation operation) async {
    debugPrint(
      '📤 Pushing ${operation.type.name} operation for ${operation.tableName}.${operation.recordId}',
    );

    try {
      // Handle different table types
      switch (operation.tableName) {
        case 'students':
          // For students, we need to fetch the full record and its relationships
          final student = await (_db.select(
            _db.students,
          )..where((s) => s.id.equals(operation.recordId))).getSingle();

          final subjectIds =
              await (_db.select(_db.studentSubjects)
                    ..where((ss) => ss.studentId.equals(operation.recordId)))
                  .map((row) => row.subjectId)
                  .get();

          final domainStudent = domain.Student(
            id: student.id,
            name: student.name,
            phone: student.phone,
            email: student.email,
            birthDate: student.birthDate ?? DateTime.now(),
            address: student.address ?? '',
            imageUrl: student.imageUrl,
            stage: student.stage ?? '',
            subjectIds: subjectIds,
            parentId: student.parentPhone,
            status: domain.StudentStatus.values.firstWhere(
              (s) => s.name == student.status,
              orElse: () => domain.StudentStatus.active,
            ),
            createdAt: student.createdAt,
            lastAttendance: student.lastAttendance,
          );

          if (operation.type == SyncOperationType.create) {
            await StudentsRemoteSource().addStudent(domainStudent);
          } else {
            await StudentsRemoteSource().updateStudent(domainStudent);
          }
          break;

        case 'teachers':
          // For teachers, we need to fetch the full record and its relationships
          final teacher = await (_db.select(
            _db.teachers,
          )..where((t) => t.id.equals(operation.recordId))).getSingle();

          final subjectIds =
              await (_db.select(_db.teacherSubjects)
                    ..where((ts) => ts.teacherId.equals(operation.recordId)))
                  .map((row) => row.subjectId)
                  .get();

          final domainTeacher = domain.Teacher(
            id: teacher.id,
            name: teacher.name,
            phone: teacher.phone,
            email: '', // Not in database schema
            imageUrl: '', // Not in database schema
            subjectIds: subjectIds,
            salaryType: domain.SalaryType.values.firstWhere(
              (s) => s.name == teacher.salaryType,
              orElse: () => domain.SalaryType.fixed,
            ),
            salaryAmount: teacher.salaryValue,
            isActive: teacher.salaryType != 'deleted',
            createdAt: teacher.updatedAt,
            rating: 0.0,
            courseCount: 0,
            studentCount: 0,
          );

          if (operation.type == SyncOperationType.create) {
            await TeachersRemoteSource().addTeacher(domainTeacher);
          } else {
            await TeachersRemoteSource().updateTeacher(domainTeacher);
          }
          break;

        case 'subjects':
        case 'courses':
          // For subjects, we need to fetch the full record and its relationships
          final subject = await (_db.select(
            _db.subjects,
          )..where((s) => s.id.equals(operation.recordId))).getSingle();

          final teacherIds =
              await (_db.select(_db.teacherSubjects)
                    ..where((ts) => ts.subjectId.equals(operation.recordId)))
                  .map((row) => row.teacherId)
                  .get();

          final domainSubject = domain.Subject(
            id: subject.id,
            name: subject.name,
            description: subject.description,
            monthlyFee: subject.monthlyFee,
            teacherIds: teacherIds,
            isActive: subject.isActive,
          );

          if (operation.type == SyncOperationType.create) {
            await SubjectsRemoteSource().addSubject(domainSubject);
          } else {
            await SubjectsRemoteSource().updateSubject(domainSubject);
          }
          break;

        case 'rooms':
        case 'classrooms':
          // For rooms, we need to fetch the full record
          final room = await (_db.select(
            _db.rooms,
          )..where((r) => r.id.equals(operation.recordId))).getSingle();

          List<String> equipment = [];
          if (room.equipment != null) {
            try {
              // Try to parse as JSON array
              equipment = (jsonDecode(room.equipment!) as List).cast<String>();
            } catch (e) {
              // If not JSON, treat as comma-separated
              equipment = room.equipment!
                  .split(',')
                  .map((s) => s.trim())
                  .toList();
            }
          }

          final domainRoom = domain.Room(
            id: room.id,
            number: room.number,
            name: room.name,
            capacity: room.capacity,
            equipment: equipment,
            status: domain.RoomStatus.values.firstWhere(
              (s) => s.name == room.status,
              orElse: () => domain.RoomStatus.available,
            ),
          );

          if (operation.type == SyncOperationType.create) {
            await RoomsRemoteSource().addRoom(domainRoom);
          } else {
            await RoomsRemoteSource().updateRoom(domainRoom);
          }
          break;

        case 'sessions':
        case 'schedules':
          // For sessions, we need to fetch the full record
          final session = await (_db.select(
            _db.sessions,
          )..where((s) => s.id.equals(operation.recordId))).getSingle();

          final domainSession = domain.ScheduleSession(
            id: session.id,
            subjectId: session.subjectId,
            subjectName: '', // Will be filled by Supabase
            teacherId: session.teacherId ?? '',
            teacherName: '', // Will be filled by Supabase
            roomId: session.roomId,
            roomName: '', // Will be filled by Supabase
            dayOfWeek: session.dayOfWeek,
            startTime: session.startTime,
            endTime: session.endTime,
            status: domain.SessionStatus.values.firstWhere(
              (s) => s.name == session.status,
              orElse: () => domain.SessionStatus.scheduled,
            ),
          );

          if (operation.type == SyncOperationType.create) {
            await ScheduleRemoteSource().addSession(domainSession);
          } else {
            await ScheduleRemoteSource().updateSession(domainSession);
          }
          break;

        case 'payments':
          // For payments, we need to fetch the full record
          final payment = await (_db.select(
            _db.payments,
          )..where((p) => p.id.equals(operation.recordId))).getSingle();

          // Get student name for domain model
          String studentName = '';
          try {
            final student = await (_db.select(
              _db.students,
            )..where((s) => s.id.equals(payment.studentId))).getSingle();
            studentName = student.name;
          } catch (e) {
            // If we can't get the student name, use empty string
            studentName = '';
          }

          final domainPayment = domain.Payment(
            id: payment.id,
            studentId: payment.studentId,
            studentName: studentName,
            amount: payment.amount,
            paidAmount: payment.amount, // Assume fully paid for simplicity
            method: domain.PaymentMethod.cash, // Default since not in DB
            status: domain.PaymentStatus.paid, // Default since not in DB
            month: '', // Not in DB schema
            dueDate: payment.date,
            paidDate: payment.date,
            notes: payment.description,
          );

          if (operation.type == SyncOperationType.create) {
            await PaymentsRemoteSource().addPayment(domainPayment);
          } else {
            await PaymentsRemoteSource().updatePayment(domainPayment);
          }
          break;

        case 'attendance':
          // For attendance, we need to fetch the full record
          final attendance = await (_db.select(
            _db.attendance,
          )..where((a) => a.id.equals(operation.recordId))).getSingle();

          // Get student name for domain model
          String studentName = '';
          try {
            final student = await (_db.select(
              _db.students,
            )..where((s) => s.id.equals(attendance.studentId))).getSingle();
            studentName = student.name;
          } catch (e) {
            // If we can't get the student name, use empty string
            studentName = '';
          }

          final domainAttendance = domain.AttendanceRecord(
            id: attendance.id,
            studentId: attendance.studentId,
            studentName: studentName,
            sessionId: attendance.sessionId,
            sessionName: '', // Not in DB schema
            date: attendance.date,
            status: domain.AttendanceStatus.values.firstWhere(
              (s) => s.name == attendance.status,
              orElse: () => domain.AttendanceStatus.absent,
            ),
            notes: attendance.notes,
            checkInTime: attendance.checkInTime,
            checkOutTime: attendance.checkOutTime,
          );

          if (operation.type == SyncOperationType.create) {
            await AttendanceRemoteSource().addAttendance(domainAttendance);
          } else {
            await AttendanceRemoteSource().updateAttendance(domainAttendance);
          }
          break;

        default:
          debugPrint('Unsupported table type: ${operation.tableName}');
          throw Exception('Unsupported table type: ${operation.tableName}');
      }

      debugPrint(
        '✅ Successfully pushed record ${operation.recordId} to ${operation.tableName}',
      );
    } catch (e) {
      debugPrint(
        '❌ Error pushing record ${operation.recordId} to ${operation.tableName}: $e',
      );
      rethrow;
    }
  }

  /// Delete a record on the server
  Future<void> _deleteRecord(SyncOperation operation) async {
    debugPrint(
      '🗑️ Deleting record ${operation.recordId} from ${operation.tableName}',
    );

    try {
      // Handle different table types
      switch (operation.tableName) {
        case 'students':
          try {
            await StudentsRemoteSource().deleteStudent(operation.recordId);
          } catch (e) {
            debugPrint('Error deleting student: $e');
          }
          break;

        case 'teachers':
          try {
            await TeachersRemoteSource().deleteTeacher(operation.recordId);
          } catch (e) {
            debugPrint('Error deleting teacher: $e');
          }
          break;

        case 'subjects':
        case 'courses':
          try {
            await SubjectsRemoteSource().deleteSubject(operation.recordId);
          } catch (e) {
            debugPrint('Error deleting subject: $e');
          }
          break;

        case 'rooms':
        case 'classrooms':
          try {
            await RoomsRemoteSource().deleteRoom(operation.recordId);
          } catch (e) {
            debugPrint('Error deleting room: $e');
          }
          break;

        case 'sessions':
        case 'schedules':
          try {
            await ScheduleRemoteSource().deleteSession(operation.recordId);
          } catch (e) {
            debugPrint('Error deleting session: $e');
          }
          break;

        case 'payments':
          try {
            await PaymentsRemoteSource().deletePayment(operation.recordId);
          } catch (e) {
            debugPrint('Error deleting payment: $e');
          }
          break;

        case 'attendance':
          try {
            await AttendanceRemoteSource().deleteAttendance(operation.recordId);
          } catch (e) {
            debugPrint('Error deleting attendance: $e');
          }
          break;

        default:
          debugPrint(
            'Unsupported table type for delete: ${operation.tableName}',
          );
          throw Exception(
            'Unsupported table type for delete: ${operation.tableName}',
          );
      }

      debugPrint(
        '✅ Successfully deleted record ${operation.recordId} from ${operation.tableName}',
      );
    } catch (e) {
      debugPrint(
        '❌ Error deleting record ${operation.recordId} from ${operation.tableName}: $e',
      );
      rethrow;
    }
  }

  /// Resolve conflicts using Last-Write-Wins strategy
  Future<void> _resolveConflicts(
    Map<String, dynamic> localData,
    Map<String, dynamic> remoteData,
  ) async {
    // Last-Write-Wins: Compare updatedAt timestamps
    final localUpdatedAt = localData['updated_at'] as DateTime?;
    final remoteUpdatedAt = remoteData['updated_at'] as DateTime?;

    if (localUpdatedAt != null && remoteUpdatedAt != null) {
      if (localUpdatedAt.isAfter(remoteUpdatedAt)) {
        // Local is newer, keep local changes
        debugPrint('Conflict resolved: Keeping local version (newer)');
      } else {
        // Remote is newer or equal, use remote changes
        debugPrint('Conflict resolved: Using remote version (newer or equal)');
        // Apply remote changes to local database
        await _applyRemoteChangesToLocal(remoteData);
      }
    } else {
      // If timestamps are missing, default to remote wins
      debugPrint(
        'Conflict resolved: Using remote version (missing timestamps)',
      );
      // Apply remote changes to local database
      await _applyRemoteChangesToLocal(remoteData);
    }
  }

  /// Apply remote changes to local database
  Future<void> _applyRemoteChangesToLocal(
    Map<String, dynamic> remoteData,
  ) async {
    // This method would handle applying remote changes to the local database
    // Implementation would depend on the specific entity type
    debugPrint('Applying remote changes to local database...');
    // TODO: Implement specific logic for each entity type
  }

  /// Retry failed operations with exponential backoff
  Future<void> _retryWithBackoff(SyncOperation operation) async {
    final delay = Duration(
      milliseconds: (1000 * pow(2, operation.retryCount).toInt()),
    );
    await Future.delayed(delay);

    // Attempt to retry the operation
    debugPrint(
      'Retrying operation ${operation.id} after ${delay.inSeconds} seconds',
    );

    try {
      await _processOperation(operation);
      debugPrint('✅ Retry successful for operation ${operation.id}');
    } catch (e) {
      debugPrint('❌ Retry failed for operation ${operation.id}: $e');
      rethrow;
    }
  }

  /// Clear error
  void clearError() {
    _lastError = null;
    if (_status == SyncStatus.failed) {
      _status = SyncStatus.idle;
    }
    notifyListeners();
  }

  // ═══════════════════════════════════════════════════════════════════════
  // PUSH HELPERS (disabled until RLS is fixed)
  // ═══════════════════════════════════════════════════════════════════════

  /// Push unsynced students
  Future<void> _pushStudents() async {
    final unsyncedStudents = await (_db.select(
      _db.students,
    )..where((row) => row.isSynced.equals(false))).get();

    if (unsyncedStudents.isEmpty) return;

    debugPrint('Pushing ${unsyncedStudents.length} students...');

    try {
      final remoteSource = StudentsRemoteSource();

      for (final student in unsyncedStudents) {
        try {
          // Convert database student to domain model
          final subjectIds =
              await (_db.select(_db.studentSubjects)
                    ..where((ss) => ss.studentId.equals(student.id)))
                  .map((row) => row.subjectId)
                  .get();

          final domainStudent = domain.Student(
            id: student.id,
            name: student.name,
            phone: student.phone,
            email: student.email,
            birthDate: student.birthDate ?? DateTime.now(),
            address: student.address ?? '',
            imageUrl: student.imageUrl,
            stage: student.stage ?? '',
            subjectIds: subjectIds,
            parentId: student.parentPhone,
            status: domain.StudentStatus.values.firstWhere(
              (s) => s.name == student.status,
              orElse: () => domain.StudentStatus.active,
            ),
            createdAt: student.createdAt,
            lastAttendance: student.lastAttendance,
          );

          // Check if student exists in Supabase
          try {
            await remoteSource.getStudent(student.id);
            // Student exists, update it
            await remoteSource.updateStudent(domainStudent);
          } catch (e) {
            // Student doesn't exist, create it
            await remoteSource.addStudent(domainStudent);
          }

          // Mark as synced
          await (_db.update(_db.students)
                ..where((s) => s.id.equals(student.id)))
              .write(const StudentsCompanion(isSynced: Value(true)));
        } catch (e) {
          debugPrint('Error pushing student ${student.id}: $e');
          // Continue with other students
        }
      }
    } catch (e) {
      debugPrint('Error in _pushStudents: $e');
      rethrow;
    }
  }

  /// Push unsynced teachers
  Future<void> _pushTeachers() async {
    final unsyncedTeachers = await (_db.select(
      _db.teachers,
    )..where((row) => row.isSynced.equals(false))).get();

    if (unsyncedTeachers.isEmpty) return;

    debugPrint('Pushing ${unsyncedTeachers.length} teachers...');

    try {
      final remoteSource = TeachersRemoteSource();

      for (final teacher in unsyncedTeachers) {
        try {
          // Convert database teacher to domain model
          final subjectIds =
              await (_db.select(_db.teacherSubjects)
                    ..where((ts) => ts.teacherId.equals(teacher.id)))
                  .map((row) => row.subjectId)
                  .get();

          final domainTeacher = domain.Teacher(
            id: teacher.id,
            name: teacher.name,
            phone: teacher.phone,
            email: '', // Not in database schema
            imageUrl: '', // Not in database schema
            subjectIds: subjectIds,
            salaryType: domain.SalaryType.values.firstWhere(
              (s) => s.name == teacher.salaryType,
              orElse: () => domain.SalaryType.fixed,
            ),
            salaryAmount: teacher.salaryValue,
            isActive: teacher.salaryType != 'deleted',
            createdAt: teacher.updatedAt,
            rating: 0.0,
            courseCount: 0,
            studentCount: 0,
          );

          // Check if teacher exists in Supabase
          try {
            await remoteSource.getTeacher(teacher.id);
            // Teacher exists, update it
            await remoteSource.updateTeacher(domainTeacher);
          } catch (e) {
            // Teacher doesn't exist, create it
            await remoteSource.addTeacher(domainTeacher);
          }

          // Mark as synced
          await (_db.update(_db.teachers)
                ..where((t) => t.id.equals(teacher.id)))
              .write(const TeachersCompanion(isSynced: Value(true)));
        } catch (e) {
          debugPrint('Error pushing teacher ${teacher.id}: $e');
          // Continue with other teachers
        }
      }
    } catch (e) {
      debugPrint('Error in _pushTeachers: $e');
      rethrow;
    }
  }

  /// Push unsynced subjects
  Future<void> _pushSubjects() async {
    final unsyncedSubjects = await (_db.select(
      _db.subjects,
    )..where((row) => row.isSynced.equals(false))).get();

    if (unsyncedSubjects.isEmpty) return;

    debugPrint('Pushing ${unsyncedSubjects.length} subjects...');

    try {
      final remoteSource = SubjectsRemoteSource();

      for (final subject in unsyncedSubjects) {
        try {
          // Convert database subject to domain model
          final teacherIds =
              await (_db.select(_db.teacherSubjects)
                    ..where((ts) => ts.subjectId.equals(subject.id)))
                  .map((row) => row.teacherId)
                  .get();

          final domainSubject = domain.Subject(
            id: subject.id,
            name: subject.name,
            description: subject.description,
            monthlyFee: subject.monthlyFee,
            teacherIds: teacherIds,
            isActive: subject.isActive,
          );

          // Check if subject exists in Supabase
          try {
            await remoteSource.getSubject(subject.id);
            // Subject exists, update it
            await remoteSource.updateSubject(domainSubject);
          } catch (e) {
            // Subject doesn't exist, create it
            await remoteSource.addSubject(domainSubject);
          }

          // Mark as synced
          await (_db.update(_db.subjects)
                ..where((s) => s.id.equals(subject.id)))
              .write(const SubjectsCompanion(isSynced: Value(true)));
        } catch (e) {
          debugPrint('Error pushing subject ${subject.id}: $e');
          // Continue with other subjects
        }
      }
    } catch (e) {
      debugPrint('Error in _pushSubjects: $e');
      rethrow;
    }
  }

  /// Push unsynced rooms
  Future<void> _pushRooms() async {
    final unsyncedRooms = await (_db.select(
      _db.rooms,
    )..where((row) => row.isSynced.equals(false))).get();

    if (unsyncedRooms.isEmpty) return;

    debugPrint('Pushing ${unsyncedRooms.length} rooms...');

    try {
      final remoteSource = RoomsRemoteSource();

      for (final room in unsyncedRooms) {
        try {
          // Convert database room to domain model
          List<String> equipment = [];
          if (room.equipment != null) {
            try {
              // Try to parse as JSON array
              equipment = (jsonDecode(room.equipment!) as List).cast<String>();
            } catch (e) {
              // If not JSON, treat as comma-separated
              equipment = room.equipment!
                  .split(',')
                  .map((s) => s.trim())
                  .toList();
            }
          }

          final domainRoom = domain.Room(
            id: room.id,
            number: room.number,
            name: room.name,
            capacity: room.capacity,
            equipment: equipment,
            status: domain.RoomStatus.values.firstWhere(
              (s) => s.name == room.status,
              orElse: () => domain.RoomStatus.available,
            ),
          );

          // Since there's no getRoom method, we'll try to add/update directly
          try {
            await remoteSource.updateRoom(domainRoom);
          } catch (e) {
            // If update fails, try to add
            await remoteSource.addRoom(domainRoom);
          }

          // Mark as synced
          await (_db.update(_db.rooms)..where((r) => r.id.equals(room.id)))
              .write(const RoomsCompanion(isSynced: Value(true)));
        } catch (e) {
          debugPrint('Error pushing room ${room.id}: $e');
          // Continue with other rooms
        }
      }
    } catch (e) {
      debugPrint('Error in _pushRooms: $e');
      rethrow;
    }
  }

  /// Push unsynced sessions
  Future<void> _pushSessions() async {
    final unsyncedSessions = await (_db.select(
      _db.sessions,
    )..where((row) => row.isSynced.equals(false))).get();

    if (unsyncedSessions.isEmpty) return;

    debugPrint('Pushing ${unsyncedSessions.length} sessions...');

    try {
      final remoteSource = ScheduleRemoteSource();

      for (final session in unsyncedSessions) {
        try {
          // Convert database session to domain model
          final domainSession = domain.ScheduleSession(
            id: session.id,
            subjectId: session.subjectId,
            subjectName: '', // Will be filled by Supabase
            teacherId: session.teacherId ?? '',
            teacherName: '', // Will be filled by Supabase
            roomId: session.roomId,
            roomName: '', // Will be filled by Supabase
            dayOfWeek: session.dayOfWeek,
            startTime: session.startTime,
            endTime: session.endTime,
            status: domain.SessionStatus.values.firstWhere(
              (s) => s.name == session.status,
              orElse: () => domain.SessionStatus.scheduled,
            ),
          );

          // Since there's no getSession method, we'll try to add/update directly
          try {
            await remoteSource.updateSession(domainSession);
          } catch (e) {
            // If update fails, try to add
            await remoteSource.addSession(domainSession);
          }

          // Mark as synced
          await (_db.update(_db.sessions)
                ..where((s) => s.id.equals(session.id)))
              .write(const SessionsCompanion(isSynced: Value(true)));
        } catch (e) {
          debugPrint('Error pushing session ${session.id}: $e');
          // Continue with other sessions
        }
      }
    } catch (e) {
      debugPrint('Error in _pushSessions: $e');
      rethrow;
    }
  }

  /// Push unsynced payments
  Future<void> _pushPayments() async {
    final unsyncedPayments = await (_db.select(
      _db.payments,
    )..where((row) => row.isSynced.equals(false))).get();

    if (unsyncedPayments.isEmpty) return;

    debugPrint('Pushing ${unsyncedPayments.length} payments...');

    try {
      final remoteSource = PaymentsRemoteSource();

      for (final payment in unsyncedPayments) {
        try {
          // Get student name for domain model
          String studentName = '';
          try {
            final student = await (_db.select(
              _db.students,
            )..where((s) => s.id.equals(payment.studentId))).getSingle();
            studentName = student.name;
          } catch (e) {
            // If we can't get the student name, use empty string
            studentName = '';
          }

          // Convert database payment to domain model
          final domainPayment = domain.Payment(
            id: payment.id,
            studentId: payment.studentId,
            studentName: studentName,
            amount: payment.amount,
            paidAmount: payment.amount, // Assume fully paid for simplicity
            method: domain.PaymentMethod.cash, // Default since not in DB
            status: domain.PaymentStatus.paid, // Default since not in DB
            month: '', // Not in DB schema
            dueDate: payment.date,
            paidDate: payment.date,
            notes: payment.description,
          );

          // Since there's no getPayment method, we'll try to add/update directly
          try {
            await remoteSource.updatePayment(domainPayment);
          } catch (e) {
            // If update fails, try to add
            await remoteSource.addPayment(domainPayment);
          }

          // Mark as synced
          await (_db.update(_db.payments)
                ..where((p) => p.id.equals(payment.id)))
              .write(const PaymentsCompanion(isSynced: Value(true)));
        } catch (e) {
          debugPrint('Error pushing payment ${payment.id}: $e');
          // Continue with other payments
        }
      }
    } catch (e) {
      debugPrint('Error in _pushPayments: $e');
      rethrow;
    }
  }

  /// Push unsynced attendance
  Future<void> _pushAttendance() async {
    final unsyncedAttendance = await (_db.select(
      _db.attendance,
    )..where((row) => row.isSynced.equals(false))).get();

    if (unsyncedAttendance.isEmpty) return;

    debugPrint('Pushing ${unsyncedAttendance.length} attendance records...');

    try {
      final remoteSource = AttendanceRemoteSource();

      for (final attendance in unsyncedAttendance) {
        try {
          // Get student name for domain model
          String studentName = '';
          try {
            final student = await (_db.select(
              _db.students,
            )..where((s) => s.id.equals(attendance.studentId))).getSingle();
            studentName = student.name;
          } catch (e) {
            // If we can't get the student name, use empty string
            studentName = '';
          }

          // Convert database attendance to domain model
          final domainAttendance = domain.AttendanceRecord(
            id: attendance.id,
            studentId: attendance.studentId,
            studentName: studentName,
            sessionId: attendance.sessionId,
            sessionName: '', // Not in DB schema
            date: attendance.date,
            status: domain.AttendanceStatus.values.firstWhere(
              (s) => s.name == attendance.status,
              orElse: () => domain.AttendanceStatus.absent,
            ),
            notes: attendance.notes,
            checkInTime: attendance.checkInTime,
            checkOutTime: attendance.checkOutTime,
          );

          // Since there's no getAttendance method, we'll try to add/update directly
          try {
            await remoteSource.updateAttendance(domainAttendance);
          } catch (e) {
            // If update fails, try to add
            await remoteSource.addAttendance(domainAttendance);
          }

          // Mark as synced
          await (_db.update(_db.attendance)
                ..where((a) => a.id.equals(attendance.id)))
              .write(const AttendanceCompanion(isSynced: Value(true)));
        } catch (e) {
          debugPrint('Error pushing attendance ${attendance.id}: $e');
          // Continue with other attendance records
        }
      }
    } catch (e) {
      debugPrint('Error in _pushAttendance: $e');
      rethrow;
    }
  }

  /// Pull students from server
  Future<void> _pullStudents() async {
    try {
      final remoteSource = StudentsRemoteSource();
      final remoteStudents = await remoteSource.getStudents();
      debugPrint('Pulling ${remoteStudents.length} students from server...');
      final centerId = await _getCenterId();

      for (final student in remoteStudents) {
        try {
          // Check if student exists locally
          final localStudent =
              await (_db.select(_db.students)
                    ..where((s) => s.id.equals(student.id)))
                  .get()
                  .catchError((_) => <Student>[]);

          if (localStudent.isEmpty) {
            // Student doesn't exist locally, insert it
            await _db
                .into(_db.students)
                .insert(
                  StudentsCompanion(
                    id: Value(student.id),
                    centerId: Value(centerId ?? ''),
                    name: Value(student.name),
                    phone: Value(student.phone),
                    parentPhone: Value(student.parentId),
                    email: Value(student.email),
                    birthDate: Value(student.birthDate),
                    address: Value(student.address),
                    imageUrl: Value(student.imageUrl),
                    stage: Value(student.stage),
                    status: Value(student.status.name),
                    createdAt: Value(student.createdAt),
                    updatedAt: Value(DateTime.now()),
                    lastAttendance: Value(student.lastAttendance),
                    isSynced: const Value(
                      true,
                    ), // Mark as synced since it came from server
                  ),
                );

            // Insert student-subject relationships
            if (student.subjectIds.isNotEmpty) {
              await _db.batch((batch) {
                batch.insertAll(
                  _db.studentSubjects,
                  student.subjectIds.map(
                    (subjectId) => StudentSubjectsCompanion(
                      studentId: Value(student.id),
                      subjectId: Value(subjectId),
                    ),
                  ),
                );
              });
            }
          } else {
            // Student exists locally, update it if needed
            // In a real implementation, we'd compare timestamps and use conflict resolution
            // For now, we'll update it
            await (_db.update(
              _db.students,
            )..where((s) => s.id.equals(student.id))).write(
              StudentsCompanion(
                centerId: Value(centerId ?? ''),
                name: Value(student.name),
                phone: Value(student.phone),
                parentPhone: Value(student.parentId),
                email: Value(student.email),
                birthDate: Value(student.birthDate),
                address: Value(student.address),
                imageUrl: Value(student.imageUrl),
                stage: Value(student.stage),
                status: Value(student.status.name),
                updatedAt: Value(DateTime.now()),
                lastAttendance: Value(student.lastAttendance),
                isSynced: const Value(true), // Mark as synced
              ),
            );
          }
        } catch (e) {
          debugPrint('Error pulling student ${student.id}: $e');
        }
      }
    } catch (e) {
      debugPrint('Error in _pullStudents: $e');
    }
  }

  /// Pull teachers from server
  Future<void> _pullTeachers() async {
    try {
      final remoteSource = TeachersRemoteSource();
      final remoteTeachers = await remoteSource.getTeachers();
      debugPrint('Pulling ${remoteTeachers.length} teachers from server...');
      final centerId = await _getCenterId();

      for (final teacher in remoteTeachers) {
        try {
          // Check if teacher exists locally
          final localTeacher =
              await (_db.select(_db.teachers)
                    ..where((t) => t.id.equals(teacher.id)))
                  .get()
                  .catchError((_) => <Teacher>[]);

          if (localTeacher.isEmpty) {
            // Teacher doesn't exist locally, insert it
            await _db
                .into(_db.teachers)
                .insert(
                  TeachersCompanion(
                    id: Value(teacher.id),
                    centerId: Value(centerId ?? ''),
                    name: Value(teacher.name),
                    phone: Value(teacher.phone),
                    salaryType: Value(teacher.salaryType.name),
                    salaryValue: Value(teacher.salaryAmount),
                    updatedAt: Value(DateTime.now()),
                    isSynced: const Value(
                      true,
                    ), // Mark as synced since it came from server
                  ),
                );

            // Insert teacher-subject relationships
            if (teacher.subjectIds.isNotEmpty) {
              await _db.batch((batch) {
                batch.insertAll(
                  _db.teacherSubjects,
                  teacher.subjectIds.map(
                    (subjectId) => TeacherSubjectsCompanion(
                      teacherId: Value(teacher.id),
                      subjectId: Value(subjectId),
                    ),
                  ),
                );
              });
            }
          } else {
            // Teacher exists locally, update it
            await (_db.update(
              _db.teachers,
            )..where((t) => t.id.equals(teacher.id))).write(
              TeachersCompanion(
                centerId: Value(centerId ?? ''),
                name: Value(teacher.name),
                phone: Value(teacher.phone),
                salaryType: Value(teacher.salaryType.name),
                salaryValue: Value(teacher.salaryAmount),
                updatedAt: Value(DateTime.now()),
                isSynced: const Value(true), // Mark as synced
              ),
            );
          }
        } catch (e) {
          debugPrint('Error pulling teacher ${teacher.id}: $e');
        }
      }
    } catch (e) {
      debugPrint('Error in _pullTeachers: $e');
    }
  }

  /// Pull subjects from server
  Future<void> _pullSubjects() async {
    try {
      final remoteSource = SubjectsRemoteSource();
      final remoteSubjects = await remoteSource.getSubjects();
      debugPrint('Pulling ${remoteSubjects.length} subjects from server...');
      final centerId = await _getCenterId();

      for (final subject in remoteSubjects) {
        try {
          // Check if subject exists locally
          final localSubject =
              await (_db.select(_db.subjects)
                    ..where((s) => s.id.equals(subject.id)))
                  .get()
                  .catchError((_) => <Subject>[]);

          if (localSubject.isEmpty) {
            // Subject doesn't exist locally, insert it
            await _db
                .into(_db.subjects)
                .insert(
                  SubjectsCompanion(
                    id: Value(subject.id),
                    centerId: Value(centerId ?? ''),
                    name: Value(subject.name),
                    description: Value(subject.description),
                    monthlyFee: Value(subject.monthlyFee),
                    isActive: Value(subject.isActive),
                    updatedAt: Value(DateTime.now()),
                    isSynced: const Value(
                      true,
                    ), // Mark as synced since it came from server
                  ),
                );
          } else {
            // Subject exists locally, update it
            await (_db.update(
              _db.subjects,
            )..where((s) => s.id.equals(subject.id))).write(
              SubjectsCompanion(
                centerId: Value(centerId ?? ''),
                name: Value(subject.name),
                description: Value(subject.description),
                monthlyFee: Value(subject.monthlyFee),
                isActive: Value(subject.isActive),
                updatedAt: Value(DateTime.now()),
                isSynced: const Value(true), // Mark as synced
              ),
            );
          }
        } catch (e) {
          debugPrint('Error pulling subject ${subject.id}: $e');
        }
      }
    } catch (e) {
      debugPrint('Error in _pullSubjects: $e');
    }
  }

  /// Pull rooms from server
  Future<void> _pullRooms() async {
    try {
      final remoteSource = RoomsRemoteSource();
      final remoteRooms = await remoteSource.getRooms();
      debugPrint('Pulling ${remoteRooms.length} rooms from server...');
      final centerId = await _getCenterId();

      for (final room in remoteRooms) {
        try {
          // Check if room exists locally
          final localRoom =
              await (_db.select(_db.rooms)..where((r) => r.id.equals(room.id)))
                  .get()
                  .catchError((_) => <Room>[]);

          if (localRoom.isEmpty) {
            // Room doesn't exist locally, insert it
            final equipmentJson = jsonEncode(room.equipment);
            await _db
                .into(_db.rooms)
                .insert(
                  RoomsCompanion(
                    id: Value(room.id),
                    centerId: Value(centerId ?? ''),
                    name: Value(room.name),
                    number: Value(room.number),
                    capacity: Value(room.capacity),
                    equipment: Value(equipmentJson),
                    status: Value(room.status.name),
                    updatedAt: Value(DateTime.now()),
                    isSynced: const Value(
                      true,
                    ), // Mark as synced since it came from server
                  ),
                );
          } else {
            // Room exists locally, update it
            final equipmentJson = jsonEncode(room.equipment);
            await (_db.update(
              _db.rooms,
            )..where((r) => r.id.equals(room.id))).write(
              RoomsCompanion(
                centerId: Value(centerId ?? ''),
                name: Value(room.name),
                number: Value(room.number),
                capacity: Value(room.capacity),
                equipment: Value(equipmentJson),
                status: Value(room.status.name),
                updatedAt: Value(DateTime.now()),
                isSynced: const Value(true), // Mark as synced
              ),
            );
          }
        } catch (e) {
          debugPrint('Error pulling room ${room.id}: $e');
        }
      }
    } catch (e) {
      debugPrint('Error in _pullRooms: $e');
    }
  }

  /// Pull sessions from server
  Future<void> _pullSessions() async {
    try {
      final remoteSource = ScheduleRemoteSource();
      final remoteSessions = await remoteSource.getSessions();
      debugPrint('Pulling ${remoteSessions.length} sessions from server...');
      final centerId = await _getCenterId();

      for (final session in remoteSessions) {
        try {
          // Check if session exists locally
          final localSession =
              await (_db.select(_db.sessions)
                    ..where((s) => s.id.equals(session.id)))
                  .get()
                  .catchError((_) => <Session>[]);

          if (localSession.isEmpty) {
            // Session doesn't exist locally, insert it
            await _db
                .into(_db.sessions)
                .insert(
                  SessionsCompanion(
                    id: Value(session.id),
                    centerId: Value(centerId ?? ''),
                    subjectId: Value(session.subjectId),
                    roomId: Value(session.roomId),
                    teacherId: Value(session.teacherId),
                    dayOfWeek: Value(session.dayOfWeek),
                    startTime: Value(session.startTime),
                    endTime: Value(session.endTime),
                    status: Value(session.status.name),
                    updatedAt: Value(DateTime.now()),
                    isSynced: const Value(
                      true,
                    ), // Mark as synced since it came from server
                  ),
                );
          } else {
            // Session exists locally, update it
            await (_db.update(
              _db.sessions,
            )..where((s) => s.id.equals(session.id))).write(
              SessionsCompanion(
                centerId: Value(centerId ?? ''),
                subjectId: Value(session.subjectId),
                roomId: Value(session.roomId),
                teacherId: Value(session.teacherId),
                dayOfWeek: Value(session.dayOfWeek),
                startTime: Value(session.startTime),
                endTime: Value(session.endTime),
                status: Value(session.status.name),
                updatedAt: Value(DateTime.now()),
                isSynced: const Value(true), // Mark as synced
              ),
            );
          }
        } catch (e) {
          debugPrint('Error pulling session ${session.id}: $e');
        }
      }
    } catch (e) {
      debugPrint('Error in _pullSessions: $e');
    }
  }

  /// Pull payments from server
  Future<void> _pullPayments() async {
    try {
      final remoteSource = PaymentsRemoteSource();
      final remotePayments = await remoteSource.getPayments();
      debugPrint('Pulling ${remotePayments.length} payments from server...');
      final centerId = await _getCenterId();

      for (final payment in remotePayments) {
        try {
          // Check if payment exists locally
          final localPayment =
              await (_db.select(_db.payments)
                    ..where((p) => p.id.equals(payment.id)))
                  .get()
                  .catchError((_) => <Payment>[]);

          if (localPayment.isEmpty) {
            // Payment doesn't exist locally, insert it
            await _db
                .into(_db.payments)
                .insert(
                  PaymentsCompanion(
                    id: Value(payment.id),
                    centerId: Value(centerId ?? ''),
                    studentId: Value(payment.studentId),
                    amount: Value(payment.amount),
                    type: Value(payment.method.name),
                    date: Value(payment.paidDate ?? DateTime.now()),
                    description: Value(payment.notes),
                    updatedAt: Value(DateTime.now()),
                    isSynced: const Value(
                      true,
                    ), // Mark as synced since it came from server
                  ),
                );
          } else {
            // Payment exists locally, update it
            await (_db.update(
              _db.payments,
            )..where((p) => p.id.equals(payment.id))).write(
              PaymentsCompanion(
                centerId: Value(centerId ?? ''),
                studentId: Value(payment.studentId),
                amount: Value(payment.amount),
                type: Value(payment.method.name),
                date: Value(payment.paidDate ?? DateTime.now()),
                description: Value(payment.notes),
                updatedAt: Value(DateTime.now()),
                isSynced: const Value(true), // Mark as synced
              ),
            );
          }
        } catch (e) {
          debugPrint('Error pulling payment ${payment.id}: $e');
        }
      }
    } catch (e) {
      debugPrint('Error in _pullPayments: $e');
    }
  }

  /// Pull attendance from server
  Future<void> _pullAttendance() async {
    try {
      final remoteSource = AttendanceRemoteSource();
      final remoteAttendance = await remoteSource.getAttendance();
      debugPrint(
        'Pulling ${remoteAttendance.length} attendance records from server...',
      );
      final centerId = await _getCenterId();

      for (final attendance in remoteAttendance) {
        try {
          // Check if attendance exists locally
          final localAttendance =
              await (_db.select(_db.attendance)
                    ..where((a) => a.id.equals(attendance.id)))
                  .get()
                  .catchError((_) => <AttendanceData>[]);

          if (localAttendance.isEmpty) {
            // Attendance doesn't exist locally, insert it
            await _db
                .into(_db.attendance)
                .insert(
                  AttendanceCompanion(
                    id: Value(attendance.id),
                    centerId: Value(centerId ?? ''),
                    studentId: Value(attendance.studentId),
                    sessionId: Value(attendance.sessionId),
                    date: Value(attendance.date),
                    status: Value(attendance.status.name),
                    notes: Value(attendance.notes),
                    checkInTime: Value(attendance.checkInTime),
                    checkOutTime: Value(attendance.checkOutTime),
                    updatedAt: Value(DateTime.now()),
                    isSynced: const Value(
                      true,
                    ), // Mark as synced since it came from server
                  ),
                );
          } else {
            // Attendance exists locally, update it
            await (_db.update(
              _db.attendance,
            )..where((a) => a.id.equals(attendance.id))).write(
              AttendanceCompanion(
                centerId: Value(centerId ?? ''),
                studentId: Value(attendance.studentId),
                sessionId: Value(attendance.sessionId),
                date: Value(attendance.date),
                status: Value(attendance.status.name),
                notes: Value(attendance.notes),
                checkInTime: Value(attendance.checkInTime),
                checkOutTime: Value(attendance.checkOutTime),
                updatedAt: Value(DateTime.now()),
                isSynced: const Value(true), // Mark as synced
              ),
            );
          }
        } catch (e) {
          debugPrint('Error pulling attendance ${attendance.id}: $e');
        }
      }
    } catch (e) {
      debugPrint('Error in _pullAttendance: $e');
    }
  }
}


