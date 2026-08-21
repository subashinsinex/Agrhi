import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../../utils/routes.dart';
import 'navigation_service.dart';

class NotificationService {
  static const String agrhiChannelId = 'agrhi_alerts';
  static const String agrhiChannelName = 'AGRHI Alerts';
  static const String agrhiChannelDescription =
      'Notifications for AGRHI reminders and alerts';

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static FlutterLocalNotificationsPlugin get plugin => _plugin;

  static bool _isInitialized = false;
  static final Random _random = Random();

  static const int _engagementNotificationStartId = 9000;
  static const int _engagementNotificationCount = 8;

  static const List<Map<String, String>> _engagementMessages = [
    {
      'title': 'Hey, come take a look 👀',
      'body': 'Something useful might be waiting for you in AGRHI.',
    },
    {
      'title': 'Got a minute? 🌱',
      'body': 'Open AGRHI and see what you can discover today.',
    },
    {
      'title': 'Don\'t miss out 👋',
      'body': 'There\'s always something worth checking in AGRHI.',
    },
    {
      'title': 'A quick visit? ⚡',
      'body': 'Your next useful find could be just one tap away.',
    },
    {
      'title': 'AGRHI misses you 😄',
      'body': 'Come back and see what\'s happening today.',
    },
    {
      'title': 'Take a quick break ☕',
      'body': 'Spend a minute exploring AGRHI.',
    },
    {
      'title': 'Something for you ✨',
      'body': 'Open AGRHI and explore what\'s available.',
    },
    {
      'title': 'Been a while? 👀',
      'body': 'Jump back into AGRHI and continue exploring.',
    },
    {
      'title': 'What\'s new today? 🚀',
      'body': 'Open AGRHI and take a quick look around.',
    },
    {
      'title': 'One tap away 📱',
      'body': 'AGRHI has plenty waiting to be explored.',
    },
  ];

  static Future<void> initialize() async {
    if (_isInitialized) {
      debugPrint('AGRHI_NOTIFICATION_INIT_SKIPPED already_initialized=true');
      return;
    }

    try {
      tz.initializeTimeZones();
      tz.setLocalLocation(tz.getLocation('Asia/Kolkata'));
    } catch (e) {
      debugPrint('AGRHI_TIMEZONE_INIT_FALLBACK error=$e');
      tz.initializeTimeZones();
    }

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );

    const initializationSettings = InitializationSettings(
      android: androidSettings,
    );

    await plugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        final payload = response.payload;

        debugPrint('AGRHI_NOTIFICATION_TAPPED payload=$payload');

