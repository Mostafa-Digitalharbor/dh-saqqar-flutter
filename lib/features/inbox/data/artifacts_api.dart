import 'package:dio/dio.dart';

import '../../../core/network/api_endpoints.dart';
import '../../../core/network/response_body.dart';
import 'artifact_models.dart';

/// Repository for the flat Files feed (SAQQAR_MOBILE_API.md §9). Artifacts
/// inside a conversation snapshot come through [ConversationsApi] — this
/// surface drives the cross-conversation Files tab.
class ArtifactsApi {
  ArtifactsApi(this._dio);

  final Dio _dio;

  /// `GET /api/v1/artifacts/?limit=&offset=` — paginated list across all
  /// conversations. Returns up to 100 per page (server cap).
  Future<ArtifactsPage> list({int limit = 30, int offset = 0}) async {
    final res = await _dio.get<Map<String, dynamic>>(
      ApiEndpoints.artifacts,
      queryParameters: {'limit': limit, 'offset': offset},
    );
    return ArtifactsPage.fromJson(res.data!);
  }

  /// `GET /api/v1/artifacts/<id>/` — one artifact's detail/metadata
  /// (API_MOBILE_NEW_ENDPOINTS.md §4.4). Tolerates both a bare artifact
  /// object and an `{ artifact: {…} }` envelope so a minor server-shape
  /// choice doesn't break the parse.
  Future<Artifact> detail(String id) async {
    final res = await _dio.get<Map<String, dynamic>>(
      ApiEndpoints.artifactDetail(id),
    );
    final body = res.requiredBody;
    final obj = (body['artifact'] as Map?)?.cast<String, dynamic>() ?? body;
    return Artifact.fromJson(obj);
  }
}
