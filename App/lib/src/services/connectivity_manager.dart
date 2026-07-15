import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'connectivity_service.dart';
import 'sync_service.dart';
import 'crop_care_sync_service.dart';
import 'auth_service.dart';
import 'notification_service.dart';
import 'notification_reminder_sync_service.dart';
import '../../utils/routes.dart';

class ConnectivityManager extends ChangeNotifier {
  static final ConnectivityManager instance = ConnectivityManager._();

  ConnectivityManager._() {
    _initialize();
  }

  bool _isOnline = false;
  bool get isOnline => _isOnline;

  bool _isSyncing = false;
  bool get isSyncing => _isSyncing;

  DateTime? _lastSyncTime;

  bool _bootSyncInProgress = false;
  // ignore: unused_field
  bool _bootSyncCompleted = false;

  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  static const Duration _syncInterval = Duration(minutes: 30);
  static const Duration _minAutoSyncGap = Duration(minutes: 5);
  static const Duration _minPeriodicSyncGap = Duration(minutes: 25);
  static const Duration _autoSyncTimeout = Duration(seconds: 90);
  static const Duration _manualSyncTimeout = Duration(seconds: 120);

  static const String _keySyncTime = 'last_sync_time';
  static const String _keyAccessToken = 'access_token';

  final ConnectivityService _connectivityService = ConnectivityService();
  Timer? _periodicSyncTimer;
  StreamSubscription<bool>? _connectivitySubscription;

  void _initialize() {
    _connectivityService.hasInternetConnection().then(
      (online) => _updateStatus(online, isInitial: true),
    );

    _connectivitySubscription = _connectivityService.onConnectivityChanged
        .listen(
          _updateStatus,
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
      final lastSyncStr = await _storage.read(key: _keySyncTime);
      if (lastSyncStr != null) {
        _lastSyncTime = DateTime.parse(lastSyncStr);
        notifyListeners();
      }
    } catch (e) {
      debugPrint('⚠️ Error loading last sync time: $e');
    }
  }

  void _updateStatus(bool online, {bool isInitial = false}) {
    if (_isOnline == online) return;

    _isOnline = online;
    _connectivityService.clearCache();
    debugPrint('🌐 Connectivity changed: ${online ? "ONLINE" : "OFFLINE"}');
    notifyListeners();

    if (online && !isInitial) {
      _triggerAutoSync();
    }
  }

  void _startPeriodicSync() {
    _periodicSyncTimer = Timer.periodic(_syncInterval, (_) {
      if (!_isOnline) {
        debugPrint('⏰ Periodic sync skipped - offline');
        return;
      }

      if (_bootSyncInProgress) {
        debugPrint('⏰ Periodic sync skipped - boot sync in progress');
        return;
      }

      if (_lastSyncTime != null) {
        final gap = DateTime.now().difference(_lastSyncTime!);
        if (gap < _minPeriodicSyncGap) {
          debugPrint(
            '⏰ Periodic sync skipped - last synced ${gap.inMinutes}m ago',
          );
          return;
        }
      }

      debugPrint(
        '⏰ Periodic auto-sync triggered (${_syncInterval.inMinutes}m interval)',
      );
      _triggerAutoSync();
    });

    debugPrint(
      '⏰ Periodic sync timer started (${_syncInterval.inMinutes}m interval)',
    );
  }

  Future<String?> _getValidToken() async {
    final authService = AuthService();
    final authStatus = await authService.checkAuthStatus();

    if (authStatus == AuthStatus.unauthenticated) {
      debugPrint('⚠️ Not authenticated - skipping sync');
      return null;
    }

    if (authStatus == AuthStatus.authenticatedOffline) {
      debugPrint('⚠️ Offline auth - skipping sync');
      return null;
    }

    final token = await _storage.read(key: _keyAccessToken);

    if (token == null || token.isEmpty) {
      debugPrint('⚠️ No access token - skipping sync');
      return null;
    }

    return token;
  }

