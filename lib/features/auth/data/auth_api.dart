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

  // ── Email-OTP signup (Gap D) ─────────────────────────────────────────
  //
  // The server keys the OTP flow by EMAIL (the `start` calls return only
  // `{ ok, resend_in }` — no flow token), so every step carries the email.

  /// Step 1: `POST /signup/start/ { email }` → sends a 6-digit code.
  Future<void> signupStart({required String email}) async {
    await _dio.post<Map<String, dynamic>>(
      ApiEndpoints.signupStart,
      data: {'email': email},
      options: Options(extra: _skipAuth),
    );
  }

  /// Step 2: `POST /signup/verify/ { email, code }` — confirms the emailed
  /// code and returns a short-lived verification token the *complete* step
  /// must echo back (the reset branch confirmed this shape:
  /// `{ ok, reset_token, ttl_seconds }`). Returns `null` if the server
  /// doesn't issue one (then complete falls back to email).
  Future<String?> signupVerify({
    required String email,
    required String code,
  }) async {
    final res = await _dio.post<Map<String, dynamic>>(
      ApiEndpoints.signupVerify,
      data: {'email': email, 'code': code},
      options: Options(extra: _skipAuth),
    );
    final d = res.data ?? const {};
    return (d['signup_token'] ?? d['token']) as String?;
  }

  /// Re-send the signup code. `POST /signup/resend/ { email }`.
  Future<void> signupResend({required String email}) async {
    await _dio.post<Map<String, dynamic>>(
      ApiEndpoints.signupResend,
      data: {'email': email},
      options: Options(extra: _skipAuth),
    );
  }

  /// Step 3: `POST /signup/complete/ { email, password, first_name?,
  /// last_name? }` → `{ token, user }`. Returns the session, same shape as
  /// login.
  Future<AuthSession?> signupComplete({
    required String email,
    required String password,
    String? signupToken,
    String? firstName,
    String? lastName,
  }) async {
    final body = <String, dynamic>{
      'email': email,
      if (signupToken != null && signupToken.isNotEmpty)
        'signup_token': signupToken,
      'password': password,
      if (firstName != null && firstName.isNotEmpty) 'first_name': firstName,
      if (lastName != null && lastName.isNotEmpty) 'last_name': lastName,
    };
    final res = await _dio.post<Map<String, dynamic>>(
      ApiEndpoints.signupComplete,
      data: body,
      options: Options(extra: _skipAuth),
    );
    return _sessionOrNull(res.data ?? const {});
  }

  // ── Passwordless email login (Gap D) ─────────────────────────────────

  /// `POST /login/email/start/ { email }` → sends a code. Response is just
  /// `{ ok, resend_in }`.
  Future<void> loginEmailStart({required String email}) async {
    await _dio.post<Map<String, dynamic>>(
      ApiEndpoints.loginEmailStart,
      data: {'email': email},
      options: Options(extra: _skipAuth),
    );
  }

  /// `POST /login/email/verify/ { email, code }` → `{ token, user }`.
  Future<AuthSession> loginEmailVerify({
    required String email,
    required String code,
  }) async {
    final res = await _dio.post<Map<String, dynamic>>(
      ApiEndpoints.loginEmailVerify,
      data: {'email': email, 'code': code},
      options: Options(extra: _skipAuth),
    );
    return _sessionFrom(res.data!);
  }

  /// Re-send the login code. `POST /login/email/resend/ { email }`.
  Future<void> loginEmailResend({required String email}) async {
    await _dio.post<Map<String, dynamic>>(
      ApiEndpoints.loginEmailResend,
      data: {'email': email},
      options: Options(extra: _skipAuth),
    );
  }

  // ── Password reset (Gap D) ───────────────────────────────────────────

  /// `POST /password/reset/start/ { email }` → sends a code. The server
  /// returns 200 even for unknown emails (no account enumeration) — the UI
  /// advances to the code step regardless.
  Future<void> passwordResetStart({required String email}) async {
    await _dio.post<Map<String, dynamic>>(
      ApiEndpoints.passwordResetStart,
      data: {'email': email},
      options: Options(extra: _skipAuth),
    );
  }

  /// `POST /password/reset/verify/ { email, code }` → confirms the code and
  /// returns a short-lived `reset_token` (TTL ~10 min) that the *complete*
  /// step must send back.
  Future<String> passwordResetVerify({
    required String email,
    required String code,
  }) async {
    final res = await _dio.post<Map<String, dynamic>>(
      ApiEndpoints.passwordResetVerify,
      data: {'email': email, 'code': code},
      options: Options(extra: _skipAuth),
    );
    final d = res.data ?? const {};
    return (d['reset_token'] ?? d['token']) as String;
  }

  /// Re-send the reset code. `POST /password/reset/resend/ { email }`.
  Future<void> passwordResetResend({required String email}) async {
    await _dio.post<Map<String, dynamic>>(
      ApiEndpoints.passwordResetResend,
      data: {'email': email},
      options: Options(extra: _skipAuth),
    );
  }

  /// `POST /password/reset/complete/ { reset_token, new_password }` → fresh
  /// `{ token, user }`. The `reset_token` is the one minted by
  /// [passwordResetVerify]; the password field is **`new_password`** (not
  /// `password`) — sending `password` makes the server read an empty
  /// `new_password` and reject it as too short.
  Future<AuthSession?> passwordResetComplete({
    required String resetToken,
    required String password,
  }) async {
    final res = await _dio.post<Map<String, dynamic>>(
      ApiEndpoints.passwordResetComplete,
      data: {'reset_token': resetToken, 'new_password': password},
      options: Options(extra: _skipAuth),
    );
    return _sessionOrNull(res.data ?? const {});
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

  /// `PATCH /api/v1/auth/me/ { first_name?, last_name? }` (Gap I) — updates
  /// the display name. Email/username stay read-only. Only the keys you send
  /// change. Returns the refreshed user + counts, same shape as [me].
  Future<({AuthUser user, AuthCounts counts})> updateProfile({
    String? firstName,
    String? lastName,
  }) async {
    final body = <String, dynamic>{
      if (firstName != null) 'first_name': firstName,
      if (lastName != null) 'last_name': lastName,
    };
    final res = await _dio.patch<Map<String, dynamic>>(
      ApiEndpoints.me,
      data: body,
    );
    final data = res.data!;
    return (
      user: AuthUser.fromJson(data['user'] as Map<String, dynamic>),
      counts: data['counts'] is Map<String, dynamic>
          ? AuthCounts.fromJson(data['counts'] as Map<String, dynamic>)
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

  /// Like [_sessionFrom] but returns `null` when the response carries no
  /// token — some endpoints (e.g. `password/reset/complete/`) return just
  /// `{ ok: true }` and expect the caller to sign in afterwards.
  static AuthSession? _sessionOrNull(Map<String, dynamic> body) {
    final token = body['token'];
    final user = body['user'];
    if (token is! String || token.isEmpty || user is! Map<String, dynamic>) {
      return null;
    }
    return AuthSession(token: token, user: AuthUser.fromJson(user));
  }
}

