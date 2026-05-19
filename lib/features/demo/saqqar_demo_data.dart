import 'package:flutter/material.dart';

import '../../core/theme/app_icons.dart';

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
    this.toolName,
    this.attachments = const [],
    this.createdAt,
  });

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

const demoConversations = <DemoConversation>[
  DemoConversation(
    id: '3abf67f5',
    title: 'محتاجه اعرف في موديول الموافقات طلب موافقة الخرسانة',
    preview: 'I need your PostgreSQL credentials to continue.',
    updatedLabel: 'Yesterday',
    messageCount: 80,
    activeCredential: 'gac-staging',
    environmentId: 'gac-staging',
    hasPending: true,
  ),
  DemoConversation(
    id: '26e07cdd',
    title: 'هل كل الموظفين مربوطين بمستخدمين؟',
    preview: 'الحقول مخزنة وليست computed أو related.',
    updatedLabel: 'Yesterday',
    messageCount: 107,
    activeCredential: 'gac-staging',
    environmentId: 'gac-staging',
  ),
  DemoConversation(
    id: 'c74c6b90',
    title: 'how many users?',
    preview: '199 users.',
    updatedLabel: 'May 9',
    messageCount: 4,
    activeCredential: 'alzomman-staging',
    environmentId: 'alzomman-staging',
  ),
  DemoConversation(
    id: 'ae8d2f4b',
    title: 'illustrate this image',
    preview: 'The image shows a person wearing a black hoodie and cap.',
    updatedLabel: 'May 9',
    messageCount: 2,
    activeCredential: 'none',
  ),
  DemoConversation(
    id: '3178101c',
    title: 'GAC staging users by type',
    preview: 'Internal users: 55. Portal/Public users: 25,478.',
    updatedLabel: 'May 8',
    messageCount: 67,
    activeCredential: 'gac-staging',
    environmentId: 'gac-staging',
  ),
  // A conversation pinned to a LIVE environment so the chat warning fires
  // the first time the user sends a message in it.
  DemoConversation(
    id: 'prod-pulse',
    title: 'GAC production sanity check',
    preview: 'Inspect a single live record before the deploy.',
    updatedLabel: 'May 8',
    messageCount: 1,
    activeCredential: 'gac-staging',
    environmentId: 'gac-production',
    hasPending: true,
  ),
  DemoConversation(
    id: 'archived-1',
    title: 'Old export run',
    preview: 'Excel report generated and shared.',
    updatedLabel: 'Older',
    messageCount: 12,
    activeCredential: 'zad-staging',
    environmentId: 'zad-staging',
    isArchived: true,
  ),
];

const demoMessages = <DemoMessage>[
  DemoMessage(
    role: DemoMessageRole.user,
    content: 'how many users?',
    time: '12:50 AM',
  ),
  DemoMessage(
    role: DemoMessageRole.assistant,
    content: 'Checking Odoo data with the active credential.',
    time: '12:50 AM',
    toolName: 'count_odoo_records',
  ),
  DemoMessage(
    role: DemoMessageRole.tool,
    content:
        '{"status":"ok","credential_name":"alzomman-staging","model":"res.users","count":199,"server_version":"19.0+e"}',
    time: '12:50 AM',
    toolName: 'count_odoo_records',
  ),
  DemoMessage(
    role: DemoMessageRole.assistant,
    content: '199 users.',
    time: '12:50 AM',
  ),
  DemoMessage(
    role: DemoMessageRole.user,
    content: 'Export active internal users if the count is above 50.',
    time: '12:52 AM',
    attachments: [
      DemoAttachment(name: 'users_filter.csv', kind: 'CSV', size: '14 KB'),
    ],
  ),
  DemoMessage(
    role: DemoMessageRole.assistant,
    content:
        'The count is above 50. I prepared an Excel artifact and a write action that needs approval before it touches Odoo.',
    time: '12:53 AM',
    attachments: [
      DemoAttachment(
        name: 'active_internal_users.xlsx',
        kind: 'Spreadsheet',
        size: '128 KB',
        source: AttachmentSource.generatedOutput,
      ),
    ],
  ),
];

