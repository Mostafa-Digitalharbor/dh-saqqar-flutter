import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/error/app_failure.dart';
import '../../../core/i18n/app_localizations.dart';
import '../../../core/network/api_error_mapper.dart';
import '../../../core/theme/app_icons.dart';
import '../../../shared/extensions/context_extensions.dart';
import '../../../shared/widgets/ambient_background.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/app_toast.dart';
import '../../../shared/widgets/ghost_button.dart';
import '../../../shared/widgets/labeled_divider.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../../shared/widgets/saqqar_logo.dart';
import '../data/auth_api.dart';
import '../data/social_auth_service.dart';
import '../view_model/auth_cubit.dart';
import '../view_model/auth_flow_cubit.dart';
import '../widgets/auth_header_actions.dart';
import '../widgets/social_auth_buttons.dart';
import '../../../core/theme/app_radius.dart';

/// Email-OTP auth flow (Gap D). One screen, nine steps, driven by
/// [AuthFlowCubit]. `/sign-up` enters at [AuthFlowStep.signUpEmail] and
/// `/sign-in` at [AuthFlowStep.signInEmail]; every other step is reached by
/// in-flow navigation. On any terminal success the cubit adopts the session
/// and the router gate routes to /chats.
class AuthFlowScreen extends StatelessWidget {
  const AuthFlowScreen({super.key, required this.initial});

  final AuthFlowStep initial;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<AuthFlowCubit>(
      create: (ctx) => AuthFlowCubit(
        api: ctx.read<AuthApi>(),
        authCubit: ctx.read<AuthCubit>(),
        socialAuth: ctx.read<SocialAuthService>(),
        initial: initial,
      ),
      child: const _AuthFlowView(),
    );
  }
}

class _AuthFlowView extends StatelessWidget {
  const _AuthFlowView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Decorative blobs (the soft circles) were retired on user request
      // 2026-07-06 for a cleaner login — plain ambient backdrop, with the
      // logo now framed by an elegant card (see below).
      body: AmbientBackground(
        withBlobs: false,
        child: SafeArea(
          child: BlocConsumer<AuthFlowCubit, AuthFlowState>(
            listenWhen: (a, b) =>
                (a.failure != b.failure && b.failure != null) ||
                (a.noticeKey != b.noticeKey && b.noticeKey != null),
            listener: (context, state) {
              // Success notice (e.g. password set — sign in now).
              if (state.noticeKey != null) {
                AppToast.show(
                  context,
                  message: context.tr.lookup(
                    state.noticeKey!,
                    fallback: '',
                  ),
                  variant: ToastVariant.success,
                );
                return;
              }
              // A 401 here means the user typed a wrong password — NOT that
              // their session ended. Surface the auth-specific wording
              // instead of the generic "your session ended" the mapper
              // returns for UnauthorizedFailure.
              final failure = ApiErrorMapper.toFailure(state.failure);
              final message = failure is UnauthorizedFailure
                  ? context.tr.authInvalidCredentials
                  : ApiErrorMapper.message(context, failure);
              AppToast.show(
                context,
                message: message,
                variant: ToastVariant.error,
              );
            },
            builder: (context, state) {
              return Column(
                children: [
                  // Language (EN ↔ AR) + theme (light ↔ dark) toggles pinned
                  // to the top — reachable before signing in, when the
                  // account preferences card isn't yet available.
                  const AuthHeaderActions(),
                  Expanded(
                    child: Center(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 440),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // App brand logo above the form — shown on every
                              // auth step, framed by an elegant card (matches
                              // the splash). SaqqarLogo tints itself (white on
                              // the dark auth backdrop, navy on light).
                              const Padding(
                                padding: EdgeInsets.only(bottom: 28),
                                child: Center(child: _AuthLogoCard()),
                              ),
                              // Key by step so each step's StatefulWidget body
                              // gets a fresh element (controllers reset) on
                              // navigation, but is preserved across loading
                              // rebuilds within a step.
                              _bodyFor(state.step),
                            ],
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

  Widget _bodyFor(AuthFlowStep step) {
    return switch (step) {
      AuthFlowStep.signUpEmail => const _SignUpEmailBody(key: ValueKey('su_email')),
      AuthFlowStep.signUpOtp => const _OtpBody(
          key: ValueKey('su_otp'),
          kind: _OtpKind.signup,
        ),
      AuthFlowStep.signUpProfile =>
        const _ProfileBody(key: ValueKey('su_profile')),
      AuthFlowStep.signInEmail => const _SignInEmailBody(key: ValueKey('si_email')),
      AuthFlowStep.signInOtp => const _OtpBody(
          key: ValueKey('si_otp'),
          kind: _OtpKind.signin,
        ),
      AuthFlowStep.signInPassword =>
        const _PasswordBody(key: ValueKey('si_pwd')),
      AuthFlowStep.resetEmail => const _ResetEmailBody(key: ValueKey('rs_email')),
      AuthFlowStep.resetOtp => const _OtpBody(
          key: ValueKey('rs_otp'),
          kind: _OtpKind.reset,
        ),
      AuthFlowStep.resetNewPassword =>
        const _ResetPasswordBody(key: ValueKey('rs_pwd')),
    };
  }
}

/// Elegant frame around the brand logo on the auth screen — mirrors the
/// splash's framed mark: a faint surface fill, a hairline border, generously
/// rounded corners and a soft shadow, sized snugly to the logo. Theme-aware
/// via [context.saqqar].
class _AuthLogoCard extends StatelessWidget {
  const _AuthLogoCard();

  @override
  Widget build(BuildContext context) {
    final s = context.saqqar;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 24),
      decoration: BoxDecoration(
        color: s.surface.withValues(alpha: context.isDark ? 0.45 : 0.55),
        borderRadius: AppRadius.heroPlateR,
        border: Border.all(color: s.cardBorder),
        boxShadow: s.glassShadow,
      ),
      child: const SaqqarLogo(height: 40),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Shared scaffolding
// ─────────────────────────────────────────────────────────────────────────

/// Title + subtitle header shared by every step.
class _Header extends StatelessWidget {
  const _Header({required this.title, required this.subtitle});
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final s = context.saqqar;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: context.text.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 6),
        Text(subtitle, style: context.text.bodyMedium?.copyWith(color: s.muted)),
        const SizedBox(height: 26),
      ],
    );
  }
}

/// Divider with a centered label + a full-width ghost button below — the
/// "Already have an account? / Sign in instead" footer pattern.
class _Footer extends StatelessWidget {
  const _Footer({
    required this.label,
    required this.actionLabel,
    required this.onAction,
  });

  final String label;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 22),
        LabeledDivider(label: label),
        const SizedBox(height: 18),
        GhostButton(label: actionLabel, expand: true, onPressed: onAction),
      ],
    );
  }
}

