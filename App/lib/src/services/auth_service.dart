import 'dart:async';
import 'package:jwt_decoder/jwt_decoder.dart';
import 'connectivity_service.dart';
import 'api_service.dart';
import '../../utils/storage_helper.dart';
import '../../utils/constants.dart';

class AuthService {
  final _storageHelper = StorageHelper();
  final _connectivityService = ConnectivityService();

  static const String _baseUrl = AppConstants.baseUrl;

  // ✅ ADD: Simple manual lock
  bool _isRefreshing = false;
  final List<Completer<RefreshResult>> _refreshCompleters = [];

  /// Validate JWT token format
  bool _isValidJwtFormat(String token) {
    try {
      final parts = token.split('.');
      return parts.length == 3;
    } catch (e) {
      return false;
    }
  }

  /// Check authentication status on app startup
  Future<AuthStatus> checkAuthStatus() async {
    try {
      final accessToken = await _storageHelper.getAccessToken();
      final refreshToken = await _storageHelper.getRefreshToken();

      print('🔍 Checking auth status...');
      print('  Access token: ${accessToken != null ? "Found" : "NULL"}');
      print('  Refresh token: ${refreshToken != null ? "Found" : "NULL"}');

      // No tokens found
      if (accessToken == null || refreshToken == null) {
        print('❌ No tokens found');
        return AuthStatus.unauthenticated;
      }

      // Validate token format before decoding
      if (!_isValidJwtFormat(accessToken) || !_isValidJwtFormat(refreshToken)) {
        print('❌ Invalid token format');
        await clearTokens();
        return AuthStatus.unauthenticated;
      }

      // Check if refresh token is expired
      if (JwtDecoder.isExpired(refreshToken)) {
        print('❌ Refresh token expired');
        await clearTokens();
        return AuthStatus.unauthenticated;
      }

      // Check internet connectivity
      final hasInternet = await _connectivityService.hasInternetConnection();
      print('📶 Internet: ${hasInternet ? "Available" : "Offline"}');

      if (hasInternet) {
        // Online mode
        final isAccessExpired = JwtDecoder.isExpired(accessToken);

        if (isAccessExpired) {
          print('! Access token expired - attempting refresh...');

          // ✅ Use manual lock for token refresh
          final refreshResult = await _lockedRefreshToken(refreshToken);

          if (!refreshResult.success) {
            if (refreshResult.isNetworkError) {
              print(
                '⚠️ Refresh failed (network error) - switching to offline mode',
              );
              return AuthStatus.authenticatedOffline;
            } else {
              print('❌ Failed to refresh expired access token');
              await clearTokens();
              return AuthStatus.unauthenticated;
            }
          }

          print('✅ Tokens refreshed - authenticated');
          return AuthStatus.authenticated;
        } else {
          // Access token is still valid - try preemptive refresh
          print('✅ Access token valid');

          final refreshed = await _refreshTokensIfNeeded(
            accessToken,
            refreshToken,
          );

          print(
            '✅ Authenticated ${refreshed ? "(tokens refreshed)" : "(using current tokens)"}',
          );
          return AuthStatus.authenticated;
        }
      } else {
        // Offline mode
        print('📴 Offline mode - using cached authentication');
        return AuthStatus.authenticatedOffline;
      }
    } catch (e) {
      print('❌ checkAuthStatus error: $e');

      try {
        final refreshToken = await _storageHelper.getRefreshToken();
        if (refreshToken != null &&
            _isValidJwtFormat(refreshToken) &&
            !JwtDecoder.isExpired(refreshToken)) {
          print(
            '⚠️ Error during check, but tokens valid - allowing offline mode',
          );
          return AuthStatus.authenticatedOffline;
        }
      } catch (_) {}

      return AuthStatus.unauthenticated;
    }
  }

  /// Public method to refresh access token (called by TokenRefreshService)
  Future<void> refreshAccessToken() async {
    try {
      final refreshToken = await _storageHelper.getRefreshToken();

      if (refreshToken == null) {
        throw Exception('No refresh token available');
      }

      if (JwtDecoder.isExpired(refreshToken)) {
        await clearTokens();
        throw Exception('Refresh token expired');
      }

      // ✅ Use manual lock to prevent concurrent refresh
      final result = await _lockedRefreshToken(refreshToken);

      if (!result.success) {
        if (result.isNetworkError) {
          throw Exception('Network error: ${result.error}');
        } else {
          await clearTokens();
          throw Exception('Failed to refresh tokens from server');
        }
      }

      print('✅ Access token refreshed successfully');
    } catch (e) {
      print('❌ Error in refreshAccessToken: $e');
      rethrow;
    }
  }

