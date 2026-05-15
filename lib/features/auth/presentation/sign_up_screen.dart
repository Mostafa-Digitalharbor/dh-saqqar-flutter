import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/i18n/app_localizations.dart';
import '../../../core/routing/route_names.dart';
import '../../../shared/widgets/ambient_background.dart';
import '../../../shared/widgets/app_toast.dart';
import '../widgets/widgets.dart';

/// Mirror of [SignInScreen] for new accounts. Wide viewports keep the brand
/// panel on the left; phones get the form centered with a compact lockup.
///
/// Validation is client-side only today — server-side errors will be surfaced
/// once the auth controller is wired in Sprint 2.
class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _username = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirmPassword = TextEditingController();

  bool _loading = false;
  String? _usernameError;
  String? _passwordError;
  String? _confirmError;

  @override
  void dispose() {
    _username.dispose();
    _email.dispose();
    _password.dispose();
    _confirmPassword.dispose();
    super.dispose();
  }

  bool _validate() {
    final tr = context.tr;
    setState(() {
      _usernameError = _username.text.trim().isEmpty ? tr.usernameRequired : null;
      _passwordError = _password.text.length < 8 ? tr.passwordTooShort : null;
      _confirmError = _confirmPassword.text != _password.text
          ? tr.passwordsDoNotMatch
          : null;
    });
    return _usernameError == null &&
        _passwordError == null &&
        _confirmError == null;
  }

  Future<void> _submit() async {
    if (!_validate()) return;

    setState(() => _loading = true);
    await Future<void>.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;

    setState(() => _loading = false);
    AppToast.show(
      context,
      message: context.tr.accountCreatedToast,
      variant: ToastVariant.success,
    );

    if (!mounted) return;
    context.go(RouteNames.chatsPath);
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
          child: LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 900;
              return Row(
                children: [
                  if (wide)
                    Expanded(
                      child: BrandPanel(
                        onStart: () => context.go(RouteNames.chatsPath),
                      ),
                    ),
                  Expanded(
                    child: Center(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(24),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 440),
                          child: SignUpForm(
                            wide: wide,
                            loading: _loading,
                            username: _username,
                            email: _email,
                            password: _password,
                            confirmPassword: _confirmPassword,
                            usernameError: _usernameError,
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
              );
            },
          ),
        ),
      ),
    );
  }
}
