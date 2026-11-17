import 'package:flutter/material.dart';

import '../../../core/i18n/app_localizations.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_sizes.dart';
import '../../../shared/extensions/context_extensions.dart';
import '../data/chat_view_models.dart';
import 'chat_markdown.dart';

/// Collapsible "Saqqar thinking" pill that groups all the intermediate
/// agent steps a single user turn produced — describe-model lookups,
/// SQL probes, multi-step reasoning — so the chat reads as
/// **one user question → one final answer**, with the messy middle
/// tucked behind a chevron the user can pop open when they want to
/// audit the work.
///
/// Web parity: matches the "Saqqar thinking · 3 steps · 14s" pill the
/// `chat-v2` web view renders above the final assistant reply.
///
/// Empty [steps] is invalid — callers should skip rendering this widget
/// entirely when there's nothing to group (single-message turns).
class ChatThinkingPill extends StatefulWidget {
  const ChatThinkingPill({super.key, required this.steps, this.totalDuration});

  /// Intermediate assistant messages (everything between the user turn
  /// and the final assistant reply). The widget renders them in order,
  /// each as a bullet with the message body inline.
  final List<ChatMessage> steps;

  /// Wall-clock time the agent spent thinking — first step's createdAt
  /// → final reply's createdAt. Rendered as `· 14s` / `· 1m 30s` next
  /// to the step count. Skipped when null (creates a tighter header).
  final Duration? totalDuration;

  @override
  State<ChatThinkingPill> createState() => _ChatThinkingPillState();
}

class _ChatThinkingPillState extends State<ChatThinkingPill> {
  bool _expanded = false;

  String _durationLabel(Duration d) {
    final secs = d.inSeconds;
    if (secs < 60) return '${secs}s';
    final mins = d.inMinutes;
    final remSecs = secs - mins * 60;
    return remSecs == 0 ? '${mins}m' : '${mins}m ${remSecs}s';
  }

  @override
  Widget build(BuildContext context) {
    final s = context.saqqar;
    final accent = s.brandCyan;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: Colors.transparent,
          borderRadius: AppRadius.pillR,
          child: InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: AppRadius.pillR,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.s12,
                vertical: AppSpacing.s7,
              ),
              decoration: BoxDecoration(
                color: accent.withValues(
                  alpha: context.alpha(AppAlphaPairs.tintFaint),
                ),
                borderRadius: AppRadius.pillR,
                border: Border.all(
                  color: accent.withValues(alpha: AppAlphas.a34),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Soft pulsing dot — same accent as the agent's
                  // "working" pill so the visual language stays unified.
                  Container(
                    width: AppBoxSizes.dot,
                    height: AppBoxSizes.dot,
                    decoration: BoxDecoration(
                      color: accent,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.s8),
                  // Both copy-bearing labels are `Flexible` + ellipsis: the
                  // row is `mainAxisSize.min`, which only means "don't
                  // expand" — it does NOT stop the children overflowing the
                  // incoming constraint. At 320 px the Arabic rendering
                  // ("صقّار يفكّر · 3 خطوات تفكير · 1m 23s") plus the chevron
                  // exceeds the ~280 px the list leaves this pill, so
                  // without these the row throws a RenderFlex overflow.
                  // The separators, duration and chevron stay rigid — they
                  // are a few glyphs each and are what the user needs most.
                  Flexible(
                    child: Text(
                      context.tr.saqqarThinking,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.labelMedium?.copyWith(
                        color: accent,
                        fontWeight: FontWeight.w800,
                        fontSize: AppFontSizes.pillTitle,
                      ),
                    ),
                  ),
                  Text(
                    ' · ',
                    style: TextStyle(
                      color: accent.withValues(alpha: AppAlphas.a60),
                      fontSize: AppFontSizes.pillTitle,
                    ),
                  ),
                  Flexible(
                    child: Text(
                      context.tr.thinkingSteps(widget.steps.length),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.labelSmall?.copyWith(
                        color: accent.withValues(alpha: AppAlphas.a85),
                        fontWeight: FontWeight.w600,
                        fontSize: AppFontSizes.pillLabel,
                      ),
                    ),
                  ),
                  if (widget.totalDuration != null) ...[
                    Text(
                      ' · ',
                      style: TextStyle(
                        color: accent.withValues(alpha: AppAlphas.a60),
                        fontSize: AppFontSizes.pillTitle,
                      ),
                    ),
                    Text(
                      _durationLabel(widget.totalDuration!),
                      style: context.text.labelSmall?.copyWith(
                        color: accent.withValues(alpha: AppAlphas.a85),
                        fontWeight: FontWeight.w600,
                        fontSize: AppFontSizes.pillLabel,
                      ),
                    ),
                  ],
                  const SizedBox(width: AppSpacing.s6),
                  AnimatedRotation(
                    duration: AppDurations.fast,
                    turns: _expanded ? 0.5 : 0,
                    child: Icon(
                      AppIcons.chevronDown,
                      size: AppIconSizes.small,
                      color: accent.withValues(alpha: AppAlphas.a85),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        // Body: one bulleted line per step. AnimatedSize + AnimatedCrossFade
        // keep the open/close transition matched to the chevron rotation.
        AnimatedSize(
          duration: AppDurations.cardIn,
          curve: Curves.easeOutCubic,
          alignment: Alignment.topLeft,
          child: AnimatedCrossFade(
            duration: AppDurations.fast,
            firstChild: const SizedBox(width: double.infinity, height: 0),
            secondChild: Padding(
              padding: const EdgeInsetsDirectional.only(
                start: AppSpacing.s6,
                top: AppSpacing.s10,
                bottom: AppSpacing.s6,
              ),
              child: Container(
                padding: const EdgeInsetsDirectional.only(
                  start: AppSpacing.s10,
                ),
                decoration: BoxDecoration(
                  border: BorderDirectional(
                    start: BorderSide(
                      color: accent.withValues(alpha: AppAlphas.a35),
                      width: AppBorderWidths.ring,
                    ),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var i = 0; i < widget.steps.length; i++) ...[
                      if (i > 0) const SizedBox(height: AppSpacing.s10),
                      _StepBullet(step: widget.steps[i], accent: accent),
                    ],
                  ],
                ),
              ),
            ),
            crossFadeState: _expanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
          ),
        ),
      ],
    );
  }
}

class _StepBullet extends StatelessWidget {
  const _StepBullet({required this.step, required this.accent});

  final ChatMessage step;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final s = context.saqqar;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: AppSpacing.s6),
          child: Container(
            width: AppControlSizes.dotSmall,
            height: AppControlSizes.dotSmall,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: AppAlphas.a70),
              shape: BoxShape.circle,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.s8),
        Expanded(
          child: DefaultTextStyle.merge(
            style: context.text.bodySmall?.copyWith(
              color: s.muted,
              height: AppLineHeights.body,
              fontSize: AppFontSizes.pillTitle,
            ),
            child: ChatMarkdown(data: step.content, isUser: false),
          ),
        ),
      ],
    );
  }
}
