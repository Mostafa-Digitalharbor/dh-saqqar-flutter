import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/i18n/app_localizations.dart';
import '../../../core/theme/app_radius.dart';
import '../../../shared/extensions/context_extensions.dart';
import '../view_model/auth_flow_cubit.dart';

/// "or continue with" divider + Google (all platforms) and Apple (iOS only)
/// sign-in buttons. Shown under the email field on the sign-in / sign-up entry
/// steps. Bound to [AuthFlowCubit.continueWithGoogle] / `continueWithApple`;
/// the cubit's `loading` flag disables every tap target while any auth call
/// (including email/OTP) is in flight, so the user can't fire two at once.
class SocialAuthButtons extends StatelessWidget {
  const SocialAuthButtons({super.key});

  @override
  Widget build(BuildContext context) {
    final tr = context.tr;
    final s = context.saqqar;
    final loading = context.select<AuthFlowCubit, bool>((c) => c.state.loading);
    final cubit = context.read<AuthFlowCubit>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 22),
        Row(
          children: [
            Expanded(child: Divider(color: s.cardBorder)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                tr.authOrContinueWith,
                style: context.text.labelSmall?.copyWith(color: s.muted),
              ),
            ),
            Expanded(child: Divider(color: s.cardBorder)),
          ],
        ),
        const SizedBox(height: 18),
        _SocialButton(
          label: tr.authContinueWithGoogle,
          logo: const _GoogleGlyph(),
          onPressed: loading ? null : cubit.continueWithGoogle,
        ),
        // App Store 4.8: offering Google on iOS requires offering Apple too.
        // Apple sign-in is iOS-native, so the button is iOS-only.
        if (Platform.isIOS) ...[
          const SizedBox(height: 12),
          _SocialButton(
            label: tr.authContinueWithApple,
            logo: Icon(Icons.apple, size: 21, color: s.text),
            onPressed: loading ? null : cubit.continueWithApple,
          ),
        ],
      ],
    );
  }
}

/// Neutral pill matching [GhostButton]'s surface + hairline, with the brand
/// logo pinned left and the label optically centered.
class _SocialButton extends StatelessWidget {
  const _SocialButton({
    required this.label,
    required this.logo,
    required this.onPressed,
  });

  final String label;
  final Widget logo;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final s = context.saqqar;
    final disabled = onPressed == null;
    final fillColor =
        s.surface2.withValues(alpha: context.isDark ? 0.45 : 0.85);

    return Semantics(
      button: true,
      enabled: !disabled,
      label: label,
      child: Opacity(
        opacity: disabled ? 0.5 : 1,
        child: Material(
          color: Colors.transparent,
          borderRadius: AppRadius.buttonR,
          child: InkWell(
            onTap: onPressed,
            borderRadius: AppRadius.buttonR,
            child: Container(
              constraints: const BoxConstraints(minHeight: 48),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: fillColor,
                borderRadius: AppRadius.buttonR,
                border: Border.all(color: s.cardBorder),
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 22,
                    height: 22,
                    child: Center(child: logo),
                  ),
                  Expanded(
                    child: Text(
                      label,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.labelLarge?.copyWith(
                        color: s.text,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  // Balances the leading logo so the label stays centered.
                  const SizedBox(width: 22),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The Google "G", drawn in its four brand colours with a [CustomPainter] so
/// no image asset (and no flutter_svg dependency) is needed. Matches Google's
/// logo geometry closely enough to read as the official mark at button size.
class _GoogleGlyph extends StatelessWidget {
  const _GoogleGlyph();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 18,
      height: 18,
      child: CustomPaint(painter: _GoogleLogoPainter()),
    );
  }
}

class _GoogleLogoPainter extends CustomPainter {
  const _GoogleLogoPainter();

  static const _blue = Color(0xFF4285F4);
  static const _red = Color(0xFFEA4335);
  static const _yellow = Color(0xFFFBBC05);
  static const _green = Color(0xFF34A853);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final stroke = w * 0.22;
    final rect = Rect.fromLTWH(
      stroke / 2,
      stroke / 2,
      w - stroke,
      h - stroke,
    );
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.butt;

    // Four coloured arcs sweeping around the ring (angles in radians,
    // clockwise from the 3-o'clock position).
    void arc(Color color, double startDeg, double sweepDeg) {
      paint.color = color;
      canvas.drawArc(
        rect,
        startDeg * 3.1415926535 / 180,
        sweepDeg * 3.1415926535 / 180,
        false,
        paint,
      );
    }

    arc(_red, -35, -85); // top-left (red)
    arc(_yellow, -120, -75); // bottom-left (yellow)
    arc(_green, 165, -80); // bottom-right (green)
    arc(_blue, 90, -125); // right side (blue)

    // The blue crossbar of the "G".
    final bar = Paint()
      ..color = _blue
      ..style = PaintingStyle.fill;
    canvas.drawRect(
      Rect.fromLTWH(w * 0.52, h * 0.40, w * 0.46, stroke),
      bar,
    );
  }

  @override
  bool shouldRepaint(covariant _GoogleLogoPainter oldDelegate) => false;
}
