import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../demo/saqqar_demo_data.dart';

/// Shared state for approval decisions, dismissed agent-request actions,
/// AND pre-approved write shapes per conversation. Inbox + Chat sheets
/// both drive this so dismissing/approving in one place is immediately
/// reflected in the other.
///
/// Phase-3 note: today this still reads from the const demo lists. When
/// the real `/api/approvals/` feed is wired (see [[reference-mobile-api]]),
/// `pendingCount` etc. swap to derive from a remote-fetched list instead
/// of `demoApprovals` — the callers won't need to change.
class ApprovalsState extends Equatable {
  const ApprovalsState({
    this.decisions = const {},
    this.dismissedActions = const {},
    this.preApprovedShapes = const {},
  });

  final Map<String, DemoApprovalStatus> decisions;
  final Set<String> dismissedActions;

  /// Map of `conversationId → set of pre-approved shape keys` (e.g.
  /// `odoo_write:res.users:write`). When the user taps "Approve all" on
  /// a grouped approval, the `sharedShape` is added here for the
  /// conversation, and every future approval with the same shape in the
  /// same conversation is auto-marked approved by the cubit. Mirrors the
  /// web's "approving 'Approve all' pre-approves future writes" tip.
  final Map<String, Set<String>> preApprovedShapes;

  DemoApprovalStatus statusFor(DemoApproval approval) {
    if (decisions.containsKey(approval.id)) return decisions[approval.id]!;
    if (isPreApproved(approval)) return DemoApprovalStatus.approved;
    return approval.status;
  }

  bool isPreApproved(DemoApproval approval) {
    final cid = approval.conversationId;
    final shape = approval.sharedShape;
    if (cid == null || shape == null) return false;
    final shapes = preApprovedShapes[cid];
    if (shapes == null) return false;
    return shapes.contains(shape);
  }

  bool isDismissed(DemoPendingAction action) =>
      dismissedActions.contains(action.id);

  /// Number of approvals still awaiting a user decision.
  int get pendingCount {
    var count = 0;
    for (final approval in demoApprovals) {
      if (statusFor(approval) == DemoApprovalStatus.pending) count++;
    }
    return count;
  }

  /// Number of agent-request actions not yet dismissed.
  int get openActionsCount {
    var count = 0;
    for (final action in demoPendingActions) {
      if (!isDismissed(action)) count++;
    }
    return count;
  }

  /// Per-conversation pending count — drives the chat menu badge + the
  /// conversation row's pulse dot.
  int pendingForConversation(String conversationId) {
    var count = 0;
    for (final a in demoApprovalsForConversation(conversationId)) {
      if (statusFor(a) == DemoApprovalStatus.pending) count++;
    }
    return count;
  }

  /// Per-conversation open agent-request actions count.
  int openActionsForConversation(String conversationId) {
    var count = 0;
    for (final a in demoPendingActionsForConversation(conversationId)) {
      if (!isDismissed(a)) count++;
    }
    return count;
  }

  bool conversationNeedsAttention(String conversationId) {
    return pendingForConversation(conversationId) > 0 ||
        openActionsForConversation(conversationId) > 0;
  }

  ApprovalsState copyWith({
    Map<String, DemoApprovalStatus>? decisions,
    Set<String>? dismissedActions,
    Map<String, Set<String>>? preApprovedShapes,
  }) {
    return ApprovalsState(
      decisions: decisions ?? this.decisions,
      dismissedActions: dismissedActions ?? this.dismissedActions,
      preApprovedShapes: preApprovedShapes ?? this.preApprovedShapes,
    );
  }

  @override
  List<Object?> get props => [decisions, dismissedActions, preApprovedShapes];
}

class ApprovalsCubit extends Cubit<ApprovalsState> {
  ApprovalsCubit() : super(const ApprovalsState());

  void decide(String approvalId, DemoApprovalStatus status) {
    emit(state.copyWith(
      decisions: {...state.decisions, approvalId: status},
    ));
  }

  /// Approve the grouped request AND pre-approve every future write of
  /// the same shape in this conversation.
  void approveAllInGroup(DemoApproval approval) {
    final cid = approval.conversationId;
    final shape = approval.sharedShape;
    final nextDecisions = {
      ...state.decisions,
      approval.id: DemoApprovalStatus.approved,
    };
    if (cid != null && shape != null) {
      final existing = state.preApprovedShapes[cid] ?? const <String>{};
      final updated = {
        ...state.preApprovedShapes,
        cid: {...existing, shape},
      };
      emit(state.copyWith(
        decisions: nextDecisions,
        preApprovedShapes: updated,
      ));
    } else {
      emit(state.copyWith(decisions: nextDecisions));
    }
  }

  void dismissAction(String actionId) {
    emit(state.copyWith(
      dismissedActions: {...state.dismissedActions, actionId},
    ));
  }
}
