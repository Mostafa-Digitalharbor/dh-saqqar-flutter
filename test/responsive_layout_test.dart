// Responsive layout smoke tests — pump key surfaces at three named phone
// profiles and assert no overflow errors fire. Catches regressions like
// "added a new chip to the header, broke 320 px Android" before they hit
// users with smaller devices.
//
// Run: `flutter test test/responsive_layout_test.dart`
//
// Adding a new size? Append to `_phoneProfiles` and every existing widget
// test is rerun against it automatically — keeps the matrix declarative.
//
// Adding a new surface? Wrap it in `_pumpAtAllSizes(...)` inside a
// `testWidgets` and pin any data it needs through `_harness`.

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:saqqar_app/core/i18n/app_localizations.dart';
import 'package:saqqar_app/core/theme/app_theme.dart';
import 'package:saqqar_app/features/chat/widgets/chat_app_bar_title.dart';
import 'package:saqqar_app/features/chat/widgets/chat_thinking_pill.dart';
import 'package:saqqar_app/features/demo/saqqar_demo_data.dart';
import 'package:saqqar_app/features/security/data/biometric_auth.dart';
import 'package:saqqar_app/features/security/view/app_lock_screen.dart';
import 'package:saqqar_app/features/security/view_model/app_lock_cubit.dart';
import 'package:saqqar_app/shared/extensions/responsive_breakpoints.dart';

/// Named phone profiles spanning the support matrix. `tiny` covers the
/// 320 px Android slice the responsive system was built for; `regular`
/// covers iPhone Pro Max; `landscape` flips a compact phone on its side
/// to exercise the cross-axis budget.
const _phoneProfiles = <_PhoneProfile>[
  _PhoneProfile(name: 'tiny portrait', size: Size(320, 568)),
  _PhoneProfile(name: 'compact portrait', size: Size(390, 844)),
  _PhoneProfile(name: 'regular portrait', size: Size(430, 932)),
  _PhoneProfile(name: 'compact landscape', size: Size(844, 390)),
];

class _PhoneProfile {
  const _PhoneProfile({required this.name, required this.size});
  final String name;
  final Size size;
}

/// Pumps [child] inside a stripped-down Material app harness at every
/// entry in [_phoneProfiles]; if anything inside the subtree records an
/// overflow / unbounded-constraint exception, the test fails with the
/// profile that triggered it.
Future<void> _pumpAtAllSizes(
  WidgetTester tester,
  Widget Function() build, {
  Locale locale = const Locale('en'),
  double textScale = 1.0,
}) async {
  for (final profile in _phoneProfiles) {
    await tester.binding.setSurfaceSize(profile.size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      _harness(build(), locale: locale, textScale: textScale),
    );
    // Single pump frame so we lay out + any one-shot animation kicks
    // off; do NOT call `pumpAndSettle` here because some widgets in
    // the chat surface (e.g. `MarqueeText`, `_AgentWorkingPill`) run
    // perpetual animations that would never settle and would mask
    // real overflow failures behind a timeout.
    await tester.pump();
    final error = tester.takeException();
    expect(
      error,
      isNull,
      reason: 'overflow / layout error on ${profile.name} '
          '(${profile.size.width.toInt()}×${profile.size.height.toInt()}, '
          'locale ${locale.languageCode}, textScale $textScale): $error',
    );
  }
}

Widget _harness(
  Widget child, {
  Locale locale = const Locale('en'),
  double textScale = 1.0,
}) {
  return MaterialApp(
    builder: (context, widget) => MediaQuery(
      // Accessibility text scaling is the other axis that breaks tight
      // rows, and it compounds with Arabic: longer strings AND bigger
      // glyphs at the same time. 1.4× is a common real-world setting,
      // not a stress value.
      data: MediaQuery.of(context)
          .copyWith(textScaler: TextScaler.linear(textScale)),
      child: widget ?? const SizedBox.shrink(),
    ),
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
    home: Scaffold(body: child),
  );
}