const demoCredentials = <DemoCredential>[
  DemoCredential(
    name: 'al-arabia-staging',
    label: 'Al Arabia Staging',
    kind: DemoCredentialKind.xmlrpc,
    source: 'dh.password #42',
    lastVerified: 'May 9, 12:23 AM',
    isMemorized: true,
  ),
  DemoCredential(
    name: 'alathereia-staging',
    label: 'Alathereia Staging',
    kind: DemoCredentialKind.xmlrpc,
    source: 'dh.password #45',
    lastVerified: null,
    isMemorized: true,
  ),
  DemoCredential(
    name: 'alzomman-staging',
    label: 'ALZOMMAN Staging',
    kind: DemoCredentialKind.xmlrpc,
    source: 'dh.password #38',
    lastVerified: 'May 9, 12:33 AM',
    isMemorized: true,
  ),
  DemoCredential(
    name: 'gac-staging',
    label: 'GAC Staging',
    kind: DemoCredentialKind.xmlrpc,
    source: 'dh.password #14',
    lastVerified: 'May 9, 12:36 AM',
    isMemorized: true,
  ),
  DemoCredential(
    name: 'icg-staging',
    label: 'ICG Staging',
    kind: DemoCredentialKind.xmlrpc,
    source: 'dh.password #19',
    lastVerified: 'May 9, 12:40 AM',
    isMemorized: true,
  ),
  DemoCredential(
    name: 'rajhi-staging',
    label: 'Rajhi Staging',
    kind: DemoCredentialKind.xmlrpc,
    source: 'dh.password #27',
    lastVerified: null,
    isMemorized: true,
  ),
  DemoCredential(
    name: 'sahm-musanda-staging',
    label: 'Sahm Musanda Staging',
    kind: DemoCredentialKind.xmlrpc,
    source: 'dh.password #31',
    lastVerified: 'May 9, 12:45 AM',
    isMemorized: true,
  ),
  DemoCredential(
    name: 'zad-staging',
    label: 'ZAD Staging',
    kind: DemoCredentialKind.xmlrpc,
    source: 'dh.password #08',
    lastVerified: 'May 9, 12:50 AM',
    isMemorized: true,
  ),
  DemoCredential(
    name: 'postgres-prod',
    label: 'Production PostgreSQL',
    kind: DemoCredentialKind.postgres,
    source: 'session',
    lastVerified: null,
    isMemorized: false,
  ),
  DemoCredential(
    name: 'server-shell',
    label: 'Odoo Server Shell',
    kind: DemoCredentialKind.serverShell,
    source: 'session',
    lastVerified: null,
    isMemorized: false,
  ),
  DemoCredential(
    name: 'addons-github',
    label: 'GitHub Addons Repo',
    kind: DemoCredentialKind.github,
    source: 'session',
    lastVerified: null,
    isMemorized: false,
  ),
];

const demoCredentialSchemas = <DemoCredentialSchema>[
  DemoCredentialSchema(
    kind: DemoCredentialKind.xmlrpc,
    label: 'Odoo XML-RPC',
    fields: [
      DemoCredentialField(
        name: 'url',
        label: 'URL',
        hint: 'https://odoo.example.com',
      ),
      DemoCredentialField(name: 'db', label: 'Database', hint: 'production'),
      DemoCredentialField(
        name: 'username',
        label: 'Username',
        hint: 'admin@example.com',
      ),
      DemoCredentialField(name: 'password', label: 'Password', obscure: true),
    ],
  ),
  DemoCredentialSchema(
    kind: DemoCredentialKind.postgres,
    label: 'PostgreSQL',
    fields: [
      DemoCredentialField(name: 'host', label: 'Host'),
      DemoCredentialField(
        name: 'port',
        label: 'Port',
        hint: '5432',
        required: false,
      ),
      DemoCredentialField(name: 'dbname', label: 'Database'),
      DemoCredentialField(name: 'username', label: 'Username'),
      DemoCredentialField(name: 'password', label: 'Password', obscure: true),
      DemoCredentialField(
        name: 'sslmode',
        label: 'SSL mode',
        hint: 'prefer',
        required: false,
        help: 'Common values: disable · require · verify-full',
      ),
    ],
  ),
  DemoCredentialSchema(
    kind: DemoCredentialKind.serverShell,
    label: 'Server shell',
    fields: [
      DemoCredentialField(
        name: 'auth',
        label: 'Auth',
        options: ['password', 'key'],
        required: false,
        help: 'Use password or SSH key',
      ),
      DemoCredentialField(name: 'host', label: 'Host'),
      DemoCredentialField(
        name: 'port',
        label: 'Port',
        hint: '22',
        required: false,
      ),
      DemoCredentialField(name: 'username', label: 'Username'),
      DemoCredentialField(
        name: 'password',
        label: 'Password',
        obscure: true,
        required: false,
        help: 'Fill this for password auth',
        showWhen: (field: 'auth', values: ['password']),
      ),
      DemoCredentialField(
        name: 'private_key',
        label: 'Private key',
        multiline: true,
        required: false,
        help: 'Paste the private SSH key when auth is set to key',
        showWhen: (field: 'auth', values: ['key']),
      ),
    ],
  ),
  DemoCredentialSchema(
    kind: DemoCredentialKind.github,
    label: 'GitHub',
    fields: [
      DemoCredentialField(name: 'token', label: 'Token', obscure: true),
      DemoCredentialField(name: 'owner', label: 'Owner', required: false),
      DemoCredentialField(name: 'repo', label: 'Repo', required: false),
    ],
  ),
];

