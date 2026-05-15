import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../demo/saqqar_demo_data.dart';

/// Shared state for approval decisions, dismissed agent-request actions, AND
/// pre-approved write shapes per conversation. Inbox + Chat sheets both
/// drive this so dismissing/approving in one place is immediately reflected
/// in the other.
class ApprovalsState {
  const ApprovalsState({
    this.decisions = const {},
    this.dismissedActions = const {},
    this.preApprovedShapes = const {},
  });

  final Map<String, DemoApprovalStatus> decisions;
  final Set<String> dismissedActions;

  /// Map of `conversationId → set of pre-approved shape keys` (e.g.
  /// `odoo_write:res.users:write`). When the user taps "Approve all" on a
  /// grouped approval, the [sharedShape] is added here for the conversation,
  /// and every future approval with the same shape in the same conversation
  /// is auto-marked approved by the controller. Mirrors the web's
  /// "approving 'Approve all' pre-approves future writes of the same shape
  /// in this conversation" tip.
  final Map<String, Set<String>> preApprovedShapes;

  DemoApprovalStatus statusFor(DemoApproval approval) {
    if (decisions.containsKey(approval.id)) return decisions[approval.id]!;
    // Pre-approval — same conversation + same shape ⇒ auto-approved.
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

  bool isDismissed(DemoPendingAction action) {
    return dismissedActions.contains(action.id);
  }

  /// Number of approvals still awaiting a user decision (decisions map empty
  /// AND not silenced by pre-approval).
  int get pendingCount {
    var count = 0;
    for (final approval in demoApprovals) {
      if (statusFor(approval) == DemoApprovalStatus.pending) count++;
    }
    return count;
  }

  /// Number of agent-request actions that haven't been dismissed yet.
  int get openActionsCount {
    var count = 0;
    for (final action in demoPendingActions) {
      if (!isDismissed(action)) count++;
    }
    return count;
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
}

class ApprovalsController extends Notifier<ApprovalsState> {
  @override
  ApprovalsState build() => const ApprovalsState();

  void decide(String approvalId, DemoApprovalStatus status) {
    state = state.copyWith(
      decisions: {...state.decisions, approvalId: status},
    );
  }

  /// Approve the grouped request AND pre-approve every future write of the
  /// same shape in this conversation. The chat surface signs off on this
  /// via the "Tip: clicking 'Approve all' also pre-approves every future
  /// write of the same shape in this conversation" hint.
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
      state = state.copyWith(
        decisions: nextDecisions,
        preApprovedShapes: updated,
      );
    } else {
      state = state.copyWith(decisions: nextDecisions);
    }
  }

  void dismissAction(String actionId) {
    state = state.copyWith(
      dismissedActions: {...state.dismissedActions, actionId},
    );
  }
}

final approvalsControllerProvider =
    NotifierProvider<ApprovalsController, ApprovalsState>(
      ApprovalsController.new,
    );

/// Convenience selector: just the pending count. Use this in HomeShell so
/// the badge only rebuilds when the count changes.
final pendingApprovalsCountProvider = Provider<int>((ref) {
  return ref.watch(
    approvalsControllerProvider.select((state) => state.pendingCount),
  );
});

/// Per-conversation pending approvals count. Drives the badge on the chat
/// menu and the pulse dot on the conversation row.
final conversationPendingApprovalsProvider = Provider.family<int, String>(
  (ref, conversationId) {
    final state = ref.watch(approvalsControllerProvider);
    var count = 0;
    for (final approval in demoApprovalsForConversation(conversationId)) {
      if (state.statusFor(approval) == DemoApprovalStatus.pending) count++;
    }
    return count;
  },
);

/// Per-conversation open agent-request actions count.
final conversationOpenActionsProvider = Provider.family<int, String>(
  (ref, conversationId) {
    final state = ref.watch(approvalsControllerProvider);
    var count = 0;
    for (final action in demoPendingActionsForConversation(conversationId)) {
      if (!state.isDismissed(action)) count++;
    }
    return count;
  },
);

/// Convenience: does this conversation need user attention right now?
/// Used by the conversation row's pulse dot.
final conversationNeedsAttentionProvider = Provider.family<bool, String>(
  (ref, conversationId) {
    final pending = ref.watch(conversationPendingApprovalsProvider(conversationId));
    final open = ref.watch(conversationOpenActionsProvider(conversationId));
    return pending > 0 || open > 0;
  },
);
