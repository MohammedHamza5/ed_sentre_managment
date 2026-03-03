import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/offline/network_monitor.dart';
import '../sources/dashboard_remote_source.dart';

/// DashboardRepository — Offline-First
///
/// استراتيجية التخزين:
///  1. إذا كان الجهاز Online → اجلب من الـ Remote وخزّن في Cache
///  2. إذا كان Offline       → اجلب من الـ Cache (مهما كان عمره)
///  3. إذا فشل Remote        → اجلب من الـ Cache كـ fallback
class DashboardRepository {
  final DashboardRemoteSource _remoteSource;
  final NetworkMonitor _networkMonitor;

  /// مدة صلاحية الـ Cache — بعدها يُعاد الجلب من الـ Server
  static const Duration _cacheTTL = Duration(hours: 24);

  /// مفاتيح SharedPreferences
  static const String _cacheDataKey = 'dashboard_cache_data';
  static const String _cacheTimeKey = 'dashboard_cache_time';
  static const String _cacheCenterKey = 'dashboard_cache_center';

  DashboardRepository({
    DashboardRemoteSource? remoteSource,
    NetworkMonitor? networkMonitor,
  })  : _remoteSource = remoteSource ?? DashboardRemoteSource(),
        _networkMonitor = networkMonitor ?? NetworkMonitor();

  // ═══════════════════════════════════════════════════════════════════════════
  // PUBLIC API
  // ═══════════════════════════════════════════════════════════════════════════

  /// جلب ملخص الـ Dashboard مع دعم Offline-First
  Future<Map<String, dynamic>> getDashboardSummary({
    String? centerId,
    bool forceRefresh = false,
  }) async {
    // ─── Offline: اجلب من Cache مباشرةً ─────────────────────────────────────
    if (!_networkMonitor.isOnline) {
      debugPrint('📴 [DashboardRepo] Offline: trying local cache…');
      final cached = await _loadFromCache(centerId);
      if (cached != null) {
        debugPrint('✅ [DashboardRepo] Offline: serving cached dashboard');
        return cached;
      }
      debugPrint('⚠️  [DashboardRepo] Offline: no cache available, returning {}');
      return {};
    }

    // ─── Online + Cache صالحة + لا يُجبَر التحديث: اجلب من Cache ────────────
    if (!forceRefresh) {
      final cached = await _loadFromCache(centerId);
      final isFresh = await _isCacheFresh(centerId);
      if (cached != null && isFresh) {
        debugPrint('⚡ [DashboardRepo] Serving fresh cached dashboard');
        return cached;
      }
    }

    // ─── Online: اجلب من Remote ثم خزّن ─────────────────────────────────────
    try {
      final data = await _remoteSource.getDashboardSummary(centerId: centerId);
      await _saveToCache(data, centerId);
      debugPrint('✅ [DashboardRepo] Remote dashboard loaded & cached');
      return data;
    } catch (e) {
      debugPrint('❌ [DashboardRepo] Remote fetch failed: $e');

      // Fallback: جرّب الـ Cache حتى لو قديمة
      final cached = await _loadFromCache(centerId);
      if (cached != null) {
        debugPrint('♻️  [DashboardRepo] Serving stale cache as fallback');
        return {...cached, '_stale': true};
      }
      return {};
    }
  }

  /// إلغاء الـ Cache يدوياً (مفيد عند تغيير السنتر مثلاً)
  Future<void> clearCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_cacheDataKey);
    await prefs.remove(_cacheTimeKey);
    await prefs.remove(_cacheCenterKey);
    debugPrint('🗑️  [DashboardRepo] Cache cleared');
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // PRIVATE CACHE HELPERS
  // ═══════════════════════════════════════════════════════════════════════════

  /// حفظ البيانات في الـ Cache مع timestamp والـ centerId
  Future<void> _saveToCache(
    Map<String, dynamic> data,
    String? centerId,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cacheDataKey, jsonEncode(data));
      await prefs.setInt(
        _cacheTimeKey,
        DateTime.now().millisecondsSinceEpoch,
      );
      if (centerId != null) {
        await prefs.setString(_cacheCenterKey, centerId);
      }
    } catch (e) {
      // فشل الحفظ لا يجب أن يوقف التطبيق
      debugPrint('⚠️  [DashboardRepo] Failed to save cache: $e');
    }
  }

  /// قراءة البيانات من الـ Cache
  /// يُرجع null إذا لم تكن هناك بيانات أو كانت لسنتر مختلف
  Future<Map<String, dynamic>?> _loadFromCache(String? centerId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_cacheDataKey);
      if (raw == null || raw.isEmpty) return null;

      // تحقق من أن الـ Cache خاصة بنفس السنتر
      if (centerId != null) {
        final cachedCenter = prefs.getString(_cacheCenterKey);
        if (cachedCenter != null && cachedCenter != centerId) {
          debugPrint(
            '⚠️  [DashboardRepo] Cache center mismatch '
            '(cached: $cachedCenter, requested: $centerId)',
          );
          return null;
        }
      }

      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) return decoded;
      return null;
    } catch (e) {
      debugPrint('⚠️  [DashboardRepo] Failed to read cache: $e');
      return null;
    }
  }

  /// هل الـ Cache لا تزال طازجة (ضمن الـ TTL)؟
  Future<bool> _isCacheFresh(String? centerId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final timestamp = prefs.getInt(_cacheTimeKey);
      if (timestamp == null) return false;

      // تحقق من توافق السنتر
      if (centerId != null) {
        final cachedCenter = prefs.getString(_cacheCenterKey);
        if (cachedCenter != null && cachedCenter != centerId) return false;
      }

      final cacheTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
      final age = DateTime.now().difference(cacheTime);
      return age < _cacheTTL;
    } catch (e) {
      return false;
    }
  }
}
