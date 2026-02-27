import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';

/// مراقب الشبكة - يكتشف حالة الاتصال بالإنترنت
/// يستخدم HTTP ping بدلاً من connectivity_plus لتجنب مشاكل المنصات
class NetworkMonitor extends ChangeNotifier {
  static final NetworkMonitor _instance = NetworkMonitor._internal();
  factory NetworkMonitor() => _instance;
  NetworkMonitor._internal();

  Timer? _periodicCheck;
  bool _isOnline = true;
  bool _isChecking = false;
  DateTime? _lastCheck;

  /// هل متصل بالإنترنت؟
  bool get isOnline => _isOnline;
  
  /// هل جاري الفحص؟
  bool get isChecking => _isChecking;
  
  /// آخر وقت فحص
  DateTime? get lastCheck => _lastCheck;

  /// بدء المراقبة الدورية
  void startMonitoring({Duration interval = const Duration(seconds: 30)}) {
    // فحص فوري
    checkConnection();
    
    // فحص دوري
    _periodicCheck?.cancel();
    _periodicCheck = Timer.periodic(interval, (_) => checkConnection());
    
    debugPrint('🔌 [NetworkMonitor] بدء المراقبة (كل ${interval.inSeconds} ثانية)');
  }

  /// إيقاف المراقبة
  void stopMonitoring() {
    _periodicCheck?.cancel();
    _periodicCheck = null;
    debugPrint('🔌 [NetworkMonitor] إيقاف المراقبة');
  }

  /// فحص الاتصال الآن
  Future<bool> checkConnection() async {
    if (_isChecking) return _isOnline;
    
    _isChecking = true;
    final wasOnline = _isOnline;
    
    try {
      // نحاول الاتصال بـ Google DNS (سريع وموثوق)
      final result = await InternetAddress.lookup('google.com')
          .timeout(const Duration(seconds: 5));
      
      _isOnline = result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } on SocketException {
      _isOnline = false;
    } on TimeoutException {
      _isOnline = false;
    } catch (e) {
      _isOnline = false;
      debugPrint('⚠️ [NetworkMonitor] خطأ في الفحص: $e');
    }
    
    _isChecking = false;
    _lastCheck = DateTime.now();
    
    // إشعار المستمعين إذا تغيرت الحالة
    if (wasOnline != _isOnline) {
      debugPrint(_isOnline 
          ? '✅ [NetworkMonitor] عاد الاتصال بالإنترنت' 
          : '❌ [NetworkMonitor] فقد الاتصال بالإنترنت');
      notifyListeners();
    }
    
    return _isOnline;
  }

  /// معالجة خطأ شبكة (يُستدعى من Repository)
  /// يُحدث الحالة إلى offline إذا كان الخطأ متعلق بالشبكة
  void handleNetworkError(dynamic error) {
    if (_isNetworkError(error)) {
      if (_isOnline) {
        _isOnline = false;
        debugPrint('❌ [NetworkMonitor] كُشف فقدان الاتصال من خطأ: $error');
        notifyListeners();
      }
    }
  }

  /// هل الخطأ متعلق بالشبكة؟
  bool _isNetworkError(dynamic error) {
    final errorString = error.toString().toLowerCase();
    return errorString.contains('socketexception') ||
           errorString.contains('failed host lookup') ||
           errorString.contains('no such host') ||
           errorString.contains('connection refused') ||
           errorString.contains('network is unreachable') ||
           errorString.contains('connection timed out') ||
           errorString.contains('timeout');
  }

  /// للاستخدام المستقبلي: هل الخطأ يستحق إعادة المحاولة؟
  bool isRetryableError(dynamic error) {
    return _isNetworkError(error);
  }

  @override
  void dispose() {
    stopMonitoring();
    super.dispose();
  }
}


