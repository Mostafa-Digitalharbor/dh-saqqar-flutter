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

    final bubble = Container(
      width: bubbleWidth,
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < linesCount; i++) ...[
            if (i > 0) const SizedBox(height: 6),
            SkeletonBlock(
              // Vary widths so the placeholder doesn't read as a uniform block.
              width: bubbleWidth - 28 - (i.isEven ? 0 : 40),
              height: 11,
            ),
          ],
        ],
      ),
    );

    final isRtl = context.isRtl;
    final children = isUser
        ? (isRtl ? [avatar, gap, bubble] : [bubble, gap, avatar])
        : (isRtl ? [bubble, gap, avatar] : [avatar, gap, bubble]);

    return Row(
      mainAxisAlignment: isUser
          ? (isRtl ? MainAxisAlignment.start : MainAxisAlignment.end)
          : (isRtl ? MainAxisAlignment.end : MainAxisAlignment.start),
      crossAxisAlignment: CrossAxisAlignment.end,
      children: children,
    );
  }
}
