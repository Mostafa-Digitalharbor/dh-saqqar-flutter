import 'package:equatable/equatable.dart';
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
class Message extends Equatable {
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
      // Defensive: never hard-cast server fields. A single row with a
      // missing/non-string id used to throw and abort parsing of the
      // WHOLE snapshot — one bad message failed the entire chat.
      id: json['id']?.toString() ?? '',
      role: MessageRole.fromWire(json['role'] as String?),
      content: json['content'] as String? ?? '',
      createdAt: _parseDate(json['created_at']) ?? DateTime.now(),
      toolName: tn is String && tn.isNotEmpty ? tn : null,
      toolPayload: (json['tool_payload'] as Map?)?.cast<String, dynamic>(),
      // whereType (not cast) so one malformed attachment is skipped rather
      // than throwing and dropping every message in the list.
      attachments: (json['attachments'] as List? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(Attachment.fromJson)
          .toList(),
    );
  }

  @override
  List<Object?> get props => [
        id,
        role,
        content,
        createdAt,
        toolName,
        toolPayload,
        attachments,
      ];
}

// ─────────────────────────────────────────────────────────────────────────
// RunProgress
// ─────────────────────────────────────────────────────────────────────────

/// Long-running tool progress (export jobs). Empty between runs.
@immutable
class RunProgress extends Equatable {
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

  @override
  List<Object?> get props => [phase, current, total, label];
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
class PendingAction extends Equatable {
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

  @override
  List<Object?> get props => [
        type,
        credentialName,
        credentialKind,
        requiredFields,
        fieldSchema,
        reason,
        rememberPreference,
      ];
}

// ─────────────────────────────────────────────────────────────────────────
// Conversation summary (list row)
// ─────────────────────────────────────────────────────────────────────────

// NOTE: deliberately NOT `Equatable`. The Chats list renders a *relative*
// timestamp ("5 min ago") and a recency-derived `isLive` ring off
// [updatedAt], both of which are functions of the wall clock rather than of
// the row's fields. Value equality would make an unchanged poll a no-op emit
// and those labels would freeze until the server happened to change
// something. The chat snapshot path (which polls 10× faster and renders no
// clock-derived text) IS value-equal — see [ConversationSnapshot].
@immutable
class ConversationSummary {
  // Not `const` any more — see [_searchHaystack], which needs a `late final`
  // to memoize. Nothing constructed one as a const literal, so this costs
  // nothing at the call sites.
  ConversationSummary({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
    required this.isArchived,
    required this.messageCount,
    this.lastMessagePreview = '',
    this.isRunning = false,
    this.projectName,
    this.environmentName,
    this.filesCount,
  });

  final String id;
  final String title;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isArchived;
  final int messageCount;
  final String lastMessagePreview;

  /// Whether the agent is mid-run for this conversation on the SERVER — the
  /// Chats list uses it to show the live "Saqqar is working" indicator. Not
  /// persisted to the offline cache (ephemeral), so a cold start reads it as
  /// false until the first live fetch.
  ///
  /// Always false in practice today: `GET /conversations/` does NOT return
  /// `is_running` per row (verified against production 2026-07-25 — a row
  /// carries `created_at environment files_count id is_archived
  /// last_message_preview message_count project title updated_at`). The list
  /// therefore cannot show a running indicator for a conversation the user
  /// hasn't opened. See docs/MOBILE_BACKEND_GAPS_CORE.md §2.
  final bool isRunning;

  /// Real project / environment context.
  ///
  /// The list endpoint DOES carry both as of 2026-07-25 (verified against
  /// production: a row returns `project` and `environment` objects). This
  /// used to say the opposite, and that stale comment is what led the client
  /// to keep an N+1 enrichment pass — one snapshot fetch per row purely to
  /// recover these two strings — long after the backend had shipped them.
  ///
  /// Still nullable and still parsed defensively: a row for a conversation
  /// with no bound environment legitimately omits them, and the card must
  /// drop the project · environment line rather than invent a value.
  final String? projectName;
  final String? environmentName;

  /// Artifacts produced in THIS conversation, straight from the row.
  ///
  /// The client used to derive this by pulling the flat `/artifacts/` feed
  /// with `limit=100` and grouping by conversation. That feed is capped
  /// account-wide, so the derived number disagreed with the server's on
  /// **41 of 100 rows** on a real account (one row reports 188 artifacts; the
  /// truncated feed could only see 90). Measured 2026-07-25.
  ///
  /// Nullable so a deployment that doesn't send it renders no count rather
  /// than a wrong one.
  final int? filesCount;

