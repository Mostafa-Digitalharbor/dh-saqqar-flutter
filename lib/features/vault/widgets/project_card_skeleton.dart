import 'package:flutter/material.dart';

import '../../../core/theme/app_radius.dart';
import '../../../shared/extensions/context_extensions.dart';
import '../../../shared/widgets/skeleton_block.dart';
import '../../../core/theme/app_sizes.dart';

/// Placeholder shimmer matching the [ProjectCard] silhouette — header row
/// (icon + name + env count) plus two stub env rows underneath. Replaces
/// the legacy `CredentialRowSkeleton` use in the vault screen so the
/// loading state actually previews the projects-list shape.
class ProjectCardSkeleton extends StatelessWidget {
  const ProjectCardSkeleton({super.key, this.envRows = 2});

  /// Number of env-row stubs to render under the header. Matches the
  /// average env count per project so the skeleton doesn't read as empty.
  final int envRows;

  @override
  Widget build(BuildContext context) {
    final s = context.saqqar;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: s.surface.withValues(alpha: context.isDark ? 0.62 : 0.92),
        borderRadius: AppRadius.cardR,
        border: Border.all(color: s.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.s16,
              AppSpacing.s14,
              AppSpacing.s16,
              AppSpacing.s10,
            ),
            child: Row(
              children: [
                SkeletonBlock(width: 34, height: 34, radius: 10),
                SizedBox(width: AppSpacing.s12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SkeletonBlock(width: 140, height: 14),
                      SizedBox(height: AppSpacing.s6),
                      SkeletonBlock(width: 90, height: 11),
                    ],
                  ),
                ),
                SkeletonBlock(width: 18, height: 18, radius: 6),
                SizedBox(width: AppSpacing.s8),
                SkeletonBlock(width: 18, height: 18, radius: 6),
              ],
            ),
          ),
          for (var i = 0; i < envRows; i++) ...[
            Divider(color: s.border, height: 1),
            const Padding(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.s16,
                AppSpacing.s12,
                AppSpacing.s12,
                AppSpacing.s12,
              ),
              child: Row(
                children: [
                  SkeletonBlock(width: 30, height: 30, radius: 8),
                  SizedBox(width: AppSpacing.s12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SkeletonBlock(width: 110, height: 13),
                        SizedBox(height: AppSpacing.s6),
                        SkeletonBlock(width: 70, height: 10),
                      ],
                    ),
                  ),
                  SkeletonBlock(width: 18, height: 18, radius: 6),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
