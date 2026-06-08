import 'package:dio/dio.dart';

import '../../../core/network/api_endpoints.dart';
import 'plan_tier_models.dart';

/// Reads the public pricing catalogue (Gap L).
///
/// `GET /api/v1/plans/` needs no bearer — anonymous users can browse. The
/// app's authenticated [Dio] is fine to reuse: when a bearer is present the
/// server fills `current_plan` so the pricing screen can mark the caller's
/// tier.
class PlansApi {
  PlansApi(this._dio);

  final Dio _dio;

  Future<PlansResponse> list() async {
    final res = await _dio.get<Map<String, dynamic>>(ApiEndpoints.plans);
    return PlansResponse.fromJson(res.data ?? const {});
  }
}
