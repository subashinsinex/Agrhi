// lib/src/services/auth_service.dart
import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:jwt_decoder/jwt_decoder.dart';
import 'connectivity_service.dart';
import '../../utils/storage_helper.dart';
import '../../utils/constants.dart';

class AuthService {
  final _storageHelper = StorageHelper();
  final _connectivityService = ConnectivityService();

  static const String _baseUrl = AppConstants.baseUrl;

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
          print('⚠️ Access token expired - attempting refresh...');

          // Access token is expired - MUST refresh
          final refreshResult = await _refreshToken(refreshToken);

          // ✅ Check if it's a network error vs auth error
          if (!refreshResult.success) {
            if (refreshResult.isNetworkError) {
              // Network error - allow offline mode
              print(
                '⚠️ Refresh failed (network error) - switching to offline mode',
              );
              return AuthStatus.authenticatedOffline;
            } else {
              // Auth error - clear tokens
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

      // ✅ On error, check if we have valid tokens for offline mode
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
      } catch (_) {
        // Ignore token check errors
      }

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

      // Check if refresh token is expired
      if (JwtDecoder.isExpired(refreshToken)) {
        await clearTokens();
        throw Exception('Refresh token expired');
      }

      // Call server to refresh tokens
      final result = await _refreshToken(refreshToken);

      if (!result.success) {
        // ✅ Only clear tokens on auth errors, not network errors
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

        final result = await _refreshToken(refreshToken);

        if (!result.success) {
          // ✅ Network error - keep using current tokens
          if (result.isNetworkError) {
            print(
              '⚠️ Refresh failed (network) - continuing with current tokens',
            );

            // Check if access token is completely expired
            if (JwtDecoder.isExpired(accessToken)) {
              print('⚠️ Access token expired and refresh failed');
              return false;
            }

            return true; // Token still valid, continue
          } else {
            // Auth error
            print('❌ Refresh failed with auth error');
            return false;
          }
        }

        print('✅ Tokens refreshed successfully');
      }

      return true;
    } catch (e) {
      print('❌ Error in _refreshTokensIfNeeded: $e');

      // Check if current tokens are still usable
      try {
        if (!JwtDecoder.isExpired(accessToken)) {
          print('✅ Access token still valid despite refresh error');
          return true;
        }
      } catch (_) {
        // Token parsing failed
      }

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

  /// Call server to refresh access token
  /// ✅ Returns RefreshResult to distinguish network errors from auth errors
  Future<RefreshResult> _refreshToken(String refreshToken) async {
    try {
      print('🔄 Calling refresh token API...');
      print('🔄 Endpoint: $_baseUrl/refreshtoken');

      final response = await http
          .post(
            Uri.parse('$_baseUrl/refreshtoken'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'refresh_token': refreshToken}),
          )
          .timeout(const Duration(seconds: 10));

      print('🔄 Refresh API Status: ${response.statusCode}');
      print('🔄 Refresh API Response: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final newAccessToken = data['access_token'];

        if (newAccessToken == null) {
          print('❌ Missing access_token in response');
          return RefreshResult.failure('Missing access_token');
        }

        await _storageHelper.write('access_token', newAccessToken as String);
        print('✅ New access token stored successfully');

        return RefreshResult.success();
      }
      // ✅ Auth errors - tokens are invalid
      else if (response.statusCode == 401 || response.statusCode == 403) {
        print('❌ Refresh token invalid or expired (${response.statusCode})');
        return RefreshResult.authError('Invalid or expired refresh token');
      }
      // ✅ Server errors - temporary issue
      else {
        print('⚠️ Refresh failed with status: ${response.statusCode}');
        return RefreshResult.serverError(
          'Server error: ${response.statusCode}',
        );
      }
    } on SocketException catch (e) {
      // ✅ Network error - keep tokens for offline mode
      print('❌ Network error calling refresh API: $e');
      return RefreshResult.networkError('No internet connection');
    } on TimeoutException catch (e) {
      // ✅ Timeout - keep tokens
      print('❌ Timeout calling refresh API: $e');
      return RefreshResult.networkError('Request timeout');
    } on FormatException catch (e) {
      // ✅ Invalid response format
      print('❌ Invalid JSON response from refresh API: $e');
      return RefreshResult.serverError('Invalid server response');
    } catch (e) {
      print('❌ Error calling refresh API: $e');
      // ✅ Unknown errors - treat as network issue to be safe
      return RefreshResult.networkError(e.toString());
    }
  }

