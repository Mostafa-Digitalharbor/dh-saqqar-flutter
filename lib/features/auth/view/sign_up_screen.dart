import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/error/app_failure.dart';
import '../../../core/i18n/app_localizations.dart';
import '../../../core/network/api_error_mapper.dart';
import '../../../core/routing/route_names.dart';
import '../../../shared/widgets/ambient_background.dart';
import '../../../shared/widgets/app_toast.dart';
import '../view_model/auth_cubit.dart';
import '../view_model/auth_state.dart';
import '../widgets/widgets.dart';

/// Sign-up screen (MVVM view). Mirror of [SignInScreen] — submits via
/// `context.read<AuthCubit>().register(...)`. 409 (email already in use)
/// lands inline under the email field.
class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  // Email + password are all we collect — username was removed from the
  // form on user request. Django auto-derives a `User.username` from the
  // email server-side, and the account screen shows whatever comes back
  // from /auth/me/.
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirmPassword = TextEditingController();

  String? _emailError;
  String? _passwordError;
  String? _confirmError;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _confirmPassword.dispose();
    super.dispose();
  }

  bool _validate() {
    final tr = context.tr;
    final email = _email.text.trim();
    String? emailErr;
    if (email.isEmpty) {
      emailErr = tr.emailRequired;
    } else if (!email.contains('@') || !email.contains('.')) {
      emailErr = tr.emailInvalid;
    }
    setState(() {
      _emailError = emailErr;
      _passwordError = _password.text.length < 8 ? tr.passwordTooShort : null;
      _confirmError = _confirmPassword.text != _password.text
          ? tr.passwordsDoNotMatch
          : null;
    });
    return emailErr == null &&
        _passwordError == null &&
        _confirmError == null;
  }

  Future<void> _submit() async {
    if (!_validate()) return;
    final cubit = context.read<AuthCubit>();
    try {
      await cubit.register(
        email: _email.text.trim(),
        password: _password.text,
      );
      if (!mounted) return;
      AppToast.show(
        context,
        message: context.tr.accountCreatedToast,
        variant: ToastVariant.success,
      );
    } catch (e) {
      if (!mounted) return;
      _surfaceAuthError(e);
    }
  }

  /// Routes any thrown error through the typed [AppFailure] pipeline so
  /// the user-facing message is always localized. Two screen-specific
  /// overrides on top of the generic mapper:
  ///   * [ConflictFailure] (409) → inline email error with the
  ///     auth-specific wording ("That email is already in use").
  ///   * [ValidationFailure] (400) → per-field errors landed on the
  ///     matching input; otherwise falls through to a toast.
  void _surfaceAuthError(Object error) {
    final failure = ApiErrorMapper.toFailure(error);
    final tr = context.tr;
    if (failure is ConflictFailure) {
      setState(() => _emailError = tr.authEmailTaken);
      return;
    }
    if (failure is ValidationFailure) {
      final emailErr = failure.firstError('email');
      final pwErr = failure.firstError('password');
      setState(() {
        if (emailErr != null) _emailError = emailErr;
        if (pwErr != null) _passwordError = pwErr;
      });
      if (emailErr != null || pwErr != null) return;
    }
    AppToast.show(
      context,
      message: ApiErrorMapper.message(context, failure),
      variant: ToastVariant.error,
    );
  }

  void _backToSignIn() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(RouteNames.signInPath);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AmbientBackground(
        withBlobs: true,
        child: SafeArea(
          child: BlocBuilder<AuthCubit, AuthState>(
            buildWhen: (a, b) => a.isLoading != b.isLoading,
            builder: (context, authState) {
              final loading = authState.isLoading;
              return LayoutBuilder(
                builder: (context, constraints) {
                  final wide = constraints.maxWidth >= 900;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const AuthHeaderActions(),
                      Expanded(
                        child: Row(
                          children: [
                            if (wide)
                              Expanded(
                                child: BrandPanel(
                                  onStart: loading ? () {} : _submit,
                                ),
                              ),
                            Expanded(
                              child: Center(
                                child: SingleChildScrollView(
                                  padding: const EdgeInsets.all(24),
                                  child: ConstrainedBox(
                                    constraints:
                                        const BoxConstraints(maxWidth: 440),
                                    child: SignUpForm(
                                      wide: wide,
                                      loading: loading,
                                      email: _email,
                                      password: _password,
                                      confirmPassword: _confirmPassword,
                                      emailError: _emailError,
                                      passwordError: _passwordError,
                                      confirmError: _confirmError,
                                      onSubmit: _submit,
                                      onBackToSignIn: _backToSignIn,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}