  /// A conversation counts as "live" — green status ring on the card, and
  /// the `live` triage filter on the Chats screen — when it was last active
  /// within this window.
  ///
  /// Representative signal: the summary API carries no per-conversation
  /// live flag yet, so recency stands in for one.
  ///
  /// Lives on the model because the card and the screen each declared their
  /// own copy (`_kLiveWindow` and `kLiveWindow`) of the same two hours. The
  /// card's was deliberately private to keep it decoupled from the screen
  /// file — right instinct, wrong owner: the concept belongs to the data,
  /// so both can depend on it without depending on each other.
  static const liveWindow = Duration(hours: 2);

  bool get isLive => DateTime.now().difference(updatedAt) <= liveWindow;

  /// Lower-cased `title` + `lastMessagePreview`, the text the Chats search
  /// runs against — built **once per row**, on first use.
  ///
  /// The screen used to lower-case both fields inline, for every row, inside
  /// a filter it re-derived several times per build. With ~166 conversations
  /// and a preview that can run to a couple of hundred characters, a single
  /// keystroke in the search box allocated hundreds of throwaway strings and
  /// re-scanned the same rows. None of that input changes between builds, so
  /// none of it needed repeating: the row owns the text, so the row caches
  /// it.
  ///
  /// The two fields are joined by a newline rather than concatenated, so a
  /// query cannot match by straddling the boundary between a title and the
  /// preview underneath it — "invoice draft" must find a row that really
  /// says that, not one whose title ends in "invoice" above a preview
  /// starting with "draft".
  late final String _searchHaystack =
      '$title\n$lastMessagePreview'.toLowerCase();

  /// Whether this row matches [lowercaseQuery].
  ///
  /// Takes an **already lower-cased** query: the caller is looping over the
  /// whole list, so folding the needle once outside the loop is the point.
  /// An empty query matches everything, which is what "no search" means.
  bool matchesQuery(String lowercaseQuery) =>
      lowercaseQuery.isEmpty || _searchHaystack.contains(lowercaseQuery);

  factory ConversationSummary.fromJson(Map<String, dynamic> json) {
    return ConversationSummary(
      // Null-safe id — one malformed row must not throw and fail the WHOLE
      // Chats list (the app's home surface). Callers skip empty-id rows.
      id: json['id']?.toString() ?? '',
      title: json['title'] as String? ?? '',
      createdAt: _parseDate(json['created_at']) ?? DateTime.now(),
      updatedAt: _parseDate(json['updated_at']) ?? DateTime.now(),
      isArchived: json['is_archived'] as bool? ?? false,
      messageCount: (json['message_count'] as num?)?.toInt() ?? 0,
      lastMessagePreview: json['last_message_preview'] as String? ?? '',
      isRunning: json['is_running'] as bool? ?? false,
      projectName:
          _nameOf(json['project']) ?? json['project_name'] as String?,
      environmentName: _nameOf(json['environment']) ??
          json['environment_name'] as String?,
      filesCount: (json['files_count'] as num?)?.toInt(),
    );
  }

  /// Serializes the row for the offline list cache (stale-while-revalidate
  /// on the Chats tab). Keeps the enriched `project` / `environment` names
  /// so a cold start paints the full row, tags included, before the live
  /// fetch lands. Round-trips through [fromJson] — the `*_name` keys are the
  /// flat shape that factory already reads.
  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'created_at': createdAt.toUtc().toIso8601String(),
        'updated_at': updatedAt.toUtc().toIso8601String(),
        'is_archived': isArchived,
        'message_count': messageCount,
        'last_message_preview': lastMessagePreview,
        if (projectName != null) 'project_name': projectName,
        if (environmentName != null) 'environment_name': environmentName,
        if (filesCount != null) 'files_count': filesCount,
      };

  /// The list endpoint doesn't carry project / environment, so the cubit
  /// enriches each row from its snapshot and rebuilds the summary with this.
  /// Only the two context fields are overridable — everything else is the
  /// server's list truth.
  ConversationSummary copyWith({
    String? projectName,
    String? environmentName,
    bool? isRunning,
  }) {
    return ConversationSummary(
      id: id,
      title: title,
      createdAt: createdAt,
      updatedAt: updatedAt,
      isArchived: isArchived,
      messageCount: messageCount,
      lastMessagePreview: lastMessagePreview,
      isRunning: isRunning ?? this.isRunning,
      projectName: projectName ?? this.projectName,
      environmentName: environmentName ?? this.environmentName,
      filesCount: filesCount,
    );
  }
}

/// Pulls a human label out of a project / environment field, tolerating the
/// three shapes a backend might use: a bare string, a nested
/// `{id, name, …}` object, or `{slug, …}` when no display name is set.
/// Returns `null` when absent so the row omits the tag rather than ever
/// showing a fabricated value.
String? _nameOf(Object? value) {
  if (value is String) {
    final t = value.trim();
    return t.isEmpty ? null : t;
  }
  if (value is Map) {
    final n = value['name'] ?? value['slug'];
    return n is String && n.trim().isNotEmpty ? n.trim() : null;
  }
  return null;
}