const demoApprovals = <DemoApproval>[
  DemoApproval(
    id: 'apr-1024',
    title: 'Execute approved Odoo write',
    prompt: 'Update 12 approval request records after validation.',
    actionType: 'odoo_write',
    risk: 'Medium',
    status: DemoApprovalStatus.pending,
    conversationId: '3abf67f5',
    groupedCount: 12,
    sharedShape: 'odoo_write:approval.request:write',
    payload: {
      'model': 'approval.request',
      'operation': 'write',
      'records': '12',
    },
    individualRecords: [
      DemoApprovalIndividual(id: 'rec-101', summary: 'approval.request #101 · state=approved'),
      DemoApprovalIndividual(id: 'rec-102', summary: 'approval.request #102 · state=approved'),
      DemoApprovalIndividual(id: 'rec-103', summary: 'approval.request #103 · state=approved'),
      DemoApprovalIndividual(id: 'rec-104', summary: 'approval.request #104 · state=approved'),
      DemoApprovalIndividual(id: 'rec-105', summary: 'approval.request #105 · state=approved'),
      DemoApprovalIndividual(id: 'rec-106', summary: 'approval.request #106 · state=approved'),
      DemoApprovalIndividual(id: 'rec-107', summary: 'approval.request #107 · state=approved'),
      DemoApprovalIndividual(id: 'rec-108', summary: 'approval.request #108 · state=approved'),
      DemoApprovalIndividual(id: 'rec-109', summary: 'approval.request #109 · state=approved'),
      DemoApprovalIndividual(id: 'rec-110', summary: 'approval.request #110 · state=approved'),
      DemoApprovalIndividual(id: 'rec-111', summary: 'approval.request #111 · state=approved'),
      DemoApprovalIndividual(id: 'rec-112', summary: 'approval.request #112 · state=approved'),
    ],
  ),
  DemoApproval(
    id: 'apr-1025',
    title: 'Run server command',
    prompt: 'Run a read-only log inspection command on the Odoo server.',
    actionType: 'server_command',
    risk: 'High',
    status: DemoApprovalStatus.pending,
    conversationId: 'prod-pulse',
    payload: {
      'command': 'tail -n 200 /var/log/odoo/odoo.log',
      'credential': 'server-shell',
    },
  ),
  DemoApproval(
    id: 'apr-1026',
    title: 'Use stored credential for this request',
    prompt:
        'Saqqar wants to reuse the saved GAC staging credential to read users for this turn only. Approve to allow a single use; reject to keep it idle.',
    actionType: 'credential_usage',
    risk: 'Low',
    status: DemoApprovalStatus.pending,
    conversationId: 'c74c6b90',
    payload: {
      'credential': 'gac-staging',
      'scope': 'single_use',
      'model': 'res.users',
    },
  ),
  DemoApproval(
    id: 'apr-1027',
    title: 'Generate Excel report',
    prompt:
        'Export 1,284 active internal users into an Excel artifact. The file is ready to download once approved.',
    actionType: 'report_export',
    risk: 'Low',
    status: DemoApprovalStatus.pending,
    conversationId: '3178101c',
    payload: {
      'format': 'xlsx',
      'rows': '1284',
      'filename': 'active_internal_users.xlsx',
    },
  ),
  DemoApproval(
    id: 'apr-1012',
    title: 'Memorize credential',
    prompt: 'Store GAC staging for future chats after approval.',
    actionType: 'credential_storage',
    risk: 'Low',
    status: DemoApprovalStatus.approved,
    conversationId: '3abf67f5',
    payload: {'credential': 'gac-staging'},
  ),
  // Extra pending approvals seeded across the most-likely-opened
  // conversations so the inline PendingApprovalsBanner is visible no
  // matter which chat the user lands in. When the API ships, drop these.
  DemoApproval(
    id: 'apr-2001',
    title: 'Update employee linkage',
    prompt: 'Link 7 unmatched hr.employee records to res.users — Saqqar wants approval before it writes.',
    actionType: 'odoo_write',
    risk: 'Medium',
    status: DemoApprovalStatus.pending,
    conversationId: '26e07cdd',
    payload: {'model': 'hr.employee', 'operation': 'write', 'records': '7'},
  ),
  DemoApproval(
    id: 'apr-2002',
    title: 'Save annotated screenshot',
    prompt: 'Attach the annotated copy of the user\'s image to this conversation\'s artifacts.',
    actionType: 'report_export',
    risk: 'Low',
    status: DemoApprovalStatus.pending,
    conversationId: 'ae8d2f4b',
    payload: {'format': 'png', 'filename': 'annotated.png'},
  ),
];

