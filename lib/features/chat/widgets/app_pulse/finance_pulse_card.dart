import 'package:flutter/material.dart';

import '../../../../core/format/compact_number.dart';
import '../../../../core/i18n/app_localizations.dart';
import '../../../../shared/extensions/context_extensions.dart';
import '../../data/app_pulse_payloads.dart';
import '../../data/interactive_card_kind.dart';
import '../../data/pulse_actions.dart';
import 'pulse_bands_list.dart';
import 'pulse_card_shell.dart';
import 'pulse_helpers.dart';

/// "Your money" pulse — collect, pay, reconcile and close the day straight
/// from Odoo financial data (Task 1, MOBILE_TASKS_2026-09.md).
class FinancePulseCard extends StatelessWidget {
  const FinancePulseCard({
    super.key,
    required this.payload,
    this.actions = const [],
    this.deepActions = const [],
    this.onSend,
  });

  final FinancePulsePayload payload;

  /// Web-parity action rows, built by `pulseActions` from the same payload.
  /// Empty leaves the card read-only, which is what every non-chat surface
  /// (the storybook, the conformance sweeps) wants.
  final List<PulseAction> actions;
  final List<PulseAction> deepActions;
  final ValueChanged<String>? onSend;

  @override
  Widget build(BuildContext context) {
    final tr = context.tr;
    // Locals so the null check promotes — a nullable field can't.
    final collectionAging = payload.collectionAging;
    final paymentHorizon = payload.paymentHorizon;
    return PulseCardShell(
      kind: InteractiveCardKind.finance,
      envelope: payload.envelope,
      actions: actions,
      deepActions: deepActions,
      onSend: onSend,
      priorities: payload.priorities,
      stats: [
        PulseStatGrid(
          tiles: [
            // Overdue money is red on the web ("تحصيل متأخر"), money merely
            // coming due is amber ("سداد 7 أيام"). This card splits both
            // sides into overdue and due-soon rather than netting them, so
            // each half takes the tone the web gives its own reading.
            _moneyTile(
              context,
              payload.cash.available,
              payload.cash.balance,
              tr.pulseFinanceCashBalance,
            ),
            pulseBucketStatTile(
              context,
              payload.receivablesOverdue,
              tr.pulseFinanceReceivablesOverdue,
              tone: PulseTone.danger,
            ),
            pulseBucketStatTile(
              context,
              payload.receivablesDueSoon,
              tr.pulseFinanceReceivablesDueSoon,
              tone: PulseTone.warn,
            ),
            pulseBucketStatTile(
              context,
              payload.payablesOverdue,
              tr.pulseFinancePayablesOverdue,
              tone: PulseTone.danger,
            ),
            pulseBucketStatTile(
              context,
              payload.payablesDueSoon,
              tr.pulseFinancePayablesDueSoon,
              tone: PulseTone.warn,
            ),
            pulseBucketStatTile(
              context,
              payload.draftVendorBills,
              tr.pulseFinanceDraftVendorBills,
            ),
            pulseBucketStatTile(
              context,
              payload.draftCustomerInvoices,
              tr.pulseFinanceDraftCustomerInvoices,
            ),
            pulseBucketStatTile(
              context,
              payload.bankReconciliation,
              tr.pulseFinanceBankReconciliation,
            ),
            if (payload.liquidityAvailable && payload.liquidityStatus != null)
              pulseStatTile(
                payload.liquidityStatus!,
                tr.pulseFinanceLiquidityStatus,
              ),
          ],
        ),
        // The day-band breakdown behind the receivable/payable tiles: which
        // of the overdue money is a week late and which is a quarter late is
        // a different decision from how much of it there is.
        if (collectionAging != null)
          PulseBandsList(
            title: tr.pulseFinanceCollectionAging,
            bands: collectionAging,
          ),
        if (paymentHorizon != null)
          PulseBandsList(
            title: tr.pulseFinancePaymentHorizon,
            bands: paymentHorizon,
          ),
      ],
    );
  }

  /// Formats a currency-scale balance via [compactCount] — the one tile
  /// here that isn't a plain bucket count, so it can't route through
  /// [pulseBucketStatTile] even though it shares the same tri-state.
  Widget _moneyTile(
    BuildContext context,
    bool available,
    double? balance,
    String label,
  ) {
    if (!available) {
      return pulseStatTile(
        context.tr.pulseUnavailable,
        label,
        color: context.saqqar.muted,
      );
    }
    if (balance == null) {
      return pulseStatTile('—', label, color: context.saqqar.muted);
    }
    return pulseStatTile(compactCount(balance.round(), context.tr), label);
  }
}
