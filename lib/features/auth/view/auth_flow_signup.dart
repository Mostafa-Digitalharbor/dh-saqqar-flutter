part of 'auth_flow_screen.dart';

class _SignUpPage extends StatefulWidget {
  const _SignUpPage({super.key});

  @override
  State<_SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<_SignUpPage> {
  final _name = TextEditingController();
  late final TextEditingController _email;
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  String? _nameErr, _emailErr, _pwdErr, _confirmErr;

  @override
  void initState() {
    super.initState();
    _email = TextEditingController(
      text: context.read<AuthFlowCubit>().state.email,
    );
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  void _submit() {
    final tr = context.tr;
    final name = _name.text.trim();
    final email = _email.text.trim();
    final pwd = _password.text;
    final nErr = name.isEmpty ? tr.authNameRequired : null;
    final eErr = email.isEmpty
        ? tr.emailRequired
        : (!_looksLikeEmail(email) ? tr.emailInvalid : null);
    final pErr = pwd.length < 8 ? tr.passwordTooShort : null;
    final cErr = _confirm.text != pwd ? tr.authPasswordsMismatch : null;
    setState(() {
      _nameErr = nErr;
      _emailErr = eErr;
      _pwdErr = pErr;
      _confirmErr = cErr;
    });
    if (nErr != null || eErr != null || pErr != null || cErr != null) return;
    context.read<AuthFlowCubit>().submitSignUpForm(
      name: name,
      email: email,
      password: pwd,
    );
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<AuthFlowCubit>();
    final loading = context.select<AuthFlowCubit, bool>((c) => c.state.loading);
    return AuthFrame(
      pillLabel: context.tr.figSignIn,
      onPill: cubit.toSignIn,
      title: context.tr.figStartSmarterWithSaqqarAi,
      subtitle: context.tr.figConnectWithYourOdooDataAutomate,
      bodyGap: 42,
      children: [
        FigField(
          label: context.tr.figName,
          hint: context.tr.figEnterYourName,
          controller: _name,
          error: _nameErr,
          height: 56,
          textInputAction: TextInputAction.next,
          autofillHints: const [AutofillHints.name],
        ),
        const SizedBox(height: AppSpacing.s22),
        FigField(
          label: context.tr.figEmail,
          hint: context.tr.figEnterYourEmail,
          controller: _email,
          error: _emailErr,
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
          error: _pwdErr,
          height: 56,
          obscure: true,
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: AppSpacing.s22),
        FigField(
          label: context.tr.figConfirmPassword2,
          hint: context.tr.figEnterYourPassword,
          controller: _confirm,
          error: _confirmErr,
          height: 56,
          obscure: true,
          textInputAction: TextInputAction.go,
          onSubmitted: (_) => _submit(),
        ),
        const SizedBox(height: 38),
        FigButton(
          label: context.tr.figSignUp,
          loading: loading,
          onPressed: _submit,
        ),
      ],
    );
  }
}
