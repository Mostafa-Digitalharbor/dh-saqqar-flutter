part of 'app_pulse_payloads.dart';

/// `cash` — the one scalar bucket in the finance payload that isn't a plain
/// [PulseBucket]: a balance plus which bank/cash journals it was read from.
@immutable
class FinanceCash extends Equatable {
  const FinanceCash({
    required this.available,
    this.balance,
    this.journals = const [],
    this.journalCount,
  });

  final bool available;
  final double? balance;
  final List<String> journals;
  final int? journalCount;

  static FinanceCash fromJson(Object? raw) {
    if (raw is! Map) return const FinanceCash(available: false);
    final json = raw.cast<String, dynamic>();
    return FinanceCash(
      available: json.containsKey('available')
          ? _bool(json['available'])
          : true,
      balance: _double(json['balance']),
      journals: _list(
        json['journals'],
      ).map(_str).where((s) => s.isNotEmpty).toList(),
      journalCount: _int(json['journal_count']),
    );
  }

  @override
  List<Object?> get props => [available, balance, journals, journalCount];
}

/// One day-bucketed band of finance's `collection_aging` / `payment_horizon`
/// — "0–30: 84,000", "90+: 12,500".
///
/// [label] is already display-ready: the server sends machine keys
/// (`d0_30`, `over_90`, `not_due`) and [pulseBandLabel] turns them into
/// something readable before this object exists, so the widget never has to
/// know a key format.
@immutable
class PulseBand extends Equatable {
  const PulseBand({required this.label, this.amount, this.count});

  final String label;
  final double? amount;
  final int? count;

  @override
  List<Object?> get props => [label, amount, count];
}

/// `collection_aging` and `payment_horizon` — the day-bucketed breakdown
/// behind finance's receivable/payable tiles.
///
/// **The shape is read defensively on purpose.** The doc names these two
/// keys but not what is inside them, and warns the payloads drift; a live
/// read was not available while this was written. So every plausible
/// encoding of "a set of day bands" is accepted — a flat `{band: amount}`
/// map, a `{available, buckets: {…}}` wrapper, or a list of
/// `{label, amount, count}` rows — and anything unrecognised yields no bands
/// at all, which the card renders as nothing rather than as a wrong number.
@immutable
class PulseBands extends Equatable {
  const PulseBands({required this.available, this.bands = const []});

  final bool available;
  final List<PulseBand> bands;

  /// Keys that describe the container itself rather than one of its bands,
  /// so a flat `{available, total, d0_30: …}` map doesn't render "total" as
  /// a band next to the real ones.
  /// Keys that describe the container itself rather than one of its bands.
  ///
  /// Anything starting with `total` is an aggregate the web puts in the row
  /// sentence, not a band: a live `collection_aging` carries `total_overdue`
  /// beside `days_1_30`, and rendering it as a band put an untranslated
  /// "total overdue" chip next to the real ones on an Arabic card.
  static const _meta = {
    'available',
    'count',
    'currency',
    'as_of',
    'status',
    'error',
    'notes',
    'label',
  };

  static bool _isMeta(String key) =>
      _meta.contains(key) || key.startsWith('total');

  /// Where a wrapper object keeps its bands, in the order they're tried.
  static const _containers = [
    'buckets',
    'bands',
    'aging',
    'horizon',
    'breakdown',
    'by_bucket',
    'items',
  ];

  static PulseBands fromJson(Object? raw) {
    if (raw is List) {
      return PulseBands(available: true, bands: _fromList(raw));
    }
    if (raw is! Map) return const PulseBands(available: false);
    final json = raw.cast<String, dynamic>();
    final available = json.containsKey('available')
        ? _bool(json['available'])
        : true;
    Object? container;
    for (final key in _containers) {
      final candidate = json[key];
      if (candidate is Map || candidate is List) {
        container = candidate;
        break;
      }
    }
    container ??= json;
    return PulseBands(
      available: available,
      bands: container is List
          ? _fromList(container)
          : _fromMap((container as Map).cast<String, dynamic>()),
    );
  }

  static List<PulseBand> _fromMap(Map<String, dynamic> json) {
    final bands = <PulseBand>[];
    for (final entry in json.entries) {
      if (_isMeta(entry.key)) continue;
      final value = entry.value;
      if (value is num) {
        bands.add(
          PulseBand(label: pulseBandLabel(entry.key), amount: value.toDouble()),
        );
      } else if (value is Map) {
        final row = value.cast<String, dynamic>();
        final band = _row(row, fallbackLabel: entry.key);
        if (band != null) bands.add(band);
      }
    }
    return bands;
  }

  static List<PulseBand> _fromList(List<Object?> raw) => raw
      .whereType<Map<dynamic, dynamic>>()
      .map((e) => _row(e.cast<String, dynamic>()))
      .whereType<PulseBand>()
      .toList();

  /// One `{label, amount, count}`-ish row. Returns null when it carries
  /// neither an amount nor a count — a band with no number is not a band.
  static PulseBand? _row(Map<String, dynamic> json, {String? fallbackLabel}) {
    final rawLabel = ['label', 'bucket', 'band', 'range', 'name', 'key', 'days']
        .map((k) => _str(json[k]))
        .firstWhere((s) => s.isNotEmpty, orElse: () => fallbackLabel ?? '');
    if (rawLabel.isEmpty) return null;
    final amount =
        _double(json['amount']) ??
        _double(json['total']) ??
        _double(json['value']) ??
        _double(json['balance']);
    final count = _int(json['count']) ?? _int(json['invoices']);
    if (amount == null && count == null) return null;
    return PulseBand(
      label: pulseBandLabel(rawLabel),
      amount: amount,
      count: count,
    );
  }

  @override
  List<Object?> get props => [available, bands];
}

