// lib/views/shared/smart_retranslator.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:agrhi/controllers/language_controller.dart';

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
  int _requestGeneration = 0;

  static const int _maxRetries = 3;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final languageService = Provider.of<LanguageController>(
      context,
      listen: true,
    );
    final currentLanguage = languageService.currentLocale.languageCode;

    // Only reload if language or source text changed
    if (_lastLanguage != currentLanguage || _lastSourceText != widget.text) {
      _lastLanguage = currentLanguage;
      _lastSourceText = widget.text;
      _loadTranslation();
    }
  }

  @override
  void didUpdateWidget(covariant SmartReTranslator oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.text != widget.text && _lastSourceText != widget.text) {
      _lastSourceText = widget.text;
      _loadTranslation();
    }
  }

  Future<void> _loadTranslation() async {
    if (!mounted) return;
    final generation = ++_requestGeneration;
    final service = context.read<LanguageController>();
    final source = widget.text;
    final locale = service.currentLocale.languageCode;
    setState(() => _displayedText = source);
    if (locale == 'en') return;
    try {
      final translated = await _translateWithValidation(
        service,
        source,
        generation,
      );
      if (!mounted ||
          generation != _requestGeneration ||
          service.currentLocale.languageCode != locale) {
        return;
      }
      setState(
        () => _displayedText = _isValidTranslation(translated, source)
            ? translated
            : source,
      );
    } catch (_) {
      // The current source remains visible on failure.
    }
  }

  Future<String> _translateWithValidation(
    LanguageController languageService,
    String text,
    int generation,
  ) async {
    int retryCount = 0;
    while (retryCount < _maxRetries &&
        mounted &&
        generation == _requestGeneration) {
      try {
        final translation = await languageService
            .translateWithValidation(text)
            .timeout(const Duration(seconds: 20), onTimeout: () => text);

        // Check if translation is valid
        if (_isValidTranslation(translation, text)) {
          debugPrint('✅ Valid translation: $text → $translation');
          return translation;
        }

        retryCount++;
        debugPrint(
          '⚠️ Invalid translation (attempt $retryCount): $text → $translation',
        );

        if (retryCount < _maxRetries) {
          // Exponential backoff
          await Future.delayed(Duration(milliseconds: 300 * retryCount));
        }
      } catch (e) {
        retryCount++;
        debugPrint('❌ Translation attempt $retryCount failed: $e');

        if (retryCount < _maxRetries) {
          await Future.delayed(Duration(milliseconds: 300 * retryCount));
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
