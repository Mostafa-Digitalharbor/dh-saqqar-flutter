import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/network/api_error_mapper.dart';
import '../../../core/state/data_state.dart';
import '../data/approval_models.dart';
import '../data/approvals_api.dart';

/// Cross-conversation approvals feed, backed by the real
/// `GET /api/v1/approvals/` endpoint (SAQQAR_MOBILE_API.md §8).
///
/// This is the flat Inbox-style view of every pending approval across
/// conversations. The per-conversation inline approval flow (the chat
/// screen's approval cards) talks to [ApprovalsApi] directly against the
/// snapshot's embedded approvals — it does NOT go through this cubit. This
/// cubit exists for a future cross-conversation approvals surface (bell /
/// global inbox); it holds no data until a view calls [load].
///
/// De-fabrication note: previously this derived its counts from the const
/// `demoApprovals` seed. It now reads the live feed and exposes real
/// [Approval] models — never fabricated data.
class ApprovalsState extends Equatable {
  const ApprovalsState({
    this.approvals = const DataIdle<List<Approval>>(),
    this.pendingTotal = 0,
  });

  /// The fetched approvals list (server returns pending first when we pass
  /// `status: pending`). Idle until [ApprovalsCubit.load] runs.
  final DataState<List<Approval>> approvals;

  /// The server's unscoped `pending_count` — the total across all pages, so
  /// a badge can show the true count even when only the first page is loaded.
  final int pendingTotal;

  List<Approval> get _list => approvals.dataOrNull ?? const [];

  /// Approvals still awaiting a decision in the currently-loaded page.
  int get pendingCount =>
      _list.where((a) => a.status == ApprovalStatus.pending).length;

  /// Per-conversation pending count — for a chat menu badge / row pulse dot
  /// once a consumer wires this cubit up.
  int pendingForConversation(String conversationId) => _list
      .where((a) =>
          a.conversation?.id == conversationId &&
          a.status == ApprovalStatus.pending)
      .length;

  bool conversationNeedsAttention(String conversationId) =>
      pendingForConversation(conversationId) > 0;

  ApprovalsState copyWith({
    DataState<List<Approval>>? approvals,
    int? pendingTotal,
  }) {
    return ApprovalsState(
      approvals: approvals ?? this.approvals,
      pendingTotal: pendingTotal ?? this.pendingTotal,
    );
  }

  @override
  List<Object?> get props => [approvals, pendingTotal];
}

class ApprovalsCubit extends Cubit<ApprovalsState> {
  ApprovalsCubit(this._api) : super(const ApprovalsState());

  final ApprovalsApi _api;

  /// Fetches the pending approvals feed. Keeps any previously-loaded list
  /// visible while refreshing (stale-while-revalidate).
  Future<void> load() async {
    emit(state.copyWith(
      approvals: DataLoading(previous: state.approvals.dataOrNull),
    ));
    try {
      final page = await _api.list(status: ApprovalStatus.pending);
      emit(state.copyWith(
        approvals: DataSuccess(page.approvals),
        pendingTotal: page.pendingCount,
      ));
    } catch (e) {
      // `message` is an unlocalized fallback (matches VaultCubit): the
      // canonical render path is `DataStateView` + `ApiErrorMapper.message`,
      // which localizes the [AppFailure] stashed in `error`.
      emit(state.copyWith(
        approvals: DataFailure(
          error: ApiErrorMapper.toFailure(e),
          previous: state.approvals.dataOrNull,
        ),
      ));
    }
  }

  /// Alias for [load] — re-fetches from scratch (pull-to-refresh).
  Future<void> refresh() => load();

  /// Approve or reject an approval, then refresh so the resolved row drops
  /// off the pending list. Pass [batchScope] to resolve every sibling with
  /// the same shape server-side (the "approve all writes of this kind" flow).
  Future<void> decide(
    String approvalId, {
    required bool approved,
    bool batchScope = false,
  }) async {
    await _api.decide(
      id: approvalId,
      approved: approved,
      batchScope: batchScope,
    );
    await load();
  }

  /// Clear on sign-out / account switch.
  void reset() => emit(const ApprovalsState());
}
