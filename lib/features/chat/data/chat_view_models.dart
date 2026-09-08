import 'package:flutter/material.dart';

import '../../../core/format/file_kind.dart';
import '../../conversations/data/conversation_models.dart'
    show MessageTokens;
import '../../inbox/data/approval_models.dart' show kDeleteOperation;

/// View models for the chat surface — the shapes its widgets render.
///
/// Server model in, view model out, widgets read the view model. The
/// adapters that do the "in" half sit beside this file
/// (`message_adapter.dart`, `approval_adapter.dart`).
///
/// **This file used to be `features/demo/saqqar_demo_data.dart`, and every
/// type in it was named `Demo*`.** That was a fossil: the types pre-dated
/// the API layer and once carried hardcoded sample data, which was deleted
/// on 2026-07-06 so nothing fabricated could reach the UI. What survived was
/// a set of production types whose names told every reader they were fake,
/// living in a directory called `demo/` that nothing demo-related used.
/// `DemoMessage` was the type the real chat rendered.
///
/// Ten types went with the move, none of which had a single reader outside
/// this file: `DemoProject`, `DemoEnvironment`, the four `DemoCredential*`
/// shapes, `DemoPendingAction`, `DemoServerActivity`,
/// `DemoApprovalIndividual`, and `DemoConversation` — the last of which was
/// constructed in exactly one place so that one string could be read back
/// off it.
enum ChatMessageRole { user, assistant, tool, system }


enum ChatApprovalStatus { pending, approved, rejected }




class ChatMessage {
  const ChatMessage({
    required this.role,
    required this.content,
    required this.time,
    this.id = '',
    this.toolName,
    this.toolPayload,
    this.attachments = const [],
    this.createdAt,
    this.isAgentStep = false,
    this.tokens,
  });

  /// Server message id (empty for locally-authored demo/optimistic rows).
  /// Carried through the API adapter so the chat list can give each row a
  /// stable [ValueKey], letting Flutter match elements across poll rebuilds
  /// instead of reusing the wrong one when messages shift index.
  final String id;

  final ChatMessageRole role;
  final String content;
  final String time;
  final String? toolName;

  /// The server's `tool_payload`, carried through verbatim.
  ///
  /// Its `kind` is what selects an INTERACTIVE card (clarifying questions,
  /// report builder, prompt suggestion) over the generic tool-activity card —
  /// see `interactive_cards.dart`. Without it a mobile user got a raw JSON
  /// blob with nothing to tap where a web user got a card to choose from.
  final Map<String, dynamic>? toolPayload;
  final List<ChatAttachment> attachments;

  /// Calendar date the message belongs to (server's `created_at`). When non-
  /// null the chat list inserts a date separator above the first message of
  /// each new day. Optional so existing demo data without timestamps keeps
  /// working — the API impl will always populate it.
  final DateTime? createdAt;

  /// This row records an action the agent took, not a reply it wrote.
  ///
  /// Set by the adapter for the `tool` rows the backend narrates a run with.
  /// [content] is then a short human label ("Applying a change in Odoo"),
  /// never the tool's raw JSON result — the transcript is not a log file.
  ///
  /// The timeline folds these into the thinking pill and, critically, never
  /// promotes one to a turn's final reply: a run whose last row is a step has
  /// not answered yet, and printing "Applying a change in Odoo" as the answer
  /// would be a sentence the agent never said.
  final bool isAgentStep;

  /// What this reply cost, when the server metered it. Rendered as a small
  /// chip beside the timestamp, the way the web does — a user paying per
  /// token can see which answer was the expensive one without leaving the
  /// conversation.
  final MessageTokens? tokens;
}

/// Where an attachment came from. Used by the chat bubble to decide whether
/// to render as a neutral file chip (user uploaded it) or a cyan "Artifact
/// ready" pill (the agent generated it, mirroring the web's separate
/// `renderMessageAttachments()` path).
enum AttachmentSource { userUpload, generatedOutput }

class ChatAttachment {
  const ChatAttachment({
    required this.name,
    required this.kind,
    required this.size,
    this.imageUrl,
    this.localPath,
    this.downloadUrl,
    this.serverId,
    this.source = AttachmentSource.userUpload,
  });

  final String name;
  final String kind;
  final String size;

  /// Remote URL for image attachments. When set, the chat bubble renders the
  /// preview inline (capped at 240 px tall) above the file meta row. Always
  /// null for non-image kinds.
  final String? imageUrl;

  /// On-disk path of a file that is already on this device — set for every
  /// attachment staged in the composer, whatever its kind.
  ///
  /// [imageUrl] only ever points at pictures, so it can't be used to preview
  /// a document. This is what lets a staged PDF render its own first page as
  /// a thumbnail instead of falling back to a generic file glyph. Null for
  /// attachments that live only on the server.
  final String? localPath;

  /// Absolute URL of the underlying file on the server (PDF, DOCX, image,
  /// etc.). When non-null the attachment chip becomes tappable and the
  /// download flow opens the file with the OS's matching viewer.
  final String? downloadUrl;

