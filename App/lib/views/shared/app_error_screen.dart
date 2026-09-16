import 'package:flutter/material.dart';
import 'package:agrhi/core/errors/app_failure.dart';

/// Deliberately independent of providers, translation, storage and networking.
class AppErrorScreen extends StatelessWidget {
  const AppErrorScreen({
    super.key,
    required this.failure,
    required this.onRetry,
    this.actionLabel = 'Try again',
  });
  final AppFailure failure;
  final VoidCallback onRetry;
  final String actionLabel;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xFFF3F8F4),
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.refresh_rounded,
                  size: 56,
                  color: Color(0xFF236A43),
                ),
                const SizedBox(height: 20),
                Text(
                  failure.title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                Text(failure.message, textAlign: TextAlign.center),
                const SizedBox(height: 24),
                FilledButton(onPressed: onRetry, child: Text(actionLabel)),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
