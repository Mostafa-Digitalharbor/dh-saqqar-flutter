part of 'app_pulse_payloads.dart';

/// "Your accounts manager" pulse — journal entries, invoice chain, bank
/// matching, tax and month-end close, computed from Odoo.
///
/// `counters` carries the headline per check (`no_reference`,
/// `manual_on_control`, `edited_after_post`, `self_cancelling`,
/// `multi_company` — the doc's own top-level key list); [blocks] carries the
/// audit trail behind each one, keyed by the same counter key. The card
/// keeps the trail collapsed under the counter it belongs to, so the card
/// still reads as five numbers until the user asks which records earned
/// one of them.
@immutable
class AccountantPulsePayload extends Equatable {
  const AccountantPulsePayload({
    required this.envelope,
    this.month,
    this.windowDays,
    this.counters = const [],
    this.blocks = const {},
    this.checks = const {},
  });

  /// The five checks the doc names as top-level keys, in the order it names
  /// them. A server that rolls them up into `counters` sends none of these
  /// and the card falls back to that list; one that sends them as objects
  /// gets a tile per check, labelled from the string table rather than from
  /// the wire key.
  static const checkKeys = [
    'no_reference',
    'manual_on_control',
    'edited_after_post',
    'self_cancelling',
    'multi_company',
  ];

  final PulseEnvelope envelope;
  final String? month;
  final int? windowDays;
  final List<PulseCounter> counters;

  /// Only the checks the payload actually carried, keyed by wire name.
  final Map<String, PulseBucket> checks;

  /// `counter key` → its rows, raw. Undocumented row shape, so the same
  /// treatment as `vendor_delay_summary`: [PulseRawItemsList] renders
  /// whatever name and numbers a row carries.
  final Map<String, List<Object?>> blocks;

  /// The audit rows behind one counter, or empty when the server sent none.
  /// Accepts either a bare list per key or a `{items: […]}` wrapper, and
  /// falls back to the check object's own `items` when the trail arrived
  /// inside the check rather than in a separate `blocks` map.
  List<Object?> detailsFor(String key) =>
      blocks[key] ?? checks[key]?.items ?? const [];

  static Map<String, List<Object?>> _blocks(Object? raw) {
    if (raw is! Map) return const {};
    final out = <String, List<Object?>>{};
    for (final entry in raw.cast<String, dynamic>().entries) {
      final value = entry.value;
      final rows = value is List
          ? value
          : value is Map
          ? _list(value.cast<String, dynamic>()['items'])
          : const <Object?>[];
      if (rows.isNotEmpty) out[entry.key] = rows;
    }
    return out;
  }

  static AccountantPulsePayload? parse(Map<String, dynamic>? payload) {
    if (interactiveCardKind(payload) != InteractiveCardKind.accountant) {
      return null;
    }
    final month = _str(payload!['month']);
    return AccountantPulsePayload(
      envelope: PulseEnvelope.fromJson(payload),
      month: month.isEmpty ? null : month,
      windowDays: _int(payload['window_days']),
      counters: _counters(payload['counters']),
      blocks: _blocks(payload['blocks']),
      checks: {
        for (final key in checkKeys)
          if (payload.containsKey(key)) key: PulseBucket.fromJson(payload[key]),
      },
    );
  }

  @override
  List<Object?> get props => [
    envelope,
    month,
    windowDays,
    counters,
    blocks,
    checks,
  ];
}

/// "Quality Guard" pulse — numeric quality checks combined with spec-
/// substitution review, computed from standard Odoo records.
///
/// The doc lists all 16 numbers as top-level keys; the live payload nests
/// them in `quality_stats` and `spec_stats`. **Both are read** — top level
/// first, then the two stat objects — so neither a server that flattens
/// them nor one that nests them loses a tile. `quality_gate` / `spec_guard`
/// hold the case-by-case trail behind the numbers; that stays out, the same
/// way the accountant's own trail is a disclosure rather than a headline.
@immutable
class QualityGuardPulsePayload extends Equatable {
  const QualityGuardPulsePayload({
    required this.envelope,
    this.outOfSpec,
    this.failedChecks,
    this.pendingChecks,
    this.qualityAlerts,
    this.missingNumericSpecs,
    this.reviewCases,
    this.invoiceSwaps,
    this.deliverySwaps,
    this.highRiskCases,
    this.costSavingTotal,
    this.deepDiscounts,
    this.lowerCostSubstitutes,
    this.documentedSubstitutes,
    this.undocumentedSubstitutes,
    this.discountValueEstimate,
    this.standardOdooOnly,
    this.priorities = const [],
  });