const demoPendingActions = <DemoPendingAction>[
  DemoPendingAction(
    id: 'act-1',
    title: 'PostgreSQL credentials needed',
    body: 'Saqqar needs database read access to inspect approval tables.',
    icon: AppIcons.database,
    color: Color(0xFF8B5CF6),
    conversationId: '3abf67f5',
    requestsCredential: DemoCredentialKind.postgres,
  ),
  DemoPendingAction(
    id: 'act-2',
    title: 'Review generated artifact',
    body:
        'An Excel report is ready. Open it before approving the final change.',
    icon: AppIcons.table,
    color: Color(0xFF06B6D4),
    conversationId: '3178101c',
  ),
];

const demoArtifacts = <DemoArtifact>[
  DemoArtifact(
    id: 'art-199',
    name: 'active_internal_users.xlsx',
    kind: 'Excel',
    size: '128 KB',
    conversation: 'how many users?',
    conversationId: 'c74c6b90',
    createdLabel: 'May 9, 12:53 AM',
  ),
  DemoArtifact(
    id: 'art-198',
    name: 'approval_request_audit.csv',
    kind: 'CSV',
    size: '84 KB',
    conversation: 'محتاجه اعرف في موديول الموافقات',
    conversationId: '3abf67f5',
    createdLabel: 'May 9, 3:04 PM',
  ),
  DemoArtifact(
    id: 'art-197',
    name: 'server_activity.log',
    kind: 'Log',
    size: '31 KB',
    conversation: 'GAC production sanity check',
    conversationId: 'prod-pulse',
    createdLabel: 'May 8, 10:17 PM',
  ),
  DemoArtifact(
    id: 'art-196',
    name: 'portal_users_snapshot.xlsx',
    kind: 'Excel',
    size: '212 KB',
    conversation: 'GAC staging users by type',
    conversationId: '3178101c',
    createdLabel: 'May 8, 9:41 PM',
  ),
  DemoArtifact(
    id: 'art-195',
    name: 'module_dependency_graph.json',
    kind: 'JSON',
    size: '46 KB',
    conversation: 'محتاجه اعرف في موديول الموافقات',
    conversationId: '3abf67f5',
    createdLabel: 'May 8, 8:20 PM',
  ),
  DemoArtifact(
    id: 'art-194',
    name: 'odoo_error_screenshot.png',
    kind: 'Image',
    size: '394 KB',
    conversation: 'GAC production sanity check',
    conversationId: 'prod-pulse',
    createdLabel: 'May 8, 7:58 PM',
  ),
  DemoArtifact(
    id: 'art-193',
    name: 'timesheet_fields_audit.csv',
    kind: 'CSV',
    size: '67 KB',
    conversation: 'هل كل الموظفين مربوطين بمستخدمين؟',
    conversationId: '26e07cdd',
    createdLabel: 'May 8, 7:12 PM',
  ),
  DemoArtifact(
    id: 'art-192',
    name: 'github_addons_review.md',
    kind: 'Markdown',
    size: '22 KB',
    conversation: 'GAC staging users by type',
    conversationId: '3178101c',
    createdLabel: 'May 8, 6:49 PM',
  ),
];

