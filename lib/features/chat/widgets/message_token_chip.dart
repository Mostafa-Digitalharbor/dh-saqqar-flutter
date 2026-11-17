import 'package:flutter/material.dart';

import '../../../core/format/compact_number.dart';
import '../../../core/i18n/app_localizations.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_sizes.dart';
import '../../../shared/extensions/context_extensions.dart';
import '../../conversations/data/conversation_models.dart' show MessageTokens;

/// What one reply cost, beside its timestamp.
///
/// The server meters most assistant replies and sends
/// `tokens: {input, output, cached_input}`; the web has always shown it and
/// the app was dropping it on the floor. On a metered plan that is the
/// difference between "the bill went up this week" and knowing which answer
/// did it.
///
/// The headline is the total. The breakdown — how much of the prompt was
/// served from cache, and what the reply itself cost — rides in a [Tooltip],
/// which is the touch equivalent of the web's hover title: long-press to see
/// it, and no space taken from the transcript until you ask.
class MessageTokenChip extends StatelessWidget {
  const MessageTokenChip({super.key, required this.tokens});

  final MessageTokens tokens;

  @override
  Widget build(BuildContext context) {
    final s = context.saqqar;
    final tr = context.tr;
    // Localised compact form, unlike the web's hardcoded "k"/"M": "51.6k"
    // under an Arabic message is the same half-translated screen this app's
    // i18n rules exist to prevent.
    final total = compactCount(tokens.total, tr);
    return Tooltip(
      message: [
        tr.tokensInput(
          compactCount(tokens.input, tr),
          compactCount(tokens.fresh, tr),
          compactCount(tokens.cachedInput, tr),
          tokens.cacheHitPercent,
        ),
        tr.tokensOutput(compactCount(tokens.output, tr)),
        tr.tokensTotal(total),
      ].join('\n'),
      triggerMode: TooltipTriggerMode.tap,
      // Flutter dismisses a tapped tooltip after 1.5 s, which is tuned for
      // a one-line hint. This is three lines of six-digit numbers, and it
      // was gone before they could be read — verified on a device, where
      // the breakdown had already vanished two seconds after the tap.
      showDuration: const Duration(seconds: 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(AppIcons.bolt, size: AppIconSizes.metaTight, color: s.muted),
          const SizedBox(width: AppSpacing.s2),
          Text(
            tr.tokensChipLabel(total),
            style: context.text.labelSmall?.copyWith(
              color: s.muted,
              fontSize: AppFontSizes.pillLabel,
              fontWeight: FontWeight.w600,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}
