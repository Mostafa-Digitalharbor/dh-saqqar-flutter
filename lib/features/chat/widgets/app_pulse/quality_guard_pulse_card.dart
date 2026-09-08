import 'package:flutter/material.dart';

import '../../../../core/format/compact_number.dart';
import '../../../../core/i18n/app_localizations.dart';
import '../../../../core/theme/app_sizes.dart';
import '../../../../shared/extensions/context_extensions.dart';
import '../../data/app_pulse_payloads.dart';
import '../../data/interactive_card_kind.dart';
import '../../data/pulse_actions.dart';
import 'pulse_card_shell.dart';
import 'pulse_helpers.dart';

/// "Quality Guard" pulse — numeric quality checks combined with spec-
/// substitution review, using standard Odoo records (Task 1,
/// MOBILE_TASKS_2026-09.md).
class QualityGuardPulseCard extends StatelessWidget {
  const QualityGuardPulseCard({
    super.key,
    required this.payload,
    this.actions = const [],
    this.deepActions = const [],
    this.onSend,
  });

  final QualityGuardPulsePayload payload;

  /// Web-parity action rows, built by `pulseActions` from the same payload.
  /// Empty leaves the card read-only, which is what every non-chat surface
  /// (the storybook, the conformance sweeps) wants.
  final List<PulseAction> actions;
  final List<PulseAction> deepActions;
  final ValueChanged<String>? onSend;

  @override
  Widget build(BuildContext context) {
    final tr = context.tr;
    return PulseCardShell(
      kind: InteractiveCardKind.qualityGuard,
      envelope: payload.envelope,
      actions: actions,
      deepActions: deepActions,
      onSend: onSend,
      priorities: payload.priorities,
      stats: [
        Wrap(
          spacing: AppSpacing.s16,
          runSpacing: AppSpacing.s12,
          children: [
            pulseScalarStatTile(
                context, payload.outOfSpec, tr.pulseQualityOutOfSpec),
            pulseScalarStatTile(
                context, payload.failedChecks, tr.pulseQualityFailedChecks),
            pulseScalarStatTile(
                context, payload.pendingChecks, tr.pulseQualityPendingChecks),
            pulseScalarStatTile(
                context, payload.qualityAlerts, tr.pulseQualityAlerts),
            pulseScalarStatTile(context, payload.missingNumericSpecs,
                tr.pulseQualityMissingSpecs),
            pulseScalarStatTile(
                context, payload.reviewCases, tr.pulseQualityReviewCases),
            pulseScalarStatTile(
                context, payload.invoiceSwaps, tr.pulseQualityInvoiceSwaps),
            pulseScalarStatTile(
                context, payload.deliverySwaps, tr.pulseQualityDeliverySwaps),
            pulseScalarStatTile(
                context, payload.highRiskCases, tr.pulseQualityHighRiskCases),
            pulseScalarStatTile(
                context, payload.deepDiscounts, tr.pulseQualityDeepDiscounts),
            pulseScalarStatTile(context, payload.lowerCostSubstitutes,
                tr.pulseQualityLowerCostSubstitutes),
            // Documented vs. undocumented is the pair the app exists to
            // separate, so both show even when one of them is zero.
            pulseScalarStatTile(context, payload.documentedSubstitutes,
                tr.pulseQualityDocumentedSubstitutes),
            pulseScalarStatTile(context, payload.undocumentedSubstitutes,
                tr.pulseQualityUndocumentedSubstitutes),
            if (payload.costSavingTotal != null && payload.costSavingTotal! > 0)
              pulseStatTile(
                compactCount(payload.costSavingTotal!.round(), tr),
                tr.pulseQualityCostSaving,
              ),
            if (payload.discountValueEstimate != null &&
                payload.discountValueEstimate! > 0)
              pulseStatTile(
                compactCount(payload.discountValueEstimate!.round(), tr),
                tr.pulseQualityDiscountValue,
              ),
          ],
        ),
        // Not a metric — a fact about how the reading was taken, which is
        // why it's a line rather than a tile.
        if (payload.standardOdooOnly ?? false)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.s10),
            child: Text(
              tr.pulseQualityStandardOdooOnly,
              style: context.text.labelSmall?.copyWith(
                color: context.saqqar.muted,
              ),
            ),
          ),
      ],
    );
  }
}
