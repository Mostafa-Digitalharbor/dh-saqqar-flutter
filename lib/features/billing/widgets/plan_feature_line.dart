import 'package:flutter/material.dart';

import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_sizes.dart';
import '../../../shared/extensions/context_extensions.dart';

/// One bullet from a tier's feature list, as saqqaar.com/pricing draws them.
///
/// Shared by the pricing catalogue and the account's current-plan card so the
/// two describe a plan in the same words. They previously did not: the account
/// card listed two token caps in "ST" and the catalogue drew a tick/cross
/// matrix, and neither was anything the website says.
///
/// Every bullet a tier lists is *included* in it, so there is no absent state
/// to draw — the check is decoration, not a value.
class PlanFeatureLine extends StatelessWidget {
  const PlanFeatureLine({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final s = context.saqqar;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.s4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            // Nudged to sit on the first line's cap height rather than
            // centring against a bullet that may wrap to three lines.
            padding: const EdgeInsets.only(top: AppSpacing.s2),
            child: Icon(AppIcons.check, size: AppIconSizes.small, color: s.brandCyan),
          ),
          const SizedBox(width: AppSpacing.s8),
          // Expanded + wrap so a long Arabic bullet (at up to 1.4x text scale
          // on a narrow phone) wraps instead of overflowing the row — a Row
          // hands its non-flex children unbounded width, so a bare Text here
          // would neither wrap nor ellipsize.
          Expanded(
            child: Text(
              label,
              style: context.text.bodyMedium?.copyWith(height: AppLineHeights.label),
            ),
          ),
        ],
      ),
    );
  }
}
