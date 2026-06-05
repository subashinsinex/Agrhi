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
    if (harvestDate != null) {
      harvestReminderDate = harvestDate.subtract(const Duration(days: 3));
    }

    final List<int> scheduledNotificationIds = [];
    final now = DateTime.now();

    try {
      await NotificationService.cancelNotification(baseId + 2);

      if (harvestReminderDate != null && harvestReminderDate.isAfter(now)) {
        try {
          await NotificationService.scheduleReminder(
            id: baseId + 2,
            title: 'Harvest Reminder',
            body: '$plantName may be ready for harvest soon.',
            scheduledDate: harvestReminderDate,
            payload: Routes.dashboard,
          );
          scheduledNotificationIds.add(baseId + 2);
        } catch (e, stackTrace) {
          debugPrint(
            '❌ Failed to schedule harvest reminder for crop $cropId: $e',
          );
          debugPrintStack(stackTrace: stackTrace);
        }
      } else if (harvestReminderDate != null) {
        debugPrint(
          'AGRHI_HARVEST_SKIPPED cropId=$cropId harvestReminderDate=$harvestReminderDate now=$now',
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

        final harvestReminderDate = DateTime.tryParse(
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
          await NotificationService.cancelNotification(baseId + 2);

          if (harvestReminderDate != null &&
              harvestReminderDate.isAfter(DateTime.now())) {
            await NotificationService.scheduleReminder(
              id: baseId + 2,
              title: 'Harvest Reminder',
              body: '$plantName may be ready for harvest soon.',
              scheduledDate: harvestReminderDate,
              payload: Routes.dashboard,
            );
            rescheduledIds.add(baseId + 2);
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

  Future<void> sendWeeklyCheckIn() async {
    final db = DatabaseHelper.instance;

    try {
      final upcomingReminders = await db.getUpcomingReminders(daysAhead: 7);
      final totalCount = await db.getActiveCropRemindersCount();

      if (upcomingReminders.isEmpty) {
        if (totalCount > 0) {
          await NotificationService.showNotification(
            id: 999,
            title: '✓ Crop Reminders Active',
            body:
                'All crop reminders on track. You have $totalCount active reminder${totalCount > 1 ? 's' : ''}.',
            payload: Routes.dashboard,
          );
        }
      } else if (upcomingReminders.length == 1) {
        final reminder = upcomingReminders.first;
        final plantName = reminder['plantname'] as String? ?? 'Crop';
        final reminderType =
            reminder['remindertype'] as String? ??
            reminder['reminder_type'] as String?;
        final daysUntil = _getDaysUntilReminder(reminder);

        final body = _buildReminderBody(
          plantName,
          reminderType,
          daysUntil,
          reminder,
        );

        await NotificationService.showNotification(
          id: 999,
          title: '🌾 Upcoming Crop Reminder',
          body: body,
          payload: Routes.dashboard,
        );
      } else {
        final firstReminder = upcomingReminders[0];
        final secondReminder = upcomingReminders[1];

        final plantName1 = firstReminder['plantname'] as String? ?? 'Crop';
        final reminderType1 =
            firstReminder['remindertype'] as String? ??
            firstReminder['reminder_type'] as String?;
        final daysUntil1 = _getDaysUntilReminder(firstReminder);

        final plantName2 = secondReminder['plantname'] as String? ?? 'Crop';
        final reminderType2 =
            secondReminder['remindertype'] as String? ??
            secondReminder['reminder_type'] as String?;
        final daysUntil2 = _getDaysUntilReminder(secondReminder);

        final body1 = _buildReminderBody(
          plantName1,
          reminderType1,
          daysUntil1,
          firstReminder,
        );
        final body2 = _buildReminderBody(
          plantName2,
          reminderType2,
          daysUntil2,
          secondReminder,
        );

        await NotificationService.showNotification(
          id: 999,
          title: '🌾 Multiple Crop Reminders',
          body: '$body1\n$body2',
          payload: Routes.dashboard,
        );
      }

      debugPrint('✅ Weekly check-in notification sent');
    } catch (e, stackTrace) {
      debugPrint('❌ Error sending weekly check-in: $e');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  int _getDaysUntilReminder(Map<String, dynamic> reminder) {
    final dynamic daysHarvestRaw =
        reminder['daysuntilharvest'] ?? reminder['days_until_harvest'];

    if (daysHarvestRaw is int && daysHarvestRaw >= 0) {
      return daysHarvestRaw;
    }
    if (daysHarvestRaw is num && daysHarvestRaw >= 0) {
      return daysHarvestRaw.toInt();
    }
    return 0;
  }

  String _buildReminderBody(
    String plantName,
    String? reminderType,
    int daysUntil,
    Map<String, dynamic> reminder,
  ) {
    final type = 'Harvest reminder';
    final dateStr = _formatDateFromReminder(reminder, reminderType);

    if (daysUntil == 0) {
      return '$plantName: $type due TODAY ($dateStr)';
    } else if (daysUntil == 1) {
      return '$plantName: $type due TOMORROW ($dateStr)';
    } else {
      return '$plantName: $type due in $daysUntil days ($dateStr)';
    }
  }

  String _formatDateFromReminder(
    Map<String, dynamic> reminder,
    String? reminderType,
  ) {
    try {
      final harvestDate = DateTime.tryParse(
        reminder['harvestreminderdate'] as String? ??
            reminder['harvest_reminder_date'] as String? ??
            '',
      );
      if (harvestDate != null) {
        return '${harvestDate.month}/${harvestDate.day}';
      }
    } catch (e) {
      debugPrint('Error formatting date: $e');
    }
    return 'soon';
  }
}
