import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:saqqar_app/core/i18n/app_localizations.dart';
import 'package:saqqar_app/core/theme/app_theme.dart';
import 'package:saqqar_app/shared/widgets/saqqar_screen.dart';

/// Performance guard for [SaqqarScreen] — the scroll container every root
/// tab (Chats / Vault / Account) and every detail list renders through.
///
/// It USED to nest all of its `children` inside a single `Column` under one
/// `ListView` child, which defeated the builder entirely: every row (e.g. 30
/// conversation cards, each with a blurred drop-shadow) was built, laid out,
/// and painted up front, with no viewport culling and — because there was one
/// sliver child — no automatic per-row `RepaintBoundary`. That is the "the
/// whole app feels heavy while scrolling / switching tabs" cost.
///
/// These tests pin the two properties that fix must never regress:
///   1. Off-screen children are NOT built (lazy culling).
///   2. Children still stretch to the content-column width (the old
///      `crossAxisAlignment.stretch` behaviour), so cards don't shrink-wrap.
void main() {
  Widget host(List<Widget> children) => MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('en'), Locale('ar')],
        theme: AppTheme.light(const Locale('en')),
        home: Scaffold(body: SaqqarScreen(children: children)),
      );

  testWidgets('only builds the on-screen children — off-screen rows are culled',
      (tester) async {
    // 60 tall rows in an 800×600 test viewport. At 400 px each only a
    // couple fit; with cacheExtent ~1500 a handful more pre-build. A row far
    // down the list must never be built at all.
    final children = <Widget>[
      for (var i = 0; i < 60; i++)
        SizedBox(height: 400, child: Text('item-$i')),
    ];

    await tester.pumpWidget(host(children));
    await tester.pump();

    // First row is on screen → built.
    expect(find.text('item-0'), findsOneWidget);
    // A row ~23 000 px down is far beyond the viewport + cache → NEVER built.
    // (Before the lazy fix, the single Column force-built ALL 60, so this
    // would have been findsOneWidget.)
    expect(find.text('item-59'), findsNothing);

    // Sanity on the culling boundary: something in the middle is also absent.
    expect(find.text('item-30'), findsNothing);
  });

  testWidgets('scrolling reveals later rows and culls earlier ones',
      (tester) async {
    final children = <Widget>[
      for (var i = 0; i < 60; i++)
        SizedBox(height: 400, child: Text('item-$i')),
    ];

    await tester.pumpWidget(host(children));
    await tester.pump();

    // Fling down far enough that item-40 enters the viewport.
    await tester.drag(find.text('item-0'), const Offset(0, -16000));
    await tester.pump();

    expect(find.text('item-40'), findsOneWidget);
    // The very first row is now well above the viewport → culled.
    expect(find.text('item-0'), findsNothing);
  });

  testWidgets('children stretch to the content-column width (no shrink-wrap)',
      (tester) async {
    // A child with no intrinsic width must fill the padded content column,
    // exactly like the old Column(crossAxisAlignment: stretch) did — not
    // collapse to zero/content width.
    await tester.pumpWidget(
      host(const [SizedBox(key: Key('stretch-probe'), height: 40)]),
    );
    await tester.pump();

    final width = tester.getSize(find.byKey(const Key('stretch-probe'))).width;
    // 800 px surface − 16 px left − 16 px right of page padding = 768.
    expect(width, 768);
  });
}
