import 'package:flutter/material.dart';

import '../../core/format/file_kind.dart';
import '../chat/data/delete_confirmation.dart';

/// Shared chat/vault view-model TYPES (the `Demo*` names are legacy — they
/// pre-date the API layer and are now populated exclusively from real API
/// responses via the per-feature adapters). ALL hardcoded sample data that
/// used to live here was removed on 2026-07-06 so nothing fabricated can ever
/// reach the UI — every value the app shows now comes from the backend.
enum DemoMessageRole { user, assistant, tool, system }

enum DemoCredentialKind { xmlrpc, postgres, serverShell, github }

enum DemoApprovalStatus { pending, approved, rejected }

class DemoConversation {
  const DemoConversation({
    required this.id,
    required this.title,
    required this.preview,
    required this.updatedLabel,
    required this.messageCount,
    required this.activeCredential,
    this.environmentId,
    this.isArchived = false,
    this.hasPending = false,
  });

  final String id;
  final String title;
  final String preview;
  final String updatedLabel;
  final int messageCount;

  /// Legacy field — short name of the bundle the agent is using. New code
  /// should read [environmentId] and resolve via [demoEnvironmentForConversation].
  /// Kept so older row-meta widgets (conversation card pill) keep working.
  final String activeCredential;

  /// Preferred per-spec target for the agent. When null, falls back to the
  /// legacy [activeCredential] string. Conversations that haven't picked an
  /// environment yet get `null` here AND `'none'` for activeCredential.
  final String? environmentId;

  final bool isArchived;

  /// `true` when this conversation has at least one pending approval or
  /// agent-request action. Surfaces a pulse dot on the conversation row so
  /// users can scan their list and find what needs attention without
  /// opening every chat.
  final bool hasPending;
}

/// A workspace project — collects related environments under one name.
/// Mirrors the production data model exposed by the web at
/// `https://saqqaar.com/static/odoo_agent/app.js` (each Odoo customer is one
/// project with one or more environments).
class DemoProject {
  const DemoProject({required this.id, required this.name});

  final String id;
  final String name;
}

/// A target the agent operates against — one Odoo deployment / DB / shell
/// host. Credentials live HERE (not as standalone bundles like the older
/// design), and `is_live` controls the one-time confirmation dialog the
/// chat screen pops on the first message sent to a live env.
class DemoEnvironment {
  const DemoEnvironment({
    required this.id,
    required this.projectId,
    required this.name,
    this.isLive = false,
    this.readOnly = false,
    this.autoApprove = false,
    this.credentialNames = const [],
  });

  final String id;
  final String projectId;
  final String name;

  /// When true, the chat screen prompts the user once per (conversation,
  /// environment) before the first message goes through. Persists the ack
  /// in SharedPreferences keyed by `liveAck.{convId}.{envId}`.
  final bool isLive;

  final bool readOnly;
  final bool autoApprove;

  /// Names of [DemoCredential] bundles the agent can use against this env.
  /// Empty list = the env is configured but no credentials wired yet.
  final List<String> credentialNames;
}

class DemoMessage {
  const DemoMessage({
    required this.role,
    required this.content,
    required this.time,
    this.id = '',
    this.toolName,
    this.toolPayload,
    this.attachments = const [],
    this.createdAt,
  });

  /// Server message id (empty for locally-authored demo/optimistic rows).
  /// Carried through the API adapter so the chat list can give each row a
  /// stable [ValueKey], letting Flutter match elements across poll rebuilds
  /// instead of reusing the wrong one when messages shift index.
  final String id;

  final DemoMessageRole role;
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
  final List<DemoAttachment> attachments;

  /// Calendar date the message belongs to (server's `created_at`). When non-
  /// null the chat list inserts a date separator above the first message of
  /// each new day. Optional so existing demo data without timestamps keeps
  /// working — the API impl will always populate it.
  final DateTime? createdAt;
}

/// Where an attachment came from. Used by the chat bubble to decide whether
/// to render as a neutral file chip (user uploaded it) or a cyan "Artifact
/// ready" pill (the agent generated it, mirroring the web's separate
/// `renderMessageAttachments()` path).
enum AttachmentSource { userUpload, generatedOutput }

