import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_mlkit_translation/google_mlkit_translation.dart';
import 'dart:convert';
import 'dart:async' show unawaited, Completer;

class LanguageService extends ChangeNotifier {
  static const String _languageKey = 'selected_language';
  static const String _downloadedModelsKey = 'downloaded_models';
  static const String _cacheKey = 'translation_cache';
  static const Locale defaultLocale = Locale('en');

  Locale _currentLocale = defaultLocale;
  Locale _previousLocale = defaultLocale;
  bool _isInitialized = false;
  bool _isDisposed = false;
  bool _hasError = false;

  Key _rebuildKey = UniqueKey();

  final Map<String, double> _downloadProgress = {};
  final Map<String, bool> _isDownloading = {};

  // Translation cache
  final Map<String, Map<String, String>> _translationCache = {};
  Map<String, Map<String, String>> get translationCache => _translationCache;

  // Race condition prevention
  final Map<String, Completer<String>> _inFlightTranslations = {};

  // Track untranslated texts
  final Set<String> _untranslatedTexts = {};
  Set<String> get untranslatedTexts => Set.from(_untranslatedTexts);

  // Cache performance
  int _cacheHits = 0;
  int _cacheMisses = 0;
  int _duplicateRequestsPrevented = 0;

  int get cacheHits => _cacheHits;
  int get cacheMisses => _cacheMisses;
  int get duplicateRequestsPrevented => _duplicateRequestsPrevented;

  double get cacheHitRate => (_cacheHits + _cacheMisses) > 0
      ? _cacheHits / (_cacheHits + _cacheMisses)
      : 0.0;

  Set<String> get pendingTranslations => _inFlightTranslations.keys.toSet();

  Locale get currentLocale => _currentLocale;
  Locale get previousLocale => _previousLocale;
  bool get isInitialized => _isInitialized;
  bool get hasError => _hasError;
  Key get rebuildKey => _rebuildKey;

  // ============ OPTIMIZED: Parallel translation limit ============
  static const int _maxParallelTranslations = 5;
  int _activeTranslations = 0;

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
    'More Info',
    'Settings',
    'Logout',
    'Cancel',
    'OK',
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
    'More Info',
    'Search by title or state',
    'Title A-Z',
    'Title Z-A',
    'State A-Z',
    'State Z-A',
    'Tamil Nadu',
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
          '✅ Loaded cache: ${_translationCache.keys.length} languages, '
          '${_translationCache.values.fold(0, (sum, map) => sum + map.length)} total phrases',
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

