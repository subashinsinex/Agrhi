import 'package:flutter/foundation.dart';
import 'auth_service.dart';
import 'connectivity_manager.dart';
import 'reminders_manager.dart';
import 'notification_service.dart';
import 'navigation_service.dart';
import 'session_coordinator.dart';
import '../../utils/routes.dart';

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
          await ConnectivityManager.instance.performManualSync(
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
