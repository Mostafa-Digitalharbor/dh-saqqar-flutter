part of 'pulse_actions.dart';

// ── factory ──────────────────────────────────────────────────────────────
//
// ONE row per at-risk order carrying TWO buttons, which is the web's shape:
// "Delivery date" then "Cover shortage", the second filled. Both continue
// the conversation rather than acting — the agent reads the order, and any
// document it then wants to write still goes through the approval card.
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
    out.add(
      PulseAction(
        title: order,
        main: _str(risk['customer']),
        cause: tr.format(_k('factory', 'risk', 'cause'), vars),
        label: tr.lookup(_k('factory', 'promise', 'label')),
        prompt: tr.format(_k('factory', 'promise', 'prompt'), vars),
        extraButtons: [
          PulseActionButton(
            label: tr.lookup(_k('factory', 'cover', 'label')),
            prompt: tr.format(_k('factory', 'cover', 'prompt'), vars),
            primary: true,
          ),
        ],
      ),
    );
  }
  return out;
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
        : tr.format('pulse_act_inventory_on_hand', {
            'qty': formatPulseNumber(item['qty_available']),
          });
    final forecast = item['virtual_available'] == null
        ? ''
        : tr.format('pulse_act_inventory_forecast', {
            'qty': formatPulseNumber(item['virtual_available']),
          });
    return '$code$name$onHand$forecast';
  }

  PulseAction row(
    String key, {
    required String main,
    String cause = '',
    bool primary = false,
  }) => PulseAction(
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
    rows.add(
      row(
        'demand',
        main: tr.format(_k('inventory', 'demand', 'main'), {
          'n': _count(demand),
        }),
        cause: productLine(_first(demand)),
        primary: true,
      ),
    );
  }
  if ((_count(low) ?? 0) != 0) {
    rows.add(
      row(
        'low',
        main: tr.format(_k('inventory', 'low', 'main'), {'n': _count(low)}),
        cause: productLine(_first(low)),
      ),
    );
  }
  if ((_count(fast) ?? 0) != 0) {
    rows.add(
      row(
        'fast',
        main: tr.format(_k('inventory', 'fast', 'main'), {'n': _count(fast)}),
        cause: productLine(_first(fast)),
      ),
    );
  }
  if ((_count(stagnant) ?? 0) != 0) {
    rows.add(
      row(
        'stagnant',
        main: tr.format(_k('inventory', 'stagnant', 'main'), {
          'n': _count(stagnant),
          'total': formatPulseNumber(_total(stagnant)),
        }),
        cause: productLine(_first(stagnant)),
      ),
    );
  }
  if ((_count(overstock) ?? 0) != 0) {
    rows.add(
      row(
        'overstock',
        main: tr.format(_k('inventory', 'overstock', 'main'), {
          'n': _count(overstock),
        }),
        cause: productLine(_first(overstock)),
      ),
    );
  }
  if ((_count(missing) ?? 0) != 0) {
    final counts = _map(_map(missing)['counts']);
    rows.add(
      row(
        'missing',
        main: tr.format(_k('inventory', 'missing', 'main'), {
          'cost': _int(counts['missing_cost']),
          'barcode': _int(counts['missing_barcode']),
          'code': _int(counts['missing_code']),
        }),
        cause: tr.lookup(_k('inventory', 'missing', 'cause')),
      ),
    );
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
    rows.add(
      PulseAction(
        title: tr.lookup(_k('quality', 'measure', 'title')),
        main: tr.format(_k('quality', 'measure', 'main'), {
          'n': formatPulseNumber(outOfSpec),
        }),
        cause: _str(first['product']).isEmpty
            ? ''
            : '${_str(first['product'])} / '
                  '${formatPulseNumber(first['measure'])}${_str(first['unit'])} / '
                  '${formatPulseNumber(first['lower'])}-'
                  '${formatPulseNumber(first['upper'])}',
        label: tr.lookup(_k('quality', 'measure', 'label')),
        prompt: tr.lookup(_k('quality', 'measure', 'prompt')),
        primary: true,
      ),
    );
  }

  if (failedCount != 0 || pending != 0 || alerts != 0) {
    final first = _first(failed);
    final parts = [
      _str(first['name']),
      _str(first['product']),
      _str(first['context']),
    ].where((s) => s.isNotEmpty).toList();
    rows.add(
      PulseAction(
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
      ),
    );
  }

  if (cases.isNotEmpty && cases.first is Map) {
    final first = (cases.first! as Map).cast<String, dynamic>();
    final order = _str(first['order']);
    rows.add(
      PulseAction(
        title: tr.format(_k('quality', 'swap', 'title'), {
          'risk': formatPulseNumber(first['risk_score'] ?? 0),
        }),
        main: tr.format(_k('quality', 'swap', 'main'), {
          'order': order,
          'requested': _str(first['requested_product']),
          'actual': _str(first['actual_product']),
        }),
        cause: tr.format(_k('quality', 'swap', 'cause'), {
          'discount': formatPulseNumber(first['discount']),
        }),
        label: tr.lookup(_k('quality', 'swap', 'label')),
        prompt: tr.format(_k('quality', 'swap', 'prompt'), {'order': order}),
        primary: rows.isEmpty,
      ),
    );
    // "Find user" — the recorded actor behind that swap.
    final changedBy = _str(first['changed_by']);
    final changedAt = _str(first['changed_at']);
    rows.add(
      PulseAction(
        title: tr.lookup(_k('quality', 'actor', 'title')),
        main: changedBy.isEmpty
            ? tr.lookup(_k('quality', 'actor', 'main_empty'))
            : (changedAt.isEmpty ? changedBy : '$changedBy / $changedAt'),
        cause: tr.lookup(_k('quality', 'actor', 'cause')),
        label: tr.lookup(_k('quality', 'actor', 'label')),
        prompt: tr.lookup(_k('quality', 'actor', 'prompt')),
      ),
    );
  }

  final lowerCost =
      _num(payload['lower_cost_substitutes']) ??
      _num(specStats['lower_cost_substitutes']) ??
      0;
  final undocumented =
      _num(payload['undocumented_substitutes']) ??
      _num(specStats['undocumented_substitutes']) ??
      0;
  final costGap =
      _num(payload['cost_saving_total']) ??
      _num(specStats['cost_saving_total']) ??
      0;
  if ((lowerCost != 0 || undocumented != 0 || costGap != 0) &&
      rows.length < 5) {
    rows.add(
      PulseAction(
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
      ),
    );
  }

  // The web gates this row on `control_points.available` — a database that
  // can't answer must not be told its limits are missing.
  final pointsAvailable = points.isEmpty ? true : points['available'] != false;
  final missingSpecs =
      _num(points['missing_specs']) ??
      _num(payload['missing_numeric_specs']) ??
      _num(qStats['missing_numeric_specs']) ??
      0;
  if (pointsAvailable && missingSpecs != 0 && rows.length < 4) {
    rows.add(
      PulseAction(
        title: tr.lookup(_k('quality', 'limits', 'title')),
        main: tr.format(_k('quality', 'limits', 'main'), {
          'n': formatPulseNumber(missingSpecs),
        }),
        cause: tr.lookup(_k('quality', 'limits', 'cause')),
        label: tr.lookup(_k('quality', 'limits', 'label')),
        prompt: tr.lookup(_k('quality', 'limits', 'prompt')),
        primary: rows.isEmpty,
      ),
    );
  }
  return rows;
}
