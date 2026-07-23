import 'package:dio/dio.dart';

import '../../../core/network/api_endpoints.dart';
import 'checkout_models.dart';

/// Paymob checkout client (API_MOBILE_NEW_ENDPOINTS.md §4.3).
///
/// ⚠️ STORE POLICY: buying digital goods in-app via a third-party processor
/// may conflict with App Store / Google Play IAP rules. The UI is gated
/// behind `showPaidUpsell` (hidden on iOS); confirm compliance before
/// shipping this on any platform. This client only talks to the endpoints —
/// the guard lives in the routing + Account entry.
class CheckoutApi {
  CheckoutApi(this._dio);

  final Dio _dio;

  /// `GET /api/v1/billing/plans/` — the purchasable plans (Paymob view).
  /// `currency` is a top-level field, so it's threaded into each plan.
  Future<List<CheckoutPlan>> plans() async {
    final res = await _dio.get<Map<String, dynamic>>(ApiEndpoints.billingPlans);
    final data = res.data ?? const <String, dynamic>{};
    final currency = (data['currency'] ?? 'SAR').toString();
    return (data['plans'] as List? ?? const [])
        .cast<Map<String, dynamic>>()
        .map((j) => CheckoutPlan.fromJson(j, currency: currency))
        .toList();
  }

  /// `POST /api/v1/billing/checkout/ { plan }` — start a checkout; returns
  /// the hosted payment URL + a reference to poll.
  Future<CheckoutSession> start(String planId) async {
    final res = await _dio.post<Map<String, dynamic>>(
      ApiEndpoints.billingCheckout,
      data: {'plan': planId},
    );
    return CheckoutSession.fromJson(res.data ?? const {});
  }

  /// `GET /api/v1/billing/payment/<ref>/status/` — poll a payment.
  Future<PaymentStatus> status(String ref) async {
    final res = await _dio.get<Map<String, dynamic>>(
      ApiEndpoints.billingPaymentStatus(ref),
    );
    return PaymentStatus.fromJson(res.data ?? const {});
  }
}