        if (payload != null && payload.isNotEmpty) {
          handleNotificationTap(payload);
        }
      },
    );

    final androidPlugin = plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    final bool? notificationsGranted = await androidPlugin
        ?.requestNotificationsPermission();

    debugPrint('AGRHI_NOTIFICATION_PERMISSION granted=$notificationsGranted');

    final bool? exactAlarmGranted = await androidPlugin
        ?.requestExactAlarmsPermission();

    debugPrint('AGRHI_EXACT_ALARM_PERMISSION granted=$exactAlarmGranted');

    const channel = AndroidNotificationChannel(
      agrhiChannelId,
      agrhiChannelName,
      description: agrhiChannelDescription,
      importance: Importance.max,
    );

    await androidPlugin?.createNotificationChannel(channel);

    _isInitialized = true;

    debugPrint('AGRHI_NOTIFICATION_INIT_DONE initialized=$_isInitialized');
  }

  static Future<void> _ensureInitialized() async {
    if (!_isInitialized) {
      await initialize();
    }
  }

  static NotificationDetails _notificationDetails() {
    const androidDetails = AndroidNotificationDetails(
      agrhiChannelId,
      agrhiChannelName,
      channelDescription: agrhiChannelDescription,
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      visibility: NotificationVisibility.public,
    );

    return const NotificationDetails(android: androidDetails);
  }

  static Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    await _ensureInitialized();

    await _plugin.show(
      id,
      title,
      body,
      _notificationDetails(),
      payload: payload,
    );

    debugPrint('AGRHI_NOTIFICATION_SHOWN id=$id title=$title payload=$payload');
  }

  static Future<void> scheduleReminder({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
    String? payload,
  }) async {
    await _ensureInitialized();

    final now = DateTime.now();

    if (!scheduledDate.isAfter(now)) {
      debugPrint(
        'AGRHI_REMINDER_SKIPPED '
        'date=$scheduledDate '
        'id=$id '
        'now=$now',
      );
      return;
    }

    final androidPlugin = plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    final bool? exactAlarmsAllowed = await androidPlugin
        ?.canScheduleExactNotifications();

    final zonedDate = tz.TZDateTime.from(scheduledDate, tz.local);

    await _plugin.zonedSchedule(
      id,
      title,
      body,
      zonedDate,
      _notificationDetails(),
      androidScheduleMode: (exactAlarmsAllowed ?? false)
          ? AndroidScheduleMode.exactAllowWhileIdle
          : AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      payload: payload,
    );

    debugPrint(
      'AGRHI_REMINDER_SCHEDULED '
      'id=$id '
      'title=$title '
      'at=$scheduledDate',
    );
  }

  static Future<void> scheduleGeneralEngagementNotifications() async {
    await _ensureInitialized();

    await cancelGeneralEngagementNotifications();

    final now = tz.TZDateTime.now(tz.local);

    final possibleDays = List<int>.generate(29, (index) => index + 2)
      ..shuffle(_random);

    final selectedDays =
        possibleDays.take(_engagementNotificationCount).toList()..sort();

    final shuffledMessages = List<Map<String, String>>.from(_engagementMessages)
      ..shuffle(_random);

    const minuteOptions = [0, 15, 30, 45];

    for (int i = 0; i < selectedDays.length; i++) {
      final dayOffset = selectedDays[i];

      final hour = 10 + _random.nextInt(11);

      final minute = minuteOptions[_random.nextInt(minuteOptions.length)];

      final scheduledDate = tz.TZDateTime(
        tz.local,
        now.year,
        now.month,
        now.day + dayOffset,
        hour,
        minute,
      );

      final message = shuffledMessages[i % shuffledMessages.length];

      final notificationId = _engagementNotificationStartId + i;

      try {
        await _plugin.zonedSchedule(
          notificationId,
          message['title'],
          message['body'],
          scheduledDate,
          _notificationDetails(),
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          payload: Routes.dashboard,
        );

        debugPrint(
          'AGRHI_ENGAGEMENT_SCHEDULED '
          'id=$notificationId '
          'date=$scheduledDate '
          'title=${message['title']}',
        );
      } catch (e, stackTrace) {
        debugPrint(
          'AGRHI_ENGAGEMENT_SCHEDULE_FAILED '
          'id=$notificationId '
          'error=$e',
        );

        debugPrintStack(stackTrace: stackTrace);
      }
    }

    debugPrint(
      'AGRHI_ENGAGEMENT_SETUP_DONE '
      'count=${selectedDays.length}',
    );
  }

  static Future<void> ensureGeneralEngagementNotificationsScheduled() async {
    await _ensureInitialized();

    try {
      final pending = await _plugin.pendingNotificationRequests();

      final engagementPending = pending.where(
        (notification) =>
            notification.id >= _engagementNotificationStartId &&
            notification.id <
                _engagementNotificationStartId + _engagementNotificationCount,
      );

      final remaining = engagementPending.length;

      debugPrint('AGRHI_ENGAGEMENT_PENDING count=$remaining');

      if (remaining >= 3) {
        return;
      }

      await scheduleGeneralEngagementNotifications();
    } catch (e, stackTrace) {
      debugPrint('AGRHI_ENGAGEMENT_ENSURE_FAILED error=$e');

      debugPrintStack(stackTrace: stackTrace);
    }
  }

  static Future<void> cancelGeneralEngagementNotifications() async {
    await _ensureInitialized();

    for (int i = 0; i < _engagementNotificationCount; i++) {
      final id = _engagementNotificationStartId + i;

      try {
        await _plugin.cancel(id);
      } catch (e) {
        debugPrint(
          'AGRHI_ENGAGEMENT_CANCEL_FAILED '
          'id=$id '
          'error=$e',
        );
      }
    }

    debugPrint('AGRHI_ENGAGEMENT_NOTIFICATIONS_CANCELLED');
  }

  static Future<void> cancelNotification(int id) async {
    await _ensureInitialized();

    try {
      await _plugin.cancel(id);

      debugPrint('AGRHI_NOTIFICATION_CANCELLED id=$id');
    } catch (e, stackTrace) {
      debugPrint(
        'AGRHI_NOTIFICATION_CANCEL_FAILED '
        'id=$id '
        'error=$e',
      );

      debugPrintStack(stackTrace: stackTrace);

      rethrow;
    }
  }

  static Future<void> cancelAllNotifications() async {
    await _ensureInitialized();

    try {
      await _plugin.cancelAll();

      debugPrint('AGRHI_ALL_NOTIFICATIONS_CANCELLED');
    } catch (e, stackTrace) {
      debugPrint('AGRHI_ALL_NOTIFICATIONS_CANCEL_FAILED error=$e');

      debugPrintStack(stackTrace: stackTrace);

      rethrow;
    }
  }

  static Future<void> debugPendingNotifications() async {
    await _ensureInitialized();

    try {
      final pending = await _plugin.pendingNotificationRequests();

      debugPrint('AGRHI_PENDING_NOTIFICATIONS count=${pending.length}');

      for (final notification in pending) {
        debugPrint(
          'AGRHI_PENDING '
          'id=${notification.id} '
          'title=${notification.title} '
          'payload=${notification.payload}',
        );
      }
    } catch (e) {
      debugPrint('AGRHI_PENDING_NOTIFICATIONS_ERROR error=$e');
    }
  }

  static Future<void> showSyncSuccessNotification({
    required int analysesUploaded,
    required int imagesUploaded,
  }) async {
    await showNotification(
      id: _generateUniqueId(),
      title: 'Sync Completed',
      body: '$analysesUploaded analyses and $imagesUploaded images uploaded.',
      payload: Routes.dashboard,
    );
  }

  static int _generateUniqueId() {
    return _random.nextInt(2147483646) + 1;
  }

  static void handleNotificationTap(String payload) {
    debugPrint('AGRHI_HANDLE_NOTIFICATION payload=$payload');

    final navigator = NavigationService.navigator;

    if (navigator == null) {
      debugPrint('AGRHI_HANDLE_NOTIFICATION navigator=null');
      return;
    }

    switch (payload) {
      case Routes.modelManager:
        navigator.pushNamedAndRemoveUntil(Routes.dashboard, (route) => false);

        navigator.pushNamed(Routes.modelManager);
        break;

      case Routes.login:
        navigator.pushNamedAndRemoveUntil(Routes.login, (route) => false);
        break;

      case Routes.signup:
        navigator.pushNamedAndRemoveUntil(Routes.signup, (route) => false);
        break;

      case Routes.dashboard:
      default:
        navigator.pushNamedAndRemoveUntil(Routes.dashboard, (route) => false);
        break;
    }
  }
}
