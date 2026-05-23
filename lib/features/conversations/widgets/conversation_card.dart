import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/i18n/app_date_format.dart';
import '../../../core/i18n/app_localizations.dart';
import '../../../core/theme/app_gradients.dart';
import '../../../core/theme/app_icons.dart';
import '../../../shared/animations/pulse_dot.dart';
import '../../../shared/extensions/context_extensions.dart';
import '../../../shared/widgets/mini_chip.dart';
import '../../inbox/view_model/approvals_cubit.dart';
import '../data/conversation_models.dart';
import '../view_model/conversations_cubit.dart';
import 'conversation_action.dart';
import 'conversation_actions_sheet.dart';
import 'conversation_row_menu.dart';
import 'meta_dot.dart';

/// Single row in the conversation list. Tap opens the chat; the kebab
/// menu reveals row-level actions. Archived rows render at 70% opacity
/// with an amber "archived" chip.
///
/// Reads the "needs attention" pulse dot live via a `BlocSelector` on
/// [ApprovalsCubit] — when the user approves something inside a chat,
/// the dot on that conversation row disappears without us reloading the
/// whole list.
class ConversationCard extends StatelessWidget {
  const ConversationCard({
    super.key,
    required this.conversation,
    required this.onTap,
    required this.onAction,
  });

  final ConversationSummary conversation;
  final VoidCallback onTap;
  final ValueChanged<ConversationAction> onAction;

  @override
  Widget build(BuildContext context) {
    final s = context.saqqar;
    final isArchived = conversation.isArchived;
    final needsAttention = context.select<ApprovalsCubit, bool>(
      (cubit) => cubit.state.conversationNeedsAttention(conversation.id),
    );
    final isPinned = context.select<ConversationsCubit, bool>(
      (cubit) =>
          cubit.state.data.dataOrNull?.pinnedIds.contains(conversation.id) ??
          false,
    );

    final title = conversation.title.trim();
    // `lastMessagePreview` removed on user request — the row now shows
    // title + relative time + message count only. The assistant's reply
    // text was visually noisy and often redundant with the title.

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        // Long-press surfaces the same actions the ⋯ kebab exposes, but
        // anywhere on the row instead of demanding a precision tap on
        // the trailing edge — testers (2026-05-23) asked for this to
        // match the WhatsApp / Gmail muscle memory.
        onLongPress: () async {
          final action = await ConversationActionsSheet.show(
            context,
            conversation: conversation,
            isPinned: isPinned,
          );
          if (action != null) onAction(action);
        },
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
                          if (isPinned) ...[
                            Icon(
                              Icons.push_pin,
                              size: 13,
                              color: s.brandCyan,
                            ),
                            const SizedBox(width: 6),
                          ],
                          Expanded(
                            child: Text(
                              title.isEmpty
                                  ? context.tr.untitledConversation
                                  : title,
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
                            AppDateFormat.relative(
                              context,
                              conversation.updatedAt,
                            ),
                            style: context.text.labelSmall?.copyWith(
                              color: s.muted,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          MetaDot(
                            icon: AppIcons.message,
                            text: '${conversation.messageCount}',
                            color: s.muted,
                          ),
                          if (needsAttention) ...[
                            const SizedBox(width: 10),
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
                ConversationRowMenu(
                  onAction: onAction,
                  isPinned: isPinned,
                  isArchived: isArchived,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
