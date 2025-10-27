// lib/src/services/auth_service.dart
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:jwt_decoder/jwt_decoder.dart';
import 'connectivity_service.dart';
import '../../utils/storage_helper.dart';
import '../../utils/constants.dart';

class AuthService {
  // Use StorageHelper singleton instead of direct FlutterSecureStorage
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
      // Use StorageHelper to read tokens
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
          final success = await _refreshToken(refreshToken);

          if (!success) {
            print('❌ Failed to refresh expired access token');
            await clearTokens();
            return AuthStatus.unauthenticated;
          }

          print('✅ Tokens refreshed - authenticated');
          return AuthStatus.authenticated;
        } else {
          // Access token is still valid - just check if it needs preemptive refresh
          print('✅ Access token valid');

          // Try to refresh if expiring soon (non-blocking)
          final refreshed = await _refreshTokensIfNeeded(
            accessToken,
            refreshToken,
          );

          // Even if preemptive refresh fails, we're still authenticated
          // because the current token is valid
          print(
            '✅ Authenticated ${refreshed ? "(tokens refreshed)" : "(using current tokens)"}',
          );
          return AuthStatus.authenticated;
        }
      } else {
        // Offline mode
        print('📴 Offline mode');

        // In offline mode, we allow expired access tokens
        // as long as refresh token is valid
        return AuthStatus.authenticatedOffline;
      }
    } catch (e) {
      print('❌ checkAuthStatus error: $e');
      return AuthStatus.unauthenticated;
    }
  }

  /// Public method to refresh access token (called by TokenRefreshService)
  Future<void> refreshAccessToken() async {
    try {
      // Use StorageHelper to get refresh token
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
      final success = await _refreshToken(refreshToken);

      if (!success) {
        await clearTokens();
        throw Exception('Failed to refresh tokens from server');
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
      // Check if access token needs refresh (expired or expiring within 5 minutes)
      final shouldRefreshAccess = _shouldRefreshToken(accessToken, minutes: 5);

      // Check if refresh token needs refresh (within 3 days of expiry)
      final shouldRefreshRefreshToken = _shouldRefreshToken(
        refreshToken,
        days: 3,
      );

      if (shouldRefreshAccess || shouldRefreshRefreshToken) {
        print('🔄 Token refresh needed - attempting preemptive refresh...');

        // Refresh tokens
        final success = await _refreshToken(refreshToken);

        if (!success) {
          print('❌ Server returned error - possible network or server issue');
          // DON'T clear tokens here - might just be temporary network issue

          // Check if access token is completely expired
          if (JwtDecoder.isExpired(accessToken)) {
            print('⚠️ Access token expired and refresh failed');
            return false;
          }

          // Access token still valid (just expiring soon), allow it
          print('✅ Access token still valid - continuing with current token');
          return true;
        }

        print('✅ Tokens refreshed successfully');
      }

      return true;
    } catch (e) {
      print('❌ Error in _refreshTokensIfNeeded: $e');

      // Don't immediately fail - check if current tokens are still usable
      try {
        // If access token is still valid (not expired), allow it
        if (!JwtDecoder.isExpired(accessToken)) {
          print('✅ Access token still valid despite refresh error');
          return true;
        }
      } catch (_) {
        // Token parsing failed
      }

      // Access token is expired and refresh failed
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

  /// Call server to refresh access token (only returns access_token, no refresh_token)
  Future<bool> _refreshToken(String refreshToken) async {
    try {
      print('🔄 Calling refresh token API...');
      print('🔄 Endpoint: $_baseUrl/refreshtoken');

      final response = await http
          .post(
            Uri.parse('$_baseUrl/refreshtoken'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'refresh_token':
                  refreshToken, // Send as camelCase or snake_case based on your API
            }),
          )
          .timeout(const Duration(seconds: 10));

      print('🔄 Refresh API Status: ${response.statusCode}');
      print('🔄 Refresh API Response: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        // Server only sends access_token (snake_case), not refresh_token
        final newAccessToken = data['access_token'];

        if (newAccessToken == null) {
          print('❌ Missing access_token in response');
          return false;
        }

        // Store only the new access token (refresh token stays the same)
        await _storageHelper.write('access_token', newAccessToken as String);
        print('✅ New access token stored successfully');

        // Note: refresh_token is NOT updated since server doesn't send a new one
        return true;
      } else {
        print('❌ Refresh failed with status: ${response.statusCode}');
        print('❌ Response body: ${response.body}');
        return false;
      }
    } on SocketException catch (e) {
      print('❌ Network error calling refresh API: $e');
      return false;
    } on FormatException catch (e) {
      print('❌ Invalid JSON response from refresh API: $e');
      return false;
    } catch (e) {
      print('❌ Error calling refresh API: $e');
      return false;
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

        // Use StorageHelper to store tokens
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
        // Try to call logout API
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
          // Continue with local logout even if API fails
        }
      }
    } finally {
      // Always clear tokens regardless of API call result
      await clearTokens();
      print('✅ Logout complete');
    }
  }
}

enum AuthStatus { authenticated, authenticatedOffline, unauthenticated }

class LoginResult {
  final bool isSuccess;
  final String? message;

  LoginResult.success() : isSuccess = true, message = null;

  LoginResult.failure(this.message) : isSuccess = false;
}
