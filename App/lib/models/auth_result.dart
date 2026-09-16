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

  bool get isAuthError => errorType == RefreshErrorType.auth;

  bool get isNetworkError => errorType == RefreshErrorType.network;
}

enum RefreshErrorType { none, network, auth, server, unknown }

enum AuthStatus { authenticated, authenticatedOffline, unauthenticated }
