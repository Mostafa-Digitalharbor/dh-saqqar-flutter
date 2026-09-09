import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';

import 'interactive_card_kind.dart' show interactiveCardKind, InteractiveCardKind;
import '../../../core/format/wire_value.dart';

/// Parsed payloads for the seven guided-app "pulse" cards (Task 1,
/// MOBILE_TASKS_2026-09.md) — a read-only dashboard rendered from
/// `tool_payload` on the final assistant message of a turn, exactly like the
/// interactive cards in `interactive_cards.dart`, but a different family:
/// nothing here composes a follow-up message, so no kind in this file needs
/// an `onSend`/`onSeed` callback.
///
/// Every parser follows the same forgiving rule as the rest of this app's
/// card payloads: a malformed or unrecognised shape returns `null` and the
/// message falls through to an ordinary text bubble, never throws. These run
/// inside `isVisibleMessage` on every poll tick, so a partial backend
/// rollout must not take a whole conversation down.
///
/// Four rules apply to every kind here, straight from the server's own
/// documented behaviour:
///  1. A bucket's `available: false` means "this database can't answer" —
///     render it as unavailable, never as a zero.
///  2. A scalar can be `null` when the underlying Odoo app isn't installed;
///     the server explains why in `notes`.
///  3. `status` can be `"error"`, with an `error` string and empty buckets —
///     render the error, not an empty card.
///  4. `notes` / `priorities` arrive already written in Arabic. Print them
///     verbatim — never through `context.tr`, never re-translated.

// Shared with every other wire parser — see `core/format/wire_value.dart`
// for why these are one implementation rather than a copy per file.
const _str = wireString;
const _list = wireList;
const _int = wireInt;
const _double = wireDouble;
const _bool = wireBool;

/// `status` on every pulse payload — `"ok"` or `"error"` per the doc; an
/// unrecognised value degrades to `ok` so a payload with real numbers is
/// never hidden behind an error screen over a wording drift.
enum PulseStatus {
  ok,
  error;

  static PulseStatus fromWire(Object? value) =>
      value == 'error' ? PulseStatus.error : PulseStatus.ok;
}

/// The one note the server sends that no card shows: a standing disclaimer
/// that the reading came from a stock Odoo install. It says nothing about
/// THIS database, and it arrives on every card of every app, so the web
/// drops it (`renderCardNotes`) and so does this.
///
/// A wire literal, not UI copy: it is matched against what the server
/// writes, never rendered, so it belongs with the parser rather than in
/// `AppStrings`. A substring match, because the sentence continues
/// differently per app.
const _boilerplateNote = 'القراءة الحالية مبنية على Standard Odoo';

/// Common envelope every pulse payload shares: `status`, `as_of`, `error`,
/// `notes`. Each typed payload below embeds one rather than extending it —
/// Dart has no multiple inheritance and these are `Equatable` value types,
/// so composition keeps `props` honest without a mixin's boilerplate.
@immutable
class PulseEnvelope extends Equatable {
  const PulseEnvelope({
    required this.status,
    this.asOf,
    this.error = '',
    this.notes = const [],
  });

  final PulseStatus status;

  /// Raw `YYYY-MM-DD` (or similar) from the server. Parsed for display by
  /// the widget, which falls back to the raw string on a format the client
  /// doesn't recognise — never hidden.
  final String? asOf;

  /// Set when [status] is [PulseStatus.error]. Server-authored, shown as-is.
  final String error;

  /// Already written in Arabic by the server — see rule 4 above.
  final List<String> notes;

  factory PulseEnvelope.fromJson(Map<String, dynamic> json) => PulseEnvelope(
        status: PulseStatus.fromWire(json['status']),
        asOf: _str(json['as_of']).isEmpty ? null : _str(json['as_of']),
        error: _str(json['error']),
        notes: _list(json['notes'])
            .map(_str)
            .where((s) => s.isNotEmpty && !s.contains(_boilerplateNote))
            .toList(),
      );

  @override
  List<Object?> get props => [status, asOf, error, notes];
}

