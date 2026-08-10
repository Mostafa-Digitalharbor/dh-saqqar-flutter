import 'package:dio/dio.dart';

import '../../../core/network/api_endpoints.dart';
import '../../../core/network/response_body.dart';
import 'trial_models.dart';

/// Requests and polls a managed Odoo trial (API_MOBILE_NEW_ENDPOINTS.md §2).
///
/// A user has exactly one trial; [request] is idempotent server-side (a
/// second call returns the existing one rather than creating a duplicate).
class TrialApi {
  TrialApi(this._dio);

  final Dio _dio;

  /// `POST /api/v1/trial/` — create (or return the existing) trial. The
  /// response nests the trial under `trial`; both the `201 created` and
  /// `200 existing` shapes carry the same sub-object.
  Future<TrialInfo> request(TrialRequest req) async {
    final res = await _dio.post<Map<String, dynamic>>(
      ApiEndpoints.trial,
      data: req.toJson(),
    );
    // The `trial` sub-object is required — a body without it means the
    // server did not create (or find) a trial, and parsing `{}` into a
    // TrialInfo produces a blank "not requested" card, i.e. the exact
    // screen the user was looking at before they pressed the button.
    final trial = requireBody(
      (res.requiredBody['trial'] as Map?)?.cast<String, dynamic>(),
      statusCode: res.statusCode,
    );
    return TrialInfo.fromJson(trial);
  }

  /// `GET /api/v1/trial/status/` — poll provisioning. Also kicks off
  /// provisioning on the first call (when auto-provisioning is enabled).
  /// When `ready`, the body carries live admin credentials.
  Future<TrialInfo> status() async {
    final res = await _dio.get<Map<String, dynamic>>(ApiEndpoints.trialStatus);
    return TrialInfo.fromJson(res.requiredBody);
  }
}
