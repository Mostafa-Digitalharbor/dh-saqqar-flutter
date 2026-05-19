import 'package:equatable/equatable.dart';

import '../data/auth_models.dart';

/// Lifecycle stage of the auth session. Distinct from "is the user
/// authenticated" because the very first frame is `initial` (controller
/// hasn't bootstrapped yet) — the router needs to wait for that frame to
/// pass before deciding whether to redirect to /sign-in.
enum AuthStatus {
  /// Bootstrap hasn't run yet — the launch splash is still on screen.
  initial,

  /// `me()` round-trip in flight (cold start or post-login refresh).
  loading,

  /// Valid bearer token + a hydrated [user]. Router gate allows protected
  /// routes.
  authenticated,

  /// No token, or the stored one failed `/me/` validation. Router gate
  /// redirects to /sign-in.
  unauthenticated,
}

/// Immutable snapshot owned by [AuthCubit]. Emitted on every state change;
/// views rebuild via `BlocBuilder<AuthCubit, AuthState>`.
class AuthState extends Equatable {
  const AuthState({
    this.status = AuthStatus.initial,
    this.user,
    this.counts = AuthCounts.empty,
    this.failure,
  });

  final AuthStatus status;
  final AuthUser? user;
  final AuthCounts counts;

  /// Set when the most recent action (login / register / changePassword)
  /// failed. Views read this to render inline errors / toasts. Cleared on
  /// the next successful action.
  final Object? failure;

  bool get isAuthenticated => status == AuthStatus.authenticated;
  bool get isLoading => status == AuthStatus.loading;
  bool get isResolved =>
      status == AuthStatus.authenticated ||
      status == AuthStatus.unauthenticated;

  AuthState copyWith({
    AuthStatus? status,
    AuthUser? user,
    AuthCounts? counts,
    Object? failure,
    bool clearUser = false,
    bool clearFailure = false,
  }) {
    return AuthState(
      status: status ?? this.status,
      user: clearUser ? null : (user ?? this.user),
      counts: counts ?? this.counts,
      failure: clearFailure ? null : (failure ?? this.failure),
    );
  }

  @override
  List<Object?> get props => [status, user, counts, failure];
}
