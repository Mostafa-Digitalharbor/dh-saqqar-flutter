import 'package:flutter/foundation.dart';

/// A purchasable plan from `GET /api/v1/billing/plans/` (the Paymob view,
/// API_MOBILE_NEW_ENDPOINTS.md §4.3).
///
/// ⚠️ The §4 endpoints ship without documented payloads, so these fields are
/// parsed defensively across the likely key names; confirm against
/// `odoo_agent/urls.py` / the Paymob billing view.
@immutable
class CheckoutPlan {
  const CheckoutPlan({
    required this.id,
    required this.name,
    required this.price,
    required this.currency,
    this.description,
  });

  final String id;
  final String name;
  final double price;
  final String currency;
  final String? description;

  factory CheckoutPlan.fromJson(Map<String, dynamic> json, {String? currency}) {
    // Live schema nests the price under `cycles.monthly.price_sar`; older /
    // alternate shapes put a flat `price`/`amount` on the plan. Try the nested
    // monthly SAR price first, then fall back so a schema change can't blank
    // the price silently (verified live against /billing/plans/).
    double price = 0;
    final cycles = json['cycles'];
    if (cycles is Map) {
      final monthly = cycles['monthly'];
      if (monthly is Map) {
        price = (monthly['price_sar'] as num?)?.toDouble() ?? 0;
      }
    }
    if (price == 0) {
      price = ((json['price'] ?? json['amount'] ?? json['price_sar']) as num?)
              ?.toDouble() ??
          0;
    }
    return CheckoutPlan(
      // Live schema keys the plan by `slug` ("pro", "max-5x").
      id: (json['slug'] ?? json['id'] ?? json['sku'] ?? '').toString(),
      name: (json['name'] ?? json['title'] ?? '').toString(),
      price: price,
      // Currency is a top-level field on the response, not per-plan — the API
      // layer threads it in; default to SAR only if it didn't.
      currency: currency ?? (json['currency'] ?? 'SAR').toString(),
      description: json['description'] as String?,
    );
  }
}

/// Result of `POST /api/v1/billing/checkout/` — a hosted payment page URL
/// plus a reference to poll.
@immutable
class CheckoutSession {
  const CheckoutSession({required this.url, required this.ref});

  final String url;
  final String ref;

  bool get isValid => url.isNotEmpty && ref.isNotEmpty;

  factory CheckoutSession.fromJson(Map<String, dynamic> json) {
    return CheckoutSession(
      url: (json['url'] ?? json['payment_url'] ?? json['checkout_url'] ?? '')
          .toString(),
      ref: (json['ref'] ?? json['reference'] ?? json['payment_ref'] ?? '')
          .toString(),
    );
  }
}

/// Result of `GET /api/v1/billing/payment/<ref>/status/`.
@immutable
class PaymentStatus {
  const PaymentStatus({required this.status, required this.isPaid});

  final String status;
  final bool isPaid;

  bool get isFailed => status == 'failed' || status == 'declined';

  factory PaymentStatus.fromJson(Map<String, dynamic> json) {
    final status = (json['status'] ?? '').toString();
    return PaymentStatus(
      status: status,
      isPaid: json['is_paid'] as bool? ?? status == 'paid',
    );
  }
}
