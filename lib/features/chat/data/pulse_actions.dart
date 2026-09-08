import 'package:flutter/foundation.dart';

import '../../../core/i18n/app_strings.dart';
import 'interactive_card_kind.dart';

/// The action rows an app-pulse card offers — "Customer collection · 13
/// overdue invoices · [Start collection]".
///
/// **Why this exists.** The cards used to render as read-only dashboards on
/// mobile while the web rendered the same payload as a set of rows, each
/// ending in a button that sends a prompt and puts the agent to work. A user
/// on the phone could read that 13 invoices were overdue and had no way to
/// act on it without retyping the request; the team reported exactly that
/// ("مافيش زراير ومافيش اكشن").
///
/// **Where the copy comes from.** The buttons are NOT in the payload — the
/// web builds them client-side from the same `tool_payload` this client
/// already parses, so the wording, the conditions that decide which rows
/// appear, and above all the prompt each button sends are ported from the
/// web's own card builders (`buildFinanceCard`, `buildFactoryCard`, …). The
/// prompt is the contract: it is what the agent receives, so it is matched
/// word for word rather than paraphrased. Copy lives in `app_strings.dart`
/// under `pulse_act_*` keys and is resolved with [AppStrings.format].
///
/// Numbers are formatted the way the web formats them (`formatPulseNumber`:
/// grouped thousands, at most two decimals, an em dash for null) so a row
/// reads identically on both surfaces.
@immutable
class PulseAction {
  const PulseAction({
    required this.title,
    required this.main,
    required this.label,
    required this.prompt,
    this.cause = '',
    this.primary = false,
  });

  /// Row heading — "Customer collection".
  final String title;

  /// The one-line reading under it — "13 invoice(s): 1-30 …".
  final String main;

  /// Optional second line naming the biggest contributor. Empty when the
  /// payload carried no item to name.
  final String cause;

  /// Button label — "Start collection".
  final String label;

  /// What the button sends to the agent, in the UI language. Verbatim from
  /// the web so the same tap produces the same run on both clients.
  final String prompt;

  /// The first actionable row gets the filled button; the rest are ghosts.
  final bool primary;

  @override
  bool operator ==(Object other) =>
      other is PulseAction &&
      other.title == title &&
      other.main == main &&
      other.cause == cause &&
      other.label == label &&
      other.prompt == prompt &&
      other.primary == primary;

  @override
  int get hashCode => Object.hash(title, main, cause, label, prompt, primary);
}

// ─────────────────────────────────────────────────────────────────────────
// Payload readers — ported from the web's helpers of the same name
// ─────────────────────────────────────────────────────────────────────────

Map<String, dynamic> _map(Object? raw) =>
    raw is Map ? raw.cast<String, dynamic>() : const <String, dynamic>{};

List<Object?> _list(Object? raw) => raw is List ? raw : const [];

/// `bucketCount` — null when the bucket says it can't answer, else its count
/// (a missing count reads as 0, matching the web's `Number(x) || 0`).
int? _count(Object? bucket) {
  final b = _map(bucket);
  if (b.isEmpty || b['available'] == false) return null;
  final n = b['count'];
  if (n is num) return n.toInt();
  if (n is String) return int.tryParse(n.trim()) ?? 0;
  return 0;
}

/// `bucketTotal` — null when unavailable or absent.
num? _total(Object? bucket) {
  final b = _map(bucket);
  if (b.isEmpty || b['available'] == false) return null;
  final t = b['total'];
  if (t is num) return t;
  if (t is String) return num.tryParse(t.trim());
  return null;
}

/// `firstItem` — the first row of a bucket's `items`, or an empty map.
Map<String, dynamic> _first(Object? bucket) {
  final items = _list(_map(bucket)['items']);
  for (final item in items) {
    if (item is Map) return item.cast<String, dynamic>();
  }
  return const {};
}

String _str(Object? value) {
  if (value is String) return value;
  if (value is num || value is bool) return '$value';
  return '';
}

num? _num(Object? value) {
  if (value is num) return value;
  if (value is String) return num.tryParse(value.trim());
  return null;
}

int _int(Object? value) => _num(value)?.toInt() ?? 0;

