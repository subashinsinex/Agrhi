import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';

/// Bounded, redacted local diagnostics. No network reporting or user data.
abstract final class ErrorReporter {
  static final Map<String, DateTime> _recent = {};

  static void report(
    Object error,
    StackTrace stack, {
    required String operation,
  }) {
    try {
      final key = '$operation:${error.runtimeType}';
      final now = DateTime.now();
      final last = _recent[key];
      if (last != null && now.difference(last) < const Duration(seconds: 30)) {
        return;
      }
      if (_recent.length >= 64) _recent.remove(_recent.keys.first);
      _recent[key] = now;
      developer.log(
        key,
        name: 'agrhi.errors',
        level: 1000,
        error: kDebugMode ? error : null,
        stackTrace: kDebugMode ? stack : null,
      );
    } catch (_) {
      // Reporting must never generate another application failure.
    }
  }

  /// For optional work only. User actions must handle failure at their UI.
  static Future<void> background(
    String operation,
    Future<void> Function() action,
  ) async {
    try {
      await action();
    } catch (error, stack) {
      report(error, stack, operation: operation);
    }
  }
}
