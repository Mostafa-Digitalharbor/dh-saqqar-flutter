import 'package:flutter/material.dart';

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

  /// Absolute URL of the underlying file on the server (PDF, DOCX, image,
  /// etc.). When non-null the attachment chip becomes tappable and the
  /// download flow opens the file with the OS's matching viewer.
  final String? downloadUrl;

  /// Server-side id of the attachment. Used as the on-disk cache key so
  /// the same file isn't re-downloaded each time the user taps it.
  final String? serverId;

  final AttachmentSource source;

  bool get isImage {
    final k = kind.toUpperCase();
    return k == 'IMAGE' ||
        k == 'PNG' ||
        k == 'JPG' ||
        k == 'JPEG' ||
        k == 'GIF' ||
        k == 'WEBP';
  }

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
  });

  final String id;
  final String title;
  final String prompt;
  final String actionType;
  final String risk;
  final DemoApprovalStatus status;
  final Map<String, String> payload;

  /// When >1, the card renders as a grouped approval (e.g. "12 similar
  /// requests") with an "Approve all" CTA. Null or 1 means a single record.
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

  bool get isGrouped => (groupedCount ?? 1) > 1;
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
