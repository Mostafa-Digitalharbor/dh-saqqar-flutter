import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/error/app_failure.dart';
import '../../../core/logging/app_logger.dart';
import '../../../core/network/api_error_mapper.dart';
import '../data/auth_api.dart';
import '../data/auth_models.dart';
import '../data/social_auth_service.dart';
import 'auth_cubit.dart';

/// The nine screens of the email-OTP auth flow (Gap D). One cubit drives a
/// single screen that swaps its body per [AuthFlowStep], matching the web's
/// step-by-step auth.
enum AuthFlowStep {
  // Sign-up branch
  signUpEmail,
  signUpOtp,
  signUpProfile,
  // Sign-in branch
  signInEmail,
  signInOtp,
  signInPassword,
  // Password-reset branch
  resetEmail,
  resetOtp,
  resetNewPassword,
}

class AuthFlowState extends Equatable {
  const AuthFlowState({
    required this.step,
    this.email = '',
    this.token = '',
    this.loading = false,
    this.failure,
    this.noticeKey,
  });

  final AuthFlowStep step;

  /// Email carried across steps. `start` is keyed by email (it returns only
  /// `{ ok, resend_in }`); the short-lived [token] below is what `verify`
  /// mints and `complete` consumes.
  final String email;

  /// Short-lived verification token issued by the *verify* step
  /// (`reset_token` / `signup_token`) and required by the *complete* step.
  /// Empty until verify runs (or when the server issues none).
  final String token;

  final bool loading;

  /// Last error (raw — the view localizes via ApiErrorMapper). Cleared on
  /// each new action.
  final Object? failure;

  /// i18n key for a one-shot success notice (e.g. "password set — sign in").
  /// The view shows it as a success toast and it's cleared on the next action.
  final String? noticeKey;

  bool get isOtpStep =>
      step == AuthFlowStep.signUpOtp ||
      step == AuthFlowStep.signInOtp ||
      step == AuthFlowStep.resetOtp;

  AuthFlowState copyWith({
    AuthFlowStep? step,
    String? email,
    String? token,
    bool? loading,
    Object? failure,
    String? noticeKey,
    bool clearFailure = false,
    bool clearNotice = false,
  }) {
    return AuthFlowState(
      step: step ?? this.step,
      email: email ?? this.email,
      token: token ?? this.token,
      loading: loading ?? this.loading,
      failure: clearFailure ? null : (failure ?? this.failure),
      noticeKey: clearNotice ? null : (noticeKey ?? this.noticeKey),
    );
  }

  @override
  List<Object?> get props => [step, email, token, loading, failure, noticeKey];
}

/// Drives the multi-step email-OTP auth flow. On any terminal success it
/// hands the minted [AuthSession] to [AuthCubit.adoptSession], which flips
/// the app to authenticated and lets the router gate route to /chats.
class AuthFlowCubit extends Cubit<AuthFlowState> {
  AuthFlowCubit({
    required AuthApi api,
    required AuthCubit authCubit,
    required SocialAuthService socialAuth,
    required AuthFlowStep initial,
  })  : _api = api,
        _auth = authCubit,
        _social = socialAuth,
        super(AuthFlowState(step: initial));

  final AuthApi _api;
  final AuthCubit _auth;
  final SocialAuthService _social;

  @override
  void emit(AuthFlowState state) {
    if (isClosed) return;
    super.emit(state);
  }

  // ── Navigation between steps (no network) ────────────────────────────

  void goTo(AuthFlowStep step) =>
      emit(state.copyWith(step: step, clearFailure: true));

  /// Carry the typed email across a no-network step switch (e.g. "Continue
  /// with password" or "Forgot password?") so the next screen prefills it.
  void rememberEmail(String email) {
    if (email.trim() == state.email) return;
    emit(state.copyWith(email: email.trim()));
  }

  void toSignUp() => emit(state.copyWith(
        step: AuthFlowStep.signUpEmail,
        clearFailure: true,
      ));

  void toSignIn() => emit(state.copyWith(
        step: AuthFlowStep.signInEmail,
        clearFailure: true,
      ));

  // ── Sign-up branch ───────────────────────────────────────────────────

  Future<void> submitSignUpEmail(String email) async {
    await _run(() async {
      await _api.signupStart(email: email);
      emit(state.copyWith(
        email: email,
        step: AuthFlowStep.signUpOtp,
        loading: false,
      ));
    });
  }

  Future<void> verifySignUpOtp(String code) async {
    await _run(() async {
      final token = await _api.signupVerify(email: state.email, code: code);
      emit(state.copyWith(
        token: token ?? '',
        step: AuthFlowStep.signUpProfile,
        loading: false,
      ));
    });
  }

  Future<void> completeSignUp({
    required String firstName,
    required String lastName,
    required String password,
  }) async {
    await _run(() async {
      final session = await _api.signupComplete(
        email: state.email,
        signupToken: state.token.isEmpty ? null : state.token,
        password: password,
        firstName: firstName,
        lastName: lastName,
      );
      await _adoptOrSignIn(session, password);
    });
  }

  // ── Sign-in branch ───────────────────────────────────────────────────

  Future<void> submitSignInEmail(String email) async {
    await _run(() async {
      await _api.loginEmailStart(email: email);
      emit(state.copyWith(
        email: email,
        step: AuthFlowStep.signInOtp,
        loading: false,
      ));
    });
  }