  Future<_SyncResult> _runSync(String token, Duration timeout, {bool includeReminderSync = false}) async {
    final results =
        await Future.wait([
          SyncService.instance.performFullSync(token),
          CropCareSyncService.instance.performFullSync(token),
        ], eagerError: false).timeout(
          timeout,
          onTimeout: () {
            debugPrint('⚠️ Sync timed out after ${timeout.inSeconds}s');
            return [
              {'success': false, 'error': 'Sync timeout', 'timeout': true},
              {'success': false, 'error': 'Sync timeout', 'timeout': true},
            ];
          },
        );

    final diseaseSync = results[0];
    final cropCareSync = results[1];

    final diseaseSuccess = diseaseSync['success'] as bool? ?? false;
    final cropCareSuccess = cropCareSync['success'] as bool? ?? false;
    final cropCarePartial = cropCareSync['partialSuccess'] as bool? ?? false;
    final diseaseTimeout = diseaseSync['timeout'] as bool? ?? false;
    final cropCareTimeout = cropCareSync['timeout'] as bool? ?? false;
    final timedOut = diseaseTimeout || cropCareTimeout;

    Map<String, dynamic> reminderSync = {'success': false};

    if (includeReminderSync && !cropCareTimeout) {
      debugPrint('🔔 Running reminder sync...');
      try {
        reminderSync = await NotificationReminderSyncService.instance
            .performPostCropSync();
      } catch (e) {
        debugPrint('❌ Reminder sync failed: $e');
        reminderSync = {'success': false, 'error': e.toString()};
      }
    } else if (includeReminderSync && cropCareTimeout) {
      debugPrint('Skipping reminder sync - crop care sync timed out');
    } else {
      debugPrint('⚠️ Skipping reminder sync - crop care sync timed out');
    }

    final reminderSuccess = reminderSync['success'] as bool? ?? false;

    return _SyncResult(
      diseaseSync: diseaseSync,
      cropCareSync: cropCareSync,
      reminderSync: reminderSync,
      diseaseSuccess: diseaseSuccess,
      cropCareSuccess: cropCareSuccess,
      cropCarePartial: cropCarePartial,
      reminderSuccess: reminderSuccess,
      timedOut: timedOut,
    );
  }

  Future<void> _saveLastSyncTime() async {
    _lastSyncTime = DateTime.now();
    await _storage.write(
      key: _keySyncTime,
      value: _lastSyncTime!.toIso8601String(),
    );
    notifyListeners();
  }

