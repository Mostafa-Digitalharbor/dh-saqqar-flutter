import 'package:dio/dio.dart';

import '../../../core/network/api_endpoints.dart';
import 'shared_transcript_models.dart';

/// Public, unauthenticated read of a shared transcript
/// (SAQQAR_MOBILE_API.md §10). 404 on unknown / revoked tokens.
class SharesApi {
  SharesApi(this._dio);

  final Dio _dio;

  /// `GET /api/v1/shares/<token>/` — no bearer token attached (the
  /// `skipAuth` extra prevents the interceptor from injecting one even
  /// if the user happens to be signed in).
  Future<SharedTranscript> get(String token) async {
    final res = await _dio.get<Map<String, dynamic>>(
      ApiEndpoints.shareTranscript(token),
      options: Options(extra: const {'skipAuth': true}),
    );
    return SharedTranscript.fromJson(res.data!);
  }
}
