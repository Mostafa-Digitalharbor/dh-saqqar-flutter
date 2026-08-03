import 'package:dio/dio.dart';

import '../../../core/network/api_endpoints.dart';

/// Thin client for the deterministic, read-only Odoo data endpoints
/// (API_MOBILE_NEW_ENDPOINTS.md §4.2).
///
/// These read a bound environment directly (search / count / read-group /
/// read / fields / SQL) WITHOUT an agent turn — no LLM cost, fully
/// deterministic. DATA LAYER ONLY for now: the endpoints are live
/// server-side, so this client is the adoption seam for a future
/// reports/dashboards surface. Bodies/results are raw JSON so the caller
/// shapes them when a UI is built.
class OdooDataApi {
  OdooDataApi(this._dio);

  final Dio _dio;

  /// `POST /environments/<envId>/odoo/search/` — search records.
  Future<Map<String, dynamic>> search(String envId, Map<String, dynamic> q) =>
      _post(ApiEndpoints.odooSearch(envId), q);

  /// `POST /environments/<envId>/odoo/count/` — count records.
  Future<Map<String, dynamic>> count(String envId, Map<String, dynamic> q) =>
      _post(ApiEndpoints.odooCount(envId), q);

  /// `POST /environments/<envId>/odoo/read-group/` — grouped aggregates.
  Future<Map<String, dynamic>> readGroup(String envId, Map<String, dynamic> q) =>
      _post(ApiEndpoints.odooReadGroup(envId), q);

  /// `POST /environments/<envId>/odoo/read/` — read records by id.
  Future<Map<String, dynamic>> read(String envId, Map<String, dynamic> q) =>
      _post(ApiEndpoints.odooRead(envId), q);

  /// `POST /environments/<envId>/odoo/fields/` — field metadata.
  Future<Map<String, dynamic>> fields(String envId, Map<String, dynamic> q) =>
      _post(ApiEndpoints.odooFields(envId), q);

  /// `POST /environments/<envId>/sql/` — read-only SQL.
  Future<Map<String, dynamic>> sql(String envId, Map<String, dynamic> q) =>
      _post(ApiEndpoints.envSql(envId), q);

  /// `GET /report-entities/?conversation_id=<id>` — entity list for the
  /// report filter.
  ///
  /// Conversation-scoped, not environment-scoped: a bare call answers
  /// `400 conversation_id is required and must belong to you`.
  Future<Map<String, dynamic>> reportEntities(Map<String, dynamic> q) async {
    final res = await _dio.get<Map<String, dynamic>>(
      ApiEndpoints.reportEntities,
      queryParameters: q,
    );
    return res.data ?? const {};
  }

  Future<Map<String, dynamic>> _post(
    String path,
    Map<String, dynamic> body,
  ) async {
    final res = await _dio.post<Map<String, dynamic>>(path, data: body);
    return res.data ?? const {};
  }
}
