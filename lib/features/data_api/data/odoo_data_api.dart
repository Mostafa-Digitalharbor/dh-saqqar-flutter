import 'package:dio/dio.dart';

import '../../../core/error/app_failure.dart';
import '../../../core/network/api_endpoints.dart';
import '../../../core/network/response_body.dart';

/// Thin client for the deterministic, read-only Odoo data endpoints
/// (API_MOBILE_NEW_ENDPOINTS.md §4.2).
///
/// These read a bound environment directly (search / count / read-group /
/// read / fields / SQL) WITHOUT an agent turn — no LLM cost, fully
/// deterministic. DATA LAYER ONLY for now: the endpoints are live
/// server-side, so this client is the adoption seam for a future
/// reports/dashboards surface. Bodies/results are raw JSON so the caller
/// shapes them when a UI is built.
///
/// Requests go through [JsonRequests] rather than a private `_post` — the
/// helper this file used to own was byte-identical to `MeetingsApi`'s, down
/// to the `res.data ?? const {}` that turned a bodiless response into an
/// empty result set. For a *count* or a *search* that is the most damaging
/// possible default: zero rows is a legitimate answer, so nothing
/// downstream could tell it apart from a real one.
class OdooDataApi {
  OdooDataApi(this._dio);

  final Dio _dio;

  /// `POST /environments/<envId>/odoo/search/` — search records.
  Future<Map<String, dynamic>> search(String envId, Map<String, dynamic> q) =>
      _odoo(() => _dio.postJson(ApiEndpoints.odooSearch(envId), data: q));

  /// `POST /environments/<envId>/odoo/count/` — count records.
  Future<Map<String, dynamic>> count(String envId, Map<String, dynamic> q) =>
      _odoo(() => _dio.postJson(ApiEndpoints.odooCount(envId), data: q));

  /// `POST /environments/<envId>/odoo/read-group/` — grouped aggregates.
  Future<Map<String, dynamic>> readGroup(
    String envId,
    Map<String, dynamic> q,
  ) => _odoo(() => _dio.postJson(ApiEndpoints.odooReadGroup(envId), data: q));

  /// `POST /environments/<envId>/odoo/read/` — read records by id.
  Future<Map<String, dynamic>> read(String envId, Map<String, dynamic> q) =>
      _odoo(() => _dio.postJson(ApiEndpoints.odooRead(envId), data: q));

  /// `POST /environments/<envId>/odoo/fields/` — field metadata.
  Future<Map<String, dynamic>> fields(String envId, Map<String, dynamic> q) =>
      _odoo(() => _dio.postJson(ApiEndpoints.odooFields(envId), data: q));

  /// `POST /environments/<envId>/sql/` — read-only SQL.
  Future<Map<String, dynamic>> sql(String envId, Map<String, dynamic> q) =>
      _odoo(() => _dio.postJson(ApiEndpoints.envSql(envId), data: q));

  /// Turns a gateway 5xx into [OdooUnreachableFailure].
  ///
  /// Every call above reaches through Saqqar into the customer's own Odoo, so
  /// a 502/504 here does not mean Saqqar is unwell — it means that database
  /// did not answer. Verified against the live server on 2026-09-08: one
  /// environment returned a 502 with an HTML maintenance page and no JSON
  /// message at all, which the generic mapper could only render as "the
  /// server had a problem, try again later". That points the user at us, and
  /// the only action it offers is waiting.
  ///
  /// Anything else is rethrown untouched: a 400 is still a bad query and a
  /// 403 is still a permission problem, and relabelling those would be
  /// trading one wrong explanation for another.
  static Future<T> _odoo<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on DioException catch (e) {
      final code = e.response?.statusCode;
      if (code == 502 || code == 504) {
        throw OdooUnreachableFailure(statusCode: code);
      }
      rethrow;
    }
  }

  /// `GET /report-entities/?conversation_id=<id>` — entity list for the
  /// report filter.
  ///
  /// Conversation-scoped, not environment-scoped: a bare call answers
  /// `400 conversation_id is required and must belong to you`.
  Future<Map<String, dynamic>> reportEntities(Map<String, dynamic> q) =>
      _dio.getJson(ApiEndpoints.reportEntities, queryParameters: q);
}
