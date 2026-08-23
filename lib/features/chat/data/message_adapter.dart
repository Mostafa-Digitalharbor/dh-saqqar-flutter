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
/// `ChatMessage` and never run this function.
///
/// Intl stays OUT of here on purpose: the caller passes an already-formatted
/// [time] label and already-adapted [attachments], so the mapping is a pure
/// function that a test can call without a `BuildContext`.
library;

import '../../../core/format/byte_size.dart';
import '../../../core/i18n/app_strings.dart';
import '../../conversations/data/attachment_models.dart' as api;
import '../../conversations/data/conversation_models.dart' as api;
import 'chat_view_models.dart';

/// Maps a server [message] onto [ChatMessage].
ChatMessage adaptApiMessage(
  api.Message message, {
  required String time,
  List<ChatAttachment> attachments = const [],
}) {
  return ChatMessage(
    id: message.id,
    role: switch (message.role) {
      api.MessageRole.user => ChatMessageRole.user,
      // Tool + system messages render in the assistant lane; the chat widgets
      // don't visually distinguish those today.
      api.MessageRole.assistant ||
      api.MessageRole.tool ||
      api.MessageRole.system =>
        ChatMessageRole.assistant,
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

/// Maps a server [attachment] onto the chip the composer and the bubble
/// render.
///
/// Moved out of `chat_screen.dart`, where it sat as a private free function
/// beside the message adapter it feeds. Nothing about turning an
/// `api.Attachment` into a chip is a view concern — it takes [AppStrings] and
/// returns a value — and leaving it in the screen meant the only two adapters
/// in the chat feature lived in two different layers.
ChatAttachment adaptApiAttachment(api.Attachment attachment, AppStrings tr) {
  return ChatAttachment(
    name: attachment.originalName,
    kind: attachment.kind.toUpperCase(),
    size: humanBytes(attachment.sizeBytes, tr),
    imageUrl: attachment.kind == 'image' ? attachment.absoluteUrl : null,
    // Carry the server-side id + absolute URL so the AttachmentChip tap
    // handler can download + open the file via [ArtifactDownloader].
    serverId: attachment.id,
    downloadUrl: attachment.absoluteUrl,
  );
}
