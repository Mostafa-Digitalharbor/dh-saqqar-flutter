import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';

import '../../../core/constants/ui_strings.dart';

/// Wire value of the destructive operation on an `odoo_write` approval.
///
/// The single string that decides whether an approval is irreversible, so it
/// is named once and read from the server's `payload.operation` — never
/// inferred from the prompt, which is a human sentence in the user's own
/// language.
///
/// It used to live in `chat/data/delete_confirmation.dart` beside a
/// type-to-confirm matcher and an Arabic-Indic digit normalizer. That whole
/// file was deleted on 2026-08-17: the user no longer types anything, so there
/// is nothing to match, and the constant belongs next to the model that reads
/// it. See `docs/updates/WEB_TO_MOBILE_PARITY_AND_DELETE_FIX.md` §A.3.
const kDeleteOperation = 'delete';

/// The `action_type` values the backend emits per SAQQAR_MOBILE_API.md §3 /
/// §8, plus `send_email` (Task 4, MOBILE_TASKS_2026-09.md). `unknown` is the
/// safe fallback for forward-compat (so a new server-side action_type
/// doesn't crash the mobile client).
enum ApprovalActionType {
  credentialStorage('credential_storage'),
  credentialUsage('credential_usage'),
  serverCommand('server_command'),
  odooWrite('odoo_write'),
  reportExport('report_export'),
  sendEmail('send_email'),
  unknown('');

  const ApprovalActionType(this.wire);
  final String wire;

  static ApprovalActionType fromWire(String? value) {
    for (final t in ApprovalActionType.values) {
      if (t.wire == value) return t;
    }
    return ApprovalActionType.unknown;
  }
}

enum ApprovalStatus {
  pending('pending'),
  approved('approved'),
  rejected('rejected');

  const ApprovalStatus(this.wire);
  final String wire;

  static ApprovalStatus fromWire(String? value) {
    for (final s in ApprovalStatus.values) {
      if (s.wire == value) return s;
    }
    return ApprovalStatus.pending;
  }
}

/// Pointer to the conversation an approval belongs to. Only present on the
/// flat `/api/v1/approvals/` list response — approvals inside a snapshot
/// already live in conversation scope.
@immutable
class ApprovalConversationRef extends Equatable {
  const ApprovalConversationRef({required this.id, required this.title});
  final String id;
  final String title;

  factory ApprovalConversationRef.fromJson(Map<String, dynamic> json) {
    return ApprovalConversationRef(
      id: json['id'] as String,
      title: json['title'] as String? ?? '',
    );
  }

  @override
  List<Object?> get props => [id, title];
}

/// Out-of-band consent request for a destructive operation. Lives in both
/// the conversation snapshot (§3) and the flat Inbox feed (§8).
@immutable
class Approval extends Equatable {
  const Approval({
    required this.id,
    required this.actionType,
    required this.status,
    required this.prompt,
    required this.payload,
    this.resolutionNote,
    this.createdAt,
    this.resolvedAt,
    this.conversation,
    this.modelLabelEn,
    this.modelLabelAr,
    this.recordCount,
    this.confirmPhrase,
    this.batchScoped = false,
  });

  final String id;
  final ApprovalActionType actionType;
  final ApprovalStatus status;
  final String prompt;

  /// Shape depends on [actionType] — e.g. `{command: "..."}` for
  /// `serverCommand`, `{name, kind}` for `credentialStorage`. The UI
  /// treats this as opaque payload to render under "Show details".
  final Map<String, dynamic> payload;

  final String? resolutionNote;
  final DateTime? createdAt;
  final DateTime? resolvedAt;

  /// Only present on the flat /approvals/ list. Inside a conversation
  /// snapshot, the conversation context is implicit.
  final ApprovalConversationRef? conversation;

  /// Human model name resolved server-side (Gap E), e.g. "Manufacturing
  /// Order" / "أمر التصنيع". Pick by locale via [modelLabel]. `null` on
  /// legacy approvals or non-Odoo actions.
  final String? modelLabelEn;
  final String? modelLabelAr;

  /// Records the write touches (create=1, create_many=len, …). `null` when
  /// not applicable to the action type.
  final int? recordCount;

  /// The exact phrase the server will accept to confirm a destructive delete
  /// (e.g. `"delete 3"`), from `confirm_phrase`. `null` on every non-delete
  /// approval, and on a server that predates the field.
  ///
  /// This is **echoed back verbatim** in the decision POST when the user taps
  /// the red "Delete N" button — the user is never asked to reproduce it.
  ///
  /// Never build the string client-side. The server owns the canonical
  /// wording and has already changed it once (the Odoo model name used to be
  /// part of it), so reading it is what inherits the next change for free. It
  /// also re-normalizes whatever it receives and accepts a superset (`delete
  /// N`, `حذف N`, `احذف N`), which means its own string is always in the
  /// accepted set.
  ///
  /// `null` here on a delete is why `decide` omits the key rather than
  /// sending null: a server that predates the field does not want it.
  final String? confirmPhrase;

  /// `payload.batch_scope` — this approval was auto-resolved by a scope the
  /// user already approved. Suppresses "approve all similar", which would
  /// offer to do something that has already happened.
  final bool batchScoped;

