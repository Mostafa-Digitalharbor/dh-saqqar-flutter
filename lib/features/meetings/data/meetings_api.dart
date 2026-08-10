import 'package:dio/dio.dart';

import '../../../core/network/api_endpoints.dart';
import '../../../core/network/response_body.dart';

/// Thin client for the Vexa meeting-transcription endpoints
/// (API_MOBILE_NEW_ENDPOINTS.md §4.1).
///
/// DATA LAYER ONLY — there is no meetings UI surface yet. The endpoints are
/// already live server-side, so this client is the adoption seam: a future
/// meetings feature builds its models + cubit on top without a backend
/// change. Returns raw decoded JSON so shaping happens when the UI lands.
///
/// Requests go through [JsonRequests], which fails on a response that
/// carried no body. The hand-rolled `_post` this replaced answered `{}`
/// instead — and because these methods return raw maps rather than typed
/// models, that empty map would reach the future UI as a real (blank)
/// transcript rather than as an error, with nothing left to trace it back
/// to. The same helper is shared with [OdooDataApi], which had a
/// byte-identical copy of it.
class MeetingsApi {
  MeetingsApi(this._dio);

  final Dio _dio;

  /// `POST /api/v1/meetings/` — start a meeting transcription.
  Future<Map<String, dynamic>> start(Map<String, dynamic> body) =>
      _dio.postJson(ApiEndpoints.meetings, data: body);

  /// `GET /api/v1/meetings/<id>/transcript` — fetch the transcript.
  Future<Map<String, dynamic>> transcript(String id) =>
      _dio.getJson(ApiEndpoints.meetingTranscript(id));

  /// `POST /api/v1/meetings/<id>/stop` — stop the meeting.
  Future<Map<String, dynamic>> stop(String id) =>
      _dio.postJson(ApiEndpoints.meetingStop(id), data: const {});

  /// `POST /api/v1/meetings/<id>/summarize` — summarize the meeting.
  Future<Map<String, dynamic>> summarize(String id) =>
      _dio.postJson(ApiEndpoints.meetingSummarize(id), data: const {});

  /// `POST /api/v1/meetings/<id>/chat` — chat over the transcript.
  Future<Map<String, dynamic>> chat(String id, Map<String, dynamic> body) =>
      _dio.postJson(ApiEndpoints.meetingChat(id), data: body);
}
