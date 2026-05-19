import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/i18n/app_localizations.dart';
import '../../../core/routing/route_names.dart';
import '../../../core/theme/app_icons.dart';
import '../../../shared/extensions/context_extensions.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/ghost_button.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/widgets/primary_button.dart';
import 'brand_lockup.dart';

/// Card-shaped sign-in form: optional compact brand lockup, welcome copy,
/// username + password fields, primary "Sign in", divider, "Create an
/// account" ghost button, and the powered-by footer.
class SignInForm extends StatelessWidget {
  const SignInForm({
    super.key,
    required this.wide,
    required this.loading,
    required this.username,
    required this.password,
    required this.onSubmit,
    this.usernameError,
    this.passwordError,
  });

  final bool wide;
  final bool loading;
  final TextEditingController username;
  final TextEditingController password;
  final VoidCallback onSubmit;
  final String? usernameError;
  final String? passwordError;

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
                  context.tr.welcomeBack,
                  style: context.text.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  context.tr.signInSubtitle,
                  style: context.text.bodyMedium?.copyWith(
                    color: s.muted,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 24),
                AppTextField(
                  label: context.tr.emailLabel,
                  hint: context.tr.emailHint,
                  controller: username,
                  prefixIcon: AppIcons.mail,
                  textInputAction: TextInputAction.next,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [
                    AutofillHints.email,
                    AutofillHints.username,
                  ],
                  errorText: usernameError,
                ),
                const SizedBox(height: 16),
                AppPasswordField(
                  label: context.tr.password,
                  hint: context.tr.authPasswordHint,
                  controller: password,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => onSubmit(),
                  errorText: passwordError,
                ),
                const SizedBox(height: 22),
                PrimaryButton(
                  label: context.tr.signIn,
                  icon: AppIcons.signIn,
                  loading: loading,
                  expand: true,
                  onPressed: loading ? null : onSubmit,
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
                context.tr.newToSaqqar,
                style: context.text.labelSmall?.copyWith(color: s.muted),
              ),
            ),
            Expanded(child: Divider(color: s.border)),
          ],
        ),
        const SizedBox(height: 14),
        GhostButton(
          label: context.tr.createAccount,
          icon: AppIcons.userPlus,
          expand: true,
          onPressed: () => context.pushNamed(RouteNames.signUp),
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
