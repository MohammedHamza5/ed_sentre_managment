import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/offline/network_monitor.dart';
import '../sources/support_remote_source.dart';

/// SupportRepository — Offline-First (read-only cache)
///
/// استراتيجية التخزين:
///  1. إذا كان الجهاز Online  → اجلب من Remote وخزّن في Cache
///  2. إذا كان Offline        → اجلب من Cache (مهما كان عمرها)
///  3. إذا فشل Remote         → اجلب من Cache كـ fallback
///
/// ملاحظة: العمليات التي تكتب بيانات (فتح تذكرة، الرد) تتطلب اتصالاً بالإنترنت.
class SupportRepository {
  final SupportRemoteSource _remoteSource;
  final NetworkMonitor _networkMonitor;

  /// مدة صلاحية الـ Cache للتذاكر
  static const Duration _cacheTTL = Duration(hours: 1);

  /// مفاتيح SharedPreferences
  static const String _cacheTicketsKey = 'support_tickets_cache';
  static const String _cacheTimeKey    = 'support_tickets_cache_time';

  SupportRepository({
    SupportRemoteSource? remoteSource,
    NetworkMonitor? networkMonitor,
  })  : _remoteSource = remoteSource ?? SupportRemoteSource(),
        _networkMonitor = networkMonitor ?? NetworkMonitor();

  // ═══════════════════════════════════════════════════════════════════════════
  // PUBLIC API
  // ═══════════════════════════════════════════════════════════════════════════

  /// فتح تذكرة دعم جديدة (يتطلب اتصالاً بالإنترنت)
  Future<String> openSupportTicket({
    required String subject,
    required String description,
    required String category,
    required String priority,
  }) async {
    if (!_networkMonitor.isOnline) {
      throw Exception(
        'لا يمكن فتح تذكرة دعم بدون اتصال بالإنترنت.\n'
        'يرجى التحقق من اتصالك والمحاولة مجدداً.',
      );
    }

    final ticketId = await _remoteSource.openSupportTicket(
      subject: subject,
      description: description,
      category: category,
      priority: priority,
    );

    // تحديث الـ Cache بعد إنشاء التذكرة
    await _invalidateCache();

    return ticketId;
  }

  /// جلب تذاكر السنتر مع دعم Offline-First
  Future<List<Map<String, dynamic>>> getCenterTickets({
    bool forceRefresh = false,
  }) async {
    // ─── Offline ──────────────────────────────────────────────────────────
    if (!_networkMonitor.isOnline) {
      debugPrint('📴 [SupportRepo] Offline: trying local cache…');
      final cached = await _loadTicketsFromCache();
      if (cached != null) {
        debugPrint(
          '✅ [SupportRepo] Offline: serving ${cached.length} cached tickets',
        );
        return cached;
      }
      debugPrint('⚠️  [SupportRepo] Offline: no cache available');
      return [];
    }

    // ─── Online + Cache صالحة ─────────────────────────────────────────────
    if (!forceRefresh) {
      final cached  = await _loadTicketsFromCache();
      final isFresh = await _isCacheFresh();
      if (cached != null && isFresh) {
        debugPrint('⚡ [SupportRepo] Serving fresh cached tickets');
        return cached;
      }
    }

    // ─── Online: اجلب من Remote ثم خزّن ──────────────────────────────────
    try {
      final tickets = await _remoteSource.getCenterTickets();
      await _saveTicketsToCache(tickets);
      debugPrint(
        '✅ [SupportRepo] Remote tickets loaded & cached (${tickets.length})',
      );
      return tickets;
    } catch (e) {
      debugPrint('❌ [SupportRepo] Remote fetch failed: $e');
      final cached = await _loadTicketsFromCache();
      if (cached != null) {
        debugPrint('♻️  [SupportRepo] Serving stale cache as fallback');
        return cached;
      }
      return [];
    }
  }

  /// جلب تفاصيل تذكرة بعينها (Online فقط — البيانات حساسة ومتغيرة)
  Future<Map<String, dynamic>> getTicketDetails(String ticketId) async {
    if (!_networkMonitor.isOnline) {
      throw Exception(
        'تفاصيل التذكرة غير متاحة بدون اتصال بالإنترنت.\n'
        'يرجى التحقق من اتصالك والمحاولة مجدداً.',
      );
    }
    return await _remoteSource.getTicketDetails(ticketId);
  }

  /// إضافة رد على تذكرة (يتطلب اتصالاً بالإنترنت)
  Future<void> addTicketReply({
    required String ticketId,
    required String message,
  }) async {
    if (!_networkMonitor.isOnline) {
      throw Exception(
        'لا يمكن إرسال الرد بدون اتصال بالإنترنت.\n'
        'يرجى التحقق من اتصالك والمحاولة مجدداً.',
      );
    }
    await _remoteSource.addTicketReply(ticketId: ticketId, message: message);
  }

  /// مسح الـ Cache يدوياً
  Future<void> clearCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_cacheTicketsKey);
    await prefs.remove(_cacheTimeKey);
    debugPrint('🗑️  [SupportRepo] Cache cleared');
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // PRIVATE CACHE HELPERS
  // ═══════════════════════════════════════════════════════════════════════════

  Future<void> _saveTicketsToCache(List<Map<String, dynamic>> tickets) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cacheTicketsKey, jsonEncode(tickets));
      await prefs.setInt(
        _cacheTimeKey,
        DateTime.now().millisecondsSinceEpoch,
      );
    } catch (e) {
      debugPrint('⚠️  [SupportRepo] Failed to save cache: $e');
    }
  }

  Future<List<Map<String, dynamic>>?> _loadTicketsFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw   = prefs.getString(_cacheTicketsKey);
      if (raw == null || raw.isEmpty) return null;

      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded.cast<Map<String, dynamic>>();
      }
      return null;
    } catch (e) {
      debugPrint('⚠️  [SupportRepo] Failed to read cache: $e');
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

  /// إلغاء صلاحية الـ Cache (بعد إنشاء تذكرة جديدة)
  Future<void> _invalidateCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_cacheTimeKey); // حذف الـ timestamp فقط يجبر re-fetch
    } catch (e) {
      debugPrint('⚠️  [SupportRepo] Failed to invalidate cache: $e');
    }
  }
}