void main() {
  group('Breakpoint resolution', () {
    test('width thresholds map to the expected tier', () {
      expect(breakpointForWidth(320), Breakpoint.tiny);
      expect(breakpointForWidth(340), Breakpoint.tiny);
      expect(breakpointForWidth(360), Breakpoint.compact);
      expect(breakpointForWidth(400), Breakpoint.compact);
      expect(breakpointForWidth(430), Breakpoint.regular);
      expect(breakpointForWidth(600), Breakpoint.regular);
      expect(breakpointForWidth(840), Breakpoint.wide);
    });

    test('tier helpers compose correctly', () {
      expect(Breakpoint.tiny.isTinyOrBelow, isTrue);
      expect(Breakpoint.compact.isTinyOrBelow, isFalse);
      expect(Breakpoint.compact.isCompactOrBelow, isTrue);
      expect(Breakpoint.regular.isCompactOrBelow, isFalse);
      expect(Breakpoint.wide.isRegularOrAbove, isTrue);
    });
  });

  group('ChatAppBarTitle responsive', () {
    testWidgets('renders without overflow when title + all 3 badges + AUTO '
        'fight for space', (tester) async {
      await _pumpAtAllSizes(
        tester,
        () => Align(
          alignment: Alignment.topLeft,
          child: ChatAppBarTitle(
            title: 'Reschedule yesterday\'s SAR ledger close',
            activeCredentialLabel: 'ALZOMMAN Staging',
            autoApprove: true,
            envIsLive: true,
            envReadOnly: true,
            onCredentialTap: () {},
            onRenameTap: () {},
            agentBusy: true,
          ),
        ),
      );
    });

    testWidgets('renders Arabic title + badges without overflow',
        (tester) async {
      await _pumpAtAllSizes(
        tester,
        () => Align(
          alignment: Alignment.topRight,
          child: ChatAppBarTitle(
            title: 'إعادة جدولة إقفال دفتر الأستاذ بالريال السعودي',
            activeCredentialLabel: 'بيئة ألزومان التجريبية',
            autoApprove: true,
            envIsLive: true,
            envReadOnly: false,
            onCredentialTap: () {},
          ),
        ),
        locale: const Locale('ar'),
      );
    });

    // Regression: a long env name overflowed the subtitle row by ~14 px on
    // a 320 px phone. The two tests above missed it for two reasons, both
    // worth preserving here:
    //
    //   1. They pump into `Align`, which passes LOOSE constraints — the
    //      widget got the whole screen width. The real chat AppBar gives
    //      its title slot ~146 px less than the screen once the leading
    //      back button, the search action and the inbox bell are taken
    //      out. The bug only exists inside that narrower box.
    //   2. 'ALZOMMAN Staging' is 16 chars — too short to reach the cap.
    //      The name has to be long enough to saturate it (~27+ EN chars).
    //
    // So this pumps into a real AppBar carrying the same chrome as
    // `ChatScreen`, with a name long enough to fight for the last pixels.
    for (final locale in const [Locale('en'), Locale('ar')]) {
      final isArabic = locale.languageCode == 'ar';
      testWidgets(
        'long env name stays inside the real AppBar title slot '
        '(${locale.languageCode})',
        (tester) async {
          await _pumpAtAllSizes(
            tester,
            () => _ChatAppBarHarness(
              title: isArabic ? 'إقفال دفتر الأستاذ' : 'Ledger close',
              // Long enough to saturate the env-name cap in both scripts.
              activeCredentialLabel: isArabic
                  ? 'بيئة ألزومان للإنتاج والتجريب الرئيسية'
                  : 'ALZOMMAN Production Staging Server',
            ),
            locale: locale,
          );
        },
      );
    }
  });

  // Regression: the lock screen centred a ~360dp Column with no scroll, so
  // it overflowed by ~40px in landscape (a 320dp cross-axis budget). Nothing
  // pins the app to portrait — Info.plist allows both landscape orientations,
  // AndroidManifest sets no screenOrientation, and `setPreferredOrientations`
  // is never called — so a returning user who rotated their phone met a
  // RenderFlex overflow on the first surface the app shows them.
  //
  // `_phoneProfiles` includes a landscape entry, which is what makes this
  // test meaningful: it FAILS against the pre-fix widget.
  group('AppLockScreen responsive', () {
    for (final locale in const [Locale('en'), Locale('ar')]) {
      testWidgets(
        'lock screen survives every profile incl. landscape '
        '(${locale.languageCode})',
        (tester) async {
          SharedPreferences.setMockInitialValues({});
          final prefs = await SharedPreferences.getInstance();
          await _pumpAtAllSizes(
            tester,
            () => BlocProvider(
              create: (_) => AppLockCubit(
                prefs: prefs,
                auth: _StubBiometricAuth(),
              ),
              child: const AppLockScreen(),
            ),
            locale: locale,
          );
        },
      );
    }

    // The sizes above do NOT catch this on their own, which is the whole
    // point of pinning them explicitly here:
    //
    //   * `compact landscape` in `_phoneProfiles` is 844×390. The column is
    //     ~360dp, so it FITS at 390 and the profile sweep stays green.
    //   * iPhone SE landscape is 568×320 — 40dp short. That's the device
    //     that actually broke.
    //   * At 1.4× the subtitle wraps and the column grows past even a
    //     568dp-tall portrait viewport.
    //
    // Each case below fails against the pre-fix widget; the sweep above
    // doesn't. Verified by reverting the fix and re-running.
    const tightCases = <({String name, Size size, double scale})>[
      (name: 'iPhone SE landscape', size: Size(568, 320), scale: 1.0),
      (name: 'iPhone SE landscape @1.4×', size: Size(568, 320), scale: 1.4),
      (name: 'tiny portrait @1.4×', size: Size(320, 568), scale: 1.4),
    ];

    for (final c in tightCases) {
      testWidgets('lock screen survives ${c.name}', (tester) async {
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        await tester.binding.setSurfaceSize(c.size);
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(
          _harness(
            MediaQuery(
              data: MediaQueryData(textScaler: TextScaler.linear(c.scale)),
              child: BlocProvider(
                create: (_) => AppLockCubit(
                  prefs: prefs,
                  auth: _StubBiometricAuth(),
                ),
                child: const AppLockScreen(),
              ),
            ),
            locale: const Locale('ar'),
          ),
        );
        await tester.pump();
        expect(
          tester.takeException(),
          isNull,
          reason: '${c.name} overflowed — the lock screen must scroll rather '
              'than clip when the viewport is shorter than its content.',
        );
      });
    }
  });

  group('ChatThinkingPill responsive', () {
    // This pill was a live overflow. Its Row is `mainAxisSize.min` with
    // five unguarded Text children — and `.min` only means "don't expand",
    // it does NOT stop children exceeding the incoming constraint. At
    // 320 px the Arabic header plus the chevron ran past the ~280 px the
    // message list leaves it, throwing a RenderFlex overflow.
    //
    // Worth pinning at ar + 1.4× specifically: that combination is what
    // the earlier fixes in this file were all found by, and it is the one
    // an English-locale reviewer never reproduces.
    List<DemoMessage> steps(int n) => List.generate(
          n,
          (i) => DemoMessage(
            role: DemoMessageRole.assistant,
            content: 'Intermediate reasoning step ${i + 1}',
            time: '11:4$i',
          ),
        );

    testWidgets('header fits with steps + duration in English',
        (tester) async {
      await _pumpAtAllSizes(
        tester,
        () => Align(
          alignment: Alignment.topLeft,
          child: ChatThinkingPill(
            steps: steps(3),
            totalDuration: const Duration(minutes: 1, seconds: 23),
          ),
        ),
      );
    });

    testWidgets('header fits in Arabic at 1.4x text scale', (tester) async {
      await _pumpAtAllSizes(
        tester,
        () => Align(
          alignment: Alignment.topLeft,
          child: ChatThinkingPill(
            steps: steps(12),
            totalDuration: const Duration(minutes: 14, seconds: 7),
          ),
        ),
        locale: const Locale('ar'),
        textScale: 1.4,
      );
    });
  });

}

