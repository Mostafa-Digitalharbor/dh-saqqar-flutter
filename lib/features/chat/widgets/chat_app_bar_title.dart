import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/i18n/app_localizations.dart';
import '../../../core/theme/app_gradients.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_radius.dart';
import '../../../shared/extensions/context_extensions.dart';
import '../../conversations/state/conversations_controller.dart';
import '../../demo/saqqar_demo_data.dart';

/// AppBar title slot for the chat screen: gradient Saqqar avatar + the
/// conversation title + a subtitle row showing the active credential and
/// an "Auto-approve on" pill when relevant.
///
/// Tapping the row opens the credential picker. A small inline edit
/// pencil sits next to the title — tapping it opens the rename dialog
/// (web parity for `#renameButton`). [onRenameTap] fires with the
/// current effective title (post-rename overlay) and lets the parent
/// open the appropriate dialog.
class ChatAppBarTitle extends ConsumerWidget {
  const ChatAppBarTitle({
    super.key,
    required this.conversation,
    required this.activeCredentialLabel,
    required this.autoApprove,
    required this.onCredentialTap,
    this.onRenameTap,
    this.agentBusy = false,
  });

  final DemoConversation conversation;
  final String activeCredentialLabel;
  final bool autoApprove;
  final VoidCallback onCredentialTap;
  final VoidCallback? onRenameTap;

  /// When true, a small "Working" pill with a pulsing cyan dot is rendered
  /// next to the conversation title. Surfaces global agent-running state
  /// from anywhere in the chat — even if the user scrolled away from the
  /// typing row. Web parity (`#streamingPill` in chat-v2 layout).
  final bool agentBusy;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = context.saqqar;
    // Pull the effective title via the controller so renames done from
    // any surface (this AppBar pencil or the ⋯ menu) reflect instantly
    // without prop-drilling through chat_screen.
    final effectiveTitle =
        ref.watch(conversationTitleProvider(conversation));
    final displayTitle = effectiveTitle.trim().isEmpty
        ? context.tr.untitledConversation
        : effectiveTitle;

    return InkWell(
      onTap: onCredentialTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(4, 4, 4, 4),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: AppGradients.vivid,
                border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
              ),
              child: const Icon(AppIcons.sparkles, color: Colors.white, size: 17),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          displayTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
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
                  Row(
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
                      Flexible(
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
                      if (autoApprove) ...[
                        const SizedBox(width: 8),
                        _AutoApprovePill(),
                      ],
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
  )..repeat(reverse: true);

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
    return Container(
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
    );
  }
}
