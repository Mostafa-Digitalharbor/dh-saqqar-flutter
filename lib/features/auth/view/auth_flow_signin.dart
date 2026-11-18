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
                width: FigMetrics.size16, height: FigMetrics.size16,
                decoration: BoxDecoration(
                  color: _agreed ? Fig.blue : Colors.transparent,
                  borderRadius: BorderRadius.circular(FigMetrics.radFig3),
                  border: Border.all(
                    color: _agreed ? Fig.blue : Fig.muted,
                    width: AppBorderWidths.hairline,
                  ),
                ),
                child: _agreed
                    ? const Icon(AppIcons.check, size: AppIconSizes.meta, color: AppColors.figWhite)
                    : null,
              ),
            ),
            const SizedBox(width: AppSpacing.s8),
            Expanded(
              child: Text.rich(
                TextSpan(
                  style: Fig.t(context, size: FigMetrics.fontFig10, color: Fig.muted),
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
                    size: AppFontSizes.microCaps,
                    color: AppColors.figCFF2B3A8F,
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
              style: Fig.t(context, size: FigMetrics.fontFig11, color: Fig.dangerText),
            ),
          ),
        const SizedBox(height: AppSpacing.s40),
        FigButton(
          label: context.tr.figSignIn,
          loading: loading,
          onPressed: _submit,
          height: 54,
        ),
        const SizedBox(height: AppSpacing.s25),
        const _OrDivider(),
        const SizedBox(height: AppSpacing.s38),
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
      child: Container(height: 1, color: AppColors.figCFFD5DAEA),
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
              style: Fig.t(context, size: FigMetrics.fontFig11, color: Fig.muted),
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
        width: FigMetrics.size54, height: FigMetrics.size54,
        decoration: BoxDecoration(
          color: AppColors.figCFFE7E8ED,
          borderRadius: BorderRadius.circular(AppRadius.bubble),
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
            Image.asset(AssetPaths.socialApple, width: FigMetrics.size28, height: FigMetrics.size28),
            cubit.continueWithApple,
          ),
          const SizedBox(width: AppSpacing.s22),
        ],
        tile(
          Image.asset(AssetPaths.socialGoogle, width: FigMetrics.size28, height: FigMetrics.size28),
          cubit.continueWithGoogle,
        ),
      ],
    );
  }
}