// ───── Per-conversation helpers (chat sheets call these) ─────────────────

List<DemoArtifact> demoArtifactsForConversation(String conversationId) {
  return demoArtifacts.where((a) => a.conversationId == conversationId).toList();
}

/// Seeded server-command activity. Two conversations have shell runs so
/// the Activity sheet has something to render in the demo; the rest stay
/// empty and exercise the "No server commands yet" empty state.
const demoServerActivity = <DemoServerActivity>[
  DemoServerActivity(
    id: 'act-1',
    conversationId: 'prod-pulse',
    command: 'tail -n 100 /var/log/odoo/odoo-server.log',
    host: 'odoo@gac-prod',
    createdLabel: '12 min ago',
    stdout: '''2026-05-16 17:14:02,118 INFO gac-prod odoo.modules.loading: Modules loaded.
2026-05-16 17:14:02,201 INFO gac-prod werkzeug: Listening on http://0.0.0.0:8069
2026-05-16 17:14:02,310 INFO gac-prod odoo.service.server: HTTP service running
2026-05-16 17:14:32,002 WARN gac-prod odoo.addons.mail: outbound queue length 142
2026-05-16 17:14:55,440 INFO gac-prod odoo.http: 80.121.5.4 POST /web/dataset/call_kw 200''',
  ),
  DemoServerActivity(
    id: 'act-2',
    conversationId: 'prod-pulse',
    command: 'systemctl status odoo --no-pager',
    host: 'odoo@gac-prod',
    createdLabel: '11 min ago',
    stdout: '''● odoo.service - Odoo
     Loaded: loaded (/etc/systemd/system/odoo.service; enabled)
     Active: active (running) since Wed 2026-05-14 10:02:13 UTC; 2 days ago
   Main PID: 1842 (python3)
      Tasks: 12 (limit: 4644)
     Memory: 612.4M''',
  ),
  DemoServerActivity(
    id: 'act-3',
    conversationId: 'prod-pulse',
    command: r'df -h | grep -E "/$|/var"',
    host: 'odoo@gac-prod',
    createdLabel: '8 min ago',
    stdout: '/dev/sda1        50G   38G   10G  79% /\n/dev/sdb1       100G   91G  9.5G  91% /var',
    stderr: '',
    returnCode: 0,
  ),
  DemoServerActivity(
    id: 'act-4',
    conversationId: 'prod-pulse',
    command: 'pg_ctl status -D /var/lib/postgresql/16/main',
    host: 'postgres@gac-prod',
    createdLabel: '6 min ago',
    stdout: '',
    stderr: 'pg_ctl: server is not running\nError: connection refused on socket /var/run/postgresql/.s.PGSQL.5432',
    returnCode: 3,
  ),
];

List<DemoServerActivity> demoServerActivityForConversation(
  String conversationId,
) {
  return demoServerActivity
      .where((a) => a.conversationId == conversationId)
      .toList();
}

List<DemoApproval> demoApprovalsForConversation(String conversationId) {
  return demoApprovals.where((a) => a.conversationId == conversationId).toList();
}

List<DemoPendingAction> demoPendingActionsForConversation(
  String conversationId,
) {
  return demoPendingActions
      .where((a) => a.conversationId == conversationId)
      .toList();
}

String demoCredentialKindLabel(DemoCredentialKind kind) {
  return switch (kind) {
    DemoCredentialKind.xmlrpc => 'Odoo XML-RPC',
    DemoCredentialKind.postgres => 'PostgreSQL',
    DemoCredentialKind.serverShell => 'Server shell',
    DemoCredentialKind.github => 'GitHub',
  };
}

IconData demoCredentialKindIcon(DemoCredentialKind kind) {
  return switch (kind) {
    DemoCredentialKind.xmlrpc => AppIcons.sparkles,
    DemoCredentialKind.postgres => AppIcons.database,
    DemoCredentialKind.serverShell => AppIcons.terminal,
    DemoCredentialKind.github => AppIcons.github,
  };
}

// ───── Projects & Environments ─────────────────────────────────────────────
//
// One project per Odoo customer. Each project has 1–2 environments. The env
// `id` matches the legacy `activeCredential` string on existing
// conversations, so the migration is a no-op for old data — we just look up
// the env by that id.

