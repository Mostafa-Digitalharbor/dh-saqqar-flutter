import 'package:flutter/material.dart';

import '../../../../core/i18n/app_localizations.dart';
import '../../../../core/theme/app_sizes.dart';
import '../../../../shared/extensions/context_extensions.dart';
import '../../data/app_pulse_payloads.dart';
import '../../data/interactive_card_kind.dart';
import '../../data/pulse_actions.dart';
import 'pulse_card_shell.dart';
import 'pulse_counter_list.dart';
import 'pulse_helpers.dart';
import 'pulse_raw_items.dart';

/// "Your accounts manager" pulse — journal entries, the invoice chain, bank
/// matching, tax and month-end close, computed from Odoo (Task 1,
/// MOBILE_TASKS_2026-09.md).
class AccountantPulseCard extends StatelessWidget {
  const AccountantPulseCard({
    super.key,
    required this.payload,
    this.actions = const [],
    this.deepActions = const [],
    this.onSend,
  });

  final AccountantPulsePayload payload;

  /// Web-parity action rows, built by `pulseActions` from the same payload.
  /// Empty leaves the card read-only, which is what every non-chat surface
  /// (the storybook, the conformance sweeps) wants.
  final List<PulseAction> actions;
  final List<PulseAction> deepActions;
  final ValueChanged<String>? onSend;

  @override
  Widget build(BuildContext context) {
    final tr = context.tr;
    final month = payload.month;
    return PulseCardShell(
      kind: InteractiveCardKind.accountant,
      envelope: payload.envelope,
      actions: actions,
      deepActions: deepActions,
      onSend: onSend,
      stats: [
        if (month != null)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.s8),
            child: Text(
              tr.pulseAccountantMonth(month),
              style: context.text.labelSmall?.copyWith(
                color: context.saqqar.muted,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        // The five documented checks, when the server sends them as their
        // own keys. A server that rolls them into `counters` instead sends
        // none of these and the list below carries the card on its own.
        if (payload.checks.isNotEmpty)
          PulseStatGrid(
            tiles: [
              for (final key in AccountantPulsePayload.checkKeys)
                if (payload.checks[key] case final bucket?)
                  pulseBucketStatTile(
                      context, bucket, tr.pulseAccountantCheck(key)),
            ],
          ),
      ],
      details: [
        PulseCounterList(
          counters: payload.counters,
          detailsFor: payload.detailsFor,
        ),
        // The audit trail behind each check, when it arrived keyed by check
        // rather than by counter — same rows, one level up.
        if (payload.counters.isEmpty)
          for (final key in AccountantPulsePayload.checkKeys)
            PulseRawItemsList(
              title: tr.pulseAccountantCheck(key),
              items: payload.detailsFor(key),
            ),
      ],
    );
  }
}
