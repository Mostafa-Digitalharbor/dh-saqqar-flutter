import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:saqqar_app/core/i18n/app_localizations.dart';
import 'package:saqqar_app/core/routing/route_names.dart';
import 'package:saqqar_app/core/theme/app_theme.dart';
import 'package:saqqar_app/navigation/home_shell.dart';

/// A minimal GoRouter that mirrors the real ShellRoute — [HomeShell] wrapping
/// stub bodies for the three tabs it hosts (Home / Apps / Tasks). Chat is a
/// full-screen route outside the shell, so it is stubbed at the root.
GoRouter _shellRouter() {
  Widget body(String label) =>
      Scaffold(body: Center(child: Text('$label-body')));
  return GoRouter(
    initialLocation: RouteNames.homePath,
    routes: [
      GoRoute(path: '/chats/:id', builder: (_, __) => body('chat')),
      ShellRoute(
        builder: (_, __, child) => HomeShell(child: child),
        routes: [
          GoRoute(path: RouteNames.homePath, builder: (_, __) => body('home')),
          GoRoute(path: RouteNames.appsPath, builder: (_, __) => body('apps')),
          GoRoute(
            path: RouteNames.tasksPath,
            builder: (_, __) => body('tasks'),
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
  group('HomeShell floating pill bar', () {
    testWidgets('shows the four tab icons on every tab', (tester) async {
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      expect(find.byIcon(LucideIcons.house), findsOneWidget);
      expect(find.byIcon(LucideIcons.sparkles), findsOneWidget);
      expect(find.byIcon(LucideIcons.layoutGrid), findsOneWidget);
      expect(find.byIcon(LucideIcons.listChecks), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Home shows the bare pill; other tabs add the ⋮ pill', (
      tester,
    ) async {
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();
      expect(find.byIcon(LucideIcons.ellipsisVertical), findsNothing);

      await tester.tap(find.byIcon(LucideIcons.layoutGrid));
      await tester.pumpAndSettle();
      expect(find.text('apps-body'), findsOneWidget);
      expect(find.byIcon(LucideIcons.ellipsisVertical), findsOneWidget);
    });

    testWidgets('tapping Tasks navigates to /tasks', (tester) async {
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(LucideIcons.listChecks));
      await tester.pumpAndSettle();
      expect(find.text('tasks-body'), findsOneWidget);
    });

    testWidgets('tapping the sparkle tab opens a new chat', (tester) async {
      await tester.pumpWidget(_app());
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(LucideIcons.sparkles));
      await tester.pumpAndSettle();
      expect(find.text('chat-body'), findsOneWidget);
    });
  });
}
