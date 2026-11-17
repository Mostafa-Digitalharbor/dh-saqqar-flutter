import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/storage/secure_token_store.dart';
import '../data/auth_api.dart';
import '../data/auth_models.dart';
import 'auth_state.dart';

/// ViewModel for the auth surface. Owns the bearer-token lifecycle:
/// bootstrap on cold start, login, register, change-password, logout.
///
/// Wired in `main.dart` as an app-level `BlocProvider<AuthCubit>` so the
/// router gate (`BlocListener<AuthCubit, AuthState>` inside the GoRouter
/// `refreshListenable`) can react to status changes from anywhere.
class AuthCubit extends Cubit<AuthState> {
  AuthCubit({required AuthApi api, required SecureTokenStore tokenStore})
    : _api = api,
      _store = tokenStore,
      super(const AuthState());

  final AuthApi _api;
  final SecureTokenStore _store;

  /// Drop any [emit] call that lands after [close] has run. AuthCubit
  /// is app-lifetime so it rarely closes in practice, but bootstrap /
  /// login / register all do network round-trips — if the user
  /// background-then-force-kills mid-call the resolved future would
  /// otherwise crash on `emit`. Matches the guard pattern documented
  /// in [ChatCubit.emit] and applied to the other async cubits.
  @override
  void emit(AuthState state) {
    if (isClosed) return;
    super.emit(state);
  }

  // ── Bootstrap ───────────────────────────────────────────────────────

  /// Reads any persisted bearer token and validates it via `GET /me/`.
  /// Called once from `main.dart` after the in-app splash mounts, then
  /// the splash awaits this future before handing off to the router so
  /// the gate sees a resolved status (not [AuthStatus.initial]).
  ///
  /// Important: only an **explicit 401** (token rejected by the server)
  /// transitions us to unauthenticated. Network blips, timeouts, and
  /// 5xx errors keep the user signed in — we trust the stored token
  /// until the server itself tells us it's bad. The Account screen's
  /// pull-to-refresh re-fetches identity once the network's back.
  Future<void> bootstrap() async {
    emit(state.copyWith(status: AuthStatus.loading, clearFailure: true));
    final token = await _store.readAccessToken();
    if (token == null || token.isEmpty) {
      emit(state.copyWith(status: AuthStatus.unauthenticated, clearUser: true));
      return;
    }
    try {
      final me = await _api.me();
      emit(
        state.copyWith(
          status: AuthStatus.authenticated,
          user: me.user,
          counts: me.counts,
        ),
      );
    } on ApiException catch (e) {
      if (e.isUnauthorized) {
        // Server rejected the token → real session-ended state.
        await _store.clear();
        emit(
          state.copyWith(status: AuthStatus.unauthenticated, clearUser: true),
        );
      } else {
        // Network / 500 / timeout — keep the user signed in with
        // whatever data we already had (none on cold start). Don't
        // clear the token; the next request will retry.
        emit(state.copyWith(status: AuthStatus.authenticated, failure: e));
      }
    } catch (e) {
      // Unknown error (not even an ApiException) — same policy: stay
      // authenticated so the user isn't kicked out by a transient
      // failure we can't classify.
      emit(state.copyWith(status: AuthStatus.authenticated, failure: e));
    }
  }

  // ── Actions ─────────────────────────────────────────────────────────

  /// Sign-in flow. Persists the returned token, then sets state to
  /// authenticated. Re-throws [ApiException] so the screen can render
  /// field errors / toasts (state's `failure` carries the same).
  Future<void> login({required String email, required String password}) async {
    emit(state.copyWith(status: AuthStatus.loading, clearFailure: true));
    try {
      final session = await _api.login(email: email, password: password);
      await _store.writeAccessToken(session.token);
      final counts = await _safeCounts();
      emit(
        state.copyWith(
          status: AuthStatus.authenticated,
          user: session.user,
          counts: counts,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          status: AuthStatus.unauthenticated,
          failure: e,
          clearUser: true,
        ),
      );
      rethrow;
    }
  }

  /// Sign-up flow (register returns a session — same shape as [login]).
  /// 409 surfaces as ApiException with statusCode == 409.
  Future<void> register({
    required String email,
    required String password,
    String? username,
  }) async {
    emit(state.copyWith(status: AuthStatus.loading, clearFailure: true));
    try {
      final session = await _api.register(
        email: email,
        password: password,
        username: username,
      );
      await _store.writeAccessToken(session.token);
      final counts = await _safeCounts();
      emit(
        state.copyWith(
          status: AuthStatus.authenticated,
          user: session.user,
          counts: counts,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          status: AuthStatus.unauthenticated,
          failure: e,
          clearUser: true,
        ),
      );
      rethrow;
    }
  }

  /// Adopt a session minted by the email-OTP flow (signup complete, email
  /// login verify, or password-reset complete). Persists the bearer token
  /// and flips to authenticated — the router gate then routes to /chats.
  /// Mirrors the tail of [login] without re-hitting a password endpoint.
  Future<void> adoptSession(AuthSession session) async {
    await _store.writeAccessToken(session.token);
    final counts = await _safeCounts();
    emit(
      state.copyWith(
        status: AuthStatus.authenticated,
        user: session.user,
        counts: counts,
      ),
    );
  }

  /// Best-effort POST to /logout/ then clear local state. The server call
  /// is fire-and-forget for UX — if it fails (offline, server down), we
  /// still want the device signed out locally.
  Future<void> logout() async {
    try {
      await _api.logout();
    } catch (_) {
      // Swallow — local clear is the source of truth for "signed out".
    } finally {
      await _store.clear();
      emit(const AuthState(status: AuthStatus.unauthenticated));
    }
  }

  /// Irreversibly deletes the account (App/Play Store requirement), then
  /// clears local state and flips to unauthenticated — same teardown as
  /// [logout]. Unlike logout, the server call must SUCCEED before we wipe
  /// anything: if it throws (offline, server error) we re-throw and keep
  /// the user signed in so the confirm sheet can surface the failure —
  /// silently "signing out" would wrongly imply the account was deleted.
  Future<void> deleteAccount() async {
    await _api.deleteAccount();
    await _store.clear();
    emit(const AuthState(status: AuthStatus.unauthenticated));
  }

  /// Update the user's display name (Gap I). Patches `/auth/me/` and swaps
  /// the refreshed user into state so the hero + chat header update live.
  /// Re-throws so the form can surface validation errors.
  Future<void> updateProfile({String? firstName, String? lastName}) async {
    final me = await _api.updateProfile(
      firstName: firstName,
      lastName: lastName,
    );
    emit(state.copyWith(user: me.user, counts: me.counts));
  }

  /// Rotates the password and stores the fresh token. The current device
  /// stays signed in; every other device gets 401 on its next call.
  Future<void> changePassword({
    required String oldPassword,
    required String newPassword,
  }) async {
    final token = await _api.changePassword(
      oldPassword: oldPassword,
      newPassword: newPassword,
    );
    await _store.writeAccessToken(token);
    // No state change needed — user object unchanged, the bearer token
    // is read from the store on every request by [AuthInterceptor].
  }

  /// Invoked by [AuthInterceptor] when a request returns 401. Drops the
  /// local token and flips status so the router gate redirects on the
  /// next frame.
  Future<void> handleUnauthorized() async {
    await _store.clear();
    if (state.isAuthenticated) {
      emit(const AuthState(status: AuthStatus.unauthenticated));
    }
  }

  Future<AuthCounts> _safeCounts() async {
    try {
      final me = await _api.me();
      return me.counts;
    } catch (_) {
      return AuthCounts.empty;
    }
  }
}
