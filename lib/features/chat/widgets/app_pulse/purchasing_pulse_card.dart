import 'package:flutter/material.dart';

import '../../../../core/i18n/app_localizations.dart';
import '../../../../core/theme/app_sizes.dart';
import '../../../../shared/widgets/stat_tile.dart';
import '../../data/app_pulse_payloads.dart';
import '../../data/interactive_card_kind.dart';
import 'pulse_card_shell.dart';
import 'pulse_helpers.dart';

/// "Your purchasing" pulse — purchase orders, late receipts, vendor bills
/// and risk, computed from Odoo (Task 1, MOBILE_TASKS_2026-09.md).
class PurchasingPulseCard extends StatelessWidget {
  const PurchasingPulseCard({super.key, required this.payload});

  final PurchasingPulsePayload payload;

  @override
  Widget build(BuildContext context) {
    final tr = context.tr;
    return PulseCardShell(
      kind: InteractiveCardKind.purchasing,
      envelope: payload.envelope,
      priorities: payload.priorities,
      children: [
        Wrap(
          spacing: AppSpacing.s16,
          runSpacing: AppSpacing.s12,
          children: [
            _countTile(context, payload.openRfqs, tr.pulsePurchasingOpenRfqs),
            _countTile(context, payload.awaitingApproval,
                tr.pulsePurchasingAwaitingApproval),
            _countTile(context, payload.latePurchaseOrders,
                tr.pulsePurchasingLateOrders),
            _countTile(context, payload.lateIncomingReceipts,
                tr.pulsePurchasingLateReceipts),
            _countTile(context, payload.toBill, tr.pulsePurchasingToBill),
            _countTile(
                context, payload.vendorBills, tr.pulsePurchasingVendorBills),
            if (payload.vendorDelayCount > 0)
              _wrap('${payload.vendorDelayCount}',
                  tr.pulsePurchasingVendorDelays, null),
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
}
