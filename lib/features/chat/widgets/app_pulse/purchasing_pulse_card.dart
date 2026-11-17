import 'package:flutter/material.dart';

import '../../../../core/i18n/app_localizations.dart';
import '../../data/app_pulse_payloads.dart';
import '../../data/interactive_card_kind.dart';
import '../../data/pulse_actions.dart';
import 'pulse_card_shell.dart';
import 'pulse_helpers.dart';
import 'pulse_raw_items.dart';

/// "Your purchasing" pulse — purchase orders, late receipts, vendor bills
/// and risk, computed from Odoo (Task 1, MOBILE_TASKS_2026-09.md).
class PurchasingPulseCard extends StatelessWidget {
  const PurchasingPulseCard({
    super.key,
    required this.payload,
    this.actions = const [],
    this.deepActions = const [],
    this.onSend,
  });

  final PurchasingPulsePayload payload;

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
      kind: InteractiveCardKind.purchasing,
      envelope: payload.envelope,
      actions: actions,
      deepActions: deepActions,
      onSend: onSend,
      priorities: payload.priorities,
      stats: [
        // The web's tones. It merges late receipts and late POs into one
        // "Late receipts/POs" tile; this card keeps them apart — the two are
        // different phone calls — so the danger tone applies to both.
        PulseStatGrid(
          tiles: [
            pulseBucketStatTile(
              context,
              payload.openRfqs,
              tr.pulsePurchasingOpenRfqs,
              tone: PulseTone.warn,
            ),
            pulseBucketStatTile(
              context,
              payload.awaitingApproval,
              tr.pulsePurchasingAwaitingApproval,
              tone: PulseTone.warn,
            ),
            pulseBucketStatTile(
              context,
              payload.latePurchaseOrders,
              tr.pulsePurchasingLateOrders,
              tone: PulseTone.danger,
            ),
            pulseBucketStatTile(
              context,
              payload.lateIncomingReceipts,
              tr.pulsePurchasingLateReceipts,
              tone: PulseTone.danger,
            ),
            pulseBucketStatTile(
              context,
              payload.toBill,
              tr.pulsePurchasingToBill,
            ),
            pulseBucketStatTile(
              context,
              payload.vendorBills,
              tr.pulsePurchasingVendorBills,
              tone: PulseTone.warn,
            ),
          ],
        ),
      ],
      details: [
        // Which vendors, not just how many: the count alone can't start a
        // phone call. There is no vendor-delay TILE any more — the count it
        // showed was this list's own length, so the two said the same thing
        // twice under one label. Row shape is undocumented, so the generic
        // summariser reads whatever name and delay figures each row carries.
        PulseRawItemsList(
          title: tr.pulsePurchasingVendorDelays,
          items: payload.vendorDelays,
        ),
        PulseRawItemsList(
          title: tr.pulsePurchasingLateOrders,
          items: payload.latePurchaseOrders.items,
        ),
        PulseRawItemsList(
          title: tr.pulsePurchasingLateReceipts,
          items: payload.lateIncomingReceipts.items,
        ),
      ],
    );
  }
}
