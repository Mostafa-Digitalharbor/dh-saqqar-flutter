import 'package:flutter/material.dart';

import '../../../shared/animations/typing_dots.dart';
import '../../../shared/fig/fig.dart';
import '../../../core/i18n/app_localizations.dart';
import '../../../core/constants/asset_paths.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_sizes.dart';

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
            width: 36,
            height: 36,
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
                    size: 10,
                    weight: FontWeight.w600,
                    color: Colors.white.withValues(alpha: 0.8),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: Fig.navyDeep.withValues(alpha: 0.9),
                  borderRadius: const BorderRadiusDirectional.only(
                    topStart: Radius.circular(4),
                    topEnd: Radius.circular(16),
                    bottomStart: Radius.circular(16),
                    bottomEnd: Radius.circular(16),
                  ),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.07),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TypingDots(
                      color: Colors.white.withValues(alpha: 0.55),
                      dotSize: 9,
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
                              size: 12,
                              color: Colors.white.withValues(alpha: 0.8),
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
