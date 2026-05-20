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
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:saqqar_app/core/i18n/app_localizations.dart';
import 'package:saqqar_app/core/theme/app_theme.dart';
import 'package:saqqar_app/features/chat/widgets/chat_app_bar_title.dart';
import 'package:saqqar_app/features/chat/widgets/chat_header_badges.dart';
import 'package:saqqar_app/features/demo/saqqar_demo_data.dart';
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
}) async {
  for (final profile in _phoneProfiles) {
    await tester.binding.setSurfaceSize(profile.size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(_harness(build(), locale: locale));
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
          '(${profile.size.width.toInt()}×${profile.size.height.toInt()}): '
          '$error',
    );
  }
}

Widget _harness(Widget child, {Locale locale = const Locale('en')}) {
  return MaterialApp(
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
  });

  group('ChatHeaderBadges responsive', () {
    testWidgets('long project + env names + all 3 badges fit on every size',
        (tester) async {
      await _pumpAtAllSizes(
        tester,
        () => ChatHeaderBadges(
          project: const DemoProject(
            id: 'p1',
            name: 'Default workspace',
          ),
          environment: const DemoEnvironment(
            id: 'e1',
            name: 'Sahm Musanda Staging',
            projectId: 'p1',
            isLive: true,
            readOnly: true,
            autoApprove: true,
          ),
          onTap: () {},
        ),
      );
    });
  });
}
