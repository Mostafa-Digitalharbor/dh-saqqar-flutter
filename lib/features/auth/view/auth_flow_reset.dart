part of 'auth_flow_screen.dart';

class _ResetEmailPage extends StatefulWidget {
  const _ResetEmailPage({super.key});

  @override
  State<_ResetEmailPage> createState() => _ResetEmailPageState();
}

class _ResetEmailPageState extends State<_ResetEmailPage> {
  late final TextEditingController _email;
  String? _error;

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
    super.dispose();
  }

  void _submit() {
    final email = _email.text.trim();
    if (email.isEmpty || !_looksLikeEmail(email)) {
      setState(() => _error = context.tr.emailInvalid);
      return;
    }
    setState(() => _error = null);
    context.read<AuthFlowCubit>().submitResetEmail(email);
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<AuthFlowCubit>();
    final loading = context.select<AuthFlowCubit, bool>((c) => c.state.loading);
    return AuthFrame(
      onBack: cubit.toSignIn,
      pillLabel: context.tr.figSignIn,
      onPill: cubit.toSignIn,
      titleGap: 98,
      bodyGap: 44,
      title: context.tr.figResetYourPassword,
      subtitle: context.tr.figEnterYourEmailWeLlSend,
      children: [
        FigField(
          label: context.tr.figEmailAddress2,
          hint: context.tr.figEnterYourEmail,
          controller: _email,
          error: _error,
          height: 56,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.go,
          autofillHints: const [AutofillHints.email],
          onSubmitted: (_) => _submit(),
        ),
        const SizedBox(height: AppSpacing.s40),
        FigButton(
          label: context.tr.figReset,
          loading: loading,
          onPressed: _submit,
        ),
      ],
    );
  }
}

class _NewPasswordPage extends StatefulWidget {
  const _NewPasswordPage({super.key});

  @override
  State<_NewPasswordPage> createState() => _NewPasswordPageState();
}

class _NewPasswordPageState extends State<_NewPasswordPage> {
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  String? _pErr, _cErr;

  @override
  void initState() {
    super.initState();
    _watchEdits(_password, () {
      if (mounted) setState(() => _pErr = null);
    });
    _watchEdits(_confirm, () {
      if (mounted) setState(() => _cErr = null);
    });
  }

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  void _submit() {
    final pwd = _password.text;
    final pErr = _strongPassword(pwd)
        ? null
        : context.tr.figPleaseEnterAtLeast8Characters;
    final cErr = _confirm.text != pwd ? context.tr.figPasswordsDonTMatch : null;
    setState(() {
      _pErr = pErr;
      _cErr = cErr;
    });
    if (pErr != null || cErr != null) return;
    context.read<AuthFlowCubit>().completeReset(pwd);
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<AuthFlowCubit>();
    final loading = context.select<AuthFlowCubit, bool>((c) => c.state.loading);
    return AuthFrame(
      onBack: () => cubit.goTo(AuthFlowStep.resetEmail),
      pillLabel: context.tr.figSignIn,
      onPill: cubit.toSignIn,
      titleGap: 98,
      bodyGap: 44,
      title: context.tr.figNewPassword2,
      subtitle: context.tr.figEnterNewPasswordMustBeDifferent,
      children: [
        FigField(
          label: context.tr.figNewPassword3,
          hint: context.tr.figEnterYourPassword,
          controller: _password,
          error: _pErr,
          height: 56,
          obscure: true,
          textInputAction: TextInputAction.next,
        ),
        SizedBox(height: _pErr != null ? 22 : 24),
        FigField(
          label: context.tr.figConfirmNewPassword,
          hint: context.tr.figEnterYourPassword,
          controller: _confirm,
          error: _cErr,
          height: 56,
          obscure: true,
          textInputAction: TextInputAction.go,
          onSubmitted: (_) => _submit(),
        ),
        const SizedBox(height: AppSpacing.s34),
        FigButton(
          label: context.tr.figResetNewPassword,
          loading: loading,
          onPressed: _submit,
        ),
      ],
    );
  }
}
