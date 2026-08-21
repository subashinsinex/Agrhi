import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../database/database_helper.dart';
import 'notification_service.dart';
import '../../utils/routes.dart';

class RemindersManager {
  static final RemindersManager instance = RemindersManager._();

  RemindersManager._();

  int _baseReminderId(String cropId) {
    return cropId.hashCode & 0x7fffffff;
  }

  Future<Map<String, dynamic>> scheduleCropReminders({
    required String cropId,
    required String plantName,
    required DateTime plantingDate,
    DateTime? harvestDate,
  }) async {
    final int baseId = _baseReminderId(cropId);
    final db = DatabaseHelper.instance;

    DateTime? harvestReminderDate;
    DateTime? harvestDayReminderDate;

    if (harvestDate != null) {
      harvestReminderDate = harvestDate.subtract(const Duration(days: 3));
      harvestDayReminderDate = harvestDate;
    }

    final List<int> scheduledNotificationIds = [];
    final now = DateTime.now();

    try {
      await NotificationService.cancelNotification(baseId + 1);
      await NotificationService.cancelNotification(baseId + 2);

      if (harvestReminderDate != null && harvestReminderDate.isAfter(now)) {
        try {
          await NotificationService.scheduleReminder(
            id: baseId + 1,
            title: 'Harvest Reminder',
            body: '$plantName may be ready for harvest in 3 days.',
            scheduledDate: harvestReminderDate,
            payload: Routes.dashboard,
          );
          scheduledNotificationIds.add(baseId + 1);
        } catch (e, stackTrace) {
          debugPrint(
            '❌ Failed to schedule pre-harvest reminder for crop $cropId: $e',
          );
          debugPrintStack(stackTrace: stackTrace);
        }
      } else if (harvestReminderDate != null) {
        debugPrint(
          'AGRHI_PREHARVEST_SKIPPED cropId=$cropId harvestReminderDate=$harvestReminderDate now=$now',
        );
      }

      if (harvestDayReminderDate != null &&
          harvestDayReminderDate.isAfter(now)) {
        try {
          await NotificationService.scheduleReminder(
            id: baseId + 2,
            title: 'Harvest Today',
            body: '$plantName is ready for harvest today.',
            scheduledDate: harvestDayReminderDate,
            payload: Routes.dashboard,
          );
          scheduledNotificationIds.add(baseId + 2);
        } catch (e, stackTrace) {
          debugPrint(
            '❌ Failed to schedule harvest-day reminder for crop $cropId: $e',
          );
          debugPrintStack(stackTrace: stackTrace);
        }
      } else if (harvestDayReminderDate != null) {
        debugPrint(
          'AGRHI_HARVESTDAY_SKIPPED cropId=$cropId harvestDayReminderDate=$harvestDayReminderDate now=$now',
        );
      }

      if (scheduledNotificationIds.isEmpty) {
        await db.deleteCropReminder(cropId);
        debugPrint(
          'AGRHI_REMINDER_NOT_SAVED cropId=$cropId no future reminders available',
        );
      } else {
        await db.upsertCropReminder(
          cropId: cropId,
          plantName: plantName,
          harvestReminderDate: harvestReminderDate,
          notificationIds: jsonEncode(scheduledNotificationIds),
        );

        debugPrint(
          '✅ Reminder metadata saved for crop $cropId with notificationIds=${jsonEncode(scheduledNotificationIds)}',
        );
      }

      return {
        'harvestReminderDate': harvestReminderDate,
        'harvestDayReminderDate': harvestDayReminderDate,
        'scheduledNotificationIds': scheduledNotificationIds,
      };
    } catch (e, stackTrace) {
      debugPrint('❌ Error scheduling reminders for crop $cropId: $e');
      debugPrintStack(stackTrace: stackTrace);
      rethrow;
    }
  }

