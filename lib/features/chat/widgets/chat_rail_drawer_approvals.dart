part of 'chat_rail_drawer.dart';

class _ApprovalsTab extends StatelessWidget {
  const _ApprovalsTab({
    required this.approvals,
    required this.company,
    required this.onApprove,
    required this.onReject,
    required this.onView,
  });

  final List<inbox_api.Approval> approvals;
  final String company;

  /// Take the whole approval, not just its id: a destructive delete has to
  /// carry its confirm phrase into the decision POST, and an id cannot.
  final ValueChanged<inbox_api.Approval> onApprove;
  final ValueChanged<inbox_api.Approval> onReject;

  /// "View details": leave the drawer and show this request where it is
  /// decided, in the chat.
  final ValueChanged<inbox_api.Approval> onView;

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
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.s16,
        AppSpacing.s14,
        AppSpacing.s16,
        AppSpacing.s24,
      ),
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.s12),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  context.tr.figRequests,
                  style: Fig.t(
                    context,
                    size: AppFontSizes.caption,
                    color: Fig.muted,
                  ),
                ),
              ),
              Text(
                context.tr.figNeedsYourReview(needs),
                style: Fig.t(
                  context,
                  size: AppFontSizes.caption,
                  color: Fig.muted,
                ),
              ),
            ],
          ),
        ),
        for (final a in approvals) ...[
          _ApprovalCard(
            approval: a,
            onApprove: () => onApprove(a),
            onReject: () => onReject(a),
            onView: () => onView(a),
          ),
          const SizedBox(height: AppSpacing.s12),
        ],
        Padding(
          padding: const EdgeInsets.only(top: AppSpacing.s6),
          child: Text(
            company.isEmpty
                ? context.tr.figRequestsSharedInChats
                : context.tr.figRequestsSharedInChats2(company),
            style: Fig.t(
              context,
              size: AppFontSizes.metaLine,
              color: Fig.muted,
            ),
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
    required this.onView,
  });

  final inbox_api.Approval approval;
  final VoidCallback onApprove;
  final VoidCallback onReject;
  final VoidCallback onView;

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
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.s14,
        AppSpacing.s12,
        AppSpacing.s14,
        AppSpacing.s12,
      ),
      decoration: BoxDecoration(
        color: AppColors.figCFFDFE2EE,
        borderRadius: BorderRadius.circular(AppRadius.modal),
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
                  style: Fig.t(
                    context,
                    size: AppFontSizes.microCaps,
                    color: Fig.muted,
                  ),
                ),
              ),
              Container(
                width: FigMetrics.size7,
                height: FigMetrics.size7,
                decoration: BoxDecoration(color: tone, shape: BoxShape.circle),
              ),
              const SizedBox(width: AppSpacing.s6),
              Flexible(
                child: Text(
                  word,
                  style: Fig.t(
                    context,
                    size: AppFontSizes.microCaps,
                    color: tone,
                  ),
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
              size: AppFontSizes.markdownH2,
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
                      style: Fig.t(
                        context,
                        size: AppFontSizes.caption,
                        color: Fig.navy,
                      ),
                    ),
                  ),
                ],
                const Spacer(),
                Flexible(
                  child: Text(
                    when,
                    style: Fig.t(
                      context,
                      size: AppFontSizes.microCaps,
                      color: Fig.muted,
                    ),
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
              style: Fig.t(
                context,
                size: AppFontSizes.caption,
                color: Fig.muted,
              ),
            ),
          ],
          if (a.status == inbox_api.ApprovalStatus.pending) ...[
            const SizedBox(height: AppSpacing.s12),
            // "View details" gets its own line; the two decisions sit under it,
            // centred on the card. A Wrap, not a Row, so at a large text size
            // the second button drops to the next line instead of overflowing.
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onView,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    context.tr.figViewDetails,
                    style: Fig.t(
                      context,
                      size: AppFontSizes.caption,
                      weight: FontWeight.w600,
                      color: Fig.blue,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.s4),
                  Icon(
                    Directionality.of(context) == TextDirection.rtl
                        ? LucideIcons.arrowLeft
                        : LucideIcons.arrowRight,
                    size: AppIconSizes.dense,
                    color: Fig.blue,
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.s12),
            Center(
              child: Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: AppSpacing.s8,
                runSpacing: AppSpacing.s8,
                children: [
                  GestureDetector(
                    onTap: onReject,
                    child: Container(
                      height: 34,
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.s16,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.figCFFE9EBF3,
                        borderRadius: BorderRadius.circular(
                          FigMetrics.radFig17,
                        ),
                      ),
                      // widthFactor: 1 — the pill hugs its label. A Container
                      // with `alignment` takes all the width it is offered,
                      // which sent each button to its own row.
                      child: Center(
                        widthFactor: 1,
                        child: Text(
                          context.tr.figReject,
                          style: Fig.t(
                            context,
                            size: AppFontSizes.caption,
                            color: Fig.dangerText,
                          ),
                        ),
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: onApprove,
                    child: Container(
                      height: 34,
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.s18,
                      ),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Fig.blueTop, Fig.blueBottom],
                        ),
                        borderRadius: BorderRadius.circular(
                          FigMetrics.radFig17,
                        ),
                      ),
                      child: Center(
                        widthFactor: 1,
                        child: Text(
                          context.tr.figApprove,
                          style: Fig.t(
                            context,
                            size: AppFontSizes.caption,
                            weight: FontWeight.w600,
                            color: AppColors.figWhite,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            const SizedBox(height: AppSpacing.s8),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onView,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    context.tr.figViewDetails,
                    style: Fig.t(
                      context,
                      size: AppFontSizes.caption,
                      weight: FontWeight.w600,
                      color: Fig.blue,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.s4),
                  Icon(
                    Directionality.of(context) == TextDirection.rtl
                        ? LucideIcons.arrowLeft
                        : LucideIcons.arrowRight,
                    size: AppIconSizes.dense,
                    color: Fig.blue,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
