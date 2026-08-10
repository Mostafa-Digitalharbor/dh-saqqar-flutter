// `saqqar_features` — the object the web team added to `GET /api/v1/usage/`
// on 2026-08-06, and the cubit that holds it.
//
// The whole reason this needs its own file is a lifetime problem that no
// amount of testing `ChatFeatures` in isolation would catch:
//
//   * `saqqar_features` ships ONLY on `/api/v1/usage/`.
//   * `PlanCubit` — the obvious place to put it — is replaced wholesale by
//     every conversation snapshot on a 1.5 s poll, and the snapshot's `plan`
//     object does not carry these flags.
//
// Store them together and the tools rows light up on an Account visit and
// blink out one poll after the user opens a chat. `SaqqarFeaturesCubit`
// exists to give them a separate lifetime, and the tests below pin the
// behaviours that make it worth having.

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saqqar_app/features/billing/data/plan_models.dart';
import 'package:saqqar_app/features/billing/data/saqqar_features.dart';
import 'package:saqqar_app/features/billing/data/usage_api.dart';
import 'package:saqqar_app/features/billing/view_model/plan_cubit.dart';
import 'package:saqqar_app/features/billing/view_model/saqqar_features_cubit.dart';

class _StubAdapter implements HttpClientAdapter {
  _StubAdapter(this.body, {this.status = 200});

  final Object body;
  final int status;

  /// How many times the endpoint was actually hit — the `ensureLoaded`
  /// tests are about NOT hitting it.
  int calls = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    calls++;
    if (status >= 400) {
      throw DioException(
        requestOptions: options,
        response: Response(requestOptions: options, statusCode: status),
        type: DioExceptionType.badResponse,
      );
    }
    return ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

/// Holds the response open until [release], so a test can interleave a
/// `clear()` between the request going out and the answer coming back.
class _SlowAdapter implements HttpClientAdapter {
  _SlowAdapter(this.body);

  final Object body;
  final _gate = Completer<void>();

