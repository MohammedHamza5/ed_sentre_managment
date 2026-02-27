import '../../../../core/offline/network_monitor.dart';
import '../../../../core/supabase/auth_service.dart';
import '../../../../shared/models/auth_models.dart';
import '../../../../shared/models/pricing_models.dart';
import '../sources/settings_remote_source.dart';
import '../sources/settings_local_source.dart';

class SettingsRepository {
  final SettingsRemoteSource _remoteSource;
  final SettingsLocalSource _localSource;
  final NetworkMonitor _networkMonitor;
  static const Duration _cacheTTL = Duration(minutes: 5);

  SettingsRepository({
    SettingsRemoteSource? remoteSource,
    SettingsLocalSource? localSource,
    NetworkMonitor? networkMonitor,
  }) : _remoteSource = remoteSource ?? SettingsRemoteSource(),
       _localSource = localSource ?? SettingsLocalSource(),
       _networkMonitor = networkMonitor ?? NetworkMonitor();

  Future<List<CenterUser>> getCenterUsers() async {
    final lastCache = await _localSource.getUsersLastCacheTime();
    final cacheValid = lastCache != null &&
        DateTime.now().difference(lastCache) < _cacheTTL;
    if (!_networkMonitor.isOnline || cacheValid) {
      final local = await _localSource.getCenterUsers();
      if (local.isNotEmpty || !_networkMonitor.isOnline) return local;
    }
    final remote = await _remoteSource.getCenterUsers();
    await _localSource.saveCenterUsers(remote);
    return remote;
  }

  Future<void> addCenterUser({
    required String fullName,
    required String phone,
    required String role,
    String? email,
  }) async {
    if (!_networkMonitor.isOnline) {
      throw Exception('Adding users is only available online');
    }
    await _remoteSource.addCenterUser(
      fullName: fullName,
      phone: phone,
      role: role,
      email: email,
    );
    try {
      final fresh = await _remoteSource.getCenterUsers();
      await _localSource.saveCenterUsers(fresh);
    } catch (_) {}
  }

  Future<List<AppRole>> getCenterRoles() async {
    final lastCache = await _localSource.getRolesLastCacheTime();
    final cacheValid = lastCache != null &&
        DateTime.now().difference(lastCache) < _cacheTTL;
    if (!_networkMonitor.isOnline || cacheValid) {
      final local = await _localSource.getCenterRoles();
      if (local.isNotEmpty || !_networkMonitor.isOnline) return local;
    }
    final remote = await _remoteSource.getCenterRoles();
    await _localSource.saveCenterRoles(remote);
    return remote;
  }

  Future<void> createRole({
    required String name,
    required String description,
  }) async {
    if (!_networkMonitor.isOnline) {
      throw Exception('Creating roles is only available online');
    }
    await _remoteSource.createRole(name: name, description: description);
    try {
      final fresh = await _remoteSource.getCenterRoles();
      await _localSource.saveCenterRoles(fresh);
    } catch (_) {}
  }

  Future<List<CoursePrice>> getCoursePrices(String centerId) async {
    final lastCache = await _localSource.getCoursePricesLastCacheTime(centerId);
    final cacheValid = lastCache != null &&
        DateTime.now().difference(lastCache) < _cacheTTL;
    if (!_networkMonitor.isOnline || cacheValid) {
      final local = await _localSource.getCoursePrices(centerId);
      if (local.isNotEmpty || !_networkMonitor.isOnline) return local;
    }
    final remote = await _remoteSource.getCoursePrices(centerId);
    await _localSource.saveCoursePrices(centerId, remote);
    return remote;
  }

  Future<String> upsertCoursePrice({
    required String centerId,
    required String subjectName,
    required double sessionPrice,
    String? teacherId,
    String? gradeLevel,
    double? monthlyPrice,
    int sessionsPerMonth = 8,
    String? notes,
  }) async {
    if (!_networkMonitor.isOnline) {
      throw Exception('Updating prices is only available online');
    }
    return await _remoteSource.upsertCoursePrice(
      centerId: centerId,
      subjectName: subjectName,
      sessionPrice: sessionPrice,
      teacherId: teacherId,
      gradeLevel: gradeLevel,
      monthlyPrice: monthlyPrice,
      sessionsPerMonth: sessionsPerMonth,
      notes: notes,
    );
  }

  Future<int> getBillableActiveEnrollmentsCount() async {
    final lastCache = await _localSource.getBillableCountLastCacheTime();
    final cacheValid = lastCache != null &&
        DateTime.now().difference(lastCache) < _cacheTTL;
    if (!_networkMonitor.isOnline || cacheValid) {
      return await _localSource.getBillableActiveEnrollmentsCount();
    }
    final remote = await _remoteSource.getBillableActiveEnrollmentsCount();
    await _localSource.saveBillableActiveEnrollmentsCount(remote);
    return remote;
  }

  Future<Map<String, int>> getAiUsageStats() async {
    final lastCache = await _localSource.getAiStatsLastCacheTime();
    final cacheValid = lastCache != null &&
        DateTime.now().difference(lastCache) < _cacheTTL;
    if (!_networkMonitor.isOnline || cacheValid) {
      return await _localSource.getAiUsageStats();
    }
    final remote = await _remoteSource.getAiUsageStats();
    await _localSource.saveAiUsageStats(remote);
    return remote;
  }

  /// Simulate the impact of a price change
  Future<Map<String, dynamic>> simulatePriceImpact({
    required String centerId,
    required String subjectName,
    String? teacherId,
    String? gradeLevel,
    required double newPrice,
  }) async {
    if (!_networkMonitor.isOnline) {
      throw Exception('Price simulation is only available online');
    }
    return await _remoteSource.simulatePriceImpact(
      centerId: centerId,
      subjectName: subjectName,
      teacherId: teacherId,
      gradeLevel: gradeLevel,
      newPrice: newPrice,
    );
  }

  /// Delete a course price
  Future<void> deleteCoursePrice(String priceId) async {
    if (!_networkMonitor.isOnline) {
      throw Exception('Deleting prices is only available online');
    }
    await _remoteSource.deleteCoursePrice(priceId);
    try {
      final centerId = await AuthService.getSavedCenterId();
      if (centerId != null) {
        final fresh = await _remoteSource.getCoursePrices(centerId);
        await _localSource.saveCoursePrices(centerId, fresh);
      }
    } catch (_) {}
  }

  /// Update a role
  Future<void> updateRole({
    required String roleId,
    required String name,
    String? description,
  }) async {
    if (!_networkMonitor.isOnline) {
      throw Exception('Updating roles is only available online');
    }
    await _remoteSource.updateRole(
      roleId: roleId,
      name: name,
      description: description,
    );
    try {
      final fresh = await _remoteSource.getCenterRoles();
      await _localSource.saveCenterRoles(fresh);
    } catch (_) {}
  }

  /// Delete a role
  Future<void> deleteRole(String roleId) async {
    if (!_networkMonitor.isOnline) {
      throw Exception('Deleting roles is only available online');
    }
    await _remoteSource.deleteRole(roleId);
    try {
      final fresh = await _remoteSource.getCenterRoles();
      await _localSource.saveCenterRoles(fresh);
    } catch (_) {}
  }
}