/// One row of `factory.top_risks` — at most 5, per the doc.
@immutable
class FactoryTopRisk extends Equatable {
  const FactoryTopRisk({
    required this.order,
    this.orderId,
    this.customer = '',
    this.missingLines,
    this.leadDays,
    this.worstProduct = '',
  });

  final String order;
  final int? orderId;
  final String customer;
  final int? missingLines;
  final int? leadDays;
  final String worstProduct;

  static FactoryTopRisk? fromJson(Map<String, dynamic> json) {
    final order = _str(json['order']);
    if (order.isEmpty) return null;
    return FactoryTopRisk(
      order: order,
      orderId: _int(json['order_id']),
      customer: _str(json['customer']),
      missingLines: _int(json['missing_lines']),
      leadDays: _int(json['lead_days']),
      worstProduct: _str(json['worst_product']),
    );
  }

  @override
  List<Object?> get props =>
      [order, orderId, customer, missingLines, leadDays, worstProduct];
}

@immutable
class FactoryPulsePayload extends Equatable {
  const FactoryPulsePayload({
    required this.envelope,
    this.moRunning,
    this.moLate,
    this.moDoneToday,
    this.poLate,
    this.ordersAtRisk,
    this.topRisks = const [],
  });

  final PulseEnvelope envelope;

  /// Null when the `mrp` Odoo app isn't installed (rule 2).
  final int? moRunning;
  final int? moLate;
  final int? moDoneToday;

  /// Null when the `purchase` Odoo app isn't installed.
  final int? poLate;
  final int? ordersAtRisk;
  final List<FactoryTopRisk> topRisks;

  static FactoryPulsePayload? parse(Map<String, dynamic>? payload) {
    if (interactiveCardKind(payload) != InteractiveCardKind.factory) {
      return null;
    }
    return FactoryPulsePayload(
      envelope: PulseEnvelope.fromJson(payload!),
      moRunning: _int(payload['mo_running']),
      moLate: _int(payload['mo_late']),
      moDoneToday: _int(payload['mo_done_today']),
      poLate: _int(payload['po_late']),
      ordersAtRisk: _int(payload['orders_at_risk']),
      topRisks: _list(payload['top_risks'])
          .whereType<Map<dynamic, dynamic>>()
          .map((e) => FactoryTopRisk.fromJson(e.cast<String, dynamic>()))
          .whereType<FactoryTopRisk>()
          .toList(),
    );
  }

  @override
  List<Object?> get props =>
      [envelope, moRunning, moLate, moDoneToday, poLate, ordersAtRisk, topRisks];
}

/// One of inventory's six uniform buckets — `available`/`count`/`items`, plus
/// an optional `total`. The doc gives this envelope but not the shape of
/// `items` inside it, so [items] stays a raw JSON list; [PulseRawItemsList]
/// (`app_pulse/pulse_raw_items.dart`) renders it generically until a kind's
/// item shape is confirmed against a live payload and gets its own typed row.
@immutable
class PulseBucket extends Equatable {
  const PulseBucket({
    required this.available,
    this.count,
    this.items = const [],
    this.total,
  });

  /// `false` means "this database can't answer" (rule 1) — render
  /// unavailable, never as a zero-count bucket.
  final bool available;
  final int? count;
  final List<Object?> items;
  final double? total;

  static PulseBucket fromJson(Object? raw) {
    // A bare number is a bucket the server chose to send as just its count
    // (the accountant's five checks do this). Reading it as unavailable
    // would turn a real answer into "this database can't answer".
    if (raw is num) {
      return PulseBucket(available: true, count: raw.toInt());
    }
    if (raw is! Map) return const PulseBucket(available: false);
    final json = raw.cast<String, dynamic>();
    return PulseBucket(
      // Missing `available` reads as available — every field on the bucket
      // is then read as absent-means-zero-ish rather than unavailable,
      // matching a server that predates the flag.
      available: json.containsKey('available') ? _bool(json['available']) : true,
      count: _int(json['count']),
      items: _list(json['items']),
      total: _double(json['total']),
    );
  }

  @override
  List<Object?> get props => [available, count, items, total];
}

