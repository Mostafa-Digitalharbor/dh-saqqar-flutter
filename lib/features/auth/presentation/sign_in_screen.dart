import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/ui_strings.dart';
import '../../../core/routing/route_names.dart';
import '../../../shared/widgets/ambient_background.dart';
import '../widgets/widgets.dart';

/// Sign-in screen. On wide viewports a left brand panel sits next to the
/// form card; on phones the form is centered with a compact brand lockup.
class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final _username = TextEditingController(text: UiStrings.demoUsername);
  final _password = TextEditingController(text: UiStrings.demoUsername);
  bool _loading = false;

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _loading = true);
    await Future<void>.delayed(const Duration(milliseconds: 450));
    if (!mounted) return;
    setState(() => _loading = false);
    if (!mounted) return;
    context.go(RouteNames.chatsPath);
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
                          child: SignInForm(
                            wide: wide,
                            loading: _loading,
                            username: _username,
                            password: _password,
                            onSubmit: _submit,
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
