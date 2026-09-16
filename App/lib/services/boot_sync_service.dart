import 'package:agrhi/models/auth_result.dart';
import 'package:flutter/foundation.dart';
import 'package:agrhi/services/auth_service.dart';
import 'package:agrhi/controllers/connectivity_controller.dart';
import 'package:agrhi/services/reminders_manager.dart';
import 'package:agrhi/services/notification_service.dart';
import 'package:agrhi/services/navigation_service.dart';
import 'package:agrhi/services/session_coordinator.dart';
import 'package:agrhi/core/utils/routes.dart';

class BootSyncService {
  static Future<void> run() async {
    if (SessionCoordinator.instance.isClosing) return;
    try {
      await SessionCoordinator.instance.run(() async {
        final status = await AuthService().checkAuthStatus();
        if (SessionCoordinator.instance.isClosing) return;
        if (status == AuthStatus.unauthenticated) {
          NavigationService.navigatorKey.currentState?.pushNamedAndRemoveUntil(
            Routes.login,
            (_) => false,
          );
          return;
        }
        if (status == AuthStatus.authenticated) {
          await ConnectivityController.instance.performManualSync(
            isBootSync: true,
          );
        }
        await RemindersManager.instance.rescheduleAllCropReminders();
        await NotificationService.ensureGeneralEngagementNotificationsScheduled();
      });
    } catch (error) {
      debugPrint('Background startup sync: $error');
    }
  }
}