  /// Refresh tokens if they're expiring soon (non-critical refresh)
  Future<bool> _refreshTokensIfNeeded(
    String accessToken,
    String refreshToken,
  ) async {
    try {
      final shouldRefreshAccess = _shouldRefreshToken(accessToken, minutes: 5);
      final shouldRefreshRefreshToken = _shouldRefreshToken(
        refreshToken,
        days: 3,
      );

      if (shouldRefreshAccess || shouldRefreshRefreshToken) {
        print('🔄 Token refresh needed - attempting preemptive refresh...');

        // ✅ Use manual lock to prevent concurrent refresh
        final result = await _lockedRefreshToken(refreshToken);

        if (!result.success) {
          if (result.isNetworkError) {
            print(
              '⚠️ Refresh failed (network) - continuing with current tokens',
            );

            if (JwtDecoder.isExpired(accessToken)) {
              print('⚠️ Access token expired and refresh failed');
              return false;
            }

            return true;
          } else {
            print('❌ Refresh failed with auth error');
            return false;
          }
        }

        print('✅ Tokens refreshed successfully');
      }

      return true;
    } catch (e) {
      print('❌ Error in _refreshTokensIfNeeded: $e');

      try {
        if (!JwtDecoder.isExpired(accessToken)) {
          print('✅ Access token still valid despite refresh error');
          return true;
        }
      } catch (_) {}

      return false;
    }
  }

  /// Check if token should be refreshed based on expiry time
  bool _shouldRefreshToken(String token, {int? minutes, int? days}) {
    try {
      if (JwtDecoder.isExpired(token)) {
        return true;
      }

      final expiryDate = JwtDecoder.getExpirationDate(token);
      final now = DateTime.now();
      final difference = expiryDate.difference(now);

      if (minutes != null) {
        return difference.inMinutes < minutes;
      }

      if (days != null) {
        return difference.inDays < days;
      }

      return false;
    } catch (e) {
      return true;
    }
  }

  // ✅ NEW: Manual lock implementation for token refresh
  Future<RefreshResult> _lockedRefreshToken(String refreshToken) async {
    // If already refreshing, wait for the existing refresh to complete
    if (_isRefreshing) {
      print('⏳ Token refresh already in progress - waiting...');
      final completer = Completer<RefreshResult>();
      _refreshCompleters.add(completer);
      return completer.future;
    }

    // Start refresh
    _isRefreshing = true;

    try {
      final result = await _refreshToken(refreshToken);

      // Notify all waiting requests
      for (final completer in _refreshCompleters) {
        if (!completer.isCompleted) {
          completer.complete(result);
        }
      }
      _refreshCompleters.clear();

      return result;
    } catch (e) {
      final errorResult = RefreshResult.networkError(e.toString());

      // Notify all waiting requests about the error
      for (final completer in _refreshCompleters) {
        if (!completer.isCompleted) {
          completer.complete(errorResult);
        }
      }
      _refreshCompleters.clear();

      return errorResult;
    } finally {
      _isRefreshing = false;
    }
  }

  /// Call server to refresh access token
  Future<RefreshResult> _refreshToken(String refreshToken) async {
    try {
      print('🔄 Calling refresh token API...');
      print('🔄 Endpoint: $_baseUrl/refreshtoken');

      final response = await ApiService.instance.post(
        '/refreshtoken',
        body: {'refresh_token': refreshToken},
        timeout: const Duration(seconds: 10),
        requiresAuth: false,
      );

      print('🔄 Refresh API Status: ${response.statusCode}');

      if (response.isSuccess) {
        final data = response.data;
        final newAccessToken = data['access_token'];

        if (newAccessToken == null) {
          print('❌ Missing access_token in response');
          return RefreshResult.failure('Missing access_token');
        }

        await _storageHelper.write('access_token', newAccessToken as String);
        print('✅ New access token stored successfully');

        return RefreshResult.success();
      } else if (response.isUnauthorized ||
          response.errorType == ApiErrorType.forbidden) {
        print('❌ Refresh token invalid or expired (${response.statusCode})');
        return RefreshResult.authError('Invalid or expired refresh token');
      } else if (response.isOffline ||
          response.isTimeout ||
          response.errorType == ApiErrorType.network) {
        print('⚠️ Refresh failed - network issue');
        return RefreshResult.networkError(response.error ?? 'Network error');
      } else {
        print('⚠️ Refresh failed: ${response.error}');
        return RefreshResult.serverError(response.error ?? 'Server error');
      }
    } catch (e) {
      print('❌ Error calling refresh API: $e');
      return RefreshResult.networkError(e.toString());
    }
  }

  /// Clear all stored tokens
  Future<void> clearTokens() async {
    await _storageHelper.delete('access_token');
    await _storageHelper.delete('refresh_token');
    await _storageHelper.delete('user_profile');
    print('🗑️ All tokens cleared');
  }
}

class RefreshResult {
  final bool success;
  final String? error;
  final RefreshErrorType errorType;

  RefreshResult.success()
    : success = true,
      error = null,
      errorType = RefreshErrorType.none;

  RefreshResult.failure(this.error)
    : success = false,
      errorType = RefreshErrorType.unknown;

  RefreshResult.networkError(this.error)
    : success = false,
      errorType = RefreshErrorType.network;

  RefreshResult.authError(this.error)
    : success = false,
      errorType = RefreshErrorType.auth;

  RefreshResult.serverError(this.error)
    : success = false,
      errorType = RefreshErrorType.server;

  bool get isNetworkError => errorType == RefreshErrorType.network;
}

enum RefreshErrorType { none, network, auth, server, unknown }

enum AuthStatus { authenticated, authenticatedOffline, unauthenticated }

