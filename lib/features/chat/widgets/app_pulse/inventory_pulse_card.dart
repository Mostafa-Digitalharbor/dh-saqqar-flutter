import 'package:flutter/material.dart';

import '../../../../core/format/compact_number.dart';
import '../../../../core/i18n/app_localizations.dart';
import '../../../../core/i18n/app_strings.dart';
import '../../../../shared/extensions/context_extensions.dart';
import '../../data/app_pulse_payloads.dart';
import '../../data/interactive_card_kind.dart';
import '../../data/pulse_actions.dart';
import 'pulse_bands_list.dart';
import 'pulse_card_shell.dart';
import 'pulse_helpers.dart';
import 'pulse_raw_items.dart';

/// "Your inventory" pulse — the stock that needs attention: shortages,
/// stagnant stock, overstock, missing data, and reorder signals, computed
/// from Odoo (Task 1, MOBILE_TASKS_2026-09.md).
///
/// The six buckets' `items` arrays have no documented shape, so they render
/// through [PulseRawItemsList], which summarises each row from whatever
/// fields it actually carries instead of requiring ones this client has
/// never seen. A bucket with no rows shows its tile and no list.
class InventoryPulseCard extends StatelessWidget {
  const InventoryPulseCard({
    super.key,
    required this.payload,
    this.actions = const [],
    this.deepActions = const [],
    this.onSend,
  });

  final InventoryPulsePayload payload;

  /// Web-parity action rows, built by `pulseActions` from the same payload.
  /// Empty leaves the card read-only, which is what every non-chat surface
  /// (the storybook, the conformance sweeps) wants.
  final List<PulseAction> actions;
  final List<PulseAction> deepActions;
  final ValueChanged<String>? onSend;

  @override
  Widget build(BuildContext context) {
    final tr = context.tr;
    // Local so the null check promotes — a nullable field can't.
    final missingDataReasons = payload.missingDataReasons;
    return PulseCardShell(
      kind: InteractiveCardKind.inventory,
      envelope: payload.envelope,
      actions: actions,
      deepActions: deepActions,
      onSend: onSend,
      // Chips and the tracking box go under the numbers, above the buckets
      // — the web's order, and the only place they stay reachable on a
      // phone once six bucket lists sit below them.
      toolsFirst: true,
      priorities: payload.priorities,
      stats: [
        // The web's six tiles, in its order and with its tones, then the
        // three this client shows and the web does not.
        PulseStatGrid(
          tiles: [
            pulseScalarStatTile(
                context, payload.productCount, tr.pulseInventoryProductCount),
            _totalTile(context, payload.inventoryValue, tr.pulseInventoryValue),
            pulseBucketStatTile(
                context, payload.lowStock, tr.pulseInventoryLowStock,
                tone: PulseTone.danger),
            pulseBucketStatTile(context, payload.demandShortage,
                tr.pulseInventoryDemandShortage,
                tone: PulseTone.danger),
            pulseBucketStatTile(context, payload.stagnantStock,
                tr.pulseInventoryStagnantStock,
                tone: PulseTone.warn),
            pulseBucketStatTile(
                context, payload.missingData, tr.pulseInventoryMissingData,
                tone: PulseTone.warn),
            pulseBucketStatTile(
                context, payload.overstock, tr.pulseInventoryOverstock,
                tone: PulseTone.warn),
            pulseBucketStatTile(
                context, payload.fastReorder, tr.pulseInventoryFastReorder),
            pulseScalarStatTile(
                context, payload.salesDays, tr.pulseInventorySalesDays),
          ],
        ),
      ],
      details: [
        // The rows behind the counts. A tile that says "12 low stock" and
        // nothing else leaves the user knowing there is a problem but not
        // which product has it — which is the question the app was opened
        // to answer. The item shape is undocumented, so [PulseRawItemsList]
        // reads whatever each row happens to carry.
        for (final section in _sections(tr))
          PulseRawItemsList(title: section.$1, items: section.$2.items),
        // `missing_data.counts` — WHY the data is missing, which is the part
        // that says whether this is one import to fix or a policy problem.
        if (missingDataReasons != null)
          PulseBandsList(
            title: tr.pulseInventoryMissingDataReasons,
            bands: missingDataReasons,
          ),
      ],
    );
  }

  /// The buckets that can carry rows, each paired with the label its own
  /// tile already uses — so a list is titled with the same words as the
  /// number it belongs to. `inventory_value` is left out: its rows are the
  /// whole product catalogue, a report rather than a list to scan in a card.
  List<(String, PulseBucket)> _sections(AppStrings tr) => [
        (tr.pulseInventoryLowStock, payload.lowStock),
        (tr.pulseInventoryDemandShortage, payload.demandShortage),
        (tr.pulseInventoryStagnantStock, payload.stagnantStock),
        (tr.pulseInventoryOverstock, payload.overstock),
        (tr.pulseInventoryFastReorder, payload.fastReorder),
        (tr.pulseInventoryMissingData, payload.missingData),
      ];

  /// The one tile in this card whose value isn't a plain count — it formats
  /// a currency-scale total via [compactCount], so it can't be expressed as
  /// [pulseBucketStatTile] even though it shares the same "unavailable /
  /// null / real value" tri-state as every other bucket tile here.
  Widget _totalTile(BuildContext context, PulseBucket bucket, String label) {
    if (!bucket.available) {
      return pulseStatTile(
          context.tr.pulseUnavailable, label, color: context.saqqar.muted);
    }
    final total = bucket.total;
    if (total == null) {
      return pulseStatTile('—', label, color: context.saqqar.muted);
    }
    return pulseStatTile(compactCount(total.round(), context.tr), label);
  }
}
