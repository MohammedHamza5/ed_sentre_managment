import 'package:flutter/foundation.dart';
import '../../../../core/offline/network_monitor.dart';
import '../../../../shared/models/models.dart';
import '../sources/teachers_local_source.dart';
import '../sources/teachers_remote_source.dart';

class TeachersRepository {
  final TeachersRemoteSource _remoteSource;
  final TeachersLocalSource _localSource;
  final NetworkMonitor _networkMonitor;

  static const Duration _cacheTTL = Duration(minutes: 5);

  TeachersRepository({
    TeachersRemoteSource? remoteSource,
    TeachersLocalSource? localSource,
    NetworkMonitor? networkMonitor,
  }) : _remoteSource = remoteSource ?? TeachersRemoteSource(),
       _localSource = localSource ?? TeachersLocalSource(),
       _networkMonitor = networkMonitor ?? NetworkMonitor();

  Future<List<Teacher>> getTeachers({bool forceRefresh = false}) async {
    // 1. Check Cache
    final lastCacheTime = await _localSource.getLastCacheTime();
    final isCacheValid =
        lastCacheTime != null &&
        DateTime.now().difference(lastCacheTime) < _cacheTTL;

    if (!forceRefresh && isCacheValid) {
      final localData = await _localSource.getTeachers();
      if (localData.isNotEmpty) {
        debugPrint(
          '⚡ [TeachersRepo] Returning cached data (${localData.length})',
        );
        return localData;
      }
    }

    // 2. Check Offline
    if (!_networkMonitor.isOnline) {
      debugPrint('📴 [TeachersRepo] Offline: Returning local data');
      return await _localSource.getTeachers();
    }

    // 3. Fetch Remote
    try {
      final remoteData = await _remoteSource.getTeachers();
      await _localSource.saveTeachers(remoteData);
      return remoteData;
    } catch (e) {
      debugPrint('❌ [TeachersRepo] Remote fetch failed: $e');
      return await _localSource.getTeachers();
    }
  }

  Future<Teacher> getTeacher(String id) async {
    if (_networkMonitor.isOnline) {
      return await _remoteSource.getTeacher(id);
    }
    final localList = await _localSource.getTeachers();
    return localList.firstWhere(
      (t) => t.id == id,
      orElse: () => throw Exception('Teacher not found locally'),
    );
  }

  Future<Map<String, dynamic>> addTeacher(Teacher teacher) async {
    if (!_networkMonitor.isOnline) {
      throw Exception('Adding teachers is only available online');
    }
    final result = await _remoteSource.addTeacher(teacher);

    // 📦 تحديث الـ Cache فوراً بعد إضافة معلم جديد
    // هذا يضمن ظهور المعلم مباشرة بدون انتظار انتهاء مدة الـ cache
    try {
      final freshData = await _remoteSource.getTeachers();
      await _localSource.saveTeachers(freshData);
      debugPrint('✅ [TeachersRepo] Cache refreshed after adding teacher');
    } catch (e) {
      debugPrint('⚠️ [TeachersRepo] Could not refresh cache: $e');
    }

    return result;
  }

  Future<void> updateTeacher(Teacher teacher) async {
    if (!_networkMonitor.isOnline) {
      throw Exception('Updating teachers is only available online');
    }
    await _remoteSource.updateTeacher(teacher);

    final currentList = await _localSource.getTeachers();
    final index = currentList.indexWhere((t) => t.id == teacher.id);
    if (index != -1) {
      currentList[index] = teacher;
      await _localSource.saveTeachers(currentList);
    }
  }

  Future<void> deleteTeacher(String id) async {
    if (!_networkMonitor.isOnline) {
      throw Exception('Deleting teachers is only available online');
    }
    await _remoteSource.deleteTeacher(id);

    final currentList = await _localSource.getTeachers();
    currentList.removeWhere((t) => t.id == id);
    await _localSource.saveTeachers(currentList);
  }

  Future<void> deactivateTeacher(String id) async {
    if (!_networkMonitor.isOnline) throw Exception('Online required');
    await _remoteSource.deactivateTeacher(id);
    // Could update cache status locally too
  }

  Future<void> reactivateTeacher(String id) async {
    if (!_networkMonitor.isOnline) throw Exception('Online required');
    await _remoteSource.reactivateTeacher(id);
  }

