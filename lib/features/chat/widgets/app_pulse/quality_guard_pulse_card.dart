import 'package:flutter/material.dart';

import '../../../../core/format/compact_number.dart';
import '../../../../core/i18n/app_localizations.dart';
import '../../../../core/theme/app_sizes.dart';
import '../../../../shared/widgets/stat_tile.dart';
import '../../data/app_pulse_payloads.dart';
import '../../data/interactive_card_kind.dart';
import 'pulse_card_shell.dart';
import 'pulse_helpers.dart';

/// "Quality Guard" pulse — numeric quality checks combined with spec-
/// substitution review, using standard Odoo records (Task 1,
/// MOBILE_TASKS_2026-09.md).
class QualityGuardPulseCard extends StatelessWidget {
  const QualityGuardPulseCard({super.key, required this.payload});

  final QualityGuardPulsePayload payload;

  @override
  Widget build(BuildContext context) {
    final tr = context.tr;
    return PulseCardShell(
      kind: InteractiveCardKind.qualityGuard,
      envelope: payload.envelope,
      priorities: payload.priorities,
      children: [
        Wrap(
          spacing: AppSpacing.s16,
          runSpacing: AppSpacing.s12,
          children: [
            _tile(context, payload.outOfSpec, tr.pulseQualityOutOfSpec),
            _tile(context, payload.failedChecks, tr.pulseQualityFailedChecks),
            _tile(
                context, payload.pendingChecks, tr.pulseQualityPendingChecks),
            _tile(context, payload.qualityAlerts, tr.pulseQualityAlerts),
            _tile(context, payload.missingNumericSpecs,
                tr.pulseQualityMissingSpecs),
            _tile(context, payload.reviewCases, tr.pulseQualityReviewCases),
            _tile(context, payload.invoiceSwaps, tr.pulseQualityInvoiceSwaps),
            _tile(
                context, payload.deliverySwaps, tr.pulseQualityDeliverySwaps),
            _tile(
                context, payload.highRiskCases, tr.pulseQualityHighRiskCases),
            if (payload.costSavingTotal != null && payload.costSavingTotal! > 0)
              _wrap(
                compactCount(payload.costSavingTotal!.round(), tr),
                tr.pulseQualityCostSaving,
                null,
              ),
          ],
        ),
      ],
    );
  }

  Widget _wrap(String value, String label, Color? color) => SizedBox(
        width: AppControlSizes.pulseStatTile,
        child: StatTile(value: value, label: label, valueColor: color),
      );

  Widget _tile(BuildContext context, int? value, String label) {
    final cell = pulseScalarCell(context, value);
    return _wrap(cell.value, label, cell.color);
  }
}
