import 'package:flutter/material.dart';

import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_sizes.dart';
import '../../../shared/extensions/context_extensions.dart';

/// The card body every accented in-chat card wears: a translucent surface, a
/// hairline border, and a 4 px accent rail down the inline-start edge.
///
/// Extracted because `chat_approval_card.dart` and `interactive_card_shell.dart`
/// carried this chrome twice, character for character — the same fill alpha
/// split by theme, the same `AppRadius.bubbleR`, the same `Stack` +
/// `PositionedDirectional` rail, the same `fromSTEB(18, 14, 14, 14)` inset.
/// Only the accent colour differed.
///
/// That duplication was not cosmetic. The rail's own corner had to match the
/// card's outer radius to sit flush, and both files hard-coded it as
/// `Radius.circular(16)` rather than reading the card's token — so re-shaping
/// the card would have left two rails poking out of two different corners,
/// and only one of them is on a screen anyone opens often.
///
/// The rail is [PositionedDirectional] rather than `Positioned` so it stays on
/// the *inline* start: left in English, right in Arabic. A `Positioned(left:)`
/// would pin it to the left of an Arabic card, on the side the text ends.
class AccentCardChrome extends StatelessWidget {
  const AccentCardChrome({
    super.key,
    required this.accent,
    required this.child,
  });

  /// The rail colour, and the card's whole meaning. Amber says "a decision
  /// with consequences is waiting"; cyan says "Saqqar needs input before it
  /// starts".
  final Color accent;

  /// The card's contents, already laid out as a column. The chrome supplies
  /// the padding around it.
  final Widget child;

  /// Inset for the card body. Larger on the start edge because the accent rail
  /// occupies the first 4 px and the text would otherwise crowd it.
  static const EdgeInsetsDirectional contentPadding =
      EdgeInsetsDirectional.fromSTEB(AppSpacing.s18, AppSpacing.s14, AppSpacing.s14, AppSpacing.s14);

  /// Width of the accent rail.
  static const double railWidth = 4;

  @override
  Widget build(BuildContext context) {
    final s = context.saqqar;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: s.surface.withValues(alpha: context.isDark ? 0.62 : 0.92),
        borderRadius: AppRadius.bubbleR,
        border: Border.all(color: s.cardBorder),
      ),
      child: Stack(
        children: [
          PositionedDirectional(
            start: 0,
            top: 0,
            bottom: 0,
            child: Container(
              width: railWidth,
              decoration: BoxDecoration(
                color: accent,
                borderRadius: AppRadius.accentRailR,
              ),
            ),
          ),
          Padding(padding: contentPadding, child: child),
        ],
      ),
    );
  }
}
