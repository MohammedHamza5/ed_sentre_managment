import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Secure Local Storage implementation for Supabase Auth
/// Uses flutter_secure_storage to encrypt tokens on disk
class SecureLocalStorage extends GotrueAsyncStorage {
  final _storage = const FlutterSecureStorage();
  
  static const String _sessionKey = 'SUPABASE_PERSIST_SESSION_KEY';

  @override
  Future<String?> getItem({required String key}) async {
    return await _storage.read(key: key);
  }

  @override
  Future<void> setItem({required String key, required String value}) async {
    await _storage.write(key: key, value: value);
  }

  @override
  Future<void> removeItem({required String key}) async {
    await _storage.delete(key: key);
  }
}