const demoProjects = <DemoProject>[
  DemoProject(id: 'al-arabia', name: 'Al Arabia'),
  DemoProject(id: 'alathereia', name: 'Alathereia'),
  DemoProject(id: 'alzomman', name: 'ALZOMMAN'),
  DemoProject(id: 'gac', name: 'GAC'),
  DemoProject(id: 'icg', name: 'ICG'),
  DemoProject(id: 'rajhi', name: 'Rajhi'),
  DemoProject(id: 'sahm-musanda', name: 'Sahm Musanda'),
  DemoProject(id: 'zad', name: 'ZAD'),
];

const demoEnvironments = <DemoEnvironment>[
  // Al Arabia — kept on auto-approve so the user can demo the env-level
  // shortcut. Picking this env flips the chat's auto-approve toggle on.
  DemoEnvironment(
    id: 'al-arabia-staging',
    projectId: 'al-arabia',
    name: 'Staging',
    autoApprove: true,
    credentialNames: ['al-arabia-staging'],
  ),
  // Alathereia
  DemoEnvironment(
    id: 'alathereia-staging',
    projectId: 'alathereia',
    name: 'Staging',
    credentialNames: ['alathereia-staging'],
  ),
  // ALZOMMAN
  DemoEnvironment(
    id: 'alzomman-staging',
    projectId: 'alzomman',
    name: 'Staging',
    credentialNames: ['alzomman-staging'],
  ),
  DemoEnvironment(
    id: 'alzomman-production',
    projectId: 'alzomman',
    name: 'Production',
    isLive: true,
    credentialNames: ['alzomman-staging'],
  ),
  // GAC
  DemoEnvironment(
    id: 'gac-staging',
    projectId: 'gac',
    name: 'Staging',
    credentialNames: ['gac-staging', 'postgres-prod'],
  ),
  DemoEnvironment(
    id: 'gac-production',
    projectId: 'gac',
    name: 'Production',
    isLive: true,
    credentialNames: ['gac-staging', 'postgres-prod', 'server-shell'],
  ),
  // ICG
  DemoEnvironment(
    id: 'icg-staging',
    projectId: 'icg',
    name: 'Staging',
    credentialNames: ['icg-staging'],
  ),
  // Rajhi
  DemoEnvironment(
    id: 'rajhi-staging',
    projectId: 'rajhi',
    name: 'Staging',
    credentialNames: ['rajhi-staging'],
  ),
  // Sahm Musanda
  DemoEnvironment(
    id: 'sahm-musanda-staging',
    projectId: 'sahm-musanda',
    name: 'Staging',
    credentialNames: ['sahm-musanda-staging'],
  ),
  // ZAD
  DemoEnvironment(
    id: 'zad-staging',
    projectId: 'zad',
    name: 'Staging',
    credentialNames: ['zad-staging'],
  ),
  DemoEnvironment(
    id: 'zad-production',
    projectId: 'zad',
    name: 'Production',
    isLive: true,
    readOnly: true,
    credentialNames: ['zad-staging'],
  ),
];

DemoEnvironment? demoEnvironmentById(String? id) {
  if (id == null || id.isEmpty || id == 'none') return null;
  for (final env in demoEnvironments) {
    if (env.id == id) return env;
  }
  return null;
}

DemoProject? demoProjectById(String id) {
  for (final p in demoProjects) {
    if (p.id == id) return p;
  }
  return null;
}

/// Resolves the active environment for a conversation. Prefers the new
/// [DemoConversation.environmentId] field; falls back to the legacy
/// [DemoConversation.activeCredential] string so existing seed data still
/// shows the right env in headers and pickers.
DemoEnvironment? demoEnvironmentForConversation(DemoConversation c) {
  final env = demoEnvironmentById(c.environmentId);
  if (env != null) return env;
  return demoEnvironmentById(c.activeCredential);
}

List<DemoEnvironment> demoEnvironmentsForProject(String projectId) {
  return demoEnvironments.where((e) => e.projectId == projectId).toList();
}

/// Human label rendered in headers, pickers, and breadcrumbs:
/// "GAC · Staging" or "GAC · Production" (with the live envs styled
/// elsewhere in the call site).
String demoEnvironmentLabel(DemoEnvironment env) {
  final project = demoProjectById(env.projectId);
  final projectName = project?.name ?? env.projectId;
  return '$projectName · ${env.name}';
}