// ─────────────────────────────────────────────────────────────────────────
// Conversation (detail / snapshot)
// ─────────────────────────────────────────────────────────────────────────

@immutable
class Conversation extends Equatable {
  const Conversation({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
    required this.autoApprove,
    this.taskPrep,
    required this.deepThink,
    required this.isRunning,
    required this.stopRequested,
    this.context = const {},
    this.runProgress,
    this.runError,
    this.activeCredential,
    this.environment,
    this.environments = const <Environment>[],
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

  /// Per-conversation "task prep" toggle, on exactly the terms as
  /// [deepThink] above:
  ///   * `true` / `false` — the server owns the setting; use it, and PATCH
  ///     it when the user flips the switch.
  ///   * `null`           — the server does not send the field, so it owns
  ///     nothing. Callers fall back to the device-local `TaskPrepCubit`,
  ///     which is exactly how the app behaves today.
  ///
  /// **Nullable so this ships BEFORE the backend field exists.** As of
  /// 2026-08-10 the conversation carries `auto_approve` and `deep_think` but
  /// no `task_prep`, which is why flipping the toggle in the app never
  /// reached the website and vice versa — there was no shared value to agree
  /// through, only two private copies. The product decision has been made:
  /// per-conversation, mirroring `auto_approve`.
  ///
  /// Reading it now, ahead of the server, is what removes a mobile release
  /// from that fix: the day the field appears in the snapshot the toggle
  /// starts syncing on builds already in users' hands. Until then `null`
  /// keeps today's behaviour precisely, so shipping this early costs
  /// nothing and cannot regress.
  final bool? taskPrep;

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

  /// All environments bound to this conversation (web allows several).
  /// [environment] is the primary; this is the full set. Empty when none.
  final List<Environment> environments;

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
      id: json['id']?.toString() ?? '',
      title: json['title'] as String? ?? '',
      context: ctx,
      createdAt: _parseDate(json['created_at']) ?? DateTime.now(),
      updatedAt: _parseDate(json['updated_at']) ?? DateTime.now(),
      autoApprove: json['auto_approve'] as bool? ?? false,
      deepThink: deepThinkRaw is bool ? deepThinkRaw : null,
      // `is bool`, not `as bool?`: a non-bool would throw and take the whole
      // snapshot with it. Anything that is not a boolean reads as "the server
      // said nothing", which falls back to the local preference.
      taskPrep: json['task_prep'] is bool ? json['task_prep'] as bool : null,
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
      // ALL bound environments (web supports binding several to one chat).
      // `environment` above is the primary; this is the full set.
      environments: (json['environments'] as List? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(Environment.fromJson)
          .toList(),
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
    bool? taskPrep,
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
      taskPrep: taskPrep ?? this.taskPrep,
      isArchived: isArchived ?? this.isArchived,
      isRunning: isRunning ?? this.isRunning,
      stopRequested: stopRequested ?? this.stopRequested,
      runProgress: runProgress ?? this.runProgress,
      runError: runError ?? this.runError,
      activeCredential: activeCredential ?? this.activeCredential,
      environment: environment ?? this.environment,
      // Server-driven — preserved across optimistic copyWith flips.
      environments: environments,
      project: project ?? this.project,
      plan: plan ?? this.plan,
      needsEnvironment: needsEnvironment ?? this.needsEnvironment,
    );
  }

  @override
  List<Object?> get props => [
        id,
        title,
        context,
        createdAt,
        updatedAt,
        autoApprove,
        deepThink,
        taskPrep,
        isArchived,
        isRunning,
        stopRequested,
        runProgress,
        runError,
        activeCredential,
        environment,
        environments,
        project,
        plan,
        needsEnvironment,
      ];
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
/// Value-equal (see [props]): a poll that returns a snapshot identical to the
/// one already on screen compares equal, so `ChatCubit`'s `emit` is a no-op
/// and the chat screen does not rebuild. With a 1.5 s polling cadence that is
/// the difference between rebuilding the whole chat tree ~40×/min and
/// rebuilding it only when something actually changed — the single biggest
/// idle-CPU saving on low-end devices.
@immutable
class ConversationSnapshot extends Equatable {
  const ConversationSnapshot({
    required this.conversation,
    required this.messages,
    required this.delta,
    this.cursor,
    this.oldestCursor,
    this.hasMoreBefore = false,
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

  /// Opaque cursor pointing at the OLDEST message in this page, in the form
  /// `<iso-timestamp>|<message-id>`. Pass it back as `?before=` to fetch the
  /// page before this one.
  ///
  /// This is how backwards paging is meant to work, and it is the only way
  /// that scales: `?limit=` is capped at 500 server-side, so the client's old
  /// "ask for a bigger window each time" strategy could never reach past the
  /// most recent 500 messages of a conversation — on a 5,000-message chat
  /// that stranded most of the history. Verified against production
  /// 2026-07-25.
  final String? oldestCursor;

  /// Whether messages exist before [oldestCursor]. Server-authoritative, so
  /// the client no longer has to infer "is there more?" from whether a page
  /// came back full — an inference that broke exactly at the `limit` ceiling.
  final bool hasMoreBefore;

  final List<Approval> approvals;
  final List<Artifact> artifacts;
  final List<Credential> availableCredentials;
  final List<String> disabledCredentials;
  final List<PendingAction> pendingActions;

  factory ConversationSnapshot.fromJson(Map<String, dynamic> json) {
    // The `conversation` object is required. Guard it so a snapshot missing
    // the key surfaces a clear "couldn't load this conversation" failure
    // upstream instead of an opaque TypeError.
    final conv = json['conversation'];
    if (conv is! Map<String, dynamic>) {
      throw const FormatException('snapshot missing "conversation" object');
    }
    return ConversationSnapshot(
      conversation: Conversation.fromJson(conv),
      // whereType (not cast) throughout: one malformed element (a bad
      // message / approval / artifact / credential / action) is skipped
      // rather than aborting the parse of the ENTIRE snapshot.
      messages: (json['messages'] as List? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(Message.fromJson)
          .toList(),
      cursor: _parseDate(json['cursor']),
      // Kept as a raw string, never parsed: it is an opaque
      // `<iso-timestamp>|<message-id>` pair that goes straight back to the
      // server as `?before=`. Splitting it would invite reformatting it.
      oldestCursor: (json['oldest_cursor'] as String?)?.trim(),
      hasMoreBefore: json['has_more_before'] as bool? ?? false,
      delta: json['delta'] as bool? ?? false,
      approvals: (json['approvals'] as List? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(Approval.fromJson)
          .toList(),
      artifacts: (json['artifacts'] as List? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(Artifact.fromJson)
          .toList(),
      availableCredentials: (json['available_credentials'] as List? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(Credential.fromJson)
          .toList(),
      disabledCredentials: (json['disabled_credentials'] as List? ?? [])
          .map((e) => e.toString())
          .toList(),
      pendingActions: (json['pending_actions'] as List? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(PendingAction.fromJson)
          .toList(),
      // Read from `conversation.quota.kind` FIRST, with the top-level
      // `quota_exceeded` kept only as a fallback.
      //
      // The top level is where this used to look, and production does not
      // send it — verified 2026-07-25, the snapshot has no `quota_exceeded`
      // key at all. What it does send is
      // `conversation.quota = {kind, token_balance}`, `kind` being null while
      // the user is under their cap. So the over-quota banner and the
      // send-blocking it drives have never once been able to fire.
      //
      // `fromWire` returns null for anything it doesn't recognise, so if
      // `kind` turns out to use different strings than day/week/month this
      // degrades to exactly today's behaviour rather than misfiring.
      quotaExceeded: QuotaWindow.fromWire(
        _quotaKind(conv) ?? json['quota_exceeded'] as String?,
      ),
    );
  }

  /// Returns a copy with selected fields overridden. Used by ChatCubit
  /// to swap the inner [Conversation] when an optimistic flag flip
  /// needs to land in the snapshot without re-fetching the full body.
  ConversationSnapshot copyWith({
    Conversation? conversation,
    List<Message>? messages,
    DateTime? cursor,
    String? oldestCursor,
    bool? hasMoreBefore,
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
      oldestCursor: oldestCursor ?? this.oldestCursor,
      hasMoreBefore: hasMoreBefore ?? this.hasMoreBefore,
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

  @override
  List<Object?> get props => [
        conversation,
        messages,
        quotaExceeded,
        cursor,
        oldestCursor,
        hasMoreBefore,
        delta,
        approvals,
        artifacts,
        availableCredentials,
        disabledCredentials,
        pendingActions,
      ];
}

// ─────────────────────────────────────────────────────────────────────────

/// Pulls `conversation.quota.kind` out of a raw snapshot body, tolerating a
/// missing `quota` object and a non-string `kind`.
String? _quotaKind(Map<String, dynamic> conversation) {
  final quota = conversation['quota'];
  if (quota is! Map) return null;
  final kind = quota['kind'];
  return kind is String && kind.isNotEmpty ? kind : null;
}

DateTime? _parseDate(Object? value) {
  if (value is String && value.isNotEmpty) {
    return DateTime.tryParse(value)?.toLocal();
  }
  return null;
}
