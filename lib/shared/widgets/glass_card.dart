import 'dart:ui';

import 'package:flutter/material.dart';

import '../../core/theme/app_radius.dart';
import '../extensions/context_extensions.dart';

/// Spec §5.1 glass panel — translucent fill + 14px backdrop blur + 1px border.
///
/// Use sparingly. Long scrolling lists should use opaque [Material] surfaces
/// instead because backdrop blur is expensive on mobile (per §5.1 mobile note).
class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    this.padding = const EdgeInsets.all(16),
    this.borderRadius = AppRadius.cardR,
    this.blur = true,
    this.color,
    this.borderColor,
    this.child,
  });

  final EdgeInsetsGeometry padding;
  final BorderRadius borderRadius;
  final Color? color;
  final Color? borderColor;

  /// Set to `false` to skip the [BackdropFilter] cost on long lists.
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
        boxShadow: context.isDark
            ? [
                BoxShadow(
                  color: const Color(0xFF020617).withValues(alpha: 0.55),
                  blurRadius: 60,
                  offset: const Offset(0, 22),
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