/// `formatPulseNumber` — `Intl.NumberFormat("en-US", {maximumFractionDigits:
/// 2})`, and an em dash for a value the server didn't send. Western digits
/// in both locales, matching both the web and this app's own numerics.
String formatPulseNumber(Object? value) {
  if (value == null || value == '') return '—';
  final n = _num(value);
  if (n == null) return '$value';
  final rounded = (n * 100).round() / 100;
  final negative = rounded < 0;
  final abs = negative ? -rounded : rounded;
  final whole = abs.truncate();
  final fraction = abs - whole;
  final digits = whole.toString();
  final grouped = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) grouped.write(',');
    grouped.write(digits[i]);
  }
  var out = grouped.toString();
  if (fraction > 0) {
    // Two decimals at most, trailing zeros dropped — "1,234.5", not
    // "1,234.50", which is what Intl does with maximumFractionDigits.
    var frac = fraction.toStringAsFixed(2).substring(2);
    while (frac.endsWith('0')) {
      frac = frac.substring(0, frac.length - 1);
    }
    if (frac.isNotEmpty) out = '$out.$frac';
  }
  return negative ? '-$out' : out;
}

/// The actions for one pulse card, in the order the web renders them.
///
/// Returns empty for a payload with nothing to act on — the card then shows
/// its numbers and no button row, exactly like the web's empty state.
List<PulseAction> pulseActions(
  InteractiveCardKind kind,
  Map<String, dynamic>? payload,
  AppStrings tr,
) {
  if (payload == null) return const [];
  return switch (kind) {
    InteractiveCardKind.factory => _factory(payload, tr),
    InteractiveCardKind.finance => _finance(payload, tr),
    InteractiveCardKind.purchasing => _purchasing(payload, tr),
    InteractiveCardKind.inventory => _inventory(payload, tr),
    InteractiveCardKind.qualityGuard => _qualityGuard(payload, tr),
    InteractiveCardKind.accountant => _counterDriven(payload, tr, 'accountant'),
    InteractiveCardKind.hr => _counterDriven(payload, tr, 'hr'),
    InteractiveCardKind.promptClarify ||
    InteractiveCardKind.reportBuilder ||
    InteractiveCardKind.promptSuggestion =>
      const [],
  };
}

String _k(String kind, String row, String part) =>
    'pulse_act_${kind}_${row}_$part';

// ── factory ──────────────────────────────────────────────────────────────
//
// Two buttons per at-risk order, both continuing the conversation rather
// than acting: the agent reads the order, and any document it then wants to
// write still goes through the approval card.
List<PulseAction> _factory(Map<String, dynamic> payload, AppStrings tr) {
  final out = <PulseAction>[];
  for (final raw in _list(payload['top_risks'])) {
    if (raw is! Map) continue;
    final risk = raw.cast<String, dynamic>();
    final order = _str(risk['order']);
    if (order.isEmpty) continue;
    final vars = {
      'order': order,
      'days': formatPulseNumber(risk['lead_days']),
      'product': _str(risk['worst_product']),
    };
    final title = order;
    final main = _str(risk['customer']);
    final cause = tr.format(_k('factory', 'risk', 'cause'), vars);
    out.add(PulseAction(
      title: title,
      main: main,
      cause: cause,
      label: tr.lookup(_k('factory', 'promise', 'label')),
      prompt: tr.format(_k('factory', 'promise', 'prompt'), vars),
    ));
    out.add(PulseAction(
      title: title,
      main: main,
      cause: cause,
      label: tr.lookup(_k('factory', 'cover', 'label')),
      prompt: tr.format(_k('factory', 'cover', 'prompt'), vars),
      primary: true,
    ));
  }
  return out;
}