@immutable
class InventoryPulsePayload extends Equatable {
  const InventoryPulsePayload({
    required this.envelope,
    this.salesDays,
    this.productCount,
    required this.inventoryValue,
    required this.lowStock,
    required this.demandShortage,
    required this.stagnantStock,
    required this.overstock,
    required this.fastReorder,
    required this.missingData,
    this.missingDataReasons,
    this.priorities = const [],
  });

  final PulseEnvelope envelope;
  final int? salesDays;
  final int? productCount;
  final PulseBucket inventoryValue;
  final PulseBucket lowStock;
  final PulseBucket demandShortage;
  final PulseBucket stagnantStock;
  final PulseBucket overstock;
  final PulseBucket fastReorder;
  final PulseBucket missingData;

  /// `missing_data.counts` — the reason breakdown behind the missing-data
  /// count (`{no_cost: 8, no_lead_time: 14}`). The doc shows the key with an
  /// empty object, so the reason names are the server's own and are shown
  /// de-underscored rather than translated, exactly like a band label.
  /// Null when the payload carried no `counts` at all.
  final PulseBands? missingDataReasons;

  /// Already in Arabic, same as `envelope.notes` — see rule 4.
  final List<String> priorities;

  static InventoryPulsePayload? parse(Map<String, dynamic>? payload) {
    if (interactiveCardKind(payload) != InteractiveCardKind.inventory) {
      return null;
    }
    final missingData = _map(payload!['missing_data']);
    return InventoryPulsePayload(
      envelope: PulseEnvelope.fromJson(payload),
      salesDays: _int(payload['sales_days']),
      productCount: _int(payload['product_count']),
      inventoryValue: PulseBucket.fromJson(payload['inventory_value']),
      lowStock: PulseBucket.fromJson(payload['low_stock']),
      demandShortage: PulseBucket.fromJson(payload['demand_shortage']),
      stagnantStock: PulseBucket.fromJson(payload['stagnant_stock']),
      overstock: PulseBucket.fromJson(payload['overstock']),
      fastReorder: PulseBucket.fromJson(payload['fast_reorder']),
      missingData: PulseBucket.fromJson(payload['missing_data']),
      missingDataReasons: missingData.containsKey('counts')
          ? PulseBands.fromJson(missingData['counts'])
          : null,
      priorities:
          _list(payload['priorities']).map(_str).where((s) => s.isNotEmpty).toList(),
    );
  }

  @override
  List<Object?> get props => [
        envelope,
        salesDays,
        productCount,
        inventoryValue,
        lowStock,
        demandShortage,
        stagnantStock,
        overstock,
        fastReorder,
        missingData,
        missingDataReasons,
        priorities,
      ];
}

const _map = wireMap;

/// One row of the accountant's and HR's shared `counters` list: a label, the
/// count that earned it a place on the list, and the server's own suggested
/// next step — all already written in the screen's working language by the
/// server. Rendered verbatim (rule 4), never through `context.tr`, which is
/// exactly why this card needs almost no new translation keys of its own.
@immutable
class PulseCounter extends Equatable {
  const PulseCounter({
    required this.key,
    required this.label,
    this.value,
    this.action = '',
  });

  final String key;
  final String label;
  final int? value;
  final String action;

  static PulseCounter? fromJson(Map<String, dynamic> json) {
    final label = _str(json['label']);
    if (label.isEmpty) return null;
    return PulseCounter(
      key: _str(json['key']),
      label: label,
      value: _int(json['value']),
      action: _str(json['action']),
    );
  }

  @override
  List<Object?> get props => [key, label, value, action];
}

List<PulseCounter> _counters(Object? raw) => _list(raw)
    .whereType<Map<dynamic, dynamic>>()
    .map((e) => PulseCounter.fromJson(e.cast<String, dynamic>()))
    .whereType<PulseCounter>()
    .toList();

