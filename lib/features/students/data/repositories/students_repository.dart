import 'package:flutter/foundation.dart';
import '../../../../core/offline/network_monitor.dart';
import '../../../../shared/models/models.dart';
import '../sources/students_local_source.dart';
import '../sources/students_remote_source.dart';

class StudentsRepository {
  final StudentsRemoteSource _remoteSource;
  final StudentsLocalSource _localSource;
  final NetworkMonitor _networkMonitor;

  // Cache validity duration (e.g., 5 minutes)
  static const Duration _cacheTTL = Duration(minutes: 5);

  StudentsRepository({
    StudentsRemoteSource? remoteSource,
    StudentsLocalSource? localSource,
    NetworkMonitor? networkMonitor,
  }) : _remoteSource = remoteSource ?? StudentsRemoteSource(),
       _localSource = localSource ?? StudentsLocalSource(),
       _networkMonitor = networkMonitor ?? NetworkMonitor();

  /// Get students with offline-first strategy
  Future<List<Student>> getStudents({
    int? page,
    int? limit,
    String? searchQuery,
    String? status,
    String? gradeLevel,
    bool forceRefresh = false,
  }) async {
    // 0. Handle Search
    if (searchQuery != null && searchQuery.isNotEmpty) {
      if (_networkMonitor.isOnline) {
        try {
          return await _remoteSource.getStudents(
            page: page,
            limit: limit,
            searchQuery: searchQuery,
            status: status,
            gradeLevel: gradeLevel,
          );
        } catch (e) {
          debugPrint('❌ [StudentsRepo] Remote search failed: $e');
        }
      }
      // Offline/Fallback search
      final all = await _localSource.getStudents();
      final filtered = all
          .where(
            (s) =>
                (s.name.toLowerCase().contains(searchQuery.toLowerCase()) ||
                    s.phone.contains(searchQuery)) &&
                (status == null || s.status.name == status) &&
                (gradeLevel == null || s.stage == gradeLevel),
          )
          .toList();
      return _sliceList(filtered, page, limit);
    }

    // If pagination OR filtering is requested and we are online
    if ((page != null ||
            limit != null ||
            status != null ||
            gradeLevel != null) &&
        _networkMonitor.isOnline) {
      try {
        final remoteData = await _remoteSource.getStudents(
          page: page,
          limit: limit,
          status: status,
          gradeLevel: gradeLevel,
        );
        // Note: We don't overwrite the entire cache with a single page usually,
        // unless we have a sophisticated cache that handles pages.
        // For simplicity, we might append or just return remote data.
        // If it's page 1, we might treat it as a fresh start.
        if (page == 1) {
          // If we are fetching page 1, maybe we want to cache it?
          // But saving partial list to 'cache_students' (which implies all) is dangerous.
          // So for pagination, we often bypass cache write or use a different strategy.
          // However, to keep it simple and consistent with previous 'God Repo':
          // The previous repo fetched from Supabase and saved to cache IF it was a full fetch?
          // Actually CachingRepo said: "If pagination is used, bypass full-list cache for now".
          return remoteData;
        }
        return remoteData;
      } catch (e) {
        debugPrint('❌ [StudentsRepo] Remote paged fetch failed: $e');
        // Fallback to local
      }
    }

    // 1. Check Local Cache validity
    final lastCacheTime = await _localSource.getLastCacheTime();
    final isCacheValid =
        lastCacheTime != null &&
        DateTime.now().difference(lastCacheTime) < _cacheTTL;

    if (!forceRefresh && isCacheValid) {
      final localData = await _localSource.getStudents();
      if (localData.isNotEmpty) {
        debugPrint(
          '⚡ [StudentsRepo] Returning cached data (${localData.length})',
        );
        return _sliceList(localData, page, limit);
      }
    }

    // 2. Check Connectivity
    if (!_networkMonitor.isOnline) {
      debugPrint('📴 [StudentsRepo] Offline: Returning local data');
      final localData = await _localSource.getStudents();
      return _sliceList(localData, page, limit);
    }

    // 3. Fetch Remote (Full List if no pagination, or Paged if pagination)
    try {
      final remoteData = await _remoteSource.getStudents(
        page: page,
        limit: limit,
      );

      // Only cache if we fetched "all" (no pagination) or maybe page 1?
      // For now, let's only cache if no pagination is requested to avoid partial cache.
      if (page == null && limit == null) {
        await _localSource.saveStudents(remoteData);
      }

      return remoteData;
    } catch (e) {
      debugPrint('❌ [StudentsRepo] Remote fetch failed: $e');
      // Fallback to local if remote fails
      final localData = await _localSource.getStudents();
      return _sliceList(localData, page, limit);
    }
  }

