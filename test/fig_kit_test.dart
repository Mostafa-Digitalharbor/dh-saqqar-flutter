// The 2026-11 redesign's shared primitives (`lib/shared/fig/fig.dart`).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:saqqar_app/core/theme/app_theme.dart';
import 'package:saqqar_app/shared/fig/fig.dart';
import 'package:saqqar_app/shared/fig/fig_page.dart';

Widget _host(Widget child) => MaterialApp(
      theme: AppTheme.light(const Locale('en')),
      home: Scaffold(body: child),
    );

void main() {
  testWidgets('FigField shows label, hint, error and toggles obscuring',
      (tester) async {
    await tester.pumpWidget(_host(const FigField(
      label: 'Password',
      hint: 'Enter your password',
      obscure: true,
      error: 'Too short',
    )));

    expect(find.text('Password'), findsOneWidget);
    expect(find.text('Enter your password'), findsOneWidget);
    expect(find.text('Too short'), findsOneWidget);
    expect(find.byIcon(LucideIcons.eye), findsOneWidget);

    await tester.tap(find.byIcon(LucideIcons.eye));
    await tester.pump();
    expect(find.byIcon(LucideIcons.eyeOff), findsOneWidget);
  });

  testWidgets('FigButton fires, and is inert while loading', (tester) async {
    var taps = 0;
    await tester.pumpWidget(_host(FigButton(label: 'Go', onPressed: () => taps++)));
    await tester.tap(find.text('Go'));
    expect(taps, 1);

    await tester.pumpWidget(
        _host(FigButton(label: 'Go', loading: true, onPressed: () => taps++)));
    await tester.tap(find.byType(FigButton));
    expect(taps, 1);
    expect(find.text('Go'), findsNothing);
  });

  testWidgets('FigTopPill and FigBackButton are tappable', (tester) async {
    var pill = 0;
    var back = 0;
    await tester.pumpWidget(_host(Row(children: [
      FigTopPill(label: 'Sign Up', onTap: () => pill++),
      FigBackButton(onTap: () => back++),
    ])));
    await tester.tap(find.text('Sign Up'));
    await tester.tap(find.byIcon(LucideIcons.chevronLeft));
    expect([pill, back], [1, 1]);
  });

  testWidgets('FigPageHeader renders eyebrow, title and subtitle',
      (tester) async {
    await tester.pumpWidget(_host(const FigPageHeader(
      eyebrow: 'Billing',
      title: 'Plans & pricing',
      subtitle: 'Pick one',
    )));
    expect(find.text('Billing'), findsOneWidget);
    expect(find.text('Plans & pricing'), findsOneWidget);
    expect(find.text('Pick one'), findsOneWidget);
  });

  testWidgets('FigPage frames its child under a title and a working back',
      (tester) async {
    var back = 0;
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light(const Locale('en')),
      home: FigPage(
        eyebrow: 'Billing',
        title: 'Payment history',
        onBack: () => back++,
        child: const Text('Body'),
      ),
    ));
    expect(find.text('Billing'), findsOneWidget);
    expect(find.text('Payment history'), findsOneWidget);
    expect(find.text('Body'), findsOneWidget);

    await tester.tap(find.byIcon(LucideIcons.chevronLeft));
    expect(back, 1);
  });

  testWidgets('FigNotchSheet shows its child and a close button',
      (tester) async {
    await tester.pumpWidget(_host(const FigNotchSheet(child: Text('Body'))));
    expect(find.text('Body'), findsOneWidget);
    expect(find.byIcon(LucideIcons.x), findsOneWidget);
  });

  testWidgets('FigBackdrop paints its child over the gradient (light + dark)',
      (tester) async {
    await tester.pumpWidget(_host(const FigBackdrop(child: Text('Hi'))));
    expect(find.text('Hi'), findsOneWidget);
    await tester.pumpWidget(
        _host(const FigBackdrop(dark: true, child: Text('Hi dark'))));
    expect(find.text('Hi dark'), findsOneWidget);
  });
}
