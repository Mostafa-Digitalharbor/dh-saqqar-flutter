import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../shared/fig/fig.dart';
import '../../../core/theme/app_sizes.dart';

/// One bullet from a tier's feature list: a grey ring-check and the text.
///
/// Shared by the pricing catalogue and the account's current-plan card. Every
/// bullet a tier lists is *included*, so the check is decoration.
class PlanFeatureLine extends StatelessWidget {
  const PlanFeatureLine({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.s7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: AppSpacing.s1),
            child: Icon(
              LucideIcons.circleCheck,
              size: 18,
              color: Color(0xFF8D93A5),
            ),
          ),
          const SizedBox(width: AppSpacing.s10),
          Expanded(
            child: Text(
              label,
              style: Fig.t(
                context,
                size: 12.5,
                color: Fig.mutedGrey,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
