// The "Monthly · Renews on 4 Mar 2027" line under the plan name.
//
// New with API_MOBILE_SUBSCRIPTION.md §1, which is the first time the app has
// been able to answer "when does this renew?". Two things it must get right,
// and both are easy to get wrong in a way nobody notices:
//
//   * **Never a countdown.** Saqqar billing is prepaid — entitlement is the
//     token balance plus the window caps, so nothing is cut off on
//     `expires_at`. Wording it as an expiry would be a deadline the user acts
//     on and that does not exist.
//   * **Never a bare cycle.** A live staff account reports `cycle: "monthly"`
//     with `expires_at: null` and nothing ever purchased. Printing "Monthly"
//     alone tells that user they are on a billing cycle they have never been
//     billed for.
//
// Rendered through the real widget rather than by calling the private helper,
// so the test breaks if the line stops being wired into the card at all.

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saqqar_app/core/i18n/app_localizations.dart';
import 'package:saqqar_app/core/theme/app_theme.dart';
import 'package:saqqar_app/features/account/widgets/plan_usage_card.dart';
import 'package:saqqar_app/features/billing/data/plan_models.dart';
import 'package:saqqar_app/features/billing/view_model/plan_cubit.dart';

const _window = UsageWindow(used: 10, cap: 100, pct: 10, remaining: 90);

PlanSnapshot _plan({
  String status = 'active',
  String cycle = '',
  DateTime? expiresAt,
  bool exempt = false,
}) =>
    PlanSnapshot(
      slug: 'pro',
      name: 'Professional',
      exempt: exempt,
      day: _window,
      week: _window,
      month: _window,
      features: const PlanFeatures(),
      status: status,
      cycle: cycle,
      expiresAt: expiresAt,
    );

Future<void> _pump(WidgetTester tester, PlanSnapshot plan,
    {String locale = 'en'}) async {
  final cubit = PlanCubit()..update(plan);
  addTearDown(cubit.close);
  await tester.pumpWidget(
    MaterialApp(
      locale: Locale(locale),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en'), Locale('ar')],
      theme: AppTheme.light(Locale(locale)),
      home: BlocProvider<PlanCubit>.value(
        value: cubit,
        child: const Scaffold(body: SingleChildScrollView(child: PlanUsageCard())),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('a paid period shows the cycle and the renewal date',
      (tester) async {
    await _pump(
      tester,
      _plan(cycle: 'annual', expiresAt: DateTime.utc(2027, 3, 4)),
    );

    expect(find.textContaining('Annual'), findsOneWidget);
    expect(find.textContaining('Renews on'), findsOneWidget);
    expect(find.textContaining('2027'), findsOneWidget);
  });

  testWidgets('it is worded as a renewal, never an expiry', (tester) async {
    await _pump(
      tester,
      _plan(cycle: 'monthly', expiresAt: DateTime.utc(2027, 3, 4)),
    );

    // Prepaid billing: access ends when tokens run out, not on this date.
    expect(find.textContaining('Expires'), findsNothing);
    expect(find.textContaining('expires'), findsNothing);
    expect(find.textContaining('Ends'), findsNothing);
  });

  testWidgets('a cycle with no period end renders nothing', (tester) async {
    // The live staff-account shape.
    await _pump(tester, _plan(cycle: 'monthly'));

    expect(find.textContaining('Monthly'), findsNothing);
    expect(find.textContaining('Renews'), findsNothing);
  });

  testWidgets('"active" is not printed — only states needing action are',
      (tester) async {
    await _pump(
      tester,
      _plan(cycle: 'monthly', expiresAt: DateTime.utc(2027, 3, 4)),
    );
    expect(find.textContaining('Active'), findsNothing);
  });

  testWidgets('past_due surfaces even with no renewal date', (tester) async {
    // The one case worth interrupting someone for: their payment failed and
    // the plan is about to stop working.
    await _pump(tester, _plan(status: 'past_due', cycle: 'monthly'));

    expect(find.textContaining('Payment overdue'), findsOneWidget);
  });

  testWidgets('canceled surfaces too', (tester) async {
    await _pump(tester, _plan(status: 'canceled'));
    expect(find.textContaining('Canceled'), findsOneWidget);
  });

  testWidgets('the Arabic renewal line is Arabic', (tester) async {
    await _pump(
      tester,
      _plan(cycle: 'annual', expiresAt: DateTime.utc(2027, 3, 4)),
      locale: 'ar',
    );

    expect(find.textContaining('تتجدّد'), findsOneWidget);
    expect(find.textContaining('سنوي'), findsOneWidget);
  });
}
