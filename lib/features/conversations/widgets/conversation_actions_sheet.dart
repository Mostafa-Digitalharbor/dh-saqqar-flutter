import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/i18n/app_localizations.dart';
import '../../../core/theme/app_icons.dart';
import '../../../shared/extensions/context_extensions.dart';
import '../../../shared/widgets/sheet_drag_handle.dart';
import '../data/conversation_models.dart';
import 'conversation_action.dart';

/// Bottom sheet surfaced when the user long-presses a conversation row
/// in the list. Same set of actions the ⋯ kebab exposes (Pin, Rename,
/// Share, Archive, Delete) but in a roomier touch-friendly layout — the
/// kebab requires a precision tap on the trailing edge, long-press +
/// sheet works from anywhere on the row.
///
/// Returns the selected [ConversationAction] (or null on dismiss) so
/// the caller threads it back into the same handler the kebab uses.
class ConversationActionsSheet extends StatelessWidget {
  const ConversationActionsSheet({
    super.key,
    required this.conversation,
    required this.isPinned,
  });

  final ConversationSummary conversation;
  final bool isPinned;

  static Future<ConversationAction?> show(
    BuildContext context, {
    required ConversationSummary conversation,
    required bool isPinned,
  }) {
    // Medium haptic so the long-press registers physically the instant
    // the sheet starts to animate in — matches the iOS / WhatsApp feel
    // where long-press has a clear "you triggered something" cue.
    HapticFeedback.mediumImpact();
    return showModalBottomSheet<ConversationAction>(
      context: context,
      isScrollControlled: true,
      builder: (_) => ConversationActionsSheet(
        conversation: conversation,
        isPinned: isPinned,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = context.saqqar;
    final tr = context.tr;
    final isArchived = conversation.isArchived;
    final title = conversation.title.trim().isEmpty
        ? tr.untitledConversation
        : conversation.title.trim();

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          18,
          4,
          18,
          22 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SheetDragHandle(),
            const SizedBox(height: 18),
            Text(
              tr.longPressActionsTitle,
              style: context.text.labelSmall?.copyWith(
                color: s.muted,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.0,
                fontSize: 10,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: context.text.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(height: 14),
            _ActionRow(
              icon: isPinned ? Icons.push_pin : Icons.push_pin_outlined,
              label: isPinned ? tr.unpinConversation : tr.pinConversation,
              onTap: () =>
                  Navigator.of(context).pop(ConversationAction.pin),
            ),
            _ActionRow(
              icon: AppIcons.edit,
              label: tr.rename,
              onTap: () =>
                  Navigator.of(context).pop(ConversationAction.rename),
            ),
            _ActionRow(
              icon: AppIcons.share,
              label: tr.shareLink,
              onTap: () =>
                  Navigator.of(context).pop(ConversationAction.share),
            ),
            _ActionRow(
              icon: isArchived
                  ? Icons.unarchive_outlined
                  : AppIcons.archive,
              label: isArchived ? tr.unarchive : tr.archive,
              onTap: () =>
                  Navigator.of(context).pop(ConversationAction.archive),
            ),
            _ActionRow(
              icon: AppIcons.trash,
              label: tr.delete,
              danger: true,
              onTap: () =>
                  Navigator.of(context).pop(ConversationAction.delete),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.icon,
    required this.label,
    required this.onTap,
    this.danger = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final s = context.saqqar;
    final fg = danger ? s.danger : s.text;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: (danger ? s.danger : s.muted).withValues(alpha: 0.10),
                ),
                child: Icon(icon, size: 18, color: fg),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  label,
                  style: context.text.bodyMedium?.copyWith(
                    color: fg,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
