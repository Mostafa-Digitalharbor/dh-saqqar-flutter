import 'package:flutter/material.dart';

import '../../core/theme/app_radius.dart';
import '../../core/theme/app_typography.dart';
import '../extensions/context_extensions.dart';
import 'text_scale_lock.dart';
import '../../core/theme/app_sizes.dart';

/// Spec §5.6 — small uppercase chip used in panel headers and credential
/// cards. Cyan-soft background, cyan border, cyan text.
///
/// Text scale is locked at 1.0 — the chip's fixed-pixel padding + small
/// font size don't survive accessibility scaling without clipping, and
/// the chip's role is supplementary status (LIVE, READ-ONLY, AUTO).
/// Surrounding body copy still respects the user's system text scale.
class MiniChip extends StatelessWidget {
  const MiniChip(this.text, {super.key, this.color});

  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final s = context.saqqar;
    final c = color ?? s.brandCyan;
    return TextScaleLock(
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s8,
          vertical: AppSpacing.s4,
        ),
        decoration: BoxDecoration(
          color: c.withValues(alpha: 0.16),
          borderRadius: AppRadius.pillR,
          border: Border.all(color: c.withValues(alpha: 0.30)),
        ),
        child: Text(
          text.toUpperCase(),
          style: AppTypography.statusPill(locale: context.locale, color: c),
        ),
      ),
    );
  }
}
