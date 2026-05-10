import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/ui_strings.dart';
import '../../../core/i18n/app_localizations.dart';
import '../../../core/routing/route_names.dart';
import '../../../core/theme/app_gradients.dart';
import '../../../core/theme/app_icons.dart';
import '../../../shared/extensions/context_extensions.dart';
import '../../../shared/widgets/ambient_background.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/app_toast.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/widgets/ghost_button.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../../shared/widgets/status_pill.dart';

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
                      child: _BrandPanel(
                        onStart: () => context.go(RouteNames.chatsPath),
                      ),
                    ),
                  Expanded(
                    child: Center(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(24),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 440),
                          child: _SignInForm(
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

class _SignInForm extends StatelessWidget {
  const _SignInForm({
    required this.wide,
    required this.loading,
    required this.username,
    required this.password,
    required this.onSubmit,
  });

  final bool wide;
  final bool loading;
  final TextEditingController username;
  final TextEditingController password;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final s = context.saqqar;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!wide) ...[
          const _BrandLockup(compact: true),
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
                  label: context.tr.username,
                  hint: context.tr.usernameHint,
                  controller: username,
                  prefixIcon: AppIcons.user,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.username],
                ),
                const SizedBox(height: 16),
                AppPasswordField(
                  label: context.tr.password,
                  hint: context.tr.authPasswordHint,
                  controller: password,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => onSubmit(),
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
            Expanded(child: Divider(color: s.border, thickness: 1)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                context.tr.newToSaqqar,
                style: context.text.labelSmall?.copyWith(color: s.muted),
              ),
            ),
            Expanded(child: Divider(color: s.border, thickness: 1)),
          ],
        ),
        const SizedBox(height: 14),
        GhostButton(
          label: context.tr.createAccount,
          icon: AppIcons.userPlus,
          expand: true,
          onPressed: () => AppToast.show(
            context,
            message: context.tr.createAccountUnavailable,
          ),
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

class _BrandLockup extends StatelessWidget {
  const _BrandLockup({this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final s = context.saqqar;

    return Column(
      crossAxisAlignment: compact
          ? CrossAxisAlignment.center
          : CrossAxisAlignment.start,
      children: [
        Container(
          width: compact ? 68 : 80,
          height: compact ? 68 : 80,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: AppGradients.vivid,
            border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
            boxShadow: [
              BoxShadow(
                color: s.brandCyan.withValues(alpha: 0.32),
                blurRadius: 36,
                offset: const Offset(0, 16),
              ),
            ],
          ),
          alignment: Alignment.center,
          child: Icon(
            AppIcons.logoMark,
            color: Colors.white,
            size: compact ? 30 : 36,
          ),
        ),
        SizedBox(height: compact ? 18 : 24),
        Text(
          context.tr.appName,
          textAlign: compact ? TextAlign.center : TextAlign.start,
          style: context.text.displaySmall?.copyWith(
            fontWeight: FontWeight.w900,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          context.tr.appTagline,
          textAlign: compact ? TextAlign.center : TextAlign.start,
          style: context.text.bodyMedium?.copyWith(
            color: s.muted,
            height: 1.4,
          ),
        ),
      ],
    );
  }
}

class _BrandPanel extends StatelessWidget {
  const _BrandPanel({required this.onStart});

  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final s = context.saqqar;

    return Container(
      padding: const EdgeInsets.all(56),
      decoration: BoxDecoration(
        color: s.surface3,
        border: Border(right: BorderSide(color: s.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Spacer(),
          const _BrandLockup(),
          const SizedBox(height: 18),
          Text(
            context.tr.authBrandTitle,
            style: context.text.displaySmall?.copyWith(
              fontWeight: FontWeight.w800,
              height: 1.08,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            context.tr.authBrandBody,
            style: context.text.bodyLarge?.copyWith(
              color: s.muted,
              height: 1.55,
            ),
          ),
          const SizedBox(height: 28),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              StatusPill(label: context.tr.smartDiagnosis),
              StatusPill(label: context.tr.liveTools),
              StatusPill(label: context.tr.approvalGated),
              StatusPill(label: context.tr.perUserVault),
            ],
          ),
          const SizedBox(height: 32),
          PrimaryButton(
            label: context.tr.openWorkspace,
            icon: AppIcons.chevronRight,
            onPressed: onStart,
          ),
          const Spacer(),
          Text(
            context.tr.poweredByDigitalHarbor,
            style: context.text.labelSmall?.copyWith(color: s.muted),
          ),
        ],
      ),
    );
  }
}
