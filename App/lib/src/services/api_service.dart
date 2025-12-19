import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'connectivity_service.dart';
import 'auth_service.dart';
import '../../utils/storage_helper.dart';
import '../../utils/constants.dart';

/// Centralized API service with automatic connectivity checks,
/// token refresh, and error handling
class ApiService {
  static final ApiService instance = ApiService._();
  ApiService._();

  final _connectivityService = ConnectivityService();
  final _authService = AuthService();
  final _storageHelper = StorageHelper();

  static const String baseUrl = AppConstants.baseUrl;
  static const Duration defaultTimeout = Duration(seconds: 30);

  /// GET request with automatic connectivity check and token refresh
  Future<ApiResponse> get(
    String endpoint, {
    Map<String, String>? headers,
    Map<String, dynamic>? queryParams,
    Duration? timeout,
    bool requiresAuth = true,
  }) async {
    return _makeRequest(
      method: 'GET',
      endpoint: endpoint,
      headers: headers,
      queryParams: queryParams,
      timeout: timeout,
      requiresAuth: requiresAuth,
    );
  }

  /// POST request with automatic connectivity check and token refresh
  Future<ApiResponse> post(
    String endpoint, {
    Map<String, String>? headers,
    Map<String, dynamic>? body,
    Duration? timeout,
    bool requiresAuth = true,
  }) async {
    return _makeRequest(
      method: 'POST',
      endpoint: endpoint,
      headers: headers,
      body: body,
      timeout: timeout,
      requiresAuth: requiresAuth,
    );
  }

  /// PUT request with automatic connectivity check and token refresh
  Future<ApiResponse> put(
    String endpoint, {
    Map<String, String>? headers,
    Map<String, dynamic>? body,
    Duration? timeout,
    bool requiresAuth = true,
  }) async {
    return _makeRequest(
      method: 'PUT',
      endpoint: endpoint,
      headers: headers,
      body: body,
      timeout: timeout,
      requiresAuth: requiresAuth,
    );
  }

  /// DELETE request with automatic connectivity check and token refresh
  Future<ApiResponse> delete(
    String endpoint, {
    Map<String, String>? headers,
    Duration? timeout,
    bool requiresAuth = true,
  }) async {
    return _makeRequest(
      method: 'DELETE',
      endpoint: endpoint,
      headers: headers,
      timeout: timeout,
      requiresAuth: requiresAuth,
    );
  }

  /// Core request handler with all automatic checks
  Future<ApiResponse> _makeRequest({
    required String method,
    required String endpoint,
    Map<String, String>? headers,
    Map<String, dynamic>? body,
    Map<String, dynamic>? queryParams,
    Duration? timeout,
    bool requiresAuth = true,
  }) async {
    try {
      // ✅ STEP 1: Check connectivity
      final isOnline = await _connectivityService.hasInternetConnection();

      if (!isOnline) {
        debugPrint('❌ API call blocked - No internet connection');
        return ApiResponse.offline();
      }

      // ✅ STEP 2: Check authentication and refresh token if needed
      if (requiresAuth) {
        final authStatus = await _authService.checkAuthStatus();

        if (authStatus == AuthStatus.unauthenticated) {
          debugPrint('❌ API call blocked - Not authenticated');
          return ApiResponse.unauthenticated();
        }

        if (authStatus == AuthStatus.authenticatedOffline) {
          debugPrint(
            '❌ API call blocked - Offline mode (cannot reach auth server)',
          );
          return ApiResponse.offline();
        }
      }

      // ✅ STEP 3: Build request
      final uri = _buildUri(endpoint, queryParams);
      final requestHeaders = await _buildHeaders(headers, requiresAuth);

      debugPrint('📡 API $method: $uri');

      // ✅ STEP 4: Execute request
      final response = await _executeRequest(
        method: method,
        uri: uri,
        headers: requestHeaders,
        body: body,
        timeout: timeout ?? defaultTimeout,
      );

      // ✅ STEP 5: Handle response
      return _handleResponse(response);
    } on SocketException catch (e) {
      debugPrint('❌ Network error: $e');
      return ApiResponse.networkError(e.toString());
    } on TimeoutException catch (e) {
      debugPrint('❌ Request timeout: $e');
      return ApiResponse.timeout();
    } on FormatException catch (e) {
      debugPrint('❌ Invalid response format: $e');
      return ApiResponse.formatError(e.toString());
    } catch (e) {
      debugPrint('❌ Unexpected error: $e');
      return ApiResponse.error(e.toString());
    }
  }

  /// Build URI with query parameters
  Uri _buildUri(String endpoint, Map<String, dynamic>? queryParams) {
    final path = endpoint.startsWith('/') ? endpoint : '/$endpoint';
    final url = '$baseUrl$path';

    if (queryParams != null && queryParams.isNotEmpty) {
      return Uri.parse(url).replace(
        queryParameters: queryParams.map(
          (key, value) => MapEntry(key, value.toString()),
        ),
      );
    }

    return Uri.parse(url);
  }

