import 'package:flutter/material.dart';

import '../../../shared/extensions/context_extensions.dart';
import '../../../shared/widgets/skeleton_block.dart';
import '../../../core/theme/app_radius.dart';

/// Placeholder shimmer matching the silhouette of a [MessageBubble] row:
/// avatar slot + bubble plate with two text lines. Renders on the assistant
/// side by default; pass `isUser: true` for the right-aligned variant.
///
/// Used during the chat's initial open (before the messages endpoint
/// returns) and during pull-to-refresh.
class MessageBubbleSkeleton extends StatelessWidget {
  const MessageBubbleSkeleton({
    super.key,
    this.isUser = false,
    this.bubbleWidth = 240,
    this.linesCount = 2,
  });

  final bool isUser;
  final double bubbleWidth;
  final int linesCount;

  @override
  Widget build(BuildContext context) {
    final s = context.saqqar;
    const gap = SizedBox(width: 10);
    const avatar = SkeletonBlock(width: 32, height: 32, radius: 16);

    // `maxWidth` + `Flexible`, never a fixed `width`. The avatar and its gap
    // take 42 px of the row, so a 280 px bubble needs a 322 px viewport —
    // 2 px more than the narrowest phone we support, and it overflowed there
    // (found by `overlay_responsive_sweep_test.dart`, 2026-08-04). The screen
    // sweep could never catch it: skeletons are gone by the time a loaded
    // screen is measured.
    final bubble = Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: isUser
            ? s.brandCyan.withValues(alpha: 0.08)
            : s.surface2.withValues(alpha: context.isDark ? 0.55 : 0.86),
        borderRadius: AppRadius.modalR,
        border: Border.all(
          color: isUser ? s.brandCyan.withValues(alpha: 0.18) : s.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < linesCount; i++) ...[
            if (i > 0) const SizedBox(height: 6),
            // Vary widths so the placeholder doesn't read as a uniform block.
            // A ratio rather than `bubbleWidth - 28 - 40`: once the bubble can
            // be narrower than requested, px arithmetic against the *asked-for*
            // width overflows the width it actually got.
            FractionallySizedBox(
              alignment: AlignmentDirectional.centerStart,
              widthFactor: i.isEven ? 1.0 : 0.72,
              child: const SkeletonBlock(height: 11),
            ),
          ],
        ],
      ),
    );

    // Flexible so the bubble yields to the avatar instead of pushing the row
    // past the viewport. `bubbleWidth` becomes a ceiling, not a demand.
    final sized = Flexible(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: bubbleWidth),
        child: bubble,
      ),
    );

    final isRtl = context.isRtl;
    final children = isUser
        ? (isRtl ? [avatar, gap, sized] : [sized, gap, avatar])
        : (isRtl ? [sized, gap, avatar] : [avatar, gap, sized]);

    return Row(
      mainAxisAlignment: isUser
          ? (isRtl ? MainAxisAlignment.start : MainAxisAlignment.end)
          : (isRtl ? MainAxisAlignment.end : MainAxisAlignment.start),
      crossAxisAlignment: CrossAxisAlignment.end,
      children: children,
    );
  }
}