// ── finance ──────────────────────────────────────────────────────────────
List<PulseAction> _finance(Map<String, dynamic> payload, AppStrings tr) {
  final rows = <PulseAction>[];
  var hasPrimary = false;
  PulseAction row(
    String key, {
    required String main,
    String cause = '',
    Map<String, Object?> labelVars = const {},
  }) {
    final primary = !hasPrimary;
    hasPrimary = true;
    return PulseAction(
      title: tr.lookup(_k('finance', key, 'title')),
      main: main,
      cause: cause,
      label: tr.format(_k('finance', key, 'label'), labelVars),
      prompt: tr.lookup(_k('finance', key, 'prompt')),
      primary: primary,
    );
  }

  final receivables = _map(payload['receivables']);
  final payables = _map(payload['payables']);
  final drafts = _map(payload['drafts']);
  final aging = _map(payload['collection_aging']);
  final horizon = _map(payload['payment_horizon']);
  final liquidity = _map(payload['liquidity_7d']);
  final bank = payload['bank_reconciliation'];
  final overdueCustomers = receivables['overdue'];
  final dueVendors = payables['due_soon'];
  final overdueVendors = payables['overdue'];

  final hasAging = aging['available'] == true;
  final hasHorizon = horizon['available'] == true;
  final agingBuckets = [
    aging['days_1_30'],
    aging['days_31_60'],
    aging['days_61_plus'],
  ];
  final agingOverdueCount = hasAging
      ? agingBuckets.fold<int>(0, (sum, b) => sum + (_count(b) ?? 0))
      : (_count(overdueCustomers) ?? 0);
  final agingOverdueTotal =
      hasAging ? _num(aging['total_overdue']) : _total(overdueCustomers);
  final paymentBuckets7 = [
    horizon['overdue'],
    horizon['due_today'],
    horizon['days_1_7'],
  ];
  final vendorDueCount = hasHorizon
      ? paymentBuckets7.fold<int>(0, (sum, b) => sum + (_count(b) ?? 0))
      : (_count(dueVendors) ?? 0) + (_count(overdueVendors) ?? 0);
  final vendorDueTotal = hasHorizon
      ? _num(horizon['total_due_7d'])
      : (_total(dueVendors) ?? 0) + (_total(overdueVendors) ?? 0);
  final cashGap = _num(liquidity['cash_gap']);
  final hasLiquidity = liquidity['available'] == true && cashGap != null;

  if (hasLiquidity && cashGap < 0) {
    rows.add(row(
      'gap',
      main: tr.format(_k('finance', 'gap', 'main'),
          {'amount': formatPulseNumber(cashGap.abs())}),
      cause: tr.format(_k('finance', 'gap', 'cause'),
          {'after': formatPulseNumber(liquidity['after_collection_gap'])}),
    ));
  }

  final topCustomer = _first(overdueCustomers);
  if (agingOverdueCount != 0 || (agingOverdueTotal ?? 0) != 0) {
    final main = hasAging
        ? tr.format(_k('finance', 'collect', 'main_aging'), {
            'n': agingOverdueCount,
            'b1': formatPulseNumber(_total(aging['days_1_30'])),
            'b2': formatPulseNumber(_total(aging['days_31_60'])),
            'b3': formatPulseNumber(_total(aging['days_61_plus'])),
          })
        : tr.format(_k('finance', 'collect', 'main_plain'), {
            'n': agingOverdueCount,
            'total': formatPulseNumber(agingOverdueTotal),
          });
    rows.add(row(
      'collect',
      main: main,
      cause: _str(topCustomer['partner']).isEmpty
          ? ''
          : tr.format(_k('finance', 'collect', 'cause'), {
              'name': _str(topCustomer['name']).isEmpty
                  ? tr.lookup('pulse_act_no_number')
                  : _str(topCustomer['name']),
              'partner': _str(topCustomer['partner']),
              'amount': formatPulseNumber(topCustomer['amount']),
            }),
    ));
  }

  final topVendor = _first(
      (_count(overdueVendors) ?? 0) != 0 ? overdueVendors : dueVendors);
  if (vendorDueCount != 0 ||
      (vendorDueTotal ?? 0) != 0 ||
      (hasHorizon && _int(horizon['total_due_30d']) != 0)) {
    rows.add(row(
      'pay',
      main: hasHorizon
          ? tr.format(_k('finance', 'pay', 'main_horizon'), {
              'week': formatPulseNumber(horizon['total_due_7d']),
              'month': formatPulseNumber(horizon['total_due_30d']),
            })
          : tr.format(_k('finance', 'pay', 'main_plain'), {
              'n': vendorDueCount,
              'total': formatPulseNumber(vendorDueTotal),
            }),
      // The horizon breakdown wins when the server sent one; the biggest
      // single bill is the fallback — same precedence as the web's
      // `horizonCause || (topVendor.partner ? … : "")`.
      cause: hasHorizon
          ? tr.format(_k('finance', 'pay', 'cause_horizon'), {
              'late': formatPulseNumber(_total(horizon['overdue'])),
              'today': formatPulseNumber(_total(horizon['due_today'])),
              'week': formatPulseNumber(_total(horizon['days_1_7'])),
            })
          : (_str(topVendor['partner']).isEmpty
              ? ''
              : tr.format(_k('finance', 'pay', 'cause_vendor'), {
                  'partner': _str(topVendor['partner']),
                  'amount': formatPulseNumber(topVendor['amount']),
                })),
    ));
  }

  final bankCount = _count(bank);
  if (bankCount != null && bankCount != 0) {
    rows.add(row(
      'bank',
      main: tr.format(_k('finance', 'bank', 'main'), {'n': bankCount}),
      cause: (_total(bank) ?? 0) == 0
          ? ''
          : tr.format(_k('finance', 'bank', 'cause'),
              {'total': formatPulseNumber(_total(bank))}),
    ));
  }

  final customerDrafts = _count(drafts['customer_invoices']) ?? 0;
  final vendorDrafts = _count(drafts['vendor_bills']) ?? 0;
  if (customerDrafts != 0 || vendorDrafts != 0) {
    rows.add(row(
      'drafts',
      main: tr.format(_k('finance', 'drafts', 'main'),
          {'customer': customerDrafts, 'vendor': vendorDrafts}),
    ));
  }
  return rows;
}

