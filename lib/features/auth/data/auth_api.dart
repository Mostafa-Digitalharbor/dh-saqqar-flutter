import 'package:dio/dio.dart';

import '../../../core/network/api_endpoints.dart';
import 'auth_models.dart';

/// Repository for `/api/v1/auth/*` endpoints. Returns typed models; throws
/// the [ApiException] surfaced by the Dio interceptor on any non-2xx.
///
/// Auth endpoints set `extra['skipAuth'] = true` so the [AuthInterceptor]
/// doesn't try to attach (a likely-stale) bearer token or attempt a refresh
/// on 401 — login / register / refresh must work even when no token exists.
class AuthApi {
  AuthApi(this._dio);

  final Dio _dio;

  static const _skipAuth = <String, dynamic>{'skipAuth': true};

  /// `POST /api/v1/auth/register/` — creates an account and returns a fresh
  /// bearer token. 400 on weak/missing password, 409 on duplicate email.
  ///
  /// [username] is the display name the user typed on the sign-up form.
  /// The contract in SAQQAR_MOBILE_API.md only mandates email + password,
  /// but Django's `User` model carries a `username` column, and the
  /// register endpoint accepts it as an optional hint — pass it through
  /// so the account screen has a real name to show instead of an
  /// auto-derived one.
  Future<AuthSession> register({
    required String email,
    required String password,
    String? username,
  }) async {
    final body = <String, dynamic>{'email': email, 'password': password};
    final name = username?.trim();
    if (name != null && name.isNotEmpty) body['username'] = name;
    final res = await _dio.post<Map<String, dynamic>>(
      ApiEndpoints.register,
      data: body,
      options: Options(extra: _skipAuth),
    );
    return _sessionFrom(res.data!);
  }

  /// `POST /api/v1/auth/login/` — exchanges email + password for a bearer
  /// token. 401 on bad credentials (also when account is inactive — server
  /// returns the same error to avoid account-existence enumeration).
  Future<AuthSession> login({
    required String email,
    required String password,
  }) async {
    final res = await _dio.post<Map<String, dynamic>>(
      ApiEndpoints.login,
      data: {'email': email, 'password': password},
      options: Options(extra: _skipAuth),
    );
    return _sessionFrom(res.data!);
  }

  /// `POST /api/v1/auth/logout/` — revokes the token used on this call.
  /// Always settle the local state regardless of the network result — if
  /// the server can't reach us we still want the device signed out.
  Future<bool> logout() async {
    final res = await _dio.post<Map<String, dynamic>>(ApiEndpoints.logout);
    return res.data?['revoked'] as bool? ?? false;
  }

  /// `GET /api/v1/auth/me/` — identity + per-user counts. Used on cold
  /// start to validate a stored token and hydrate the auth controller.
  Future<({AuthUser user, AuthCounts counts})> me() async {
    final res = await _dio.get<Map<String, dynamic>>(ApiEndpoints.me);
    final body = res.data!;
    return (
      user: AuthUser.fromJson(body['user'] as Map<String, dynamic>),
      counts: body['counts'] is Map<String, dynamic>
          ? AuthCounts.fromJson(body['counts'] as Map<String, dynamic>)
          : AuthCounts.empty,
    );
  }

  /// `POST /api/v1/auth/password/` — rotates the password. Returns a fresh
  /// bearer token; every other token belonging to this user is revoked
  /// server-side, so other devices will get a 401 on their next call.
  Future<String> changePassword({
    required String oldPassword,
    required String newPassword,
  }) async {
    final res = await _dio.post<Map<String, dynamic>>(
      ApiEndpoints.changePassword,
      data: {'old_password': oldPassword, 'new_password': newPassword},
    );
    return res.data!['token'] as String;
  }

  static AuthSession _sessionFrom(Map<String, dynamic> body) {
    return AuthSession(
      token: body['token'] as String,
      user: AuthUser.fromJson(body['user'] as Map<String, dynamic>),
    );
  }
}

