// lib/src/services/connectivity_manager.dart

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'connectivity_service.dart';
import 'sync_service.dart';
import 'crop_care_sync_service.dart';
import 'auth_service.dart';
import 'notification_service.dart';
import '../../utils/routes.dart';

/// Manages connectivity status and triggers async sync (non-blocking UI)
class ConnectivityManager extends ChangeNotifier {
  static final ConnectivityManager instance = ConnectivityManager._();

  ConnectivityManager._() {
    _initialize();
  }

  bool _isOnline = false;
  bool get isOnline => _isOnline;

  DateTime? _lastSyncTime;

  bool _isSyncing = false;
  bool get isSyncing => _isSyncing;

  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  final ConnectivityService _connectivityService = ConnectivityService();
  Timer? _periodicSyncTimer;
  static const Duration _syncInterval = Duration(minutes: 30);

  StreamSubscription<bool>? _connectivitySubscription;

  void _initialize() {
    _connectivityService.hasInternetConnection().then((online) {
      _updateStatus(online, isInitial: true);
    });

    _connectivitySubscription = _connectivityService.onConnectivityChanged
        .listen(
          (online) {
            _updateStatus(online);
          },
          onError: (error) {
            debugPrint('❌ Connectivity stream error: $error');
            _updateStatus(false);
          },
        );

    _loadLastSyncTime();
    _startPeriodicSync();
  }

  Future<void> _loadLastSyncTime() async {
    try {
      final lastSyncStr = await _storage.read(key: 'last_sync_time');
      if (lastSyncStr != null) {
        _lastSyncTime = DateTime.parse(lastSyncStr);
        notifyListeners();
      }
    } catch (e) {
      debugPrint('⚠️ Error loading last sync time: $e');
    }
  }

  void _updateStatus(bool online, {bool isInitial = false}) {
    if (_isOnline != online) {
      _isOnline = online;

      _connectivityService.clearCache();

      debugPrint('🌐 Connectivity changed: ${online ? "ONLINE" : "OFFLINE"}');
      notifyListeners();

      if (online && !isInitial) {
        _triggerAutoSync();
      }
    }
  }

  void _startPeriodicSync() {
    _periodicSyncTimer = Timer.periodic(_syncInterval, (timer) {
      if (!_isOnline) {
        debugPrint('⏰ Periodic sync skipped - offline');
        return;
      }

      if (_lastSyncTime != null) {
        final timeSinceSync = DateTime.now().difference(_lastSyncTime!);
        if (timeSinceSync.inMinutes < 25) {
          debugPrint(
            '⏰ Periodic sync skipped - last synced ${timeSinceSync.inMinutes} min ago',
          );
          return;
        }
      }

      debugPrint(
        '⏰ Periodic auto-sync triggered (${_syncInterval.inMinutes} min interval)',
      );
      _triggerAutoSync();
    });

    debugPrint(
      '⏰ Periodic sync timer started (${_syncInterval.inMinutes} min interval)',
    );
  }

