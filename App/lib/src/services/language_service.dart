// language_service.dart
import 'dart:async' show Completer, Timer, unawaited;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_mlkit_translation/google_mlkit_translation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:quiver/cache.dart';

class LanguageService extends ChangeNotifier {
  static const String _languageKey = 'selected_language';
  static const String _downloadedModelsKey = 'downloaded_models';
  static const String _hiveBoxName = 'translation_cache';
  static const Locale defaultLocale = Locale('en');

  Locale _currentLocale = defaultLocale;
  Locale _previousLocale = defaultLocale;
  // ignore: unused_field
  bool _isInitialized = false;
  bool _isDisposed = false;
  bool _hasError = false;

  // ignore: unused_field
  Key _rebuildKey = UniqueKey();

  final Map<String, double> _downloadProgress = {};
  final Map<String, bool> _isDownloading = {};

  final Map<String, MapCache<String, String>> _translationCache = {};
  final Map<String, Set<String>> _cachedKeys = {};

  MapCache<String, String> _getCacheForLanguage(String langCode) {
    if (!_translationCache.containsKey(langCode)) {
      _translationCache[langCode] = MapCache<String, String>.lru(
        maximumSize: 1000,
      );
      _cachedKeys[langCode] = {};
    }
    return _translationCache[langCode]!;
  }

  Future<String?> _getCachedValue(String langCode, String key) async {
    final cache = _translationCache[langCode];
    if (cache == null) return null;
    return await cache.get(key);
  }

  Future<void> _setCachedValue(
    String langCode,
    String key,
    String value,
  ) async {
    final cache = _getCacheForLanguage(langCode);
    await cache.set(key, value);
    _cachedKeys[langCode]!.add(key);
  }

  final Map<String, Completer<String>> _inFlightTranslations = {};
  final Set<String> _untranslatedTexts = {};

  int _cacheHits = 0;
  int _cacheMisses = 0;
  // ignore: unused_field
  int _duplicateRequestsPrevented = 0;

  double get cacheHitRate => (_cacheHits + _cacheMisses) > 0
      ? _cacheHits / (_cacheHits + _cacheMisses)
      : 0.0;

  Locale get currentLocale => _currentLocale;

