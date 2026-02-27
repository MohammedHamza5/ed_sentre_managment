import 'package:drift/drift.dart';

// ═══════════════════════════════════════════════════════════════════════════
// Students Table - WITH CENTER_ID
// ═══════════════════════════════════════════════════════════════════════════
class Students extends Table {
  TextColumn get id => text()(); // UUID
  TextColumn get centerId => text()(); // ✅ NEW: Filter by center
  TextColumn get name => text()();
  TextColumn get phone => text()();
  TextColumn get parentPhone => text().nullable()();
  TextColumn get email => text().nullable()();
  TextColumn get imageUrl => text().nullable()();
  DateTimeColumn get birthDate => dateTime().nullable()();
  TextColumn get address => text().withDefault(const Constant(''))();
  TextColumn get stage => text()();
  TextColumn get status => text()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get lastAttendance => dateTime().nullable()();

  // Sync fields
  BoolColumn get isSynced => boolean().withDefault(const Constant(false))();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

// ═══════════════════════════════════════════════════════════════════════════
// StudentSubjects (Many-to-Many)
// ═══════════════════════════════════════════════════════════════════════════
class StudentSubjects extends Table {
  TextColumn get studentId => text().references(Students, #id)();
  TextColumn get subjectId => text().references(Subjects, #id)();

  @override
  Set<Column> get primaryKey => {studentId, subjectId};
}

// ═══════════════════════════════════════════════════════════════════════════
// Teachers Table - WITH CENTER_ID
// ═══════════════════════════════════════════════════════════════════════════
class Teachers extends Table {
  TextColumn get id => text()();
  TextColumn get centerId => text()(); // ✅ NEW: Filter by center
  TextColumn get name => text()();
  TextColumn get phone => text()();
  TextColumn get specialty => text().nullable()();
  TextColumn get salaryType => text().withDefault(const Constant('fixed'))();
  RealColumn get salaryValue => real().withDefault(const Constant(0.0))();

  // Sync fields
  BoolColumn get isSynced => boolean().withDefault(const Constant(false))();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

// ═══════════════════════════════════════════════════════════════════════════
// TeacherSubjects (Many-to-Many)
// ═══════════════════════════════════════════════════════════════════════════
class TeacherSubjects extends Table {
  TextColumn get teacherId => text().references(Teachers, #id)();
  TextColumn get subjectId => text().references(Subjects, #id)();

  @override
  Set<Column> get primaryKey => {teacherId, subjectId};
}

// ═══════════════════════════════════════════════════════════════════════════
// Subjects Table - WITH CENTER_ID
// ═══════════════════════════════════════════════════════════════════════════
class Subjects extends Table {
  TextColumn get id => text()();
  TextColumn get centerId => text()(); // ✅ NEW: Filter by center
  TextColumn get name => text()();
  TextColumn get description => text().nullable()();
  RealColumn get monthlyFee => real().withDefault(const Constant(0.0))();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();

  // Sync fields
  BoolColumn get isSynced => boolean().withDefault(const Constant(false))();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

// ═══════════════════════════════════════════════════════════════════════════
// Rooms Table - WITH CENTER_ID ✅ THIS FIXES YOUR ROOM ISSUE
// ═══════════════════════════════════════════════════════════════════════════
class Rooms extends Table {
  TextColumn get id => text()();
  TextColumn get centerId => text()(); // ✅ NEW: Filter by center
  TextColumn get number => text()();
  TextColumn get name => text()();
  IntColumn get capacity => integer().withDefault(const Constant(0))();
  TextColumn get equipment => text().nullable()();
  TextColumn get status => text().withDefault(const Constant('available'))();

  // Sync fields
  BoolColumn get isSynced => boolean().withDefault(const Constant(false))();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

// ═══════════════════════════════════════════════════════════════════════════
// Sessions (Schedule) Table - WITH CENTER_ID
// ═══════════════════════════════════════════════════════════════════════════
class Sessions extends Table {
  TextColumn get id => text()();
  TextColumn get centerId => text()(); // ✅ NEW: Filter by center
  TextColumn get subjectId => text().references(Subjects, #id)();
  TextColumn get roomId => text().references(Rooms, #id)();
  TextColumn get teacherId => text().nullable().references(Teachers, #id)();
  IntColumn get dayOfWeek => integer()();
  TextColumn get startTime => text()();
  TextColumn get endTime => text()();
  TextColumn get status => text().withDefault(const Constant('scheduled'))();

  // Sync fields
  BoolColumn get isSynced => boolean().withDefault(const Constant(false))();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

// ═══════════════════════════════════════════════════════════════════════════
// Payments Table - WITH CENTER_ID
// ═══════════════════════════════════════════════════════════════════════════
class Payments extends Table {
  TextColumn get id => text()();
  TextColumn get centerId => text()(); // ✅ NEW: Filter by center
  TextColumn get studentId => text().references(Students, #id)();
  RealColumn get amount => real()();
  TextColumn get type => text()();
  DateTimeColumn get date => dateTime().withDefault(currentDateAndTime)();
  TextColumn get description => text().nullable()();

  // Sync fields
  BoolColumn get isSynced => boolean().withDefault(const Constant(false))();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

// ═══════════════════════════════════════════════════════════════════════════
// Attendance Table - WITH CENTER_ID
// ═══════════════════════════════════════════════════════════════════════════
class Attendance extends Table {
  TextColumn get id => text()();
  TextColumn get centerId => text()(); // ✅ NEW: Filter by center
  TextColumn get studentId => text().references(Students, #id)();
  TextColumn get sessionId => text().nullable().references(Sessions, #id)();
  DateTimeColumn get date => dateTime()();
  TextColumn get status => text()();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get checkInTime => dateTime().nullable()();
  DateTimeColumn get checkOutTime => dateTime().nullable()();

  // Sync fields
  BoolColumn get isSynced => boolean().withDefault(const Constant(false))();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}

