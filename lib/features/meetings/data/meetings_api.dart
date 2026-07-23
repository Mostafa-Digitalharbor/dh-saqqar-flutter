import 'package:dio/dio.dart';

import '../../../core/network/api_endpoints.dart';

/// Thin client for the Vexa meeting-transcription endpoints
/// (API_MOBILE_NEW_ENDPOINTS.md §4.1).
///
/// DATA LAYER ONLY — there is no meetings UI surface yet. The endpoints are
/// already live server-side, so this client is the adoption seam: a future
/// meetings feature builds its models + cubit on top without a backend
/// change. Returns raw decoded JSON so shaping happens when the UI lands.
class MeetingsApi {
  MeetingsApi(this._dio);

  final Dio _dio;

  /// `POST /api/v1/meetings/` — start a meeting transcription.
  Future<Map<String, dynamic>> start(Map<String, dynamic> body) =>
      _post(ApiEndpoints.meetings, body);

  /// `GET /api/v1/meetings/<id>/transcript` — fetch the transcript.
  Future<Map<String, dynamic>> transcript(String id) async {
    final res = await _dio.get<Map<String, dynamic>>(
      ApiEndpoints.meetingTranscript(id),
    );
    return res.data ?? const {};
  }

  /// `POST /api/v1/meetings/<id>/stop` — stop the meeting.
  Future<Map<String, dynamic>> stop(String id) =>
      _post(ApiEndpoints.meetingStop(id), const {});

  /// `POST /api/v1/meetings/<id>/summarize` — summarize the meeting.
  Future<Map<String, dynamic>> summarize(String id) =>
      _post(ApiEndpoints.meetingSummarize(id), const {});

  /// `POST /api/v1/meetings/<id>/chat` — chat over the transcript.
  Future<Map<String, dynamic>> chat(String id, Map<String, dynamic> body) =>
      _post(ApiEndpoints.meetingChat(id), body);

  Future<Map<String, dynamic>> _post(
    String path,
    Map<String, dynamic> body,
  ) async {
    final res = await _dio.post<Map<String, dynamic>>(path, data: body);
    return res.data ?? const {};
  }
}
