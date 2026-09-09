import 'package:flutter/material.dart';

import '../../../core/i18n/app_localizations.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_sizes.dart';
import '../../../shared/extensions/context_extensions.dart';
import 'conversation_action.dart';

/// Overflow menu (kebab) on each conversation row: pin / rename / share /
/// archive / delete. The "delete" entry is tinted danger to set
/// expectations. The Pin label flips to Unpin when [isPinned] is true,
/// and the Archive label flips to Unarchive when [isArchived] is true
/// so a row that's already in the archive bucket reads as "Unarchive"
/// instead of confusingly offering Archive again.
class ConversationRowMenu extends StatelessWidget {
  const ConversationRowMenu({
    super.key,
    required this.onAction,
    this.isPinned = false,
    this.isArchived = false,
  });

  final ValueChanged<ConversationAction> onAction;
  final bool isPinned;
  final bool isArchived;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<ConversationAction>(
      tooltip: context.tr.conversationActions,
      icon: Icon(AppIcons.more, color: context.saqqar.muted, size: AppIconSizes.action),
      onSelected: onAction,
      itemBuilder: (context) => [
        PopupMenuItem(
          value: ConversationAction.pin,
          child: _MenuRow(
            // The glyph shows the ACTION, not the current state — the label
            // beside it already says which. Material's filled/outline pin
            // pair only differed in weight; Lucide's `pinOff` is a struck
            // -through pin, so pointing it at the wrong branch would put an
            // "unpin" glyph next to the word "Pin".
            icon: isPinned ? AppIcons.pinOff : AppIcons.pin,
            label: isPinned
                ? context.tr.unpinConversation
                : context.tr.pinConversation,
          ),
        ),
        PopupMenuItem(
          value: ConversationAction.rename,
          child: _MenuRow(icon: AppIcons.edit, label: context.tr.rename),
        ),
        PopupMenuItem(
          value: ConversationAction.share,
          child: _MenuRow(icon: AppIcons.share, label: context.tr.shareLink),
        ),
        PopupMenuItem(
          value: ConversationAction.archive,
          child: _MenuRow(
            // Same `ConversationAction.archive` value either way — the
            // screen's handler already inspects `c.isArchived` and
            // routes to unarchiveConversation when true. We only flip
            // the label/icon here.
            icon: isArchived ? AppIcons.unarchive : AppIcons.archive,
            label: isArchived ? context.tr.unarchive : context.tr.archive,
          ),
        ),
        PopupMenuItem(
          value: ConversationAction.delete,
          child: _MenuRow(
            icon: AppIcons.trash,
            label: context.tr.delete,
            danger: true,
          ),
        ),
      ],
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({
    required this.icon,
    required this.label,
    this.danger = false,
  });

  final IconData icon;
  final String label;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final color = danger ? context.saqqar.danger : context.saqqar.text;
    return Row(
      children: [
        Icon(icon, size: AppIconSizes.regular, color: color),
        const SizedBox(width: AppSpacing.s10),
        // Expanded + ellipsis, matching `SheetActionRow`. `PopupMenuButton`
        // sizes its items against the viewport, not against their content, so
        // an unconstrained `Text` here overflowed by 27 px on a 320 px phone
        // in Arabic at 1.4× — "إلغاء الأرشفة" beside its glyph is simply wider
        // than the menu the OS will give it. The row menu is the ONLY route
        // to rename, pin, share, archive and delete, so an overflow here
        // takes five actions with it.
        Expanded(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: color),
          ),
        ),
      ],
    );
  }
}
