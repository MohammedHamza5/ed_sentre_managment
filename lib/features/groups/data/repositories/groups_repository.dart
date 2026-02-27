import 'package:flutter/foundation.dart';
import '../../../../core/offline/network_monitor.dart';
import '../../../../shared/models/models.dart';
import '../../models/smart_enrollment_models.dart';
import '../sources/groups_local_source.dart';
import '../sources/groups_remote_source.dart';

class GroupsRepository {
  final GroupsRemoteSource _remoteSource;
  final GroupsLocalSource _localSource;
  final NetworkMonitor _networkMonitor;

  static const Duration _cacheTTL = Duration(minutes: 5);

  GroupsRepository({
    GroupsRemoteSource? remoteSource,
    GroupsLocalSource? localSource,
    NetworkMonitor? networkMonitor,
  }) : _remoteSource = remoteSource ?? GroupsRemoteSource(),
       _localSource = localSource ?? GroupsLocalSource(),
       _networkMonitor = networkMonitor ?? NetworkMonitor();

  Future<List<Group>> getGroups({
    bool forceRefresh = false,
    String? courseId,
    String? teacherId,
    GroupStatus? status,
    String? gradeLevel,
  }) async {
    final bool hasFilters =
        courseId != null ||
        teacherId != null ||
        status != null ||
        gradeLevel != null;

    final lastCacheTime = await _localSource.getLastCacheTime();
    final isCacheValid =
        lastCacheTime != null &&
        DateTime.now().difference(lastCacheTime) < _cacheTTL;

    if (!forceRefresh && isCacheValid && !hasFilters) {
      final localData = await _localSource.getGroups();
      if (localData.isNotEmpty) {
        debugPrint(
          '⚡ [GroupsRepo] Returning cached data (${localData.length})',
        );
        return localData;
      }
    }
    // If we have filters, we might want to check cache first and see if we can satisfy from it?
    // For now, let's prioritize remote if filters are set, unless offline.

    // 2. Check Offline
    if (!_networkMonitor.isOnline) {
      debugPrint('📴 [GroupsRepo] Offline: Returning local data');
      final localData = await _localSource.getGroups();
      return _applyFilters(localData, courseId, teacherId, status, gradeLevel);
    }

    // 3. Fetch Remote
    try {
      if (hasFilters) {
        return await _remoteSource.getGroups(
          courseId: courseId,
          teacherId: teacherId,
          status: status,
          gradeLevel: gradeLevel,
        );
      }

      final remoteData = await _remoteSource.getGroups();
      await _localSource.saveGroups(remoteData);
      return remoteData;
    } catch (e) {
      debugPrint('❌ [GroupsRepo] Remote fetch failed: $e');
      final localData = await _localSource.getGroups();
      return _applyFilters(localData, courseId, teacherId, status, gradeLevel);
    }
  }

  List<Group> _applyFilters(
    List<Group> groups,
    String? courseId,
    String? teacherId,
    GroupStatus? status,
    String? gradeLevel,
  ) {
    return groups.where((g) {
      if (courseId != null && g.courseId != courseId) return false;
      if (teacherId != null && g.teacherId != teacherId) return false;
      if (status != null && g.status != status) return false;
      if (gradeLevel != null && g.gradeLevel != gradeLevel) return false;
      return true;
    }).toList();
  }

  Future<Group> getGroup(String id) async {
    if (_networkMonitor.isOnline) {
      return await _remoteSource.getGroup(id);
    }
    final localList = await _localSource.getGroups();
    return localList.firstWhere(
      (g) => g.id == id,
      orElse: () => throw Exception('Group not found locally'),
    );
  }

  Future<Group> addGroup(Group group) async {
    if (!_networkMonitor.isOnline) {
      throw Exception('Adding groups is only available online');
    }
    final newGroup = await _remoteSource.addGroup(group);

    // Optimistic Update
    final currentList = await _localSource.getGroups();
    currentList.add(newGroup);
    await _localSource.saveGroups(currentList);

    return newGroup;
  }

  Future<void> updateGroup(Group group) async {
    if (!_networkMonitor.isOnline) {
      throw Exception('Updating groups is only available online');
    }
    await _remoteSource.updateGroup(group);

    final currentList = await _localSource.getGroups();
    final index = currentList.indexWhere((g) => g.id == group.id);
    if (index != -1) {
      currentList[index] = group;
      await _localSource.saveGroups(currentList);
    }
  }

  Future<void> deleteGroup(String id) async {
    if (!_networkMonitor.isOnline) {
      throw Exception('Deleting groups is only available online');
    }
    await _remoteSource.deleteGroup(id);

    final currentList = await _localSource.getGroups();
    currentList.removeWhere((g) => g.id == id);
    await _localSource.saveGroups(currentList);
  }

  Future<List<StudentGroupEnrollment>> getGroupEnrollments(
    String groupId,
  ) async {
    if (_networkMonitor.isOnline) {
      return await _remoteSource.getGroupEnrollments(groupId);
    }
    // TODO: Implement local caching for enrollments if needed
    return [];
  }

  Future<String> enrollStudentInGroup({
    required String studentId,
    required String groupId,
    String? notes,
  }) async {
    if (!_networkMonitor.isOnline) {
      throw Exception('Enrollment is only available online');
    }
    return await _remoteSource.enrollStudentInGroup(
      studentId: studentId,
      groupId: groupId,
      notes: notes,
    );
  }

  Future<void> transferStudentToGroup({
    required String studentId,
    required String fromGroupId,
    required String toGroupId,
    String? notes,
  }) async {
    if (!_networkMonitor.isOnline) {
      throw Exception('Transfer is only available online');
    }
    await _remoteSource.transferStudentToGroup(
      studentId: studentId,
      fromGroupId: fromGroupId,
      toGroupId: toGroupId,
      notes: notes,
    );
  }

  Future<void> withdrawStudentFromGroup({
    required String studentId,
    required String groupId,
    String? reason,
  }) async {
    if (!_networkMonitor.isOnline) {
      throw Exception('Withdrawal is only available online');
    }
    await _remoteSource.withdrawStudentFromGroup(
      studentId: studentId,
      groupId: groupId,
      reason: reason,
    );
  }

  Future<List<SmartStudentOption>> getAvailableStudentsForGroup({
    required String groupId,
    StudentFilterType filterType = StudentFilterType.all,
    String? searchQuery,
  }) async {
    if (!_networkMonitor.isOnline) {
      throw Exception('Smart enrollment is only available online');
    }
    return await _remoteSource.getAvailableStudentsForGroup(
      groupId: groupId,
      filterType: filterType,
      searchQuery: searchQuery,
    );
  }

  Future<SmartEnrollmentResult> bulkEnrollStudents({
    required List<String> studentIds,
    required String groupId,
  }) async {
    if (!_networkMonitor.isOnline) {
      throw Exception('Bulk enrollment is only available online');
    }
    return await _remoteSource.bulkEnrollStudents(
      studentIds: studentIds,
      groupId: groupId,
    );
  }

  Future<SmartEnrollmentResult> autoEnrollCourseStudents({
    required String groupId,
    int sessionsPerStudent = 1,
    bool avoidTimeConflicts = true,
    bool fairDistribution = true,
  }) async {
    if (!_networkMonitor.isOnline) {
      throw Exception('Auto enrollment is only available online');
    }
    return await _remoteSource.autoEnrollCourseStudents(
      groupId: groupId,
      sessionsPerStudent: sessionsPerStudent,
      avoidTimeConflicts: avoidTimeConflicts,
      fairDistribution: fairDistribution,
    );
  }
}


