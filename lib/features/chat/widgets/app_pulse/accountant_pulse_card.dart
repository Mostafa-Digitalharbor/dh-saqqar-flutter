import 'package:flutter/material.dart';

import '../../../../core/i18n/app_localizations.dart';
import '../../../../core/theme/app_sizes.dart';
import '../../../../shared/extensions/context_extensions.dart';
import '../../data/app_pulse_payloads.dart';
import '../../data/interactive_card_kind.dart';
import 'pulse_card_shell.dart';
import 'pulse_counter_list.dart';

/// "Your accounts manager" pulse — journal entries, the invoice chain, bank
/// matching, tax and month-end close, computed from Odoo (Task 1,
/// MOBILE_TASKS_2026-09.md).
class AccountantPulseCard extends StatelessWidget {
  const AccountantPulseCard({super.key, required this.payload});

  final AccountantPulsePayload payload;

  @override
  Widget build(BuildContext context) {
    final tr = context.tr;
    final month = payload.month;
    return PulseCardShell(
      kind: InteractiveCardKind.accountant,
      envelope: payload.envelope,
      children: [
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
        PulseCounterList(counters: payload.counters),
      ],
    );
  }
}