// ── purchasing ───────────────────────────────────────────────────────────
List<PulseAction> _purchasing(Map<String, dynamic> payload, AppStrings tr) {
  final rows = <PulseAction>[];
  final rfqs = payload['open_rfqs'];
  final approval = payload['awaiting_approval'];
  final latePo = payload['late_purchase_orders'];
  final lateReceipts = payload['late_incoming_receipts'];
  final toBill = payload['to_bill'];
  final bills = _map(payload['vendor_bills']);
  final billsSoon = bills['due_soon'];
  final billsOverdue = bills['overdue'];
  final billsDraft = bills['drafts'];

  PulseAction row(String key,
          {required String main, String cause = '', bool primary = false}) =>
      PulseAction(
        title: tr.lookup(_k('purchasing', key, 'title')),
        main: main,
        cause: cause,
        label: tr.lookup(_k('purchasing', key, 'label')),
        prompt: tr.lookup(_k('purchasing', key, 'prompt')),
        primary: primary,
      );

  final lateTotal = (_count(latePo) ?? 0) + (_count(lateReceipts) ?? 0);
  if (lateTotal != 0) {
    final lateFirst = _str(_first(lateReceipts)['name']).isNotEmpty
        ? _first(lateReceipts)
        : _first(latePo);
    rows.add(row(
      'late',
      main: tr.format(_k('purchasing', 'late', 'main'), {
        'receipts': _count(lateReceipts) ?? 0,
        'orders': _count(latePo) ?? 0,
      }),
      cause: _str(lateFirst['vendor']).isEmpty
          ? ''
          : tr.format(_k('purchasing', 'late', 'cause'), {
              'name': [_str(lateFirst['name']), _str(lateFirst['origin'])]
                      .firstWhere((s) => s.isNotEmpty,
                          orElse: () => tr.lookup('pulse_act_no_number')),
              'vendor': _str(lateFirst['vendor']),
            }),
      primary: true,
    ));
  }

  if ((_count(approval) ?? 0) != 0) {
    final first = _first(approval);
    rows.add(row(
      'approval',
      main: tr.format(_k('purchasing', 'approval', 'main'), {
        'n': _count(approval),
        'total': formatPulseNumber(_total(approval)),
      }),
      cause: _str(first['vendor']).isEmpty
          ? ''
          : '${_str(first['name'])} / ${_str(first['vendor'])} / '
              '${formatPulseNumber(first['amount'])}',
    ));
  }

  if ((_count(rfqs) ?? 0) != 0) {
    final first = _first(rfqs);
    rows.add(row(
      'rfq',
      main: tr.format(_k('purchasing', 'rfq', 'main'),
          {'n': _count(rfqs), 'total': formatPulseNumber(_total(rfqs))}),
      cause: _str(first['vendor']).isEmpty
          ? ''
          : '${_str(first['name'])} / ${_str(first['vendor'])} / '
              '${formatPulseNumber(first['amount'])}',
    ));
  }

  if ((_count(toBill) ?? 0) != 0) {
    rows.add(row(
      'bill',
      main: tr.format(_k('purchasing', 'bill', 'main'), {'n': _count(toBill)}),
      cause: tr.lookup(_k('purchasing', 'bill', 'cause')),
    ));
  }

  final overdueBills = _count(billsOverdue) ?? 0;
  final soonBills = _count(billsSoon) ?? 0;
  final draftBills = _count(billsDraft) ?? 0;
  if (overdueBills != 0 || soonBills != 0 || draftBills != 0) {
    final vendorBillTotal = (_total(billsSoon) ?? 0) + (_total(billsOverdue) ?? 0);
    rows.add(row(
      'bills',
      main: tr.format(_k('purchasing', 'bills', 'main'), {
        'overdue': overdueBills,
        'soon': soonBills,
        'draft': draftBills,
      }),
      cause: vendorBillTotal == 0
          ? ''
          : tr.format(_k('purchasing', 'bills', 'cause'),
              {'total': formatPulseNumber(vendorBillTotal)}),
    ));
  }
  return rows;
}

