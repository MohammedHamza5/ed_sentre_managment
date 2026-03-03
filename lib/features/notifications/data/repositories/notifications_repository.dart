import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/offline/network_monitor.dart';
import '../sources/notifications_remote_source.dart';

/// NotificationsRepository — Offline-First
///
/// استراتيجية التخزين:
///  1. إذا كان الجهاز Online  → اجلب من Remote وخزّن في Cache
///  2. إذا كان Offline        → اجلب من Cache (مهما كان عمرها)
///  3. إذا فشل Remote         → اجلب من Cache كـ fallback
class NotificationsRepository {
  final NotificationsRemoteSource _remoteSource;
  final NetworkMonitor _networkMonitor;

  /// مدة صلاحية الـ Cache
  static const Duration _cacheTTL = Duration(minutes: 30);

  /// مفاتيح SharedPreferences
  static const String _cacheDataKey   = 'notifications_cache_data';
  static const String _cacheTimeKey   = 'notifications_cache_time';
  static const String _cacheCountKey  = 'notifications_unread_count';

  NotificationsRepository({
    NotificationsRemoteSource? remoteSource,
    NetworkMonitor? networkMonitor,
  })  : _remoteSource = remoteSource ?? NotificationsRemoteSource(),
        _networkMonitor = networkMonitor ?? NetworkMonitor();

  // ═══════════════════════════════════════════════════════════════════════════
  // PUBLIC API
  // ═══════════════════════════════════════════════════════════════════════════

  /// جلب الإشعارات مع دعم Offline-First
  Future<List<Map<String, dynamic>>> getNotifications({
    int limit = 50,
    bool forceRefresh = false,
  }) async {
    // ─── Offline ──────────────────────────────────────────────────────────
    if (!_networkMonitor.isOnline) {
      debugPrint('📴 [NotificationsRepo] Offline: trying local cache…');
      final cached = await _loadFromCache();
      if (cached != null) {
        debugPrint(
          '✅ [NotificationsRepo] Offline: serving ${cached.length} cached notifications',
        );
        return cached;
      }
      debugPrint('⚠️  [NotificationsRepo] Offline: no cache available');
      return [];
    }

    // ─── Online + Cache صالحة ─────────────────────────────────────────────
    if (!forceRefresh) {
      final cached   = await _loadFromCache();
      final isFresh  = await _isCacheFresh();
      if (cached != null && isFresh) {
        debugPrint('⚡ [NotificationsRepo] Serving fresh cached notifications');
        return cached;
      }
    }

    // ─── Online: اجلب من Remote ثم خزّن ──────────────────────────────────
    try {
      final data = await _remoteSource.getNotifications(limit: limit);
      await _saveToCache(data);
      debugPrint(
        '✅ [NotificationsRepo] Remote notifications loaded & cached (${data.length})',
      );
      return data;
    } catch (e) {
      debugPrint('❌ [NotificationsRepo] Remote fetch failed: $e');
      final cached = await _loadFromCache();
      if (cached != null) {
        debugPrint('♻️  [NotificationsRepo] Serving stale cache as fallback');
        return cached;
      }
      return [];
    }
  }

  /// تعليم إشعار واحد كـ مقروء
  Future<void> markNotificationRead(String id) async {
    if (!_networkMonitor.isOnline) return;

    await _remoteSource.markNotificationRead(id);

    // تحديث الـ Cache محلياً لتفادي re-fetch
    final cached = await _loadFromCache();
    if (cached != null) {
      final updated = cached.map((n) {
        if (n['id'] == id) {
          return {...n, 'is_read': true};
        }
        return n;
      }).toList();
      await _saveToCache(updated);
    }
  }

  /// تعليم كل الإشعارات كـ مقروءة
  Future<void> markAllNotificationsRead() async {
    if (!_networkMonitor.isOnline) return;

    await _remoteSource.markAllNotificationsRead();

    // تحديث الـ Cache محلياً
    final cached = await _loadFromCache();
    if (cached != null) {
      final updated = cached
          .map((n) => {...n, 'is_read': true})
          .toList();
      await _saveToCache(updated);
      await _saveUnreadCount(0);
    }
  }

  /// عدد الإشعارات غير المقروءة — مع offline fallback
  Future<int> getUnreadNotificationsCount() async {
    if (!_networkMonitor.isOnline) {
      return await _loadUnreadCount();
    }

    try {
      final count = await _remoteSource.getUnreadNotificationsCount();
      await _saveUnreadCount(count);
      return count;
    } catch (e) {
      debugPrint('❌ [NotificationsRepo] Failed to get unread count: $e');
      return await _loadUnreadCount();
    }
  }

  /// تشغيل الفحوصات الذكية للإشعارات (Online فقط)
  Future<void> runSmartNotificationChecks() async {
    if (!_networkMonitor.isOnline) return;
    await _remoteSource.runSmartNotificationChecks();
  }

  /// مسح الـ Cache يدوياً
  Future<void> clearCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_cacheDataKey);
    await prefs.remove(_cacheTimeKey);
    await prefs.remove(_cacheCountKey);
    debugPrint('🗑️  [NotificationsRepo] Cache cleared');
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // PRIVATE CACHE HELPERS
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> _saveToCache(List<Map<String, dynamic>> data) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cacheDataKey, jsonEncode(data));
      await prefs.setInt(
        _cacheTimeKey,
        DateTime.now().millisecondsSinceEpoch,
      );
      // حفظ عدد الإشعارات غير المقروءة في نفس الوقت
      final unread = data.where((n) => n['is_read'] == false).length;
      await prefs.setInt(_cacheCountKey, unread);
    } catch (e) {
      debugPrint('⚠️  [NotificationsRepo] Failed to save cache: $e');
    }
  }

  Future<List<Map<String, dynamic>>?> _loadFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw   = prefs.getString(_cacheDataKey);
      if (raw == null || raw.isEmpty) return null;

      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded.cast<Map<String, dynamic>>();
      }
      return null;
    } catch (e) {
      debugPrint('⚠️  [NotificationsRepo] Failed to read cache: $e');
      return null;
    }
  }

  Future<bool> _isCacheFresh() async {
    try {
      final prefs     = await SharedPreferences.getInstance();
      final timestamp = prefs.getInt(_cacheTimeKey);
      if (timestamp == null) return false;

      final cacheTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
      final age       = DateTime.now().difference(cacheTime);
      return age < _cacheTTL;
    } catch (e) {
      return false;
    }
  }

  Future<void> _saveUnreadCount(int count) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_cacheCountKey, count);
    } catch (e) {
      debugPrint('⚠️  [NotificationsRepo] Failed to save unread count: $e');
    }
  }

  Future<int> _loadUnreadCount() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getInt(_cacheCountKey) ?? 0;
    } catch (e) {
      return 0;
    }
  }
}
