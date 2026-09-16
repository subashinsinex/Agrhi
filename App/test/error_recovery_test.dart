import 'dart:async';
import 'package:agrhi/app/app_recovery.dart';
import 'package:agrhi/app/startup_gate.dart';
import 'package:agrhi/core/errors/app_failure.dart';
import 'package:agrhi/core/errors/error_reporter.dart';
import 'package:agrhi/models/api_response.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'critical startup failure hides details and retries without entering app',
    (tester) async {
      var attempts = 0;
      var entered = 0;
      await tester.pumpWidget(
        StartupGate(
          initialize: () async {
            if (++attempts == 1) {
              throw StateError('private database path and user data');
            }
            return 'notification';
          },
          builder: (payload) {
            entered++;
            return MaterialApp(home: Text(payload!));
          },
        ),
      );
      await tester.pumpAndSettle();
      expect(entered, 0);
      expect(find.text('Unable to open AGRHI'), findsOneWidget);
      expect(find.textContaining('private database'), findsNothing);
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(attempts, 2);
      expect(entered, 1);
      expect(find.text('notification'), findsOneWidget);
    },
  );

  testWidgets('startup rebuilds do not repeat in-flight initialization', (
    tester,
  ) async {
    final pending = Completer<String?>();
    var calls = 0;
    Widget gate() => StartupGate(
      initialize: () {
        calls++;
        return pending.future;
      },
      builder: (_) => const MaterialApp(home: Text('ready')),
    );
    await tester.pumpWidget(gate());
    await tester.pumpWidget(gate());
    expect(calls, 1);
    pending.complete();
    await tester.pumpAndSettle();
    expect(find.text('ready'), findsOneWidget);
  });

  testWidgets('build failure recovers only after explicit user retry', (
    tester,
  ) async {
    final controller = AppRecoveryController();
    final original = ErrorWidget.builder;
    var shouldFail = true;
    ErrorWidget.builder = (_) {
      controller.showScreenFailure();
      return ErrorWidget.withDetails(message: '');
    };
    try {
      await tester.pumpWidget(
        AppRecovery(
          controller: controller,
          builder: (_) => MaterialApp(
            home: Builder(
              builder: (_) {
                if (shouldFail) throw StateError('private widget failure');
                return const Text('recovered');
              },
            ),
          ),
        ),
      );
      expect(tester.takeException(), isA<StateError>());
      await tester.pumpAndSettle();
      expect(find.text(AppFailure.screen.title), findsOneWidget);
      expect(find.textContaining('private widget'), findsNothing);
      shouldFail = false;
      await tester.tap(find.text('Reopen app'));
      await tester.pumpAndSettle();
      expect(find.text('recovered'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    } finally {
      ErrorWidget.builder = original;
      controller.dispose();
    }
  });

  test(
    'optional sync and async failures are consumed without a user error',
    () async {
      await ErrorReporter.background(
        'test_optional',
        () async => throw StateError('private'),
      );
      await ErrorReporter.background(
        'test_optional_sync',
        () => throw StateError('private'),
      );
    },
  );

  test('safe messages never include exception or server response bodies', () {
    const secret = '<html>secret-token and database-password</html>';
    for (final message in [
      AppFailure.from(StateError(secret)).message,
      ApiResponse.serverError(500, secret).error,
      ApiResponse.clientError(400, secret).error,
      ApiResponse.networkError(secret).error,
      ApiResponse.formatError(secret).error,
      ApiResponse.error(secret).error,
    ]) {
      expect(message, isNot(contains('secret')));
    }
    expect(
      AppFailure.from(TimeoutException(secret)).title,
      'Taking longer than expected',
    );
  });
}
