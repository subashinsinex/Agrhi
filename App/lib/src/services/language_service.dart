import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_mlkit_translation/google_mlkit_translation.dart';
import 'dart:convert';
import 'dart:async' show unawaited;

class LanguageService extends ChangeNotifier {
  static const String _languageKey = 'selected_language';
  static const String _downloadedModelsKey = 'downloaded_models';
  static const String _cacheKey = 'translation_cache';
  static const Locale defaultLocale = Locale('en');

  Locale _currentLocale = defaultLocale;
  Locale _previousLocale = defaultLocale;
  bool _isInitialized = false;
  bool _isTranslating = false;
  bool _isDisposed = false;
  bool _hasError = false;

  Key _rebuildKey = UniqueKey();

  final Map<String, double> _downloadProgress = {};
  final Map<String, bool> _isDownloading = {};

  // Translation cache
  final Map<String, Map<String, String>> _translationCache = {};

  Locale get currentLocale => _currentLocale;
  Locale get previousLocale => _previousLocale;
  bool get isInitialized => _isInitialized;
  bool get hasError => _hasError;
  Key get rebuildKey => _rebuildKey;

  // Critical phrases for instant switching
  static const List<String> criticalPhrases = [
    'Welcome',
    'Dashboard',
    'Smart Farming',
    'Language',
    'Changing language...',
    "Don't have an account?",
    'Sign Up',
    'Smart Farm App',
    'Skip for demo',
    'Password',
    'Phone Number',
    'Login Successful',
    'Sign In',
  ];

  // Full list for background loading
  static const List<String> commonPhrases = [
    'Welcome',
    'Enjoy our Services',
    'Dashboard',
    'Plant Doctor',
    'Disease Detection',
    'Analytics',
    'Soil Health',
    'Weather',
    'Market Prices',
    'Settings',
    'Help & Support',
    'Logout',
    'Confirm Logout',
    'Are you sure you want to log out?',
    'Cancel',
    'Logged out successfully',
    'Coming Soon',
    'This feature is under development',
    'Back to Dashboard',
    'Smart Farming',
    'Profile',
    'Hello',
  ];

  static const List<Locale> supportedLocales = [
    Locale('en'),
    Locale('hi'),
    Locale('ta'),
    Locale('te'),
    Locale('tr'),
    Locale('ms'),
  ];

  static const Map<String, String> languageNames = {
    'en': 'English',
    'hi': 'हिंदी',
    'ta': 'தமிழ்',
    'te': 'తెలుగు',
    'tr': 'Türkçe',
    'ms': 'Bahasa Melayu',
  };

  OnDeviceTranslator? _sourceToEnglishTranslator;
  OnDeviceTranslator? _englishToTargetTranslator;

  final OnDeviceTranslatorModelManager _modelManager =
      OnDeviceTranslatorModelManager();

  LanguageService() {
    _loadLanguage();
  }

  Future<void> _loadLanguage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedCode = prefs.getString(_languageKey);

      if (savedCode != null && isSupported(Locale(savedCode))) {
        _currentLocale = Locale(savedCode);
        _previousLocale = Locale(savedCode);
      } else {
        _currentLocale = defaultLocale;
        _previousLocale = defaultLocale;
      }

      _hasError = false;

      // Load cache from disk
      await _loadCacheFromDisk();

