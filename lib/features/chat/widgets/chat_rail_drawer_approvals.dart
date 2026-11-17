part of 'chat_rail_drawer.dart';

class _ApprovalsTab extends StatelessWidget {
  const _ApprovalsTab({
    required this.approvals,
    required this.company,
    required this.onApprove,
    required this.onReject,
  });

  final List<inbox_api.Approval> approvals;
  final String company;

  /// Take the whole approval, not just its id: a destructive delete has to
  /// carry its confirm phrase into the decision POST, and an id cannot.
  final ValueChanged<inbox_api.Approval> onApprove;
  final ValueChanged<inbox_api.Approval> onReject;

  @override
  Widget build(BuildContext context) {
    if (approvals.isEmpty) {
      return _EmptyTab(
        icon: LucideIcons.shieldCheck,
        title: context.tr.noPendingApprovalsTitle,
        body: context.tr.noPendingApprovalsBody,
      );
    }
    final needs = approvals
        .where((a) => a.status == inbox_api.ApprovalStatus.pending)
        .length;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.s12),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  context.tr.figRequests,
                  style: Fig.t(context, size: 13, color: Fig.muted),
                ),
              ),
              Text(
                context.tr.figNeedsYourReview(needs),
                style: Fig.t(context, size: 13, color: Fig.muted),
              ),
            ],
          ),
        ),
        for (final a in approvals) ...[
          _ApprovalCard(
            approval: a,
            onApprove: () => onApprove(a),
            onReject: () => onReject(a),
          ),
          const SizedBox(height: AppSpacing.s12),
        ],
        Padding(
          padding: const EdgeInsets.only(top: AppSpacing.s6),
          child: Text(
            company.isEmpty
                ? context.tr.figRequestsSharedInChats
                : context.tr.figRequestsSharedInChats2(company),
            style: Fig.t(context, size: 12.5, color: Fig.muted),
          ),
        ),
      ],
    );
  }
}

class _ApprovalCard extends StatelessWidget {
  const _ApprovalCard({
    required this.approval,
    required this.onApprove,
    required this.onReject,
  });

  final inbox_api.Approval approval;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    final a = approval;
    final adapted = adaptApiApproval(a, context.tr);
    final (Color tone, String word) = switch (a.status) {
      inbox_api.ApprovalStatus.pending => (
        _statusPending,
        context.tr.figPending,
      ),
      inbox_api.ApprovalStatus.approved => (
        _statusApproved,
        context.tr.figApproved,
      ),
      inbox_api.ApprovalStatus.rejected => (
        _statusRejected,
        context.tr.figRejected,
      ),
    };
    final who = a.conversation?.title ?? '';
    final when = a.createdAt == null
        ? ''
        : '${AppDateFormat.date(context, a.createdAt!)} · ${AppDateFormat.time(context, a.createdAt!)}';
    final model = adapted.payload['model'] ?? '';
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: const Color(0xFFDFE2EE),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  model.isEmpty ? a.actionType.wire : model,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Fig.t(context, size: 12, color: Fig.muted),
                ),
              ),
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(color: tone, shape: BoxShape.circle),
              ),
              const SizedBox(width: AppSpacing.s6),
              Flexible(
                child: Text(
                  word,
                  style: Fig.t(context, size: 12, color: tone),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.s6),
          Text(
            adapted.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Fig.t(
              context,
              size: 17,
              weight: FontWeight.w700,
              color: Fig.navy,
            ),
          ),
          if (who.isNotEmpty || when.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.s8),
            Row(
              children: [
                if (who.isNotEmpty) ...[
                  _Avatar(who),
                  const SizedBox(width: AppSpacing.s8),
                  Flexible(
                    child: Text(
                      who,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Fig.t(context, size: 13, color: Fig.navy),
                    ),
                  ),
                ],
                const Spacer(),
                Flexible(
                  child: Text(
                    when,
                    style: Fig.t(context, size: 12, color: Fig.muted),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
          if (a.prompt.trim().isNotEmpty) ...[
            const SizedBox(height: AppSpacing.s8),
            Text(
              a.prompt,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: Fig.t(context, size: 13, color: Fig.muted),
            ),
          ],
          if (a.status == inbox_api.ApprovalStatus.pending) ...[
            const SizedBox(height: AppSpacing.s12),
            Row(
              children: [
                Expanded(
                  child: Text(
                    context.tr.figViewDetails,
                    style: Fig.t(
                      context,
                      size: 13,
                      weight: FontWeight.w600,
                      color: Fig.blue,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: onReject,
                  child: Container(
                    height: 34,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.s16,
                    ),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE9EBF3),
                      borderRadius: BorderRadius.circular(17),
                    ),
                    child: Text(
                      context.tr.figReject,
                      style: Fig.t(context, size: 13, color: Fig.dangerText),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.s8),
                GestureDetector(
                  onTap: onApprove,
                  child: Container(
                    height: 34,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.s18,
                    ),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Fig.blueTop, Fig.blueBottom],
                      ),
                      borderRadius: BorderRadius.circular(17),
                    ),
                    child: Text(
                      context.tr.figApprove,
                      style: Fig.t(
                        context,
                        size: 13,
                        weight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ] else ...[
            const SizedBox(height: AppSpacing.s8),
            Text(
              context.tr.figViewDetails,
              style: Fig.t(
                context,
                size: 13,
                weight: FontWeight.w600,
                color: Fig.blue,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
