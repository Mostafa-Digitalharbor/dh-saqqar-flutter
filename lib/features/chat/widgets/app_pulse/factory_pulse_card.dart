import 'package:flutter/material.dart';

import '../../../../core/i18n/app_localizations.dart';
import '../../../../core/theme/app_sizes.dart';
import '../../../../shared/extensions/context_extensions.dart';
import '../../data/app_pulse_payloads.dart';
import '../../data/interactive_card_kind.dart';
import '../../data/pulse_actions.dart';
import 'pulse_card_shell.dart';
import 'pulse_helpers.dart';
import 'pulse_ranked_list.dart';

/// "Your factory" pulse — production status, missing material, and a
/// delivery date, computed from Odoo (Task 1, MOBILE_TASKS_2026-09.md).
class FactoryPulseCard extends StatelessWidget {
  const FactoryPulseCard({
    super.key,
    required this.payload,
    this.actions = const [],
    this.deepActions = const [],
    this.onSend,
  });

  final FactoryPulsePayload payload;

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
      kind: InteractiveCardKind.factory,
      envelope: payload.envelope,
      actions: actions,
      deepActions: deepActions,
      onSend: onSend,
      stats: [
        Wrap(
          spacing: AppSpacing.s16,
          runSpacing: AppSpacing.s12,
          children: [
            pulseScalarStatTile(context, payload.moRunning, tr.pulseFactoryMoRunning),
            pulseScalarStatTile(context, payload.moLate, tr.pulseFactoryMoLate),
            pulseScalarStatTile(
                context, payload.moDoneToday, tr.pulseFactoryMoDoneToday),
            pulseScalarStatTile(context, payload.poLate, tr.pulseFactoryPoLate),
            pulseScalarStatTile(
                context, payload.ordersAtRisk, tr.pulseFactoryOrdersAtRisk),
          ],
        ),
        PulseRankedList<FactoryTopRisk>(
          title: tr.pulseTopRisksTitle,
          items: payload.topRisks,
          itemBuilder: (context, risk) => _RiskRow(risk: risk),
        ),
      ],
    );
  }
}

class _RiskRow extends StatelessWidget {
  const _RiskRow({required this.risk});

  final FactoryTopRisk risk;

  @override
  Widget build(BuildContext context) {
    final s = context.saqqar;
    final tr = context.tr;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                risk.customer.isEmpty ? risk.order : '${risk.order} · ${risk.customer}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.text.bodyMedium?.copyWith(
                  color: s.text,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        if (risk.worstProduct.isNotEmpty)
          Text(
            risk.worstProduct,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.text.bodySmall?.copyWith(color: s.muted),
          ),
        const SizedBox(height: AppSpacing.s4),
        Wrap(
          spacing: AppSpacing.s10,
          runSpacing: AppSpacing.s4,
          children: [
            if (risk.missingLines != null)
              _stat(context, tr.pulseFactoryRiskMissingLines, '${risk.missingLines}'),
            if (risk.leadDays != null)
              _stat(context, tr.pulseFactoryRiskLeadDays, '${risk.leadDays}'),
          ],
        ),
      ],
    );
  }

  Widget _stat(BuildContext context, String label, String value) {
    final s = context.saqqar;
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: '$label: ',
            style: context.text.labelSmall?.copyWith(color: s.muted),
          ),
          TextSpan(
            text: value,
            style: context.text.labelSmall?.copyWith(
              color: s.text,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