// ─────────────────────────────────────────────────────────────────────────
// finance
// ─────────────────────────────────────────────────────────────────────────

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
      available:
          json.containsKey('available') ? _bool(json['available']) : true,
      balance: _double(json['balance']),
      journals:
          _list(json['journals']).map(_str).where((s) => s.isNotEmpty).toList(),
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
    final available =
        json.containsKey('available') ? _bool(json['available']) : true;
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
        bands.add(PulseBand(
          label: pulseBandLabel(entry.key),
          amount: value.toDouble(),
        ));
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
    final rawLabel = [
      'label',
      'bucket',
      'band',
      'range',
      'name',
      'key',
      'days',
    ].map((k) => _str(json[k])).firstWhere((s) => s.isNotEmpty,
        orElse: () => fallbackLabel ?? '');
    if (rawLabel.isEmpty) return null;
    final amount = _double(json['amount']) ??
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
  final open = RegExp(r'^(over|gt|above|more_than)_(\d+)$').firstMatch(k) ??
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
      liquidityStatus:
          _str(liquidity['status']).isEmpty ? null : _str(liquidity['status']),
      liquidityAvailable: liquidity.containsKey('available')
          ? _bool(liquidity['available'])
          : false,
      priorities:
          _list(payload['priorities']).map(_str).where((s) => s.isNotEmpty).toList(),
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

// ─────────────────────────────────────────────────────────────────────────
// purchasing
// ─────────────────────────────────────────────────────────────────────────

/// "Your purchasing" pulse — RFQs, approvals, late orders/receipts, vendor
/// bills and vendor delays, computed from Odoo.
///
/// `vendor_delay_summary`'s row shape is undocumented — a live payload from a
/// database with the Purchase app installed still returned an empty list. The
/// rows are therefore kept raw in [vendorDelays] and rendered by
/// [PulseRawItemsList], which reads whatever name and numbers each row
/// happens to carry instead of requiring fields this client has never seen.
@immutable
class PurchasingPulsePayload extends Equatable {
  const PurchasingPulsePayload({
    required this.envelope,
    required this.openRfqs,
    required this.awaitingApproval,
    required this.latePurchaseOrders,
    required this.lateIncomingReceipts,
    required this.toBill,
    required this.vendorBills,
    this.vendorDelays = const [],
    this.priorities = const [],
  });

  final PulseEnvelope envelope;
  final PulseBucket openRfqs;
  final PulseBucket awaitingApproval;
  final PulseBucket latePurchaseOrders;
  final PulseBucket lateIncomingReceipts;
  final PulseBucket toBill;
  final PulseBucket vendorBills;

  /// Raw `vendor_delay_summary` rows — see the class doc. Kept as JSON
  /// rather than a typed row so an unknown field is rendered, not dropped.
  final List<Object?> vendorDelays;
  final List<String> priorities;

  int get vendorDelayCount => vendorDelays.length;

  static PurchasingPulsePayload? parse(Map<String, dynamic>? payload) {
    if (interactiveCardKind(payload) != InteractiveCardKind.purchasing) {
      return null;
    }
    return PurchasingPulsePayload(
      envelope: PulseEnvelope.fromJson(payload!),
      openRfqs: PulseBucket.fromJson(payload['open_rfqs']),
      awaitingApproval: PulseBucket.fromJson(payload['awaiting_approval']),
      latePurchaseOrders: PulseBucket.fromJson(payload['late_purchase_orders']),
      lateIncomingReceipts:
          PulseBucket.fromJson(payload['late_incoming_receipts']),
      toBill: PulseBucket.fromJson(payload['to_bill']),
      vendorBills: PulseBucket.fromJson(payload['vendor_bills']),
      vendorDelays: _list(payload['vendor_delay_summary']),
      priorities:
          _list(payload['priorities']).map(_str).where((s) => s.isNotEmpty).toList(),
    );
  }

  @override
  List<Object?> get props => [
        envelope,
        openRfqs,
        awaitingApproval,
        latePurchaseOrders,
        lateIncomingReceipts,
        toBill,
        vendorBills,
        vendorDelays,
        priorities,
      ];
}

// ─────────────────────────────────────────────────────────────────────────
// hr (Recruitment Manager)
// ─────────────────────────────────────────────────────────────────────────

/// One flagged employee from `operations.items` — a reason already written
/// in Arabic by the server (rule 4), never re-translated.
@immutable
class HrOperationItem extends Equatable {
  const HrOperationItem({required this.employee, this.reason = '', this.type = ''});

  final String employee;
  final String reason;
  final String type;

