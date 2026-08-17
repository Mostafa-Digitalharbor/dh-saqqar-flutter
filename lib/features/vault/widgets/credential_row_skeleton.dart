import 'package:flutter/material.dart';

import '../../../shared/extensions/context_extensions.dart';
import '../../../shared/widgets/skeleton_block.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_sizes.dart';

/// Placeholder shimmer matching the [CredentialRow] silhouette — kind-icon
/// plate + label + bundle name + two pill chips.
class CredentialRowSkeleton extends StatelessWidget {
  const CredentialRowSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.saqqar;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.s14),
      decoration: BoxDecoration(
        color: s.surface.withValues(alpha: context.isDark ? 0.62 : 0.88),
        borderRadius: AppRadius.bubbleR,
        border: Border.all(color: s.cardBorder),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SkeletonBlock(width: 44, height: 44, radius: 12),
          SizedBox(width: AppSpacing.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonBlock(width: 160, height: 14),
                SizedBox(height: AppSpacing.s8),
                SkeletonBlock(width: 220, height: 11),
                SizedBox(height: AppSpacing.s12),
                Row(
                  children: [
                    SkeletonBlock(width: 70, height: 16, radius: 999),
                    SizedBox(width: AppSpacing.s8),
                    SkeletonBlock(width: 110, height: 16, radius: 999),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
