import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/i18n/app_localizations.dart';
import '../../../core/theme/app_icons.dart';
import '../../../shared/extensions/context_extensions.dart';
import '../../../shared/widgets/action_card.dart';
import '../../../shared/widgets/app_toast.dart';
import '../../../shared/widgets/feature_intro_card.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/widgets/ghost_button.dart';
import '../../../shared/widgets/mini_chip.dart';
import '../../../shared/widgets/page_scaffold.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../../shared/widgets/section_header.dart';
import '../../../shared/widgets/status_pill.dart';
import '../../demo/saqqar_demo_data.dart';
import '../state/approvals_controller.dart';

class InboxScreen extends ConsumerStatefulWidget {
  const InboxScreen({super.key});

  @override
  ConsumerState<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends ConsumerState<InboxScreen> {
  @override
  Widget build(BuildContext context) {
    final approvalsState = ref.watch(approvalsControllerProvider);
    final openActions = demoPendingActions
        .where((a) => !approvalsState.isDismissed(a))
        .toList();
    final pendingApprovals = demoApprovals
        .where(
          (approval) =>
              approvalsState.statusFor(approval) == DemoApprovalStatus.pending,
        )
        .toList();

    return PageScaffold(
      title: context.tr.tabInbox,
      children: [
        FeatureIntroCard(
          title: context.tr.actionCenter,
          body: context.tr.actionCenterSummaryBody,
          pills: [
            StatusPill(label: context.tr.agentRequests, pulsing: true),
            StatusPill(label: context.tr.reviewQueue),
          ],
        ),
        const SizedBox(height: 18),
        SectionHeader(
          title: context.tr.agentRequests,
          chip: context.tr.openCount(openActions.length),
        ),
        const SizedBox(height: 10),
        if (openActions.isEmpty)
          _EmptyCard(
            icon: AppIcons.success,
            title: context.tr.noAgentActionsTitle,
            body: context.tr.noAgentActionsBody,
          )
        else
          for (final action in openActions) ...[
            _PendingActionCard(
              action: action,
              onDismiss: () {
                ref
                    .read(approvalsControllerProvider.notifier)
                    .dismissAction(action.id);
                _toast(context.tr.actionDismissed);
              },
            ),
            const SizedBox(height: 10),
          ],
        const SizedBox(height: 18),
        SectionHeader(
          title: context.tr.pendingApprovals,
          chip: context.tr.pendingCount(pendingApprovals.length),
        ),
        const SizedBox(height: 10),
        if (pendingApprovals.isEmpty)
          _EmptyCard(
            icon: AppIcons.shieldCheck,
            title: context.tr.noPendingApprovalsTitle,
            body: context.tr.noPendingApprovalsBody,
          )
        else
          for (final approval in pendingApprovals) ...[
            _ApprovalDecisionCard(
              approval: approval,
              onApprove: () => _decide(approval, DemoApprovalStatus.approved),
              onReject: () => _decide(approval, DemoApprovalStatus.rejected),
            ),
            const SizedBox(height: 10),
          ],
        const SizedBox(height: 18),
        SectionHeader(title: context.tr.history, chip: context.tr.latest),
        const SizedBox(height: 10),
        for (final approval in demoApprovals.where(
          (a) => approvalsState.statusFor(a) != DemoApprovalStatus.pending,
        ))
          _HistoryTile(
            approval: approval,
            status: approvalsState.statusFor(approval),
          ),
      ],
    );
  }

  void _decide(DemoApproval approval, DemoApprovalStatus status) {
    ref.read(approvalsControllerProvider.notifier).decide(approval.id, status);
    _toast(
      status == DemoApprovalStatus.approved
          ? context.tr.approvalGrantedExecuting
          : context.tr.approvalRejected,
    );
  }

  void _toast(String text) {
    AppToast.show(context, message: text);
  }
}

class _PendingActionCard extends StatelessWidget {
  const _PendingActionCard({required this.action, required this.onDismiss});

  final DemoPendingAction action;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return ActionCard(
      title: action.title,
      body: action.body,
      icon: action.icon,
      color: action.color,
      actions: [
        GhostButton(
          label: context.tr.dismiss,
          icon: AppIcons.close,
          onPressed: onDismiss,
        ),
        PrimaryButton(
          label: context.tr.open,
          icon: AppIcons.open,
          onPressed: () =>
              AppToast.show(context, message: context.tr.opening(action.title)),
        ),
      ],
    );
  }
}

class _ApprovalDecisionCard extends StatelessWidget {
  const _ApprovalDecisionCard({
    required this.approval,
    required this.onApprove,
    required this.onReject,
  });

  final DemoApproval approval;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    return ActionCard(
      title: approval.title,
      body: approval.prompt,
      icon: AppIcons.shieldAlert,
      warning: true,
      chips: [
        MiniChip(approval.actionType),
        MiniChip(context.tr.riskValue(approval.risk)),
        for (final entry in approval.payload.entries)
          MiniChip(context.tr.keyValue(entry.key, entry.value)),
      ],
      actions: [
        GhostButton(
          label: context.tr.reject,
          icon: AppIcons.close,
          onPressed: onReject,
        ),
        PrimaryButton(
          label: context.tr.approve,
          icon: AppIcons.check,
          onPressed: onApprove,
        ),
      ],
    );
  }
}

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({required this.approval, required this.status});

  final DemoApproval approval;
  final DemoApprovalStatus status;

  @override
  Widget build(BuildContext context) {
    final color = status == DemoApprovalStatus.approved
        ? context.saqqar.success
        : context.saqqar.danger;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        status == DemoApprovalStatus.approved
            ? AppIcons.success
            : AppIcons.error,
        color: color,
      ),
      title: Text(approval.title),
      subtitle: Text(approval.prompt),
      trailing: MiniChip(
        status == DemoApprovalStatus.approved
            ? context.tr.approved
            : context.tr.rejected,
        color: color,
      ),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final s = context.saqqar;
    return GlassCard(
      blur: false,
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 22),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: s.success.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: s.success.withValues(alpha: 0.25)),
            ),
            child: Icon(icon, size: 26, color: s.success),
          ),
          const SizedBox(height: 14),
          Text(
            title,
            style: context.text.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            body,
            textAlign: TextAlign.center,
            style: context.text.bodyMedium?.copyWith(
              color: s.muted,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
