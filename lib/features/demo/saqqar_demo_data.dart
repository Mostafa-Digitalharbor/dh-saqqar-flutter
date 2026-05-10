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
    this.isArchived = false,
  });

  final String id;
  final String title;
  final String preview;
  final String updatedLabel;
  final int messageCount;
  final String activeCredential;
  final bool isArchived;
}

class DemoMessage {
  const DemoMessage({
    required this.role,
    required this.content,
    required this.time,
    this.toolName,
    this.attachments = const [],
  });

  final DemoMessageRole role;
  final String content;
  final String time;
  final String? toolName;
  final List<DemoAttachment> attachments;
}

class DemoAttachment {
  const DemoAttachment({
    required this.name,
    required this.kind,
    required this.size,
  });

  final String name;
  final String kind;
  final String size;
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
    this.obscure = false,
    this.multiline = false,
    this.options = const [],
  });

  final String name;
  final String label;
  final String? hint;
  final bool obscure;
  final bool multiline;
  final List<String> options;
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
  });

  final String id;
  final String title;
  final String prompt;
  final String actionType;
  final String risk;
  final DemoApprovalStatus status;
  final Map<String, String> payload;
}

class DemoPendingAction {
  const DemoPendingAction({
    required this.id,
    required this.title,
    required this.body,
    required this.icon,
    required this.color,
  });

  final String id;
  final String title;
  final String body;
  final IconData icon;
  final Color color;
}

class DemoArtifact {
  const DemoArtifact({
    required this.id,
    required this.name,
    required this.kind,
    required this.size,
    required this.conversation,
    required this.createdLabel,
  });

  final String id;
  final String name;
  final String kind;
  final String size;
  final String conversation;
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
  ),
  DemoConversation(
    id: '26e07cdd',
    title: 'هل كل الموظفين مربوطين بمستخدمين؟',
    preview: 'الحقول مخزنة وليست computed أو related.',
    updatedLabel: 'Yesterday',
    messageCount: 107,
    activeCredential: 'gac-staging',
  ),
  DemoConversation(
    id: 'c74c6b90',
    title: 'how many users?',
    preview: '199 users.',
    updatedLabel: 'May 9',
    messageCount: 4,
    activeCredential: 'alzomman-staging',
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
  ),
  DemoConversation(
    id: 'archived-1',
    title: 'Old export run',
    preview: 'Excel report generated and shared.',
    updatedLabel: 'Older',
    messageCount: 12,
    activeCredential: 'zad-staging',
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
      DemoCredentialField(name: 'port', label: 'Port', hint: '5432'),
      DemoCredentialField(name: 'dbname', label: 'Database'),
      DemoCredentialField(name: 'username', label: 'Username'),
      DemoCredentialField(name: 'password', label: 'Password', obscure: true),
      DemoCredentialField(name: 'sslmode', label: 'SSL mode', hint: 'prefer'),
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
      ),
      DemoCredentialField(name: 'host', label: 'Host'),
      DemoCredentialField(name: 'port', label: 'Port', hint: '22'),
      DemoCredentialField(name: 'username', label: 'Username'),
      DemoCredentialField(name: 'password', label: 'Password', obscure: true),
      DemoCredentialField(
        name: 'private_key',
        label: 'Private key',
        multiline: true,
      ),
    ],
  ),
  DemoCredentialSchema(
    kind: DemoCredentialKind.github,
    label: 'GitHub',
    fields: [
      DemoCredentialField(name: 'token', label: 'Token', obscure: true),
      DemoCredentialField(name: 'owner', label: 'Owner'),
      DemoCredentialField(name: 'repo', label: 'Repo'),
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
    payload: {
      'model': 'approval.request',
      'operation': 'write',
      'records': '12',
    },
  ),
  DemoApproval(
    id: 'apr-1025',
    title: 'Run server command',
    prompt: 'Run a read-only log inspection command on the Odoo server.',
    actionType: 'server_command',
    risk: 'High',
    status: DemoApprovalStatus.pending,
    payload: {
      'command': 'tail -n 200 /var/log/odoo/odoo.log',
      'credential': 'server-shell',
    },
  ),
  DemoApproval(
    id: 'apr-1012',
    title: 'Memorize credential',
    prompt: 'Store GAC staging for future chats after approval.',
    actionType: 'credential_storage',
    risk: 'Low',
    status: DemoApprovalStatus.approved,
    payload: {'credential': 'gac-staging'},
  ),
];

const demoPendingActions = <DemoPendingAction>[
  DemoPendingAction(
    id: 'act-1',
    title: 'PostgreSQL credentials needed',
    body: 'Saqqar needs database read access to inspect approval tables.',
    icon: AppIcons.database,
    color: Color(0xFF8B5CF6),
  ),
  DemoPendingAction(
    id: 'act-2',
    title: 'Review generated artifact',
    body:
        'An Excel report is ready. Open it before approving the final change.',
    icon: AppIcons.table,
    color: Color(0xFF06B6D4),
  ),
];

const demoArtifacts = <DemoArtifact>[
  DemoArtifact(
    id: 'art-199',
    name: 'active_internal_users.xlsx',
    kind: 'Excel',
    size: '128 KB',
    conversation: 'how many users?',
    createdLabel: 'May 9, 12:53 AM',
  ),
  DemoArtifact(
    id: 'art-198',
    name: 'approval_request_audit.csv',
    kind: 'CSV',
    size: '84 KB',
    conversation: 'محتاجه اعرف في موديول الموافقات',
    createdLabel: 'May 9, 3:04 PM',
  ),
  DemoArtifact(
    id: 'art-197',
    name: 'server_activity.log',
    kind: 'Log',
    size: '31 KB',
    conversation: 'Server issue diagnosis',
    createdLabel: 'May 8, 10:17 PM',
  ),
  DemoArtifact(
    id: 'art-196',
    name: 'portal_users_snapshot.xlsx',
    kind: 'Excel',
    size: '212 KB',
    conversation: 'GAC staging users by type',
    createdLabel: 'May 8, 9:41 PM',
  ),
  DemoArtifact(
    id: 'art-195',
    name: 'module_dependency_graph.json',
    kind: 'JSON',
    size: '46 KB',
    conversation: 'Inspect approval module dependencies',
    createdLabel: 'May 8, 8:20 PM',
  ),
  DemoArtifact(
    id: 'art-194',
    name: 'odoo_error_screenshot.png',
    kind: 'Image',
    size: '394 KB',
    conversation: 'Server issue diagnosis',
    createdLabel: 'May 8, 7:58 PM',
  ),
  DemoArtifact(
    id: 'art-193',
    name: 'timesheet_fields_audit.csv',
    kind: 'CSV',
    size: '67 KB',
    conversation: 'هل كل الموظفين مربوطين بمستخدمين؟',
    createdLabel: 'May 8, 7:12 PM',
  ),
  DemoArtifact(
    id: 'art-192',
    name: 'github_addons_review.md',
    kind: 'Markdown',
    size: '22 KB',
    conversation: 'Review custom addons repository',
    createdLabel: 'May 8, 6:49 PM',
  ),
];

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
