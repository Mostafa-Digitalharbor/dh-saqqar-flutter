import 'package:flutter/material.dart';

import '../../../core/theme/app_gradients.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/extensions/context_extensions.dart';
import '../../../shared/widgets/responsive_content.dart';

/// Technical-density context / usage meter that mirrors the Saqqar Design
/// System's ChatScreen meter sitting between the env selectors and the
/// message stream:
///
///   [⌬ SAQQÂR·1]   CONTEXT  12.4K / 200K ST   ●42ms
///                  ▰▰▱▱▱▱▱▱▱▱▱▱▱▱▱▱▱▱▱▱
///
/// The numbers are representative (the snapshot API doesn't expose token
/// accounting yet) — derived once from the conversation id so a given
/// chat shows stable figures across rebuilds rather than flickering.
class ChatContextMeter extends StatelessWidget {
  const ChatContextMeter({super.key, required this.conversationId});

  final String conversationId;

  @override
  Widget build(BuildContext context) {
    final s = context.saqqar;
    // Representative token usage — stable per conversation.
    final seed = conversationId.hashCode & 0x7fffffff;
    final usedK = 4 + seed % 60; // 4K..63K
    final fraction = (usedK / 200).clamp(0.02, 0.95);
    final latencyMs = 28 + seed % 80; // 28..107 ms

    return DecoratedBox(
      decoration: BoxDecoration(
        color: s.surface.withValues(alpha: context.isDark ? 0.55 : 0.85),
        border: Border(bottom: BorderSide(color: s.border)),
      ),
      child: ResponsiveContent(
        maxWidth: 980,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
        child: Row(
          children: [
            // Engine badge — cpu glyph + monospace model tag.
            Icon(AppIcons.cpu, size: 13, color: s.brandCyan),
            const SizedBox(width: 5),
            Text(
              'SAQQÂR·1',
              style: context.text.labelMedium?.copyWith(
                color: s.text,
                fontFamily: AppTypography.fontMono,
                fontSize: 11.5,
              ),
            ),
            const SizedBox(width: 12),
            // Context bar + numeric readout.
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'CONTEXT',
                        style: TextStyle(
                          fontFamily: AppTypography.fontSans,
                          fontSize: 9.5,
                          height: 1.2,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                          color: s.muted,
                        ),
                      ),
                      Text(
                        '${usedK}K / 200K ST',
                        style: TextStyle(
                          fontFamily: AppTypography.fontMono,
                          fontSize: 10.5,
                          height: 1.2,
                          color: s.muted,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: Container(
                      height: 4,
                      color: s.surface3,
                      child: FractionallySizedBox(
                        alignment: AlignmentDirectional.centerStart,
                        widthFactor: fraction,
                        child: const DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: AppGradients.primaryCta,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            // Live latency pulse.
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: s.success,
              ),
            ),
            const SizedBox(width: 5),
            Text(
              '${latencyMs}ms',
              style: context.text.labelMedium?.copyWith(
                color: s.success,
                fontSize: 11.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
