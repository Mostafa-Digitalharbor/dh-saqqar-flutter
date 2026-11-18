import 'dart:async';

import 'package:flutter/foundation.dart' show defaultTargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/error/app_failure.dart';
import '../../../core/i18n/app_localizations.dart';
import '../../../core/network/api_error_mapper.dart';
import '../../../shared/fig/fig.dart';
import '../../../shared/widgets/app_toast.dart';
import '../data/auth_api.dart';
import '../data/social_auth_service.dart';
import '../view_model/auth_cubit.dart';
import '../view_model/auth_flow_cubit.dart';
import '../../../core/constants/asset_paths.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_sizes.dart';
import '../../../core/theme/fig_metrics.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_colors.dart';
part 'auth_flow_signin.dart';
part 'auth_flow_signup.dart';
part 'auth_flow_otp.dart';
part 'auth_flow_reset.dart';

/// Email-OTP auth flow, restyled to the 2026-11 Figma set. One screen driven
/// by [AuthFlowCubit]; every step shares the dark-to-light gradient backdrop,
/// glass fields and the blue pill CTA. `/sign-up` enters at
/// [AuthFlowStep.signUpEmail] and `/sign-in` at [AuthFlowStep.signInEmail].
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
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: figLightStatusBar,
      child: Scaffold(
        backgroundColor: Fig.pageGrey,
        body: FigBackdrop(
          child: BlocConsumer<AuthFlowCubit, AuthFlowState>(
            listenWhen: (a, b) =>
                (a.failure != b.failure && b.failure != null) ||
                (a.noticeKey != b.noticeKey && b.noticeKey != null),
            listener: (context, state) {
              if (state.noticeKey != null) {
                AppToast.show(
                  context,
                  message: context.tr.lookup(state.noticeKey!, fallback: ''),
                  variant: ToastVariant.success,
                );
                return;
              }
              final failure = ApiErrorMapper.toFailure(state.failure);
              final message = failure is UnauthorizedFailure
                  ? context.tr.authInvalidCredentials
                  : ApiErrorMapper.message(context, failure);
              // A wrong OTP is shown inline on the boxes (red, as in the
              // mock) — everything else is a toast.
              if (state.isOtpStep) return;
              AppToast.show(
                context,
                message: message,
                variant: ToastVariant.error,
              );
            },
            builder: _body,
          ),
        ),
      ),
    );
  }

  Widget _body(BuildContext context, AuthFlowState state) {
    final cubit = context.read<AuthFlowCubit>();
    switch (state.step) {
      case AuthFlowStep.signInEmail:
      case AuthFlowStep.signInPassword:
        return const _SignInPage(key: ValueKey('si'));
      case AuthFlowStep.signUpEmail:
      case AuthFlowStep.signUpProfile:
        return const _SignUpPage(key: ValueKey('su'));
      case AuthFlowStep.signUpOtp:
        return _OtpPage(
          key: const ValueKey('su_otp'),
          kind: _OtpKind.signup,
          onBack: () => cubit.goTo(AuthFlowStep.signUpEmail),
        );
      case AuthFlowStep.signInOtp:
        return _OtpPage(
          key: const ValueKey('si_otp'),
          kind: _OtpKind.signin,
          onBack: () => cubit.goTo(AuthFlowStep.signInEmail),
        );
      case AuthFlowStep.resetEmail:
        return const _ResetEmailPage(key: ValueKey('rs'));
      case AuthFlowStep.resetOtp:
        return _OtpPage(
          key: const ValueKey('rs_otp'),
          kind: _OtpKind.reset,
          onBack: () => cubit.goTo(AuthFlowStep.resetEmail),
        );
      case AuthFlowStep.resetNewPassword:
        return const _NewPasswordPage(key: ValueKey('rs_pwd'));
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Shared page frame
// ─────────────────────────────────────────────────────────────────────────

/// Back / pill row + big white title + muted subtitle, then [children] in a
/// scroll view. [titleGap] is the distance from the top bar to the title —
/// the sign-in/up pages sit tighter than the OTP/reset pages in the mock.
/// Dark-header page frame shared by auth and the setup wizard.
class AuthFrame extends StatelessWidget {
  const AuthFrame({
    super.key,
    required this.title,
    required this.subtitle,
    required this.children,
    this.onBack,
    this.pillLabel,
    this.onPill,
    this.titleGap = 25,
    this.subtitleGap = 10,
    this.bodyGap = 44,
    this.footer,
    this.progress,
    this.hPad = 24,
  });

  /// 0..1 — draws the wizard progress bar under the back button.
  final double? progress;
  final double hPad;

  final String title;
  final String subtitle;
  final List<Widget> children;
  final VoidCallback? onBack;
  final String? pillLabel;
  final VoidCallback? onPill;
  final double titleGap;
  final double subtitleGap;
  final double bodyGap;
  final String? footer;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: EdgeInsets.fromLTRB(hPad, AppSpacing.s26, hPad, AppSpacing.s24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    height: 50,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        if (onBack != null)
                          Transform.translate(
                            offset: FigOffsets.oUn10U0,
                            child: FigBackButton(onTap: onBack),
                          )
                        else
                          const SizedBox.shrink(),
                        if (pillLabel != null)
                          FigTopPill(label: pillLabel!, onTap: onPill!),
                      ],
                    ),
                  ),
                  if (progress != null) ...[
                    const SizedBox(height: AppSpacing.s22),
                    _ProgressBar(value: progress!),
                  ],
                  SizedBox(height: titleGap),
                  Text(
                    title,
                    style: Fig.t(
                      context,
                      size: FigMetrics.fontFig32,
                      color: AppColors.figWhite,
                      height: FigMetrics.lhFig117,
                      letterSpacing: AppLetterSpacing.heading,
                    ),
                  ),
                  SizedBox(height: subtitleGap),
                  Text(
                    subtitle,
                    // White with a soft shadow: the last lines of the subtitle
                    // sit where the glow turns light, and plain white blends
                    // into it there.
                    style:
                        Fig.t(
                          context,
                          size: AppFontSizes.dense,
                          color: AppColors.figWhite,
                          height: AppLineHeights.snug,
                        ).copyWith(
                          shadows: const [
                            Shadow(color: Fig.shadowInk, blurRadius: FigMetrics.blur6),
                          ],
                        ),
                  ),
                  SizedBox(height: bodyGap),
                  ...children,
                ],
              ),
            ),
          ),
          if (footer != null)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.s14),
              child: Text(
                footer!,
                style: Fig.t(context, size: FigMetrics.fontFig10, color: Fig.muted),
              ),
            ),
        ],
      ),
    );
  }
}

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.value});

  final double value;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 6,
      decoration: BoxDecoration(
        color: AppColors.figWhite.withValues(alpha: AppAlphas.a85),
        borderRadius: BorderRadius.circular(FigMetrics.radFig3),
      ),
      alignment: AlignmentDirectional.centerStart,
      child: FractionallySizedBox(
        widthFactor: value,
        child: Container(
          decoration: BoxDecoration(
            color: Fig.blueStrong,
            borderRadius: BorderRadius.circular(FigMetrics.radFig3),
          ),
        ),
      ),
    );
  }
}

