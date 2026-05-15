import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/i18n/app_localizations.dart';
import '../../../core/theme/app_gradients.dart';
import '../../../core/theme/app_icons.dart';
import '../../../shared/animations/pulse_dot.dart';
import '../../../shared/extensions/context_extensions.dart';
import '../../../shared/widgets/mini_chip.dart';
import '../../demo/saqqar_demo_data.dart';
import '../../inbox/state/approvals_controller.dart';
import 'conversation_action.dart';
import 'conversation_row_menu.dart';
import 'meta_dot.dart';

/// Single row in the conversation list. Tap opens the chat; the kebab menu
/// reveals row-level actions. Archived rows render at 70% opacity with an
/// amber "archived" chip.
///
/// ConsumerWidget so the "needs attention" pulse dot stays live — when the
/// user approves something inside a chat, the dot on that conversation row
/// disappears without us reloading the whole list.
class ConversationCard extends ConsumerWidget {
  const ConversationCard({
    super.key,
    required this.conversation,
    required this.onTap,
    required this.onAction,
  });

  final DemoConversation conversation;
  final VoidCallback onTap;
  final ValueChanged<ConversationAction> onAction;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = context.saqqar;
    final isArchived = conversation.isArchived;
    final hasCredential = conversation.activeCredential != 'none';
    // Combine the demo's pre-baked hint with the live per-conversation
    // controller so approvals resolved inside the chat clear the row dot.
    final needsAttention = conversation.hasPending ||
        ref.watch(conversationNeedsAttentionProvider(conversation.id));

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Opacity(
          opacity: isArchived ? 0.7 : 1,
          child: Container(
            padding: const EdgeInsets.fromLTRB(14, 14, 6, 14),
            decoration: BoxDecoration(
              color: s.surface.withValues(alpha: context.isDark ? 0.62 : 0.88),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: s.cardBorder),
              boxShadow: context.isDark
                  ? null
                  : [
                      BoxShadow(
                        color: const Color(0xFF0F172A).withValues(alpha: 0.04),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: AppGradients.vivid,
                    boxShadow: [
                      BoxShadow(
                        color: s.brandCyan.withValues(alpha: 0.18),
                        blurRadius: 14,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: const Icon(
                    AppIcons.message,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              conversation.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: context.text.titleSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                                height: 1.3,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            conversation.updatedLabel,
                            style: context.text.labelSmall?.copyWith(
                              color: s.muted,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        conversation.preview,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: context.text.bodySmall?.copyWith(
                          color: s.muted,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          MetaDot(
                            icon: AppIcons.message,
                            text: '${conversation.messageCount}',
                            color: s.muted,
                          ),
                          if (hasCredential) ...[
                            const SizedBox(width: 10),
                            Flexible(
                              child: MetaDot(
                                icon: AppIcons.key,
                                text: conversation.activeCredential,
                                color: s.brandCyan,
                              ),
                            ),
                          ],
                          if (needsAttention) ...[
                            const SizedBox(width: 10),
                            // Pulse dot + tiny label so the row reads as
                            // "this one needs attention" at a glance.
                            PulseDot(color: s.warning),
                            const SizedBox(width: 4),
                            Text(
                              context.tr.pending,
                              style: context.text.labelSmall?.copyWith(
                                color: s.warning,
                                fontWeight: FontWeight.w700,
                                fontSize: 10,
                                letterSpacing: 0.4,
                              ),
                            ),
                          ],
                          if (isArchived) ...[
                            const SizedBox(width: 10),
                            MiniChip(context.tr.archived, color: s.warning),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                ConversationRowMenu(onAction: onAction),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