// ── inventory ────────────────────────────────────────────────────────────
List<PulseAction> _inventory(Map<String, dynamic> payload, AppStrings tr) {
  final rows = <PulseAction>[];

  /// `firstProductLine` — "[CODE] Name / on hand 4 / forecast 9".
  String productLine(Map<String, dynamic> item) {
    final name = _str(item['name']);
    if (name.isEmpty) return '';
    final code = _str(item['code']).isEmpty ? '' : '[${_str(item['code'])}] ';
    final onHand = item['qty_available'] == null
        ? ''
        : tr.format('pulse_act_inventory_on_hand',
            {'qty': formatPulseNumber(item['qty_available'])});
    final forecast = item['virtual_available'] == null
        ? ''
        : tr.format('pulse_act_inventory_forecast',
            {'qty': formatPulseNumber(item['virtual_available'])});
    return '$code$name$onHand$forecast';
  }

  PulseAction row(String key,
          {required String main, String cause = '', bool primary = false}) =>
      PulseAction(
        title: tr.lookup(_k('inventory', key, 'title')),
        main: main,
        cause: cause,
        label: tr.lookup(_k('inventory', key, 'label')),
        prompt: tr.lookup(_k('inventory', key, 'prompt')),
        primary: primary,
      );

  final demand = payload['demand_shortage'];
  final low = payload['low_stock'];
  final fast = payload['fast_reorder'];
  final stagnant = payload['stagnant_stock'];
  final overstock = payload['overstock'];
  final missing = payload['missing_data'];

  if ((_count(demand) ?? 0) != 0) {
    rows.add(row(
      'demand',
      main: tr.format(_k('inventory', 'demand', 'main'), {'n': _count(demand)}),
      cause: productLine(_first(demand)),
      primary: true,
    ));
  }
  if ((_count(low) ?? 0) != 0) {
    rows.add(row(
      'low',
      main: tr.format(_k('inventory', 'low', 'main'), {'n': _count(low)}),
      cause: productLine(_first(low)),
    ));
  }
  if ((_count(fast) ?? 0) != 0) {
    rows.add(row(
      'fast',
      main: tr.format(_k('inventory', 'fast', 'main'), {'n': _count(fast)}),
      cause: productLine(_first(fast)),
    ));
  }
  if ((_count(stagnant) ?? 0) != 0) {
    rows.add(row(
      'stagnant',
      main: tr.format(_k('inventory', 'stagnant', 'main'), {
        'n': _count(stagnant),
        'total': formatPulseNumber(_total(stagnant)),
      }),
      cause: productLine(_first(stagnant)),
    ));
  }
  if ((_count(overstock) ?? 0) != 0) {
    rows.add(row(
      'overstock',
      main: tr.format(
          _k('inventory', 'overstock', 'main'), {'n': _count(overstock)}),
      cause: productLine(_first(overstock)),
    ));
  }
  if ((_count(missing) ?? 0) != 0) {
    final counts = _map(_map(missing)['counts']);
    rows.add(row(
      'missing',
      main: tr.format(_k('inventory', 'missing', 'main'), {
        'cost': _int(counts['missing_cost']),
        'barcode': _int(counts['missing_barcode']),
        'code': _int(counts['missing_code']),
      }),
      cause: tr.lookup(_k('inventory', 'missing', 'cause')),
    ));
  }
  return rows;
}

