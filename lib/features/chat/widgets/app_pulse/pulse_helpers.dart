import 'package:flutter/material.dart';

import '../../../../core/i18n/app_localizations.dart';
import '../../../../core/i18n/app_strings.dart';
import '../../../../shared/extensions/context_extensions.dart';
import '../../data/app_pulse_payloads.dart';
import '../../data/interactive_card_kind.dart';

/// The `app_name_<key>` lookup Task 3 already built for the Apps gallery,
/// reused here so a pulse card's title is the exact same word the user
/// tapped to launch it — one translation, two surfaces, instead of a second
/// title string per kind that could drift from the first.
String pulseAppTitle(AppStrings tr, InteractiveCardKind kind) {
  final key = switch (kind) {
    InteractiveCardKind.factory => 'factory',
    InteractiveCardKind.inventory => 'smart_inventory',
    InteractiveCardKind.finance => 'finance_pulse',
    InteractiveCardKind.purchasing => 'purchase_pulse',
    InteractiveCardKind.qualityGuard => 'quality_guard',
    InteractiveCardKind.accountant => 'accountant',
    InteractiveCardKind.hr => 'hr_assistant',
    InteractiveCardKind.promptClarify ||
    InteractiveCardKind.reportBuilder ||
    InteractiveCardKind.promptSuggestion =>
      '',
  };
  return tr.lookup('app_name_$key', fallback: kind.wire);
}

/// One tile's display value + colour — the tri-state every scalar and every
/// bucket count needs (MOBILE_TASKS_2026-09.md Task 1, rules 1 & 2):
///  * a real number renders as itself;
///  * `null` (an Odoo app isn't installed) renders as an em dash, never `0`
///    — the card's notes explain why, this cell just doesn't lie;
///  * `available: false` (the database can't answer) renders the localized
///    "Unavailable", greyed, which is a different message than either.
typedef PulseCell = ({String value, Color? color});

PulseCell pulseScalarCell(BuildContext context, int? value) {
  if (value == null) {
    return (value: '—', color: context.saqqar.muted);
  }
  return (value: '$value', color: null);
}

PulseCell pulseBucketCountCell(BuildContext context, PulseBucket bucket) {
  if (!bucket.available) {
    return (value: context.tr.pulseUnavailable, color: context.saqqar.muted);
  }
  return pulseScalarCell(context, bucket.count);
}
