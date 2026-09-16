import 'package:flutter/foundation.dart';
import 'package:agrhi/models/api_response.dart';
import 'package:agrhi/models/auth_result.dart';
import 'package:agrhi/services/session_coordinator.dart';
import 'dart:async';
import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:agrhi/services/connectivity_service.dart';
import 'package:agrhi/services/api_service.dart';
import 'package:agrhi/core/utils/storage_helper.dart';
import 'package:agrhi/core/utils/constants.dart';

class AuthService {
  static final AuthService _instance = AuthService._();
  factory AuthService() => _instance;
  AuthService._() : _storageHelper = StorageHelper(), _refreshRequest = null;
  AuthService.withDependencies({
    required StorageHelper storage,
    required Future<ApiResponse> Function(String) this._refreshRequest,
  }) : _storageHelper = storage;

  /// Fast local routing check; no networking or credential deletion.
  Future<AuthStatus> cachedStatus() async {
    // Storage/plugin failures must reach startup recovery, not masquerade as logout.
    final access = await _storageHelper.getAccessToken();
    final refresh = await _storageHelper.getRefreshToken();
    try {
      if (access == null || refresh == null || JwtDecoder.isExpired(refresh)) {
        return AuthStatus.unauthenticated;
      }
      JwtDecoder.decode(access);
      return AuthStatus.authenticatedOffline;
    } catch (_) {
      return AuthStatus.unauthenticated;
    }
  }

