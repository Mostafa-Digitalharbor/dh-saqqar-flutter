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
        color: s.surface.withValues(alpha: context.isDark ? 0.62 : 0.88),
        borderRadius: AppRadius.modalR,
        border: Border.all(color: s.cardBorder),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SkeletonBlock(width: 44, height: 44, radius: 22),
          SizedBox(width: AppSpacing.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonBlock(width: 220, height: 14),
                SizedBox(height: AppSpacing.s10),
                SkeletonBlock(height: 11),
                SizedBox(height: AppSpacing.s6),
                SkeletonBlock(width: 180, height: 11),
                SizedBox(height: AppSpacing.s12),
                Row(
                  children: [
                    SkeletonBlock(width: 50, height: 10, radius: 999),
                    SizedBox(width: AppSpacing.s8),
                    SkeletonBlock(width: 80, height: 10, radius: 999),
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
