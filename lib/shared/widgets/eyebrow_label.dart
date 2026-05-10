import 'package:flutter/material.dart';

import '../../core/theme/app_typography.dart';
import '../extensions/context_extensions.dart';

/// Spec §5.7 — tiny uppercase label above a heading or panel.
/// 11pt, weight 700, +0.10em tracking, brand-cyan by default.
class EyebrowLabel extends StatelessWidget {
  const EyebrowLabel(this.text, {super.key, this.color});

  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final s = context.saqqar;
    return Text(
      text.toUpperCase(),
      style: AppTypography.eyebrow(
        locale: context.locale,
        color: color ?? s.brandCyan,
      ),
    );
  }
}
