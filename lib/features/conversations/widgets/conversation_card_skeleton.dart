import 'package:flutter/material.dart';

import '../../../shared/extensions/context_extensions.dart';
import '../../../shared/widgets/skeleton_block.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_sizes.dart';

/// Placeholder shimmer card matching the [ConversationCard] silhouette —
/// 44-px round avatar + title bar + preview bar + meta dots row.
///
/// Render while the conversations list is loading from the API so users
/// see structure immediately instead of a blank screen.
class ConversationCardSkeleton extends StatelessWidget {
  const ConversationCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.saqqar;
    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.s14,
        AppSpacing.s14,
        AppSpacing.s14,
        AppSpacing.s14,
      ),
      decoration: BoxDecoration(
        color: s.surface.withValues(alpha: context.alpha(AppAlphaPairs.panelSkeleton)),
        // `conversationCardR`, not `modalR`: this stands in for
        // `ConversationCard`, whose corner is 16. It was 18, so every row
        // visibly changed shape at the moment the real list arrived.
        borderRadius: AppRadius.conversationCardR,
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
                SkeletonBlock(width: AppSkeletonSizes.previewLong, height: AppSkeletonSizes.titleLine),
                SizedBox(height: AppSpacing.s10),
                SkeletonBlock(height: AppSkeletonSizes.subtitleLine),
                SizedBox(height: AppSpacing.s6),
                SkeletonBlock(width: AppSkeletonSizes.previewShort, height: AppSkeletonSizes.subtitleLine),
                SizedBox(height: AppSpacing.s12),
                Row(
                  children: [
                    SkeletonBlock(width: AppSkeletonSizes.chipShort, height: AppSkeletonSizes.chipLine, radius: AppRadius.pill),
                    SizedBox(width: AppSpacing.s8),
                    SkeletonBlock(width: AppSkeletonSizes.chipWide, height: AppSkeletonSizes.chipLine, radius: AppRadius.pill),
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
