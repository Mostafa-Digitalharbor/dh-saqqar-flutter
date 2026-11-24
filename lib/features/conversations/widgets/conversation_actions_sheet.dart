import '../../../shared/fig/fig.dart' show showLightSheet;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/i18n/app_localizations.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_sizes.dart';
import '../../../shared/extensions/context_extensions.dart';
import '../data/conversation_models.dart';
import 'conversation_action.dart';
import '../../../shared/widgets/sheet_action_row.dart';

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
    return showLightSheet<ConversationAction>(
      context,
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
          maxHeight: MediaQuery.sizeOf(context).height * AppFractions.sheet,
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
              Text(
                tr.longPressActionsTitle,
                style: context.text.labelSmall?.copyWith(
                  color: s.muted,
                  fontWeight: FontWeight.w800,
                  letterSpacing: AppLetterSpacing.microCaps,
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
                  letterSpacing: AppLetterSpacing.heading,
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
                      SheetActionRow(
                        // Shows the ACTION, not the state — see the same
                        // pairing in `conversation_row_menu.dart`.
                        icon: isPinned ? AppIcons.pinOff : AppIcons.pin,
                        label: isPinned
                            ? tr.unpinConversation
                            : tr.pinConversation,
                        onTap: () =>
                            Navigator.of(context).pop(ConversationAction.pin),
                      ),
                      SheetActionRow(
                        icon: AppIcons.edit,
                        label: tr.rename,
                        onTap: () => Navigator.of(
                          context,
                        ).pop(ConversationAction.rename),
                      ),
                      SheetActionRow(
                        icon: AppIcons.share,
                        label: tr.shareLink,
                        onTap: () =>
                            Navigator.of(context).pop(ConversationAction.share),
                      ),
                      SheetActionRow(
                        icon: isArchived
                            ? AppIcons.unarchive
                            : AppIcons.archive,
                        label: isArchived ? tr.unarchive : tr.archive,
                        onTap: () => Navigator.of(
                          context,
                        ).pop(ConversationAction.archive),
                      ),
                      SheetActionRow(
                        icon: AppIcons.trash,
                        label: tr.delete,
                        tint: context.saqqar.danger,
                        glyphColor: context.saqqar.danger,
                        labelColor: context.saqqar.danger,
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
