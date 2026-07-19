import 'package:flutter/material.dart';

import '../../../shared/extensions/context_extensions.dart';
import '../../../core/theme/app_radius.dart';

/// Plan-name pill — cyan accent, matches the web's plan badge. Shown top-right
/// of the "Plan & usage" card and beside the user name in the profile hero
/// (Gap A). Only render this for non-free plans (see `PlanSnapshot.showBadge`).
class PlanBadge extends StatelessWidget {
  const PlanBadge({super.key, required this.name, this.dense = false});

  final String name;

  /// Tighter padding + smaller text for inline use next to the username.
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final s = context.saqqar;
    return Container(
      padding: dense
          ? const EdgeInsets.symmetric(horizontal: 8, vertical: 2)
          : const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: s.brandCyan.withValues(alpha: 0.12),
        borderRadius: AppRadius.pillR,
        border: Border.all(color: s.brandCyan.withValues(alpha: 0.35)),
      ),
      child: Text(
        name,
        style: (dense ? context.text.labelSmall : context.text.labelMedium)
            ?.copyWith(
          color: s.brandCyan,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
