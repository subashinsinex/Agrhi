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
          final tokens = await _refreshTokensFromServer(refreshToken);

          if (tokens == null) {
            print('❌ Failed to refresh expired access token');
            await clearTokens();
            return AuthStatus.unauthenticated;
          }

          // Store refreshed tokens
          await _storageHelper.write('access_token', tokens['access_token']!);
          await _storageHelper.write('refresh_token', tokens['refresh_token']!);

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
      final tokens = await _refreshTokensFromServer(refreshToken);

      if (tokens == null) {
        await clearTokens();
        throw Exception('Failed to refresh tokens from server');
      }

      // Store new tokens using StorageHelper
      await _storageHelper.write('access_token', tokens['access_token']!);
      await _storageHelper.write('refresh_token', tokens['refresh_token']!);

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

        // Refresh both tokens
        final tokens = await _refreshTokensFromServer(refreshToken);

        if (tokens == null) {
          print('❌ Server returned null - possible network or server issue');
          // DON'T clear tokens here - might just be temporary network issue
          // If refresh token is still valid, allow the user to stay authenticated

          // Check if access token is completely expired
          if (JwtDecoder.isExpired(accessToken)) {
            print('⚠️ Access token expired and refresh failed');
            // If online but refresh failed, it's a real auth problem
            return false;
          }

          // Access token still valid (just expiring soon), allow it
          print('✅ Access token still valid - continuing with current token');
          return true;
        }

        // Successfully refreshed - store new tokens
        await _storageHelper.write('access_token', tokens['access_token']!);
        await _storageHelper.write('refresh_token', tokens['refresh_token']!);

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

  /// Call server to refresh tokens
  Future<Map<String, String>?> _refreshTokensFromServer(
    String refreshToken,
  ) async {
    try {
      print('🔄 Calling refresh token API...');
      print('🔄 Endpoint: $_baseUrl/refreshtoken');

      final response = await http
          .post(
            Uri.parse('$_baseUrl/refreshtoken'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'refreshToken':
                  refreshToken, // Send refresh token in request body
            }),
          )
          .timeout(const Duration(seconds: 10));

      print('🔄 Refresh API Status: ${response.statusCode}');
      print('🔄 Refresh API Response: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        // Ensure both tokens are present in response
        if (data['access_token'] == null || data['refresh_token'] == null) {
          print(
            '❌ Missing tokens in response - received: ${data.keys.join(", ")}',
          );
          return null;
        }

        print('✅ Tokens received from server');
        return {
          'access_token': data['access_token'] as String,
          'refresh_token': data['refresh_token'] as String,
        };
      } else {
        print('❌ Refresh failed with status: ${response.statusCode}');
        print('❌ Response body: ${response.body}');
        return null;
      }
    } on SocketException catch (e) {
      print('❌ Network error calling refresh API: $e');
      return null;
    } on FormatException catch (e) {
      print('❌ Invalid JSON response from refresh API: $e');
      return null;
    } catch (e) {
      print('❌ Error calling refresh API: $e');
      return null;
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

  /// Debug method to check token status (quick check)
  Future<void> debugTokenStatus() async {
    print('\n=== TOKEN DEBUG (Quick) ===');
    final access = await _storageHelper.getAccessToken();
    final refresh = await _storageHelper.getRefreshToken();

    print('Access token exists: ${access != null}');
    print('Refresh token exists: ${refresh != null}');

    if (access != null) {
      print('Access token length: ${access.length}');
      try {
        print('Access token expired: ${JwtDecoder.isExpired(access)}');
        final exp = JwtDecoder.getExpirationDate(access);
        final remaining = exp.difference(DateTime.now());
        print('Access token expires in: ${remaining.inMinutes} minutes');
      } catch (e) {
        print('Error decoding access token: $e');
      }
    }

    if (refresh != null) {
      print('Refresh token length: ${refresh.length}');
      try {
        print('Refresh token expired: ${JwtDecoder.isExpired(refresh)}');
        final exp = JwtDecoder.getExpirationDate(refresh);
        final remaining = exp.difference(DateTime.now());
        print('Refresh token expires in: ${remaining.inDays} days');
      } catch (e) {
        print('Error decoding refresh token: $e');
      }
    }
    print('===========================\n');
  }

  /// Debug: Read and log all stored items (comprehensive)
  Future<void> debugAllStorageItems() async {
    print('\n' + '=' * 60);
    print('🔍 FLUTTER SECURE STORAGE - ALL ITEMS');
    print('=' * 60);

    try {
      // Read all items using StorageHelper
      final allItems = await _storageHelper.readAll();

      if (allItems.isEmpty) {
        print('⚠️ Storage is EMPTY - no items found');
      } else {
        print('✅ Found ${allItems.length} items in storage:\n');

        allItems.forEach((key, value) {
          if (key == 'access_token' || key == 'refresh_token') {
            // Show partial token for security
            final preview = value.length > 50
                ? '${value.substring(0, 30)}...${value.substring(value.length - 20)}'
                : value;
            print('📌 $key:');
            print('   Length: ${value.length} chars');
            print('   Preview: $preview');

            // Try to decode JWT
            try {
              final isExpired = JwtDecoder.isExpired(value);
              final expiryDate = JwtDecoder.getExpirationDate(value);
              final remaining = expiryDate.difference(DateTime.now());
              print('   Expired: $isExpired');
              print(
                '   Expires in: ${remaining.inMinutes} minutes (${remaining.inHours} hours)',
              );
            } catch (e) {
              print('   ⚠️ Invalid JWT format: $e');
            }
          } else {
            // For other items, show full content (limited)
            final preview = value.length > 100
                ? '${value.substring(0, 100)}...'
                : value;
            print('📌 $key:');
            print('   Length: ${value.length} chars');
            print('   Value: $preview');
          }
          print('');
        });
      }

      // Test individual reads with retry
      print('\n' + '-' * 60);
      print('🔄 Testing individual reads with retry logic:');
      print('-' * 60);

      final accessToken = await _storageHelper.getAccessToken();
      final refreshToken = await _storageHelper.getRefreshToken();
      final userProfile = await _storageHelper.getUserProfile();

      print(
        'access_token: ${accessToken != null ? "✅ Found (${accessToken.length} chars)" : "❌ NULL"}',
      );
      print(
        'refresh_token: ${refreshToken != null ? "✅ Found (${refreshToken.length} chars)" : "❌ NULL"}',
      );
      print(
        'user_profile: ${userProfile != null ? "✅ Found (${userProfile.length} chars)" : "❌ NULL"}',
      );
    } catch (e) {
      print('❌ Error reading storage: $e');
    }

    print('=' * 60 + '\n');
  }
}

enum AuthStatus { authenticated, authenticatedOffline, unauthenticated }

class LoginResult {
  final bool isSuccess;
  final String? message;

  LoginResult.success() : isSuccess = true, message = null;

  LoginResult.failure(this.message) : isSuccess = false;
}
