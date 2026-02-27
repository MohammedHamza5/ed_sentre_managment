import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import '../../core/supabase/supabase_client.dart';

/// Service to handle data backup and export
class BackupService {
  static final BackupService _instance = BackupService._internal();

  factory BackupService() {
    return _instance;
  }

  BackupService._internal();

  /// Export all critical data to a JSON file
  Future<String> exportData({required String centerId}) async {
    try {
      debugPrint('📦 [BackupService] Starting backup process for Center: $centerId...');

      // Tables to backup (RLS will filter by center)
      // Only include tables that work with RLS
      final tables = [
        'subjects',
        'groups',
        'classrooms', // Fixed: was 'rooms'
        'students',
        'student_enrollments',
        'teacher_enrollments',
        'teacher_courses',
        'schedules',
        'payments',
        'attendance',
        'course_prices',
        // Removed: student_group_enrollments (no center_id)
        // Removed: payment_items, teacher_salaries, salary_items, notifications (RLS issues)
      ];

      final Map<String, List<Map<String, dynamic>>> allData = {};

      for (final table in tables) {
        allData[table] = await _fetchTable(table);
      }

      // 2. Structure the data
      final backupData = {
        'version': '3.0',
        'timestamp': DateTime.now().toIso8601String(),
        'center_id': centerId,
        'data': allData,
      };

      // 3. Convert to JSON
      final jsonString = jsonEncode(backupData);

      // 4. Save to temporary file
      final directory = await getApplicationDocumentsDirectory();
      final dateStr = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
      final fileName = 'edsentre_backup_$dateStr.json';
      final file = File('${directory.path}/$fileName');
      
      await file.writeAsString(jsonString);

      debugPrint('✅ [BackupService] Backup created at: ${file.path}');
      return file.path;

    } catch (e) {
      debugPrint('❌ [BackupService] Backup failed: $e');
      throw Exception('Failed to create backup: $e');
    }
  }

  /// Helper to fetch table data safely
  Future<List<Map<String, dynamic>>> _fetchTable(String tableName) async {
    try {
      debugPrint('   Fetching $tableName...');
      final response = await SupabaseClientManager.client
          .from(tableName)
          .select('*');
      debugPrint('   ✅ Fetched ${(response as List).length} records from $tableName');
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('⚠️ [BackupService] Failed to fetch table $tableName (Skipping): $e');
      return []; 
    }
  }

  /// Restore data from a backup file
  Future<void> restoreData(String filePath) async {
    try {
      debugPrint('📦 [BackupService] Starting restore process...');
      
      final file = File(filePath);
      if (!await file.exists()) {
        throw Exception('Backup file not found at $filePath');
      }

      final jsonString = await file.readAsString();
      final backupData = jsonDecode(jsonString) as Map<String, dynamic>;

      if (backupData['data'] == null) {
        throw Exception('Invalid backup format');
      }

      final data = backupData['data'] as Map<String, dynamic>;
      final version = backupData['version'] ?? '1.0';
      debugPrint('📄 Backup version: $version');

      // Tables that can be restored (skip auth-related tables)
      const skipTables = ['users', 'center_users', 'expenses'];
      
      // Restore order is CRITICAL due to Foreign Keys:
      final restoreOrder = [
        'classrooms', // Also accept 'rooms' from old backups
        'rooms', // Alias for classrooms
        'subjects',
        'teacher_enrollments',
        'teacher_courses',
        'groups',
        'students',
        'student_enrollments',
        'schedules',
        'attendance',
        'payments',
        'course_prices',
      ];

      int restoredCount = 0;
      int skippedCount = 0;
      List<String> failedTables = [];

      for (final tableName in restoreOrder) {
        if (skipTables.contains(tableName)) {
          debugPrint('⏭️ Skipping protected table: $tableName');
          skippedCount++;
          continue;
        }
        
        final tableData = data[tableName];
        if (tableData == null || (tableData as List).isEmpty) {
          debugPrint('ℹ️ No data for: $tableName');
          continue;
        }
        
        final success = await _restoreTable(tableName, tableData);
        if (success) {
          restoredCount++;
        } else {
          failedTables.add(tableName);
        }
      }

      debugPrint('');
      debugPrint('═══════════════════════════════════════');
      debugPrint('✅ Restore Summary:');
      debugPrint('   - Tables restored: $restoredCount');
      debugPrint('   - Tables skipped: $skippedCount');
      if (failedTables.isNotEmpty) {
        debugPrint('   - Failed: ${failedTables.join(', ')}');
      }
      debugPrint('═══════════════════════════════════════');
      
    } catch (e) {
      debugPrint('❌ [BackupService] Restore failed: $e');
      throw Exception('Failed to restore data: $e');
    }
  }

