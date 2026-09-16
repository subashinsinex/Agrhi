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
      error: 'Unable to connect. Check your internet connection and try again.',
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
      error: 'The service is temporarily unavailable. Please try again later.',
      errorType: ApiErrorType.server,
    );
  }

  factory ApiResponse.clientError(int statusCode, String message) {
    return ApiResponse._(
      isSuccess: false,
      statusCode: statusCode,
      error:
          'Unable to complete the request. Check your details and try again.',
      errorType: ApiErrorType.client,
    );
  }

  factory ApiResponse.formatError(String message) {
    return ApiResponse._(
      isSuccess: false,
      error: 'The service returned an unexpected response. Please try again.',
      errorType: ApiErrorType.format,
    );
  }

  factory ApiResponse.error(String message) {
    return ApiResponse._(
      isSuccess: false,
      error: 'Unable to complete the action. Please try again.',
      errorType: ApiErrorType.unknown,
    );
  }

  // Helper getters
  bool get isOffline => errorType == ApiErrorType.offline;
  bool get isUnauthorized => errorType == ApiErrorType.unauthorized;
  bool get isUnauthenticated => errorType == ApiErrorType.unauthenticated;
  bool get isTimeout => errorType == ApiErrorType.timeout;
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
