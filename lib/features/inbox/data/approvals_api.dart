import 'package:dio/dio.dart';

import '../../../core/network/api_endpoints.dart';
import 'approval_models.dart';

/// Repository for the flat Inbox feed (SAQQAR_MOBILE_API.md §8). Approvals
/// embedded inside a conversation snapshot are read via [ConversationsApi]
/// — this surface is for the cross-conversation Inbox tab.
class ApprovalsApi {
  ApprovalsApi(this._dio);

  final Dio _dio;

  /// `GET /api/v1/approvals/?status=&limit=&offset=` — flat paginated list
  /// across every conversation. Pass `status: ApprovalStatus.pending` for
  /// the primary call (the response's `pendingCount` drives the badge).
  Future<ApprovalsPage> list({
    ApprovalStatus? status,
    int limit = 30,
    int offset = 0,
  }) async {
    final res = await _dio.get<Map<String, dynamic>>(
      ApiEndpoints.approvals,
      queryParameters: {
        if (status != null) 'status': status.wire,
        'limit': limit,
        'offset': offset,
      },
    );
    return ApprovalsPage.fromJson(res.data!);
  }

  /// `POST /api/v1/approvals/<id>/decision/` — approve or reject.
  ///
  /// Setting [batchScope] to `true` sends `scope: "batch"` so the server
  /// resolves every sibling approval with the same shape (same conversation
  /// + action_type + payload signature). Use this for "approve all writes
  /// of this kind" flows.
  ///
  /// [confirmPhrase] is **required by the backend for a destructive delete**
  /// and must be `Approval.confirmPhrase`, echoed back verbatim.
  ///
  /// Its absence was a user-facing outage, not a missing nicety:
  /// `views.py:approval_decision` refuses a bare approve on a destructive
  /// delete with HTTP 400 ("To confirm this permanent deletion, type:
  /// delete 12"), so every delete approval in the app was unresolvable. The
  /// app even had a type-to-confirm dialog in front of this call — it matched
  /// the phrase the user typed and then dropped it here, which made the
  /// friction real and the approval still impossible. See
  /// `docs/updates/WEB_TO_MOBILE_PARITY_AND_DELETE_FIX.md` Part A.
  ///
  /// The server re-normalizes what it receives (folds Arabic-Indic digits,
  /// trims, lowercases) and accepts a superset of spellings, so echoing its
  /// own string is always in the accepted set — and stays there if the
  /// canonical wording changes again, which it already has once.
  Future<ApprovalDecisionResult> decide({
    required String id,
    required bool approved,
    String? note,
    bool batchScope = false,
    String? confirmPhrase,
  }) async {
    final body = <String, dynamic>{
      'approved': approved,
      if (note != null) 'note': note,
      if (batchScope) 'scope': 'batch',
      // Omitted entirely rather than sent as null: the key is meaningless on
      // a non-destructive approval, and on a reject the server wants no
      // phrase at all.
      if (confirmPhrase != null && confirmPhrase.isNotEmpty)
        'confirm_phrase': confirmPhrase,
    };
    final res = await _dio.post<Map<String, dynamic>>(
      ApiEndpoints.approvalDecision(id),
      data: body,
    );
    return ApprovalDecisionResult(
      approval: Approval.fromJson(
        res.data!['approval'] as Map<String, dynamic>,
      ),
      batch: (res.data!['batch'] as Map?)?.cast<String, dynamic>(),
    );
  }
}
