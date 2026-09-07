import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';

import 'interactive_card_kind.dart' show interactiveCardKind, InteractiveCardKind;

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

/// A displayable string. Numbers and bools stringify; maps and lists become
/// empty. Mirrors `interactive_cards.dart`'s `_str` — kept as a separate copy
/// rather than exported, since exposing a private helper across files is a
/// worse coupling than four lines duplicated once.
String _str(Object? value) {
  if (value is String) return value;
  if (value is num || value is bool) return '$value';
  return '';
}

List<Object?> _list(Object? value) => value is List ? value : const [];

int? _int(Object? value) {
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value.trim());
  return null;
}

double? _double(Object? value) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value.trim());
  return null;
}

bool _bool(Object? value) => value is bool && value;

/// `status` on every pulse payload — `"ok"` or `"error"` per the doc; an
/// unrecognised value degrades to `ok` so a payload with real numbers is
/// never hidden behind an error screen over a wording drift.
enum PulseStatus {
  ok,
  error;

  static PulseStatus fromWire(Object? value) =>
      value == 'error' ? PulseStatus.error : PulseStatus.ok;
}

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
        notes: _list(json['notes']).map(_str).where((s) => s.isNotEmpty).toList(),
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

  /// Already in Arabic, same as `envelope.notes` — see rule 4.
  final List<String> priorities;

  static InventoryPulsePayload? parse(Map<String, dynamic>? payload) {
    if (interactiveCardKind(payload) != InteractiveCardKind.inventory) {
      return null;
    }
    return InventoryPulsePayload(
      envelope: PulseEnvelope.fromJson(payload!),
      salesDays: _int(payload['sales_days']),
      productCount: _int(payload['product_count']),
      inventoryValue: PulseBucket.fromJson(payload['inventory_value']),
      lowStock: PulseBucket.fromJson(payload['low_stock']),
      demandShortage: PulseBucket.fromJson(payload['demand_shortage']),
      stagnantStock: PulseBucket.fromJson(payload['stagnant_stock']),
      overstock: PulseBucket.fromJson(payload['overstock']),
      fastReorder: PulseBucket.fromJson(payload['fast_reorder']),
      missingData: PulseBucket.fromJson(payload['missing_data']),
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
        priorities,
      ];
}

Map<String, dynamic> _map(Object? raw) =>
    raw is Map ? raw.cast<String, dynamic>() : const <String, dynamic>{};

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

/// "Your money" pulse — cash, receivables, payables, drafts and bank
/// reconciliation, computed from Odoo (Task 1, MOBILE_TASKS_2026-09.md).
///
/// `payment_horizon` and `collection_aging` carry a further day-bucketed
/// breakdown the doc documents, but every number in them is a finer cut of
/// what [receivablesOverdue]/[payablesOverdue] already show — surfacing both
/// would double the tile count without a new question the card answers, so
/// this parser stops at the bucket level.
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
/// database with the Purchase app installed still returned an empty list, so
/// only its length is trustworthy; the card shows a count, not a breakdown.
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
    this.vendorDelayCount = 0,
    this.priorities = const [],
  });

  final PulseEnvelope envelope;
  final PulseBucket openRfqs;
  final PulseBucket awaitingApproval;
  final PulseBucket latePurchaseOrders;
  final PulseBucket lateIncomingReceipts;
  final PulseBucket toBill;
  final PulseBucket vendorBills;
  final int vendorDelayCount;
  final List<String> priorities;

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
      vendorDelayCount: _list(payload['vendor_delay_summary']).length,
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
        vendorDelayCount,
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
@immutable
class HrPulsePayload extends Equatable {
  const HrPulsePayload({
    required this.envelope,
    this.windowDays,
    this.counters = const [],
    required this.operations,
  });

  final PulseEnvelope envelope;
  final int? windowDays;
  final List<PulseCounter> counters;
  final HrOperations operations;

  static HrPulsePayload? parse(Map<String, dynamic>? payload) {
    if (interactiveCardKind(payload) != InteractiveCardKind.hr) return null;
    return HrPulsePayload(
      envelope: PulseEnvelope.fromJson(payload!),
      windowDays: _int(payload['window_days']),
      counters: _counters(payload['counters']),
      operations: HrOperations.fromJson(payload['operations']),
    );
  }

  @override
  List<Object?> get props => [envelope, windowDays, counters, operations];
}

// ─────────────────────────────────────────────────────────────────────────
// accountant
// ─────────────────────────────────────────────────────────────────────────

/// "Your accounts manager" pulse — journal entries, invoice chain, bank
/// matching, tax and month-end close, computed from Odoo.
///
/// The payload also carries a `blocks` map with a full audit trail behind
/// each counter (which invoice, which journal line...); `counters` is that
/// trail already rolled up into the label/value/action the doc's own top-
/// level key list describes, so this parser stops there — the same
/// simplification [PurchasingPulsePayload] makes for `vendor_delay_summary`.
@immutable
class AccountantPulsePayload extends Equatable {
  const AccountantPulsePayload({
    required this.envelope,
    this.month,
    this.windowDays,
    this.counters = const [],
  });

  final PulseEnvelope envelope;
  final String? month;
  final int? windowDays;
  final List<PulseCounter> counters;

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
    );
  }

  @override
  List<Object?> get props => [envelope, month, windowDays, counters];
}

// ─────────────────────────────────────────────────────────────────────────
// quality_guard
// ─────────────────────────────────────────────────────────────────────────

/// "Quality Guard" pulse — numeric quality checks combined with spec-
/// substitution review, computed from standard Odoo records.
///
/// The payload's own `quality_stats` and `spec_stats` objects are already
/// the flat rollup the doc's top-level key list describes (each of those 16
/// documented keys is one field on one of the two); the richer
/// `quality_gate` / `spec_guard` blocks behind them carry the same
/// simplify-at-the-summary-level trade-off as [AccountantPulsePayload].
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

  /// Already in Arabic, same as [PulseEnvelope.notes] — see rule 4.
  final List<String> priorities;

  static QualityGuardPulsePayload? parse(Map<String, dynamic>? payload) {
    if (interactiveCardKind(payload) != InteractiveCardKind.qualityGuard) {
      return null;
    }
    final qualityStats = _map(payload!['quality_stats']);
    final specStats = _map(payload['spec_stats']);
    return QualityGuardPulsePayload(
      envelope: PulseEnvelope.fromJson(payload),
      outOfSpec: _int(qualityStats['out_of_spec']),
      failedChecks: _int(qualityStats['failed_checks']),
      pendingChecks: _int(qualityStats['pending_checks']),
      qualityAlerts: _int(qualityStats['quality_alerts']),
      missingNumericSpecs: _int(qualityStats['missing_numeric_specs']),
      reviewCases: _int(specStats['review_cases']),
      invoiceSwaps: _int(specStats['invoice_swaps']),
      deliverySwaps: _int(specStats['delivery_swaps']),
      highRiskCases: _int(specStats['high_risk_cases']),
      costSavingTotal: _double(specStats['cost_saving_total']),
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
        priorities,
      ];
}
