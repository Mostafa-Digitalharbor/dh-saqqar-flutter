import 'package:dio/dio.dart';

import '../../../core/network/api_endpoints.dart';
import 'plan_models.dart';

/// Reads token usage + caps directly from `GET /api/v1/usage/` (§9).
///
/// Until now the app only learned the plan/usage from a conversation
/// snapshot's `plan` object — so the Account screen showed real usage bars
/// ONLY after the user opened a chat. This endpoint lets any screen pull
/// usage on demand (e.g. Account open / pull-to-refresh) and feed the
/// app-wide [PlanCubit].
///
/// The wire shape differs from the snapshot's `plan` object — `/usage/`
/// nests the three windows under `windows` and reports `plan` as a bare
/// slug — so [fetch] re-keys it into the [PlanSnapshot] shape rather than
/// inventing a second model the rest of the app would have to special-case.
class UsageApi {
  UsageApi(this._dio);

  final Dio _dio;

  Future<PlanSnapshot> fetch() async {
    final res = await _dio.get<Map<String, dynamic>>(ApiEndpoints.usage);
    final body = res.data ?? const <String, dynamic>{};
    final windows =
        (body['windows'] as Map?)?.cast<String, dynamic>() ?? const {};
    return PlanSnapshot.fromJson({
      'plan': body['plan'],
      'plan_name': body['plan_name'],
      'exempt': body['exempt'],
      'features': body['features'],
      'day': windows['day'],
      'week': windows['week'],
      'month': windows['month'],
    });
  }
}
