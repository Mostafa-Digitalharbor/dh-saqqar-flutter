import 'package:dio/dio.dart';

import '../network/api_endpoints.dart';

/// Remote i18n bundle (SAQQAR_MOBILE_API.md §13). Public, no auth, cached
/// `public, max-age=3600` server-side. Mobile keeps a local cache and only
/// re-fetches when the cache expires or the user switches language.
///
/// The local [AppStrings] map remains the source of truth for offline +
/// cold-start. The remote bundle is a *layer on top* used to push string
/// updates between app releases — when the remote bundle has a key the
/// local map doesn't, it wins.
class RemoteI18nApi {
  RemoteI18nApi(this._dio);

  final Dio _dio;

  /// `GET /api/v1/i18n/<lang>.json` — returns the full string table for
  /// the language. 404 on unknown languages.
  Future<Map<String, String>> getBundle(String lang) async {
    final res = await _dio.get<Map<String, dynamic>>(
      ApiEndpoints.i18n(lang),
      options: Options(extra: const {'skipAuth': true}),
    );
    final strings = res.data!['strings'] as Map<String, dynamic>? ?? const {};
    return strings.map((key, value) => MapEntry(key, value.toString()));
  }
}