  List<Student> _sliceList(List<Student> list, int? page, int? limit) {
    if (page == null || limit == null) return list;

    final start = (page - 1) * limit;
    if (start >= list.length) return [];

    final end = (start + limit) > list.length ? list.length : (start + limit);
    return list.sublist(start, end);
  }

  Future<Student> getStudent(String id) async {
    // For single student, we prefer fresh data, but could fall back to cache list search
    if (_networkMonitor.isOnline) {
      return await _remoteSource.getStudent(id);
    }

    // Offline: search in local list
    final localList = await _localSource.getStudents();
    return localList.firstWhere(
      (s) => s.id == id,
      orElse: () => throw Exception('Student not found locally'),
    );
  }

  Future<Map<String, dynamic>> addStudent(Student student) async {
    if (!_networkMonitor.isOnline) {
      throw Exception('Adding students is only available online');
    }

    // 1. Remote Call
    final result = await _remoteSource.addStudent(student);

    // 2. 📦 تحديث الـ Cache فوراً بعد إضافة طالب جديد
    // هذا يضمن ظهور الطالب مباشرة بدون انتظار انتهاء مدة الـ cache
    try {
      final freshData = await _remoteSource.getStudents();
      await _localSource.saveStudents(freshData);
      debugPrint('✅ [StudentsRepo] Cache refreshed after adding student');
    } catch (e) {
      debugPrint('⚠️ [StudentsRepo] Could not refresh cache: $e');
    }

    return result;
  }

  Future<void> updateStudent(Student student) async {
    if (!_networkMonitor.isOnline) {
      throw Exception('Updating students is only available online');
    }

    await _remoteSource.updateStudent(student);

    // Invalidate/Update Cache
    final currentList = await _localSource.getStudents();
    final index = currentList.indexWhere((s) => s.id == student.id);
    if (index != -1) {
      currentList[index] = student;
      await _localSource.saveStudents(currentList);
    }
  }

  Future<void> deleteStudent(String id) async {
    if (!_networkMonitor.isOnline) {
      throw Exception('Deleting students is only available online');
    }

    await _remoteSource.deleteStudent(id);

    // Optimistic Update
    final currentList = await _localSource.getStudents();
    currentList.removeWhere((s) => s.id == id);
    await _localSource.saveStudents(currentList);
  }

  Future<List<Map<String, dynamic>>> getStudentSubjectsWithTeachers(
    String studentId,
  ) async {
    if (!_networkMonitor.isOnline) {
      return [];
    }
    return await _remoteSource.getStudentSubjectsWithTeachers(studentId);
  }

  Future<List<String>> getStudentSubjectIds(String studentId) async {
    if (!_networkMonitor.isOnline) {
      return [];
    }
    return await _remoteSource.getStudentSubjectIds(studentId);
  }

  Future<Map<String, String?>> getInvitationCodes(String studentId) async {
    if (!_networkMonitor.isOnline) {
      return {'student_code': null, 'parent_code': null};
    }
    return await _remoteSource.getInvitationCodes(studentId);
  }

  Future<List<Map<String, dynamic>>> updateStudentSubjects(
    String studentId,
    List<String> newSubjectIds,
  ) async {
    if (!_networkMonitor.isOnline) {
      throw Exception('Updating subjects is only available online');
    }
    return await _remoteSource.updateStudentSubjects(studentId, newSubjectIds);
  }
}
