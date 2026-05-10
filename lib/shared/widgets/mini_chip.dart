import 'package:flutter/material.dart';

import '../../core/theme/app_radius.dart';
import '../../core/theme/app_typography.dart';
import '../extensions/context_extensions.dart';

/// Spec §5.6 — small uppercase chip used in panel headers and credential
/// cards. Cyan-soft background, cyan border, cyan text.
class MiniChip extends StatelessWidget {
  const MiniChip(this.text, {super.key, this.color});

  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final s = context.saqqar;
    final c = color ?? s.brandCyan;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.16),
        borderRadius: AppRadius.pillR,
        border: Border.all(color: c.withValues(alpha: 0.30)),
      ),
      child: Text(
        text.toUpperCase(),
        style: AppTypography.statusPill(locale: context.locale, color: c),
      ),
    );
  }
}
