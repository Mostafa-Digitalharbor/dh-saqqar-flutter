import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../../core/network/api_endpoints.dart';
import '../../../core/network/response_body.dart';
import 'plan_models.dart';
import 'saqqar_features.dart';

/// Everything one `GET /api/v1/usage/` call yields.
///
/// The two halves come from different objects on the wire and have different
/// lifetimes downstream — [plan] is also supplied by every conversation
/// snapshot, while [saqqarFeatures] exists ONLY here. Returning them together
/// keeps that a single request; keeping them as separate fields stops a chat
/// snapshot's plan from overwriting flags it never carried.
@immutable
class UsageSnapshot {
  const UsageSnapshot({required this.plan, required this.saqqarFeatures});

  final PlanSnapshot plan;
  final SaqqarFeatures saqqarFeatures;
}

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

  Future<UsageSnapshot> fetch() async {
    final res = await _dio.get<Map<String, dynamic>>(ApiEndpoints.usage);
    // Never `?? {}`. Every field below is read with a null-tolerant default,
    // so a missing body would produce a complete, plausible, entirely
    // invented snapshot: the `free` plan, not exempt, all features off, and
    // three usage windows of 0/0. The Account screen renders that without a
    // single hint that nothing was actually read — a paying account shown as
    // free, with no retry offered.
    final body = res.requiredBody;
    final windows =
        (body['windows'] as Map?)?.cast<String, dynamic>() ?? const {};

    // `exempt` and `features` live INSIDE `windows`, not at the root — read
    // from the root and they come back null, which silently means "not
    // exempt, every feature locked". Verified against production 2026-08-04:
    // an account with `windows.exempt: true` and all four features on was
    // being fed into PlanCubit as exempt-false with everything off, every
    // time the Account screen opened. Masked in practice only because a chat
    // snapshot overwrites it with the correct object moments later.
    //
    // Root wins where the server sends both (`plan`, `plan_name`) — the root
    // pair is the documented one in API_MOBILE_SUBSCRIPTION.md §1; `windows`
    // repeats them for the chat-snapshot shape.
    Object? pick(String key) => body[key] ?? windows[key];

    return UsageSnapshot(
      plan: PlanSnapshot.fromJson({
        'plan': pick('plan'),
        'plan_name': pick('plan_name'),
        'exempt': windows['exempt'],
        'features': windows['features'],
        'token_balance': windows['token_balance'],
        // Subscription state — root-level only, and new as of the 2026-08-04
        // API doc. Null on a free/never-paid account by design.
        'status': body['status'],
        'cycle': body['cycle'],
        'expires_at': body['expires_at'],
        'day': windows['day'],
        'week': windows['week'],
        'month': windows['month'],
      }),
      // Top level, and ONLY here — deliberately a different object from
      // `windows.features` so billing entitlement and feature availability
      // never collide. Absent on a server that predates the 2026-08-06
      // deploy, which reads as "unknown" rather than "everything off".
      // `as Map?` would THROW on any non-map value, and this parse sits in
      // front of the whole usage snapshot — a single malformed field would
      // take out the plan, the quota bars and the subscription state along
      // with the flags. A pattern match degrades to "unknown" instead.
      saqqarFeatures: SaqqarFeatures.fromJson(
        switch (body['saqqar_features']) {
          final Map<dynamic, dynamic> m => m.cast<String, dynamic>(),
          _ => null,
        },
      ),
    );
  }
}
