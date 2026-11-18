import 'package:flutter/material.dart';

import '../../../shared/animations/typing_dots.dart';
import '../../../shared/fig/fig.dart';
import '../../../core/i18n/app_localizations.dart';
import '../../../core/constants/asset_paths.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_sizes.dart';
import '../../../core/theme/fig_metrics.dart';
import '../../../core/theme/app_colors.dart';

/// "Saqqar Assistant is typing" row: orb avatar, small name label and a dark
/// bubble holding the three typing dots (plus the live tool-status label).
class ChatTypingRow extends StatelessWidget {
  const ChatTypingRow({
    super.key,
    required this.firstOfGroup,
    this.statusLabel,
  });

  final bool firstOfGroup;
  final String? statusLabel;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipOval(
          child: Image.asset(
            AssetPaths.orb,
            width: FigMetrics.size36, height: FigMetrics.size36,
            fit: BoxFit.cover,
          ),
        ),
        const SizedBox(width: AppSpacing.s10),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.s4),
                child: Text(
                  context.tr.figSaqqarAssistant,
                  style: Fig.t(
                    context,
                    size: FigMetrics.fontFig10,
                    weight: FontWeight.w600,
                    color: AppColors.figWhite.withValues(alpha: AppAlphas.a80),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.s18,
                  vertical: AppSpacing.s14,
                ),
                decoration: BoxDecoration(
                  color: Fig.navyDeep.withValues(alpha: AppAlphas.a90),
                  borderRadius: const BorderRadiusDirectional.only(
                    topStart: Radius.circular(AppRadius.badge),
                    topEnd: Radius.circular(AppRadius.bubble),
                    bottomStart: Radius.circular(AppRadius.bubble),
                    bottomEnd: Radius.circular(AppRadius.bubble),
                  ),
                  border: Border.all(
                    color: AppColors.figWhite.withValues(alpha: AppAlphas.a07),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TypingDots(
                      color: AppColors.figWhite.withValues(alpha: AppAlphas.a55),
                      dotSize: AppIconSizes.overlay,
                    ),
                    if (statusLabel != null) ...[
                      const SizedBox(width: AppSpacing.s10),
                      Flexible(
                        child: AnimatedSwitcher(
                          duration: AppDurations.cardIn,
                          switchInCurve: Curves.easeOut,
                          switchOutCurve: Curves.easeIn,
                          layoutBuilder: (current, previous) => Stack(
                            alignment: AlignmentDirectional.centerStart,
                            children: [
                              ...previous,
                              if (current != null) current,
                            ],
                          ),
                          transitionBuilder: (child, animation) =>
                              FadeTransition(opacity: animation, child: child),
                          child: Text(
                            statusLabel!,
                            key: ValueKey<String>(statusLabel!),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Fig.t(
                              context,
                              size: AppFontSizes.microCaps,
                              color: AppColors.figWhite.withValues(alpha: AppAlphas.a80),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
