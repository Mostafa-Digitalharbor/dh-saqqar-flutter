import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/i18n/app_localizations.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_sizes.dart';
import '../../../shared/extensions/context_extensions.dart';
import '../../../shared/widgets/sheet_drag_handle.dart';
import '../data/conversation_models.dart';
import 'conversation_action.dart';
import '../../../shared/widgets/tappable_surface.dart';

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
      // Shown with `isScrollControlled: true`, which lets the sheet grow to
      // the full viewport — so an uncapped, unscrollable column overflows
      // wherever the content is taller than the window (landscape at ~320 px
      // tall, or Arabic at 1.4×). Cap the height and let the rows scroll,
      // mirroring `ChatSheet` / `EnvironmentDetailSheet`.
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.85,
        ),
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.s18,
            AppSpacing.s4,
            AppSpacing.s18,
            AppSpacing.s22 + MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SheetDragHandle(),
              const SizedBox(height: AppSpacing.s18),
              Text(
                tr.longPressActionsTitle,
                style: context.text.labelSmall?.copyWith(
                  color: s.muted,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.0,
                  fontSize: AppFontSizes.chipLabel,
                ),
              ),
              const SizedBox(height: AppSpacing.s4),
              Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: context.text.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: AppSpacing.s14),
              // Only the action rows scroll — the drag handle and the
              // conversation title stay pinned, so the user can always see
              // which conversation they're acting on.
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _ActionRow(
                        // Shows the ACTION, not the state — see the same
                        // pairing in `conversation_row_menu.dart`.
                        icon: isPinned
                            ? AppIcons.pinOff
                            : AppIcons.pin,
                        label: isPinned
                            ? tr.unpinConversation
                            : tr.pinConversation,
                        onTap: () =>
                            Navigator.of(context).pop(ConversationAction.pin),
                      ),
                      _ActionRow(
                        icon: AppIcons.edit,
                        label: tr.rename,
                        onTap: () => Navigator.of(
                          context,
                        ).pop(ConversationAction.rename),
                      ),
                      _ActionRow(
                        icon: AppIcons.share,
                        label: tr.shareLink,
                        onTap: () =>
                            Navigator.of(context).pop(ConversationAction.share),
                      ),
                      _ActionRow(
                        icon: isArchived
                            ? AppIcons.unarchive
                            : AppIcons.archive,
                        label: isArchived ? tr.unarchive : tr.archive,
                        onTap: () => Navigator.of(
                          context,
                        ).pop(ConversationAction.archive),
                      ),
                      _ActionRow(
                        icon: AppIcons.trash,
                        label: tr.delete,
                        danger: true,
                        onTap: () => Navigator.of(
                          context,
                        ).pop(ConversationAction.delete),
                      ),
                    ],
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
    return TappableSurface(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.s6,
          vertical: AppSpacing.s12,
        ),
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
              child: Icon(icon, size: AppIconSizes.regular, color: fg),
            ),
            const SizedBox(width: AppSpacing.s14),
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
    );
  }
}
