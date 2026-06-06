import 'package:flutter/foundation.dart';

import '../../billing/data/plan_models.dart';
import '../../inbox/data/approval_models.dart';
import '../../inbox/data/artifact_models.dart';
import '../../vault/data/credential_models.dart';
import '../../vault/data/project_models.dart';
import 'attachment_models.dart';

// ─────────────────────────────────────────────────────────────────────────
// Messages
// ─────────────────────────────────────────────────────────────────────────

enum MessageRole {
  user('user'),
  assistant('assistant'),
  tool('tool'),
  system('system');

  const MessageRole(this.wire);
  final String wire;

  static MessageRole fromWire(String? value) {
    for (final r in MessageRole.values) {
      if (r.wire == value) return r;
    }
    return MessageRole.system;
  }
}

@immutable
class Message {
  const Message({
    required this.id,
    required this.role,
    required this.content,
    required this.createdAt,
    this.toolName,
    this.toolPayload,
    this.attachments = const [],
  });

  final String id;
  final MessageRole role;
  final String content;
  final DateTime createdAt;

  /// Empty for user / assistant rows. For assistant rows that triggered
  /// tool calls, [toolPayload] carries `tool_calls`. For tool rows, this
  /// is the tool name and [content] is the (capped) tool result.
  final String? toolName;
  final Map<String, dynamic>? toolPayload;

  final List<Attachment> attachments;

