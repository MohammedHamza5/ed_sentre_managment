import 'package:flutter/foundation.dart';
import '../../../../core/offline/network_monitor.dart';
import '../../../../shared/models/models.dart';
import '../sources/subjects_local_source.dart';
import '../sources/subjects_remote_source.dart';

class SubjectsRepository {
  final SubjectsRemoteSource _remoteSource;
  final SubjectsLocalSource _localSource;
  final NetworkMonitor _networkMonitor;

  static const Duration _cacheTTL = Duration(minutes: 5);

  SubjectsRepository({
    SubjectsRemoteSource? remoteSource,
    SubjectsLocalSource? localSource,
    NetworkMonitor? networkMonitor,
  })  : _remoteSource = remoteSource ?? SubjectsRemoteSource(),
        _localSource = localSource ?? SubjectsLocalSource(),
        _networkMonitor = networkMonitor ?? NetworkMonitor();

  Future<List<Subject>> getSubjects({bool forceRefresh = false}) async {
    // 1. Check Cache
    final lastCacheTime = await _localSource.getLastCacheTime();
    final isCacheValid = lastCacheTime != null &&
        DateTime.now().difference(lastCacheTime) < _cacheTTL;

    if (!forceRefresh && isCacheValid) {
      final localData = await _localSource.getSubjects();
      if (localData.isNotEmpty) {
        debugPrint('⚡ [SubjectsRepo] Returning cached data (${localData.length})');
        return localData;
      }
    }

    // 2. Check Offline
    if (!_networkMonitor.isOnline) {
      debugPrint('📴 [SubjectsRepo] Offline: Returning local data');
      return await _localSource.getSubjects();
    }

    // 3. Fetch Remote
    try {
      final remoteData = await _remoteSource.getSubjects();
      await _localSource.saveSubjects(remoteData);
      return remoteData;
    } catch (e) {
      debugPrint('❌ [SubjectsRepo] Remote fetch failed: $e');
      return await _localSource.getSubjects();
    }
  }

  Future<Subject> getSubject(String id) async {
    if (_networkMonitor.isOnline) {
      return await _remoteSource.getSubject(id);
    }
    final localList = await _localSource.getSubjects();
    return localList.firstWhere(
      (s) => s.id == id,
      orElse: () => throw Exception('Subject not found locally'),
    );
  }

  Future<Subject> addSubject(Subject subject) async {
    if (!_networkMonitor.isOnline) {
      throw Exception('Adding subjects is only available online');
    }
    final newSubject = await _remoteSource.addSubject(subject);
    
    // Optimistic Update
    final currentList = await _localSource.getSubjects();
    currentList.add(newSubject);
    await _localSource.saveSubjects(currentList);
    
    return newSubject;
  }

  Future<void> updateSubject(Subject subject) async {
    if (!_networkMonitor.isOnline) {
      throw Exception('Updating subjects is only available online');
    }
    await _remoteSource.updateSubject(subject);
    
    final currentList = await _localSource.getSubjects();
    final index = currentList.indexWhere((s) => s.id == subject.id);
    if (index != -1) {
      currentList[index] = subject;
      await _localSource.saveSubjects(currentList);
    }
  }

  Future<void> deleteSubject(String id) async {
    if (!_networkMonitor.isOnline) {
      throw Exception('Deleting subjects is only available online');
    }
    await _remoteSource.deleteSubject(id);
    
    final currentList = await _localSource.getSubjects();
    currentList.removeWhere((s) => s.id == id);
    await _localSource.saveSubjects(currentList);
  }
}


