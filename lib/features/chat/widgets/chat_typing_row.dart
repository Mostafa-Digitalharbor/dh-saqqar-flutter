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

    final avatarSlot = SizedBox(
      width: 32,
      child: firstOfGroup
          ? const ChatAvatar(isUser: false)
          : const SizedBox.shrink(),
    );
    const gap = SizedBox(width: 10);

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
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  switchInCurve: Curves.easeOut,
                  switchOutCurve: Curves.easeIn,
                  transitionBuilder: (child, animation) {
                    return FadeTransition(
                      opacity: animation,
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0, 0.15),
                          end: Offset.zero,
                        ).animate(animation),
                        child: child,
                      ),
                    );
                  },
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
    final children = isRtl
        ? [bubble, gap, avatarSlot]
        : [avatarSlot, gap, bubble];

    return Row(
      mainAxisAlignment: isRtl
          ? MainAxisAlignment.end
          : MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: children,
    );
  }
}
