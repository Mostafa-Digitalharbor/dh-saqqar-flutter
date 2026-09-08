import 'package:flutter/material.dart';

import '../../../../core/i18n/app_localizations.dart';
import '../../../../core/i18n/app_strings.dart';
import '../../../../core/theme/app_sizes.dart';
import '../../../../shared/extensions/context_extensions.dart';
import '../../../../shared/widgets/stat_tile.dart';
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

/// The fixed-width [StatTile] cell every pulse card's `Wrap` of numbers is
/// built from — extracted because all seven pulse cards were each hand-
/// rolling this exact `SizedBox(width: AppControlSizes.pulseStatTile, ...)`
/// wrapper under a private `_wrap`/`_tile` helper of their own.
Widget pulseStatTile(String value, String label, {Color? color}) => SizedBox(
      width: AppControlSizes.pulseStatTile,
      child: StatTile(value: value, label: label, valueColor: color),
    );

/// [pulseStatTile] fed straight from a raw scalar via [pulseScalarCell] —
/// the common case (most tiles are just "this number, or an em dash").
Widget pulseScalarStatTile(BuildContext context, int? value, String label) {
  final cell = pulseScalarCell(context, value);
  return pulseStatTile(cell.value, label, color: cell.color);
}

/// [pulseStatTile] fed from a [PulseBucket] via [pulseBucketCountCell] —
/// the other common case, where "unavailable" is a third state distinct
/// from both a real count and a null one.
Widget pulseBucketStatTile(
  BuildContext context,
  PulseBucket bucket,
  String label,
) {
  final cell = pulseBucketCountCell(context, bucket);
  return pulseStatTile(cell.value, label, color: cell.color);
}
