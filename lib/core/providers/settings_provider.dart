import 'package:flutter/material.dart';

import 'package:shared_preferences/shared_preferences.dart';

/// مزود الإعدادات لإدارة حالة التطبيق
class SettingsProvider extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.light;
  Locale _locale = const Locale('ar');
  String _currency = 'EGP';
  bool _isInitialized = false;

  SettingsProvider() {
    _loadSettings();
  }

  ThemeMode get themeMode => _themeMode;
  Locale get locale => _locale;
  String get currency => _currency;
  bool get isDarkMode => _themeMode == ThemeMode.dark;
  bool get isInitialized => _isInitialized;

  // Notifications Settings
  bool _emailNotifications = true;
  bool _smsNotifications = true;

  bool get emailNotifications => _emailNotifications;
  bool get smsNotifications => _smsNotifications;

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Load Theme
    final isDark = prefs.getBool('is_dark_mode') ?? false;
    _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
    
    // Load Locale
    final langCode = prefs.getString('language_code') ?? 'ar';
    _locale = Locale(langCode);
    
    // Load Currency
    _currency = prefs.getString('currency') ?? 'EGP';

    // Load Notifications
    _emailNotifications = prefs.getBool('notifications_email') ?? true;
    _smsNotifications = prefs.getBool('notifications_sms') ?? true;
    
    _isInitialized = true;
    notifyListeners();
  }

  Future<void> toggleTheme(bool isDark) async {
    _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
    notifyListeners();
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_dark_mode', isDark);
  }

  Future<void> setLocale(String languageCode) async {
    _locale = Locale(languageCode);
    notifyListeners();
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('language_code', languageCode);
  }

  Future<void> setCurrency(String currency) async {
    _currency = currency;
    notifyListeners();
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('currency', currency);
  }

  Future<void> setNotificationSettings({bool? email, bool? sms}) async {
    if (email != null) _emailNotifications = email;
    if (sms != null) _smsNotifications = sms;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    if (email != null) await prefs.setBool('notifications_email', email);
    if (sms != null) await prefs.setBool('notifications_sms', sms);
  }
}