// ── quality_guard ────────────────────────────────────────────────────────
List<PulseAction> _qualityGuard(Map<String, dynamic> payload, AppStrings tr) {
  final rows = <PulseAction>[];
  // The sub-buckets live under `quality_gate` / `spec_guard`, and the flat
  // numbers under `quality_stats` / `spec_stats` — the same two roots the
  // web reads. Top-level keys are still honoured for the shape the doc
  // documents.
  final qStats = _map(payload['quality_stats']);
  final gate = _map(payload['quality_gate']);
  final measures = gate['measurements'];
  final failed = gate['failed_checks'];
  final points = _map(gate['control_points']);
  final specStats = _map(payload['spec_stats']);
  final specGuard = _map(payload['spec_guard']);
  final cases = _list(specGuard['findings']);

  final outOfSpec =
      _num(payload['out_of_spec']) ?? _num(qStats['out_of_spec']) ?? 0;
  final failedCount =
      _num(payload['failed_checks']) ?? _num(qStats['failed_checks']) ?? 0;
  final pending =
      _num(payload['pending_checks']) ?? _num(qStats['pending_checks']) ?? 0;
  final alerts =
      _num(payload['quality_alerts']) ?? _num(qStats['quality_alerts']) ?? 0;

  if (outOfSpec != 0) {
    final first = _first(measures);
    rows.add(PulseAction(
      title: tr.lookup(_k('quality', 'measure', 'title')),
      main: tr.format(_k('quality', 'measure', 'main'),
          {'n': formatPulseNumber(outOfSpec)}),
      cause: _str(first['product']).isEmpty
          ? ''
          : '${_str(first['product'])} / '
              '${formatPulseNumber(first['measure'])}${_str(first['unit'])} / '
              '${formatPulseNumber(first['lower'])}-'
              '${formatPulseNumber(first['upper'])}',
      label: tr.lookup(_k('quality', 'measure', 'label')),
      prompt: tr.lookup(_k('quality', 'measure', 'prompt')),
      primary: true,
    ));
  }

  if (failedCount != 0 || pending != 0 || alerts != 0) {
    final first = _first(failed);
    final parts = [
      _str(first['name']),
      _str(first['product']),
      _str(first['context'])
    ].where((s) => s.isNotEmpty).toList();
    rows.add(PulseAction(
      title: tr.lookup(_k('quality', 'checks', 'title')),
      main: tr.format(_k('quality', 'checks', 'main'), {
        'failed': formatPulseNumber(failedCount),
        'pending': formatPulseNumber(pending),
        'alerts': formatPulseNumber(alerts),
      }),
      cause: parts.join(' / '),
      label: tr.lookup(_k('quality', 'checks', 'label')),
      prompt: tr.lookup(_k('quality', 'checks', 'prompt')),
      primary: rows.isEmpty,
    ));
  }

  if (cases.isNotEmpty && cases.first is Map) {
    final first = (cases.first! as Map).cast<String, dynamic>();
    final order = _str(first['order']);
    rows.add(PulseAction(
      title: tr.format(_k('quality', 'swap', 'title'),
          {'risk': formatPulseNumber(first['risk_score'] ?? 0)}),
      main: tr.format(_k('quality', 'swap', 'main'), {
        'order': order,
        'requested': _str(first['requested_product']),
        'actual': _str(first['actual_product']),
      }),
      cause: tr.format(_k('quality', 'swap', 'cause'),
          {'discount': formatPulseNumber(first['discount'])}),
      label: tr.lookup(_k('quality', 'swap', 'label')),
      prompt: tr.format(_k('quality', 'swap', 'prompt'), {'order': order}),
      primary: rows.isEmpty,
    ));
    // "Find user" — the recorded actor behind that swap.
    final changedBy = _str(first['changed_by']);
    final changedAt = _str(first['changed_at']);
    rows.add(PulseAction(
      title: tr.lookup(_k('quality', 'actor', 'title')),
      main: changedBy.isEmpty
          ? tr.lookup(_k('quality', 'actor', 'main_empty'))
          : (changedAt.isEmpty ? changedBy : '$changedBy / $changedAt'),
      cause: tr.lookup(_k('quality', 'actor', 'cause')),
      label: tr.lookup(_k('quality', 'actor', 'label')),
      prompt: tr.lookup(_k('quality', 'actor', 'prompt')),
    ));
  }

  final lowerCost = _num(payload['lower_cost_substitutes']) ??
      _num(specStats['lower_cost_substitutes']) ??
      0;
  final undocumented = _num(payload['undocumented_substitutes']) ??
      _num(specStats['undocumented_substitutes']) ??
      0;
  final costGap = _num(payload['cost_saving_total']) ??
      _num(specStats['cost_saving_total']) ??
      0;
  if ((lowerCost != 0 || undocumented != 0 || costGap != 0) &&
      rows.length < 5) {
    rows.add(PulseAction(
      title: tr.lookup(_k('quality', 'substitutes', 'title')),
      main: tr.format(_k('quality', 'substitutes', 'main'), {
        'lower': formatPulseNumber(lowerCost),
        'undocumented': formatPulseNumber(undocumented),
        'gap': formatPulseNumber(costGap),
      }),
      cause: tr.lookup(_k('quality', 'substitutes', 'cause')),
      label: tr.lookup(_k('quality', 'substitutes', 'label')),
      prompt: tr.lookup(_k('quality', 'substitutes', 'prompt')),
      primary: rows.isEmpty,
    ));
  }

  // The web gates this row on `control_points.available` — a database that
  // can't answer must not be told its limits are missing.
  final pointsAvailable =
      points.isEmpty ? true : points['available'] != false;
  final missingSpecs = _num(points['missing_specs']) ??
      _num(payload['missing_numeric_specs']) ??
      _num(qStats['missing_numeric_specs']) ??
      0;
  if (pointsAvailable && missingSpecs != 0 && rows.length < 4) {
    rows.add(PulseAction(
      title: tr.lookup(_k('quality', 'limits', 'title')),
      main: tr.format(
          _k('quality', 'limits', 'main'), {'n': formatPulseNumber(missingSpecs)}),
      cause: tr.lookup(_k('quality', 'limits', 'cause')),
      label: tr.lookup(_k('quality', 'limits', 'label')),
      prompt: tr.lookup(_k('quality', 'limits', 'prompt')),
      primary: rows.isEmpty,
    ));
  }
  return rows;
}