bool _looksLikeEmail(String v) => v.contains('@') && v.contains('.');

/// 8+ chars with a digit, a symbol, a lowercase and an uppercase letter.
bool _strongPassword(String v) =>
    v.length >= 8 &&
    RegExp(r'[0-9]').hasMatch(v) &&
    RegExp(r'[a-z]').hasMatch(v) &&
    RegExp(r'[A-Z]').hasMatch(v) &&
    RegExp(r'[^A-Za-z0-9]').hasMatch(v);

// ─────────────────────────────────────────────────────────────────────────
// Sign in
// ─────────────────────────────────────────────────────────────────────────

// ─────────────────────────────────────────────────────────────────────────
// Sign up
// ─────────────────────────────────────────────────────────────────────────

// ─────────────────────────────────────────────────────────────────────────
// OTP
// ─────────────────────────────────────────────────────────────────────────

extension on Text {
  Widget withUnderline() => DefaultTextStyle.merge(
    style: const TextStyle(decoration: TextDecoration.underline),
    child: this,
  );
}

// ─────────────────────────────────────────────────────────────────────────
// Reset password
// ─────────────────────────────────────────────────────────────────────────

/// Runs [onEdit] when the text in [controller] actually changes (not on a
/// cursor move or a tap), so a field's validation message can disappear as soon
/// as the user starts fixing it instead of lingering — and contradicting what
/// is now typed — until the next submit.
void _watchEdits(TextEditingController controller, VoidCallback onEdit) {
  var last = controller.text;
  controller.addListener(() {
    if (controller.text == last) return;
    last = controller.text;
    onEdit();
  });
}