  Future<void> _triggerAutoSync() async {
    if (_isSyncing) {
      debugPrint('⚠️ Sync already in progress, skipping');
      return;
    }

    if (_lastSyncTime != null) {
      final timeSinceSync = DateTime.now().difference(_lastSyncTime!);
      if (timeSinceSync.inMinutes < 5) {
        debugPrint(
          'Skipping auto-sync - last synced ${timeSinceSync.inMinutes} min ago',
        );
        return;
      }
    }

    _isSyncing = true;
    notifyListeners();

    try {
      debugPrint('🔄 Auto-sync started (async, non-blocking)...');

      final authService = AuthService();
      final authStatus = await authService.checkAuthStatus();

      if (authStatus == AuthStatus.unauthenticated) {
        debugPrint('⚠️ Not authenticated - skipping sync');
        return;
      }

      if (authStatus == AuthStatus.authenticatedOffline) {
        debugPrint('⚠️ Offline mode detected during sync - skipping');
        return;
      }

      final token = await _storage.read(key: 'access_token');

      if (token == null || token.isEmpty) {
        debugPrint('⚠️ No access token after auth check - skipping sync');
        return;
      }

      debugPrint('✅ Token validated, starting sync...');

      final results =
          await Future.wait([
            SyncService.instance.performFullSync(token),
            CropCareSyncService.instance.performFullSync(token),
          ], eagerError: false).timeout(
            const Duration(seconds: 90),
            onTimeout: () {
              debugPrint('⚠️ Auto-sync timed out after 90 seconds');
              return [
                {'success': false, 'error': 'Sync timeout', 'timeout': true},
                {'success': false, 'error': 'Sync timeout', 'timeout': true},
              ];
            },
          );

      final diseaseSuccess = results[0]['success'] as bool? ?? false;
      final cropCareSuccess = results[1]['success'] as bool? ?? false;
      final cropCarePartialSuccess =
          results[1]['partialSuccess'] as bool? ?? false;
      final diseaseTimeout = results[0]['timeout'] as bool? ?? false;
      final cropCareTimeout = results[1]['timeout'] as bool? ?? false;

      if (diseaseTimeout || cropCareTimeout) {
        debugPrint('⚠️ Auto-sync timed out - will retry later');
      } else if (diseaseSuccess && cropCareSuccess) {
        debugPrint('✅ Auto-sync completed successfully');
        _lastSyncTime = DateTime.now();
        await _storage.write(
          key: 'last_sync_time',
          value: _lastSyncTime!.toIso8601String(),
        );
        notifyListeners();
      } else if (cropCarePartialSuccess || diseaseSuccess) {
        debugPrint('⚠️ Auto-sync completed with partial success');
        _lastSyncTime = DateTime.now();
        await _storage.write(
          key: 'last_sync_time',
          value: _lastSyncTime!.toIso8601String(),
        );
        notifyListeners();
      } else {
        debugPrint('⚠️ Auto-sync completed with errors');
      }
    } catch (e) {
      debugPrint('❌ Auto-sync failed: $e');
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  /// Manual sync trigger (for user-initiated sync)
  Future<Map<String, dynamic>> performManualSync() async {
    if (!_isOnline) {
      await NotificationService.showNotification(
        id: _generateNotificationId(),
        title: 'Sync Failed',
        body: 'No internet connection. Please try again later.',
        payload: Routes.dashboard,
      );

      return {'success': false, 'error': 'No internet connection'};
    }

    if (_isSyncing) {
      return {'success': false, 'error': 'Sync already in progress'};
    }

    _isSyncing = true;
    notifyListeners();

    try {
      debugPrint('🔄 Manual sync started...');

      final authService = AuthService();
      final authStatus = await authService.checkAuthStatus();

      if (authStatus == AuthStatus.unauthenticated) {
        await NotificationService.showNotification(
          id: _generateNotificationId(),
          title: 'Sync Failed',
          body: 'You are not logged in. Please sign in again.',
          payload: Routes.dashboard,
        );

        return {'success': false, 'error': 'Not authenticated'};
      }

      if (authStatus == AuthStatus.authenticatedOffline) {
        await NotificationService.showNotification(
          id: _generateNotificationId(),
          title: 'Sync Failed',
          body: 'No internet connection. Please try again later.',
          payload: Routes.dashboard,
        );

        return {'success': false, 'error': 'No internet connection'};
      }

      final token = await _storage.read(key: 'access_token');

      if (token == null || token.isEmpty) {
        await NotificationService.showNotification(
          id: _generateNotificationId(),
          title: 'Sync Failed',
          body: 'Session expired. Please log in again.',
          payload: Routes.dashboard,
        );

        return {'success': false, 'error': 'No access token'};
      }

      debugPrint('✅ Token validated, starting manual sync...');

      final results =
          await Future.wait([
            SyncService.instance.performFullSync(token),
            CropCareSyncService.instance.performFullSync(token),
          ], eagerError: false).timeout(
            const Duration(seconds: 120),
            onTimeout: () {
              return [
                {'success': false, 'error': 'Sync timeout'},
                {'success': false, 'error': 'Sync timeout'},
              ];
            },
          );

      final diseaseSync = results[0];
      final cropCareSync = results[1];

      final diseaseSuccess = diseaseSync['success'] as bool? ?? false;
      final cropCareSuccess = cropCareSync['success'] as bool? ?? false;
      final cropCarePartialSuccess =
          cropCareSync['partialSuccess'] as bool? ?? false;
      final allSuccess = diseaseSuccess && cropCareSuccess;

      if (allSuccess) {
        _lastSyncTime = DateTime.now();
        await _storage.write(
          key: 'last_sync_time',
          value: _lastSyncTime!.toIso8601String(),
        );
        notifyListeners();

        await NotificationService.showNotification(
          id: _generateNotificationId(),
          title: 'Sync Successful',
          body: 'Your AGRHI data was synced successfully.',
          payload: Routes.dashboard,
        );
      } else if (cropCarePartialSuccess || diseaseSuccess) {
        _lastSyncTime = DateTime.now();
        await _storage.write(
          key: 'last_sync_time',
          value: _lastSyncTime!.toIso8601String(),
        );
        notifyListeners();

        await NotificationService.showNotification(
          id: _generateNotificationId(),
          title: 'Sync Partially Successful',
          body: 'Some of your AGRHI data was synced. Tap to check details.',
          payload: Routes.dashboard,
        );
      } else {
        String failureMessage = 'Some data could not be synced. Tap to check.';

        if (!diseaseSuccess && !cropCareSuccess) {
          failureMessage = 'Sync failed for all modules. Tap to retry.';
        } else if (!diseaseSuccess) {
          failureMessage = 'Disease data sync failed. Tap to check.';
        } else if (!cropCareSuccess) {
          failureMessage = 'Crop care data sync failed. Tap to check.';
        }

        await NotificationService.showNotification(
          id: _generateNotificationId(),
          title: 'Sync Failed',
          body: failureMessage,
          payload: Routes.dashboard,
        );
      }

      return {
        'success': allSuccess,
        'disease_success': diseaseSuccess,
        'crop_care_success': cropCareSuccess,
        'disease_sync': diseaseSync,
        'crop_care_sync': cropCareSync,
        'timestamp': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      await NotificationService.showNotification(
        id: _generateNotificationId(),
        title: 'Sync Failed',
        body: 'An unexpected error occurred during sync. Tap to retry.',
        payload: Routes.dashboard,
      );

      return {'success': false, 'error': e.toString()};
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  String get syncStatusMessage {
    if (_isSyncing) {
      return 'Syncing...';
    }

    if (!_isOnline) {
      return 'Offline';
    }

    if (_lastSyncTime == null) {
      return 'Never synced';
    }

    final timeSince = DateTime.now().difference(_lastSyncTime!);

    if (timeSince.inMinutes < 1) {
      return 'Just synced';
    } else if (timeSince.inMinutes < 60) {
      return 'Synced ${timeSince.inMinutes}m ago';
    } else if (timeSince.inHours < 24) {
      return 'Synced ${timeSince.inHours}h ago';
    } else {
      return 'Synced ${timeSince.inDays}d ago';
    }
  }

  void updateLastSyncTime(DateTime time) async {
    _lastSyncTime = time;
    await _storage.write(
      key: 'last_sync_time',
      value: _lastSyncTime!.toIso8601String(),
    );
    notifyListeners();
  }

  int _generateNotificationId() {
    return (DateTime.now().millisecondsSinceEpoch % 2147483647).toInt();
  }

  @override
  void dispose() {
    debugPrint('🗑️ Disposing ConnectivityManager...');
    _periodicSyncTimer?.cancel();
    _connectivitySubscription?.cancel();
    super.dispose();
  }
}
