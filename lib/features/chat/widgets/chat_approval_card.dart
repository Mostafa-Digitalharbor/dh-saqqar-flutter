import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;

import '../../../core/i18n/app_localizations.dart';
import '../../../core/theme/app_icons.dart';
import '../../../shared/extensions/context_extensions.dart';
import '../../../shared/widgets/ghost_button.dart';
import '../../../shared/widgets/mini_chip.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../demo/saqqar_demo_data.dart';

/// Approval card shown inside the chat "Pending approvals" sheet.
/// Neutral surface + 4 px amber start-side stripe + Reject / Approve actions.
///
/// The friendly title ("Create 6 × Manufacturing Order", Gap E) is always
/// visible; the raw `payload` map stays collapsed behind a "Show details"
/// toggle so non-technical users aren't faced with a JSON dump by default.
class ChatApprovalCard extends StatefulWidget {
  const ChatApprovalCard({
    super.key,
    required this.approval,
    required this.onApprove,
    required this.onReject,
  });

  final DemoApproval approval;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  @override
  State<ChatApprovalCard> createState() => _ChatApprovalCardState();
}

class _ChatApprovalCardState extends State<ChatApprovalCard> {
  bool _showDetails = false;

  @override
  Widget build(BuildContext context) {
    final s = context.saqqar;
    final approval = widget.approval;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: s.surface.withValues(alpha: context.isDark ? 0.62 : 0.92),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: s.cardBorder),
      ),
      child: Stack(
        children: [
          PositionedDirectional(
            start: 0,
            top: 0,
            bottom: 0,
            child: Container(
              width: 4,
              decoration: BoxDecoration(
                color: s.warning,
                borderRadius: const BorderRadiusDirectional.horizontal(
                  start: Radius.circular(16),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(18, 14, 14, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: s.warning.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: s.warning.withValues(alpha: 0.30),
                        ),
                      ),
                      child: Icon(
                        AppIcons.shieldAlert,
                        color: s.warning,
                        size: 17,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        approval.title,
                        style: context.text.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: s.text,
                          letterSpacing: -0.1,
                        ),
                      ),
                    ),
                    if (approval.isGrouped) ...[
                      MiniChip('×${approval.groupedCount ?? 1}',
                          color: s.warning),
                      const SizedBox(width: 6),
                    ],
                    MiniChip(approval.risk, color: s.warning),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  approval.prompt,
                  style: context.text.bodyMedium?.copyWith(
                    color: s.muted,
                    height: 1.5,
                  ),
                ),
                // Gap E — raw payload collapsed by default behind a
                // "Show details" disclosure; the friendly title above is
                // enough for non-technical users.
                if (approval.payload.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => setState(() => _showDetails = !_showDetails),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _showDetails
                              ? AppIcons.chevronUp
                              : AppIcons.chevronDown,
                          size: 15,
                          color: s.muted,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _showDetails
                              ? context.tr.hideDetails
                              : context.tr.showDetails,
                          style: context.text.labelMedium?.copyWith(
                            color: s.muted,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_showDetails) ...[
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final entry in approval.payload.entries)
                          MiniChip(context.tr.keyValue(entry.key, entry.value)),
                      ],
                    ),
                  ],
                ],
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: GhostButton(
                        label: context.tr.reject,
                        icon: AppIcons.close,
                        onPressed: () {
                          HapticFeedback.mediumImpact();
                          widget.onReject();
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      // Web parity: when this approval is grouped (shape
                      // shared by multiple pending writes), the primary
                      // button approves the whole batch in one tap AND
                      // pre-approves future writes of the same shape in
                      // this conversation. The label must reflect that —
                      // a generic "Approve" would be misleading.
                      child: PrimaryButton(
                        label: approval.isGrouped
                            ? context.tr.approveAllN(
                                approval.groupedCount ?? 1,
                              )
                            : context.tr.approve,
                        icon: AppIcons.check,
                        onPressed: () {
                          HapticFeedback.mediumImpact();
                          widget.onApprove();
                        },
                      ),
                    ),
                  ],
                ),
                // Pre-approval hint — same copy the web uses below the
                // "Approve all" button. Only rendered when the approval
                // belongs to a shape group so single one-off approvals
                // don't get an irrelevant disclosure.
                if (approval.isGrouped) ...[
                  const SizedBox(height: 8),
                  Text(
                    context.tr.preApprovalTip,
                    style: context.text.labelSmall?.copyWith(
                      color: s.muted,
                      height: 1.4,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
