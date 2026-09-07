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

/// "Your inventory" pulse — the stock that needs attention: shortages,
/// stagnant stock, overstock, missing data, and reorder signals, computed
/// from Odoo (Task 1, MOBILE_TASKS_2026-09.md).
///
/// The six buckets' `items` arrays have no documented shape yet — the doc
/// says to read a live payload before building that part, and the bucket-
/// level `available` / `count` / `total` already carries the headline number
/// each tile exists to show, so item-level detail is deferred rather than
/// guessed at.
class InventoryPulseCard extends StatelessWidget {
  const InventoryPulseCard({super.key, required this.payload});

  final InventoryPulsePayload payload;

  @override
  Widget build(BuildContext context) {
    final tr = context.tr;
    return PulseCardShell(
      kind: InteractiveCardKind.inventory,
      envelope: payload.envelope,
      priorities: payload.priorities,
      children: [
        Wrap(
          spacing: AppSpacing.s16,
          runSpacing: AppSpacing.s12,
          children: [
            _scalarTile(context, payload.salesDays, tr.pulseInventorySalesDays),
            _scalarTile(
                context, payload.productCount, tr.pulseInventoryProductCount),
            _totalTile(
                context, payload.inventoryValue, tr.pulseInventoryValue),
            _countTile(
                context, payload.lowStock, tr.pulseInventoryLowStock),
            _countTile(context, payload.demandShortage,
                tr.pulseInventoryDemandShortage),
            _countTile(context, payload.stagnantStock,
                tr.pulseInventoryStagnantStock),
            _countTile(
                context, payload.overstock, tr.pulseInventoryOverstock),
            _countTile(
                context, payload.fastReorder, tr.pulseInventoryFastReorder),
            _countTile(
                context, payload.missingData, tr.pulseInventoryMissingData),
          ],
        ),
      ],
    );
  }

  Widget _wrap(String value, String label, Color? color) => SizedBox(
        width: AppControlSizes.pulseStatTile,
        child: StatTile(value: value, label: label, valueColor: color),
      );

  Widget _scalarTile(BuildContext context, int? value, String label) {
    final cell = pulseScalarCell(context, value);
    return _wrap(cell.value, label, cell.color);
  }

  Widget _countTile(BuildContext context, PulseBucket bucket, String label) {
    final cell = pulseBucketCountCell(context, bucket);
    return _wrap(cell.value, label, cell.color);
  }

  Widget _totalTile(BuildContext context, PulseBucket bucket, String label) {
    if (!bucket.available) {
      return _wrap(context.tr.pulseUnavailable, label, context.saqqar.muted);
    }
    final total = bucket.total;
    if (total == null) return _wrap('—', label, context.saqqar.muted);
    return _wrap(compactCount(total.round(), context.tr), label, null);
  }
}