      if (!_isDisposed) {
        _isInitialized = true;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error loading language: $e');
      await _resetToEnglishOnError();
    }
  }

  Future<void> _loadCacheFromDisk() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheJson = prefs.getString(_cacheKey);

      if (cacheJson != null && cacheJson.isNotEmpty) {
        final Map<String, dynamic> decoded = json.decode(cacheJson);
        _translationCache.clear();

        decoded.forEach((langCode, translations) {
          _translationCache[langCode] = Map<String, String>.from(
            translations as Map,
          );
        });

        debugPrint(
          '✅ Loaded cache: ${_translationCache.keys.length} languages',
        );
      }
    } catch (e) {
      debugPrint('⚠️ Failed to load cache: $e');
      _translationCache.clear();
    }
  }

  Future<void> _saveCacheToDisk() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheJson = json.encode(_translationCache);
      await prefs.setString(_cacheKey, cacheJson);
      debugPrint('💾 Cache saved to disk');
    } catch (e) {
      debugPrint('⚠️ Failed to save cache: $e');
    }
  }

  // OPTIMIZED: Fast preload with optional full load
  Future<void> preloadTranslations({bool fullLoad = false}) async {
    if (_currentLocale.languageCode == 'en') {
      debugPrint('✓ English - no preload needed');
      return;
    }

    final cacheKey = _currentLocale.languageCode;
    final phrasesToLoad = fullLoad ? commonPhrases : criticalPhrases;

    // Check if already preloaded
    if (_translationCache.containsKey(cacheKey) &&
        _translationCache[cacheKey]!.length >= phrasesToLoad.length * 0.8) {
      debugPrint('✅ Translations already preloaded from cache');
      return;
    }

    debugPrint('⏬ Preloading ${phrasesToLoad.length} phrases...');

    _translationCache[cacheKey] = _translationCache[cacheKey] ?? {};

    int loaded = 0;
    for (String phrase in phrasesToLoad) {
      try {
        if (_translationCache[cacheKey]!.containsKey(phrase)) {
          loaded++;
          continue;
        }

        final translated = await _translateText(phrase);
        _translationCache[cacheKey]![phrase] = translated;
        loaded++;

        if (loaded % 3 == 0) {
          await _saveCacheToDisk();
        }
      } catch (e) {
        debugPrint('⚠️ Failed to preload: $phrase');
      }
    }

    debugPrint('✅ Preloaded $loaded/${phrasesToLoad.length} phrases');

    await _saveCacheToDisk();
    notifyListeners();

    // Load remaining phrases in background
    if (!fullLoad) {
      unawaited(_loadRemainingPhrases());
    }
  }

  Future<void> _loadRemainingPhrases() async {
    await Future.delayed(const Duration(milliseconds: 500));
    await preloadTranslations(fullLoad: true);
  }

  // OPTIMIZED: Instant language switch with background preloading
  Future<void> changeLanguage(Locale locale, {Locale? previousLocale}) async {
    if (_isDisposed) return;

    if (!isSupported(locale)) {
      locale = defaultLocale;
    }

    if (_currentLocale == locale) return;

    try {
      while (_isTranslating) {
        await Future.delayed(const Duration(milliseconds: 100));
      }

      _previousLocale = previousLocale ?? _currentLocale;
      _currentLocale = locale;

      debugPrint(
        'Changing language from ${_previousLocale.languageCode} to ${_currentLocale.languageCode}',
      );

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_languageKey, locale.languageCode);

      await _prepareTranslators();
      _hasError = false;

      // Update UI immediately
      _rebuildKey = UniqueKey();

      if (!_isDisposed) {
        notifyListeners();
      }

      // Preload translations in background (non-blocking)
      unawaited(_preloadTranslationsInBackground());
    } catch (e) {
      debugPrint('Error changing language: $e');
      await _resetToEnglishOnError();
    }
  }

  Future<void> _preloadTranslationsInBackground() async {
    try {
      await preloadTranslations();
      debugPrint('✅ Background preloading completed');
    } catch (e) {
      debugPrint('⚠️ Background preloading failed: $e');
    }
  }

  Future<void> _prepareTranslators() async {
    if (_isDisposed) return;

    try {
      while (_isTranslating) {
        await Future.delayed(const Duration(milliseconds: 100));
      }

      try {
        _sourceToEnglishTranslator?.close();
        _englishToTargetTranslator?.close();
      } catch (e) {
        debugPrint('Error closing old translators: $e');
      }

      _sourceToEnglishTranslator = null;
      _englishToTargetTranslator = null;

      final previousLang = _mapToTranslatorLanguage(_previousLocale);
      final currentLang = _mapToTranslatorLanguage(_currentLocale);

      if (_currentLocale.languageCode == 'en') {
        debugPrint('Target is English - no translators needed');
        return;
      }

      if (_previousLocale.languageCode == 'en') {
        debugPrint('Creating translator: en -> ${_currentLocale.languageCode}');

        if (!_isDisposed) {
          _englishToTargetTranslator = OnDeviceTranslator(
            sourceLanguage: TranslateLanguage.english,
            targetLanguage: currentLang,
          );
        }
        return;
      }

      debugPrint(
        'Creating two-step translators: ${_previousLocale.languageCode} -> en -> ${_currentLocale.languageCode}',
      );

      if (!_isDisposed) {
        _sourceToEnglishTranslator = OnDeviceTranslator(
          sourceLanguage: previousLang,
          targetLanguage: TranslateLanguage.english,
        );

        _englishToTargetTranslator = OnDeviceTranslator(
          sourceLanguage: TranslateLanguage.english,
          targetLanguage: currentLang,
        );
      }
    } catch (e) {
      debugPrint('Error preparing translators: $e');
      rethrow;
    }
  }

  TranslateLanguage _mapToTranslatorLanguage(Locale locale) {
    switch (locale.languageCode) {
      case 'hi':
        return TranslateLanguage.hindi;
      case 'ta':
        return TranslateLanguage.tamil;
      case 'te':
        return TranslateLanguage.telugu;
      case 'tr':
        return TranslateLanguage.turkish;
      case 'ms':
        return TranslateLanguage.malay;
      default:
        return TranslateLanguage.english;
    }
  }

  Future<String> translate(String text) async {
    if (_isDisposed || _hasError || text.trim().isEmpty) return text;

    if (_currentLocale.languageCode == 'en') {
      return text;
    }

    // Check cache first
    final cacheKey = _currentLocale.languageCode;
    if (_translationCache.containsKey(cacheKey) &&
        _translationCache[cacheKey]!.containsKey(text)) {
      return _translationCache[cacheKey]![text]!;
    }

    // If not in cache, translate and cache it
    _isTranslating = true;

    try {
      final translated = await _translateText(text);

      // Store in cache
      if (!_translationCache.containsKey(cacheKey)) {
        _translationCache[cacheKey] = {};
      }
      _translationCache[cacheKey]![text] = translated;

      // Save to disk (async, don't wait)
      unawaited(_saveCacheToDisk());

      return translated;
    } catch (e) {
      debugPrint('Translation error: $e');
      return text;
    } finally {
      _isTranslating = false;
    }
  }

  Future<String> _translateText(String text) async {
    if (_englishToTargetTranslator == null) {
      await _prepareTranslators();
    }

    if (_isDisposed) {
      return text;
    }

    if (_sourceToEnglishTranslator == null &&
        _englishToTargetTranslator != null) {
      try {
        final translatedText = await _englishToTargetTranslator!
            .translateText(text)
            .timeout(
              const Duration(minutes: 3),
              onTimeout: () {
                debugPrint('⏱️ Translation timeout');
                return text;
              },
            );
        return translatedText;
      } catch (e) {
        debugPrint('Translation error: $e');
        throw e;
      }
    }

    if (_sourceToEnglishTranslator != null &&
        _englishToTargetTranslator != null) {
      try {
        final englishText = await _sourceToEnglishTranslator!
            .translateText(text)
            .timeout(const Duration(minutes: 3), onTimeout: () => text);

        final targetText = await _englishToTargetTranslator!
            .translateText(englishText)
            .timeout(const Duration(minutes: 3), onTimeout: () => englishText);

        return targetText;
      } catch (e) {
        debugPrint('Two-step translation error: $e');
        throw e;
      }
    }

    return text;
  }

  Future<List<String>> translateBatch(List<String> texts) async {
    final results = <String>[];

    for (final text in texts) {
      final translated = await translate(text);
      results.add(translated);
    }

    return results;
  }

  Future<void> clearCache([String? languageCode]) async {
    if (languageCode != null) {
      _translationCache.remove(languageCode);
      debugPrint('🗑️ Cleared cache for $languageCode');
    } else {
      _translationCache.clear();
      debugPrint('🗑️ Cleared all translation cache');
    }

    await _saveCacheToDisk();
    notifyListeners();
  }

  Map<String, int> getCacheStats() {
    final stats = <String, int>{};
    _translationCache.forEach((lang, translations) {
      stats[lang] = translations.length;
    });
    return stats;
  }

  Future<void> _resetToEnglishOnError() async {
    debugPrint('Resetting to English due to error');
    _hasError = true;
    _currentLocale = defaultLocale;
    _previousLocale = defaultLocale;

    try {
      _sourceToEnglishTranslator?.close();
      _englishToTargetTranslator?.close();
    } catch (e) {
      debugPrint('Error closing translators during reset: $e');
    }

    _sourceToEnglishTranslator = null;
    _englishToTargetTranslator = null;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_languageKey, defaultLocale.languageCode);

    _rebuildKey = UniqueKey();

    if (!_isDisposed) {
      notifyListeners();
    }
  }

  String get currentLanguageName =>
      languageNames[_currentLocale.languageCode] ?? 'English';

  bool isSupported(Locale locale) =>
      supportedLocales.any((l) => l.languageCode == locale.languageCode);

  bool isRTL() {
    const rtlLanguages = ['ar', 'he', 'fa', 'ur'];
    return rtlLanguages.contains(_currentLocale.languageCode);
  }

  Future<void> resetToDefault() async {
    await changeLanguage(defaultLocale);
  }

  @override
  void dispose() {
    _isDisposed = true;

    Future.delayed(const Duration(milliseconds: 200), () {
      try {
        _sourceToEnglishTranslator?.close();
        _englishToTargetTranslator?.close();
        _sourceToEnglishTranslator = null;
        _englishToTargetTranslator = null;
      } catch (e) {
        debugPrint('Error disposing translators: $e');
      }
    });

    super.dispose();
  }

  // ============ MODEL MANAGEMENT METHODS ============

  Future<bool> isLanguageModelDownloaded(String languageCode) async {
    try {
      if (languageCode == 'en') return true;

      final locale = Locale(languageCode);
      final translateLang = _mapToTranslatorLanguage(locale);

      final isDownloaded = await _modelManager
          .isModelDownloaded(translateLang.bcpCode)
          .timeout(
            const Duration(seconds: 5),
            onTimeout: () {
              debugPrint('⏱️ Check timeout for $languageCode');
              return false;
            },
          );

      debugPrint('📱 Model $languageCode downloaded: $isDownloaded');
      return isDownloaded;
    } catch (e) {
      debugPrint('❌ Error checking model: $e');
      return false;
    }
  }

  bool isDownloadingModel(String languageCode) {
    return _isDownloading[languageCode] ?? false;
  }

  double getDownloadProgress(String languageCode) {
    return _downloadProgress[languageCode] ?? 0.0;
  }

  Future<bool> downloadLanguageModel(
    String languageCode, {
    bool allowCellular = true,
  }) async {
    if (languageCode == 'en') {
      debugPrint('✓ English is always available');
      return true;
    }

    if (_isDownloading[languageCode] == true) {
      debugPrint('⚠️ Already downloading $languageCode');
      return false;
    }

    try {
      _isDownloading[languageCode] = true;
      _downloadProgress[languageCode] = 0.0;
      notifyListeners();

      final locale = Locale(languageCode);
      final translateLang = _mapToTranslatorLanguage(locale);
      final bcpCode = translateLang.bcpCode;

      final alreadyDownloaded = await _modelManager
          .isModelDownloaded(bcpCode)
          .timeout(const Duration(seconds: 10), onTimeout: () => false);

      if (alreadyDownloaded) {
        debugPrint('✅ Model $languageCode already downloaded');
        _downloadProgress[languageCode] = 1.0;
        _isDownloading[languageCode] = false;
        notifyListeners();
        await _markAsDownloaded(languageCode);
        return true;
      }

      debugPrint('⏬ Starting download: $languageCode ($bcpCode)');
      debugPrint('📊 Estimated size: 30-40 MB');
      debugPrint('⏱️ Expected time: 30-90 seconds on WiFi');

      _simulateDownloadProgress(languageCode);

      final success = await _modelManager
          .downloadModel(bcpCode, isWifiRequired: !allowCellular)
          .timeout(
            const Duration(minutes: 5),
            onTimeout: () {
              debugPrint('⏱️ Download timeout after 5 minutes');
              return false;
            },
          );

      _isDownloading[languageCode] = false;

      if (success) {
        debugPrint('✅ Download completed for $languageCode');
        _downloadProgress[languageCode] = 1.0;

        await Future.delayed(const Duration(seconds: 1));
        final verified = await _modelManager.isModelDownloaded(bcpCode);

        if (verified) {
          debugPrint('✅✅ Model $languageCode verified and ready!');
          await _markAsDownloaded(languageCode);

          // Preload translations after model download
          if (_currentLocale.languageCode == languageCode) {
            unawaited(preloadTranslations());
          }

          notifyListeners();
          return true;
        } else {
          debugPrint('⚠️ Download reported success but verification failed');
          _downloadProgress[languageCode] = 0.0;
          notifyListeners();
          return false;
        }
      } else {
        debugPrint('❌ Download failed for $languageCode');
        _downloadProgress[languageCode] = 0.0;
        notifyListeners();
        return false;
      }
    } catch (e) {
      debugPrint('❌ Error downloading $languageCode: $e');
      _isDownloading[languageCode] = false;
      _downloadProgress[languageCode] = 0.0;
      notifyListeners();
      return false;
    }
  }

  void _simulateDownloadProgress(String languageCode) {
    int step = 0;
    const totalSteps = 30;

    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));

      if (_isDownloading[languageCode] != true || step >= totalSteps) {
        return false;
      }

      step++;
      _downloadProgress[languageCode] = (step / totalSteps) * 0.9;
      notifyListeners();

      return true;
    });
  }

  Future<void> _markAsDownloaded(String languageCode) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final downloaded = prefs.getStringList(_downloadedModelsKey) ?? [];

      if (!downloaded.contains(languageCode)) {
        downloaded.add(languageCode);
        await prefs.setStringList(_downloadedModelsKey, downloaded);
      }
    } catch (e) {
      debugPrint('Error marking as downloaded: $e');
    }
  }

  Future<bool> deleteLanguageModel(String languageCode) async {
    if (languageCode == 'en') {
      debugPrint('❌ Cannot delete English');
      return false;
    }

    if (languageCode == _currentLocale.languageCode) {
      debugPrint('❌ Cannot delete currently active language');
      return false;
    }

    try {
      final locale = Locale(languageCode);
      final translateLang = _mapToTranslatorLanguage(locale);

      debugPrint('🗑️ Deleting model: $languageCode');

      final success = await _modelManager
          .deleteModel(translateLang.bcpCode)
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () {
              debugPrint('⏱️ Delete timeout');
              return false;
            },
          );

      if (success) {
        debugPrint('✅ Model $languageCode deleted');

        final prefs = await SharedPreferences.getInstance();
        final downloaded = prefs.getStringList(_downloadedModelsKey) ?? [];
        downloaded.remove(languageCode);
        await prefs.setStringList(_downloadedModelsKey, downloaded);

        await clearCache(languageCode);

        notifyListeners();
        return true;
      } else {
        debugPrint('❌ Failed to delete $languageCode');
        return false;
      }
    } catch (e) {
      debugPrint('❌ Error deleting $languageCode: $e');
      return false;
    }
  }

  Future<Set<String>> getDownloadedLanguages() async {
    final downloaded = <String>{'en'};

    for (final locale in supportedLocales) {
      if (locale.languageCode != 'en') {
        try {
          final isDownloaded = await isLanguageModelDownloaded(
            locale.languageCode,
          );
          if (isDownloaded) {
            downloaded.add(locale.languageCode);
          }
        } catch (e) {
          // Continue silently
        }
      }
    }

    debugPrint('📱 Downloaded languages: $downloaded');
    return downloaded;
  }

  Future<String> getEstimatedStorageUsed() async {
    final downloaded = await getDownloadedLanguages();
    final count = downloaded.length - 1;
    final sizeMB = count * 35;

    if (sizeMB < 1024) {
      return '$sizeMB MB';
    } else {
      final sizeGB = (sizeMB / 1024).toStringAsFixed(2);
      return '$sizeGB GB';
    }
  }

  Future<Map<String, bool>> downloadAllLanguages() async {
    final results = <String, bool>{};

    for (final locale in supportedLocales) {
      if (locale.languageCode != 'en') {
        debugPrint('📦 Batch downloading: ${locale.languageCode}');
        final success = await downloadLanguageModel(locale.languageCode);
        results[locale.languageCode] = success;

        await Future.delayed(const Duration(seconds: 2));
      }
    }

    return results;
  }
}
