import 'package:flutter/material.dart';

import '../../../core/i18n/app_localizations.dart';
import '../../../core/theme/app_icons.dart';
import '../../../shared/extensions/context_extensions.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/ghost_button.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/widgets/primary_button.dart';
import 'brand_lockup.dart';

/// Card-shaped sign-up form mirroring [SignInForm]: optional brand lockup,
/// title + subtitle, email/password/confirm-password, primary
/// "Create account", divider, "Back to sign in" ghost button, footer.
///
/// Validates client-side (password ≥ 8 chars, passwords match). Server
/// validation surfaces via the screen's typed-failure pipeline. Username
/// was removed from the form — Django auto-derives it from the email on
/// register, and the account screen displays whatever the server returns.
class SignUpForm extends StatelessWidget {
  const SignUpForm({
    super.key,
    required this.wide,
    required this.loading,
    required this.email,
    required this.password,
    required this.confirmPassword,
    required this.passwordError,
    required this.confirmError,
    required this.onSubmit,
    required this.onBackToSignIn,
    this.emailError,
  });

  final bool wide;
  final bool loading;
  final TextEditingController email;
  final TextEditingController password;
  final TextEditingController confirmPassword;
  final String? emailError;
  final String? passwordError;
  final String? confirmError;
  final VoidCallback onSubmit;
  final VoidCallback onBackToSignIn;

  @override
  Widget build(BuildContext context) {
    final s = context.saqqar;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!wide) ...[
          const BrandLockup(compact: true),
          const SizedBox(height: 28),
        ],
        GlassCard(
          padding: const EdgeInsets.fromLTRB(22, 24, 22, 22),
          child: AutofillGroup(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  context.tr.signUpTitle,
                  style: context.text.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  context.tr.signUpSubtitle,
                  style: context.text.bodyMedium?.copyWith(
                    color: s.muted,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 24),
                AppTextField(
                  label: context.tr.emailLabel,
                  hint: context.tr.emailHint,
                  controller: email,
                  prefixIcon: AppIcons.mail,
                  textInputAction: TextInputAction.next,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                  errorText: emailError,
                ),
                const SizedBox(height: 16),
                AppPasswordField(
                  label: context.tr.password,
                  hint: context.tr.authPasswordHint,
                  controller: password,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.newPassword],
                  errorText: passwordError,
                ),
                const SizedBox(height: 16),
                AppPasswordField(
                  label: context.tr.confirmPassword,
                  hint: context.tr.confirmPasswordHint,
                  controller: confirmPassword,
                  textInputAction: TextInputAction.done,
                  autofillHints: const [AutofillHints.newPassword],
                  errorText: confirmError,
                  onSubmitted: (_) => onSubmit(),
                ),
                const SizedBox(height: 22),
                // Disabled until all three fields have content — the screen
                // still owns the ≥8-chars / passwords-match validation, but
                // there's no point letting an empty form fire a request.
                AnimatedBuilder(
                  animation: Listenable.merge(
                    [email, password, confirmPassword],
                  ),
                  builder: (context, _) {
                    final canSubmit = email.text.trim().isNotEmpty &&
                        password.text.isNotEmpty &&
                        confirmPassword.text.isNotEmpty;
                    return PrimaryButton(
                      label: context.tr.createAccountButton,
                      icon: AppIcons.userPlus,
                      loading: loading,
                      expand: true,
                      onPressed: (loading || !canSubmit) ? null : onSubmit,
                    );
                  },
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(child: Divider(color: s.border)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                context.tr.alreadyHaveAccount,
                style: context.text.labelSmall?.copyWith(color: s.muted),
              ),
            ),
            Expanded(child: Divider(color: s.border)),
          ],
        ),
        const SizedBox(height: 14),
        GhostButton(
          label: context.tr.backToSignIn,
          icon: AppIcons.signIn,
          expand: true,
          onPressed: onBackToSignIn,
        ),
        const SizedBox(height: 22),
        Text(
          context.tr.poweredByDigitalHarbor,
          textAlign: TextAlign.center,
          style: context.text.labelSmall?.copyWith(color: s.muted),
        ),
      ],
    );
  }
}