  factory Message.fromJson(Map<String, dynamic> json) {
    final tn = json['tool_name'];
    return Message(
      id: json['id'] as String,
      role: MessageRole.fromWire(json['role'] as String?),
      content: json['content'] as String? ?? '',
      createdAt: _parseDate(json['created_at']) ?? DateTime.now(),
      toolName: tn is String && tn.isNotEmpty ? tn : null,
      toolPayload: (json['tool_payload'] as Map?)?.cast<String, dynamic>(),
      attachments: (json['attachments'] as List? ?? [])
          .cast<Map<String, dynamic>>()
          .map(Attachment.fromJson)
          .toList(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// RunProgress
// ─────────────────────────────────────────────────────────────────────────

/// Long-running tool progress (export jobs). Empty between runs.
@immutable
class RunProgress {
  const RunProgress({
    required this.phase,
    this.current,
    this.total,
    this.label,
  });

  /// Free-form stage identifier — e.g. `building_report`, `rendering_report`.
  final String phase;

  /// Items processed so far. `null` for indeterminate runs.
  final int? current;

  /// Total items. `null` for SQL exports (no cheap pre-count); render an
  /// indeterminate progress bar in that case.
  final int? total;

  /// Short human label (≤100 chars) — safe to show verbatim.
  final String? label;

  bool get isIndeterminate => total == null || total == 0;

  factory RunProgress.fromJson(Map<String, dynamic> json) {
    return RunProgress(
      phase: json['phase'] as String? ?? '',
      current: (json['current'] as num?)?.toInt(),
      total: (json['total'] as num?)?.toInt(),
      label: json['label'] as String?,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// PendingAction
// ─────────────────────────────────────────────────────────────────────────

/// User-facing prompt written by the agent. Today only `collect_credentials`
/// is emitted; mobile renders these inline in chat AND on the Inbox tab.
///
/// Remove by either submitting the matching credential, or by calling
/// `POST .../pending-actions/dismiss/` (see [ConversationsApi.dismissPendingAction]).
@immutable
class PendingAction {
  const PendingAction({
    required this.type,
    this.credentialName,
    this.credentialKind,
    this.requiredFields = const [],
    this.fieldSchema = const [],
    this.reason,
    this.rememberPreference,
  });

  /// `collect_credentials` is the only emitted value today; treat unknown
  /// strings as opaque and skip rendering.
  final String type;

  final String? credentialName;
  final CredentialKind? credentialKind;
  final List<String> requiredFields;

  /// Same shape as [CredentialSchema.fields] — render against this.
  final List<CredentialField> fieldSchema;

  final String? reason;

  /// `'session_only' | 'memorize'` — pre-checks the matching toggle in the
  /// inline credential form.
  final String? rememberPreference;

  factory PendingAction.fromJson(Map<String, dynamic> json) {
    return PendingAction(
      type: json['type'] as String? ?? '',
      credentialName: json['credential_name'] as String?,
      credentialKind: CredentialKind.fromWire(
        json['credential_kind'] as String?,
      ),
      requiredFields: (json['required_fields'] as List? ?? [])
          .map((e) => e.toString())
          .toList(),
      fieldSchema: (json['field_schema'] as List? ?? [])
          .cast<Map<String, dynamic>>()
          .map(CredentialField.fromJson)
          .toList(),
      reason: json['reason'] as String?,
      rememberPreference: json['remember_preference'] as String?,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Conversation summary (list row)
// ─────────────────────────────────────────────────────────────────────────

@immutable
class ConversationSummary {
  const ConversationSummary({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
    required this.isArchived,
    required this.messageCount,
    this.lastMessagePreview = '',
  });

  final String id;
  final String title;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isArchived;
  final int messageCount;
  final String lastMessagePreview;

  factory ConversationSummary.fromJson(Map<String, dynamic> json) {
    return ConversationSummary(
      id: json['id'] as String,
      title: json['title'] as String? ?? '',
      createdAt: _parseDate(json['created_at']) ?? DateTime.now(),
      updatedAt: _parseDate(json['updated_at']) ?? DateTime.now(),
      isArchived: json['is_archived'] as bool? ?? false,
      messageCount: (json['message_count'] as num?)?.toInt() ?? 0,
      lastMessagePreview: json['last_message_preview'] as String? ?? '',
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Conversation (detail / snapshot)
// ─────────────────────────────────────────────────────────────────────────

@immutable
class Conversation {
  const Conversation({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
    required this.autoApprove,
    required this.deepThink,
    required this.isRunning,
    required this.stopRequested,
    this.context = const {},
    this.runProgress,
    this.runError,
    this.activeCredential,
    this.environment,
    this.project,
    this.isArchived = false,
    this.plan,
    this.needsEnvironment = false,
  });

  final String id;
  final String title;

  /// Server-side scratchpad. The load-bearing keys are surfaced as
  /// top-level fields here ([activeCredential], etc.) — treat the rest
  /// as opaque.
  final Map<String, dynamic> context;

  final DateTime createdAt;
  final DateTime updatedAt;
  final bool autoApprove;

  /// Per-conversation "deep think" toggle. Nullable on purpose:
  ///   * `true` / `false` — the server returned an explicit value, use
  ///     it as the source of truth (the web persists it the same way).
  ///   * `null`           — the server didn't include the field at all
  ///     (older deployments where deep-think lives only client-side).
  ///     Callers fall back to the local [DeepThinkCubit] in that case
  ///     so the toggle still works inside the app even when no sync
  ///     channel exists.
  ///
  /// Read from the top-level `deep_think` field first (canonical),
  /// falls back to `context['deep_think']` for backwards compatibility.
  final bool? deepThink;
  final bool isArchived;

  /// `true` while the agent worker is processing this conversation.
  /// Drives the polling cadence (1.5 s vs 15 s) and disables Send.
  final bool isRunning;

  /// `true` after [ConversationsApi.stop] — the worker is exiting; UI may
  /// show "Stopping…".
  final bool stopRequested;

  final RunProgress? runProgress;
  final String? runError;

  /// Legacy single-credential pointer (slug). New conversations use
  /// [environment] binding instead.
  final String? activeCredential;

  final Environment? environment;
  final Project? project;

  /// Plan / quota / feature snapshot for the calling user. Carried on every
  /// conversation snapshot; surfaced app-wide via `PlanCubit`. `null` only
  /// on older snapshots that predate the field.
  final PlanSnapshot? plan;

  /// `true` when this conversation has no environment bound yet — drives the
  /// "Use My Database" env-hint banner (Gap H).
  final bool needsEnvironment;

  factory Conversation.fromJson(Map<String, dynamic> json) {
    final env = json['environment'];
    final proj = json['project'];
    final rp = json['run_progress'];
    final ctx = (json['context'] as Map?)?.cast<String, dynamic>() ?? const {};
    // Deep-think persistence shape isn't pinned yet — try the top-level
    // canonical key first, then fall back to `context.deep_think` for
    // older snapshots. STAYS null when neither is present so callers
    // can fall back to the local DeepThinkCubit instead of defaulting
    // to false (which used to clobber the user's local toggle the
    // moment the next poll landed).
    final deepThinkRaw = json['deep_think'] ?? ctx['deep_think'];
    return Conversation(
      id: json['id'] as String,
      title: json['title'] as String? ?? '',
      context: ctx,
      createdAt: _parseDate(json['created_at']) ?? DateTime.now(),
      updatedAt: _parseDate(json['updated_at']) ?? DateTime.now(),
      autoApprove: json['auto_approve'] as bool? ?? false,
      deepThink: deepThinkRaw is bool ? deepThinkRaw : null,
      isArchived: json['is_archived'] as bool? ?? false,
      isRunning: json['is_running'] as bool? ?? false,
      stopRequested: json['stop_requested'] as bool? ?? false,
      runProgress: rp is Map<String, dynamic> && rp.isNotEmpty
          ? RunProgress.fromJson(rp)
          : null,
      runError: json['run_error'] as String?,
      activeCredential: json['active_credential'] as String?,
      environment: env is Map<String, dynamic>
          ? Environment.fromJson(env)
          : null,
      project: proj is Map<String, dynamic>
          ? Project.fromJson({
              ...proj,
              'environments': const <Map<String, dynamic>>[],
            })
          : null,
      plan: json['plan'] is Map<String, dynamic>
          ? PlanSnapshot.fromJson(json['plan'] as Map<String, dynamic>)
          : null,
      needsEnvironment: json['needs_environment'] as bool? ?? false,
    );
  }

  /// Returns a copy with selected fields overridden. Used by ChatCubit
  /// to flip per-conversation toggles (auto_approve / deep_think)
  /// optimistically before the server round-trip lands.
  Conversation copyWith({
    String? title,
    Map<String, dynamic>? context,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? autoApprove,
    bool? deepThink,
    bool? isArchived,
    bool? isRunning,
    bool? stopRequested,
    RunProgress? runProgress,
    String? runError,
    String? activeCredential,
    Environment? environment,
    Project? project,
    PlanSnapshot? plan,
    bool? needsEnvironment,
  }) {
    return Conversation(
      id: id,
      title: title ?? this.title,
      context: context ?? this.context,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      autoApprove: autoApprove ?? this.autoApprove,
      deepThink: deepThink ?? this.deepThink,
      isArchived: isArchived ?? this.isArchived,
      isRunning: isRunning ?? this.isRunning,
      stopRequested: stopRequested ?? this.stopRequested,
      runProgress: runProgress ?? this.runProgress,
      runError: runError ?? this.runError,
      activeCredential: activeCredential ?? this.activeCredential,
      environment: environment ?? this.environment,
      project: project ?? this.project,
      plan: plan ?? this.plan,
      needsEnvironment: needsEnvironment ?? this.needsEnvironment,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Snapshot (response of GET /conversations/<id>/)
// ─────────────────────────────────────────────────────────────────────────

/// Full response body for `GET /api/v1/conversations/<id>/` (and the
/// snapshot-returning variants of `…/messages/`, `…/pending-actions/dismiss/`).
///
/// Polling rules — REPLACE local copies of every list field here on every
/// snapshot, never merge (mobile API §4.3). Only [messages] is appended
/// (and only when `delta=true`).
@immutable
class ConversationSnapshot {
  const ConversationSnapshot({
    required this.conversation,
    required this.messages,
    required this.delta,
    this.cursor,
    this.approvals = const [],
    this.artifacts = const [],
    this.availableCredentials = const [],
    this.disabledCredentials = const [],
    this.pendingActions = const [],
    this.quotaExceeded,
  });

  final Conversation conversation;
  final List<Message> messages;

  /// Set to the exceeded window (`day | week | month`) when the server
  /// blocked the run because the user is over a usage cap. `null` otherwise.
  /// The assistant message already carries the bilingual limit notice; this
  /// signal lets the UI add an upgrade CTA and block further sends (Gap B).
  final QuotaWindow? quotaExceeded;

  /// ISO timestamp of the latest message in the conversation. Pass back
  /// as `?since=` on the next poll. `null` when the conversation has no
  /// messages yet.
  final DateTime? cursor;

  /// `true` when the snapshot was filtered by `?since` (so [messages]
  /// only carries new rows). `false` for full snapshots.
  final bool delta;

  final List<Approval> approvals;
  final List<Artifact> artifacts;
  final List<Credential> availableCredentials;
  final List<String> disabledCredentials;
  final List<PendingAction> pendingActions;

  factory ConversationSnapshot.fromJson(Map<String, dynamic> json) {
    return ConversationSnapshot(
      conversation: Conversation.fromJson(
        json['conversation'] as Map<String, dynamic>,
      ),
      messages: (json['messages'] as List? ?? [])
          .cast<Map<String, dynamic>>()
          .map(Message.fromJson)
          .toList(),
      cursor: _parseDate(json['cursor']),
      delta: json['delta'] as bool? ?? false,
      approvals: (json['approvals'] as List? ?? [])
          .cast<Map<String, dynamic>>()
          .map(Approval.fromJson)
          .toList(),
      artifacts: (json['artifacts'] as List? ?? [])
          .cast<Map<String, dynamic>>()
          .map(Artifact.fromJson)
          .toList(),
      availableCredentials: (json['available_credentials'] as List? ?? [])
          .cast<Map<String, dynamic>>()
          .map(Credential.fromJson)
          .toList(),
      disabledCredentials: (json['disabled_credentials'] as List? ?? [])
          .map((e) => e.toString())
          .toList(),
      pendingActions: (json['pending_actions'] as List? ?? [])
          .cast<Map<String, dynamic>>()
          .map(PendingAction.fromJson)
          .toList(),
      quotaExceeded: QuotaWindow.fromWire(json['quota_exceeded'] as String?),
    );
  }

  /// Returns a copy with selected fields overridden. Used by ChatCubit
  /// to swap the inner [Conversation] when an optimistic flag flip
  /// needs to land in the snapshot without re-fetching the full body.
  ConversationSnapshot copyWith({
    Conversation? conversation,
    List<Message>? messages,
    DateTime? cursor,
    bool? delta,
    List<Approval>? approvals,
    List<Artifact>? artifacts,
    List<Credential>? availableCredentials,
    List<String>? disabledCredentials,
    List<PendingAction>? pendingActions,
    QuotaWindow? quotaExceeded,
  }) {
    return ConversationSnapshot(
      conversation: conversation ?? this.conversation,
      messages: messages ?? this.messages,
      cursor: cursor ?? this.cursor,
      delta: delta ?? this.delta,
      approvals: approvals ?? this.approvals,
      artifacts: artifacts ?? this.artifacts,
      availableCredentials:
          availableCredentials ?? this.availableCredentials,
      disabledCredentials: disabledCredentials ?? this.disabledCredentials,
      pendingActions: pendingActions ?? this.pendingActions,
      quotaExceeded: quotaExceeded ?? this.quotaExceeded,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────

DateTime? _parseDate(Object? value) {
  if (value is String && value.isNotEmpty) {
    return DateTime.tryParse(value)?.toLocal();
  }
  return null;
}
