// The update gate — `GET /api/v1/app/version/`.
//
// The gate can take the entire installed base offline in one backend edit,
// so most of what is pinned here is not "does it block when it should" but
// "does it refuse to block when the numbers are nonsense". Each of the
// fail-open guards in `AppUpdateStatus.blocks` / `AppUpdateDecision.forBuild`
// has a test below, and each one goes red if you delete the guard it covers —
// verified by deleting them one at a time, not by assuming.

import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saqqar_app/core/i18n/app_localizations.dart';
import 'package:saqqar_app/core/i18n/app_strings.dart';
import 'package:saqqar_app/core/theme/app_theme.dart';
import 'package:saqqar_app/features/app_update/data/app_update_api.dart';
import 'package:saqqar_app/features/app_update/data/app_update_status.dart';
import 'package:saqqar_app/features/app_update/data/play_update_service.dart';
import 'package:saqqar_app/features/app_update/view/app_update_gate.dart';
import 'package:saqqar_app/features/app_update/view/update_nudge_banner.dart';
import 'package:saqqar_app/features/app_update/view/update_required_screen.dart';
import 'package:saqqar_app/features/app_update/view_model/app_update_cubit.dart';
import 'package:saqqar_app/features/push/data/devices_api.dart'
    show DevicePlatform;
import 'package:shared_preferences/shared_preferences.dart';

/// Answers every request with [status] and [body], and counts the calls so
/// the throttle can be asserted on rather than inferred from timing.
class _StubAdapter implements HttpClientAdapter {
  _StubAdapter({this.body, this.status = 200});

