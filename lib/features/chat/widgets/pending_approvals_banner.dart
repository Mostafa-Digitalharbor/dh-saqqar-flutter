import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/i18n/app_localizations.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_radius.dart';
import '../../../shared/extensions/context_extensions.dart';
import '../../../shared/widgets/ghost_button.dart';
import '../../../shared/widgets/mini_chip.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../../shared/widgets/responsive_content.dart';
import '../../demo/saqqar_demo_data.dart';
import '../../inbox/state/approvals_controller.dart';

/// Inline strip rendered just above the composer when this conversation has
/// pending approvals. Replaces the old hidden ⋯-menu item: the user no longer
/// has to leave the chat (or open a menu) to act on Saqqar's requests.
///
/// Behaviour:
/// - 0 pending → renders nothing (zero-height).
/// - 1 pending → shows the approval title + body + Reject/Approve actions.
/// - 2+ pending → shows the first one inline + a "+X more pending" tail
///   that taps through to [onReviewMore] (the existing chat approvals sheet).
class PendingApprovalsBanner extends ConsumerWidget {
  const PendingApprovalsBanner({
    super.key,
    required this.conversationId,
    required this.onApprove,
    required this.onReject,
    required this.onReviewMore,
  });

  final String conversationId;
  final void Function(DemoApproval approval) onApprove;
  final void Function(DemoApproval approval) onReject;
  final VoidCallback onReviewMore;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = context.saqqar;
    final approvalsState = ref.watch(approvalsControllerProvider);
    final pending = demoApprovalsForConversation(conversationId)
        .where(
          (a) => approvalsState.statusFor(a) == DemoApprovalStatus.pending,
        )
        .toList();

    if (pending.isEmpty) return const SizedBox.shrink();

    final headline = pending.first;
    final extras = pending.length - 1;

    return ResponsiveContent(
      maxWidth: 980,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
      child: Container(
        decoration: BoxDecoration(
          // Stronger warning tint + visible left stripe so the banner
          // never reads as decorative — it MUST grab the user's eye the
          // moment it appears above the composer.
          color: s.warning.withValues(alpha: context.isDark ? 0.18 : 0.14),
          borderRadius: AppRadius.cardR,
          border: Border.all(
            color: s.warning.withValues(alpha: 0.55),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: s.warning.withValues(alpha: 0.18),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 28,
                  height: 28,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: s.warning.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: s.warning.withValues(alpha: 0.40),
                    ),
                  ),
                  child: Icon(
                    AppIcons.shieldAlert,
                    size: 16,
                    color: s.warning,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Tiny uppercase eyebrow so the user reads
                      // "PENDING APPROVAL" first — even if the title
                      // wording isn't immediately clear.
                      Text(
                        context.tr.pendingApprovals.toUpperCase(),
                        style: context.text.labelSmall?.copyWith(
                          color: s.warning,
                          fontWeight: FontWeight.w800,
                          fontSize: 9,
                          letterSpacing: 1.0,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              headline.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: context.text.titleSmall?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          if (headline.isGrouped) ...[
                            const SizedBox(width: 6),
                            MiniChip(
                              '×${headline.groupedCount ?? 1}',
                              color: s.warning,
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        headline.prompt,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: context.text.bodySmall?.copyWith(
                          color: s.muted,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                if (extras > 0)
                  Expanded(
                    child: GestureDetector(
                      onTap: onReviewMore,
                      behavior: HitTestBehavior.opaque,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Text(
                          context.tr.morePendingApprovals(extras),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.text.labelMedium?.copyWith(
                            color: s.brandCyan,
                            fontWeight: FontWeight.w700,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ),
                  )
                else
                  const Spacer(),
                GhostButton(
                  label: context.tr.reject,
                  icon: AppIcons.close,
                  minHeight: 38,
                  tone: GhostButtonTone.danger,
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    onReject(headline);
                  },
                ),
                const SizedBox(width: 8),
                PrimaryButton(
                  label: headline.isGrouped
                      ? context.tr.approveAllN(headline.groupedCount ?? 1)
                      : context.tr.approve,
                  icon: AppIcons.check,
                  minHeight: 38,
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    onApprove(headline);
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
