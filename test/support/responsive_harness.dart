// The shared device-matrix harness behind every whole-screen responsive
// sweep.
//
// Extracted from `screen_responsive_sweep_test.dart` once a second sweep file
// needed the same 5 viewports × 2 locales × 2 text scales, the same app-level
// providers and the same overflow-attribution logic. Two copies of a matrix
// is how a viewport gets added to one sweep and not the other — the screens
// covered by the forgotten copy then stop being tested at 320 px without
// anything turning red.
//
// Everything here is screen-agnostic: the matrix, the provider chrome that
// `app.dart` installs above the router, and the fakes for the three platform
// channels (`SecureTokenStore`, `Connectivity`, `BiometricAuth`) that no
// widget test has. Per-screen fakes stay in the file that pumps that screen.

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:saqqar_app/core/i18n/app_localizations.dart';
import 'package:saqqar_app/core/i18n/view_model/locale_cubit.dart';
import 'package:saqqar_app/core/network/view_model/connectivity_cubit.dart';
import 'package:saqqar_app/core/storage/secure_token_store.dart';
import 'package:saqqar_app/core/theme/app_theme.dart';
import 'package:saqqar_app/core/theme/view_model/theme_cubit.dart';
import 'package:saqqar_app/features/auth/data/auth_api.dart';
import 'package:saqqar_app/features/auth/data/auth_models.dart';
import 'package:saqqar_app/features/auth/data/social_auth_service.dart';
import 'package:saqqar_app/features/auth/view_model/auth_cubit.dart';
import 'package:saqqar_app/features/auth/view_model/auth_state.dart';
import 'package:saqqar_app/features/chat/view_model/running_agents_cubit.dart';
import 'package:saqqar_app/features/notifications/data/notifications_store.dart';
import 'package:saqqar_app/features/notifications/view_model/notifications_settings_cubit.dart';
import 'package:saqqar_app/features/security/data/biometric_auth.dart';
import 'package:saqqar_app/features/security/view_model/app_lock_cubit.dart';

// ── Matrix ───────────────────────────────────────────────────────────────

typedef Viewport = ({String name, Size size});

/// 320×568 is the smallest phone the app supports and the width every
/// horizontal overflow shows up at first; the landscape row is the only cell
/// with less vertical room than a keyboard-less portrait screen.
const kViewports = <Viewport>[
  (name: '320×568 tiny', size: Size(320, 568)),
  (name: '360×640 small', size: Size(360, 640)),
  (name: '390×844 compact', size: Size(390, 844)),
  (name: '430×932 regular', size: Size(430, 932)),
  (name: '568×320 landscape', size: Size(568, 320)),
];

const kLocales = <Locale>[Locale('en'), Locale('ar')];

/// 1.3× is where the OS "Larger text" slider sits at roughly two notches up —
/// common enough that shipping an overflow there is shipping it to real
/// users, and large enough to break a `Row` that fits at 1.0×.
const kTextScales = <double>[1.0, 1.3];

/// Deliberately hostile but *realistic*: names this long come straight off
/// the Odoo instances the app talks to.
const kLongName = 'ALZOMMAN Trading & Contracting Establishment — Staging';

// ── Shared identity ──────────────────────────────────────────────────────

final kUser = AuthUser(
  id: 1,
  email: 'ai-tools@digital-harbor.net',
  username: 'digital-harbor',
  isStaff: true,
  isSuperuser: false,
  firstName: 'Digital',
  lastName: 'Harbor',
  fullName: 'Digital Harbor',
  dateJoined: DateTime.utc(2026, 5, 8),
  lastLogin: DateTime.utc(2026, 8, 3, 17, 19),
);

const kCounts = AuthCounts(
  conversations: 1432,
  credentials: 199,
  approvals: 24515,
  artifacts: 8801,
);

// ── Fakes for the platform channels ──────────────────────────────────────
//
// `noSuchMethod` covers everything the layout never calls; only the reads a
// first paint performs are given real answers.

