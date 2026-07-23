import 'package:dio/dio.dart';

import '../../../core/network/api_endpoints.dart';
import 'app_package_models.dart';

/// Reads and launches the guided Saqqar Apps (API_MOBILE_NEW_ENDPOINTS.md
/// §1). Returns typed models; the interceptor stack in [buildDio] turns
/// wire errors into `ApiException` for the cubit to map.
class AppsApi {
  AppsApi(this._dio);

  final Dio _dio;

  /// `GET /api/v1/apps/` — the full package catalogue.
  Future<List<SaqqarApp>> list() async {
    final res = await _dio.get<Map<String, dynamic>>(ApiEndpoints.apps);
    return (res.data?['apps'] as List? ?? const [])
        .cast<Map<String, dynamic>>()
        .map(SaqqarApp.fromJson)
        .toList();
  }

  /// `POST /api/v1/apps/<slug>/launch/` — creates the package-tagged
  /// conversation and returns its id. [environmentId] binds an owned
  /// environment; anything the server can't honour (null / not owned) is
  /// ignored and the agent asks the user to pick one in-chat.
  Future<String> launch(String slug, {String? environmentId}) async {
    final res = await _dio.post<Map<String, dynamic>>(
      ApiEndpoints.appLaunch(slug),
      data: {
        if (environmentId != null && environmentId.isNotEmpty)
          'environment_id': environmentId,
      },
    );
    final id = res.data?['conversation_id'] as String?;
    if (id == null || id.isEmpty) {
      // Contract violation — surface it rather than routing to /chats/ with
      // an empty id (which would open a broken "new chat" sentinel).
      throw StateError('apps/$slug/launch/ returned no conversation_id');
    }
    return id;
  }
}