// ── accountant + hr ──────────────────────────────────────────────────────
//
// Both cards are counter-driven: every counter the server sends carries its
// own action, keyed by the counter's `key`. The label and prompt come from
// the string table under `pulse_act_<kind>_<counter key>_*`; a counter whose
// key this client doesn't know yet renders with no button rather than with a
// guessed one.
const _accountantKeys = [
  'journal',
  'invoices',
  'bank',
  'tax',
  'close',
  'stock',
  'diagnosis',
  'closing',
  'cycles',
];

const _hrKeys = [
  'applicants',
  'strong',
  'contracts',
  'payroll',
  'timeoff',
  'attendance',
];

/// The deep-dive chips under a counter-driven card — the checks an
/// accountant (or a recruiter) runs beyond what the counters already say.
/// Order is the web's own.
const _accountantDeep = [
  'brief',
  'transit',
  'statements',
  'ledger',
  'balances',
  'duplicates',
  'chart',
  'setup',
];

const _hrDeep = ['rank', 'interview', 'ops', 'payroll', 'timeoff'];

/// The counter keys each counter-driven card knows an action for.
List<String> pulseCounterActionKeys(String kind) =>
    kind == 'hr' ? _hrKeys : _accountantKeys;

/// The deep-dive chip keys for a counter-driven card.
List<String> pulseDeepActionKeys(String kind) =>
    kind == 'hr' ? _hrDeep : _accountantDeep;

