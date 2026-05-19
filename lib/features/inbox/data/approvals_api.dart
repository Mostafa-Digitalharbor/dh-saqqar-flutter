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
  Future<ApprovalDecisionResult> decide({
    required String id,
    required bool approved,
    String? note,
    bool batchScope = false,
  }) async {
    final body = <String, dynamic>{
      'approved': approved,
      if (note != null) 'note': note,
      if (batchScope) 'scope': 'batch',
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

