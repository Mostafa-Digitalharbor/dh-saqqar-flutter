import 'package:flutter/material.dart';

import '../../../core/constants/ui_strings.dart';
import '../../../core/i18n/app_localizations.dart';
import '../../../core/theme/app_gradients.dart';
import '../../../shared/extensions/context_extensions.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/widgets/mini_chip.dart';
import 'stats_line.dart';

/// Identity card at the top of the simplified Account tab — gradient avatar,
/// username headline, role chip, compact stats line, and the
/// "Powered by Digital Harbor" footer.
///
/// [onLongPress] is the storybook easter egg — long-press the username to
/// open the dev showcase. Hidden because storybook is not a user feature.
class ProfileHero extends StatelessWidget {
  const ProfileHero({super.key, this.onLongPress});

  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final s = context.saqqar;

    return GlassCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 64,
                height: 64,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: AppGradients.vivid,
                  border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
                ),
                child: const Text(
                  UiStrings.demoUserInitial,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GestureDetector(
                      onLongPress: onLongPress,
                      behavior: HitTestBehavior.opaque,
                      child: Text(
                        UiStrings.demoUsername,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.text.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.3,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    MiniChip(context.tr.standardUser),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const StatsLine(),
          const SizedBox(height: 6),
          Text(
            context.tr.poweredByDigitalHarbor,
            style: context.text.labelSmall?.copyWith(
              color: s.muted,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
