import 'package:flutter/material.dart';

import '../../../core/theme/app_radius.dart';
import '../../../shared/extensions/context_extensions.dart';
import '../../../shared/widgets/skeleton_block.dart';
import '../../../core/theme/app_sizes.dart';

/// Placeholder shimmer matching the [ProjectCard] silhouette — header row
/// (icon + name + env count) plus two stub env rows underneath.
///
/// This is the vault's only loading placeholder. It replaced a
/// credential-row shimmer that previewed the wrong shape; that widget kept
/// being swept and conformance-tested for a while after its last call site
/// went, which is the only reason it looked alive.
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
        color: s.surface.withValues(
          alpha: context.alpha(AppAlphaPairs.panelOpaque),
        ),
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
                SkeletonBlock(
                  width: AppSkeletonSizes.tileLarge,
                  height: AppSkeletonSizes.tileLarge,
                  radius: AppRadius.small,
                ),
                SizedBox(width: AppSpacing.s12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SkeletonBlock(
                        width: AppSkeletonSizes.title,
                        height: AppSkeletonSizes.titleLine,
                      ),
                      SizedBox(height: AppSpacing.s6),
                      SkeletonBlock(
                        width: AppSkeletonSizes.subtitleShort,
                        height: AppSkeletonSizes.subtitleLine,
                      ),
                    ],
                  ),
                ),
                SkeletonBlock(
                  width: AppSkeletonSizes.actionSquare,
                  height: AppSkeletonSizes.actionSquare,
                  radius: AppRadius.micro,
                ),
                SizedBox(width: AppSpacing.s8),
                SkeletonBlock(
                  width: AppSkeletonSizes.actionSquare,
                  height: AppSkeletonSizes.actionSquare,
                  radius: AppRadius.micro,
                ),
              ],
            ),
          ),
          for (var i = 0; i < envRows; i++) ...[
            Divider(color: s.border, height: AppBorderWidths.hairline),
            const Padding(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.s16,
                AppSpacing.s12,
                AppSpacing.s12,
                AppSpacing.s12,
              ),
              child: Row(
                children: [
                  SkeletonBlock(
                    width: AppSkeletonSizes.tile,
                    height: AppSkeletonSizes.tile,
                    radius: AppRadius.tight,
                  ),
                  SizedBox(width: AppSpacing.s12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SkeletonBlock(
                          width: AppSkeletonSizes.subtitle,
                          height: AppSkeletonSizes.denseLine,
                        ),
                        SizedBox(height: AppSpacing.s6),
                        SkeletonBlock(
                          width: AppSkeletonSizes.chip,
                          height: AppSkeletonSizes.chipLine,
                        ),
                      ],
                    ),
                  ),
                  SkeletonBlock(
                    width: AppSkeletonSizes.actionSquare,
                    height: AppSkeletonSizes.actionSquare,
                    radius: AppRadius.micro,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
