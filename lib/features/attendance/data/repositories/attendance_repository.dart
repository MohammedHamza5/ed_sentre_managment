import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import '../../../../core/offline/network_monitor.dart';
import '../../../../shared/models/models.dart';
import '../sources/attendance_local_source.dart';
import '../sources/attendance_remote_source.dart';

class AttendanceRepository {
  final AttendanceRemoteSource _remoteSource;
  final AttendanceLocalSource _localSource;
  final NetworkMonitor _networkMonitor;

  AttendanceRepository({
    AttendanceRemoteSource? remoteSource,
    AttendanceLocalSource? localSource,
    NetworkMonitor? networkMonitor,
  }) : _remoteSource = remoteSource ?? AttendanceRemoteSource(),
       _localSource = localSource ?? AttendanceLocalSource(),
       _networkMonitor = networkMonitor ?? NetworkMonitor();

  Future<List<AttendanceRecord>> getAttendanceByDate(DateTime date) async {
    // 1. Try Remote if online
    if (_networkMonitor.isOnline) {
      try {
        final remoteData = await _remoteSource.getAttendanceByDate(date);
        await _localSource.saveAttendance(date, remoteData);
        return remoteData;
      } catch (e) {
        debugPrint('❌ [AttendanceRepo] Remote fetch failed: $e');
        // Fallback to local
      }
    }

    // 2. Local
    debugPrint('📴 [AttendanceRepo] Returning local data');
    return await _localSource.getAttendanceByDate(date);
  }

  Future<List<AttendanceRecord>> getAttendanceRange(
    DateTime start,
    DateTime end,
  ) async {
    if (_networkMonitor.isOnline) {
      try {
        return await _remoteSource.getAttendanceRange(start, end);
      } catch (e) {
        debugPrint('❌ [AttendanceRepo] Range fetch failed: $e');
      }
    }
    // TODO: Implement local range query if needed
    return [];
  }

  Future<void> addBulkAttendance(List<AttendanceRecord> records) async {
    if (!_networkMonitor.isOnline) {
      throw Exception('Attendance submission is only available online');
    }
    await _remoteSource.addBulkAttendance(records);
    // Note: We might want to refresh local cache for that date, but caller usually reloads.
  }

  Future<void> updateAttendance(AttendanceRecord record) async {
    if (!_networkMonitor.isOnline) {
      throw Exception('Attendance update is only available online');
    }
    await _remoteSource.updateAttendance(record);
  }

  Future<void> deleteAttendance(String id) async {
    if (!_networkMonitor.isOnline) {
      throw Exception('Attendance deletion is only available online');
    }
    await _remoteSource.deleteAttendance(id);
  }

  Future<Map<String, dynamic>> getAttendanceStats({DateTime? date}) async {
    if (_networkMonitor.isOnline) {
      return await _remoteSource.getAttendanceStats(date: date);
    }
    return {}; // Todo: Calculate from local if needed
  }

  Future<List<AttendanceRecord>> getAttendanceByStudent(
    String studentId,
  ) async {
    if (!_networkMonitor.isOnline) {
      return [];
    }
    return await _remoteSource.getAttendanceByStudent(studentId);
  }

  Future<Map<String, dynamic>> startAttendanceSession({
    required String groupId,
    int durationMinutes = 60,
  }) async {
    if (!_networkMonitor.isOnline) {
      throw Exception('Starting session is only available online');
    }
    return await _remoteSource.startAttendanceSession(
      groupId: groupId,
      durationMinutes: durationMinutes,
    );
  }

  Future<Map<String, dynamic>> getAttendanceSessionStatus(
    String sessionId,
  ) async {
    if (!_networkMonitor.isOnline) {
      return {};
    }
    return await _remoteSource.getAttendanceSessionStatus(sessionId);
  }

  Future<void> endAttendanceSession(String sessionId) async {
    if (!_networkMonitor.isOnline) {
      throw Exception('Ending session is only available online');
    }
    await _remoteSource.endAttendanceSession(sessionId);
  }

  Future<List<Map<String, dynamic>>> getGroupAttendanceSheet(
    String groupId,
    DateTime date,
  ) async {
    if (_networkMonitor.isOnline) {
      return await _remoteSource.getGroupAttendanceSheet(groupId, date);
    }
    return [];
  }

  Future<Map<String, dynamic>> createSmartSession({
    required String groupId,
    required DateTime opensAt,
    DateTime? closesAt,
    DateTime? onTimeUntil,
  }) async {
    if (!_networkMonitor.isOnline) {
      throw Exception('Creating smart session is only available online');
    }

    return await _remoteSource.createSmartSession(
      groupId: groupId,
      opensAt: opensAt,
      closesAt: closesAt,
      onTimeUntil: onTimeUntil,
    );
  }

  Future<String> getSessionQr(String sessionId) async {
    if (!_networkMonitor.isOnline) {
      throw Exception('QR generation is only available online');
    }
    return await _remoteSource.generateSessionQr(sessionId);
  }

  Future<String> getUniversalQr() async {
    // 1. Try Online
    if (_networkMonitor.isOnline) {
      try {
        // Fetch the key to ensure we have the latest for offline use
        final keyPart = await _remoteSource.fetchUniversalQrKey();
        if (keyPart != null) {
          await _localSource.saveUniversalQrKey(keyPart);
        }

        // Return server-generated QR
        return await _remoteSource.generateUniversalQr();
      } catch (e) {
        debugPrint(
          '⚠️ [AttendanceRepo] Online QR gen failed, trying offline: $e',
        );
      }
    }

    // 2. Offline Fallback
    final cachedKey = await _localSource.getUniversalQrKey();
    if (cachedKey != null) {
      // Generate Local QR: UNIVERSAL:DEFAULT:TIMESTAMP:SIGNATURE
      final timestamp = (DateTime.now().millisecondsSinceEpoch / 1000 / 15)
          .floor();
      final signature = md5
          .convert(utf8.encode('$cachedKey$timestamp'))
          .toString();
      return 'UNIVERSAL:DEFAULT:$timestamp:$signature';
    }

    throw Exception('No internet and no cached key for Offline QR');
  }
}
