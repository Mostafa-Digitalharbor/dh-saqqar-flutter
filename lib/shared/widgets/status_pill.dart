import 'package:flutter/material.dart';

import '../../core/theme/app_radius.dart';
import '../../core/theme/app_typography.dart';
import '../extensions/context_extensions.dart';
import '../animations/pulse_dot.dart';

enum StatusPillVariant { success, warning, info, danger }

/// Spec §5.5 — inline status indicator with optional leading pulsing dot.
class StatusPill extends StatelessWidget {
  const StatusPill({
    super.key,
    required this.label,
    this.variant = StatusPillVariant.info,
    this.pulsing = false,
  });

  final String label;
  final StatusPillVariant variant;
  final bool pulsing;

  Color _color(BuildContext context) {
    final s = context.saqqar;
    return switch (variant) {
      StatusPillVariant.success => s.success,
      StatusPillVariant.warning => s.warning,
      StatusPillVariant.info => s.brandCyan,
      StatusPillVariant.danger => s.danger,
    };
  }

  @override
  Widget build(BuildContext context) {
    final color = _color(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: AppRadius.pillR,
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (pulsing) ...[PulseDot(color: color), const SizedBox(width: 6)],
          // Flexible + single-line ellipsis so an unexpectedly long label
          // (or a future caller's longer status) can't overflow the fixed
          // padding when the pill sits in a bounded Row.
          Flexible(
            child: Text(
              label.toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.statusPill(
                locale: context.locale,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