  /// Get remaining days until refresh token expires
  Future<int?> getRefreshTokenDaysRemaining() async {
    try {
      final refreshToken = await _storageHelper.getRefreshToken();
      if (refreshToken == null) return null;

      final expiryDate = JwtDecoder.getExpirationDate(refreshToken);
      final now = DateTime.now();
      final difference = expiryDate.difference(now);

      return difference.inDays;
    } catch (e) {
      return null;
    }
  }

  /// Clear all stored tokens
  Future<void> clearTokens() async {
    await _storageHelper.delete('access_token');
    await _storageHelper.delete('refresh_token');
    await _storageHelper.delete('user_profile');
    print('🗑️ All tokens cleared');
  }

  /// Login method
  Future<LoginResult> login({
    required String phoneNumber,
    required String password,
  }) async {
    try {
      print('🔐 Attempting login...');

      final response = await http
          .post(
            Uri.parse('$_baseUrl/login'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'phone_number': phoneNumber,
              'password': password,
              'platform': 'mobile',
            }),
          )
          .timeout(const Duration(seconds: 30));

      print('🔐 Login response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final accessToken = data['access_token'] as String;
        final refreshToken = data['refresh_token'] as String;

        print('💾 Storing tokens...');

        await _storageHelper.write('access_token', accessToken);
        await _storageHelper.write('refresh_token', refreshToken);

        // VERIFY tokens were stored
        await Future.delayed(const Duration(milliseconds: 100));
        final storedAccess = await _storageHelper.getAccessToken();
        final storedRefresh = await _storageHelper.getRefreshToken();

        print('✅ Access token stored: ${storedAccess != null}');
        print('✅ Refresh token stored: ${storedRefresh != null}');

        if (storedAccess == null || storedRefresh == null) {
          print('❌ Token storage failed!');
          return LoginResult.failure('Failed to save login credentials');
        }

        // Store user profile if available
        if (data['user'] != null) {
          await _storageHelper.write('user_profile', jsonEncode(data['user']));
          print('✅ User profile stored');
        }

        print('✅ Login successful');
        return LoginResult.success();
      } else if (response.statusCode == 401) {
        print('❌ Invalid credentials');
        return LoginResult.failure('Invalid phone number or password');
      } else {
        print('❌ Server error: ${response.statusCode}');
        return LoginResult.failure('Server error. Please try again later');
      }
    } on SocketException {
      print('❌ No internet connection');
      return LoginResult.failure('No internet connection');
    } on FormatException catch (e) {
      print('❌ Invalid response format: $e');
      return LoginResult.failure('Invalid response from server');
    } catch (e) {
      print('❌ Login error: $e');
      return LoginResult.failure('An unexpected error occurred');
    }
  }

  /// Logout method
  Future<void> logout() async {
    try {
      print('🚪 Logging out...');
      final accessToken = await _storageHelper.getAccessToken();

      if (accessToken != null) {
        try {
          await http
              .post(
                Uri.parse('$_baseUrl/logout'),
                headers: {
                  'Content-Type': 'application/json',
                  'Authorization': 'Bearer $accessToken',
                },
              )
              .timeout(const Duration(seconds: 5));
          print('✅ Logout API called successfully');
        } catch (e) {
          print('⚠️ Logout API call failed: $e');
        }
      }
    } finally {
      await clearTokens();
      print('✅ Logout complete');
    }
  }
}

// ✅ NEW: RefreshResult class to distinguish error types
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
  bool get isAuthError => errorType == RefreshErrorType.auth;
  bool get isServerError => errorType == RefreshErrorType.server;
}

enum RefreshErrorType {
  none,
  network, // Network issues - keep tokens
  auth, // Authentication failed - clear tokens
  server, // Server error - keep tokens (temporary issue)
  unknown,
}

enum AuthStatus { authenticated, authenticatedOffline, unauthenticated }

class LoginResult {
  final bool isSuccess;
  final String? message;

  LoginResult.success() : isSuccess = true, message = null;
  LoginResult.failure(this.message) : isSuccess = false;
}
