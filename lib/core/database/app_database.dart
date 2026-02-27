import 'package:flutter/foundation.dart';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3_flutter_libs/sqlite3_flutter_libs.dart';

import 'tables.dart';

part 'app_database.g.dart';

@DriftDatabase(tables: [
  Students,
  Teachers,
  Subjects,
  Rooms,
  Sessions,
  Payments,
  StudentSubjects,
  TeacherSubjects,
  Attendance,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 3; // ✅ Incremented to 3 for center_id migration

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (Migrator m) async {
      await m.createAll();
    },
    onUpgrade: (Migrator m, int from, int to) async {
      if (from < 2) {
        // Add Attendance table for version 2
        await m.createTable(attendance);
      }

      if (from < 3) {
        // ✅ Migration to add center_id to all tables
        // Use raw SQL to add columns - this is the most reliable approach in Drift
        final db = m.database;
        
        // Helper to safely add column (ignores if already exists)
        Future<void> addCenterIdColumn(String tableName) async {
          try {
            await db.customStatement(
              'ALTER TABLE $tableName ADD COLUMN center_id TEXT NOT NULL DEFAULT ""',
            );
          } catch (e) {
            // Column might already exist, ignore error
            debugPrint('⚠️ Could not add center_id to $tableName: $e');
          }
        }
        
        await addCenterIdColumn('students');
        await addCenterIdColumn('teachers');
        await addCenterIdColumn('subjects');
        await addCenterIdColumn('rooms');
        await addCenterIdColumn('sessions');
        await addCenterIdColumn('payments');
        await addCenterIdColumn('attendance');
      }
    },
  );
  /// ✅ NEW: Clear all data for the current center
  Future<void> clearCenterData(String centerId) async {
    await batch((batch) {
      batch.deleteWhere(students, (t) => t.centerId.equals(centerId));
      batch.deleteWhere(teachers, (t) => t.centerId.equals(centerId));
      batch.deleteWhere(subjects, (t) => t.centerId.equals(centerId));
      batch.deleteWhere(rooms, (t) => t.centerId.equals(centerId));
      batch.deleteWhere(sessions, (t) => t.centerId.equals(centerId));
      batch.deleteWhere(payments, (t) => t.centerId.equals(centerId));
      batch.deleteWhere(attendance, (t) => t.centerId.equals(centerId));
    });
  }

  /// ✅ NEW: Clear ALL data (when logging out completely)
  Future<void> clearAllData() async {
    await batch((batch) {
      batch.deleteWhere(students, (_) => const Constant(true));
      batch.deleteWhere(teachers, (_) => const Constant(true));
      batch.deleteWhere(subjects, (_) => const Constant(true));
      batch.deleteWhere(rooms, (_) => const Constant(true));
      batch.deleteWhere(sessions, (_) => const Constant(true));
      batch.deleteWhere(payments, (_) => const Constant(true));
      batch.deleteWhere(attendance, (_) => const Constant(true));
      batch.deleteWhere(studentSubjects, (_) => const Constant(true));
      batch.deleteWhere(teacherSubjects, (_) => const Constant(true));
    });
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'ed_sentre.sqlite'));

    if (Platform.isAndroid) {
      await applyWorkaroundToOpenSqlite3OnOldAndroidVersions();
    }

    return NativeDatabase(file);
  });
}


