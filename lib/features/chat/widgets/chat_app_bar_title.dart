import 'package:flutter/material.dart';

import '../../../core/i18n/app_localizations.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_radius.dart';
import '../../../shared/extensions/context_extensions.dart';
import '../../../shared/widgets/marquee_text.dart';
import '../../../shared/widgets/text_scale_lock.dart';

/// AppBar title slot for the chat screen: conversation title + a
/// subtitle row showing the active credential + env flag badges
/// (LIVE / READ-ONLY) when relevant + an "Auto-approve on" pill.
///
/// Pure presentational — all the data comes from the parent
/// (chat_screen). The screen resolves the title from the live
/// snapshot, so the AppBar updates whenever a poll tick lands a fresh
/// `conversation.title`.
///
/// Tapping the row opens the credential picker. A small inline edit
/// pencil sits next to the title — tapping it opens the rename dialog
/// (web parity for `#renameButton`).
class ChatAppBarTitle extends StatelessWidget {
  const ChatAppBarTitle({
    super.key,
    required this.title,
    required this.activeCredentialLabel,
    required this.autoApprove,
    required this.onCredentialTap,
    this.envIsLive = false,
    this.envReadOnly = false,
    this.onRenameTap,
    this.agentBusy = false,
  });

  /// Already-resolved conversation title. Falls back to the localized
  /// "Untitled conversation" label below when blank — the parent
  /// shouldn't pass placeholder text like "Start a conversation"; it
  /// should pass the empty string and let the widget format it.
  final String title;

  /// Subtitle text — the env name, or "No environment picked" copy.
  final String activeCredentialLabel;

  final bool autoApprove;

  /// When true, render the amber LIVE badge next to [activeCredentialLabel].
  /// The bound env's `environment.is_live` is the source of truth.
  final bool envIsLive;

  /// When true, render the cyan READ-ONLY badge next to [activeCredentialLabel].
  /// The bound env's `environment.read_only` is the source of truth.
  final bool envReadOnly;

  final VoidCallback onCredentialTap;
  final VoidCallback? onRenameTap;

  /// When true, a small "Working" pill with a pulsing cyan dot is rendered
  /// next to the conversation title. Surfaces global agent-running state
  /// from anywhere in the chat — even if the user scrolled away from the
  /// typing row. Web parity (`#streamingPill` in chat-v2 layout).
  final bool agentBusy;