  final Object? body;
  final int status;
  int calls = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    calls++;
    return ResponseBody.fromString(
      body == null ? '' : jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Dio _dioReturning(_StubAdapter adapter) {
  final dio = Dio(BaseOptions(baseUrl: 'https://example.invalid'));
  // Deliberately NOT `validateStatus = (_) => true`. An earlier revision set
  // that so the 404 fixture would reach `AppUpdateApi`'s catch "as a
  // response" — but production Dio throws on a 404, so the override made the
  // 404 fixture decode its `{ok: false}` body into a REAL, all-zero
  // AppUpdateStatus. Every "the endpoint is a 404" test was then exercising a
  // state production can never be in, and it hid a live bug in `targetBuild`.
  dio.httpClientAdapter = adapter;
  return dio;
}

AppUpdateStatus _status({
  int min = 100,
  int latest = 120,
  String version = '1.2.5',
  String storeUrl = 'https://play.google.com/store/apps/details?id=x',
}) {
  return AppUpdateStatus(
    minSupportedBuild: min,
    latestBuild: latest,
    latestVersion: version,
    storeUrl: storeUrl,
  );
}

/// Stands in for Play. Subclassing the real service (rather than an interface)
/// keeps the production type free of a seam that exists only for tests.
class _FakePlay extends PlayUpdateService {
  _FakePlay({this.info, this.immediateSucceeds = true, this.flexibleSucceeds = true});

  final PlayUpdateInfo? info;
  final bool immediateSucceeds;
  final bool flexibleSucceeds;

  int immediateCalls = 0;
  int flexibleCalls = 0;

  @override
  Future<PlayUpdateInfo?> check() async => info;

  @override
  Future<bool> runImmediate() async {
    immediateCalls++;
    return immediateSucceeds;
  }

  @override
  Future<bool> runFlexible() async {
    flexibleCalls++;
    return flexibleSucceeds;
  }
}

PlayUpdateInfo _play({
  int code = 130,
  bool immediate = true,
  bool flexible = true,
}) {
  return PlayUpdateInfo(
    availableVersionCode: code,
    immediateAllowed: immediate,
    flexibleAllowed: flexible,
  );
}

Future<AppUpdateCubit> _cubit({
  required _StubAdapter adapter,
  String currentBuild = '115',
  Duration throttle = Duration.zero,
  PlayUpdateService? play,
}) async {
  SharedPreferences.setMockInitialValues({});
  return AppUpdateCubit(
    api: AppUpdateApi(_dioReturning(adapter)),
    prefs: await SharedPreferences.getInstance(),
    currentBuild: currentBuild,
    platform: DevicePlatform.android,
    minRecheckInterval: throttle,
    play: play,
  );
}

/// A backend that is not there yet — the current production reality.
_StubAdapter _noBackend() => _StubAdapter(status: 404, body: {'ok': false});

void main() {
  group('The decision table', () {
    test('a build below the floor is blocked', () {
      expect(
        AppUpdateDecision.forBuild(_status(min: 116, latest: 120), '115'),
        AppUpdateDecision.required,
      );
    });

    test('a supported but stale build is only nudged', () {
      expect(
        AppUpdateDecision.forBuild(_status(min: 100, latest: 120), '115'),
        AppUpdateDecision.optional,
      );
    });

    test('the newest build is left alone', () {
      expect(
        AppUpdateDecision.forBuild(_status(min: 100, latest: 120), '120'),
        AppUpdateDecision.none,
      );
    });

    test('a build ahead of the store is left alone', () {
      // A TestFlight / internal-track tester runs a build the public store
      // has never seen. Nudging them to "update" to an older one would be
      // actively wrong.
      expect(
        AppUpdateDecision.forBuild(_status(min: 100, latest: 120), '133'),
        AppUpdateDecision.none,
      );
    });
  });

  group('The gate refuses to brick the installed base', () {
    test('a floor above the newest shipped build never blocks', () {
      // `min_supported_build: 500` with nothing above 120 on the store is a
      // typo, not a policy: no user on earth could satisfy it, and enforcing
      // it locks out 100% of installs with no in-app recovery.
      //
      // It degrades to `optional`, not `none`, and that is the correct
      // reading — `latest_build: 120` is still a true statement about the
      // store, and 115 really is behind it. The guard's job is to refuse the
      // impossible demand, not to discard the half of the payload that was
      // sane.
      final decision =
          AppUpdateDecision.forBuild(_status(min: 500, latest: 120), '115');
      expect(decision, isNot(AppUpdateDecision.required));
      expect(decision, AppUpdateDecision.optional);
    });

    test('a floor above the newest build cannot block even a current one', () {
      // The install that would actually be bricked: already on the newest
      // build the store has, and still below a bogus floor.
      expect(
        AppUpdateDecision.forBuild(_status(min: 500, latest: 120), '120'),
        AppUpdateDecision.none,
      );
    });

    test('a block with no store URL is ignored', () {
      // The wall's only affordance is the store button. Without a URL it is
      // a dead end — worse than letting a stale build carry on.
      expect(
        AppUpdateDecision.forBuild(
          _status(min: 116, latest: 120, storeUrl: ''),
          '115',
        ),
        AppUpdateDecision.none,
      );
    });

    test('an unparseable local build number is ignored', () {
      // iOS `CFBundleVersion` is free-form and can legitimately read "1.2.5",
      // and PackageInfo hands back "" when its channel call failed. Coercing
      // either to 0 puts EVERY user of that platform below EVERY floor.
      for (final raw in ['', '1.2.5', 'abc', ' ']) {
        expect(
          AppUpdateDecision.forBuild(_status(min: 116, latest: 120), raw),
          AppUpdateDecision.none,
          reason: 'build number "$raw" must not resolve to 0',
        );
      }
    });

    test('a whitespace-padded build number still parses', () {
      // The counterpart to the test above: trimming must happen, or a value
      // the platform padded would be read as unparseable and silently
      // disable the gate for everyone.
      expect(
        AppUpdateDecision.forBuild(_status(min: 116, latest: 120), ' 115 '),
        AppUpdateDecision.required,
      );
    });

    test('no server answer at all is ignored', () {
      expect(
        AppUpdateDecision.forBuild(null, '115'),
        AppUpdateDecision.none,
      );
    });
  });

  group('An unreadable response is not an answer', () {
    test('a 404 (endpoint not shipped yet) leaves the gate inert', () async {
      final adapter = _StubAdapter(status: 404, body: {'ok': false});
      final cubit = await _cubit(adapter: adapter);
      await cubit.check();
      expect(cubit.state.decision, AppUpdateDecision.none);
      expect(cubit.state.isBlocking, isFalse);
    });

    test('a 200 with no body leaves the gate inert', () async {
      // `requiredBody` throws here rather than inventing `{}`; the point is
      // that AppUpdateApi turns that throw into "no opinion" instead of
      // letting it escape and crash boot.
      final cubit = await _cubit(adapter: _StubAdapter(body: null));
      await cubit.check();
      expect(cubit.state.decision, AppUpdateDecision.none);
    });

    test('a half-understood body cannot block', () async {
      // Fields present but named differently — every absence collapses to a
      // value that cannot gate.
      final cubit = await _cubit(
        adapter: _StubAdapter(body: {'ok': true, 'minimum': 999}),
      );
      await cubit.check();
      expect(cubit.state.decision, AppUpdateDecision.none);
    });

    test('string-typed numbers are still read', () async {
      // Django REST serializers hand back ints, but a hand-written JsonResponse
      // or a config read straight from env can easily emit "118".
      final cubit = await _cubit(
        adapter: _StubAdapter(
          body: {
            'ok': true,
            'min_supported_build': '116',
            'latest_build': '120',
            'latest_version': '1.2.5',
            'store_url': 'https://play.google.com/store/apps/details?id=x',
          },
        ),
      );
      await cubit.check();
      expect(cubit.state.decision, AppUpdateDecision.required);
    });
  });

  group('Dismissing the nudge', () {
    Map<String, Object> bodyWithLatest(int latest) => {
          'ok': true,
          'min_supported_build': 100,
          'latest_build': latest,
          'latest_version': '1.2.5',
          'store_url': 'https://play.google.com/store/apps/details?id=x',
        };

    test('hides the banner and survives a restart', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final adapter = _StubAdapter(body: bodyWithLatest(120));

      final first = AppUpdateCubit(
        api: AppUpdateApi(_dioReturning(adapter)),
        prefs: prefs,
        currentBuild: '115',
        platform: DevicePlatform.android,
        minRecheckInterval: Duration.zero,
      );
      await first.check();
      expect(first.state.showsNudge, isTrue);
      await first.dismiss();
      expect(first.state.showsNudge, isFalse);

      // A fresh cubit over the same prefs is what the next cold start sees.
      final restarted = AppUpdateCubit(
        api: AppUpdateApi(_dioReturning(adapter)),
        prefs: prefs,
        currentBuild: '115',
        platform: DevicePlatform.android,
        minRecheckInterval: Duration.zero,
      );
      await restarted.check();
      expect(restarted.state.decision, AppUpdateDecision.optional);
      expect(restarted.state.showsNudge, isFalse);
    });

    test('expires when a newer build ships', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      final cubit = AppUpdateCubit(
        api: AppUpdateApi(_dioReturning(_StubAdapter(body: bodyWithLatest(120)))),
        prefs: prefs,
        currentBuild: '115',
        platform: DevicePlatform.android,
        minRecheckInterval: Duration.zero,
      );
      await cubit.check();
      await cubit.dismiss();
      expect(cubit.state.showsNudge, isFalse);

      // Same user, same prefs, but the store now has 121. Scoping the
      // dismissal to a build number is what stops the first "later" a user
      // ever taps from muting every future release.
      final afterNewRelease = AppUpdateCubit(
        api: AppUpdateApi(_dioReturning(_StubAdapter(body: bodyWithLatest(121)))),
        prefs: prefs,
        currentBuild: '115',
        platform: DevicePlatform.android,
        minRecheckInterval: Duration.zero,
      );
      await afterNewRelease.check();
      expect(afterNewRelease.state.showsNudge, isTrue);
    });

    test('a blocking gate has nothing to dismiss', () async {
      final cubit = await _cubit(
        adapter: _StubAdapter(
          body: {
            'ok': true,
            'min_supported_build': 116,
            'latest_build': 120,
            'latest_version': '1.2.5',
            'store_url': 'https://play.google.com/store/apps/details?id=x',
          },
        ),
      );
      await cubit.check();
      expect(cubit.state.isBlocking, isTrue);
      await cubit.dismiss();
      // Still blocking — `dismissed` is only ever meaningful for `optional`,
      // so a stray call cannot open a hole in the wall.
      expect(cubit.state.isBlocking, isTrue);
    });
  });

