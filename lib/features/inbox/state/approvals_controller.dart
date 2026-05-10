import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../demo/saqqar_demo_data.dart';

/// Shared state for approval decisions and dismissed agent-request actions
/// across the app. The Inbox screen and Chat sheets both update this, so
/// dismissing in one place is immediately reflected in the other.
class ApprovalsState {
  const ApprovalsState({
    this.decisions = const {},
    this.dismissedActions = const {},
  });

  final Map<String, DemoApprovalStatus> decisions;
  final Set<String> dismissedActions;

  DemoApprovalStatus statusFor(DemoApproval approval) {
    return decisions[approval.id] ?? approval.status;
  }

  bool isDismissed(DemoPendingAction action) {
    return dismissedActions.contains(action.id);
  }

  /// Number of approvals still awaiting a user decision.
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
  }) {
    return ApprovalsState(
      decisions: decisions ?? this.decisions,
      dismissedActions: dismissedActions ?? this.dismissedActions,
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
