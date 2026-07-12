import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:saqqar_app/core/i18n/app_localizations.dart';
import 'package:saqqar_app/core/routing/route_names.dart';
import 'package:saqqar_app/core/theme/app_icons.dart';
import 'package:saqqar_app/core/theme/app_theme.dart';
import 'package:saqqar_app/navigation/home_shell.dart';

/// Builds a minimal GoRouter that mirrors the real app's ShellRoute — a
/// [HomeShell] wrapping three stub tab bodies (/chats, /vault, /account).
/// The stub bodies stand in for the real screens so the test exercises the
/// shell's bottom-nav rendering + navigation without pulling in every
/// screen's Cubit dependencies.
GoRouter _shellRouter() {
  Widget body(String label) => Scaffold(body: Center(child: Text('$label-body')));
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

Widget _app({Locale locale = const Locale('en')}) {
  return MaterialApp.router(
    locale: locale,
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: const [Locale('en'), Locale('ar')],
    theme: AppTheme.light(locale),
    darkTheme: AppTheme.dark(locale),
    routerConfig: _shellRouter(),
  );
}

void main() {
  group('HomeShell bottom navigation', () {
    testWidgets('shows all three tab icons for every user (no plan gating)', (
      tester,
    ) async {
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      // The three tabs (Chats / Projects[vault] / Account) always render.
      // This is the regression guard for the bug where the Projects tab was
      // hidden for Free-plan users, leaving a 2-tab bar.
      expect(find.byIcon(AppIcons.chats), findsOneWidget);
      expect(find.byIcon(AppIcons.projects), findsOneWidget);
      expect(find.byIcon(AppIcons.account), findsOneWidget);

      // No exception (e.g. a missing PlanCubit provider) during build.
      expect(tester.takeException(), isNull);
    });

    testWidgets('tapping the Projects tab navigates to /vault and selects it', (
      tester,
    ) async {
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      // Start on Chats.
      expect(find.text('chats-body'), findsOneWidget);
      // Material-3 pattern: only the selected tab shows its label.
      expect(find.text('Chats'), findsOneWidget);

      // Tap Projects (the vault tab) via its always-present icon.
      await tester.tap(find.byIcon(AppIcons.projects));
      await tester.pumpAndSettle();

      // The vault body is now on screen and its label is the active one —
      // i.e. the bottom bar is in sync with the route (the old bug fell back
      // to highlighting Chats because the vault tab was absent from the list).
      expect(find.text('vault-body'), findsOneWidget);
      expect(find.text('Projects'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('tapping the Account tab navigates to /account', (
      tester,
    ) async {
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(AppIcons.account));
      await tester.pumpAndSettle();

      expect(find.text('account-body'), findsOneWidget);
      expect(find.text('Account'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