  /// See the top-level [kDeleteOperation].
  ///
  /// Whether approving this destroys Odoo records irreversibly.
  ///
  /// Read off the SERVER's `payload.operation`, never guessed from the prompt
  /// text — the prompt is a human sentence in the user's own language, and
  /// matching on it would make the most dangerous branch in the app depend on
  /// wording.
  ///
  /// This is the single flag the delete design keys on: it decides whether the
  /// card shows a red one-tap "Delete N", whether "Approve all" is offered at
  /// all, and whether the decision POST has to carry [confirmPhrase].
  bool get isDestructiveDelete => payload['operation'] == kDeleteOperation;

  /// Display labels for the records this delete would destroy, in the order
  /// the server listed them.
  ///
  /// `payload.records` (`{id, name}` each) when present, else
  /// `payload.record_ids` rendered as `#id`. Empty when the server sent
  /// neither, which some deletes do.
  ///
  /// The list is what the count in the button label means — a user about to
  /// approve an irreversible delete should be able to see *which* rows die,
  /// not just how many. It is deliberately built here rather than in the card
  /// so both approval surfaces render the same thing.
  List<String> get deleteRecords {
    final records = payload['records'];
    if (records is List && records.isNotEmpty) {
      return [
        for (final r in records)
          if (r is Map)
            (r['name'] as Object?)?.toString().trim().isNotEmpty ?? false
                ? r['name'].toString().trim()
                : '#${r['id']}',
      ];
    }
    final ids = payload['record_ids'];
    if (ids is List) return [for (final id in ids) '#$id'];
    return const [];
  }

  /// Locale-aware model name — Arabic when [isArabic], else English; falls
  /// back to the other locale when one side is missing. `null` when neither
  /// is present (caller then renders the raw payload as before).
  String? modelLabel({required bool isArabic}) {
    final primary = isArabic ? modelLabelAr : modelLabelEn;
    final fallback = isArabic ? modelLabelEn : modelLabelAr;
    final v = (primary != null && primary.isNotEmpty) ? primary : fallback;
    return (v != null && v.isNotEmpty) ? v : null;
  }

  factory Approval.fromJson(Map<String, dynamic> json) {
    final ml = json['model_label'];
    final payload = (json['payload'] as Map?)?.cast<String, dynamic>() ?? const {};
    // Documented as a field on the approval object; also accepted from the
    // payload, because every other delete-specific value (record_ids, model)
    // lives there and one of the two placements will be what actually ships.
    final phrase = json['confirm_phrase'] ?? payload['confirm_phrase'];
    return Approval(
      id: json['id'] as String,
      actionType: ApprovalActionType.fromWire(json['action_type'] as String?),
      status: ApprovalStatus.fromWire(json['status'] as String?),
      prompt: json['prompt'] as String? ?? '',
      payload: payload,
      resolutionNote: json['resolution_note'] as String?,
      createdAt: _parseDate(json['created_at']),
      resolvedAt: _parseDate(json['resolved_at']),
      conversation: json['conversation'] is Map<String, dynamic>
          ? ApprovalConversationRef.fromJson(
              json['conversation'] as Map<String, dynamic>,
            )
          : null,
      modelLabelEn:
          ml is Map ? ml[UiStrings.localeEnglishCode] as String? : null,
      modelLabelAr:
          ml is Map ? ml[UiStrings.localeArabicCode] as String? : null,
      recordCount: (json['record_count'] as num?)?.toInt(),
      // Non-String (or blank) means "the server didn't tell us", and is
      // normalized to null so `decide` omits the key entirely rather than
      // posting an empty confirmation the server would reject anyway.
      confirmPhrase:
          phrase is String && phrase.trim().isNotEmpty ? phrase.trim() : null,
      batchScoped: payload['batch_scope'] == true,
    );
  }

  @override
  List<Object?> get props => [
        id,
        actionType,
        status,
        prompt,
        payload,
        resolutionNote,
        createdAt,
        resolvedAt,
        conversation,
        modelLabelEn,
        modelLabelAr,
        recordCount,
        confirmPhrase,
        batchScoped,
      ];

  static DateTime? _parseDate(Object? value) {
    if (value is String && value.isNotEmpty) {
      return DateTime.tryParse(value)?.toLocal();
    }
    return null;
  }
}

/// Result of `GET /api/v1/approvals/` — paginated list plus the unscoped
/// pending count (drives the bottom-nav badge).
@immutable
class ApprovalsPage {
  const ApprovalsPage({
    required this.approvals,
    required this.total,
    required this.pendingCount,
    required this.limit,
    required this.offset,
  });

  final List<Approval> approvals;
  final int total;
  final int pendingCount;
  final int limit;
  final int offset;

  factory ApprovalsPage.fromJson(Map<String, dynamic> json) {
    return ApprovalsPage(
      approvals: (json['approvals'] as List? ?? [])
          .cast<Map<String, dynamic>>()
          .map(Approval.fromJson)
          .toList(),
      total: (json['total'] as num?)?.toInt() ?? 0,
      pendingCount: (json['pending_count'] as num?)?.toInt() ?? 0,
      limit: (json['limit'] as num?)?.toInt() ?? 30,
      offset: (json['offset'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Result of `POST /api/v1/approvals/<id>/decision/`.
@immutable
class ApprovalDecisionResult {
  const ApprovalDecisionResult({required this.approval, this.batch});

  final Approval approval;

  /// Set only when the caller passed `scope: 'batch'` — summary of sibling
  /// approvals that were resolved together. Treated as opaque server data.
  final Map<String, dynamic>? batch;
}
