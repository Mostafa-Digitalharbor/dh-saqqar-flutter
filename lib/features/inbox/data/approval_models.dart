import 'package:flutter/foundation.dart';

/// The five `action_type` values the backend emits per
/// SAQQAR_MOBILE_API.md §3 / §8. `unknown` is the safe fallback for
/// forward-compat (so a new server-side action_type doesn't crash the
/// mobile client).
enum ApprovalActionType {
  credentialStorage('credential_storage'),
  credentialUsage('credential_usage'),
  serverCommand('server_command'),
  odooWrite('odoo_write'),
  reportExport('report_export'),
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
class ApprovalConversationRef {
  const ApprovalConversationRef({required this.id, required this.title});
  final String id;
  final String title;

  factory ApprovalConversationRef.fromJson(Map<String, dynamic> json) {
    return ApprovalConversationRef(
      id: json['id'] as String,
      title: json['title'] as String? ?? '',
    );
  }
}

/// Out-of-band consent request for a destructive operation. Lives in both
/// the conversation snapshot (§3) and the flat Inbox feed (§8).
@immutable
class Approval {
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
    return Approval(
      id: json['id'] as String,
      actionType: ApprovalActionType.fromWire(json['action_type'] as String?),
      status: ApprovalStatus.fromWire(json['status'] as String?),
      prompt: json['prompt'] as String? ?? '',
      payload: (json['payload'] as Map?)?.cast<String, dynamic>() ?? const {},
      resolutionNote: json['resolution_note'] as String?,
      createdAt: _parseDate(json['created_at']),
      resolvedAt: _parseDate(json['resolved_at']),
      conversation: json['conversation'] is Map<String, dynamic>
          ? ApprovalConversationRef.fromJson(
              json['conversation'] as Map<String, dynamic>,
            )
          : null,
      modelLabelEn: ml is Map ? ml['en'] as String? : null,
      modelLabelAr: ml is Map ? ml['ar'] as String? : null,
      recordCount: (json['record_count'] as num?)?.toInt(),
    );
  }

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
