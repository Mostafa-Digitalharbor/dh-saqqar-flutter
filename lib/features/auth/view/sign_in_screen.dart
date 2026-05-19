import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/error/app_failure.dart';
import '../../../core/i18n/app_localizations.dart';
import '../../../core/network/api_error_mapper.dart';
import '../../../shared/widgets/ambient_background.dart';
import '../../../shared/widgets/app_toast.dart';
import '../view_model/auth_cubit.dart';
import '../view_model/auth_state.dart';
import '../widgets/widgets.dart';

/// Sign-in screen (MVVM view). Reads loading state via `BlocBuilder` and
/// fires `context.read<AuthCubit>().login(...)` on submit. On success the
/// router's auth gate (`BlocListener` inside `app_router.dart`) bounces
/// the user into /chats — no explicit navigation here.
class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  String? _emailError;
  String? _passwordError;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  /// Temporary client-side bypass: the shared demo account
  /// `test / test` skips the email-format check so the company team
  /// can sign in with the test creds without the validator rejecting
  /// `"test"` for missing `@`/`.`. The server still authenticates
  /// normally — this only relaxes the local format guard. Remove once
  /// the demo account is retired.
  static const _demoUsername = 'test';
  static const _demoPassword = 'test';

  bool _validate() {
    final tr = context.tr;
    final email = _email.text.trim();
    final password = _password.text;

    final isDemoLogin = email == _demoUsername && password == _demoPassword;

    String? emailErr;
    if (email.isEmpty) {
      emailErr = tr.emailRequired;
    } else if (!isDemoLogin &&
        (!email.contains('@') || !email.contains('.'))) {
      emailErr = tr.emailInvalid;
    }
    final pwErr = password.isEmpty ? tr.passwordTooShort : null;
    setState(() {
      _emailError = emailErr;
      _passwordError = pwErr;
    });
    return emailErr == null && pwErr == null;
  }

  Future<void> _submit() async {
    if (!_validate()) return;
    final cubit = context.read<AuthCubit>();
    try {
      await cubit.login(email: _email.text.trim(), password: _password.text);
      if (!mounted) return;
      AppToast.show(
        context,
        message: context.tr.signedInToast,
        variant: ToastVariant.success,
      );
    } catch (e) {
      if (!mounted) return;
      _surfaceAuthError(e);
    }
  }

  /// Routes any thrown error through the typed [AppFailure] pipeline so
  /// the user-facing message is always localized — even for failure
  /// categories the screen doesn't handle specifically.
  ///
  /// Two screen-specific overrides on top of the generic mapper:
  ///   * [UnauthorizedFailure] (401) → inline password error with the
  ///     auth-specific wording ("Invalid email or password") instead of
  ///     the generic "Your session ended" — the user is TRYING to sign
  ///     in, they haven't been signed out.
  ///   * [ValidationFailure] (400) → per-field errors landed on the
  ///     matching input. Anything that doesn't map to email/password
  ///     falls back to a toast.
  void _surfaceAuthError(Object error) {
    final failure = ApiErrorMapper.toFailure(error);
    final tr = context.tr;
    if (failure is UnauthorizedFailure) {
      setState(() => _passwordError = tr.authInvalidCredentials);
      return;
    }
    if (failure is ValidationFailure) {
      final emailErr = failure.firstError('email');
      final passwordErr = failure.firstError('password');
      setState(() {
        if (emailErr != null) _emailError = emailErr;
        if (passwordErr != null) _passwordError = passwordErr;
      });
      if (emailErr != null || passwordErr != null) return;
      // No matched field — fall through to a toast with the generic
      // validation message.
    }
    AppToast.show(
      context,
      message: ApiErrorMapper.message(context, failure),
      variant: ToastVariant.error,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AmbientBackground(
        withBlobs: true,
        child: SafeArea(
          child: BlocBuilder<AuthCubit, AuthState>(
            // Only rebuild when loading flips — the rest of the form holds
            // its own local state (text controllers, field errors).
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
                                    child: SignInForm(
                                      wide: wide,
                                      loading: loading,
                                      username: _email,
                                      password: _password,
                                      usernameError: _emailError,
                                      passwordError: _passwordError,
                                      onSubmit: _submit,
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
