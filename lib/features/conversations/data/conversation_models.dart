import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';

import '../../../core/logging/app_logger.dart';
import '../../billing/data/plan_models.dart';
import '../../inbox/data/approval_models.dart';
import '../../inbox/data/artifact_models.dart';
import '../../vault/data/credential_models.dart';
import '../../vault/data/project_models.dart';
import 'attachment_models.dart';

part 'conversation_models_summary.dart';
part 'conversation_models_conversation.dart';
part 'conversation_models_snapshot.dart';

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
    this.tokens,
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

  /// What this reply cost, when the server reported it. Null on user rows,
  /// on tool rows, and on assistant rows the backend did not meter.
  final MessageTokens? tokens;

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
      tokens: MessageTokens.fromJson(json['tokens']),
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
    tokens,
  ];
}

/// The token cost of one assistant reply, as the server meters it.
///
/// `cached_input` is the part of the prompt that was served from the model's
/// cache — it is a SUBSET of [input], not an addition to it, which is why
/// [fresh] subtracts rather than the total adding. Getting that backwards
/// would show a number larger than what was billed.
class MessageTokens extends Equatable {
  const MessageTokens({
    required this.input,
    required this.output,
    required this.cachedInput,
  });

  final int input;
  final int output;
  final int cachedInput;

  int get total => input + output;

  /// Prompt tokens that were not served from cache. Clamped at zero: a
  /// server reporting more cache than input is wrong, but a negative count
  /// on screen would be the client repeating the mistake.
  int get fresh => input - cachedInput < 0 ? 0 : input - cachedInput;

  /// Share of the prompt that hit the cache, 0-100. Zero when there was no
  /// prompt to hit it with.
  int get cacheHitPercent =>
      input <= 0 ? 0 : ((cachedInput / input) * 100).round();

  /// Null unless the server sent a metered object with something in it.
  ///
  /// The web hides the chip when input and output are both zero, and so does
  /// this: "0" is not a cost worth a row of chrome, and a message the backend
  /// did not meter must not read as one that was free.
  static MessageTokens? fromJson(Object? raw) {
    if (raw is! Map) return null;
    int read(String key) {
      final v = raw[key];
      if (v is num) return v.toInt();
      if (v is String) return int.tryParse(v) ?? 0;
      return 0;
    }

    final input = read('input');
    final output = read('output');
    if (input == 0 && output == 0) return null;
    return MessageTokens(
      input: input,
      output: output,
      cachedInput: read('cached_input'),
    );
  }

  @override
  List<Object?> get props => [input, output, cachedInput];
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

// ─────────────────────────────────────────────────────────────────────────
// Conversation (detail / snapshot)
// ─────────────────────────────────────────────────────────────────────────

// ─────────────────────────────────────────────────────────────────────────
// Snapshot (response of GET /conversations/<id>/)
// ─────────────────────────────────────────────────────────────────────────

// ─────────────────────────────────────────────────────────────────────────

/// Decodes one list field of a snapshot, dropping any element that fails.
///
/// The bad element is skipped and logged; the other rows — and the rest of
/// the snapshot around them — survive. That is the whole point: a snapshot is
/// the chat's ONLY source of messages, approvals and artifacts, and it is
/// re-fetched on a timer, so a single unparseable row that aborts the parse
/// does not degrade one row, it takes the conversation off the air for as
/// long as the server keeps sending it.
///
/// [what] names the row type in the log so the warning identifies which feed
/// is malformed without a stack trace.
List<T> _parseRows<T>(
  Object? raw,
  T Function(Map<String, dynamic>) fromJson,
  String what,
) {
  if (raw is! List || raw.isEmpty) return const [];
  final rows = <T>[];
  for (final element in raw) {
    if (element is! Map) continue;
    try {
      rows.add(fromJson(element.cast<String, dynamic>()));
    } catch (e, st) {
      AppLogger.warn(
        'ConversationSnapshot',
        'dropped a malformed $what row',
        error: e,
        stackTrace: st,
      );
    }
  }
  return rows;
}

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