  Future<bool> _restoreTable(String tableName, List<dynamic>? records) async {
    if (records == null || records.isEmpty) {
      debugPrint('ℹ️ [Restore] Skipping table $tableName (No Data)');
      return true;
    }

    // Map old table names to new ones
    final actualTableName = tableName == 'rooms' ? 'classrooms' : tableName;

    debugPrint('⏳ [Restore] Processing table: $actualTableName (${records.length} records)...');

    try {
      // 1. Sanitize Data
      final List<Map<String, dynamic>> sanitizedData = [];
      for (var record in records) {
        if (record is Map<String, dynamic>) {
          final cleanRecord = Map<String, dynamic>.from(record);
          
          // Column mappings for schema changes
          if (actualTableName == 'groups') {
            // Map 'name' to 'group_name' if exists
            if (cleanRecord.containsKey('name') && !cleanRecord.containsKey('group_name')) {
              cleanRecord['group_name'] = cleanRecord['name'];
              cleanRecord.remove('name');
            }
          }
          
          // Remove generated/computed columns that cannot be inserted
          cleanRecord.remove('duration'); 
          cleanRecord.remove('search_vector'); 
          cleanRecord.remove('full_name'); // Sometimes computed
          cleanRecord.remove('student_name'); // Joined field
          cleanRecord.remove('subject_name'); // Joined field - this is the issue!
          cleanRecord.remove('teacher_name'); // Joined field
          
          // Remove null values to avoid constraint issues
          cleanRecord.removeWhere((key, value) => value == null);
          
          sanitizedData.add(cleanRecord);
        }
      }

      if (sanitizedData.isEmpty) return true;

      // 2. Batch Upsert with smaller batches
      const batchSize = 50; // Even smaller for reliability
      int successCount = 0;
      int failCount = 0;
      
      for (var i = 0; i < sanitizedData.length; i += batchSize) {
        final end = (i + batchSize < sanitizedData.length) ? i + batchSize : sanitizedData.length;
        final batch = sanitizedData.sublist(i, end);
        
        debugPrint('   ↳ Upserting ${i+1}-$end...');

        try {
          await SupabaseClientManager.client
              .from(actualTableName)
              .upsert(batch, onConflict: 'id');
              
          successCount += batch.length;
        } catch (batchError) {
          failCount += batch.length;
          debugPrint('   ⚠️ Batch error: $batchError');
        }
      }
      
      final allSuccess = failCount == 0;
      debugPrint('${allSuccess ? '✅' : '⚠️'} $tableName: $successCount ok, $failCount failed');
      return allSuccess;

    } catch (e) {
      debugPrint('❌ [Restore] Error in $tableName: $e');
      return false;
    }
  }

  /// Share the backup file
  Future<void> shareBackupFile(String filePath) async {
    try {
      if (!File(filePath).existsSync()) {
        throw Exception('File not found');
      }
      
      // ignore: deprecated_member_use
      final result = await Share.shareXFiles(
        [XFile(filePath)],
        subject: 'EdSentre Backup',
        text: 'Backup created on ${DateTime.now()}',
      );

      if (result.status == ShareResultStatus.dismissed) {
        debugPrint('ℹ️ [BackupService] Share dismissed');
      }
    } catch (e) {
      debugPrint('❌ [BackupService] Share failed: $e');
      throw Exception('Failed to share backup file: $e');
    }
  }

  /// Pick a backup file to restore
  Future<String?> pickBackupFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (result != null && result.files.single.path != null) {
        return result.files.single.path!;
      }
      return null;
    } catch (e) {
      debugPrint('❌ Error picking file: $e');
      return null;
    }
  }
}