  /// Server-side id of the attachment. Used as the on-disk cache key so
  /// the same file isn't re-downloaded each time the user taps it.
  final String? serverId;

  final AttachmentSource source;

  /// Whether this attachment should render as a picture rather than a file
  /// chip.
  ///
  /// Decided by the FILENAME first, deliberately. [kind] is a *display*
  /// label — the composer fills it from `tr.fileKindImage`, which is
  /// "Image" in English but "صورة" in Arabic — so matching English tokens
  /// against it meant every image attached in Arabic failed the check and
  /// fell back to the generic file glyph. The bug was invisible on an
  /// English emulator and reproduced on every Arabic device.
  bool get isImage {
    if (name.contains('.') && FileKinds.isImage(name)) return true;
    // Fallback for server-supplied rows: the API's `kind` is a machine
    // token ('image'), never localized, and a name may lack an extension.
    // `FileKinds` reads a bare token as an extension, so a `kind` of "png"
    // resolves through the same table as a filename would; "image" is the
    // one token that is a category rather than a format, so it is named
    // here.
    return kind.toUpperCase() == _serverImageToken || FileKinds.isImage(kind);
  }

  /// The API's own machine token for a picture. Not a file extension, so it
  /// cannot come out of the extension table.
  static const String _serverImageToken = 'IMAGE';

  bool get isAgentGenerated => source == AttachmentSource.generatedOutput;
}




class ChatApproval {
  const ChatApproval({
    required this.id,
    required this.title,
    required this.prompt,
    required this.actionType,
    required this.risk,
    required this.status,
    required this.payload,
    this.sharedShape,
    this.conversationId,
    this.recordCount,
    this.confirmPhrase,
    this.deleteRecords = const [],
    this.batchScoped = false,
  });

  final String id;
  final String title;
  final String prompt;
  final String actionType;
  final String risk;
  final ChatApprovalStatus status;
  final Map<String, String> payload;

  /// Composite key the agent uses to pre-approve future writes of the same
  /// shape in this conversation. Format used by the web is
  /// `<actionType>:<model>:<operation>` (e.g. `odoo_write:res.users:write`).
  /// When the user taps "Approve all", every future approval matching this
  /// string in the same conversation is auto-accepted by the controller.
  final String? sharedShape;

  /// The conversation this approval was raised in. Used to scope the
  /// pre-approval — pre-approving in conversation A must not silence
  /// approvals raised in conversation B.
  final String? conversationId;

  /// Records this write touches, straight from the server (`record_count`).
  /// Drives the count in the red "Delete N" button, which is why it is the
  /// SERVER's count and never a client-side guess — it is the informed
  /// consent a user gives before an irreversible act.
  final int? recordCount;

  /// `Approval.confirmPhrase` — the exact string the server will accept to
  /// confirm this delete. The card never asks the user to reproduce it; the
  /// red button echoes it back verbatim on tap.
  final String? confirmPhrase;

  /// `Approval.deleteRecords` — display labels for the rows a delete would
  /// destroy, so the user can review *which* records die and not only how
  /// many. Empty on every non-delete, and on deletes the server did not
  /// enumerate.
  final List<String> deleteRecords;

  /// `payload.batch_scope` — already auto-approved by a scope the user
  /// granted earlier, so offering to batch it again is offering a no-op.
  final bool batchScoped;

  /// Wire value of the action type the backend describes batching for.
  static const kOdooWrite = 'odoo_write';

  /// Whether "approve all similar" may be offered.
  ///
  /// Three conditions, each for its own reason:
  ///
  ///   * **Odoo writes only.** The backend describes the scope as registering
  ///     a shape so "future same-shape WRITES auto-approve silently". It does
  ///     not exclude other action types, but one tap that silently
  ///     pre-approves future `server_command` or `credential_storage`
  ///     approvals is a privilege escalation the user did not ask for, and
  ///     those are the two approvals most worth reading individually. Asked
  ///     the backend to confirm; conservative until they do.
  ///   * **Never deletes.** The server returns 400 for `scope: "batch"` on a
  ///     destructive delete, so the button could only fail — and a batch
  ///     delete is the one mistake with no undo.
  ///   * **Not already scoped.** `payload.batch_scope` means a scope the user
  ///     granted earlier already cleared this one.
  bool get canBatchApprove =>
      actionType == kOdooWrite &&
      !batchScoped && payload['operation'] != kDeleteOperation;
}




class ChatArtifact {
  const ChatArtifact({
    required this.id,
    required this.name,
    required this.kind,
    required this.size,
    required this.conversation,
    required this.conversationId,
    required this.createdLabel,
  });

  final String id;
  final String name;
  final String kind;
  final String size;

  /// Conversation title — kept for display. The id is the canonical link.
  final String conversation;

  /// The conversation this artifact was generated in. Drives the per-chat
  /// artifacts sheet that replaced the global Files tab.
  final String conversationId;

  final String createdLabel;
}