/// "Check your email" recipient chip + "Use different email" action.
class _EmailChip extends StatelessWidget {
  const _EmailChip({required this.email, required this.onUseDifferent});
  final String email;
  final VoidCallback onUseDifferent;

  @override
  Widget build(BuildContext context) {
    final s = context.saqqar;
    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(12, 10, 8, 10),
      decoration: BoxDecoration(
        color: s.surface2.withValues(alpha: context.isDark ? 0.5 : 0.85),
        borderRadius: AppRadius.buttonR,
        border: Border.all(color: s.cardBorder),
      ),
      child: Row(
        children: [
          Icon(AppIcons.mail, size: 16, color: s.brandCyan),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              email,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.text.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          TextButton(
            onPressed: onUseDifferent,
            child: Text(context.tr.authUseDifferentEmail.toUpperCase()),
          ),
        ],
      ),
    );
  }
}

/// "Didn't get the code? Resend in 53s" row with an owned 60-second
/// countdown that re-arms on resend.
class _ResendRow extends StatefulWidget {
  const _ResendRow({required this.onResend});
  final VoidCallback onResend;

  @override
  State<_ResendRow> createState() => _ResendRowState();
}

class _ResendRowState extends State<_ResendRow> {
  static const _cooldown = 60;
  int _remaining = _cooldown;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _start();
  }

  void _start() {
    _timer?.cancel();
    setState(() => _remaining = _cooldown);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      if (_remaining <= 1) {
        t.cancel();
        setState(() => _remaining = 0);
      } else {
        setState(() => _remaining--);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.saqqar;
    final tr = context.tr;
    final ready = _remaining <= 0;
    // Two translated phrases plus a TextButton's own 16 px insets sit
    // tight at 320 px — "لم يصلك الرمز؟" + "إعادة الإرسال الآن" reaches the
    // edge before any text scaling. `Flexible` on both lets the prompt
    // ellipsize rather than overflow, and keeps the action reachable.
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Flexible(
          child: Text(
            tr.authDidntGetCode,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.text.labelMedium?.copyWith(color: s.muted),
          ),
        ),
        const SizedBox(width: 6),
        if (ready)
          Flexible(
            child: TextButton(
              onPressed: () {
                widget.onResend();
                _start();
              },
              child: Text(
                tr.authResendNow,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          )
        else
          Flexible(
            child: Text(
              tr.authResendIn(_remaining),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.text.labelMedium?.copyWith(
                color: s.text,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
      ],
    );
  }
}

bool _looksLikeEmail(String v) => v.contains('@') && v.contains('.');

// ─────────────────────────────────────────────────────────────────────────
// Sign-up branch
// ─────────────────────────────────────────────────────────────────────────

class _SignUpEmailBody extends StatefulWidget {
  const _SignUpEmailBody({super.key});
  @override
  State<_SignUpEmailBody> createState() => _SignUpEmailBodyState();
}

class _SignUpEmailBodyState extends State<_SignUpEmailBody> {
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
    final tr = context.tr;
    final email = _email.text.trim();
    if (email.isEmpty) {
      setState(() => _error = tr.emailRequired);
      return;
    }
    if (!_looksLikeEmail(email)) {
      setState(() => _error = tr.emailInvalid);
      return;
    }
    setState(() => _error = null);
    context.read<AuthFlowCubit>().submitSignUpEmail(email);
  }

  @override
  Widget build(BuildContext context) {
    final tr = context.tr;
    final loading = context.select<AuthFlowCubit, bool>((c) => c.state.loading);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Header(title: tr.authSignUpEmailTitle, subtitle: tr.authSignUpEmailSubtitle),
        AppTextField(
          label: tr.email,
          controller: _email,
          hint: tr.authEmailPlaceholder,
          errorText: _error,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.go,
          autofillHints: const [AutofillHints.email],
          onSubmitted: (_) => _submit(),
        ),
        const SizedBox(height: 16),
        PrimaryButton(
          label: tr.authContinueWithEmail,
          icon: AppIcons.arrowRight,
          loading: loading,
          expand: true,
          onPressed: loading ? null : _submit,
        ),
        const SocialAuthButtons(),
        _Footer(
          label: tr.alreadyHaveAccount,
          actionLabel: tr.authSignInInstead,
          onAction: () => context.read<AuthFlowCubit>().toSignIn(),
        ),
      ],
    );
  }
}

