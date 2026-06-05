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
        'AGRHI_REMINDER_SKIPPED past_or_now date=$scheduledDate id=$id now=$now',
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

    debugPrint(
      'AGRHI_REMINDER_ATTEMPT id=$id exactAllowed=$exactAlarmsAllowed scheduledDate=$scheduledDate zonedDate=$zonedDate now=$now',
    );

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
      'AGRHI_REMINDER_SCHEDULED id=$id title=$title at=$scheduledDate mode=${(exactAlarmsAllowed ?? false) ? "exactAllowWhileIdle" : "inexactAllowWhileIdle"}',
    );
  }

  static Future<void> cancelNotification(int id) async {
    await _ensureInitialized();
    await _plugin.cancel(id);
    debugPrint('AGRHI_NOTIFICATION_CANCELLED id=$id');
  }

  static Future<void> cancelAllNotifications() async {
    await _ensureInitialized();
    await _plugin.cancelAll();
    debugPrint('AGRHI_ALL_NOTIFICATIONS_CANCELLED');
  }

  static Future<void> scheduleWeeklyCheckIn({
    int weekday = 1,
    int hour = 9,
    int minute = 0,
  }) async {
    await _ensureInitialized();

    DateTime nextOccurrence = _calculateNextWeeklyDate(weekday, hour, minute);

    if (nextOccurrence.isBefore(DateTime.now())) {
      nextOccurrence = nextOccurrence.add(const Duration(days: 7));
    }

    final androidPlugin = plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    final bool? exactAlarmsAllowed = await androidPlugin
        ?.canScheduleExactNotifications();

    await _plugin.zonedSchedule(
      999,
      'Crop Reminders Check-in',
      'You have active crop reminders. Tap to view.',
      tz.TZDateTime.from(nextOccurrence, tz.local),
      _notificationDetails(),
      androidScheduleMode: (exactAlarmsAllowed ?? false)
          ? AndroidScheduleMode.exactAllowWhileIdle
          : AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
      payload: Routes.dashboard,
    );

    debugPrint(
      'AGRHI_WEEKLY_CHECKIN_SCHEDULED next=$nextOccurrence exactAllowed=$exactAlarmsAllowed',
    );
  }

  static Future<void> cancelWeeklyCheckIn() async {
    await _ensureInitialized();
    await _plugin.cancel(999);
    debugPrint('AGRHI_WEEKLY_CHECKIN_CANCELLED');
  }

  static Future<void> debugPendingNotifications() async {
    await _ensureInitialized();
    try {
      final pending = await _plugin.pendingNotificationRequests();
      debugPrint('AGRHI_PENDING_NOTIFICATIONS count=${pending.length}');
      for (final notification in pending) {
        debugPrint(
          'AGRHI_PENDING id=${notification.id} title=${notification.title} payload=${notification.payload}',
        );
      }
    } catch (e) {
      debugPrint('AGRHI_PENDING_NOTIFICATIONS_ERROR error=$e');
    }
  }

  static DateTime _calculateNextWeeklyDate(int weekday, int hour, int minute) {
    final now = DateTime.now();
    final scheduled = DateTime(now.year, now.month, now.day, hour, minute);

    if (now.weekday == weekday && scheduled.isAfter(now)) {
      return scheduled;
    }

    int daysUntil = (weekday - now.weekday) % 7;
    if (daysUntil == 0 && !scheduled.isAfter(now)) {
      daysUntil = 7;
    }

    return scheduled.add(Duration(days: daysUntil));
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
