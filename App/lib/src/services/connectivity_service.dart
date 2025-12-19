// lib/src/services/connectivity_service.dart

import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:internet_connection_checker_plus/internet_connection_checker_plus.dart';
import 'package:flutter/foundation.dart';

class ConnectivityService {
  final Connectivity _connectivity = Connectivity();
  final InternetConnection _internetConnection = InternetConnection();

  // ✅ Cache the last check result to avoid excessive API calls
  bool? _lastKnownStatus;
  DateTime? _lastCheckTime;
  static const Duration _cacheValidDuration = Duration(seconds: 5);

  /// Check if device has internet connection
  /// ✅ Returns cached result if checked within last 5 seconds
  Future<bool> hasInternetConnection({bool forceCheck = false}) async {
    try {
      // ✅ Return cached result if still valid (unless force check)
      if (!forceCheck && _lastKnownStatus != null && _lastCheckTime != null) {
        final timeSinceCheck = DateTime.now().difference(_lastCheckTime!);
        if (timeSinceCheck < _cacheValidDuration) {
          debugPrint('📶 Using cached connectivity status: $_lastKnownStatus');
          return _lastKnownStatus!;
        }
      }

      // ✅ Step 1: Quick check - is any network available?
      final connectivityResult = await _connectivity.checkConnectivity();

      if (connectivityResult.contains(ConnectivityResult.none)) {
        debugPrint('📶 No network adapter available');
        _updateCache(false);
        return false;
      }

      // ✅ Step 2: Verify actual internet access (tries to reach known servers)
      final hasInternet = await _internetConnection.hasInternetAccess.timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          debugPrint('⚠️ Internet check timed out - assuming offline');
          return false;
        },
      );

      debugPrint('📶 Internet connectivity: $hasInternet');
      _updateCache(hasInternet);
      return hasInternet;
    } catch (e) {
      debugPrint('❌ Error checking connectivity: $e');
      // ✅ On error, return last known status or assume offline
      return _lastKnownStatus ?? false;
    }
  }

  /// Update cached connectivity status
  void _updateCache(bool status) {
    _lastKnownStatus = status;
    _lastCheckTime = DateTime.now();
  }

  /// Clear cached connectivity status (force next check)
  void clearCache() {
    _lastKnownStatus = null;
    _lastCheckTime = null;
    debugPrint('🗑️ Connectivity cache cleared');
  }

  /// Stream to listen to connectivity changes
  /// ✅ Real-time updates when network status changes
  Stream<bool> get onConnectivityChanged {
    return _internetConnection.onStatusChange
        .map((status) {
          final isConnected = status == InternetStatus.connected;
          debugPrint(
            '📶 Connectivity changed: ${isConnected ? "ONLINE" : "OFFLINE"}',
          );
          _updateCache(isConnected);
          return isConnected;
        })
        .handleError((error) {
          debugPrint('❌ Error in connectivity stream: $error');
          // ✅ On stream error, assume offline
          _updateCache(false);
          return false;
        });
  }

  /// Check specific connectivity type (WiFi, Mobile, etc.)
  Future<ConnectivityResult> getConnectivityType() async {
    try {
      final results = await _connectivity.checkConnectivity();

      // Return first non-none result
      if (results.contains(ConnectivityResult.wifi)) {
        return ConnectivityResult.wifi;
      } else if (results.contains(ConnectivityResult.mobile)) {
        return ConnectivityResult.mobile;
      } else if (results.contains(ConnectivityResult.ethernet)) {
        return ConnectivityResult.ethernet;
      } else {
        return ConnectivityResult.none;
      }
    } catch (e) {
      debugPrint('❌ Error getting connectivity type: $e');
      return ConnectivityResult.none;
    }
  }

  /// Get human-readable connectivity status
  Future<String> getConnectivityStatus() async {
    final type = await getConnectivityType();
    final hasInternet = await hasInternetConnection();

    switch (type) {
      case ConnectivityResult.wifi:
        return hasInternet ? 'WiFi (Online)' : 'WiFi (No Internet)';
      case ConnectivityResult.mobile:
        return hasInternet
            ? 'Mobile Data (Online)'
            : 'Mobile Data (No Internet)';
      case ConnectivityResult.ethernet:
        return hasInternet ? 'Ethernet (Online)' : 'Ethernet (No Internet)';
      case ConnectivityResult.none:
        return 'Offline';
      default:
        return 'Unknown';
    }
  }

  /// Wait for internet connection to become available
  /// Useful for retry logic
  Future<void> waitForConnection({
    Duration timeout = const Duration(seconds: 30),
    Duration checkInterval = const Duration(seconds: 2),
  }) async {
    final startTime = DateTime.now();

    while (DateTime.now().difference(startTime) < timeout) {
      if (await hasInternetConnection(forceCheck: true)) {
        debugPrint('✅ Internet connection restored');
        return;
      }

      await Future.delayed(checkInterval);
    }

    throw TimeoutException('Failed to establish connection within $timeout');
  }
}
