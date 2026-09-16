import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:agrhi/services/notification_service.dart';
import 'package:agrhi/data/database/database_helper.dart';
import 'package:agrhi/core/utils/system_ui.dart';
import 'package:agrhi/core/errors/error_reporter.dart';
import 'app.dart';
import 'app_recovery.dart';
import 'startup_gate.dart';

Future<void> bootstrap() async {
  // Keep binding initialization and runApp in the same zone.
  WidgetsFlutterBinding.ensureInitialized();
  final recovery = AppRecoveryController();
  installErrorHandlers(recovery);
  if (kReleaseMode) {
    // Existing diagnostic prints can include API payloads and file paths.
    debugPrint = (String? message, {int? wrapWidth}) {};
  }
  runApp(
    AppRecovery(
      controller: recovery,
      builder: (_) => StartupGate(
        initialize: _initialize,
        builder: (payload) => MyApp(initialNotificationPayload: payload),
      ),
    ),
  );
}

Future<String?>? _optionalInitialization;

Future<String?> _initialize() async {
  // Offline data is essential. Never enter the app with a failed database,
  // and never delete user data to make a retry succeed.
  await DatabaseHelper.instance.database.timeout(const Duration(seconds: 20));
  // Timeouts do not cancel work. Reuse optional setup on a recovery attempt.
  return _optionalInitialization ??= _initializeOptional();
}

Future<String?> _initializeOptional() async {
  String? payload;
  await Future.wait([
    _optional('system_ui', () async {
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      SystemChrome.setSystemUIOverlayStyle(AppSystemUi.overlayStyle);
    }),
    _optional('translation_cache', () async {
      if (!Hive.isBoxOpen('translation_cache')) {
        await Hive.initFlutter();
        await Hive.openBox('translation_cache');
      }
    }),
    _optional('notifications', () async {
      await NotificationService.initialize();
      final launch = await NotificationService.plugin
          .getNotificationAppLaunchDetails();
      if (launch?.didNotificationLaunchApp ?? false) {
        payload = launch?.notificationResponse?.payload;
      }
    }),
  ]);
  return payload;
}

Future<void> _optional(String name, Future<void> Function() action) =>
    ErrorReporter.background(
      name,
      () => action().timeout(const Duration(seconds: 10)),
    );
