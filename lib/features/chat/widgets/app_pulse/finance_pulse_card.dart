import 'package:flutter/material.dart';

import '../../../../core/format/compact_number.dart';
import '../../../../core/i18n/app_localizations.dart';
import '../../../../core/theme/app_sizes.dart';
import '../../../../shared/extensions/context_extensions.dart';
import '../../../../shared/widgets/stat_tile.dart';
import '../../data/app_pulse_payloads.dart';
import '../../data/interactive_card_kind.dart';
import 'pulse_card_shell.dart';
import 'pulse_helpers.dart';

/// "Your money" pulse — collect, pay, reconcile and close the day straight
/// from Odoo financial data (Task 1, MOBILE_TASKS_2026-09.md).
class FinancePulseCard extends StatelessWidget {
  const FinancePulseCard({super.key, required this.payload});

  final FinancePulsePayload payload;

  @override
  Widget build(BuildContext context) {
    final tr = context.tr;
    return PulseCardShell(
      kind: InteractiveCardKind.finance,
      envelope: payload.envelope,
      priorities: payload.priorities,
      children: [
        Wrap(
          spacing: AppSpacing.s16,
          runSpacing: AppSpacing.s12,
          children: [
            _moneyTile(context, payload.cash.available, payload.cash.balance,
                tr.pulseFinanceCashBalance),
            _countTile(context, payload.receivablesOverdue,
                tr.pulseFinanceReceivablesOverdue),
            _countTile(context, payload.receivablesDueSoon,
                tr.pulseFinanceReceivablesDueSoon),
            _countTile(context, payload.payablesOverdue,
                tr.pulseFinancePayablesOverdue),
            _countTile(context, payload.payablesDueSoon,
                tr.pulseFinancePayablesDueSoon),
            _countTile(context, payload.draftVendorBills,
                tr.pulseFinanceDraftVendorBills),
            _countTile(context, payload.draftCustomerInvoices,
                tr.pulseFinanceDraftCustomerInvoices),
            _countTile(context, payload.bankReconciliation,
                tr.pulseFinanceBankReconciliation),
            if (payload.liquidityAvailable && payload.liquidityStatus != null)
              _wrap(payload.liquidityStatus!, tr.pulseFinanceLiquidityStatus,
                  null),
          ],
        ),
      ],
    );
  }

  Widget _wrap(String value, String label, Color? color) => SizedBox(
        width: AppControlSizes.pulseStatTile,
        child: StatTile(value: value, label: label, valueColor: color),
      );

  Widget _countTile(BuildContext context, PulseBucket bucket, String label) {
    final cell = pulseBucketCountCell(context, bucket);
    return _wrap(cell.value, label, cell.color);
  }

  Widget _moneyTile(
    BuildContext context,
    bool available,
    double? balance,
    String label,
  ) {
    if (!available) {
      return _wrap(context.tr.pulseUnavailable, label, context.saqqar.muted);
    }
    if (balance == null) {
      return _wrap('—', label, context.saqqar.muted);
    }
    return _wrap(compactCount(balance.round(), context.tr), label, null);
  }
}