  static HrOperationItem? fromJson(Map<String, dynamic> json) {
    final employee = _str(json['employee']);
    if (employee.isEmpty) return null;
    return HrOperationItem(
      employee: employee,
      reason: _str(json['reason']),
      type: _str(json['type']),
    );
  }

  @override
  List<Object?> get props => [employee, reason, type];
}

@immutable
class HrOperations extends Equatable {
  const HrOperations({
    required this.available,
    this.activeEmployees,
    this.missingManagers,
    this.missingWorkEmail,
    this.items = const [],
  });

  final bool available;
  final int? activeEmployees;
  final int? missingManagers;
  final int? missingWorkEmail;
  final List<HrOperationItem> items;

  static HrOperations fromJson(Object? raw) {
    if (raw is! Map) return const HrOperations(available: false);
    final json = raw.cast<String, dynamic>();
    return HrOperations(
      available:
          json.containsKey('available') ? _bool(json['available']) : true,
      activeEmployees: _int(json['active_employees']),
      missingManagers: _int(json['missing_managers']),
      missingWorkEmail: _int(json['missing_work_email']),
      items: _list(json['items'])
          .whereType<Map<dynamic, dynamic>>()
          .map((e) => HrOperationItem.fromJson(e.cast<String, dynamic>()))
          .whereType<HrOperationItem>()
          .toList(),
    );
  }

  @override
  List<Object?> get props =>
      [available, activeEmployees, missingManagers, missingWorkEmail, items];
}

/// "Recruitment Manager" pulse — applicants, employee/contract hygiene,
/// payroll and time-off readiness, computed from Odoo.
///
/// `counters` is the server's own pre-summarized "what needs a look, and
/// what to do about it" list — already labelled and captioned in the
/// screen's working language — so it carries the headline numbers for
/// recruitment, payroll and time-off without this parser inventing its own
/// tile labels for them. [operations] is kept as its own field only because
/// it names WHO is flagged, which `counters` cannot.
///
/// [recruitment], [payroll] and [timeOff] are the doc's other three
/// top-level keys. Their inner shape is undocumented, so each is read as the
/// same uniform `{available, count, items}` bucket the inventory kind uses:
/// a server that sends that shape gets a real tile and a real list, and one
/// that sends something else gets a section with nothing in it rather than a
/// fabricated number. Null means the key was absent entirely.
@immutable
class HrPulsePayload extends Equatable {
  const HrPulsePayload({
    required this.envelope,
    this.windowDays,
    this.counters = const [],
    required this.operations,
    this.recruitment,
    this.payroll,
    this.timeOff,
  });

  final PulseEnvelope envelope;
  final int? windowDays;
  final List<PulseCounter> counters;
  final HrOperations operations;
  final PulseBucket? recruitment;
  final PulseBucket? payroll;
  final PulseBucket? timeOff;

  static HrPulsePayload? parse(Map<String, dynamic>? payload) {
    if (interactiveCardKind(payload) != InteractiveCardKind.hr) return null;
    PulseBucket? section(String key) => payload!.containsKey(key)
        ? PulseBucket.fromJson(payload[key])
        : null;
    return HrPulsePayload(
      envelope: PulseEnvelope.fromJson(payload!),
      windowDays: _int(payload['window_days']),
      counters: _counters(payload['counters']),
      operations: HrOperations.fromJson(payload['operations']),
      recruitment: section('recruitment'),
      payroll: section('payroll'),
      timeOff: section('time_off'),
    );
  }

  @override
  List<Object?> get props => [
        envelope,
        windowDays,
        counters,
        operations,
        recruitment,
        payroll,
        timeOff,
      ];
}

// ─────────────────────────────────────────────────────────────────────────
// accountant
// ─────────────────────────────────────────────────────────────────────────

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
  List<Object?> get props =>
      [envelope, month, windowDays, counters, blocks, checks];
}

// ─────────────────────────────────────────────────────────────────────────
// quality_guard
// ─────────────────────────────────────────────────────────────────────────

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
    double? readDouble(String key) => _double(payload[key]) ??
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
      priorities:
          _list(payload['priorities']).map(_str).where((s) => s.isNotEmpty).toList(),
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
