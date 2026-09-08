// Running out of tokens is a blocked send too.
//
// Found in the full web-vs-mobile sweep. The server reports why a send is
// blocked as `conversation.quota.kind`, and the web branches on four values:
// day, week, month, and `balance`. The app's enum had the first three, so
// `QuotaWindow.fromWire('balance')` returned null — no banner, and the
// composer stayed live. The user typed, sent, and watched it fail with
// nothing on screen saying why.
//
// The copy has to differ, not just exist: the window cases promise "it resets
// when the window rolls over", and a spent balance never does.

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saqqar_app/core/i18n/app_localizations.dart';
import 'package:saqqar_app/core/i18n/app_strings.dart';
import 'package:saqqar_app/core/theme/app_theme.dart';
import 'package:saqqar_app/features/billing/data/billing_visibility.dart';
import 'package:saqqar_app/features/billing/data/plan_models.dart';
import 'package:saqqar_app/features/chat/widgets/chat_plan_banner.dart';
import 'package:saqqar_app/features/conversations/data/conversation_models.dart';

final _plan = PlanSnapshot.fromJson(const {
  'plan': 'free',
  'plan_name': 'Free',
  'exempt': false,
  'features': <String, dynamic>{},
});

ConversationSnapshot _snapshot(Object? quota) =>
    ConversationSnapshot.fromJson(<String, dynamic>{
      'conversation': <String, dynamic>{
        'id': 'c1',
        'title': 'T',
        'is_running': false,
        'stop_requested': false,
        if (quota != null) 'quota': quota,
      },
      'messages': const <Map<String, dynamic>>[],
    });

Future<void> _pumpBanner(
  WidgetTester tester,
  QuotaWindow? window, {
  Locale locale = const Locale('en'),
  bool paidUpsell = false,
}) async {
  // A dart-define is fixed at compile time; this hook is how both sides of
  // the store-policy gate get exercised in one run.
  debugShowPaidUpsell = paidUpsell;
  addTearDown(() => debugShowPaidUpsell = null);
  await tester.pumpWidget(
    MaterialApp(
      locale: locale,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en'), Locale('ar')],
      theme: AppTheme.light(locale),
      home: Scaffold(
        body: SingleChildScrollView(
          child: ChatPlanBanner(
            plan: _plan,
            exceededWindow: window,
            onUpgrade: () {},
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  final en = AppStrings(const Locale('en'));
  final ar = AppStrings(const Locale('ar'));

  group('the wire values the server actually sends', () {
    test('all four are understood', () {
      // The web branches on exactly these; a fourth that parses to null is a
      // blocked send with no explanation.
      expect(QuotaWindow.fromWire('day'), QuotaWindow.day);
      expect(QuotaWindow.fromWire('week'), QuotaWindow.week);
      expect(QuotaWindow.fromWire('month'), QuotaWindow.month);
      expect(QuotaWindow.fromWire('balance'), QuotaWindow.balance);
    });

    test('and anything else is still null', () {
      // Forward-compat: a kind this build has never heard of must not fake a
      // banner it cannot word.
      expect(QuotaWindow.fromWire('decade'), isNull);
      expect(QuotaWindow.fromWire(''), isNull);
      expect(QuotaWindow.fromWire(null), isNull);
    });

    test('a spent balance reaches the screen through the snapshot', () {
      // The whole path, not just the enum: this is where it was being lost.
      expect(
        _snapshot(const {'kind': 'balance'}).quotaExceeded,
        QuotaWindow.balance,
      );
      expect(
        _snapshot(const {'kind': 'month'}).quotaExceeded,
        QuotaWindow.month,
      );
      expect(_snapshot(null).quotaExceeded, isNull);
    });
  });

  group('what the banner says', () {
    testWidgets('a spent balance does not promise a reset', (tester) async {
      for (final locale in [const Locale('en'), const Locale('ar')]) {
        final tr = locale.languageCode == 'en' ? en : ar;

        await _pumpBanner(tester, QuotaWindow.balance, locale: locale);

        expect(find.text(tr.quotaBalanceBodyPlain), findsOneWidget);
        // The window wording would tell them to wait for something that is
        // never coming.
        expect(find.text(tr.quotaExceededBodyPlain(tr.planWindowWord('month'))),
            findsNothing);
      }
    });

    testWidgets('a window limit still reads as a window', (tester) async {
      await _pumpBanner(tester, QuotaWindow.month);

      expect(
        find.text(en.quotaExceededBodyPlain(en.planWindowWord('month'))),
        findsOneWidget,
      );
      expect(find.text(en.quotaBalanceBodyPlain), findsNothing);
    });

    testWidgets('the balance copy offers a top-up where sales are allowed',
        (tester) async {
      await _pumpBanner(tester, QuotaWindow.balance, paidUpsell: true);

      expect(find.text(en.quotaBalanceBody), findsOneWidget);
      expect(find.text(en.quotaUpgradeCta), findsOneWidget);
    });

    testWidgets('and says only the fact where they are not', (tester) async {
      // Store policy: no purchase CTA in the app build.
      await _pumpBanner(tester, QuotaWindow.balance);

      expect(find.text(en.quotaBalanceBodyPlain), findsOneWidget);
      expect(find.text(en.quotaUpgradeCta), findsNothing);
    });

    testWidgets('no quota, no banner', (tester) async {
      await _pumpBanner(tester, null);

      expect(find.text(en.quotaExceededTitle), findsNothing);
      expect(find.text(en.quotaBalanceBodyPlain), findsNothing);
    });

    test('the two languages are not the same string', () {
      expect(ar.quotaBalanceBody, isNot(en.quotaBalanceBody));
      expect(ar.quotaBalanceBodyPlain, isNot(en.quotaBalanceBodyPlain));
      expect(ar.quotaBalanceBodyPlain, matches(RegExp(r'[؀-ۿ]')));
    });
  });
}
