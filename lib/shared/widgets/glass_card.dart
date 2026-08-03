import 'dart:ui';

import 'package:flutter/material.dart';

import '../../core/theme/app_radius.dart';
import '../extensions/context_extensions.dart';

/// Spec §5.1 glass panel — translucent fill + 1px border, with an optional
/// 14px backdrop blur.
///
/// **[blur] defaults to `false`.** A `BackdropFilter` blurs whatever is
/// painted *behind* it, and in this app that is always `AmbientBackground`,
/// which paints a flat opaque `bg` fill — `withBlobs: true` has no call site
/// anywhere in `lib/`. Blurring a uniform colour returns the same uniform
/// colour, so the filter renders an identical frame while still forcing an
/// offscreen `saveLayer` plus a gaussian pass, per card, per frame — cost
/// that is invisible on a flagship and shows up as dropped frames on a
/// low-end GPU.
///
/// Every production call site had already worked around this by passing
/// `blur: false` by hand; defaulting it off means a new card can't
/// accidentally opt into a no-op blur just by not knowing to. The parameter
/// stays so the effect can be switched back on for a surface that genuinely
/// sits over varied content (a sheet over the chat transcript, or the ambient
/// blobs if they are ever re-enabled) — that is where blur reads as glass
/// rather than as a no-op.
class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    this.padding = const EdgeInsets.all(16),
    this.borderRadius = AppRadius.cardR,
    this.blur = false,
    this.color,
    this.borderColor,
    this.child,
  });

  final EdgeInsetsGeometry padding;
  final BorderRadius borderRadius;
  final Color? color;
  final Color? borderColor;

  /// Set to `true` only when this card actually sits over varied content —
  /// see the class doc for why the default is off.
  final bool blur;

  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final s = context.saqqar;

    final body = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? s.cardBg,
        borderRadius: borderRadius,
        border: Border.all(color: borderColor ?? s.cardBorder),
        // Tightened shadows: the old dark-mode shadow (60 blur) was bleeding
        // beyond every card and reading as haze rather than depth.
        boxShadow: context.isDark
            ? [
                BoxShadow(
                  color: const Color(0xFF020617).withValues(alpha: 0.35),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ]
            : [
                BoxShadow(
                  color: const Color(0xFF0F172A).withValues(alpha: 0.06),
                  blurRadius: 3,
                  offset: const Offset(0, 1),
                ),
              ],
      ),
      child: child,
    );

    if (!blur) return body;

    return ClipRRect(
      borderRadius: borderRadius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: body,
      ),
    );
  }
}