class _ProfileBody extends StatefulWidget {
  const _ProfileBody({super.key});
  @override
  State<_ProfileBody> createState() => _ProfileBodyState();
}

class _ProfileBodyState extends State<_ProfileBody> {
  final _first = TextEditingController();
  final _last = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  String? _firstError;
  String? _passwordError;
  String? _confirmError;

  @override
  void dispose() {
    _first.dispose();
    _last.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  void _submit() {
    final tr = context.tr;
    final first = _first.text.trim();
    final pwd = _password.text;
    final confirm = _confirm.text;
    String? fErr;
    String? pErr;
    String? cErr;
    if (first.isEmpty) fErr = tr.authNameRequired;
    if (pwd.length < 8) pErr = tr.passwordTooShort;
    if (confirm != pwd) cErr = tr.authPasswordsMismatch;
    setState(() {
      _firstError = fErr;
      _passwordError = pErr;
      _confirmError = cErr;
    });
    if (fErr != null || pErr != null || cErr != null) return;
    context.read<AuthFlowCubit>().completeSignUp(
          firstName: first,
          lastName: _last.text.trim(),
          password: pwd,
        );
  }

  @override
  Widget build(BuildContext context) {
    final tr = context.tr;
    final cubit = context.watch<AuthFlowCubit>();
    final loading = cubit.state.loading;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Header(title: tr.authProfileTitle, subtitle: tr.authProfileSubtitle),
        AppTextField(
          label: tr.email,
          initialValue: cubit.state.email,
          enabled: false,
        ),
        const SizedBox(height: 14),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: AppTextField(
                label: tr.authFirstName,
                controller: _first,
                errorText: _firstError,
                textInputAction: TextInputAction.next,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: AppTextField(
                label: tr.authLastName,
                controller: _last,
                textInputAction: TextInputAction.next,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        AppPasswordField(
          label: tr.password,
          hint: tr.authPasswordPlaceholder,
          controller: _password,
          errorText: _passwordError,
        ),
        const SizedBox(height: 14),
        AppPasswordField(
          label: tr.confirmPassword,
          hint: tr.authConfirmPlaceholder,
          controller: _confirm,
          errorText: _confirmError,
          onSubmitted: (_) => _submit(),
        ),
        const SizedBox(height: 16),
        PrimaryButton(
          label: tr.authCreateAccountBtn,
          icon: AppIcons.arrowRight,
          loading: loading,
          expand: true,
          onPressed: loading ? null : _submit,
        ),
        _Footer(
          label: tr.alreadyHaveAccount,
          actionLabel: tr.authSignInInstead,
          onAction: () => context.read<AuthFlowCubit>().toSignIn(),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Sign-in branch
// ─────────────────────────────────────────────────────────────────────────

class _SignInEmailBody extends StatefulWidget {
  const _SignInEmailBody({super.key});
  @override
  State<_SignInEmailBody> createState() => _SignInEmailBodyState();
}

class _SignInEmailBodyState extends State<_SignInEmailBody> {
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

  bool _validate() {
    final tr = context.tr;
    final email = _email.text.trim();
    if (email.isEmpty) {
      setState(() => _error = tr.emailRequired);
      return false;
    }
    if (!_looksLikeEmail(email)) {
      setState(() => _error = tr.emailInvalid);
      return false;
    }
    setState(() => _error = null);
    return true;
  }

  void _continueWithEmail() {
    if (!_validate()) return;
    context.read<AuthFlowCubit>().submitSignInEmail(_email.text.trim());
  }

  void _continueWithPassword() {
    context.read<AuthFlowCubit>().rememberEmail(_email.text.trim());
    context.read<AuthFlowCubit>().goTo(AuthFlowStep.signInPassword);
  }

  @override
  Widget build(BuildContext context) {
    final tr = context.tr;
    final loading = context.select<AuthFlowCubit, bool>((c) => c.state.loading);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Header(title: tr.authWelcomeBackTitle, subtitle: tr.authWelcomeBackSubtitle),
        AppTextField(
          label: tr.email,
          controller: _email,
          hint: tr.authEmailPlaceholder,
          errorText: _error,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.go,
          autofillHints: const [AutofillHints.email],
          onSubmitted: (_) => _continueWithEmail(),
        ),
        const SizedBox(height: 16),
        PrimaryButton(
          label: tr.authContinueWithEmail,
          icon: AppIcons.arrowRight,
          loading: loading,
          expand: true,
          onPressed: loading ? null : _continueWithEmail,
        ),
        const SizedBox(height: 6),
        TextButton(
          onPressed: loading ? null : _continueWithPassword,
          child: Text(tr.authContinueWithPassword),
        ),
        const SocialAuthButtons(),
        _Footer(
          label: tr.newToSaqqar,
          actionLabel: tr.authCreateAnAccount,
          onAction: () => context.read<AuthFlowCubit>().toSignUp(),
        ),
      ],
    );
  }
}

class _PasswordBody extends StatefulWidget {
  const _PasswordBody({super.key});
  @override
  State<_PasswordBody> createState() => _PasswordBodyState();
}

class _PasswordBodyState extends State<_PasswordBody> {
  late final TextEditingController _email;
  final _password = TextEditingController();
  String? _emailError;
  String? _passwordError;

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
    context.read<AuthFlowCubit>().submitPasswordLogin(email: email, password: pwd);
  }

  @override
  Widget build(BuildContext context) {
    final tr = context.tr;
    final loading = context.select<AuthFlowCubit, bool>((c) => c.state.loading);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Header(title: tr.authPasswordTitle, subtitle: tr.authPasswordSubtitle),
        AppTextField(
          label: tr.email,
          controller: _email,
          hint: tr.authEmailPlaceholder,
          errorText: _emailError,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          autofillHints: const [AutofillHints.email],
        ),
        const SizedBox(height: 14),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: Text(
                tr.password.toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.text.labelSmall?.copyWith(
                  color: context.saqqar.muted,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                ),
              ),
            ),
            Flexible(
              child: TextButton(
                onPressed: () {
                  context
                      .read<AuthFlowCubit>()
                      .rememberEmail(_email.text.trim());
                  context.read<AuthFlowCubit>().goTo(AuthFlowStep.resetEmail);
                },
                child: Text(
                  tr.authForgotPassword.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
        ),
        AppPasswordField(
          hint: tr.authPasswordEnterPlaceholder,
          controller: _password,
          errorText: _passwordError,
          onSubmitted: (_) => _submit(),
        ),
        const SizedBox(height: 16),
        PrimaryButton(
          label: tr.authLoginBtn,
          icon: AppIcons.arrowRight,
          loading: loading,
          expand: true,
          onPressed: loading ? null : _submit,
        ),
        const SizedBox(height: 6),
        TextButton(
          onPressed: () {
            context.read<AuthFlowCubit>().rememberEmail(_email.text.trim());
            context.read<AuthFlowCubit>().goTo(AuthFlowStep.signInEmail);
          },
          child: Text(tr.authContinueWithEmailInstead),
        ),
        _Footer(
          label: tr.newToSaqqar,
          actionLabel: tr.authCreateAnAccount,
          onAction: () => context.read<AuthFlowCubit>().toSignUp(),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Reset branch
// ─────────────────────────────────────────────────────────────────────────

class _ResetEmailBody extends StatefulWidget {
  const _ResetEmailBody({super.key});
  @override
  State<_ResetEmailBody> createState() => _ResetEmailBodyState();
}

class _ResetEmailBodyState extends State<_ResetEmailBody> {
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
    final tr = context.tr;
    final email = _email.text.trim();
    if (email.isEmpty || !_looksLikeEmail(email)) {
      setState(() => _error = tr.emailInvalid);
      return;
    }
    setState(() => _error = null);
    context.read<AuthFlowCubit>().submitResetEmail(email);
  }

  @override
  Widget build(BuildContext context) {
    final tr = context.tr;
    final loading = context.select<AuthFlowCubit, bool>((c) => c.state.loading);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Header(title: tr.authResetTitle, subtitle: tr.authResetSubtitle),
        AppTextField(
          label: tr.email,
          controller: _email,
          hint: tr.authEmailPlaceholder,
          errorText: _error,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.go,
          onSubmitted: (_) => _submit(),
        ),
        const SizedBox(height: 16),
        PrimaryButton(
          label: tr.authSendResetCode,
          icon: AppIcons.arrowRight,
          loading: loading,
          expand: true,
          onPressed: loading ? null : _submit,
        ),
        _Footer(
          label: tr.authRememberItNow,
          actionLabel: tr.authBackToSignIn,
          onAction: () => context.read<AuthFlowCubit>().toSignIn(),
        ),
      ],
    );
  }
}

class _ResetPasswordBody extends StatefulWidget {
  const _ResetPasswordBody({super.key});
  @override
  State<_ResetPasswordBody> createState() => _ResetPasswordBodyState();
}

class _ResetPasswordBodyState extends State<_ResetPasswordBody> {
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  String? _passwordError;
  String? _confirmError;

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  void _submit() {
    final tr = context.tr;
    final pwd = _password.text;
    final confirm = _confirm.text;
    String? pErr;
    String? cErr;
    if (pwd.length < 8) pErr = tr.passwordTooShort;
    if (confirm != pwd) cErr = tr.authPasswordsMismatch;
    setState(() {
      _passwordError = pErr;
      _confirmError = cErr;
    });
    if (pErr != null || cErr != null) return;
    context.read<AuthFlowCubit>().completeReset(pwd);
  }

  @override
  Widget build(BuildContext context) {
    final tr = context.tr;
    final cubit = context.watch<AuthFlowCubit>();
    final loading = cubit.state.loading;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Header(title: tr.authNewPasswordTitle, subtitle: tr.authNewPasswordSubtitle),
        AppTextField(
          label: tr.email,
          initialValue: cubit.state.email,
          enabled: false,
        ),
        const SizedBox(height: 14),
        AppPasswordField(
          label: tr.authNewPasswordLabel,
          hint: tr.authPasswordPlaceholder,
          controller: _password,
          errorText: _passwordError,
        ),
        const SizedBox(height: 14),
        AppPasswordField(
          label: tr.authConfirmNewPasswordLabel,
          hint: tr.authConfirmNewPlaceholder,
          controller: _confirm,
          errorText: _confirmError,
          onSubmitted: (_) => _submit(),
        ),
        const SizedBox(height: 16),
        PrimaryButton(
          label: tr.authSetNewPasswordBtn,
          icon: AppIcons.arrowRight,
          loading: loading,
          expand: true,
          onPressed: loading ? null : _submit,
        ),
        _Footer(
          label: tr.authRememberItNow,
          actionLabel: tr.authBackToSignIn,
          onAction: () => context.read<AuthFlowCubit>().toSignIn(),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// OTP body (shared by the three "Check your email" steps)
// ─────────────────────────────────────────────────────────────────────────

enum _OtpKind { signup, signin, reset }

class _OtpBody extends StatefulWidget {
  const _OtpBody({super.key, required this.kind});
  final _OtpKind kind;

  @override
  State<_OtpBody> createState() => _OtpBodyState();
}

class _OtpBodyState extends State<_OtpBody> {
  final _code = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  void _verify() {
    final tr = context.tr;
    final code = _code.text.trim();
    if (code.length != 6) {
      setState(() => _error = tr.authCodeRequired);
      return;
    }
    setState(() => _error = null);
    final cubit = context.read<AuthFlowCubit>();
    switch (widget.kind) {
      case _OtpKind.signup:
        cubit.verifySignUpOtp(code);
      case _OtpKind.signin:
        cubit.verifySignInOtp(code);
      case _OtpKind.reset:
        cubit.verifyResetOtp(code);
    }
  }

  void _useDifferentEmail() {
    final cubit = context.read<AuthFlowCubit>();
    switch (widget.kind) {
      case _OtpKind.signup:
        cubit.goTo(AuthFlowStep.signUpEmail);
      case _OtpKind.signin:
        cubit.goTo(AuthFlowStep.signInEmail);
      case _OtpKind.reset:
        cubit.goTo(AuthFlowStep.resetEmail);
    }
  }

  String get _verifyLabel {
    final tr = context.tr;
    return widget.kind == _OtpKind.signin ? tr.authVerifyAndSignIn : tr.authVerifyCode;
  }

  @override
  Widget build(BuildContext context) {
    final tr = context.tr;
    final s = context.saqqar;
    final cubit = context.watch<AuthFlowCubit>();
    final loading = cubit.state.loading;
    final email = cubit.state.email;

    // Footer differs by branch: signup/signin invite the opposite action,
    // reset offers "back to sign in".
    final (footerLabel, footerActionLabel, VoidCallback footerAction) =
        switch (widget.kind) {
      _OtpKind.signup => (
          tr.alreadyHaveAccount,
          tr.authSignInInstead,
          () => context.read<AuthFlowCubit>().toSignIn(),
        ),
      _OtpKind.signin => (
          tr.newToSaqqar,
          tr.authCreateAnAccount,
          () => context.read<AuthFlowCubit>().toSignUp(),
        ),
      _OtpKind.reset => (
          tr.authRememberItNow,
          tr.authBackToSignIn,
          () => context.read<AuthFlowCubit>().toSignIn(),
        ),
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Header(title: tr.authCheckEmailTitle, subtitle: tr.authCheckEmailSubtitle),
        _EmailChip(email: email, onUseDifferent: _useDifferentEmail),
        const SizedBox(height: 18),
        AppTextField(
          label: tr.authOtpLabel,
          controller: _code,
          hint: tr.authOtpPlaceholder,
          errorText: _error,
          keyboardType: TextInputType.number,
          textInputAction: TextInputAction.go,
          autofillHints: const [AutofillHints.oneTimeCode],
          onSubmitted: (_) => _verify(),
        ),
        const SizedBox(height: 6),
        Text(
          tr.authOtpHint,
          style: context.text.labelSmall?.copyWith(color: s.muted),
        ),
        const SizedBox(height: 16),
        PrimaryButton(
          label: _verifyLabel,
          icon: AppIcons.arrowRight,
          loading: loading,
          expand: true,
          onPressed: loading ? null : _verify,
        ),
        const SizedBox(height: 12),
        _ResendRow(onResend: () => context.read<AuthFlowCubit>().resend()),
        // Sign-in OTP also offers a password fallback.
        if (widget.kind == _OtpKind.signin) ...[
          const SizedBox(height: 4),
          TextButton(
            onPressed: () =>
                context.read<AuthFlowCubit>().goTo(AuthFlowStep.signInPassword),
            child: Text(tr.authContinueWithPasswordInstead),
          ),
        ],
        _Footer(
          label: footerLabel,
          actionLabel: footerActionLabel,
          onAction: footerAction,
        ),
      ],
    );
  }
}
