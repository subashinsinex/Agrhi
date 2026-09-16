import 'package:agrhi/models/auth_result.dart';
import 'package:agrhi/models/api_response.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:agrhi/services/connectivity_service.dart';
import 'package:agrhi/services/auth_service.dart';
import 'package:agrhi/core/utils/storage_helper.dart';
import 'package:agrhi/core/utils/constants.dart';

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

  /// ✅ Upload file (multipart/form-data)
  /// Used for profile pictures and other file uploads
  Future<ApiResponse> uploadFile({
    required String endpoint,
    required File file,
    required String fieldName,
    Map<String, String>? additionalFields,
    Map<String, String>? headers,
    Duration? timeout,
  }) async {
    try {
      // Check connectivity
      final isOnline = await _connectivityService.hasInternetConnection();
      if (!isOnline) {
        debugPrint('❌ Upload blocked - No internet connection');
        return ApiResponse.offline();
      }

      // Check authentication
      final authStatus = await _authService.checkAuthStatus();
      if (authStatus == AuthStatus.unauthenticated) {
        debugPrint('❌ Upload blocked - Not authenticated');
        return ApiResponse.unauthenticated();
      }

      if (authStatus == AuthStatus.authenticatedOffline) {
        debugPrint('❌ Upload blocked - Offline mode');
        return ApiResponse.offline();
      }

      // Get token
      final token = await _storageHelper.getAccessToken();
      if (token == null) {
        return ApiResponse.unauthenticated();
      }

      // Verify file exists
      if (!await file.exists()) {
        return ApiResponse.error('File not found');
      }

      // Build multipart request
      final path = endpoint.startsWith('/') ? endpoint : '/$endpoint';
      final uri = Uri.parse('$baseUrl$path');
      debugPrint('📤 Uploading file to: $uri');

      final request = http.MultipartRequest('POST', uri);

      // Add authorization header
      request.headers['Authorization'] = 'Bearer $token';

      // Add custom headers (excluding Content-Type as it's set automatically)
      if (headers != null) {
        for (final entry in headers.entries) {
          if (entry.key.toLowerCase() != 'content-type') {
            request.headers[entry.key] = entry.value;
          }
        }
      }

      // Add additional fields
      if (additionalFields != null) {
        request.fields.addAll(additionalFields);
      }

      // Add file
      final multipartFile = await http.MultipartFile.fromPath(
        fieldName,
        file.path,
      );
      request.files.add(multipartFile);

      debugPrint('📦 File size: ${await file.length()} bytes');
      debugPrint('📋 Additional fields: $additionalFields');

      final response = await _sendWithDeadline(
        request,
        timeout ?? defaultTimeout,
      );

      // Handle response
      return _handleResponse(response);
    } on SocketException catch (e) {
      debugPrint('❌ Network error during upload: $e');
      return ApiResponse.networkError(e.toString());
    } on TimeoutException catch (e) {
      debugPrint('❌ Upload timeout: $e');
      return ApiResponse.timeout();
    } catch (e) {
      debugPrint('❌ Upload failed: $e');
      return ApiResponse.error(e.toString());
    }
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
      var response = await _executeRequest(
        method: method,
        uri: uri,
        headers: requestHeaders,
        body: body,
        timeout: timeout ?? defaultTimeout,
      );

      if (requiresAuth && response.statusCode == 401) {
        await _authService.refreshAccessToken();
        response = await _executeRequest(
          method: method,
          uri: uri,
          headers: await _buildHeaders(headers, true),
          body: body,
          timeout: timeout ?? defaultTimeout,
        );
      }
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
    if (!const {'GET', 'POST', 'PUT', 'DELETE'}.contains(method)) {
      throw UnsupportedError('HTTP method not supported');
    }
    final request = http.Request(method, uri)..headers.addAll(headers);
    if (body != null) request.body = jsonEncode(body);
    return _sendWithDeadline(request, timeout);
  }

  Future<http.Response> _sendWithDeadline(
    http.BaseRequest request,
    Duration timeout,
  ) async {
    final client = http.Client();
    try {
      // The deadline covers headers AND body; closing the client aborts I/O.
      return await (() async {
        final streamed = await client.send(request);
        return await http.Response.fromStream(streamed);
      })().timeout(timeout);
    } finally {
      client.close();
    }
  }

  /// Handle HTTP response
  ApiResponse _handleResponse(http.Response response) {
    debugPrint('📡 Response status: ${response.statusCode}');

    if (response.statusCode >= 200 && response.statusCode < 300) {
      // Success
      try {
        final data = jsonDecode(response.body);
        debugPrint('✅ Response data: $data');
        return ApiResponse.success(data, response.statusCode);
      } catch (e) {
        // Response is not JSON (might be plain text)
        debugPrint('✅ Response body: ${response.body}');
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
      debugPrint('❌ Server error (${response.statusCode}): ${response.body}');
      return ApiResponse.serverError(response.statusCode, response.body);
    } else {
      // Other client errors
      debugPrint('❌ Client error (${response.statusCode}): ${response.body}');
      return ApiResponse.clientError(response.statusCode, response.body);
    }
  }
}
