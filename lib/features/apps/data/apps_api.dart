import 'package:dio/dio.dart';

import '../../../core/network/api_endpoints.dart';
import '../../../core/network/response_body.dart';
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
    // A bodiless 200 used to render the Apps screen's "no apps" empty state.
    // The catalogue is server-owned and never legitimately empty, so that
    // was always a failure wearing an empty state's clothes.
    return (res.requiredBody['apps'] as List? ?? const [])
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
    final id = res.requiredBody['conversation_id'] as String?;
    if (id == null || id.isEmpty) {
      // Contract violation — surface it rather than routing to /chats/ with
      // an empty id (which would open a broken "new chat" sentinel).
      //
      // A FormatException, not a StateError: `ApiErrorMapper` classifies it
      // as `ParseFailure` → "unexpected response from the server", which is
      // exactly what happened. A StateError fell through to `UnknownFailure`
      // ("something went wrong, please try again"), which invites a retry
      // that replays the same contract violation forever.
      throw const FormatException('apps launch returned no conversation_id');
    }
    return id;
  }
}
