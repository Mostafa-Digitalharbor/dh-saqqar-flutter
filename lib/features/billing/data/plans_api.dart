import 'package:dio/dio.dart';

import '../../../core/network/api_endpoints.dart';
import '../../../core/network/response_body.dart';
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
    // `?? {}` here parsed into an empty catalogue, and the pricing screen
    // renders an empty catalogue as its ordinary empty state — the user is
    // told nothing is for sale rather than that the price list failed to
    // load, and gets no retry.
    return PlansResponse.fromJson(res.requiredBody);
  }
}