/// `d0_30` → `0–30`, `over_90` → `90+`, `not_due` → `not due`.
///
/// Band keys are the server's own machine names, and the numeric ones — the
/// overwhelming majority — carry no language at all, which is why they can
/// be shown in both locales. The rest are un-prefixed and de-underscored
/// rather than translated: inventing an Arabic word for a band this client
/// has never seen would be a guess printed as fact.
String pulseBandLabel(String key) {
  var k = key.trim().toLowerCase();
  if (k.isEmpty) return key.trim();
  // Already human ("0-30 days", "Overdue") — leave it exactly as sent.
  if (k.contains(' ')) return key.trim();
  for (final prefix in ['days_', 'day_', 'bucket_', 'band_', 'range_']) {
    if (k.startsWith(prefix)) k = k.substring(prefix.length);
  }
  // A lone leading `d` in front of digits (`d0_30`) is a field-name prefix,
  // not part of the range.
  if (RegExp(r'^d\d').hasMatch(k)) k = k.substring(1);
  final open =
      RegExp(r'^(over|gt|above|more_than)_(\d+)$').firstMatch(k) ??
      RegExp(r'^(\d+)_(plus)$').firstMatch(k);
  if (open != null) {
    final digits = RegExp(r'\d+').firstMatch(k)!.group(0)!;
    return '$digits+';
  }
  final under = RegExp(r'^(under|lt|below|less_than)_(\d+)$').firstMatch(k);
  if (under != null) return '<${under.group(2)}';
  final range = RegExp(r'^(\d+)_(\d+)$').firstMatch(k);
  if (range != null) return '${range.group(1)}–${range.group(2)}';
  return k.replaceAll('_', ' ');
}

/// "Your money" pulse — cash, receivables, payables, drafts, bank
/// reconciliation and the day-bucketed aging behind them, computed from
/// Odoo (Task 1, MOBILE_TASKS_2026-09.md).
@immutable
class FinancePulsePayload extends Equatable {
  const FinancePulsePayload({
    required this.envelope,
    required this.cash,
    required this.receivablesOverdue,
    required this.receivablesDueSoon,
    required this.payablesOverdue,
    required this.payablesDueSoon,
    required this.draftVendorBills,
    required this.draftCustomerInvoices,
    required this.bankReconciliation,
    this.collectionAging,
    this.paymentHorizon,
    this.liquidityStatus,
    this.liquidityAvailable = false,
    this.priorities = const [],
  });

  final PulseEnvelope envelope;
  final FinanceCash cash;
  final PulseBucket receivablesOverdue;
  final PulseBucket receivablesDueSoon;
  final PulseBucket payablesOverdue;
  final PulseBucket payablesDueSoon;
  final PulseBucket draftVendorBills;
  final PulseBucket draftCustomerInvoices;
  final PulseBucket bankReconciliation;

  /// Receivables split by how long they've been overdue, and payables split
  /// by when they fall due. **Null means the server didn't send the key at
  /// all** — a different thing from `available: false`, which means it sent
  /// the key and said the database can't answer it. The card renders
  /// nothing for the first and an explicit "unavailable" for the second.
  final PulseBands? collectionAging;
  final PulseBands? paymentHorizon;

  /// Server's own word for the 7-day cash position (`"covered"` etc.) — a
  /// system status keyword, not app copy, so it renders as-is rather than
  /// through a translation table this parser would have to keep in sync with
  /// every value the server might ever send.
  final String? liquidityStatus;
  final bool liquidityAvailable;

  /// Already in Arabic, same as [PulseEnvelope.notes] — see rule 4.
  final List<String> priorities;

  static FinancePulsePayload? parse(Map<String, dynamic>? payload) {
    if (interactiveCardKind(payload) != InteractiveCardKind.finance) {
      return null;
    }
    final receivables = _map(payload!['receivables']);
    final payables = _map(payload['payables']);
    final drafts = _map(payload['drafts']);
    final liquidity = _map(payload['liquidity_7d']);
    return FinancePulsePayload(
      envelope: PulseEnvelope.fromJson(payload),
      cash: FinanceCash.fromJson(payload['cash']),
      receivablesOverdue: PulseBucket.fromJson(receivables['overdue']),
      receivablesDueSoon: PulseBucket.fromJson(receivables['due_soon']),
      payablesOverdue: PulseBucket.fromJson(payables['overdue']),
      payablesDueSoon: PulseBucket.fromJson(payables['due_soon']),
      draftVendorBills: PulseBucket.fromJson(drafts['vendor_bills']),
      draftCustomerInvoices: PulseBucket.fromJson(drafts['customer_invoices']),
      bankReconciliation: PulseBucket.fromJson(payload['bank_reconciliation']),
      collectionAging: payload.containsKey('collection_aging')
          ? PulseBands.fromJson(payload['collection_aging'])
          : null,
      paymentHorizon: payload.containsKey('payment_horizon')
          ? PulseBands.fromJson(payload['payment_horizon'])
          : null,
      liquidityStatus: _str(liquidity['status']).isEmpty
          ? null
          : _str(liquidity['status']),
      liquidityAvailable: liquidity.containsKey('available')
          ? _bool(liquidity['available'])
          : false,
      priorities: _list(
        payload['priorities'],
      ).map(_str).where((s) => s.isNotEmpty).toList(),
    );
  }

  @override
  List<Object?> get props => [
    envelope,
    cash,
    receivablesOverdue,
    receivablesDueSoon,
    payablesOverdue,
    payablesDueSoon,
    draftVendorBills,
    draftCustomerInvoices,
    bankReconciliation,
    collectionAging,
    paymentHorizon,
    liquidityStatus,
    liquidityAvailable,
    priorities,
  ];
}