  void release() => _gate.complete();

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    await _gate.future;
    return ResponseBody.fromString(
      jsonEncode(body),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

/// The sample response from the web team's doc, verbatim in shape: a regular
/// non-staff account, where most flags really are `false` today.
const _production = {
  'ok': true,
  'plan': 'free',
  'plan_name': 'Free',
  'status': 'active',
  'saqqar_features': {
    'voice_support': false,
    'task_prep': true,
    'prompt_bank': true,
    'business_pulse': false,
    'health_radar': false,
    'what_if': false,
    'collection_note': false,
    'version_awareness': false,
    'module_management': false,
    'report_builder': false,
  },
  'windows': {
    'plan': 'free',
    'plan_name': 'Free',
    'exempt': false,
    'token_balance': 0,
    'day': {'used': 0, 'cap': 0, 'pct': 0, 'remaining': 0},
    'features': {
      'voice': false,
      'postgres': false,
      'github': false,
      'server_shell': false,
    },
  },
};

void main() {
  group('UsageApi reads saqqar_features off the ROOT', () {
    test('the documented payload parses both halves', () async {
      final adapter = _StubAdapter(_production);
      final usage =
          await UsageApi(Dio()..httpClientAdapter = adapter).fetch();

      // Availability — top level.
      expect(usage.saqqarFeatures.known, isTrue);
      expect(usage.saqqarFeatures.enabled('task_prep'), isTrue);
      expect(usage.saqqarFeatures.enabled('health_radar'), isFalse);
      expect(usage.saqqarFeatures.has('health_radar'), isTrue);

      // Billing entitlement — inside `windows`. Still parsed, still separate.
      expect(usage.plan.slug, 'free');
      expect(usage.plan.features.voice, isFalse);
    });

    test('the two objects do NOT bleed into one another', () {
      // The concrete failure this prevents: reading availability out of the
      // billing bag (what the app did before) or vice versa. Both bags carry
      // a "voice"-ish key with different meanings.
      const body = {
        'plan': 'pro',
        'saqqar_features': {'voice_support': true},
        'windows': {
          'features': {'voice': false},
        },
      };
      final adapter = _StubAdapter(body);

      return UsageApi(Dio()..httpClientAdapter = adapter).fetch().then((u) {
        expect(u.saqqarFeatures.enabled('voice_support'), isTrue);
        expect(u.saqqarFeatures.enabled('voice'), isFalse,
            reason: 'billing voice must not leak into availability');
        expect(u.plan.features.voice, isFalse);
        expect(u.plan.features.enabled('voice_support'), isFalse,
            reason: 'availability must not leak into billing');
      });
    });

    test('a server without the field yields UNKNOWN, not "all off"', () async {
      // Every deploy before 2026-08-06, and any rollback. Unknown lets the
      // optimistic gates keep working controls visible; "all off" would hide
      // the task-prep toggle from everyone.
      final adapter = _StubAdapter(const {
        'plan': 'pro',
        'windows': {'exempt': false},
      });
      final usage =
          await UsageApi(Dio()..httpClientAdapter = adapter).fetch();

      expect(usage.saqqarFeatures.known, isFalse);
    });

    test('a non-object saqqar_features degrades to unknown', () async {
      final adapter = _StubAdapter(const {
        'plan': 'pro',
        'saqqar_features': 'nope',
        'windows': {'exempt': false},
      });
      final usage =
          await UsageApi(Dio()..httpClientAdapter = adapter).fetch();

      expect(usage.saqqarFeatures.known, isFalse);
    });
  });

  group('SaqqarFeaturesCubit', () {
    test('starts unknown', () {
      final cubit = SaqqarFeaturesCubit(UsageApi(Dio()));

      expect(cubit.state.known, isFalse);
      expect(cubit.state, SaqqarFeatures.unknown);
    });

    test('ensureLoaded fetches once and caches', () async {
      final adapter = _StubAdapter(_production);
      final cubit =
          SaqqarFeaturesCubit(UsageApi(Dio()..httpClientAdapter = adapter));

      await cubit.ensureLoaded();
      await cubit.ensureLoaded();
      await cubit.ensureLoaded();

      expect(adapter.calls, 1,
          reason: 'called from every chat open — must not be one request each');
      expect(cubit.state.enabled('task_prep'), isTrue);
    });

    test('force refetches', () async {
      final adapter = _StubAdapter(_production);
      final cubit =
          SaqqarFeaturesCubit(UsageApi(Dio()..httpClientAdapter = adapter));

      await cubit.ensureLoaded();
      await cubit.ensureLoaded(force: true);

      expect(adapter.calls, 2);
    });

    test('concurrent calls collapse into one request', () async {
      final adapter = _StubAdapter(_production);
      final cubit =
          SaqqarFeaturesCubit(UsageApi(Dio()..httpClientAdapter = adapter));

      // Two chats opening in the same frame — the realistic race.
      await Future.wait([cubit.ensureLoaded(), cubit.ensureLoaded()]);

      expect(adapter.calls, 1);
    });

    test('a failed fetch stays quiet and leaves the state alone', () async {
      final adapter = _StubAdapter(const {}, status: 500);
      final cubit =
          SaqqarFeaturesCubit(UsageApi(Dio()..httpClientAdapter = adapter));

      // Must not throw: this runs from a chat screen the user opened to do
      // something else entirely, and gating is cosmetic — the server refuses
      // a disabled feature whatever the client renders.
      await cubit.ensureLoaded();

      expect(cubit.state.known, isFalse);
    });

    test('a later failure does not revert a good answer', () async {
      final good = _StubAdapter(_production);
      final api = UsageApi(Dio()..httpClientAdapter = good);
      final cubit = SaqqarFeaturesCubit(api);
      await cubit.ensureLoaded();
      expect(cubit.state.enabled('task_prep'), isTrue);

      // A transient 500 on a forced refresh must not restyle the tools sheet.
      final bad = SaqqarFeaturesCubit(
        UsageApi(Dio()..httpClientAdapter = _StubAdapter(const {}, status: 500)),
      );
      await bad.ensureLoaded();
      expect(cubit.state.enabled('task_prep'), isTrue);
    });

    test('update() ignores an unknown, so a partial caller cannot blank it',
        () async {
      final adapter = _StubAdapter(_production);
      final cubit =
          SaqqarFeaturesCubit(UsageApi(Dio()..httpClientAdapter = adapter));
      await cubit.ensureLoaded();

      cubit.update(SaqqarFeatures.unknown);

      expect(cubit.state.enabled('task_prep'), isTrue);
    });

    test('signing out MID-FETCH does not leak the old account\'s flags',
        () async {
      // The race: `clear()` runs on sign-out, then the in-flight `/usage/`
      // response lands and emits user A's staff-only rows into user B's
      // session. The cubit is app-scoped and never closed, so `isClosed`
      // cannot catch this one.
      final adapter = _SlowAdapter(_production);
      final cubit =
          SaqqarFeaturesCubit(UsageApi(Dio()..httpClientAdapter = adapter));

      final pending = cubit.ensureLoaded();
      cubit.clear(); // user signs out while the request is out
      adapter.release();
      await pending;

      expect(
        cubit.state.known,
        isFalse,
        reason: "the previous account's flags must not survive a sign-out",
      );
    });

    test('a fetch started AFTER the clear still lands', () async {
      // The generation guard must not wedge the cubit permanently.
      final adapter = _StubAdapter(_production);
      final cubit =
          SaqqarFeaturesCubit(UsageApi(Dio()..httpClientAdapter = adapter));

      cubit.clear();
      await cubit.ensureLoaded();

      expect(cubit.state.enabled('task_prep'), isTrue);
    });

    test('clear() drops the previous account\'s rows', () async {
      final adapter = _StubAdapter(_production);
      final cubit =
          SaqqarFeaturesCubit(UsageApi(Dio()..httpClientAdapter = adapter));
      await cubit.ensureLoaded();

      cubit.clear();

      // Staff-only rows must not survive a sign-out into the next account.
      expect(cubit.state.known, isFalse);
    });

    test('emits only on a real change — the poll must not churn the UI', () {
      final cubit = SaqqarFeaturesCubit(UsageApi(Dio()));
      final seen = <SaqqarFeatures>[];
      final sub = cubit.stream.listen(seen.add);

      const flags = SaqqarFeatures({'task_prep': true});
      cubit.update(flags);
      cubit.update(const SaqqarFeatures({'task_prep': true}));

      return Future<void>.delayed(Duration.zero, () {
        sub.cancel();
        expect(seen, hasLength(1),
            reason: 'value equality, so an identical refetch is a no-op');
      });
    });
  });

  group('the two holders keep separate lifetimes', () {
    test('a chat snapshot replacing the plan does not touch the flags',
        () async {
      // THE regression this whole design exists for. A conversation snapshot
      // carries a `plan` object and no `saqqar_features`; if the flags lived
      // on PlanSnapshot, this sequence would wipe them 1.5 s after the user
      // opened a chat.
      final adapter = _StubAdapter(_production);
      final features =
          SaqqarFeaturesCubit(UsageApi(Dio()..httpClientAdapter = adapter));
      final plan = PlanCubit();
      await features.ensureLoaded();

      // Now a poll lands with a snapshot-shaped plan — no saqqar_features.
      plan.update(
        PlanSnapshotFixture.fromSnapshot(),
      );

      expect(features.state.enabled('task_prep'), isTrue);
      expect(features.state.known, isTrue);
    });
  });
}

/// A `plan` object shaped the way a conversation snapshot sends it — which is
/// to say, with no `saqqar_features` anywhere in it.
abstract final class PlanSnapshotFixture {
  static PlanSnapshot fromSnapshot() => PlanSnapshot.fromJson(const {
        'plan': 'pro',
        'plan_name': 'Pro',
        'exempt': false,
        'features': {'voice': true},
        'day': {'used': 10, 'cap': 100, 'pct': 10, 'remaining': 90},
      });
}
