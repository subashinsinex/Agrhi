// lib/src/services/auth_service.dart
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'connectivity_service.dart';

class AuthService {
  final _storage = const FlutterSecureStorage();
  final _connectivityService = ConnectivityService();

  static const String _baseUrl = 'http://10.21.69.186:5000/api';

  /// Check authentication status on app startup
  Future<AuthStatus> checkAuthStatus() async {
    try {
      final accessToken = await _storage.read(key: 'access_token');
      final refreshToken = await _storage.read(key: 'refresh_token');

      // No tokens found
      if (accessToken == null || refreshToken == null) {
        return AuthStatus.unauthenticated;
      }

      // Check if refresh token is expired
      if (JwtDecoder.isExpired(refreshToken)) {
        await clearTokens();
        return AuthStatus.unauthenticated;
      }

      // Check internet connectivity
      final hasInternet = await _connectivityService.hasInternetConnection();

      if (hasInternet) {
        // Try to refresh tokens if needed
        final refreshed = await _refreshTokensIfNeeded(
          accessToken,
          refreshToken,
        );
        return refreshed
            ? AuthStatus.authenticated
            : AuthStatus.unauthenticated;
      } else {
        // Offline mode - allow if refresh token is valid
        return AuthStatus.authenticatedOffline;
      }
    } catch (e) {
      return AuthStatus.unauthenticated;
    }
  }

  /// Refresh tokens if they're expiring soon
  Future<bool> _refreshTokensIfNeeded(
    String accessToken,
    String refreshToken,
  ) async {
    try {
      // Check if access token needs refresh (within 5 minutes of expiry)
      final shouldRefreshAccess = _shouldRefreshToken(accessToken, minutes: 5);

      // Check if refresh token needs refresh (within 3 days of expiry)
      final shouldRefreshRefreshToken = _shouldRefreshToken(
        refreshToken,
        days: 3,
      );

      if (shouldRefreshAccess || shouldRefreshRefreshToken) {
        // Refresh both tokens
        final tokens = await _refreshTokensFromServer(refreshToken);
        if (tokens == null) {
          await clearTokens();
          return false;
        }

        await _storage.write(
          key: 'access_token',
          value: tokens['access_token'],
        );
        await _storage.write(
          key: 'refresh_token',
          value: tokens['refresh_token'],
        );
      }

      return true;
    } catch (e) {
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
      final response = await http
          .post(
            Uri.parse('$_baseUrl/refresh'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $refreshToken',
            },
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {
          'access_token': data['access_token'] as String,
          'refresh_token': data['refresh_token'] as String,
        };
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Get remaining days until refresh token expires
  Future<int?> getRefreshTokenDaysRemaining() async {
    try {
      final refreshToken = await _storage.read(key: 'refresh_token');
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
    await _storage.delete(key: 'access_token');
    await _storage.delete(key: 'refresh_token');
  }

  /// Login method (keep your existing implementation)
  Future<LoginResult> login({
    required String phoneNumber,
    required String password,
  }) async {
    try {
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

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final accessToken = data['access_token'] as String;
        final refreshToken = data['refresh_token'] as String;

        await _storage.write(key: 'access_token', value: accessToken);
        await _storage.write(key: 'refresh_token', value: refreshToken);

        return LoginResult.success();
      } else if (response.statusCode == 401) {
        return LoginResult.failure('Invalid phone number or password');
      } else {
        return LoginResult.failure('Server error. Please try again later');
      }
    } on SocketException {
      return LoginResult.failure('No internet connection');
    } catch (e) {
      return LoginResult.failure('An unexpected error occurred');
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
