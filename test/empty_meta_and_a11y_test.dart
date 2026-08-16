// Guards for three defects found by driving the real app on an emulator
// against production (2026-08-16):
//
//   1. Every row on the Devices screen read "Android · v" — the client never
//      sends `app_version` on registration, so the server stores "", and the
//      display guard tested `!= null` instead of "not empty".
//   2. Every row in a chat's Artifacts sheet read "XLSX -  - " — the meta line
//      joins kind/size/created unconditionally, and the adapter that builds it
//      hardcoded the created label to ''.
//   3. Only the SELECTED bottom-nav tab carried an accessibility label, so a
//      screen-reader user heard nothing identifying the two tabs they were not
//      already on.
//
// Each test was confirmed to FAIL against the code as it shipped before the
// fix — a guard that never went red is not a guard.

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:saqqar_app/core/i18n/app_localizations.dart';
import 'package:saqqar_app/core/i18n/app_strings.dart';
import 'package:saqqar_app/core/routing/route_names.dart';
import 'package:saqqar_app/core/theme/app_theme.dart';
import 'package:saqqar_app/features/push/data/devices_api.dart';
import 'package:saqqar_app/features/push/view/devices_screen.dart';
import 'package:saqqar_app/navigation/home_shell.dart';

class _FakeDevicesApi extends DevicesApi {
  _FakeDevicesApi(this.rows) : super(Dio());
  final List<DeviceRow> rows;

  @override
  Future<List<DeviceRow>> list() async => rows;
}

Widget _wrap(Widget child) => MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en'), Locale('ar')],
      theme: AppTheme.light(const Locale('en')),
      home: child,
    );

GoRouter _shellRouter() {
  Widget body(String label) =>
      Scaffold(body: Center(child: Text('$label-body')));
  return GoRouter(
    initialLocation: RouteNames.chatsPath,
    routes: [
      ShellRoute(
        builder: (_, __, child) => HomeShell(child: child),
        routes: [
          GoRoute(
            path: RouteNames.chatsPath,
            name: RouteNames.chats,
            builder: (_, __) => body('chats'),
          ),
          GoRoute(
            path: RouteNames.vaultPath,
            name: RouteNames.vault,
            builder: (_, __) => body('vault'),
          ),
          GoRoute(
            path: RouteNames.accountPath,
            name: RouteNames.account,
            builder: (_, __) => body('account'),
          ),
        ],
      ),
    ],
  );
}

void main() {
  group('empty server fields never render as dangling separators', () {
    testWidgets('a device with no app_version shows no trailing " · v"',
        (tester) async {
      // Exactly what production returns today for every registered device.
      final api = _FakeDevicesApi([
        const DeviceRow(
          id: 'd1',
          platform: DevicePlatform.android,
          tokenPreview: 'f-ZbD-vpRHOI…',
          appVersion: '',
        ),
      ]);

      await tester.pumpWidget(
        _wrap(
          Provider<DevicesApi>.value(
            value: api,
            child: const DevicesScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Android'), findsOneWidget);
      expect(
        find.textContaining('· v'),
        findsNothing,
        reason: 'empty app_version rendered as a bare "v"',
      );
    });

    test('artifactMeta drops parts the server did not send', () {
      final tr = AppStrings(const Locale('en'));

      // Nothing but the kind is known — the common case in production, where
      // `size_kb` is absent from metadata and the created label was dropped.
      expect(tr.artifactMeta('XLSX', '', ''), 'XLSX');

      // A missing middle part must not leave a doubled separator.
      expect(tr.artifactMeta('XLSX', '', 'Aug 16'), 'XLSX - Aug 16');

      // Fully-populated stays exactly as before.
      expect(
        tr.artifactMeta('XLSX', '74 KB', 'Aug 16'),
        'XLSX - 74 KB - Aug 16',
      );
    });
  });

  group('bottom navigation accessibility', () {
    testWidgets('every tab is labelled, not just the selected one',
        (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        MaterialApp.router(
          locale: const Locale('en'),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [Locale('en'), Locale('ar')],
          theme: AppTheme.light(const Locale('en')),
          routerConfig: _shellRouter(),
        ),
      );
      await tester.pumpAndSettle();

      final tr = AppStrings(const Locale('en'));
      // Chats is the selected tab, so its label renders visually anyway.
      // The other two are the regression: icon-only, no accessible name.
      expect(find.bySemanticsLabel(tr.tabChats), findsWidgets);
      expect(
        find.bySemanticsLabel(tr.tabVault),
        findsWidgets,
        reason: 'unselected Companies tab exposes no accessible name',
      );
      expect(
        find.bySemanticsLabel(tr.tabAccount),
        findsWidgets,
        reason: 'unselected Account tab exposes no accessible name',
      );

      handle.dispose();
    });
  });
}
