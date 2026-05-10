import 'package:dio/dio.dart';

import '../storage/secure_token_store.dart';

/// Attaches the bearer token to every outbound request, and on 401 attempts
/// a single refresh before bubbling the error up to the caller.
///
/// Refresh logic is intentionally minimal here — the actual token endpoints
/// don't exist on the backend yet (see BACKEND_REQUEST). When they ship,
/// wire `_refresh` to call `POST /api/auth/refresh/` and update the store.
class AuthInterceptor extends QueuedInterceptor {
  AuthInterceptor(this._store, this._dio);

  final SecureTokenStore _store;
  final Dio _dio;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (options.extra['skipAuth'] != true) {
      final token = await _store.readAccessToken();
      if (token != null && token.isNotEmpty) {
        options.headers['Authorization'] = 'Bearer $token';
      }
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final isUnauthorized = err.response?.statusCode == 401;
    final alreadyRetried = err.requestOptions.extra['didRetry'] == true;
    final isAuthEndpoint = err.requestOptions.extra['skipAuth'] == true;

    if (!isUnauthorized || alreadyRetried || isAuthEndpoint) {
      handler.next(err);
      return;
    }

    final refreshed = await _refresh();
    if (!refreshed) {
      await _store.clear();
      handler.next(err);
      return;
    }

    try {
      final retried = await _dio.fetch(
        err.requestOptions..extra['didRetry'] = true,
      );
      handler.resolve(retried);
    } on DioException catch (e) {
      handler.next(e);
    }
  }

  /// Returns `true` if a fresh access token was obtained, `false` otherwise.
  ///
  /// Stub today — backend endpoint not yet live. Wire when ready:
  ///   POST /api/auth/refresh/ { refresh } → { access, ... }
  Future<bool> _refresh() async {
    return false;
  }
}
