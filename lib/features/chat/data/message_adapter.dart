/// Server message → the demo-shaped model the chat widgets still consume.
///
/// Temporary bridge: once the chat widgets take the real model types
/// directly, delete this and read `snapshot.messages` straight into the list.
///
/// Extracted from the screen because this is the THIRD place an interactive
/// card can vanish, after `message_visibility.dart` (filtered out) and
/// `chat_timeline.dart` (buried in a collapsed pill). Here it would be
/// quieter still: drop one line — `toolPayload: m.toolPayload` — and every
/// card silently becomes an ordinary bubble, with nothing failing to build
/// and no widget test noticing, because widget tests construct their own
/// `DemoMessage` and never run this function.
///
/// Intl stays OUT of here on purpose: the caller passes an already-formatted
/// [time] label and already-adapted [attachments], so the mapping is a pure
/// function that a test can call without a `BuildContext`.
library;

import '../../conversations/data/conversation_models.dart' as api;
import '../../demo/saqqar_demo_data.dart';

/// Maps a server [message] onto [DemoMessage].
DemoMessage adaptApiMessage(
  api.Message message, {
  required String time,
  List<DemoAttachment> attachments = const [],
}) {
  return DemoMessage(
    id: message.id,
    role: switch (message.role) {
      api.MessageRole.user => DemoMessageRole.user,
      // Tool + system messages render in the assistant lane; the chat widgets
      // don't visually distinguish those today.
      api.MessageRole.assistant ||
      api.MessageRole.tool ||
      api.MessageRole.system =>
        DemoMessageRole.assistant,
    },
    content: message.content,
    // Web-parity full timestamp under the bubble. The chat row also renders a
    // date separator above the first message of a new calendar day; both
    // reference `createdAt` so they stay in sync.
    time: time,
    createdAt: message.createdAt,
    toolName: (message.toolName ?? '').isEmpty ? null : message.toolName,
    // Load-bearing: this is what lets the renderer dispatch on
    // `tool_payload.kind` and show an interactive card instead of a payload
    // the user can't act on.
    toolPayload: message.toolPayload,
    attachments: attachments,
  );
}
