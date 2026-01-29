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
  // ignore: unused_field
  StreamSubscription<bool>? _connectivitySubscription;

  bool _isOnline = true;
  // ignore: unused_field
  int? _expirationCountdown;
  bool _isRefreshing = false;

  TokenRefreshService(this._authService, this._connectivityService);

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
}