      final totalPhrases = _translationCache.values.fold(
        0,
        (sum, map) => sum + map.length,
      );
      debugPrint('💾 Cache saved: $totalPhrases phrases');
    } catch (e) {
      debugPrint('⚠️ Failed to save cache: $e');
    }
  }

  // ============ OPTIMIZED: Batch preloading with throttling ============
  Future<void> preloadTranslations({bool fullLoad = false}) async {
    if (_currentLocale.languageCode == 'en') {
      debugPrint('✓ English - no preload needed');
      return;
    }

    final cacheKey = _currentLocale.languageCode;
    final phrasesToLoad = fullLoad ? commonPhrases : criticalPhrases;

    if (_translationCache.containsKey(cacheKey) &&
        _translationCache[cacheKey]!.length >= phrasesToLoad.length * 0.8) {
      debugPrint('✅ Already preloaded from cache');
      return;
    }

    debugPrint('⚡ Fast preloading ${phrasesToLoad.length} phrases...');

    _translationCache[cacheKey] = _translationCache[cacheKey] ?? {};

    int loaded = 0;
    int fromCache = 0;
    int newTranslations = 0;

    // Process in batches of 5 for optimal speed
    for (int i = 0; i < phrasesToLoad.length; i += _maxParallelTranslations) {
      final batch = phrasesToLoad
          .skip(i)
          .take(_maxParallelTranslations)
          .toList();

      final futures = batch.map((phrase) async {
        if (_translationCache[cacheKey]!.containsKey(phrase)) {
          fromCache++;
          return;
        }

        try {
          final translated = await _translateText(phrase);
          _translationCache[cacheKey]![phrase] = translated;
          newTranslations++;
        } catch (e) {
          debugPrint('⚠️ Failed: $phrase');
        }
      }).toList();

      await Future.wait(futures);
      loaded = fromCache + newTranslations;

      // Save periodically
      if (loaded % 10 == 0) {
        await _saveCacheToDisk();
      }
    }

    debugPrint(
      '✅ Preloaded $loaded/${phrasesToLoad.length} '
      '($fromCache cached, $newTranslations new)',
    );

    await _saveCacheToDisk();
    notifyListeners();

    if (!fullLoad) {
      unawaited(_loadRemainingPhrases());
    }
  }

  Future<void> _loadRemainingPhrases() async {
    await Future.delayed(const Duration(milliseconds: 300));
    debugPrint('🔄 Background loading remaining phrases...');
    await preloadTranslations(fullLoad: true);
    debugPrint('✅ Background complete');
  }

  // ============ NEW: Preload specific texts (for dynamic content) ============
  Future<void> preloadTexts(
    List<String> texts, {
    bool highPriority = false,
  }) async {
    if (_currentLocale.languageCode == 'en' || texts.isEmpty) return;

    final cacheKey = _currentLocale.languageCode;
    _translationCache[cacheKey] = _translationCache[cacheKey] ?? {};

    // Filter out already cached texts
    final uncachedTexts = texts
        .where((text) => !_translationCache[cacheKey]!.containsKey(text))
        .toList();

    if (uncachedTexts.isEmpty) {
      debugPrint('✅ All ${texts.length} texts already cached');
      return;
    }

    debugPrint('⚡ Preloading ${uncachedTexts.length} texts...');

    int translated = 0;

    // Process in parallel batches
    for (int i = 0; i < uncachedTexts.length; i += _maxParallelTranslations) {
      final batch = uncachedTexts
          .skip(i)
          .take(_maxParallelTranslations)
          .toList();

      final futures = batch.map((text) async {
        try {
          final result = await _translateText(text);
          _translationCache[cacheKey]![text] = result;
          translated++;

          if (translated % 5 == 0) {
            debugPrint('  ⏳ Progress: $translated/${uncachedTexts.length}');
          }
        } catch (e) {
          debugPrint('  ❌ Failed: ${text.substring(0, 30)}...');
        }
      }).toList();

      await Future.wait(futures);

      // Save after each batch
      if (highPriority || translated % 10 == 0) {
        await _saveCacheToDisk();
      }
    }

    await _saveCacheToDisk();
    debugPrint('✅ Preloaded $translated/${uncachedTexts.length} texts');
    notifyListeners();
  }

  // ============ OPTIMIZED: Instant language switch ============
  Future<void> changeLanguage(Locale locale, {Locale? previousLocale}) async {
    if (_isDisposed) return;

    if (!isSupported(locale)) {
      locale = defaultLocale;
    }

    if (_currentLocale == locale) return;

    try {
      _previousLocale = previousLocale ?? _currentLocale;
      _currentLocale = locale;

      debugPrint(
        'Changing: ${_previousLocale.languageCode} -> ${_currentLocale.languageCode}',
      );

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_languageKey, locale.languageCode);

      await _prepareTranslators();
      _hasError = false;

      _untranslatedTexts.clear();
      _inFlightTranslations.clear();

      _rebuildKey = UniqueKey();

      if (!_isDisposed) {
        notifyListeners();
      }

      // Critical phrases first (blocking)
      await preloadTranslations(fullLoad: false);

      // Full list in background (non-blocking)
      unawaited(preloadTranslations(fullLoad: true));
    } catch (e) {
      debugPrint('Error changing language: $e');
      await _resetToEnglishOnError();
    }
  }

  Future<void> _prepareTranslators() async {
    if (_isDisposed) return;

    try {
      try {
        _sourceToEnglishTranslator?.close();
        _englishToTargetTranslator?.close();
      } catch (e) {
        debugPrint('Error closing translators: $e');
      }

      _sourceToEnglishTranslator = null;
      _englishToTargetTranslator = null;

      final previousLang = _mapToTranslatorLanguage(_previousLocale);
      final currentLang = _mapToTranslatorLanguage(_currentLocale);

      if (_currentLocale.languageCode == 'en') {
        debugPrint('Target: English - no translators needed');
        return;
      }

      if (_previousLocale.languageCode == 'en') {
        debugPrint('Creating: en -> ${_currentLocale.languageCode}');

        if (!_isDisposed) {
          _englishToTargetTranslator = OnDeviceTranslator(
            sourceLanguage: TranslateLanguage.english,
            targetLanguage: currentLang,
          );
        }
        return;
      }

      debugPrint(
        'Creating: ${_previousLocale.languageCode} -> en -> ${_currentLocale.languageCode}',
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

  // ============ OPTIMIZED: Translation with throttling ============
  Future<String> translate(String text) async {
    if (_isDisposed || _hasError || text.trim().isEmpty) return text;

    if (_currentLocale.languageCode == 'en') {
      return text;
    }

    final cacheKey = _currentLocale.languageCode;

    // Check cache first
    if (_translationCache.containsKey(cacheKey) &&
        _translationCache[cacheKey]!.containsKey(text)) {
      _cacheHits++;
      return _translationCache[cacheKey]![text]!;
    }

    // Check if already being translated
    if (_inFlightTranslations.containsKey(text)) {
      _duplicateRequestsPrevented++;
      try {
        return await _inFlightTranslations[text]!.future;
      } catch (e) {
        return text;
      }
    }

    // Cache miss
    _cacheMisses++;
    _untranslatedTexts.add(text);

    final completer = Completer<String>();
    _inFlightTranslations[text] = completer;

    _activeTranslations++;

    try {
      final translated = await _translateText(text);

      if (!_translationCache.containsKey(cacheKey)) {
        _translationCache[cacheKey] = {};
      }
      _translationCache[cacheKey]![text] = translated;

      _untranslatedTexts.remove(text);

      if (!completer.isCompleted) {
        completer.complete(translated);
      }

      // Save every 10 translations
      if (_translationCache[cacheKey]!.length % 10 == 0) {
        await _saveCacheToDisk();
      }

      return translated;
    } catch (e) {
      if (!completer.isCompleted) {
        completer.complete(text);
      }
      return text;
    } finally {
      _activeTranslations--;
      _inFlightTranslations.remove(text);
    }
  }

  Future<String> _translateText(String text) async {
    if (_englishToTargetTranslator == null) {
      await _prepareTranslators();
    }

    if (_isDisposed) return text;

    // Single-step translation
    if (_sourceToEnglishTranslator == null &&
        _englishToTargetTranslator != null) {
      try {
        return await _englishToTargetTranslator!
            .translateText(text)
            .timeout(const Duration(seconds: 15), onTimeout: () => text);
      } catch (e) {
        return text;
      }
    }

    // Two-step translation
    if (_sourceToEnglishTranslator != null &&
        _englishToTargetTranslator != null) {
      try {
        final englishText = await _sourceToEnglishTranslator!
            .translateText(text)
            .timeout(const Duration(seconds: 15), onTimeout: () => text);

        return await _englishToTargetTranslator!
            .translateText(englishText)
            .timeout(const Duration(seconds: 15), onTimeout: () => englishText);
      } catch (e) {
        return text;
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
      debugPrint('🗑️ Cleared: $languageCode');
    } else {
      _translationCache.clear();
      _cacheHits = 0;
      _cacheMisses = 0;
      _duplicateRequestsPrevented = 0;
      debugPrint('🗑️ Cleared all cache');
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

  Map<String, dynamic> getTranslationStats() {
    return {
      'current_language': _currentLocale.languageCode,
      'cached_languages': _translationCache.keys.length,
      'total_cached_phrases': _translationCache.values.fold(
        0,
        (sum, map) => sum + map.length,
      ),
      'cache_stats_by_language': getCacheStats(),
      'cache_hits': _cacheHits,
      'cache_misses': _cacheMisses,
      'cache_hit_rate': cacheHitRate,
      'cache_hit_rate_percent': '${(cacheHitRate * 100).toStringAsFixed(1)}%',
      'duplicate_requests_prevented': _duplicateRequestsPrevented,
      'untranslated_texts_count': _untranslatedTexts.length,
      'pending_translations_count': _inFlightTranslations.length,
      'active_translations': _activeTranslations,
    };
  }

  void resetStatistics() {
    _cacheHits = 0;
    _cacheMisses = 0;
    _duplicateRequestsPrevented = 0;
    _untranslatedTexts.clear();
    _inFlightTranslations.clear();
    notifyListeners();
  }

  List<String> getUntranslatedTexts() => _untranslatedTexts.toList();

  bool isTextCached(String text) {
    final cacheKey = _currentLocale.languageCode;
    return _translationCache.containsKey(cacheKey) &&
        _translationCache[cacheKey]!.containsKey(text);
  }

  Future<void> _resetToEnglishOnError() async {
    _hasError = true;
    _currentLocale = defaultLocale;
    _previousLocale = defaultLocale;

    try {
      _sourceToEnglishTranslator?.close();
      _englishToTargetTranslator?.close();
    } catch (e) {}

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
      } catch (e) {}
    });

    super.dispose();
  }

  // [Include all model management methods from previous code]
  // (isLanguageModelDownloaded, downloadLanguageModel, deleteLanguageModel, etc.)

  Future<bool> isLanguageModelDownloaded(String languageCode) async {
    try {
      if (languageCode == 'en') return true;

      final locale = Locale(languageCode);
      final translateLang = _mapToTranslatorLanguage(locale);

      final isDownloaded = await _modelManager
          .isModelDownloaded(translateLang.bcpCode)
          .timeout(const Duration(seconds: 5), onTimeout: () => false);

      return isDownloaded;
    } catch (e) {
      return false;
    }
  }

  bool isDownloadingModel(String languageCode) =>
      _isDownloading[languageCode] ?? false;

  double getDownloadProgress(String languageCode) =>
      _downloadProgress[languageCode] ?? 0.0;

  Future<bool> downloadLanguageModel(
    String languageCode, {
    bool allowCellular = true,
  }) async {
    if (languageCode == 'en') return true;
    if (_isDownloading[languageCode] == true) return false;

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
        _downloadProgress[languageCode] = 1.0;
        _isDownloading[languageCode] = false;
        notifyListeners();
        await _markAsDownloaded(languageCode);
        return true;
      }

      _simulateDownloadProgress(languageCode);

      final success = await _modelManager
          .downloadModel(bcpCode, isWifiRequired: !allowCellular)
          .timeout(const Duration(minutes: 5), onTimeout: () => false);

      _isDownloading[languageCode] = false;

      if (success) {
        _downloadProgress[languageCode] = 1.0;
        await _markAsDownloaded(languageCode);

        if (_currentLocale.languageCode == languageCode) {
          unawaited(preloadTranslations());
        }

        notifyListeners();
        return true;
      }

      _downloadProgress[languageCode] = 0.0;
      notifyListeners();
      return false;
    } catch (e) {
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
    } catch (e) {}
  }

  Future<bool> deleteLanguageModel(String languageCode) async {
    if (languageCode == 'en') return false;
    if (languageCode == _currentLocale.languageCode) return false;

    try {
      final locale = Locale(languageCode);
      final translateLang = _mapToTranslatorLanguage(locale);

      final success = await _modelManager
          .deleteModel(translateLang.bcpCode)
          .timeout(const Duration(seconds: 30), onTimeout: () => false);

      if (success) {
        final prefs = await SharedPreferences.getInstance();
        final downloaded = prefs.getStringList(_downloadedModelsKey) ?? [];
        downloaded.remove(languageCode);
        await prefs.setStringList(_downloadedModelsKey, downloaded);

        await clearCache(languageCode);
        notifyListeners();
        return true;
      }

      return false;
    } catch (e) {
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
          if (isDownloaded) downloaded.add(locale.languageCode);
        } catch (e) {}
      }
    }

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

  void printStatisticsReport() {
    final stats = getTranslationStats();
    debugPrint('');
    debugPrint('╔═══════════════════════════════════════════╗');
    debugPrint('║   TRANSLATION STATISTICS                 ║');
    debugPrint('╠═══════════════════════════════════════════╣');
    debugPrint('║ Language: ${stats['current_language']}');
    debugPrint('║ Cached: ${stats['total_cached_phrases']} phrases');
    debugPrint('║ Hit Rate: ${stats['cache_hit_rate_percent']}');
    debugPrint(
      '║ Duplicates Prevented: ${stats['duplicate_requests_prevented']}',
    );
    debugPrint('║ Pending: ${stats['pending_translations_count']}');
    debugPrint('╚═══════════════════════════════════════════╝');
    debugPrint('');
  }
}
