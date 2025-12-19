import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'connectivity_service.dart';
import 'sync_service.dart';
import 'crop_care_sync_service.dart';
import 'auth_service.dart'; 

class ConnectivityManager extends ChangeNotifier {
  static final ConnectivityManager instance = ConnectivityManager._();
  ConnectivityManager._() {
    _initialize();
  }

  bool _isOnline = false;
  bool get isOnline => _isOnline;

  DateTime? _lastSyncTime;
  DateTime? get lastSyncTime => _lastSyncTime;

  bool _isSyncing = false;
  bool get isSyncing => _isSyncing;

  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  final ConnectivityService _connectivityService = ConnectivityService();
  Timer? _periodicSyncTimer; // ✅ ADD THIS
  static const Duration _syncInterval = Duration(minutes: 30); // ✅ ADD THIS

  void _initialize() {
    // Check initial connectivity
    _connectivityService.hasInternetConnection().then((online) {
      _updateStatus(online, isInitial: true);
    });

    // Listen for real-time changes
    _connectivityService.onConnectivityChanged.listen((online) {
      _updateStatus(online);
    });

    // Load last sync time from storage
    _loadLastSyncTime();

    // ✅ Start periodic sync timer
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
      debugPrint('🌐 Connectivity changed: ${online ? "ONLINE" : "OFFLINE"}');
      notifyListeners();

      if (online && !isInitial) {
        // ✅ Auto-sync when coming back online
        _triggerAutoSync();
      }
    }
  }

  // ✅ NEW: Periodic sync timer
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

    // Check if we synced recently (avoid excessive syncs)
    if (_lastSyncTime != null) {
      final timeSinceSync = DateTime.now().difference(_lastSyncTime!);
      if (timeSinceSync.inMinutes < 5) {
        debugPrint(
          '⏭️ Skipping auto-sync - last synced ${timeSinceSync.inMinutes} min ago',
        );
        return;
      }
    }

    _isSyncing = true;
    notifyListeners();

    try {
      debugPrint('🔄 Auto-sync started (async, non-blocking)...');

      // ✅ STEP 1: Check authentication and refresh token if needed
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

      // ✅ STEP 2: Get fresh token (may have been refreshed by checkAuthStatus)
      final token = await _storage.read(key: 'access_token');

      if (token == null || token.isEmpty) {
        debugPrint('⚠️ No access token after auth check - skipping sync');
        return;
      }

      debugPrint('✅ Token validated, starting sync...');

      // ✅ STEP 3: Run sync with timeout
      final results =
          await Future.wait([
            SyncService.instance.performFullSync(token),
            CropCareSyncService.instance.performFullSync(token),
          ]).timeout(
            const Duration(seconds: 90), // 90s timeout for slow networks
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
      return {'success': false, 'error': 'No internet connection'};
    }

    if (_isSyncing) {
      return {'success': false, 'error': 'Sync already in progress'};
    }

    _isSyncing = true;
    notifyListeners();

    try {
      debugPrint('🔄 Manual sync started...');

      // ✅ Check auth and refresh token if needed
      final authService = AuthService();
      final authStatus = await authService.checkAuthStatus();

      if (authStatus == AuthStatus.unauthenticated) {
        return {'success': false, 'error': 'Not authenticated'};
      }

      if (authStatus == AuthStatus.authenticatedOffline) {
        return {'success': false, 'error': 'No internet connection'};
      }

      final token = await _storage.read(key: 'access_token');

      if (token == null || token.isEmpty) {
        return {'success': false, 'error': 'No access token'};
      }

      debugPrint('✅ Token validated, starting manual sync...');

      // ✅ Run sync with timeout
      final results =
          await Future.wait([
            SyncService.instance.performFullSync(token),
            CropCareSyncService.instance.performFullSync(token),
          ]).timeout(
            const Duration(seconds: 120), // 2 minutes for manual sync
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

      if (diseaseSuccess && cropCareSuccess) {
        _lastSyncTime = DateTime.now();
        await _storage.write(
          key: 'last_sync_time',
          value: _lastSyncTime!.toIso8601String(),
        );
        notifyListeners();
      }

      return {
        'success': diseaseSuccess && cropCareSuccess,
        'disease_success': diseaseSuccess,
        'crop_care_success': cropCareSuccess,
        'disease_sync': diseaseSync,
        'crop_care_sync': cropCareSync,
        'timestamp': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  /// Force sync regardless of timing
  Future<Map<String, dynamic>> forceSync() async {
    _lastSyncTime = null; // Reset to force sync
    return await performManualSync();
  }

  /// Refresh connectivity status manually
  Future<void> refreshConnectivity() async {
    final online = await _connectivityService.hasInternetConnection();
    _updateStatus(online);
  }

  // ✅ NEW: Cleanup timer on dispose
  @override
  void dispose() {
    _periodicSyncTimer?.cancel();
    super.dispose();
  }
}