  group('The re-check does not become a poll', () {
    test('the throttle suppresses a second check', () async {
      final adapter = _StubAdapter(body: {'ok': true, 'latest_build': 120});
      final cubit = await _cubit(
        adapter: adapter,
        throttle: const Duration(hours: 6),
      );
      await cubit.check();
      await cubit.check();
      await cubit.check();
      // `resumed` fires on every app switch; without the stopwatch guard this
      // would be one request per switch, forever.
      expect(adapter.calls, 1);
    });

    test('force overrides the throttle', () async {
      final adapter = _StubAdapter(body: {'ok': true, 'latest_build': 120});
      final cubit = await _cubit(
        adapter: adapter,
        throttle: const Duration(hours: 6),
      );
      await cubit.check();
      await cubit.check(force: true);
      expect(adapter.calls, 2);
    });

    test('a blocked app stops asking', () async {
      final adapter = _StubAdapter(
        body: {
          'ok': true,
          'min_supported_build': 116,
          'latest_build': 120,
          'latest_version': '1.2.5',
          'store_url': 'https://play.google.com/store/apps/details?id=x',
        },
      );
      final cubit = await _cubit(adapter: adapter);
      await cubit.check();
      expect(cubit.state.isBlocking, isTrue);
      // Nothing behind the wall can change the answer — the only escape is an
      // install, which restarts the process.
      await cubit.check(force: true);
      expect(adapter.calls, 1);
    });
  });