  final PulseEnvelope envelope;

  // quality_stats
  final int? outOfSpec;
  final int? failedChecks;
  final int? pendingChecks;
  final int? qualityAlerts;
  final int? missingNumericSpecs;

  // spec_stats
  final int? reviewCases;
  final int? invoiceSwaps;
  final int? deliverySwaps;
  final int? highRiskCases;
  final double? costSavingTotal;
  final int? deepDiscounts;
  final int? lowerCostSubstitutes;

  /// Substitutions with a written reason on the record vs. without one —
  /// the pair the app exists to separate, so both are shown even when one
  /// of them is zero.
  final int? documentedSubstitutes;
  final int? undocumentedSubstitutes;
  final double? discountValueEstimate;

  /// The server's own note that this run used nothing but standard Odoo
  /// records — a fact about the reading, not a metric, so the card shows it
  /// as a badge rather than as a number tile.
  final bool? standardOdooOnly;

  /// Already in Arabic, same as [PulseEnvelope.notes] — see rule 4.
  final List<String> priorities;

  static QualityGuardPulsePayload? parse(Map<String, dynamic>? payload) {
    if (interactiveCardKind(payload) != InteractiveCardKind.qualityGuard) {
      return null;
    }
    final qualityStats = _map(payload!['quality_stats']);
    final specStats = _map(payload['spec_stats']);
    // Top level wins, then whichever stats object owns the key. Reading
    // both costs one lookup and covers the two shapes this payload is
    // documented and observed in.
    int? readInt(String key) =>
        _int(payload[key]) ?? _int(qualityStats[key]) ?? _int(specStats[key]);
    double? readDouble(String key) =>
        _double(payload[key]) ??
        _double(qualityStats[key]) ??
        _double(specStats[key]);
    bool? readBool(String key) {
      for (final source in [payload, qualityStats, specStats]) {
        final value = source[key];
        if (value is bool) return value;
      }
      return null;
    }

    return QualityGuardPulsePayload(
      envelope: PulseEnvelope.fromJson(payload),
      outOfSpec: readInt('out_of_spec'),
      failedChecks: readInt('failed_checks'),
      pendingChecks: readInt('pending_checks'),
      qualityAlerts: readInt('quality_alerts'),
      missingNumericSpecs: readInt('missing_numeric_specs'),
      reviewCases: readInt('review_cases'),
      invoiceSwaps: readInt('invoice_swaps'),
      deliverySwaps: readInt('delivery_swaps'),
      highRiskCases: readInt('high_risk_cases'),
      costSavingTotal: readDouble('cost_saving_total'),
      deepDiscounts: readInt('deep_discounts'),
      lowerCostSubstitutes: readInt('lower_cost_substitutes'),
      documentedSubstitutes: readInt('documented_substitutes'),
      undocumentedSubstitutes: readInt('undocumented_substitutes'),
      discountValueEstimate: readDouble('discount_value_estimate'),
      standardOdooOnly: readBool('standard_odoo_only'),
      priorities: _list(
        payload['priorities'],
      ).map(_str).where((s) => s.isNotEmpty).toList(),
    );
  }

  @override
  List<Object?> get props => [
    envelope,
    outOfSpec,
    failedChecks,
    pendingChecks,
    qualityAlerts,
    missingNumericSpecs,
    reviewCases,
    invoiceSwaps,
    deliverySwaps,
    highRiskCases,
    costSavingTotal,
    deepDiscounts,
    lowerCostSubstitutes,
    documentedSubstitutes,
    undocumentedSubstitutes,
    discountValueEstimate,
    standardOdooOnly,
    priorities,
  ];
}
