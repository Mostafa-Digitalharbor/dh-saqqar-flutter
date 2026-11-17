part of 'auth_flow_screen.dart';

class _SignInPage extends StatefulWidget {
  const _SignInPage({super.key});

  @override
  State<_SignInPage> createState() => _SignInPageState();
}

class _SignInPageState extends State<_SignInPage> {
  late final TextEditingController _email;
  final _password = TextEditingController();
  String? _emailError;
  String? _passwordError;
  bool _agreed = false;
  String? _agreeError;

  @override
  void initState() {
    super.initState();
    _email = TextEditingController(
      text: context.read<AuthFlowCubit>().state.email,
    );
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _submit() {
    final tr = context.tr;
    final email = _email.text.trim();
    final pwd = _password.text;
    String? eErr;
    String? pErr;
    if (email.isEmpty) {
      eErr = tr.emailRequired;
    } else if (!_looksLikeEmail(email) && email != 'test') {
      eErr = tr.emailInvalid;
    }
    if (pwd.isEmpty) pErr = tr.passwordTooShort;
    setState(() {
      _emailError = eErr;
      _passwordError = pErr;
    });
    if (eErr != null || pErr != null) return;
    context.read<AuthFlowCubit>().submitPasswordLogin(
      email: email,
      password: pwd,
    );
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<AuthFlowCubit>();
    final loading = context.select<AuthFlowCubit, bool>((c) => c.state.loading);
    return AuthFrame(
      pillLabel: context.tr.figSignUp,
      onPill: cubit.toSignUp,
      title: context.tr.figYourBusinessOneAiConversation,
      subtitle: context.tr.figMeetYourAiPoweredCopilotTo,
      titleGap: 25,
      bodyGap: 50,
      children: [
        FigField(
          label: context.tr.figEmail,
          hint: context.tr.figEnterYourEmail,
          controller: _email,
          error: _emailError,
          height: 56,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          autofillHints: const [AutofillHints.email],
        ),
        const SizedBox(height: AppSpacing.s22),
        FigField(
          label: context.tr.figPassword2,
          hint: context.tr.figEnterYourPassword,
          controller: _password,
          error: _passwordError,
          height: 56,
          obscure: true,
          textInputAction: TextInputAction.go,
          onSubmitted: (_) => _submit(),
        ),
        const SizedBox(height: AppSpacing.s10),
        Row(
          children: [
            GestureDetector(
              onTap: () => setState(() {
                _agreed = !_agreed;
                _agreeError = null;
              }),
              child: Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  color: _agreed ? Fig.blue : Colors.transparent,
                  borderRadius: BorderRadius.circular(3),
                  border: Border.all(
                    color: _agreed ? Fig.blue : Fig.muted,
                    width: 1,
                  ),
                ),
                child: _agreed
                    ? const Icon(AppIcons.check, size: 12, color: Colors.white)
                    : null,
              ),
            ),
            const SizedBox(width: AppSpacing.s8),
            Expanded(
              child: Text.rich(
                TextSpan(
                  style: Fig.t(context, size: 10, color: Fig.muted),
                  children: [
                    TextSpan(text: context.tr.figIAgreeToThe),
                    TextSpan(
                      text: context.tr.figTermsPrivacy,
                      style: const TextStyle(
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.s8),
            Flexible(
              child: GestureDetector(
                onTap: () {
                  cubit.rememberEmail(_email.text.trim());
                  cubit.goTo(AuthFlowStep.resetEmail);
                },
                child: Text(
                  context.tr.figForgotPassword,
                  textAlign: TextAlign.end,
                  style: Fig.t(
                    context,
                    size: 12,
                    color: const Color(0xFF2B3A8F),
                    weight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ],
        ),
        if (_agreeError != null)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.s6),
            child: Text(
              _agreeError!,
              style: Fig.t(context, size: 11, color: Fig.dangerText),
            ),
          ),
        const SizedBox(height: 40),
        FigButton(
          label: context.tr.figSignIn,
          loading: loading,
          onPressed: _submit,
          height: 54,
        ),
        const SizedBox(height: 25),
        const _OrDivider(),
        const SizedBox(height: 38),
        const _SocialRow(),
      ],
    );
  }
}

class _OrDivider extends StatelessWidget {
  const _OrDivider();

  @override
  Widget build(BuildContext context) {
    final line = Expanded(
      child: Container(height: 1, color: const Color(0xFFD5DAEA)),
    );
    return Row(
      children: [
        const SizedBox(width: AppSpacing.s16),
        line,
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s10),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              context.tr.figOr,
              style: Fig.t(context, size: 11, color: Fig.muted),
            ),
          ),
        ),
        line,
        const SizedBox(width: AppSpacing.s16),
      ],
    );
  }
}

class _SocialRow extends StatelessWidget {
  const _SocialRow();

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<AuthFlowCubit>();
    final loading = context.select<AuthFlowCubit, bool>((c) => c.state.loading);
    Widget tile(Widget glyph, VoidCallback? onTap) => GestureDetector(
      onTap: loading ? null : onTap,
      child: Container(
        width: 54,
        height: 54,
        decoration: BoxDecoration(
          color: const Color(0xFFE7E8ED),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Center(child: glyph),
      ),
    );
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Apple sign-in is iOS-only (App Store 4.8 pairs it with Google).
        if (defaultTargetPlatform == TargetPlatform.iOS) ...[
          tile(
            Image.asset(AssetPaths.socialApple, width: 28, height: 28),
            cubit.continueWithApple,
          ),
          const SizedBox(width: AppSpacing.s22),
        ],
        tile(
          Image.asset(AssetPaths.socialGoogle, width: 28, height: 28),
          cubit.continueWithGoogle,
        ),
      ],
    );
  }
}