  group('Play and the backend answer different questions', () {
    test('Play alone drives the nudge when the endpoint is a 404', () async {
      // This is today's production reality: /api/v1/app/version/ does not
      // exist. Play still knows an update is on the store, so the Android
      // half of the feature works before the backend ships anything.
      final cubit = await _cubit(
        adapter: _noBackend(),
        play: _FakePlay(info: _play(code: 130)),
      );
      await cubit.check();
      expect(cubit.state.decision, AppUpdateDecision.optional);
      expect(cubit.state.showsNudge, isTrue);
      expect(cubit.state.canUpdateInPlace, isTrue);
    });

    test('Play can never cause a block', () async {
      // Play only ever says "something newer exists" — it has no concept of a
      // supported floor. Promoting that to a wall would lock users out of the
      // app for an ordinary release.
      final cubit = await _cubit(
        adapter: _noBackend(),
        play: _FakePlay(info: _play(code: 130)),
      );
      await cubit.check();
      expect(cubit.state.isBlocking, isFalse);
    });

    test('an update with no permitted flow is not an offer', () async {
      // `updateAvailable` with both flows disabled in the Play console leaves
      // nothing to actually do, and the backend is happy with this build.
      final cubit = await _cubit(
        adapter: _noBackend(),
        play: _FakePlay(info: _play(immediate: false, flexible: false)),
      );
      await cubit.check();
      expect(cubit.state.decision, AppUpdateDecision.none);
    });

    test('the backend still owns the floor when Play also speaks', () async {
      final cubit = await _cubit(
        adapter: _StubAdapter(
          body: {
            'ok': true,
            'min_supported_build': 116,
            'latest_build': 120,
            'latest_version': '1.2.5',
            'store_url': 'https://play.google.com/store/apps/details?id=x',
          },
        ),
        play: _FakePlay(info: _play(code: 130)),
      );
      await cubit.check();
      expect(cubit.state.decision, AppUpdateDecision.required);
    });

    test('a Play-only dismissal keys on Play\'s version code', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      AppUpdateCubit build(int playCode) => AppUpdateCubit(
            api: AppUpdateApi(_dioReturning(_noBackend())),
            prefs: prefs,
            currentBuild: '115',
            platform: DevicePlatform.android,
            minRecheckInterval: Duration.zero,
            play: _FakePlay(info: _play(code: playCode)),
          );

      final first = build(130);
      await first.check();
      await first.dismiss();
      expect(first.state.showsNudge, isFalse);

      // Same build still hidden after a restart…
      final again = build(130);
      await again.check();
      expect(again.state.showsNudge, isFalse);

      // …but a newer one on the store speaks up. Without `targetBuild`
      // falling back to Play's code, the dismissal would have had nothing to
      // key on and the first "later" would mute every future release.
      final newer = build(131);
      await newer.check();
      expect(newer.state.showsNudge, isTrue);
    });
  });

  test('a zero latest_build does not shadow Play\'s code', () async {
    // A 200 the app only half-understands: `latest_build` absent, so
    // `fromJson` reads it as 0 (by design — a body we cannot parse must not
    // gate anyone). `status` is therefore NON-null, and a plain
    // `status?.latestBuild ?? play?.availableVersionCode` takes that 0 as the
    // answer. The dismissal then keys on 0 permanently and one "later" mutes
    // every future Android release.
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    AppUpdateCubit build(int playCode) => AppUpdateCubit(
          api: AppUpdateApi(
            _dioReturning(
              _StubAdapter(
                body: {
                  'ok': true,
                  'store_url': 'https://play.google.com/store/apps/details?id=x',
                },
              ),
            ),
          ),
          prefs: prefs,
          currentBuild: '115',
          platform: DevicePlatform.android,
          minRecheckInterval: Duration.zero,
          play: _FakePlay(info: _play(code: playCode)),
        );

    final first = build(130);
    await first.check();
    expect(first.state.targetBuild, 130, reason: 'Play named the build, not 0');
    await first.dismiss();

    final newer = build(131);
    await newer.check();
    expect(newer.state.showsNudge, isTrue);
  });

  group('Installing without leaving the app', () {
    test('a blocked build gets Google\'s blocking updater', () async {
      final play = _FakePlay(info: _play());
      final cubit = await _cubit(
        adapter: _StubAdapter(
          body: {
            'ok': true,
            'min_supported_build': 116,
            'latest_build': 120,
            'latest_version': '1.2.5',
            'store_url': 'https://play.google.com/store/apps/details?id=x',
          },
        ),
        play: play,
      );
      await cubit.check();
      expect(await cubit.launchInPlaceUpdate(), isTrue);
      // Immediate, not flexible: the app is unusable until the install lands,
      // so a background download the user can ignore is the wrong flow.
      expect(play.immediateCalls, 1);
      expect(play.flexibleCalls, 0);
    });

    test('a merely stale build downloads in the background', () async {
      final play = _FakePlay(info: _play());
      final cubit = await _cubit(adapter: _noBackend(), play: play);
      await cubit.check();
      expect(await cubit.launchInPlaceUpdate(), isTrue);
      expect(play.flexibleCalls, 1);
      expect(play.immediateCalls, 0);
    });

    test('iOS has no in-place route and says so', () async {
      // No Play service is constructed on iOS at all, so the caller falls
      // through to the store listing. A `true` here would mean the button
      // silently did nothing.
      final cubit = await _cubit(adapter: _noBackend(), play: null);
      await cubit.check();
      expect(await cubit.launchInPlaceUpdate(), isFalse);
    });

    test('a user who backs out of Play falls through to the store', () async {
      final play = _FakePlay(info: _play(), flexibleSucceeds: false);
      final cubit = await _cubit(adapter: _noBackend(), play: play);
      await cubit.check();
      expect(await cubit.launchInPlaceUpdate(), isFalse);
    });

    test('backing out of the blocking updater also falls through', () async {
      // The wall stays up and the button now tries the store listing. The one
      // thing that must not happen is `true` — the user would be left staring
      // at a wall whose button reported success and did nothing.
      final play = _FakePlay(info: _play(), immediateSucceeds: false);
      final cubit = await _cubit(
        adapter: _StubAdapter(
          body: {
            'ok': true,
            'min_supported_build': 116,
            'latest_build': 120,
            'latest_version': '1.2.5',
            'store_url': 'https://play.google.com/store/apps/details?id=x',
          },
        ),
        play: play,
      );
      await cubit.check();
      expect(await cubit.launchInPlaceUpdate(), isFalse);
      expect(play.immediateCalls, 1);
    });
  });

  test('the real Play service degrades to null off-device', () async {
    // There is no Play plugin behind a `flutter test` host, so
    // `InAppUpdate.checkForUpdate()` throws MissingPluginException. Every
    // sideloaded APK, emulator image and `flutter run` build throws the same
    // way — that is a normal developer situation, not a bug, and it must not
    // reach the first frame as a crash.
    TestWidgetsFlutterBinding.ensureInitialized();
    expect(await const PlayUpdateService().check(), isNull);
  });

  group('The gate is not a dependency of every screen', () {
    Widget host(Widget child, {AppUpdateCubit? cubit}) {
      const locale = Locale('en');
      final app = MaterialApp(
        locale: locale,
        supportedLocales: AppStrings.supported,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        theme: AppTheme.light(locale),
        home: Scaffold(body: child),
      );
      if (cubit == null) return app;
      return BlocProvider<AppUpdateCubit>.value(value: cubit, child: app);
    }

    testWidgets('the banner renders with no AppUpdateCubit in the tree',
        (tester) async {
      // PageScaffold is the base of nearly every screen. Reading the cubit
      // with a plain `BlocBuilder` made it a hard requirement of that
      // scaffold and killed twelve unrelated widget tests with
      // ProviderNotFoundException. Nothing cosmetic gets to do that.
      await tester.pumpWidget(host(const UpdateNudgeBanner()));
      expect(tester.takeException(), isNull);
      expect(find.byType(UpdateNudgeBanner), findsOneWidget);
    });

    testWidgets('the gate passes its child through with no cubit',
        (tester) async {
      await tester.pumpWidget(
        host(const AppUpdateGate(child: Text('app', key: Key('app')))),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.byKey(const Key('app')), findsOneWidget);
    });

    testWidgets('a blocked build gets the wall instead of the app',
        (tester) async {
      // `runAsync`, not a bare await. `testWidgets` drives a FAKE clock, and
      // a Dio round-trip — even one answered by a stub adapter — resolves on
      // real timers the fake clock never advances. Awaiting `check()`
      // directly does not fail, it hangs forever; this test sat at 6+ minutes
      // with no output before the setup was moved inside `runAsync`.
      late final AppUpdateCubit cubit;
      await tester.runAsync(() async {
        cubit = await _cubit(
          adapter: _StubAdapter(
            body: {
              'ok': true,
              'min_supported_build': 116,
              'latest_build': 120,
              'latest_version': '1.2.5',
              'store_url': 'https://play.google.com/store/apps/details?id=x',
            },
          ),
        );
        await cubit.check();
      });
      expect(cubit.state.isBlocking, isTrue);

      await tester.pumpWidget(
        host(
          const AppUpdateGate(child: Text('app', key: Key('app'))),
          cubit: cubit,
        ),
      );
      await tester.pump();

      expect(find.byKey(const Key('app')), findsNothing);
      expect(find.byType(UpdateRequiredScreen), findsOneWidget);
      // The version the user is being sent to fetch is named, not implied.
      expect(find.textContaining('1.2.5'), findsOneWidget);
    });
  });

  test('an idle re-check emits an equal state', () async {
    // The gate wraps the whole router, so a state that is merely `==`-equal
    // but not identical would rebuild every screen on every resume.
    final adapter = _StubAdapter(
      body: {
        'ok': true,
        'min_supported_build': 100,
        'latest_build': 120,
        'latest_version': '1.2.5',
        'store_url': 'https://play.google.com/store/apps/details?id=x',
      },
    );
    final cubit = await _cubit(adapter: adapter);
    await cubit.check();
    final first = cubit.state;
    await cubit.check(force: true);
    expect(cubit.state, first);
  });
}