  /// Build request headers with authentication
  Future<Map<String, String>> _buildHeaders(
    Map<String, String>? customHeaders,
    bool requiresAuth,
  ) async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      ...?customHeaders,
    };

    if (requiresAuth) {
      final token = await _storageHelper.getAccessToken();
      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
      }
    }

    return headers;
  }

  /// Execute HTTP request
  Future<http.Response> _executeRequest({
    required String method,
    required Uri uri,
    required Map<String, String> headers,
    Map<String, dynamic>? body,
    required Duration timeout,
  }) async {
    switch (method) {
      case 'GET':
        return await http.get(uri, headers: headers).timeout(timeout);

      case 'POST':
        return await http
            .post(
              uri,
              headers: headers,
              body: body != null ? jsonEncode(body) : null,
            )
            .timeout(timeout);

      case 'PUT':
        return await http
            .put(
              uri,
              headers: headers,
              body: body != null ? jsonEncode(body) : null,
            )
            .timeout(timeout);

      case 'DELETE':
        return await http.delete(uri, headers: headers).timeout(timeout);

      default:
        throw UnsupportedError('HTTP method $method not supported');
    }
  }

  /// Handle HTTP response
  ApiResponse _handleResponse(http.Response response) {
    debugPrint('📡 Response status: ${response.statusCode}');

    if (response.statusCode >= 200 && response.statusCode < 300) {
      // Success
      try {
        final data = jsonDecode(response.body);
        return ApiResponse.success(data, response.statusCode);
      } catch (e) {
        // Response is not JSON (might be plain text)
        return ApiResponse.success(response.body, response.statusCode);
      }
    } else if (response.statusCode == 401) {
      // Unauthorized - token might be invalid
      debugPrint('❌ Unauthorized (401) - Token may be invalid');
      return ApiResponse.unauthorized();
    } else if (response.statusCode == 403) {
      // Forbidden
      debugPrint('❌ Forbidden (403)');
      return ApiResponse.forbidden();
    } else if (response.statusCode == 404) {
      // Not found
      debugPrint('❌ Not found (404)');
      return ApiResponse.notFound();
    } else if (response.statusCode >= 500) {
      // Server error
      debugPrint('❌ Server error (${response.statusCode})');
      return ApiResponse.serverError(response.statusCode, response.body);
    } else {
      // Other client errors
      debugPrint('❌ Client error (${response.statusCode})');
      return ApiResponse.clientError(response.statusCode, response.body);
    }
  }
}

/// API Response wrapper
class ApiResponse {
  final bool isSuccess;
  final int? statusCode;
  final dynamic data;
  final String? error;
  final ApiErrorType errorType;

  ApiResponse._({
    required this.isSuccess,
    this.statusCode,
    this.data,
    this.error,
    this.errorType = ApiErrorType.none,
  });

  // Success response
  factory ApiResponse.success(dynamic data, int statusCode) {
    return ApiResponse._(isSuccess: true, statusCode: statusCode, data: data);
  }

  // Error responses
  factory ApiResponse.offline() {
    return ApiResponse._(
      isSuccess: false,
      error: 'No internet connection',
      errorType: ApiErrorType.offline,
    );
  }

  factory ApiResponse.unauthenticated() {
    return ApiResponse._(
      isSuccess: false,
      error: 'Not authenticated',
      errorType: ApiErrorType.unauthenticated,
    );
  }

  factory ApiResponse.unauthorized() {
    return ApiResponse._(
      isSuccess: false,
      statusCode: 401,
      error: 'Unauthorized - Invalid or expired token',
      errorType: ApiErrorType.unauthorized,
    );
  }

  factory ApiResponse.forbidden() {
    return ApiResponse._(
      isSuccess: false,
      statusCode: 403,
      error: 'Access forbidden',
      errorType: ApiErrorType.forbidden,
    );
  }

  factory ApiResponse.notFound() {
    return ApiResponse._(
      isSuccess: false,
      statusCode: 404,
      error: 'Resource not found',
      errorType: ApiErrorType.notFound,
    );
  }

  factory ApiResponse.networkError(String message) {
    return ApiResponse._(
      isSuccess: false,
      error: 'Network error: $message',
      errorType: ApiErrorType.network,
    );
  }

  factory ApiResponse.timeout() {
    return ApiResponse._(
      isSuccess: false,
      error: 'Request timeout',
      errorType: ApiErrorType.timeout,
    );
  }

  factory ApiResponse.serverError(int statusCode, String message) {
    return ApiResponse._(
      isSuccess: false,
      statusCode: statusCode,
      error: 'Server error: $message',
      errorType: ApiErrorType.server,
    );
  }

  factory ApiResponse.clientError(int statusCode, String message) {
    return ApiResponse._(
      isSuccess: false,
      statusCode: statusCode,
      error: 'Client error: $message',
      errorType: ApiErrorType.client,
    );
  }

  factory ApiResponse.formatError(String message) {
    return ApiResponse._(
      isSuccess: false,
      error: 'Invalid response format: $message',
      errorType: ApiErrorType.format,
    );
  }

  factory ApiResponse.error(String message) {
    return ApiResponse._(
      isSuccess: false,
      error: message,
      errorType: ApiErrorType.unknown,
    );
  }

  // Helper getters
  bool get isOffline => errorType == ApiErrorType.offline;
  bool get isUnauthorized => errorType == ApiErrorType.unauthorized;
  bool get isUnauthenticated => errorType == ApiErrorType.unauthenticated;
  bool get isTimeout => errorType == ApiErrorType.timeout;
  bool get isServerError => errorType == ApiErrorType.server;
}

enum ApiErrorType {
  none,
  offline,
  unauthenticated,
  unauthorized,
  forbidden,
  notFound,
  network,
  timeout,
  server,
  client,
  format,
  unknown,
}