/// Never touches the platform channel — the lock screen fires an unlock
/// attempt from `initState`, and a real `BiometricAuth` would throw a
/// MissingPluginException in a widget test and mask the layout assertion.
class _StubBiometricAuth implements BiometricAuth {
  @override
  Future<bool> isAvailable() async => true;

  @override
  Future<bool> authenticate(String reason) async => false;
}

/// Mirrors the chat AppBar's real geometry: a leading button plus the two
/// trailing actions (search + inbox bell) that squeeze the title slot.
/// Pumping [ChatAppBarTitle] bare gives it the full screen width and hides
/// slot-width bugs, so the chrome is reproduced rather than approximated.
class _ChatAppBarHarness extends StatelessWidget {
  const _ChatAppBarHarness({
    required this.title,
    required this.activeCredentialLabel,
  });

  final String title;
  final String activeCredentialLabel;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () {}),
        title: ChatAppBarTitle(
          title: title,
          activeCredentialLabel: activeCredentialLabel,
          autoApprove: true,
          envIsLive: true,
          envReadOnly: true,
          onCredentialTap: () {},
          onRenameTap: () {},
        ),
        actions: [
          IconButton(icon: const Icon(Icons.search), onPressed: () {}),
          // Stands in for `_InboxBellTrigger` — a 38 px box with 4 px of
          // end padding, per chat_screen.dart.
          const Padding(
            padding: EdgeInsetsDirectional.only(end: 4),
            child: SizedBox.square(dimension: 38, child: Icon(Icons.notifications)),
          ),
        ],
      ),
      body: const SizedBox.shrink(),
    );
  }
}