  Future<void> cancelCropReminders(String cropId) async {
    final db = DatabaseHelper.instance;

    try {
      final reminder = await db.getCropReminder(cropId);

      if (reminder != null) {
        final notificationIdsRaw =
            reminder['notificationids']?.toString() ??
            reminder['notification_ids']?.toString();

        if (notificationIdsRaw != null && notificationIdsRaw.isNotEmpty) {
          try {
            final decoded = jsonDecode(notificationIdsRaw);
            if (decoded is List) {
              for (final id in decoded) {
                if (id is int) {
                  await NotificationService.cancelNotification(id);
                } else if (id is num) {
                  await NotificationService.cancelNotification(id.toInt());
                }
              }
            }
          } catch (e) {
            debugPrint(
              '❌ Failed to decode notification ids for crop $cropId: $e',
            );
          }
        }
      } else {
        final int baseId = _baseReminderId(cropId);
        await NotificationService.cancelNotification(baseId + 1);
        await NotificationService.cancelNotification(baseId + 2);
      }

      await db.deleteCropReminder(cropId);
      debugPrint('✅ Reminders cancelled for crop $cropId');
    } catch (e, stackTrace) {
      debugPrint('❌ Error cancelling reminders for crop $cropId: $e');
      debugPrintStack(stackTrace: stackTrace);
      rethrow;
    }
  }

  Future<void> rescheduleAllCropReminders() async {
    final db = DatabaseHelper.instance;

    try {
      final reminders = await db.getAllActiveCropReminders();

      for (final reminder in reminders) {
        final cropId =
            reminder['cropid']?.toString() ?? reminder['crop_id']?.toString();
        final plantName =
            reminder['plantname'] as String? ??
            reminder['plant_name'] as String? ??
            'Crop';

        final DateTime? harvestReminderDate = DateTime.tryParse(
          reminder['harvestreminderdate'] as String? ??
              reminder['harvest_reminder_date'] as String? ??
              '',
        );

        if (cropId == null) {
          continue;
        }

        final int baseId = _baseReminderId(cropId);
        final List<int> rescheduledIds = [];

        try {
          await NotificationService.cancelNotification(baseId + 1);
          await NotificationService.cancelNotification(baseId + 2);

          if (harvestReminderDate != null) {
            final preHarvestDate = harvestReminderDate;
            final harvestDayReminderDate = preHarvestDate.add(
              const Duration(days: 3),
            );

            if (preHarvestDate.isAfter(DateTime.now())) {
              await NotificationService.scheduleReminder(
                id: baseId + 1,
                title: 'Harvest Reminder',
                body: '$plantName may be ready for harvest in 3 days.',
                scheduledDate: preHarvestDate,
                payload: Routes.dashboard,
              );
              rescheduledIds.add(baseId + 1);
            }

            if (harvestDayReminderDate.isAfter(DateTime.now())) {
              await NotificationService.scheduleReminder(
                id: baseId + 2,
                title: 'Harvest Today',
                body: '$plantName is ready for harvest today.',
                scheduledDate: harvestDayReminderDate,
                payload: Routes.dashboard,
              );
              rescheduledIds.add(baseId + 2);
            }
          }

          if (rescheduledIds.isEmpty) {
            await db.deleteCropReminder(cropId);
          } else {
            await db.upsertCropReminder(
              cropId: cropId,
              plantName: plantName,
              harvestReminderDate: harvestReminderDate,
              notificationIds: jsonEncode(rescheduledIds),
            );
          }
        } catch (e, stackTrace) {
          debugPrint('❌ Error rescheduling crop $cropId: $e');
          debugPrintStack(stackTrace: stackTrace);
        }
      }

      debugPrint('✅ All crop reminders rescheduled on startup');
    } catch (e, stackTrace) {
      debugPrint('❌ Error rescheduling reminders: $e');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  Future<void> clearAllNotificationsOnLogout() async {
    final db = DatabaseHelper.instance;

    try {
      final reminders = await db.getAllCropReminders();

      for (final reminder in reminders) {
        final cropId =
            reminder['cropid']?.toString() ?? reminder['crop_id']?.toString();

        if (cropId == null || cropId.isEmpty) {
          continue;
        }

        try {
          await cancelCropReminders(cropId);
        } catch (e, stackTrace) {
          debugPrint('❌ Failed to clear reminders for crop $cropId: $e');
          debugPrintStack(stackTrace: stackTrace);
        }
      }

      await NotificationService.cancelGeneralEngagementNotifications();
      await NotificationService.cancelAllNotifications();
      await NotificationService.debugPendingNotifications();

      debugPrint('✅ All crop notifications cleared on logout');
    } catch (e, stackTrace) {
      debugPrint('❌ Error clearing all notifications on logout: $e');
      debugPrintStack(stackTrace: stackTrace);
      rethrow;
    }
  }
}
