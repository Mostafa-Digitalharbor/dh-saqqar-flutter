import 'package:flutter/material.dart';

import '../../../shared/animations/scanline_overlay.dart';
import '../../../shared/animations/typing_dots.dart';
import '../../../shared/extensions/context_extensions.dart';
import 'chat_avatar.dart';

/// The "Saqqar is typing…" row — assistant avatar (only on the first row of
/// a group) + a neutral bubble containing three pulsing [TypingDots]. When
/// [statusLabel] is set, the label sits beside the dots so the user gets
/// the contextual progress text the web shows ("Checking Odoo data",
/// "Building Excel report", etc.).
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
    final s = context.saqqar;

    // Compact slot — wordmark sized so it hugs the bubble's start edge
    // instead of feeling like a full avatar's worth of space.
    final avatarSlot = SizedBox(
      width: 50,
      child: firstOfGroup
          ? const Align(
              alignment: AlignmentDirectional.centerStart,
              child: ChatAvatar(isUser: false),
            )
          : const SizedBox.shrink(),
    );
    const gap = SizedBox(width: 8);

    final bubble = ScanlineOverlay(
      color: s.brandCyan,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 18, 12),
        decoration: BoxDecoration(
          color: s.surface2,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: s.brandCyan.withValues(alpha: 0.28)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            TypingDots(color: s.muted, dotSize: 7),
            if (statusLabel != null) ...[
              const SizedBox(width: 10),
              Flexible(
                // Crossfade between status labels so the user perceives
                // the agent moving from one tool to the next rather than
                // a hard text swap. 220 ms matches the rest of the chat's
                // motion language (FadeSlideIn message bubbles).
                //
                // Pure FadeTransition (no slide). The earlier slide
                // offset competed with the user's own scroll velocity
                // when the typing row was near a viewport edge — the
                // 2-3 px sub-pixel translate every tick read as drift,
                // not motion. A fade is enough signal for "the agent's
                // status just changed" and stays calm under scroll.
                // `layoutBuilder` keeps the outgoing child inline so
                // the row's intrinsic width doesn't snap during the
                // crossfade window.
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
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
                    style: context.text.bodySmall?.copyWith(
                      color: s.muted,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );

    final isRtl = context.isRtl;
    // The bubble MUST be Flexible in the outer row: its inner status-label
    // Flexible only ellipsizes once the bubble itself is width-bounded.
    // Without this, a long tool-status label ("Checking Odoo data…") grows
    // the bubble past the screen and overflows the row while Saqqar replies.
    final boundedBubble = Flexible(child: bubble);
    final children = isRtl
        ? [boundedBubble, gap, avatarSlot]
        : [avatarSlot, gap, boundedBubble];

    return Row(
      mainAxisAlignment: isRtl
          ? MainAxisAlignment.end
          : MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: children,
    );
  }
}
