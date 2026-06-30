// notification_reminder_sync_service.dart

import 'package:flutter/foundation.dart';

import '../database/database_helper.dart';
import 'reminders_manager.dart';

class NotificationReminderSyncService {
  static final NotificationReminderSyncService instance =
      NotificationReminderSyncService._();

  NotificationReminderSyncService._();

  Future<Map<String, dynamic>> performPostCropSync() async {
    final db = DatabaseHelper.instance;

    int totalCrops = 0;
    int created = 0;
    int skipped = 0;
    int failed = 0;

    try {
      final crops = await db.getAllCrops();
      totalCrops = crops.length;

      for (final crop in crops) {
        try {
          final cropId =
              crop['usercropid']?.toString() ??
              crop['cropid']?.toString() ??
              crop['crop_id']?.toString();

          if (cropId == null || cropId.isEmpty) {
            failed++;
            continue;
          }

          // ✅ STEP 1: Check if reminder already exists
          final existingReminder = await db.getCropReminder(cropId);
          if (existingReminder != null) {
            skipped++;
            debugPrint('🔔 Reminder already exists for crop $cropId, skipping');
            continue;
          }

          // ✅ STEP 2: Check if the usercrop is active (isactive = 1, isdeleted = 0)
          final isActive = (crop['isactive'] == 1 || crop['isactive'] == true);
          final isDeleted =
              (crop['isdeleted'] == 1 || crop['isdeleted'] == true);

          if (!isActive || isDeleted) {
            skipped++;
            debugPrint(
              '⏭️ Skipping reminder for crop $cropId — inactive or deleted '
              '(isactive=${crop['isactive']}, isdeleted=${crop['isdeleted']})',
            );
            continue;
          }

          // ✅ STEP 3: Validate planting date
          final plantName =
              crop['plantname']?.toString() ??
              crop['plant_name']?.toString() ??
              'Crop';

          final plantingDateRaw =
              crop['plantingdate']?.toString() ??
              crop['planting_date']?.toString();

          final harvestDateRaw =
              crop['harvestdate']?.toString() ??
              crop['harvest_date']?.toString() ??
              crop['expectedharvestdate']?.toString() ??
              crop['expected_harvest_date']?.toString();

          if (plantingDateRaw == null || plantingDateRaw.isEmpty) {
            debugPrint(
              '⚠️ Skipping reminder creation for crop $cropId - planting date missing',
            );
            failed++;
            continue;
          }

          final plantingDate = DateTime.tryParse(plantingDateRaw);
          final harvestDate =
              harvestDateRaw != null && harvestDateRaw.isNotEmpty
              ? DateTime.tryParse(harvestDateRaw)
              : null;

          if (plantingDate == null) {
            debugPrint(
              '⚠️ Skipping reminder creation for crop $cropId - invalid planting date',
            );
            failed++;
            continue;
          }

          // ✅ STEP 4: Schedule reminders only for active crops without existing reminder
          final result = await RemindersManager.instance.scheduleCropReminders(
            cropId: cropId,
            plantName: plantName,
            plantingDate: plantingDate,
            harvestDate: harvestDate,
          );

          final scheduledIds =
              result['scheduledNotificationIds'] as List<dynamic>? ?? [];

          if (scheduledIds.isNotEmpty) {
            created++;
            debugPrint('✅ Created reminders for active crop $cropId');
          } else {
            skipped++;
            debugPrint('ℹ️ No future reminders needed for crop $cropId');
          }
        } catch (e, stackTrace) {
          failed++;
          debugPrint('❌ Failed reminder sync for crop: $e');
          debugPrintStack(stackTrace: stackTrace);
        }
      }

      return {
        'success': true,
        'total': totalCrops,
        'created': created,
        'skipped': skipped,
        'failed': failed,
      };
    } catch (e, stackTrace) {
      debugPrint('❌ Notification reminder sync failed: $e');
      debugPrintStack(stackTrace: stackTrace);

      return {
        'success': false,
        'error': e.toString(),
        'total': totalCrops,
        'created': created,
        'skipped': skipped,
        'failed': failed,
      };
    }
  }
}
