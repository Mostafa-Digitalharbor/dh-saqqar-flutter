import 'package:dio/dio.dart';

import '../../../core/network/api_endpoints.dart';
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
}

