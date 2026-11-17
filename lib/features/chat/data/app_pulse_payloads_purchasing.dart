part of 'app_pulse_payloads.dart';

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
      lateIncomingReceipts: PulseBucket.fromJson(
        payload['late_incoming_receipts'],
      ),
      toBill: PulseBucket.fromJson(payload['to_bill']),
      vendorBills: PulseBucket.fromJson(payload['vendor_bills']),
      vendorDelays: _list(payload['vendor_delay_summary']),
      priorities: _list(
        payload['priorities'],
      ).map(_str).where((s) => s.isNotEmpty).toList(),
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
