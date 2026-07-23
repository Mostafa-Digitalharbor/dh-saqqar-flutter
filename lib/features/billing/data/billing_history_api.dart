import 'package:dio/dio.dart';

import '../../../core/network/api_endpoints.dart';
import 'billing_history_models.dart';

/// Reads the caller's own payment history (API_MOBILE_NEW_ENDPOINTS.md §3).
///
/// Read-only, so store-policy-safe — unlike checkout (§4.3), which we
/// deliberately don't wire into the app. The PDF receipt is fetched
/// separately by [ArtifactDownloader] against
/// [ApiEndpoints.billingReceipt], since it streams bytes rather than JSON.
class BillingHistoryApi {
  BillingHistoryApi(this._dio);

  final Dio _dio;

  Future<BillingHistory> fetch() async {
    final res =
        await _dio.get<Map<String, dynamic>>(ApiEndpoints.billingHistory);
    return BillingHistory.fromJson(res.data ?? const {});
  }
}
