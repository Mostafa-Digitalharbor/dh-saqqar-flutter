import 'package:flutter/material.dart';

import '../../../../core/i18n/app_localizations.dart';
import '../../data/app_pulse_payloads.dart';
import '../../data/interactive_card_kind.dart';
import '../../data/pulse_actions.dart';
import 'pulse_card_shell.dart';
import 'pulse_helpers.dart';

/// "Your factory" pulse — production status, missing material, and a
/// delivery date, computed from Odoo (Task 1, MOBILE_TASKS_2026-09.md).
///
/// `top_risks` is rendered ONCE, by the action rows: order, customer, the
/// waiting cause, and the two buttons that act on it. There used to be a
/// ranked list of the same orders above them as well, which meant four
/// at-risk orders filled the card with twelve blocks — the list, then a row
/// per button. The web prints one `.fc-risk` per order and so does this.
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
        // The web's four tiles, in the web's order and with the web's tones,
        // then the one this client shows and the web does not.
        PulseStatGrid(
          tiles: [
            pulseScalarStatTile(
              context,
              payload.moRunning,
              tr.pulseFactoryMoRunning,
            ),
            pulseScalarStatTile(
              context,
              payload.moLate,
              tr.pulseFactoryMoLate,
              tone: PulseTone.warn,
            ),
            pulseScalarStatTile(
              context,
              payload.poLate,
              tr.pulseFactoryPoLate,
              tone: PulseTone.warn,
            ),
            pulseScalarStatTile(
              context,
              payload.ordersAtRisk,
              tr.pulseFactoryOrdersAtRisk,
              tone: PulseTone.danger,
            ),
            pulseScalarStatTile(
              context,
              payload.moDoneToday,
              tr.pulseFactoryMoDoneToday,
            ),
          ],
        ),
      ],
    );
  }
}
