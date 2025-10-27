import 'dart:async';
import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'auth_service.dart';
import 'connectivity_service.dart';

class TokenRefreshService {
  final AuthService _authService;
  final ConnectivityService _connectivityService;
  final _storage = const FlutterSecureStorage();

  Timer? _refreshTimer;
  StreamSubscription<bool>? _connectivitySubscription;

  bool _isOnline = true;
  int? _expirationCountdown;
  bool _isRefreshing = false;

  TokenRefreshService(this._authService, this._connectivityService);

  /// Initialize the service - call this after login or on app startup
  Future<void> initialize() async {
    print('🔄 Initializing TokenRefreshService...');

    // Check initial connectivity with actual internet access
    _isOnline = await _connectivityService.hasInternetConnection();
    print('📶 Initial connection status: ${_isOnline ? "Online" : "Offline"}');

    // Listen to connectivity changes
    _connectivitySubscription = _connectivityService.onConnectivityChanged
        .listen(_handleConnectivityChange);

    // Start the refresh timer
    await _startRefreshTimer();
  }

  /// Handle connectivity changes
  void _handleConnectivityChange(bool isConnected) {
    final wasOnline = _isOnline;
    _isOnline = isConnected;

    if (isConnected) {
      print('🌐 Connected to internet');
    } else {
      print('📴 Lost internet connection');
    }

    // If we just came back online, immediately check and refresh if needed
    if (!wasOnline && _isOnline) {
      print('🔄 Back online - checking token status');
      _checkAndRefreshToken();
    }
  }

  /// Start the periodic token refresh timer
  Future<void> _startRefreshTimer() async {
    // Cancel existing timer
    _refreshTimer?.cancel();

    // Initial token check
    await _checkAndRefreshToken();

    // Set up periodic check every second (like your React implementation)
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 1),
      (timer) => _checkAndRefreshToken(),
    );
  }

  /// Check token expiration and refresh if necessary
  Future<void> _checkAndRefreshToken() async {
    // Prevent concurrent refresh attempts
    if (_isRefreshing) return;

    try {
      final accessToken = await _storage.read(key: 'access_token');

      if (accessToken == null || accessToken.isEmpty) {
        _expirationCountdown = null;
        return;
      }

      // Decode token to get expiration
      if (!JwtDecoder.isExpired(accessToken)) {
        final decodedToken = JwtDecoder.decode(accessToken);
        final exp = decodedToken['exp'] as int;
        final expiration = DateTime.fromMillisecondsSinceEpoch(exp * 1000);
        final remainingSeconds = expiration
            .difference(DateTime.now())
            .inSeconds;

        _expirationCountdown = remainingSeconds;

        // Refresh if token expires in 30 seconds or less AND we're online
        if (remainingSeconds <= 30 && remainingSeconds > 0 && _isOnline) {
          print(
            '⏰ Token expiring in $remainingSeconds seconds - refreshing...',
          );
          await _performRefresh();
        }
      } else {
        // Token already expired
        print('⚠️ Token expired');
        if (_isOnline) {
          await _performRefresh();
        } else {
          print('📴 Token expired but offline - using cached data');
        }
      }
    } catch (e) {
      print('❌ Error checking token: $e');
    }
  }

  /// Perform the actual token refresh
  Future<void> _performRefresh() async {
    if (!_isOnline) {
      print('📴 Offline - skipping token refresh');
      return;
    }

    if (_isRefreshing) {
      print('⏳ Refresh already in progress - skipping');
      return;
    }

    _isRefreshing = true;

    try {
      // Double-check internet connection before attempting refresh
      final hasInternet = await _connectivityService.hasInternetConnection();

      if (!hasInternet) {
        print('📴 No internet access - skipping token refresh');
        _isOnline = false;
        return;
      }

      await _authService.refreshAccessToken();
      print('✅ Token refreshed successfully');

      // Reset expiration countdown after successful refresh
      final newAccessToken = await _storage.read(key: 'access_token');
      if (newAccessToken != null) {
        final decodedToken = JwtDecoder.decode(newAccessToken);
        final exp = decodedToken['exp'] as int;
        final expiration = DateTime.fromMillisecondsSinceEpoch(exp * 1000);
        final remainingSeconds = expiration
            .difference(DateTime.now())
            .inSeconds;
        _expirationCountdown = remainingSeconds;
        print('⏱️ New token valid for $remainingSeconds seconds');
      }
    } catch (e) {
      print('❌ Token refresh failed: $e');
      // If refresh fails, mark as offline to stop retry attempts
      _isOnline = false;
    } finally {
      _isRefreshing = false;
    }
  }

  /// Get current countdown (for debugging/UI display)
  int? get expirationCountdown => _expirationCountdown;

  /// Check if currently online
  bool get isOnline => _isOnline;

  /// Get formatted time remaining
  String get timeRemaining {
    if (_expirationCountdown == null) return 'Unknown';

    final minutes = _expirationCountdown! ~/ 60;
    final seconds = _expirationCountdown! % 60;

    return '${minutes}m ${seconds}s';
  }

  /// Stop the service and clean up
  void dispose() {
    print('🛑 Disposing TokenRefreshService');
    _refreshTimer?.cancel();
    _connectivitySubscription?.cancel();
    _refreshTimer = null;
    _connectivitySubscription = null;
  }

  /// Manually trigger a refresh check (useful after app resume)
  Future<void> checkNow() async {
    print('🔍 Manual token check triggered');

    // Recheck internet connection
    _isOnline = await _connectivityService.hasInternetConnection();
    print('📶 Connection status: ${_isOnline ? "Online" : "Offline"}');

    await _checkAndRefreshToken();
  }

  /// Force immediate refresh (useful for manual testing)
  Future<void> forceRefresh() async {
    print('🔄 Force refresh triggered');

    if (!_isOnline) {
      print('📴 Cannot force refresh - device is offline');
      return;
    }

    await _performRefresh();
  }
}
