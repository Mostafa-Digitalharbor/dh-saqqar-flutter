import 'package:flutter/widgets.dart';

import '../../../core/i18n/app_localizations.dart';

/// Actions exposed by the conversation row's overflow menu.
enum ConversationAction { pin, rename, share, archive, delete }

/// Human-readable label for a [ConversationAction] in the active locale.
/// The [pinned] flag flips Pin into Unpin when the conversation is
/// already pinned — the menu uses a single enum value for both so the
/// switch handler stays trivial.
String conversationActionLabel(
  BuildContext context,
  ConversationAction a, {
  bool pinned = false,
}) {
  return switch (a) {
    ConversationAction.pin =>
      pinned ? context.tr.unpinConversation : context.tr.pinConversation,
    ConversationAction.rename => context.tr.rename,
    ConversationAction.share => context.tr.shareLink,
    ConversationAction.archive => context.tr.archive,
    ConversationAction.delete => context.tr.delete,
  };
}
