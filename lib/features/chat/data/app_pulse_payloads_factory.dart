part of 'app_pulse_payloads.dart';

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
  List<Object?> get props => [
    order,
    orderId,
    customer,
    missingLines,
    leadDays,
    worstProduct,
  ];
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
  List<Object?> get props => [
    envelope,
    moRunning,
    moLate,
    moDoneToday,
    poLate,
    ordersAtRisk,
    topRisks,
  ];
}
