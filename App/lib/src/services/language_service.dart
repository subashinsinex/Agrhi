import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LanguageService extends ChangeNotifier {
  static const String _languageKey = 'selected_language';
  Locale _currentLocale = const Locale('en');
  bool _isInitialized = false; // ✅ Track initialization state

  Locale get currentLocale => _currentLocale;
  bool get isInitialized => _isInitialized; // ✅ Getter for initialization state

  // Supported locales
  static const List<Locale> supportedLocales = [
    Locale('en', ''), // English
    Locale('hi', ''), // Hindi
    Locale('ta', ''), // Tamil
    Locale('te', ''), // Telugu
  ];

  // Language names with native script
  static const Map<String, String> languageNames = {
    'en': 'English',
    'hi': 'हिंदी',
    'ta': 'தமிழ்',
    'te': 'తెలుగు',
  };

  LanguageService() {
    _loadLanguage();
  }

  Future<void> _loadLanguage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final languageCode = prefs.getString(_languageKey) ?? 'en';
      _currentLocale = Locale(languageCode);
      _isInitialized = true; // ✅ Mark as initialized
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading language: $e');
      _isInitialized = true; // ✅ Mark as initialized even on error
      notifyListeners();
    }
  }

  Future<void> changeLanguage(Locale locale) async {
    if (_currentLocale == locale) return;

    try {
      _currentLocale = locale;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_languageKey, locale.languageCode);
      notifyListeners();
    } catch (e) {
      debugPrint('Error changing language: $e');
    }
  }

  String getLanguageName(String languageCode) {
    return languageNames[languageCode] ?? 'Unknown';
  }

  // ✅ Get current language display name
  String get currentLanguageName {
    return getLanguageName(_currentLocale.languageCode);
  }

  // ✅ Check if locale is supported
  bool isSupported(Locale locale) {
    return supportedLocales.any((l) => l.languageCode == locale.languageCode);
  }

  bool isRTL() {
    // Add RTL languages if needed in future
    const rtlLanguages = ['ar', 'he', 'fa', 'ur'];
    return rtlLanguages.contains(_currentLocale.languageCode);
  }

  // ✅ Reset to default language
  Future<void> resetToDefault() async {
    await changeLanguage(const Locale('en'));
  }
}