  @override
  Widget build(BuildContext context) {
    final s = context.saqqar;
    final displayTitle = title.trim().isEmpty
        ? context.tr.untitledConversation
        : title;

    return InkWell(
      onTap: onCredentialTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(4, 4, 4, 4),
        child: Row(
          children: [
            // The gradient sparkles avatar was retired on 2026-05-17 —
            // the hamburger leading + the agent's gradient wordmark in
            // each message body already establish "Saqqar speaking".
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      // Long conversation titles scroll horizontally so
                      // the user can read the whole thing instead of
                      // hitting a cropped "Reschedule yesterday's…"
                      // ellipsis. Short titles render as static text.
                      Flexible(
                        child: MarqueeText(
                          text: displayTitle,
                          style: context.text.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            height: 1.15,
                            letterSpacing: -0.1,
                          ),
                        ),
                      ),
                      if (onRenameTap != null) ...[
                        const SizedBox(width: 4),
                        InkResponse(
                          onTap: onRenameTap,
                          radius: 18,
                          customBorder: const CircleBorder(),
                          child: Padding(
                            padding: const EdgeInsets.all(4),
                            child: Icon(
                              AppIcons.edit,
                              size: 13,
                              color: s.muted,
                            ),
                          ),
                        ),
                      ],
                      if (agentBusy) ...[
                        const SizedBox(width: 8),
                        const _AgentWorkingPill(),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  // Subtitle uses Wrap so the env-flag badges (LIVE /
                  // READ-ONLY / AUTO) flow to a second row on narrow
                  // phones instead of fighting the env name for the
                  // last few pixels. `crossAxisAlignment.center` keeps
                  // the dot + badges visually aligned with the text.
                  Wrap(
                    spacing: 6,
                    runSpacing: 3,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: s.success,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          ConstrainedBox(
                            // Cap derived from screen width (was a fixed
                            // 220) so a long env name can't exceed the title
                            // slot and overflow the subtitle row on ~320px
                            // phones, while still capping on roomy screens.
                            constraints: BoxConstraints(
                              maxWidth: (MediaQuery.sizeOf(context).width * 0.5)
                                  .clamp(120.0, 220.0),
                            ),
                            child: Text(
                              activeCredentialLabel,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: context.text.labelSmall?.copyWith(
                                color: s.muted,
                                fontWeight: FontWeight.w600,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ],
                      ),
                      // Env-flag badges — render only when the bound
                      // env actually carries the flag. LIVE is amber
                      // (the user should notice they're about to
                      // operate on production); READ-ONLY is cyan
                      // (informational, less alarming). Both can show
                      // together; on narrow phones they wrap below the
                      // env name instead of clipping it.
                      if (envIsLive)
                        const _EnvFlagBadge(variant: _EnvFlagVariant.live),
                      if (envReadOnly)
                        const _EnvFlagBadge(
                          variant: _EnvFlagVariant.readOnly,
                        ),
                      if (autoApprove) _AutoApprovePill(),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Small "Working" pill rendered next to the conversation title while the
/// agent is processing a turn. The pulsing cyan dot announces live state to
/// users who scrolled away from the typing row; the static "Working" text
/// gives screen-reader users the same signal via aria-live-equivalent
/// semantics (Flutter announces text changes inside a [Semantics] node
/// marked liveRegion).
class _AgentWorkingPill extends StatefulWidget {
  const _AgentWorkingPill();

  @override
  State<_AgentWorkingPill> createState() => _AgentWorkingPillState();
}

class _AgentWorkingPillState extends State<_AgentWorkingPill>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Under Reduce Motion the dot holds at a constant `t = 1.0`, so keep the
    // controller stopped instead of rebuilding an identical frame 60×/s in
    // the app bar for the whole run.
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    if (reduceMotion) {
      _pulse.stop();
    } else if (!_pulse.isAnimating) {
      _pulse.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.saqqar;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return Semantics(
      liveRegion: true,
      label: context.tr.agentWorking,
      child: TextScaleLock(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: s.brandCyan.withValues(alpha: 0.14),
            borderRadius: AppRadius.pillR,
            border: Border.all(color: s.brandCyan.withValues(alpha: 0.40)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedBuilder(
                animation: _pulse,
                builder: (_, __) {
                  final t = reduceMotion
                      ? 1.0
                      : Curves.easeInOut.transform(_pulse.value);
                  return Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: s.brandCyan.withValues(alpha: 0.45 + 0.55 * t),
                      shape: BoxShape.circle,
                    ),
                  );
                },
              ),
              const SizedBox(width: 6),
              Text(
                context.tr.agentWorking.toUpperCase(),
                style: context.text.labelSmall?.copyWith(
                  color: s.brandCyan,
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Two-color variant of [_EnvFlagBadge]:
///   * `live` — amber. The env is `is_live=true` on the server; any
///     write operation hits real production data.
///   * `readOnly` — cyan. The env is `read_only=true`; destructive
///     calls (writes, shell commands) are refused server-side.
enum _EnvFlagVariant { live, readOnly }

/// Compact uppercase pill rendered next to the env name in the AppBar
/// subtitle when the bound env carries the matching flag. Sized to
/// match [_AutoApprovePill] so the three can ride together without
/// crowding the title row.
class _EnvFlagBadge extends StatelessWidget {
  const _EnvFlagBadge({required this.variant});

  final _EnvFlagVariant variant;

  @override
  Widget build(BuildContext context) {
    final s = context.saqqar;
    final color = switch (variant) {
      _EnvFlagVariant.live => s.warning,
      _EnvFlagVariant.readOnly => s.brandCyan,
    };
    final label = switch (variant) {
      _EnvFlagVariant.live => context.tr.liveBadge,
      _EnvFlagVariant.readOnly => context.tr.readOnlyBadge,
    };
    return TextScaleLock(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.16),
          borderRadius: AppRadius.pillR,
          border: Border.all(color: color.withValues(alpha: 0.40)),
        ),
        child: Text(
          label.toUpperCase(),
          style: context.text.labelSmall?.copyWith(
            color: color,
            fontSize: 9,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.8,
          ),
        ),
      ),
    );
  }
}

/// Compact "AUTO" pill shown in the title subtitle when auto-approve is on.
/// Spec §6.8 calls for a subtle warning-coloured indicator; the pill stays
/// small enough to ride next to the credential label without crowding.
class _AutoApprovePill extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final s = context.saqqar;
    return TextScaleLock(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
        decoration: BoxDecoration(
          color: s.warning.withValues(alpha: 0.16),
          borderRadius: AppRadius.pillR,
          border: Border.all(color: s.warning.withValues(alpha: 0.40)),
        ),
        child: Text(
          context.tr.auto.toUpperCase(),
          style: context.text.labelSmall?.copyWith(
            color: s.warning,
            fontSize: 9,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.8,
          ),
        ),
      ),
    );
  }
}
