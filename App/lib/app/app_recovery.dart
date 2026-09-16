import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:agrhi/core/errors/app_failure.dart';
import 'package:agrhi/core/errors/error_reporter.dart';
import 'package:agrhi/views/shared/app_error_screen.dart';

class AppRecoveryController extends ValueNotifier<bool> {
  AppRecoveryController() : super(false);
  Timer? _pending;

  void showScreenFailure() {
    if (value || _pending != null) return;
    // Never mutate the tree while Flutter is building the failing widget.
    _pending = Timer(Duration.zero, () {
      _pending = null;
      value = true;
    });
  }

  void retry() {
    _pending?.cancel();
    _pending = null;
    value = false;
  }

  @override
  void dispose() {
    _pending?.cancel();
    super.dispose();
  }
}

void installErrorHandlers(AppRecoveryController recovery) {
  FlutterError.onError = (details) {
    ErrorReporter.report(
      details.exception,
      details.stack ?? StackTrace.current,
      operation: 'flutter',
    );
    if (!details.silent && details.library == 'rendering library') {
      recovery.showScreenFailure();
    }
    assert(() {
      FlutterError.presentError(details);
      return true;
    }());
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    // Last resort for unowned async failures. Do not interrupt unrelated UI.
    ErrorReporter.report(error, stack, operation: 'unhandled_async');
    return true;
  };
  ErrorWidget.builder = (details) {
    recovery.showScreenFailure();
    // A minimal RenderBox is safe even inside a broken widget tree.
    return ErrorWidget.withDetails(message: '');
  };
}

class AppRecovery extends StatelessWidget {
  const AppRecovery({
    super.key,
    required this.controller,
    required this.builder,
  });
  final AppRecoveryController controller;
  final WidgetBuilder builder;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<bool>(
    valueListenable: controller,
    builder: (context, failed, _) => failed
        ? MaterialApp(
            debugShowCheckedModeBanner: false,
            home: AppErrorScreen(
              failure: AppFailure.screen,
              actionLabel: 'Reopen app',
              onRetry: controller.retry,
            ),
          )
        : Builder(builder: builder),
  );
}