  Future<void> verifySignInOtp(String code) async {
    await _run(() async {
      final session =
          await _api.loginEmailVerify(email: state.email, code: code);
      await _auth.adoptSession(session);
    });
  }

  Future<void> submitPasswordLogin({
    required String email,
    required String password,
  }) async {
    await _run(() async {
      final session = await _api.login(email: email, password: password);
      await _auth.adoptSession(session);
    });
  }

  // ── Social sign-in (Google / Apple) ──────────────────────────────────

  /// Runs the native Google picker, exchanges the ID token for a Saqqar
  /// bearer, and adopts the session. A user cancel is a no-op (drop loading,
  /// no error toast); real failures surface via [_run]'s catch.
  Future<void> continueWithGoogle() async {
    await _run(() async {
      final result = await _social.signInWithGoogle();
      if (result == null) {
        emit(state.copyWith(loading: false));
        return;
      }
      final session = await _api.loginWithGoogle(idToken: result.idToken);
      await _auth.adoptSession(session);
    });
  }

  /// Native Sign in with Apple (iOS). Passes the name through on the first
  /// sign-in (Apple omits it afterwards). Cancel is a no-op like Google.
  Future<void> continueWithApple() async {
    await _run(() async {
      AppLogger.info('AppleSignIn', '▶ START — user tapped "Continue with Apple"');
      final result = await _social.signInWithApple();
      if (result == null) {
        AppLogger.info('AppleSignIn', '⊘ canceled before token — nothing to do');
        emit(state.copyWith(loading: false));
        return;
      }
      AppLogger.info(
        'AppleSignIn',
        '⑥ exchanging Apple token for a Saqqar session…',
      );
      final session = await _api.loginWithApple(
        idToken: result.idToken,
        firstName: result.firstName,
        lastName: result.lastName,
      );
      await _auth.adoptSession(session);
      AppLogger.info('AppleSignIn', '✓ DONE — signed in, session adopted 🎉');
    });
  }

  // ── Password-reset branch ────────────────────────────────────────────

  Future<void> submitResetEmail(String email) async {
    await _run(() async {
      await _api.passwordResetStart(email: email);
      emit(state.copyWith(
        email: email,
        step: AuthFlowStep.resetOtp,
        loading: false,
      ));
    });
  }

  Future<void> verifyResetOtp(String code) async {
    await _run(() async {
      final token =
          await _api.passwordResetVerify(email: state.email, code: code);
      // Keep the minted reset_token for the final complete call.
      emit(state.copyWith(
        token: token,
        step: AuthFlowStep.resetNewPassword,
        loading: false,
      ));
    });
  }

  Future<void> completeReset(String password) async {
    await _run(() async {
      final session = await _api.passwordResetComplete(
        resetToken: state.token,
        password: password,
      );
      await _adoptOrSignIn(session, password);
    });
  }

  /// Finish a signup/reset completion. If the server returned a session,
  /// adopt it and we're in. Otherwise (e.g. reset/complete returns just
  /// `{ ok: true }`), auto-login with the just-set password; if THAT fails
  /// (the password login endpoint matches by username, not email), drop the
  /// user on the password screen with a success notice so they can sign in.
  Future<void> _adoptOrSignIn(AuthSession? session, String password) async {
    if (session != null) {
      await _auth.adoptSession(session);
      return;
    }
    try {
      final s = await _api.login(email: state.email, password: password);
      await _auth.adoptSession(s);
    } catch (e) {
      // The password IS set by now — `complete` already succeeded — so the
      // success notice is true, and a failed AUTO-login is the expected
      // case: the password login endpoint matches by username, not email.
      //
      // But `catch (_)` couldn't tell that apart from the connection dying
      // between the two calls, or `login` itself returning a 5xx. In those,
      // "Password set — sign in" is technically true and practically
      // useless: it sends the user into a sign-in the app already knows
      // will fail, with no hint why. Show the notice AND the reason.
      final failure = ApiErrorMapper.toFailure(e);
      final isTransport = failure is NetworkFailure ||
          failure is TimeoutFailure ||
          failure is ServerFailure;
      emit(state.copyWith(
        step: AuthFlowStep.signInPassword,
        loading: false,
        noticeKey: 'auth_password_set',
        failure: isTransport ? e : null,
        clearFailure: !isTransport,
      ));
    }
  }

  // ── Resend (no step change) ──────────────────────────────────────────

  /// Re-send the code for whichever OTP step is active. Errors are
  /// swallowed to a failure on state; the countdown is owned by the view.
  Future<void> resend() async {
    try {
      switch (state.step) {
        case AuthFlowStep.signUpOtp:
          await _api.signupResend(email: state.email);
        case AuthFlowStep.signInOtp:
          await _api.loginEmailResend(email: state.email);
        case AuthFlowStep.resetOtp:
          await _api.passwordResetResend(email: state.email);
        default:
          return;
      }
    } catch (e) {
      emit(state.copyWith(failure: e));
    }
  }

  /// Runs [action] with loading on, clearing any prior failure; on throw,
  /// stores the failure and drops loading so the view can surface it.
  Future<void> _run(Future<void> Function() action) async {
    emit(state.copyWith(loading: true, clearFailure: true, clearNotice: true));
    try {
      await action();
    } catch (e) {
      emit(state.copyWith(loading: false, failure: e));
    }
  }
}
