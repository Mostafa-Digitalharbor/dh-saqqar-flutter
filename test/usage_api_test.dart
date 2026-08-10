// `GET /api/v1/usage/` — the shape the app reads its plan from.
//
// Two things are pinned here, both found against production on 2026-08-04.
//
// 1. **`exempt` and `features` live inside `windows`, not at the root.** The
//    client read them from the root, got null, and fed PlanCubit a snapshot
//    that said "not exempt, every feature locked" — on an account whose real
//    payload had `exempt: true` and all four features on. It only looked fine
//    because opening a chat overwrites the cubit moments later with the
//    correctly-shaped object from the conversation snapshot.
//
// 2. **`status` / `cycle` / `expires_at` are new** (API_MOBILE_SUBSCRIPTION.md
//    §1) and are the only way the app can answer "when does this renew?".
//
// The fixture below is the verbatim shape production returned, trimmed.

import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saqqar_app/features/billing/data/usage_api.dart';

class _StubAdapter implements HttpClientAdapter {
  _StubAdapter(this.body);
  final Object body;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async =>
      ResponseBody.fromString(
        jsonEncode(body),
        200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );

  @override
  void close({bool force = false}) {}
}

UsageApi _apiReturning(Object body) =>
    UsageApi(Dio()..httpClientAdapter = _StubAdapter(body));

/// The live payload, trimmed to what the parser touches.
const _production = {
  'ok': true,
  'plan': 'max-20x',
  'plan_name': 'Business',
  'status': 'active',
  'cycle': 'monthly',
  'expires_at': null,
  'windows': {
    'plan': 'max-20x',
    'plan_name': 'Business',
    'exempt': true,
    'token_balance': 1250000000,
    'day': {'used': 2315832, 'cap': 212500000, 'pct': 1, 'remaining': 210184168},
    'week': {'used': 2315832, 'cap': 170000000, 'pct': 1, 'remaining': 167684168},
    'month': {'used': 28634504, 'cap': 170000000, 'pct': 17, 'remaining': 141365496},
    'features': {
      'voice': true,
      'postgres': true,
      'github': true,
      'server_shell': true,
    },
  },
};

void main() {
  group('UsageApi.fetch reads the nested level, not the root', () {
    test('exempt comes from windows', () async {
      final plan = (await _apiReturning(_production).fetch()).plan;
      expect(
        plan.exempt,
        isTrue,
        reason: 'read from the root this is null → false, and an exempt staff '
            'account silently gets treated as capped',
      );
    });

    test('features come from windows', () async {
      final plan = (await _apiReturning(_production).fetch()).plan;
      for (final key in const ['voice', 'postgres', 'github', 'server_shell']) {
        expect(
          plan.features.enabled(key),
          isTrue,
          reason: '$key read as locked — the root has no `features` key',
        );
      }
    });

    test('the three windows still parse', () async {
      final plan = (await _apiReturning(_production).fetch()).plan;
      expect(plan.month.used, 28634504);
      expect(plan.month.cap, 170000000);
      expect(plan.month.pct, 17);
    });

    test('token_balance comes through', () async {
      final plan = (await _apiReturning(_production).fetch()).plan;
      expect(plan.tokenBalance, 1250000000);
    });
  });

  group('subscription fields', () {
    test('status and cycle are read from the root', () async {
      final plan = (await _apiReturning(_production).fetch()).plan;
      expect(plan.status, 'active');
      expect(plan.cycle, 'monthly');
    });

    test('a null expires_at yields null, not an epoch date', () async {
      // Free / never-paid accounts get null by design. Rendering 1970 here
      // would be a renewal date the user could act on and that never existed.
      final plan = (await _apiReturning(_production).fetch()).plan;
      expect(plan.expiresAt, isNull);
    });

    test('a real expires_at parses to local time', () async {
      final plan = (await _apiReturning({
        ..._production,
        'expires_at': '2027-03-04T10:00:00+00:00',
      }).fetch()).plan;
      expect(plan.expiresAt, isNotNull);
      expect(plan.expiresAt!.toUtc().year, 2027);
      expect(plan.expiresAt!.toUtc().month, 3);
    });

    test('a cycle with no period end is not a subscription', () async {
      // Exactly the live staff-account shape: `cycle: "monthly"`,
      // `expires_at: null`, nothing ever purchased. The card must not print
      // "Monthly" on its own — that tells the user they are on a billing
      // cycle they have never been billed for. The suppression lives in
      // `plan_usage_card._subscriptionLine`; this pins the inputs it keys on.
      final plan = (await _apiReturning(_production).fetch()).plan;
      expect(plan.cycle, 'monthly');
      expect(plan.expiresAt, isNull);
      expect(plan.status, 'active', reason: 'nothing needing attention');
    });

    test('an older server with none of the new fields still parses', () async {
      // The chat-snapshot path carries no subscription fields at all; the
      // model must not require them.
      final plan = (await _apiReturning({
        'ok': true,
        'plan': 'free',
        'windows': {
          'exempt': false,
          'day': {'used': 0, 'cap': 625000, 'pct': 0, 'remaining': 625000},
        },
      }).fetch()).plan;
      expect(plan.slug, 'free');
      expect(plan.status, isEmpty);
      expect(plan.cycle, isEmpty);
      expect(plan.expiresAt, isNull);
      expect(plan.day.cap, 625000);
    });
  });
}
