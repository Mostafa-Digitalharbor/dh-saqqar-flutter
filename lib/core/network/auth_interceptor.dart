import 'package:dio/dio.dart';

import '../storage/secure_token_store.dart';

/// Attaches the bearer token to every outbound request, and on 401 clears
/// the stored token (no refresh endpoint exists per SAQQAR_MOBILE_API.md §1
/// — the contract is "drop the token, route to sign-in, surface
/// 'Your session ended.'").
///
/// Also fires [onUnauthorized] (when supplied) so the AuthCubit can flip
/// its state to unauthenticated synchronously — otherwise the router
/// gate keeps showing protected routes until the next unrelated cubit
/// rebuild, which can produce cascading 401s in the meantime.
///
/// Endpoints that must not attach a (potentially-stale) bearer token
/// should set `extra['skipAuth'] = true` on the request options — see
/// [AuthApi].
class AuthInterceptor extends QueuedInterceptor {
  AuthInterceptor(this._store, {this.onUnauthorized});

  final SecureTokenStore _store;

  /// Fired exactly once per 401 — after the local token is cleared but
  /// before the error bubbles up to the caller. Wire in `main.dart`:
  ///
  /// ```dart
  /// late final authCubit = AuthCubit(...);
  /// final dio = buildDio(tokenStore,
  ///   onUnauthorized: () => authCubit.handleUnauthorized());
  /// ```
  final void Function()? onUnauthorized;

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
    final isAuthEndpoint = err.requestOptions.extra['skipAuth'] == true;

    // Only treat the 401 as token-invalidation when the server
    // explicitly tells us so via `auth: false` in the JSON envelope
    // (SAQQAR_MOBILE_API.md §14). A bare 401 could be a transient
    // network blip relayed by a proxy, an endpoint-specific permission
    // issue, or a misbehaving upstream — kicking the user back to the
    // sign-in screen for any of those was an over-reaction that the
    // user explicitly asked us to stop. Surfaces the error normally
    // but keeps the session alive otherwise.
    final body = err.response?.data;
    final isTokenInvalid = body is Map<String, dynamic> && body['auth'] == false;

    if (isUnauthorized && !isAuthEndpoint && isTokenInvalid) {
      await _store.clear();
      onUnauthorized?.call();
    }

    handler.next(err);
  }
}