List<PulseAction> _counterDriven(
  Map<String, dynamic> payload,
  AppStrings tr,
  String kind,
) {
  final known = pulseCounterActionKeys(kind);
  final rows = <PulseAction>[];
  for (final raw in _list(payload['counters'])) {
    if (raw is! Map) continue;
    final counter = raw.cast<String, dynamic>();
    final key = _str(counter['key']);
    if (!known.contains(key)) continue;
    final serverAction = _str(counter['action']);
    // Arabic takes the server's own wording for the button, English takes
    // this client's — exactly the web's rule. The server writes `action` in
    // the conversation's language, so in Arabic it is already the better
    // label; the English table is the fallback when it isn't.
    final label = tr.isArabic && serverAction.isNotEmpty
        ? serverAction
        : tr.lookup(_k(kind, key, 'label'), fallback: serverAction);
    final prompt = tr.lookup(_k(kind, key, 'prompt'));
    if (label.isEmpty || prompt.isEmpty) continue;
    rows.add(PulseAction(
      // The counter's own label is server-authored and already in the
      // screen's language (rule 4) — it is the row's title as-is.
      title: _str(counter['label']),
      main: formatPulseNumber(counter['value']),
      label: label,
      prompt: prompt,
      primary: rows.isEmpty,
    ));
  }
  return rows;
}

/// The chip row under an accountant / HR card.
///
/// Split from [pulseActions] because these are not readings with a number
/// attached — they are standing questions the card can always ask, so they
/// render as a wrap of chips rather than as rows. A chip whose label already
/// appears on one of the counter buttons is dropped, matching the web's
/// `dropChipsAlreadyOnTiles`: the same words twice on one card is noise.
List<PulseAction> pulseDeepActions(
  InteractiveCardKind kind,
  Map<String, dynamic>? payload,
  AppStrings tr,
) {
  final name = switch (kind) {
    InteractiveCardKind.accountant => 'accountant',
    InteractiveCardKind.hr => 'hr',
    _ => '',
  };
  if (name.isEmpty) return const [];
  final taken = pulseActions(kind, payload, tr).map((a) => a.label).toSet();
  final out = <PulseAction>[];
  for (final key in pulseDeepActionKeys(name)) {
    final label = tr.lookup('pulse_act_${name}_deep_${key}_label');
    final prompt = tr.lookup('pulse_act_${name}_deep_${key}_prompt');
    if (label.isEmpty || prompt.isEmpty || taken.contains(label)) continue;
    out.add(PulseAction(
      title: '',
      main: '',
      label: label,
      prompt: prompt,
      primary: out.isEmpty,
    ));
  }
  return out;
}

/// What the card says when the payload earns it no action rows — "Liquidity
/// looks calm in the current read; review bank and close hygiene."
///
/// The web prints this instead of the rows, and a real database hits it
/// often: a freshly seeded Odoo answers every question with a zero. Without
/// it the card just ends after its numbers, which reads like something
/// failed to load rather than like good news. Empty for the two
/// counter-driven cards, which the web leaves without one.
String pulseEmptyStateText(InteractiveCardKind kind, AppStrings tr) {
  final key = switch (kind) {
    InteractiveCardKind.factory => 'factory',
    InteractiveCardKind.finance => 'finance',
    InteractiveCardKind.inventory => 'inventory',
    InteractiveCardKind.purchasing => 'purchasing',
    InteractiveCardKind.qualityGuard => 'quality',
    _ => '',
  };
  return key.isEmpty ? '' : tr.lookup('pulse_act_empty_$key');
}

/// The free-text row both counter-driven cards carry: the accountant's
/// "explain this document number", HR's "shortlist for this job title".
/// Returns null for every other kind.
({String hint, String label, String promptKey})? pulseFreeTextAction(
  InteractiveCardKind kind,
) =>
    switch (kind) {
      InteractiveCardKind.accountant => (
          hint: 'pulse_act_accountant_explain_hint',
          label: 'pulse_act_accountant_explain_label',
          promptKey: 'pulse_act_accountant_explain_prompt',
        ),
      InteractiveCardKind.hr => (
          hint: 'pulse_act_hr_explain_hint',
          label: 'pulse_act_hr_explain_label',
          promptKey: 'pulse_act_hr_explain_prompt',
        ),
      _ => null,
    };
