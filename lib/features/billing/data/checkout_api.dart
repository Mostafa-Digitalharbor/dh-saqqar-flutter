import 'package:dio/dio.dart';

import '../../../core/network/api_endpoints.dart';
import 'checkout_models.dart';

/// Paymob checkout client (API_MOBILE_NEW_ENDPOINTS.md §4.3).
///
/// ⚠️ **Unreachable in the shipped app.** Tokens are sold on saqqaar.com only
/// (see [showPaidUpsell]) — buying digital goods in-app through a third-party
/// processor conflicts with both App Store 3.1.1 and the Google Play Payments
/// policy, and neither is engaged if nothing is sold here.
///
/// Kept, wired and tested so restoring the surface is flipping one getter
/// rather than rewriting a payment client. This class only talks to the
/// endpoints; the guard lives in the routing + Account entry.
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

  /// `POST /api/v1/billing/checkout/ { plan, cycle }` — start a checkout;
  /// returns the hosted payment URL + a reference to poll.
  ///
  /// [cycle] is sent explicitly and defaults to `monthly` because that is the
  /// price this app renders: `/billing/plans/` returns a `cycles` map and the
  /// UI reads `cycles.monthly.price_sar`. Leaving the cycle out would let the
  /// server pick — and on the live catalogue the annual figure for Pro is
  /// 765 SAR against a displayed 75 SAR, so a silent default is a ten-fold
  /// mischarge, not a cosmetic mismatch. Whether the field is required, and
  /// what it's called, is an open question for the backend; an ignored extra
  /// key costs nothing, an omitted required one costs the user.
  Future<CheckoutSession> start(String planId, {String cycle = 'monthly'}) async {
    final res = await _dio.post<Map<String, dynamic>>(
      ApiEndpoints.billingCheckout,
      data: {'plan': planId, 'cycle': cycle},
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
