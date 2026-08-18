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
        color: s.surface.withValues(alpha: context.alpha(AppAlphaPairs.panelSkeleton)),
        borderRadius: AppRadius.bubbleR,
        border: Border.all(color: s.cardBorder),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SkeletonBlock.circle(size: AppSkeletonSizes.avatar),
          SizedBox(width: AppSpacing.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonBlock(width: AppSkeletonSizes.titleLong, height: AppSkeletonSizes.titleLine),
                SizedBox(height: AppSpacing.s8),
                SkeletonBlock(width: AppSkeletonSizes.previewLong, height: AppSkeletonSizes.subtitleLine),
                SizedBox(height: AppSpacing.s12),
                Row(
                  children: [
                    SkeletonBlock(width: AppSkeletonSizes.chip, height: AppSkeletonSizes.tagLine, radius: AppRadius.pill),
                    SizedBox(width: AppSpacing.s8),
                    SkeletonBlock(width: AppSkeletonSizes.subtitle, height: AppSkeletonSizes.tagLine, radius: AppRadius.pill),
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
