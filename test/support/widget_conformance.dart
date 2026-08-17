// The shared battery every widget in the app is put through.
//
// `responsive_harness.dart` sweeps whole SCREENS; this is its widget-level
// counterpart. The distinction matters because the two catch different bugs: a
// screen sweep proves the composition works with the content that screen
// happens to pass, while this proves the *component* survives content it does
// not control — a 60-character Arabic label, a 320 px parent, 1.4× type.
//
// A widget that only ever renders inside one screen is still worth pumping
// here, because "the content it does not control" is exactly what changes when
// somebody reuses it on the second screen.
//
// ## What each axis is for
//
//   * **320×568** — the narrowest supported phone, and the width at which an
//     unguarded `Row` breaks first.
//   * **568×320** — landscape on that phone. Nothing pins this app to
//     portrait, and a widget that centres a fixed-height column fails only
//     here.
//   * **Arabic** — not merely a mirror. Arabic copy in this app runs longer
//     than its English source, so AR is the stricter WIDTH test, and RTL
//     exercises the `Directional` variants of every padding and alignment.
//   * **1.4×** — the ceiling `app.dart` clamps the OS scaler to, so it is the
//     widest type a user can actually produce.
//   * **dark** — checked once rather than crossed with everything, because a
//     theme swap changes colours and not layout. What it catches is a widget
//     that reads a colour the dark palette leaves transparent.

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:saqqar_app/core/i18n/app_localizations.dart';
import 'package:saqqar_app/core/theme/app_theme.dart';

typedef Viewport = ({String name, Size size});

const kWidgetViewports = <Viewport>[
  (name: '320×568 tiny', size: Size(320, 568)),
  (name: '430×932 regular', size: Size(430, 932)),
  (name: '568×320 landscape', size: Size(568, 320)),
];

const kWidgetLocales = <Locale>[Locale('en'), Locale('ar')];
const kWidgetScales = <double>[1.0, 1.4];

/// Hostile but *realistic* content. These come off the Odoo instances the app
/// actually talks to; a lorem-ipsum string would be shorter and kinder than
/// production.
const kLongEnglish =
    'ALZOMMAN Trading & Contracting Establishment — Staging Environment';
const kLongArabic =
    'مؤسسة الزمان للتجارة والمقاولات — بيئة التشغيل التجريبي للمراجعة';

/// A word with no spaces in it. The one input a `Row` cannot wrap its way out
/// of, and the reason `softWrap` alone is not an overflow fix.
const kUnbreakable =
    'reconciliation_export_2026_Q4_alzomman_trading_contracting.xlsx';

Widget conformanceHarness(
  Widget child, {
  required Locale locale,
  required double scale,
  Brightness brightness = Brightness.light,
  bool scroll = true,
}) {
  return MaterialApp(
    locale: locale,
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: kWidgetLocales,
    theme: brightness == Brightness.light
        ? AppTheme.light(locale)
        : AppTheme.dark(locale),
    builder: (context, widget) => MediaQuery(
      data: MediaQuery.of(context)
          .copyWith(textScaler: TextScaler.linear(scale)),
      child: widget ?? const SizedBox.shrink(),
    ),
    // Mirrors what a real screen wraps its body in. Without it a component
    // that is legitimately taller than a 320 px landscape viewport reports a
    // vertical overflow production never shows anyone.
    home: Scaffold(
      body: SafeArea(
        child: scroll ? SingleChildScrollView(child: child) : child,
      ),
    ),
  );
}

/// Pumps [build] at all 12 layout cells and fails on the first exception,
/// naming the cell so the test name IS the repro.
///
/// Overflows are collected via `FlutterError.onError` rather than
/// `tester.takeException()` because a `RenderFlex` overflow is *reported*
/// rather than thrown — it paints a yellow banner and carries on, which means
/// a test that only checks for thrown exceptions passes over every one of
/// them.
Future<void> sweepWidget(
  WidgetTester tester,
  Widget Function() build, {
  required String name,
  bool scroll = true,
}) async {
  for (final viewport in kWidgetViewports) {
    for (final locale in kWidgetLocales) {
      for (final scale in kWidgetScales) {
        await tester.binding.setSurfaceSize(viewport.size);
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final problems = <String>[];
        final previous = FlutterError.onError;
        FlutterError.onError = (details) {
          problems.add(
            details
                .toString()
                .split('\n')
                .where((l) {
                  final t = l.trim();
                  return t.startsWith('The relevant error-causing widget') ||
                      (t.contains('.dart:') && !t.contains('package:flutter/'));
                })
                .take(3)
                .join(' | '),
          );
          previous?.call(details);
        };
        addTearDown(() => FlutterError.onError = previous);

        await tester.pumpWidget(
          conformanceHarness(
            build(),
            locale: locale,
            scale: scale,
            scroll: scroll,
          ),
        );
        // `pump`, never `pumpAndSettle`: several of these run perpetual
        // animations (the typing dots, the scanline, the ambient background),
        // and settling would time out rather than fail informatively.
        await tester.pump(const Duration(milliseconds: 60));

        final thrown = tester.takeException();
        final where =
            '$name @ ${viewport.name} · ${locale.languageCode} · ${scale}x';
        expect(thrown, isNull, reason: '$where threw: $thrown');
        expect(
          problems,
          isEmpty,
          reason: '$where overflowed:\n  ${problems.join('\n  ')}',
        );
      }
    }
  }
  await tester.binding.setSurfaceSize(null);
}

/// Renders once in the dark theme. Layout is theme-independent, so this is one
/// cell rather than a doubling of the matrix above.
Future<void> rendersInDark(
  WidgetTester tester,
  Widget Function() build, {
  required String name,
  bool scroll = true,
}) async {
  await tester.binding.setSurfaceSize(const Size(360, 720));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    conformanceHarness(
      build(),
      locale: const Locale('ar'),
      scale: 1.0,
      brightness: Brightness.dark,
      scroll: scroll,
    ),
  );
  await tester.pump(const Duration(milliseconds: 60));
  expect(tester.takeException(), isNull, reason: '$name failed in dark mode');
}