  Future<void> _triggerAutoSync() async {
    if (_bootSyncInProgress) {
      debugPrint('⚠️ Auto-sync skipped - boot sync in progress');
      return;
    }

    if (_isSyncing) {
      debugPrint('⚠️ Sync already in progress, skipping');
      return;
    }

    if (_lastSyncTime != null) {
      final gap = DateTime.now().difference(_lastSyncTime!);
      if (gap < _minAutoSyncGap) {
        debugPrint('Skipping auto-sync - last synced ${gap.inMinutes}m ago');
        return;
      }
    }

    _isSyncing = true;
    notifyListeners();

    try {
      debugPrint('🔄 Auto-sync started...');

      final token = await _getValidToken();
      if (token == null) return;

      debugPrint('✅ Token validated, starting auto-sync...');
      final r = await _runSync(token, _autoSyncTimeout, includeReminderSync: false);

      if (r.timedOut) {
        debugPrint('⚠️ Auto-sync timed out - will retry later');
      } else if (r.fullSuccess) {
        debugPrint('✅ Auto-sync completed successfully');
        await _saveLastSyncTime();
      } else if (r.partialSuccess) {
        debugPrint('⚠️ Auto-sync completed with partial success');
        await _saveLastSyncTime();
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

  Future<Map<String, dynamic>> performManualSync({
    bool isBootSync = false,
  }) async {
    if (!_isOnline) {
      if (!isBootSync) {
        await _showSyncNotification(
          title: 'Sync Failed',
          body: 'No internet connection. Please try again later.',
        );
      }
      return {'success': false, 'error': 'No internet connection'};
    }

    if (_isSyncing) {
      return {'success': false, 'error': 'Sync already in progress'};
    }

    if (isBootSync) {
      _bootSyncInProgress = true;
      notifyListeners();
    }

    _isSyncing = true;
    notifyListeners();

    try {
      debugPrint('🔄 ${isBootSync ? "Boot" : "Manual"} sync started...');

      final token = await _getValidToken();

      if (token == null) {
        if (!isBootSync) {
          await _showSyncNotification(
            title: 'Sync Failed',
            body: 'Session expired. Please log in again.',
          );
        }
        return {'success': false, 'error': 'Not authenticated'};
      }

      debugPrint('✅ Token validated, starting sync...');
      final r = await _runSync(token, _manualSyncTimeout, includeReminderSync: true);

      if (r.fullSuccess) {
        await _saveLastSyncTime();
        if (!isBootSync) {
          await _showSyncNotification(
            title: 'Sync Successful',
            body: 'Your AGRHI data was synced successfully.',
          );
        }
      } else if (r.partialSuccess) {
        await _saveLastSyncTime();
        if (!isBootSync) {
          await _showSyncNotification(
            title: 'Sync Partially Successful',
            body: 'Some of your AGRHI data was synced. Tap to check details.',
          );
        }
      } else {
        if (!isBootSync) {
          await _showSyncNotification(
            title: 'Sync Failed',
            body: _buildFailureMessage(r),
          );
        }
      }

      return {
        'success': r.fullSuccess,
        'partial_success': r.partialSuccess,
        'disease_success': r.diseaseSuccess,
        'crop_care_success': r.cropCareSuccess,
        'reminder_success': r.reminderSuccess,
        'timed_out': r.timedOut,
        'disease_sync': r.diseaseSync,
        'crop_care_sync': r.cropCareSync,
        'reminder_sync': r.reminderSync,
        'timestamp': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      if (!isBootSync) {
        await _showSyncNotification(
          title: 'Sync Failed',
          body: 'An unexpected error occurred during sync. Tap to retry.',
        );
      }
      return {'success': false, 'error': e.toString()};
    } finally {
      _isSyncing = false;

      if (isBootSync) {
        _bootSyncInProgress = false;
        _bootSyncCompleted = true;
      }

      notifyListeners();
    }
  }

  Future<void> _showSyncNotification({
    required String title,
    required String body,
  }) async {
    await NotificationService.showNotification(
      id: _generateNotificationId(),
      title: title,
      body: body,
      payload: Routes.dashboard,
    );
  }

  String _buildFailureMessage(_SyncResult r) {
    if (!r.diseaseSuccess && !r.cropCareSuccess && !r.reminderSuccess) {
      return 'Sync failed for all modules. Tap to retry.';
    }
    if (!r.diseaseSuccess) return 'Disease data sync failed. Tap to check.';
    if (!r.cropCareSuccess) return 'Crop care data sync failed. Tap to check.';
    if (!r.reminderSuccess) return 'Reminder sync failed. Tap to check.';
    return 'Some data could not be synced. Tap to check.';
  }

  String get syncStatusMessage {
    if (_isSyncing) return 'Syncing...';
    if (!_isOnline) return 'Offline';
    if (_lastSyncTime == null) return 'Never synced';

    final gap = DateTime.now().difference(_lastSyncTime!);
    if (gap.inMinutes < 1) return 'Just synced';
    if (gap.inMinutes < 60) return 'Synced ${gap.inMinutes}m ago';
    if (gap.inHours < 24) return 'Synced ${gap.inHours}h ago';
    return 'Synced ${gap.inDays}d ago';
  }

  void updateLastSyncTime(DateTime time) async {
    _lastSyncTime = time;
    await _storage.write(
      key: _keySyncTime,
      value: _lastSyncTime!.toIso8601String(),
    );
    notifyListeners();
  }

  int _generateNotificationId() =>
      (DateTime.now().millisecondsSinceEpoch % 2147483647).toInt();

  @override
  void dispose() {
    debugPrint('🗑️ Disposing ConnectivityManager...');
    _periodicSyncTimer?.cancel();
    _connectivitySubscription?.cancel();
    super.dispose();
  }
}

class _SyncResult {
  final Map<String, dynamic> diseaseSync;
  final Map<String, dynamic> cropCareSync;
  final Map<String, dynamic> reminderSync;

  final bool diseaseSuccess;
  final bool cropCareSuccess;
  final bool cropCarePartial;
  final bool reminderSuccess;
  final bool timedOut;

  const _SyncResult({
    required this.diseaseSync,
    required this.cropCareSync,
    required this.reminderSync,
    required this.diseaseSuccess,
    required this.cropCareSuccess,
    required this.cropCarePartial,
    required this.reminderSuccess,
    required this.timedOut,
  });

  bool get fullSuccess => diseaseSuccess && cropCareSuccess && !timedOut;

  bool get partialSuccess =>
      !timedOut &&
      (cropCarePartial || diseaseSuccess || cropCareSuccess);
}