class DemoAttachment {
  const DemoAttachment({
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

class DemoCredential {
  const DemoCredential({
    required this.name,
    required this.label,
    required this.kind,
    required this.source,
    required this.lastVerified,
    required this.isMemorized,
  });

  final String name;
  final String label;
  final DemoCredentialKind kind;
  final String source;
  final String? lastVerified;
  final bool isMemorized;
}

class DemoCredentialSchema {
  const DemoCredentialSchema({
    required this.kind,
    required this.label,
    required this.fields,
  });

  final DemoCredentialKind kind;
  final String label;
  final List<DemoCredentialField> fields;
}

class DemoCredentialField {
  const DemoCredentialField({
    required this.name,
    required this.label,
    this.hint,
    this.help,
    this.obscure = false,
    this.multiline = false,
    this.options = const [],
    this.showWhen,
    this.required = true,
  });

  final String name;
  final String label;
  final String? hint;

  /// Secondary explanatory text rendered below the field (italic, muted).
  /// Mirrors the web's `help` property on schema fields — e.g. for SSH the
  /// password field carries "Fill this for password auth" so the user knows
  /// why two auth-related fields appear together.
  final String? help;

  final bool obscure;
  final bool multiline;
  final List<String> options;

  /// Optional gate: only render this field when a SIBLING field in the same
  /// schema currently holds one of the listed values. Web parity for the
  /// `auth=password` vs `auth=key` conditional on server_shell — password
  /// shows when auth=password; private_key shows when auth=key.
  ///
  /// Format: `(siblingFieldName, allowedValues)`. When null, the field is
  /// always rendered.
  final ({String field, List<String> values})? showWhen;

  /// Whether the field must be filled. The form blocks Save with a hint when
  /// any required field is empty. Default true to match the web's "all
  /// fields required unless marked otherwise" pattern.
  final bool required;
}

class DemoApproval {
  const DemoApproval({
    required this.id,
    required this.title,
    required this.prompt,
    required this.actionType,
    required this.risk,
    required this.status,
    required this.payload,
    this.groupedCount,
    this.sharedShape,
    this.conversationId,
    this.individualRecords = const [],
    this.recordCount,
    this.confirmPhrase,
    this.batchScoped = false,
  });

  final String id;
  final String title;
  final String prompt;
  final String actionType;
  final String risk;
  final DemoApprovalStatus status;
  final Map<String, String> payload;

  /// Number of sibling approvals sharing this shape.
  ///
  /// **Demo data only.** The backend confirmed on 2026-08-06 that no
  /// `grouped_count` field exists anywhere — grouping is resolved by POSTing
  /// `scope: "batch"`, and the count of what that cleared comes back in the
  /// RESPONSE (`batch.resolved_count`), not on the incoming card. So a real
  /// approval can never know its group size up front, and no server-fed card
  /// sets this. It survives to keep the demo screenshots rendering; nothing
  /// on the live path may key a label off it.
  final int? groupedCount;

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

  /// Optional individual rows behind a grouped approval. Rendered in a
  /// collapsible block under the group card.
  final List<DemoApprovalIndividual> individualRecords;

  /// Records this write touches, straight from the server (`record_count`).
  /// Drives the delete type-to-confirm phrase ("Delete 6" / "حذف 6"), which
  /// is why it is the SERVER's count and never a client-side guess.
  final int? recordCount;

  /// `Approval.confirmPhrase` — the server's canonical delete phrase.
  final String? confirmPhrase;

  /// `payload.batch_scope` — already auto-approved by a scope the user
  /// granted earlier, so offering to batch it again is offering a no-op.
  final bool batchScoped;

  bool get isGrouped => (groupedCount ?? 1) > 1;

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

/// One row inside a grouped approval — e.g. one of the 12 records the agent
/// wants to write. Kept lightweight on purpose; the grouped card just lists
/// these so the user can spot-check before approving in bulk.
class DemoApprovalIndividual {
  const DemoApprovalIndividual({required this.id, required this.summary});

  final String id;
  final String summary;
}

class DemoPendingAction {
  const DemoPendingAction({
    required this.id,
    required this.title,
    required this.body,
    required this.icon,
    required this.color,
    required this.conversationId,
    this.requestsCredential,
  });

  final String id;
  final String title;
  final String body;
  final IconData icon;
  final Color color;

  /// The conversation that raised this action. Used so the chat sheet only
  /// surfaces actions from THIS chat instead of pulling a global feed.
  final String conversationId;

  /// When non-null, the action is a `request_credentials` call from the agent.
  /// The Chat screen reads this to render the inline credential request form
  /// (spec §6.7) when the user taps "Provide" instead of the dismiss path.
  final DemoCredentialKind? requestsCredential;
}

/// One `run_server_command` (or `run_server_sudo_command`) result —
/// surfaced inside the chat's Activity sheet. Mirrors the web's
/// `buildServerActivityCard()` payload: status dot (ok/err) + the executed
/// command + stdout/stderr captures + exit code.
class DemoServerActivity {
  const DemoServerActivity({
    required this.id,
    required this.conversationId,
    required this.command,
    required this.createdLabel,
    this.stdout = '',
    this.stderr = '',
    this.returnCode = 0,
    this.host,
  });

  final String id;
  final String conversationId;
  final String command;
  final String stdout;
  final String stderr;
  final int returnCode;
  final String createdLabel;

  /// Optional `user@host` label rendered in the card header for context —
  /// helpful when the same conversation runs commands across multiple
  /// boxes via different SSH credentials.
  final String? host;

  bool get failed => returnCode != 0 || stderr.trim().isNotEmpty;
}

class DemoArtifact {
  const DemoArtifact({
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
