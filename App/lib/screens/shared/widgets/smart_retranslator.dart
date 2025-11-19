// lib/screens/shared/widgets/smart_retranslator.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../src/services/language_service.dart';

/// Optimized translation widget with strict validation
class SmartReTranslator extends StatefulWidget {
  final String text;
  final TextStyle? style;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;

  const SmartReTranslator({
    super.key,
    required this.text,
    this.style,
    this.textAlign,
    this.maxLines,
    this.overflow,
  });

  @override
  State<SmartReTranslator> createState() => _SmartReTranslatorState();
}

class _SmartReTranslatorState extends State<SmartReTranslator> {
  String _displayedText = '';
  String _lastLanguage = '';
  String _lastSourceText = '';
  bool _isLoading = false;
  int _retryCount = 0;
  static const int _maxRetries = 3;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final languageService = Provider.of<LanguageService>(context, listen: true);
    final currentLanguage = languageService.currentLocale.languageCode;

    // Only reload if language or source text changed
    if (_lastLanguage != currentLanguage || _lastSourceText != widget.text) {
      _lastLanguage = currentLanguage;
      _lastSourceText = widget.text;
      _retryCount = 0; // Reset retry count on language change
      _loadTranslation();
    }
  }

  @override
  void didUpdateWidget(covariant SmartReTranslator oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.text != widget.text && _lastSourceText != widget.text) {
      _lastSourceText = widget.text;
      _retryCount = 0;
      _loadTranslation();
    }
  }

  Future<void> _loadTranslation() async {
    if (!mounted || _isLoading) return;

    _isLoading = true;

    try {
      final languageService = Provider.of<LanguageService>(
        context,
        listen: false,
      );

      // Fast path for English - always show immediately
      if (languageService.currentLocale.languageCode == 'en') {
        if (mounted && _displayedText != widget.text) {
          setState(() => _displayedText = widget.text);
        }
        _isLoading = false;
        return;
      }

      // ✅ CRITICAL: Validate translation with retry logic
      final translation = await _translateWithValidation(
        languageService,
        widget.text,
      );

      if (mounted) {
        // Only update if translation is valid and different
        if (_isValidTranslation(translation, widget.text)) {
          if (_displayedText != translation) {
            setState(() => _displayedText = translation);
          }
        } else {
          // Keep showing original text if translation fails
          if (_displayedText != widget.text) {
            setState(() => _displayedText = widget.text);
          }
        }
      }
    } catch (e) {
      debugPrint('⚠️ Translation error for "${widget.text}": $e');

      // Fallback to original text
      if (mounted && _displayedText != widget.text) {
        setState(() => _displayedText = widget.text);
      }
    } finally {
      _isLoading = false;
    }
  }

  // ✅ NEW: Validate and retry translation
  Future<String> _translateWithValidation(
    LanguageService languageService,
    String text,
  ) async {
    while (_retryCount < _maxRetries) {
      try {
        final translation = await languageService
            .translateWithValidation(text)
            .timeout(const Duration(seconds: 20), onTimeout: () => text);

        // Check if translation is valid
        if (_isValidTranslation(translation, text)) {
          debugPrint('✅ Valid translation: $text → $translation');
          return translation;
        }

        _retryCount++;
        debugPrint(
          '⚠️ Invalid translation (attempt $_retryCount): $text → $translation',
        );

        if (_retryCount < _maxRetries) {
          // Exponential backoff
          await Future.delayed(Duration(milliseconds: 300 * _retryCount));
        }
      } catch (e) {
        _retryCount++;
        debugPrint('❌ Translation attempt $_retryCount failed: $e');

        if (_retryCount < _maxRetries) {
          await Future.delayed(Duration(milliseconds: 300 * _retryCount));
        }
      }
    }

    debugPrint('❌ Translation failed after $_maxRetries attempts: $text');
    return text; // Return original text if all retries fail
  }

  // ✅ NEW: Validate translation quality
  bool _isValidTranslation(String translation, String original) {
    // Empty translation is invalid
    if (translation.isEmpty) return false;

    // Same as original might indicate failed translation
    // (but could be valid for some short words)
    if (translation == original && original.length > 5) return false;

    // Check for common error patterns
    if (translation.contains('ERROR') ||
        translation.contains('FAILED') ||
        translation.contains('null')) {
      return false;
    }

    // Translation should have reasonable length
    // (not too short compared to original, allowing for character set differences)
    if (translation.length < original.length * 0.3 && original.length > 10) {
      return false;
    }

    return true;
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      _displayedText.isEmpty ? widget.text : _displayedText,
      style: widget.style,
      textAlign: widget.textAlign,
      maxLines: widget.maxLines,
      overflow: widget.overflow,
    );
  }
}
