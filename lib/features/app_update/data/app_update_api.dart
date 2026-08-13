import 'package:dio/dio.dart';

import '../../../core/logging/app_logger.dart';
import '../../../core/network/api_endpoints.dart';
import '../../../core/network/response_body.dart';
import '../../push/data/devices_api.dart' show DevicePlatform;
import 'app_update_status.dart';

/// Reads `GET /api/v1/app/version/` — "is the build on this phone still one
/// you support, and is there a newer one on the store?"
///
/// The only client in the app that swallows its own errors and returns
/// `null`. Everywhere else that would be the "false success" antipattern
/// `response_body.dart` exists to stamp out, and the distinction matters:
///
///  * A client that returns `{}` for an absent body **invents an answer** —
///    a free plan on a paying account, an empty pricing page.
///  * This one returns `null`, which is not an answer at all. `null` maps to
///    [AppUpdateDecision.none], which is byte-for-byte the behaviour the app
///    has today with no gate wired at all.
///
/// That matters because the endpoint **does not exist yet**. Every call is a
/// 404 until the backend ships it, and a 404 must be indistinguishable from
/// "nothing to report" or the app would be unusable the moment this lands.
///
/// [DevicePlatform] is reused rather than re-spelling `'android'` / `'ios'`
/// — the push device registry already pins those wire values, and two
/// spellings of the same enum is how one of them drifts.
class AppUpdateApi {
  AppUpdateApi(this._dio);

  final Dio _dio;

  /// The backend's opinion, or `null` when it has none it can express.
  Future<AppUpdateStatus?> fetch(DevicePlatform platform) async {
    try {
      final body = await _dio.getJson(
        ApiEndpoints.appVersion,
        queryParameters: {'platform': platform.wire},
      );
      return AppUpdateStatus.fromJson(body);
    } catch (error, stackTrace) {
      // warn, never error: the expected steady state until the endpoint
      // ships is a 404, and `_shouldSkipSentry` in main.dart already drops
      // 4xx, so this stays out of the dashboard without a second filter here.
      AppLogger.warn(
        'AppUpdateApi',
        'version check unavailable',
        error: error,
        stackTrace: stackTrace,
      );
      return null;
    }
  }
}
