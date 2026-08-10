import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;

import '../../../core/constants/ui_strings.dart';
import '../../../core/i18n/app_localizations.dart';
import '../../../core/theme/app_icons.dart';
import '../../../shared/extensions/context_extensions.dart';
import '../../../shared/widgets/ghost_button.dart';
import '../../../shared/widgets/mini_chip.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../demo/saqqar_demo_data.dart';
import '../../../core/theme/app_radius.dart';
import '../data/delete_confirmation.dart';
import 'delete_approval_confirm_dialog.dart';
import 'email_approval_preview.dart';
import '../../../shared/widgets/colored_icon_box.dart';

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
    this.onApproveAllSimilar,
  });

  final DemoApproval approval;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  /// Sends the decision with `scope: "batch"` — resolves every pending
  /// sibling of the same shape in this conversation AND pre-approves future
  /// ones. Null on surfaces that don't support it (the rail drawer), which
  /// hides the action rather than showing a dead control.
  final VoidCallback? onApproveAllSimilar;

  @override
  State<ChatApprovalCard> createState() => _ChatApprovalCardState();
}

class _ChatApprovalCardState extends State<ChatApprovalCard> {
  bool _showDetails = false;

  /// Whether this approval deletes Odoo records — the one action here that
  /// can't be undone. Read off the SERVER's `payload.operation`, never
  /// guessed from the prompt text.
  bool get _isDestructiveDelete =>
      widget.approval.payload['operation'] == kDeleteOperation;

  /// Approve, gated by the type-to-confirm dialog for deletes (web parity).
  ///
  /// Lives on the card rather than at each call site so BOTH surfaces that
  /// render approvals — inline in the chat stream and the rail drawer — get
  /// the gate. A second copy is how one of them ends up without it.
  Future<void> _approve() async {
    // Fire-and-forget: awaiting the haptic would gate a user-visible dialog
    // on a platform channel that never answers in a widget test (and can be
    // slow on a real device).
    unawaited(HapticFeedback.mediumImpact());
    if (_isDestructiveDelete) {
      final confirmed = await DeleteApprovalConfirmDialog.show(
        context,
        // Falls back to 1: the phrase must always name a real number,
        // because it's what the user has to type.
        recordCount: widget.approval.recordCount ?? 1,
        // The server's own canonical phrase when it sent one; the locale
        // phrases stay accepted alongside it.
        serverPhrase: widget.approval.confirmPhrase,
      );
      if (!confirmed || !mounted) return;
    }
    widget.onApprove();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.saqqar;
    final approval = widget.approval;
    final email = EmailApprovalPreview.of(approval.payload);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: s.surface.withValues(alpha: context.isDark ? 0.62 : 0.92),
        borderRadius: AppRadius.bubbleR,
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
                    ColoredIconBox(
                      icon: AppIcons.shieldAlert,
                      color: s.warning,
                      size: 34,
                      radius: AppRadius.small,
                      iconSize: 17,
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
                      MiniChip(
                          '${UiStrings.timesSign}${approval.groupedCount ?? 1}',
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
                // §9 — when the payload is an email, show it AS an email
                // (recipient / subject / body) rather than as key-value
                // chips. The raw payload stays available under "Show
                // details" below, so nothing is hidden, only laid out.
                if (email != null) email,
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
                      // Always the singular "Approve". The card cannot label
                      // a count: the backend has no `grouped_count` field, and
                      // the number of siblings a batch clears is only known
                      // from the decision RESPONSE. "Approve all 6" here would
                      // be a number the client invented.
                      child: PrimaryButton(
                        label: context.tr.approve,
                        icon: AppIcons.check,
                        onPressed: _approve,
                      ),
                    ),
                  ],
                ),
                // Batch resolve — a separate, quieter action rather than the
                // primary button, because it does strictly more than the user
                // asked: it clears every pending sibling AND pre-approves
                // future writes of the same shape. Hidden for deletes (the
                // server 400s) and for approvals already covered by a scope.
                if (widget.onApproveAllSimilar != null &&
                    approval.canBatchApprove) ...[
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: GhostButton(
                      label: context.tr.approveAllSimilar,
                      icon: AppIcons.check,
                      onPressed: () {
                        unawaited(HapticFeedback.mediumImpact());
                        widget.onApproveAllSimilar!();
                      },
                    ),
                  ),
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