  Future<void> reassignTeacherGroups(String oldId, String newId) async {
    if (!_networkMonitor.isOnline) throw Exception('Online required');
    await _remoteSource.reassignTeacherGroups(oldId, newId);
  }

  Future<Map<String, int>> getTeacherDependencies(String id) async {
    if (!_networkMonitor.isOnline) return {'groups': 0, 'sessions': 0};
    return await _remoteSource.getTeacherDependencies(id);
  }

  Future<List<Subject>> getSubjects() async {
    // Subjects usually cached separately, but if needed here:
    if (!_networkMonitor.isOnline) {
      return []; // Or implement SubjectsLocalSource later
    }
    return await _remoteSource.getSubjects();
  }

  Future<Map<String, dynamic>> createTeacherInvitation({
    required String teacherName,
    String? phone,
    String? specialization,
  }) async {
    if (!_networkMonitor.isOnline) throw Exception('Online required');
    return await _remoteSource.createTeacherInvitation(
      teacherName: teacherName,
      phone: phone,
      specialization: specialization,
    );
  }

  Future<List<Map<String, dynamic>>> getTeacherInvitations() async {
    if (!_networkMonitor.isOnline) return [];
    return await _remoteSource.getTeacherInvitations();
  }

  Future<List<Map<String, dynamic>>> getTeacherTiers(
    String centerId,
    String teacherId,
  ) async {
    if (!_networkMonitor.isOnline) return [];
    return await _remoteSource.getTeacherTiers(centerId, teacherId);
  }

  Future<void> addTeacherTier({
    required String centerId,
    required String teacherId,
    required double minRevenue,
    required double maxRevenue,
    required double percentage,
  }) async {
    if (!_networkMonitor.isOnline) throw Exception('Online required');
    await _remoteSource.addTeacherTier(
      centerId: centerId,
      teacherId: teacherId,
      minRevenue: minRevenue,
      maxRevenue: maxRevenue,
      percentage: percentage,
    );
  }

  Future<void> deleteTeacherTier(String id) async {
    if (!_networkMonitor.isOnline) throw Exception('Online required');
    await _remoteSource.deleteTeacherTier(id);
  }

  Future<List<Map<String, dynamic>>> getTeacherSalaryHistory(
    String teacherId,
  ) async {
    if (!_networkMonitor.isOnline) return [];
    return await _remoteSource.getTeacherSalaryHistory(teacherId);
  }

  Future<Map<String, dynamic>> getTeacherSalary({
    required String teacherId,
    required int month,
    required int year,
  }) async {
    if (!_networkMonitor.isOnline) return {};
    return await _remoteSource.getTeacherSalary(
      teacherId: teacherId,
      month: month,
      year: year,
    );
  }

  Future<void> saveTeacherSalary({
    required String teacherId,
    required int month,
    required int year,
    required Map<String, dynamic> salaryData,
  }) async {
    if (!_networkMonitor.isOnline) {
      throw Exception('Saving salary is only available online');
    }
    await _remoteSource.saveTeacherSalary(
      teacherId: teacherId,
      month: month,
      year: year,
      salaryData: salaryData,
    );
  }

  Future<List<Map<String, dynamic>>> findSimilarTeachers(String name) async {
    if (!_networkMonitor.isOnline) return [];
    return await _remoteSource.findSimilarTeachers(name);
  }

  Future<String?> getTeacherInvitationCode(String teacherId) async {
    if (!_networkMonitor.isOnline) return null;
    return await _remoteSource.getTeacherInvitationCode(teacherId);
  }

  /// جلب إحصائيات المعلمين الشاملة (مُحسّنة)
  /// يتضمن: المحصل الفعلي، نصيب المعلم، نصيب المركز
  Future<Map<String, dynamic>> getTeacherStatistics({
    String? teacherId,
    int? month,
    int? year,
  }) async {
    if (!_networkMonitor.isOnline) return {};
    return await _remoteSource.getTeacherStatistics(
      teacherId: teacherId,
      month: month,
      year: year,
    );
  }

  /// لوحة المالية الشاملة للمركز
  Future<Map<String, dynamic>> getFinancialDashboard({
    int? month,
    int? year,
  }) async {
    if (!_networkMonitor.isOnline) return {};
    return await _remoteSource.getFinancialDashboard(month: month, year: year);
  }
}