class FakeAuthApi implements AuthApi {
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class FakeSocialAuth implements SocialAuthService {
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

/// `SecureTokenStore` reaches the platform keychain channel, which no widget
/// test has. Nothing here reads a token, so every call is stubbed out.
class NoopTokenStore implements SecureTokenStore {
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

/// Seeds an authenticated state without touching the network. `AuthCubit`
/// guards `emit` after close, so driving it through its own constructor and
/// a direct emit is safe and keeps the real state class in play.
class SeededAuthCubit extends AuthCubit {
  SeededAuthCubit() : super(api: FakeAuthApi(), tokenStore: NoopTokenStore()) {
    emit(AuthState(
      status: AuthStatus.authenticated,
      user: kUser,
      counts: kCounts,
    ));
  }
}

/// `ConnectivityCubit` subscribes to the connectivity plugin in its
/// constructor, which has no platform channel under `flutter test`. An empty
/// stream + a "connected" seed keeps the offline banner collapsed, which is
/// the layout the user sees the overwhelming majority of the time.
class FakeConnectivity implements Connectivity {
  @override
  Stream<List<ConnectivityResult>> get onConnectivityChanged =>
      const Stream.empty();
  @override
  Future<List<ConnectivityResult>> checkConnectivity() async =>
      [ConnectivityResult.wifi];
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

/// `AppLockCubit` probes availability in its constructor, so this has to
/// answer for real — `noSuchMethod` returns null, which is not a
/// `Future<bool>`. Reports the biometric hardware as present: that is the
/// branch that renders the extra "App lock" row, i.e. the taller layout.
class FakeBiometricAuth implements BiometricAuth {
  @override
  Future<bool> isAvailable() async => true;
  @override
  Future<bool> authenticate(String reason) async => true;
  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

// ── Provider chrome ──────────────────────────────────────────────────────

/// The providers `app.dart` installs above the router, which every screen
/// inherits in production.
///
/// Screens reach for these through shared chrome — `PageScaffold`'s brand
/// header watches `RunningAgentsCubit`, `OfflineBanner` watches
/// `ConnectivityCubit`, the account screen's security card watches
/// `AppLockCubit`. Leaving them out doesn't just throw: the
/// `ProviderNotFoundException` is rendered as an `ErrorWidget`, which is
/// unbounded, and the resulting "overflowed by 199432 pixels" buries whatever
/// real overflow the sweep was looking for.
Widget appChrome(Widget child, SharedPreferences prefs) {
  return MultiRepositoryProvider(
    providers: [
      // `AuthFlowScreen` builds its own `AuthFlowCubit` out of these two, so
      // they must be repositories here rather than a pre-built cubit.
      RepositoryProvider<AuthApi>(create: (_) => FakeAuthApi()),
      RepositoryProvider<SocialAuthService>(create: (_) => FakeSocialAuth()),
    ],
    child: MultiBlocProvider(
      providers: [
        BlocProvider<AuthCubit>(create: (_) => SeededAuthCubit()),
        BlocProvider<RunningAgentsCubit>(create: (_) => RunningAgentsCubit()),
        BlocProvider<ConnectivityCubit>(
          create: (_) => ConnectivityCubit(connectivity: FakeConnectivity()),
        ),
        BlocProvider<AppLockCubit>(
          create: (_) => AppLockCubit(prefs: prefs, auth: FakeBiometricAuth()),
        ),
        BlocProvider<NotificationsSettingsCubit>(
          create: (_) => NotificationsSettingsCubit(prefs),
        ),
        // Theme + locale are app-wide in `app.dart`; the auth screen's
        // header actions (theme toggle, language toggle) read them even
        // though the user is not signed in yet.
        BlocProvider<ThemeCubit>(create: (_) => ThemeCubit(prefs)),
        BlocProvider<LocaleCubit>(create: (_) => LocaleCubit(prefs)),
      ],
      // The notifications bell lives in `PageScaffold`'s header, so every
      // screen that uses the shared chrome needs the store in scope.
      child: ChangeNotifierProvider<NotificationsStore>(
        create: (_) => NotificationsStore(prefs),
        child: child,
      ),
    ),
  );
}

// ── Harness ──────────────────────────────────────────────────────────────

/// Wraps the pumped app in whatever providers a screen needs.
///
/// A `Widget Function(Widget)` rather than a `List<SingleChildWidget>`:
/// `provider` does not re-export `SingleChildWidget`, and taking the wrapper
/// as a plain closure lets each test compose `BlocProvider`,
/// `RepositoryProvider` and `ChangeNotifierProvider` however it likes without
/// this file depending on `nested`.
typedef WrapBuilder = Widget Function(Widget child);

Widget buildHarness(
  Widget child, {
  required Locale locale,
  required double scale,
  WrapBuilder? wrap,
}) {
  final app = MaterialApp(
    locale: locale,
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: kLocales,
    theme: AppTheme.light(locale),
    darkTheme: AppTheme.dark(locale),
    builder: (context, widget) => MediaQuery(
      data: MediaQuery.of(context)
          .copyWith(textScaler: TextScaler.linear(scale)),
      child: widget ?? const SizedBox.shrink(),
    ),
    // No SingleChildScrollView wrapper here, unlike the widget-level sweep:
    // these are whole screens that own their scrolling. Wrapping them would
    // hand every screen infinite height and mask exactly the vertical
    // overflows the 568×320 landscape row exists to find.
    home: child,
  );
  return wrap == null ? app : wrap(app);
}

/// Pumps [build] at every cell of the matrix, failing on the first layout
/// exception and naming the cell that produced it.
///
/// Installs its own `FlutterError.onError` for the duration of each pump so
/// the failure message can quote the *widget* that overflowed. Without it,
/// `takeException()` hands back only "A RenderFlex overflowed by 2.6 pixels"
/// — true, but it leaves you bisecting a whole screen to find which `Row`.
Future<void> sweepMatrix(
  WidgetTester tester,
  Widget Function() build, {
  required SharedPreferences prefs,
  WrapBuilder? wrap,
}) async {
  for (final viewport in kViewports) {
    for (final locale in kLocales) {
      for (final scale in kTextScales) {
        await tester.binding.setSurfaceSize(viewport.size);
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final culprits = <String>[];
        final previousOnError = FlutterError.onError;
        FlutterError.onError = (details) {
          // `library` is 'rendering library' for overflows; the widget and
          // its creation site come from the details' own description.
          culprits.add(
            details.toString().split('\n').where((l) {
              final t = l.trim();
              return t.startsWith('The relevant error-causing widget') ||
                  t.contains('.dart:') && !t.contains('package:flutter/');
            }).take(3).join(' | '),
          );
          previousOnError?.call(details);
        };
        addTearDown(() => FlutterError.onError = previousOnError);

        await tester.pumpWidget(
          buildHarness(
            build(),
            locale: locale,
            scale: scale,
            // App chrome sits OUTSIDE the screen's own providers, mirroring
            // `app.dart`, so a screen can still shadow one if it needs to.
            wrap: (app) => appChrome(wrap == null ? app : wrap(app), prefs),
          ),
        );
        // `pump`, never `pumpAndSettle`: the splash, the typing dots and the
        // ambient background all run perpetual animations, so settling would
        // time out and bury the real failure.
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));

        FlutterError.onError = previousOnError;
        final error = tester.takeException();
        expect(
          error,
          isNull,
          reason: 'layout error on ${viewport.name} · '
              '${locale.languageCode} · $scale× text — $error\n'
              '${culprits.join('\n')}',
        );
      }
    }
  }
}

/// Single-cell pump at a comfortable viewport, for the assertions that prove
/// a fake actually fed its screen rather than the screen rendering an error
/// state the sweep would happily call "no overflow".
Future<void> pumpOnce(
  WidgetTester tester,
  Widget screen, {
  required SharedPreferences prefs,
  WrapBuilder? wrap,
  Locale locale = const Locale('en'),
}) async {
  await tester.binding.setSurfaceSize(const Size(430, 932));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    buildHarness(
      screen,
      locale: locale,
      scale: 1.0,
      wrap: (app) => appChrome(wrap == null ? app : wrap(app), prefs),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 350));
}
