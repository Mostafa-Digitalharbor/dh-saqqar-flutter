import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/i18n/app_localizations.dart';
import '../../../core/theme/app_icons.dart';
import '../../../shared/widgets/confirm_dialog.dart';
import '../data/conversation_models.dart';
import '../view_model/conversations_cubit.dart';
import 'conversation_action.dart';
import 'rename_conversation_dialog.dart';

/// Runs a [ConversationAction] against [cubit] for [c] using the exact same
/// dialogs and flows the Chats list uses — the rename dialog, the OS share
/// sheet, and the destructive delete confirm.
///
/// Extracted here so surfaces outside the Chats screen (notably the chat
/// sidebar drawer's long-press sheet) can offer identical Pin / Rename /
/// Share / Archive / Delete behaviour without duplicating the wiring.
///
/// This handles the common path only. The Chats screen keeps its own richer
/// archive-with-undo toast; callers that don't need it (the drawer) get the
/// plain optimistic archive here.
Future<void> runConversationAction(
  BuildContext context, {
  required ConversationsCubit cubit,
  required ConversationSummary c,
  required ConversationAction action,
}) async {
  switch (action) {
    case ConversationAction.pin:
      cubit.togglePin(c.id);
    case ConversationAction.rename:
      final next = await RenameConversationDialog.show(
        context,
        initial: c.title,
      );
      if (next == null || !context.mounted) return;
      await cubit.renameConversation(id: c.id, name: next);
    case ConversationAction.share:
      final url = await cubit.shareConversation(c.id);
      if (!context.mounted || url == null) return;
      // share_plus 10.x static API. `subject` only feeds the mailto
      // fallback's email subject; most targets ignore it.
      await Share.share(
        url,
        subject: c.title.trim().isEmpty ? context.tr.appName : c.title.trim(),
      );
    case ConversationAction.archive:
      if (c.isArchived) {
        await cubit.unarchiveConversation(c.id);
      } else {
        await cubit.archiveConversation(c.id);
      }
    case ConversationAction.delete:
      // Irreversible — gate behind the same red-confirm the kebab path uses.
      final confirmed = await ConfirmDialog.show(
        context,
        title: context.tr.deleteConversationTitle,
        body: context.tr.deleteConversationBody,
        confirmLabel: context.tr.confirmYes,
        cancelLabel: context.tr.confirmNo,
        icon: AppIcons.trash,
        destructive: true,
      );
      if (!confirmed || !context.mounted) return;
      await cubit.deleteConversation(c.id);
  }
}
