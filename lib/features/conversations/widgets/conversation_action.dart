import 'package:flutter/widgets.dart';

import '../../../core/i18n/app_localizations.dart';

/// Actions exposed by the conversation row's overflow menu.
enum ConversationAction { rename, share, archive, delete }

/// Human-readable label for a [ConversationAction] in the active locale.
String conversationActionLabel(BuildContext context, ConversationAction a) {
  return switch (a) {
    ConversationAction.rename => context.tr.rename,
    ConversationAction.share => context.tr.shareLink,
    ConversationAction.archive => context.tr.archive,
    ConversationAction.delete => context.tr.delete,
  };
}
