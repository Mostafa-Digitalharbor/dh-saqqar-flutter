part of 'pulse_actions.dart';

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
  final agingOverdueTotal = hasAging
      ? _num(aging['total_overdue'])
      : _total(overdueCustomers);
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
    rows.add(
      row(
        'gap',
        main: tr.format(_k('finance', 'gap', 'main'), {
          'amount': formatPulseNumber(cashGap.abs()),
        }),
        cause: tr.format(_k('finance', 'gap', 'cause'), {
          'after': formatPulseNumber(liquidity['after_collection_gap']),
        }),
      ),
    );
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
    rows.add(
      row(
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
      ),
    );
  }

  final topVendor = _first(
    (_count(overdueVendors) ?? 0) != 0 ? overdueVendors : dueVendors,
  );
  if (vendorDueCount != 0 ||
      (vendorDueTotal ?? 0) != 0 ||
      (hasHorizon && _int(horizon['total_due_30d']) != 0)) {
    rows.add(
      row(
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
      ),
    );
  }

  final bankCount = _count(bank);
  if (bankCount != null && bankCount != 0) {
    rows.add(
      row(
        'bank',
        main: tr.format(_k('finance', 'bank', 'main'), {'n': bankCount}),
        cause: (_total(bank) ?? 0) == 0
            ? ''
            : tr.format(_k('finance', 'bank', 'cause'), {
                'total': formatPulseNumber(_total(bank)),
              }),
      ),
    );
  }

  final customerDrafts = _count(drafts['customer_invoices']) ?? 0;
  final vendorDrafts = _count(drafts['vendor_bills']) ?? 0;
  if (customerDrafts != 0 || vendorDrafts != 0) {
    rows.add(
      row(
        'drafts',
        main: tr.format(_k('finance', 'drafts', 'main'), {
          'customer': customerDrafts,
          'vendor': vendorDrafts,
        }),
      ),
    );
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

  PulseAction row(
    String key, {
    required String main,
    String cause = '',
    bool primary = false,
  }) => PulseAction(
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
    rows.add(
      row(
        'late',
        main: tr.format(_k('purchasing', 'late', 'main'), {
          'receipts': _count(lateReceipts) ?? 0,
          'orders': _count(latePo) ?? 0,
        }),
        cause: _str(lateFirst['vendor']).isEmpty
            ? ''
            : tr.format(_k('purchasing', 'late', 'cause'), {
                'name': [_str(lateFirst['name']), _str(lateFirst['origin'])]
                    .firstWhere(
                      (s) => s.isNotEmpty,
                      orElse: () => tr.lookup('pulse_act_no_number'),
                    ),
                'vendor': _str(lateFirst['vendor']),
              }),
        primary: true,
      ),
    );
  }

  if ((_count(approval) ?? 0) != 0) {
    final first = _first(approval);
    rows.add(
      row(
        'approval',
        main: tr.format(_k('purchasing', 'approval', 'main'), {
          'n': _count(approval),
          'total': formatPulseNumber(_total(approval)),
        }),
        cause: _str(first['vendor']).isEmpty
            ? ''
            : '${_str(first['name'])} / ${_str(first['vendor'])} / '
                  '${formatPulseNumber(first['amount'])}',
      ),
    );
  }

  if ((_count(rfqs) ?? 0) != 0) {
    final first = _first(rfqs);
    rows.add(
      row(
        'rfq',
        main: tr.format(_k('purchasing', 'rfq', 'main'), {
          'n': _count(rfqs),
          'total': formatPulseNumber(_total(rfqs)),
        }),
        cause: _str(first['vendor']).isEmpty
            ? ''
            : '${_str(first['name'])} / ${_str(first['vendor'])} / '
                  '${formatPulseNumber(first['amount'])}',
      ),
    );
  }

  if ((_count(toBill) ?? 0) != 0) {
    rows.add(
      row(
        'bill',
        main: tr.format(_k('purchasing', 'bill', 'main'), {
          'n': _count(toBill),
        }),
        cause: tr.lookup(_k('purchasing', 'bill', 'cause')),
      ),
    );
  }

  final overdueBills = _count(billsOverdue) ?? 0;
  final soonBills = _count(billsSoon) ?? 0;
  final draftBills = _count(billsDraft) ?? 0;
  if (overdueBills != 0 || soonBills != 0 || draftBills != 0) {
    final vendorBillTotal =
        (_total(billsSoon) ?? 0) + (_total(billsOverdue) ?? 0);
    rows.add(
      row(
        'bills',
        main: tr.format(_k('purchasing', 'bills', 'main'), {
          'overdue': overdueBills,
          'soon': soonBills,
          'draft': draftBills,
        }),
        cause: vendorBillTotal == 0
            ? ''
            : tr.format(_k('purchasing', 'bills', 'cause'), {
                'total': formatPulseNumber(vendorBillTotal),
              }),
      ),
    );
  }
  return rows;
}