  final StorageHelper _storageHelper;
  final Future<ApiResponse> Function(String)? _refreshRequest;
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
    return SessionCoordinator.instance.run(() async {
      try {
        final accessToken = await _storageHelper.getAccessToken();
        final refreshToken = await _storageHelper.getRefreshToken();

        debugPrint('🔍 Checking auth status...');
        debugPrint('  Access token: ${accessToken != null ? "Found" : "NULL"}');
        debugPrint(
          '  Refresh token: ${refreshToken != null ? "Found" : "NULL"}',
        );

        // No tokens found
        if (accessToken == null || refreshToken == null) {
          debugPrint('❌ No tokens found');
          return AuthStatus.unauthenticated;
        }

        // Validate token format before decoding
        if (!_isValidJwtFormat(accessToken) ||
            !_isValidJwtFormat(refreshToken)) {
          debugPrint('❌ Invalid token format');
          await clearTokens();
          return AuthStatus.unauthenticated;
        }

        // Check if refresh token is expired
        if (JwtDecoder.isExpired(refreshToken)) {
          debugPrint('❌ Refresh token expired');
          await clearTokens();
          return AuthStatus.unauthenticated;
        }

        // Check internet connectivity
        final hasInternet = await _connectivityService.hasInternetConnection();
        debugPrint('📶 Internet: ${hasInternet ? "Available" : "Offline"}');

        if (hasInternet) {
          // Online mode
          final isAccessExpired = JwtDecoder.isExpired(accessToken);

          if (isAccessExpired) {
            debugPrint('! Access token expired - attempting refresh...');

            // ✅ Use manual lock for token refresh
            final refreshResult = await _lockedRefreshToken(refreshToken);

            if (!refreshResult.success) {
              if (!refreshResult.isAuthError) {
                debugPrint(
                  '⚠️ Refresh failed (network error) - switching to offline mode',
                );
                return AuthStatus.authenticatedOffline;
              } else {
                debugPrint('❌ Failed to refresh expired access token');
                await clearTokens();
                return AuthStatus.unauthenticated;
              }
            }

            debugPrint('✅ Tokens refreshed - authenticated');
            return AuthStatus.authenticated;
          } else {
            // Access token is still valid - try preemptive refresh
            debugPrint('✅ Access token valid');

            final refreshed = await _refreshTokensIfNeeded(
              accessToken,
              refreshToken,
            );
            if (!refreshed && await _storageHelper.getAccessToken() == null) {
              return AuthStatus.unauthenticated;
            }

            debugPrint(
              '✅ Authenticated ${refreshed ? "(tokens refreshed)" : "(using current tokens)"}',
            );
            return AuthStatus.authenticated;
          }
        } else {
          // Offline mode
          debugPrint('📴 Offline mode - using cached authentication');
          return AuthStatus.authenticatedOffline;
        }
      } catch (e) {
        debugPrint('❌ checkAuthStatus error: $e');

        try {
          final refreshToken = await _storageHelper.getRefreshToken();
          if (refreshToken != null &&
              _isValidJwtFormat(refreshToken) &&
              !JwtDecoder.isExpired(refreshToken)) {
            debugPrint(
              '⚠️ Error during check, but tokens valid - allowing offline mode',
            );
            return AuthStatus.authenticatedOffline;
          }
        } catch (_) {}

        return AuthStatus.unauthenticated;
      }
    });
  }

  /// Refresh the access token through the shared session coordinator
  Future<void> refreshAccessToken() async {
    return SessionCoordinator.instance.run(() async {
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
          if (!result.isAuthError) {
            throw Exception('Network error: ${result.error}');
          } else {
            await clearTokens();
            throw Exception('Failed to refresh tokens from server');
          }
        }

        debugPrint('✅ Access token refreshed successfully');
      } catch (e) {
        debugPrint('❌ Error in refreshAccessToken: $e');
        rethrow;
      }
    });
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
        debugPrint(
          '🔄 Token refresh needed - attempting preemptive refresh...',
        );

        // ✅ Use manual lock to prevent concurrent refresh
        final result = await _lockedRefreshToken(refreshToken);

        if (!result.success) {
          if (!result.isAuthError) {
            debugPrint(
              '⚠️ Refresh failed (network) - continuing with current tokens',
            );

            if (JwtDecoder.isExpired(accessToken)) {
              debugPrint('⚠️ Access token expired and refresh failed');
              return false;
            }

            return true;
          } else {
            debugPrint('❌ Refresh failed with auth error');
            await clearTokens();
            return false;
          }
        }

        debugPrint('✅ Tokens refreshed successfully');
      }

      return true;
    } catch (e) {
      debugPrint('❌ Error in _refreshTokensIfNeeded: $e');

      try {
        if (!JwtDecoder.isExpired(accessToken)) {
          debugPrint('✅ Access token still valid despite refresh error');
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
      debugPrint('⏳ Token refresh already in progress - waiting...');
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
      debugPrint('🔄 Calling refresh token API...');
      debugPrint('🔄 Endpoint: $_baseUrl/refreshtoken');

      final response =
          await (_refreshRequest?.call(refreshToken) ??
              ApiService.instance.post(
                '/refreshtoken',
                body: {'refresh_token': refreshToken},
                timeout: const Duration(seconds: 10),
                requiresAuth: false,
              ));

      debugPrint('🔄 Refresh API Status: ${response.statusCode}');

      if (response.isSuccess) {
        final data = response.data;
        final newAccessToken = data['access_token'];

        if (newAccessToken == null) {
          debugPrint('❌ Missing access_token in response');
          return RefreshResult.failure('Missing access_token');
        }

        // Validate both values before modifying the stored session.
        JwtDecoder.decode(newAccessToken as String);
        final newRefreshToken = data['refresh_token'];
        if (newRefreshToken != null) {
          JwtDecoder.decode(newRefreshToken as String);
          await _storageHelper.write('refresh_token', newRefreshToken);
        }
        await _storageHelper.write('access_token', newAccessToken);
        debugPrint('✅ New access token stored successfully');

        return RefreshResult.success();
      } else if (response.isUnauthorized ||
          response.errorType == ApiErrorType.forbidden) {
        debugPrint(
          '❌ Refresh token invalid or expired (${response.statusCode})',
        );
        return RefreshResult.authError('Invalid or expired refresh token');
      } else if (response.isOffline ||
          response.isTimeout ||
          response.errorType == ApiErrorType.network) {
        debugPrint('⚠️ Refresh failed - network issue');
        return RefreshResult.networkError(response.error ?? 'Network error');
      } else {
        debugPrint('⚠️ Refresh failed: ${response.error}');
        return RefreshResult.serverError(response.error ?? 'Server error');
      }
    } catch (e) {
      debugPrint('❌ Error calling refresh API: $e');
      return RefreshResult.networkError(e.toString());
    }
  }

  /// Clear all stored tokens
  Future<void> clearTokens() async {
    await _storageHelper.delete('access_token');
    await _storageHelper.delete('refresh_token');
    await _storageHelper.delete('user_profile');
    debugPrint('🗑️ All tokens cleared');
  }
}
