import 'package:flutter/material.dart';

import '../../../../core/i18n/app_localizations.dart';
import '../../../../core/i18n/app_strings.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_sizes.dart';
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

/// What a tile's number means when it is not zero.
///
/// The web colours these (`.fc-stat--warn` amber, `.fc-stat--danger` red) and
/// the tone is a property of the measurement, not of the reading: "orders at
/// risk" is red whenever it is anything, "MOs running" is never coloured
/// however large it gets. Zero, an em dash and "unavailable" stay neutral in
/// every case — a tone is a warning about a number that exists.
enum PulseTone { none, warn, danger }

Color? _toneColor(BuildContext context, PulseTone tone) => switch (tone) {
      PulseTone.none => null,
      PulseTone.warn => context.saqqar.warning,
      PulseTone.danger => context.saqqar.danger,
    };

/// One boxed metric in a pulse card — the web's `.fc-stat`: a hairline box
/// with the number over its label, both aligned to the reading edge.
///
/// It used to be a bare centred [StatTile] on a transparent background, and
/// side by side with the web the difference was the first thing the team
/// pointed at. The box is what separates one number from the next when six
/// of them wrap across three rows.
class PulseStatTile extends StatelessWidget {
  const PulseStatTile({
    super.key,
    required this.value,
    required this.label,
    this.color,
  });

  /// Pre-formatted — an em dash and the localized "unavailable" arrive here
  /// as strings like any other value.
  final String value;

  final String label;

  /// Overrides the value colour: muted for the two absent states, a tone for
  /// a number that is a warning. Null keeps the body colour.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final s = context.saqqar;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s10,
        vertical: AppSpacing.s8,
      ),
      decoration: BoxDecoration(
        color: s.surface2.withValues(alpha: AppAlphas.a06),
        borderRadius: AppRadius.smallR,
        border: Border.all(color: s.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Scales down rather than clipping: a currency total compacted to
          // "1.2M" is short, but "1,215,654" is not, and both land here.
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: AlignmentDirectional.centerStart,
            child: Text(
              value,
              maxLines: 1,
              style: context.text.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
                height: AppLineHeights.displayTight,
                color: color,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.s2),
          Text(
            label,
            // Three, not two: the labels are the web's now, and «استلام/شراء
            // متأخر» does not fit a phone column in two.
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: context.text.labelSmall?.copyWith(
              color: s.muted,
              height: AppLineHeights.headingLoose,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

/// The row of boxed metrics at the top of a pulse card — the web's
/// `.fc-stats`, which is `repeat(auto-fit, minmax(124px, 1fr))`.
///
/// That CSS says three things a plain [Wrap] of tiles cannot: take as many
/// columns as clear the minimum, share the row out evenly between them, and
/// give every box in a row the same height. All three are why the web's row
/// reads as a row; without the last one, a tile whose label wraps to two
/// lines hangs lower than its neighbours and the boxes stop looking like a
/// set — which is exactly what a side-by-side comparison picked up.
///
/// Hence explicit rows rather than a [Wrap]: only a [Row] can stretch its
/// children to a shared height.
class PulseStatGrid extends StatelessWidget {
  const PulseStatGrid({super.key, required this.tiles});

  final List<Widget> tiles;

  /// Between columns and between rows — the web's `gap: 8px`.
  static const _gap = AppSpacing.s8;

  @override
  Widget build(BuildContext context) {
    if (tiles.isEmpty) return const SizedBox.shrink();
    return LayoutBuilder(
      builder: (context, constraints) {
        final available = constraints.maxWidth;
        // An unbounded parent (a measuring pass, an intrinsic-width probe)
        // has no row to divide. Fall back to a wrap of floor-width tiles:
        // no stretching, but nothing to stretch them against either.
        if (!available.isFinite) {
          return Wrap(
            spacing: _gap,
            runSpacing: _gap,
            children: [
              for (final tile in tiles)
                SizedBox(
                  width: AppControlSizes.pulseStatTileMin,
                  child: tile,
                ),
            ],
          );
        }
        // How many tiles of at least the floor width fit, counting the gaps
        // between them. At least one, however narrow the phone.
        final columns =
            ((available + _gap) / (AppControlSizes.pulseStatTileMin + _gap))
                .floor()
                .clamp(1, 6);
        final width = (available - _gap * (columns - 1)) / columns;
        return Column(
          children: [
            for (var start = 0; start < tiles.length; start += columns) ...[
              if (start > 0) const SizedBox(height: _gap),
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var column = 0; column < columns; column++) ...[
                      if (column > 0) const SizedBox(width: _gap),
                      SizedBox(
                        width: width,
                        // The last row can be short. Its empty cells still
                        // take their column so the tiles before them stay
                        // under the ones above.
                        child: start + column < tiles.length
                            ? tiles[start + column]
                            : null,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

/// A [PulseStatTile] with the sizing left to [PulseStatGrid].
Widget pulseStatTile(String value, String label, {Color? color}) =>
    PulseStatTile(value: value, label: label, color: color);

/// [pulseStatTile] fed straight from a raw scalar via [pulseScalarCell] —
/// the common case (most tiles are just "this number, or an em dash").
Widget pulseScalarStatTile(
  BuildContext context,
  int? value,
  String label, {
  PulseTone tone = PulseTone.none,
}) {
  final cell = pulseScalarCell(context, value);
  return pulseStatTile(
    cell.value,
    label,
    color: cell.color ?? _numberTone(context, value, tone),
  );
}

/// [pulseStatTile] fed from a [PulseBucket] via [pulseBucketCountCell] —
/// the other common case, where "unavailable" is a third state distinct
/// from both a real count and a null one.
Widget pulseBucketStatTile(
  BuildContext context,
  PulseBucket bucket,
  String label, {
  PulseTone tone = PulseTone.none,
}) {
  final cell = pulseBucketCountCell(context, bucket);
  return pulseStatTile(
    cell.value,
    label,
    color: cell.color ?? _numberTone(context, bucket.count, tone),
  );
}

/// The tone, but only for a real non-zero reading — `tp.mo_late ? "warn" :
/// ""` on the web. A zero is good news and is not painted amber.
Color? _numberTone(BuildContext context, num? value, PulseTone tone) =>
    value == null || value == 0 ? null : _toneColor(context, tone);