  static const int _maxParallelTranslations = 5;
  // ignore: unused_field
  int _activeTranslations = 0;

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
    Locale('el'),
  ];

  static const Map<String, String> languageNames = {
    'en': 'English',
    'hi': 'हिंदी',
    'ta': 'தமிழ்',
    'te': 'తెలుగు',
    'tr': 'Türkçe',
    'ms': 'Bahasa Melayu',
    'el': 'Ελληνικά',
  };

  OnDeviceTranslator? _sourceToEnglishTranslator;
  OnDeviceTranslator? _englishToTargetTranslator;

  final OnDeviceTranslatorModelManager _modelManager =
      OnDeviceTranslatorModelManager();

  Timer? _saveTimer;

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
      final box = Hive.box(_hiveBoxName);

      for (final langCode in supportedLocales.map((l) => l.languageCode)) {
        final cached = box.get(langCode);
        if (cached != null && cached is Map) {
          final cache = _getCacheForLanguage(langCode);
          final keys = <String>{};

          for (final entry in (cached).entries) {
            if (entry.key is String && entry.value is String) {
              await cache.set(entry.key as String, entry.value as String);
              keys.add(entry.key as String);
            }
          }

          _cachedKeys[langCode] = keys;
        }
      }

      final totalPhrases = _cachedKeys.values.fold(
        0,
        (sum, set) => sum + set.length,
      );
      debugPrint(
        '✅ Loaded from Hive: ${_translationCache.keys.length} languages, $totalPhrases phrases',
      );
    } catch (e) {
      debugPrint('⚠️ Failed to load cache from Hive: $e');
      _translationCache.clear();
      _cachedKeys.clear();
    }
  }

  Future<void> _saveCacheToDisk() async {
    try {
      final box = Hive.box(_hiveBoxName);

      for (final entry in _translationCache.entries) {
        final langCode = entry.key;
        final cache = entry.value;
        final keys = _cachedKeys[langCode] ?? {};

        final cacheMap = <String, String>{};
        for (final key in keys) {
          final value = await cache.get(key);
          if (value != null) {
            cacheMap[key] = value;
          }
        }

        await box.put(langCode, cacheMap);
      }

      final totalPhrases = _cachedKeys.values.fold(
        0,
        (sum, set) => sum + set.length,
      );
      debugPrint('💾 Saved to Hive: $totalPhrases phrases');
    } catch (e) {
      debugPrint('⚠️ Failed to save to Hive: $e');
    }
  }

  void _scheduleSave({Duration debounce = const Duration(seconds: 2)}) {
    _saveTimer?.cancel();
    _saveTimer = Timer(debounce, () {
      unawaited(_saveCacheToDisk());
    });
  }

  Future<void> preloadTranslations({bool fullLoad = false}) async {
    if (_currentLocale.languageCode == 'en') {
      debugPrint('✓ English - no preload needed');
      return;
    }

    final langCode = _currentLocale.languageCode;
    final phrasesToLoad = fullLoad ? commonPhrases : criticalPhrases;

    final keys = _cachedKeys[langCode] ?? {};
    if (keys.length >= phrasesToLoad.length * 0.8) {
      debugPrint('✅ Already preloaded from cache');
      return;
    }

    debugPrint('⚡ Fast preloading ${phrasesToLoad.length} phrases...');

    _getCacheForLanguage(langCode);

    int loaded = 0;
    int fromCache = 0;
    int newTranslations = 0;

    for (int i = 0; i < phrasesToLoad.length; i += _maxParallelTranslations) {
      final batch = phrasesToLoad
          .skip(i)
          .take(_maxParallelTranslations)
          .toList();

      final futures = batch.map((phrase) async {
        final cached = await _getCachedValue(langCode, phrase);
        if (cached != null) {
          fromCache++;
          return;
        }

        try {
          final translated = await _translateText(phrase);
          await _setCachedValue(langCode, phrase, translated);
          newTranslations++;
        } catch (e) {
          debugPrint('⚠️ Failed: $phrase -> $e');
        }
      }).toList();

      await Future.wait(futures);
      loaded = fromCache + newTranslations;

      if (loaded % 10 == 0) {
        _scheduleSave();
      }
    }

    debugPrint(
      '✅ Preloaded $loaded/${phrasesToLoad.length} '
      '($fromCache cached, $newTranslations new)',
    );

    _scheduleSave();
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

  // Add to language_service.dart

  // ✅ NEW: Translate with validation - only cache if successful
  Future<String> translateWithValidation(String text) async {
    if (_isDisposed || _hasError || text.trim().isEmpty) return text;

    if (_currentLocale.languageCode == 'en') {
      return text;
    }

    final langCode = _currentLocale.languageCode;

    // Check cache first
    final cached = await _getCachedValue(langCode, text);
    if (cached != null && _isValidCachedTranslation(cached, text)) {
      _cacheHits++;
      debugPrint('✅ Cache hit: $text → $cached');
      return cached;
    }

    // Check if already translating
    if (_inFlightTranslations.containsKey(text)) {
      _duplicateRequestsPrevented++;
      try {
        return await _inFlightTranslations[text]!.future;
      } catch (e) {
        return text;
      }
    }

    _cacheMisses++;
    _untranslatedTexts.add(text);

    final completer = Completer<String>();
    _inFlightTranslations[text] = completer;

    _activeTranslations++;

    try {
      // ✅ CRITICAL: Translate with validation
      final translated = await _translateTextWithValidation(text);

      // ✅ Only cache if translation is valid
      if (_isValidTranslation(translated, text)) {
        await _setCachedValue(langCode, text, translated);
        debugPrint('✅ Translation cached: $text → $translated');

        _untranslatedTexts.remove(text);

        if (!completer.isCompleted) {
          completer.complete(translated);
        }

        // Schedule save
        if ((_cachedKeys[langCode]?.length ?? 0) % 10 == 0) {
          _scheduleSave();
        }

        return translated;
      } else {
        debugPrint('⚠️ Translation invalid, not caching: $text → $translated');

        if (!completer.isCompleted) {
          completer.complete(text); // Return original text
        }

        return text;
      }
    } catch (e) {
      debugPrint('❌ Translation failed: $text - $e');

      if (!completer.isCompleted) {
        completer.complete(text);
      }

      return text;
    } finally {
      _activeTranslations--;
      _inFlightTranslations.remove(text);
    }
  }

  // ✅ NEW: Validate cached translation
  bool _isValidCachedTranslation(String cached, String original) {
    if (cached.isEmpty) return false;
    if (cached == original && original.length > 5) return false;
    if (cached.contains('ERROR') || cached.contains('null')) return false;
    return true;
  }

  // ✅ NEW: Validate translation result
  bool _isValidTranslation(String translation, String original) {
    // Empty translation is invalid
    if (translation.isEmpty) return false;

    // Same as original might indicate failed translation (except short words)
    if (translation == original && original.length > 5) {
      debugPrint('⚠️ Translation same as original: $original');
      return false;
    }

    // Check for error patterns
    if (translation.contains('ERROR') ||
        translation.contains('FAILED') ||
        translation.contains('null') ||
        translation.toLowerCase().contains('error')) {
      debugPrint('⚠️ Translation contains error pattern: $translation');
      return false;
    }

    // Translation should have reasonable length
    if (translation.length < original.length * 0.3 && original.length > 10) {
      debugPrint(
        '⚠️ Translation too short: $original (${original.length}) → $translation (${translation.length})',
      );
      return false;
    }

    return true;
  }

  // ✅ IMPROVED: Translate with validation and retry
  Future<String> _translateTextWithValidation(String text) async {
    const maxAttempts = 3;
    int attempt = 0;

    while (attempt < maxAttempts) {
      attempt++;

      try {
        if (_englishToTargetTranslator == null) {
          await _prepareTranslators();
          // Wait for translator to be ready
          await Future.delayed(const Duration(milliseconds: 500));
        }

        if (_isDisposed || _englishToTargetTranslator == null) {
          debugPrint('⚠️ Translator not available (attempt $attempt)');
          if (attempt < maxAttempts) {
            await Future.delayed(Duration(milliseconds: 500 * attempt));
            continue;
          }
          return text;
        }

        // Direct en -> target
        if (_sourceToEnglishTranslator == null) {
          final translated = await _englishToTargetTranslator!
              .translateText(text)
              .timeout(
                Duration(
                  seconds: 15 + (attempt * 5),
                ), // Longer timeout on retries
                onTimeout: () {
                  debugPrint(
                    '⏱️ Translation timeout (attempt $attempt): $text',
                  );
                  return text;
                },
              );

          // Validate before returning
          if (_isValidTranslation(translated, text)) {
            return translated;
          }

          debugPrint(
            '⚠️ Invalid translation (attempt $attempt): $text → $translated',
          );
          if (attempt < maxAttempts) {
            await Future.delayed(Duration(milliseconds: 500 * attempt));
            continue;
          }
          return text;
        }

        // source -> en -> target
        if (_sourceToEnglishTranslator != null &&
            _englishToTargetTranslator != null) {
          final englishText = await _sourceToEnglishTranslator!
              .translateText(text)
              .timeout(
                Duration(seconds: 15 + (attempt * 5)),
                onTimeout: () => text,
              );

          final translated = await _englishToTargetTranslator!
              .translateText(englishText)
              .timeout(
                Duration(seconds: 15 + (attempt * 5)),
                onTimeout: () => englishText,
              );

          if (_isValidTranslation(translated, text)) {
            return translated;
          }

          debugPrint('⚠️ Invalid two-step translation (attempt $attempt)');
          if (attempt < maxAttempts) {
            await Future.delayed(Duration(milliseconds: 500 * attempt));
            continue;
          }
          return text;
        }

        return text;
      } catch (e) {
        debugPrint('❌ Translation error (attempt $attempt): $e');

        if (attempt < maxAttempts) {
          await Future.delayed(Duration(milliseconds: 500 * attempt));
          continue;
        }

        return text;
      }
    }

    debugPrint('❌ Translation failed after $maxAttempts attempts: $text');
    return text;
  }

  // ✅ UPDATE: Use validation in preloadTexts
  Future<void> preloadTexts(
    List<String> texts, {
    bool highPriority = false,
  }) async {
    if (_currentLocale.languageCode == 'en' || texts.isEmpty) return;

    final langCode = _currentLocale.languageCode;
    _getCacheForLanguage(langCode);

    final uncachedTexts = <String>[];
    for (final text in texts) {
      final cached = await _getCachedValue(langCode, text);
      if (cached == null || !_isValidCachedTranslation(cached, text)) {
        uncachedTexts.add(text);
      }
    }

    if (uncachedTexts.isEmpty) {
      debugPrint(
        '✅ All ${texts.length} texts already cached with valid translations',
      );
      return;
    }

    debugPrint('⚡ Preloading ${uncachedTexts.length}/${texts.length} texts...');

    int successCount = 0;
    int failCount = 0;

    for (int i = 0; i < uncachedTexts.length; i += _maxParallelTranslations) {
      final batch = uncachedTexts
          .skip(i)
          .take(_maxParallelTranslations)
          .toList();

      final futures = batch.map((text) async {
        try {
          // Use validation method
          final result = await translateWithValidation(text);

          if (_isValidTranslation(result, text)) {
            successCount++;
            if (successCount % 5 == 0) {
              debugPrint(
                '  ⏳ Progress: $successCount/${uncachedTexts.length} ✓ | $failCount ✗',
              );
            }
          } else {
            failCount++;
          }
        } catch (e) {
          failCount++;
          debugPrint(
            '  ❌ Failed: ${text.substring(0, text.length < 30 ? text.length : 30)}...',
          );
        }
      }).toList();

      await Future.wait(futures);

      if (highPriority || successCount % 10 == 0) {
        _scheduleSave();
      }
    }

    _scheduleSave();
    debugPrint('✅ Preload complete: $successCount success, $failCount failed');
    notifyListeners();
  }

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

      await preloadTranslations(fullLoad: false);
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

      // If previous was english: create english->target
      if (_previousLocale.languageCode == 'en') {
        debugPrint('Creating: en -> ${_currentLocale.languageCode}');

        if (!_isDisposed) {
          try {
            _englishToTargetTranslator = OnDeviceTranslator(
              sourceLanguage: TranslateLanguage.english,
              targetLanguage: currentLang,
            );
          } catch (e) {
            debugPrint('Error creating english->target translator: $e');
            _englishToTargetTranslator = null;
          }
        }
        return;
      }

      debugPrint(
        'Creating: ${_previousLocale.languageCode} -> en -> ${_currentLocale.languageCode}',
      );

      if (!_isDisposed) {
        try {
          _sourceToEnglishTranslator = OnDeviceTranslator(
            sourceLanguage: previousLang,
            targetLanguage: TranslateLanguage.english,
          );

          _englishToTargetTranslator = OnDeviceTranslator(
            sourceLanguage: TranslateLanguage.english,
            targetLanguage: currentLang,
          );
        } catch (e) {
          debugPrint('Error creating translators: $e');
          _sourceToEnglishTranslator = null;
          _englishToTargetTranslator = null;
        }
      }
    } catch (e) {
      debugPrint('Error preparing translators: $e');
      // Do not rethrow - handle gracefully
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
      case 'el':
        return TranslateLanguage.greek;
      default:
        return TranslateLanguage.english;
    }
  }

  Future<String> translate(String text) async {
    if (_isDisposed || _hasError || text.trim().isEmpty) return text;

    if (_currentLocale.languageCode == 'en') {
      return text;
    }

    final langCode = _currentLocale.languageCode;

    final cached = await _getCachedValue(langCode, text);
    if (cached != null) {
      _cacheHits++;
      return cached;
    }

    if (_inFlightTranslations.containsKey(text)) {
      _duplicateRequestsPrevented++;
      try {
        return await _inFlightTranslations[text]!.future;
      } catch (e) {
        return text;
      }
    }

    _cacheMisses++;
    _untranslatedTexts.add(text);

    final completer = Completer<String>();
    _inFlightTranslations[text] = completer;

    _activeTranslations++;

    try {
      final translated = await _translateText(text);

      await _setCachedValue(langCode, text, translated);

      _untranslatedTexts.remove(text);

      if (!completer.isCompleted) {
        completer.complete(translated);
      }

      // schedule save debounced
      if ((_cachedKeys[langCode]?.length ?? 0) % 10 == 0) {
        _scheduleSave();
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

    // If target translator only (no source->en)
    if (_sourceToEnglishTranslator == null &&
        _englishToTargetTranslator != null) {
      try {
        return await _englishToTargetTranslator!
            .translateText(text)
            .timeout(const Duration(seconds: 15), onTimeout: () => text);
      } catch (e) {
        debugPrint('_translateText direct english->target failed: $e');
        return text;
      }
    }

    // If need to go previous->en->target
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
        debugPrint('_translateText via english failed: $e');
        return text;
      }
    }

    return text;
  }

  Future<void> clearCache([String? languageCode]) async {
    if (languageCode != null) {
      _translationCache.remove(languageCode);
      _cachedKeys.remove(languageCode);
      debugPrint('🗑️ Cleared: $languageCode');
    } else {
      _translationCache.clear();
      _cachedKeys.clear();
      _cacheHits = 0;
      _cacheMisses = 0;
      _duplicateRequestsPrevented = 0;
      debugPrint('🗑️ Cleared all cache');
    }

    _scheduleSave();
    notifyListeners();
  }

  Map<String, int> getCacheStats() {
    final stats = <String, int>{};
    _cachedKeys.forEach((lang, keys) {
      stats[lang] = keys.length;
    });
    return stats;
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

  bool isSupported(Locale locale) =>
      supportedLocales.any((l) => l.languageCode == locale.languageCode);

  @override
  void dispose() {
    _isDisposed = true;

    Future.delayed(const Duration(milliseconds: 200), () {
      try {
        _sourceToEnglishTranslator?.close();
        _englishToTargetTranslator?.close();
      } catch (e) {}
    });

    _saveTimer?.cancel();
    super.dispose();
  }

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

}
