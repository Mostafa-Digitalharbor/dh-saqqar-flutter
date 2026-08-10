// The footer "Manage subscription on saqqaar.com" button.
//
// Payment is the website's job end to end: the app sends the user to
// `/pricing/`, the backend confirms with Paymob and activates the plan, and
// the app only reads the result back. That makes *reaching the website* the
// single payment-related thing the app has to get right — and until
// 2026-08-04 it could fail silently for exactly the users who needed it most.
//
// Every route to saqqaar.com hung off a tier card, and those are suppressed on
// the tier you're on and everything below it (that guard is correct: it stops
// the app selling a downgrade the server can't apply). The consequence was
// that the top tier — a paying Business customer — saw a price list with no
// way out of it at all. Renewals, cancellations, card changes and receipts all
// live on the web, so the way there cannot depend on having something left to
// buy.
//
// The suppression cases are pinned too: an iOS-shaped build (`showPaidUpsell`
// off) must show no external-purchase route whatsoever, which is the whole
// point of the switch.

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saqqar_app/core/i18n/app_localizations.dart';
import 'package:saqqar_app/core/theme/app_theme.dart';
import 'package:saqqar_app/features/billing/data/billing_visibility.dart';
import 'package:saqqar_app/features/billing/data/plans_api.dart';
import 'package:saqqar_app/features/billing/data/plan_tier_models.dart';
import 'package:saqqar_app/features/billing/data/web_checkout.dart';
import 'package:saqqar_app/features/billing/view/pricing_screen.dart';
import 'package:saqqar_app/features/billing/view_model/plan_cubit.dart';

/// Two tiers and a `current_plan`, in the wire shape `/api/v1/plans/` returns.
class _FakePlansApi extends PlansApi {
  _FakePlansApi(this.current) : super(Dio());

  final String current;

  @override
  Future<PlansResponse> list() async => PlansResponse.fromJson({
        'current_plan': current,
        'plans': const [
          {
            'slug': 'pro',
            'name': 'Professional',
            'sort': 3,
            'price_monthly_cents': 2000,
            'price_annual_cents': 1000,
            'monthly_tokens': 35000000,
          },
          {
            'slug': 'max-20x',
            'name': 'Business',
            'sort': 4,
            'price_monthly_cents': 10000,
            'price_annual_cents': 5000,
            'monthly_tokens': 170000000,
          },
        ],
      });
}

Future<void> _pump(
  WidgetTester tester, {
  required String current,
  String locale = 'en',
}) async {
  // Tall viewport on purpose. The buttons under test sit at the bottom of a
  // `ListView`, and a sliver never inflates children below the fold — at the
  // default 800×600 the footer isn't absent, it simply doesn't exist yet, and
  // `findsNothing` would pass for the wrong reason in all three of the
  // "should be there" cases.
  tester.view.physicalSize = const Size(1000, 5000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

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
      home: BlocProvider<PlanCubit>(
        create: (_) => PlanCubit(),
        child: MultiRepositoryProvider(
          providers: [
            RepositoryProvider<PlansApi>(create: (_) => _FakePlansApi(current)),
            RepositoryProvider<Dio>(create: (_) => Dio()),
          ],
          child: const PricingScreen(),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  tearDown(() => debugShowPaidUpsell = null);

  testWidgets('the top tier still gets a way to reach the website',
      (tester) async {
    // The regression. On `max-20x` (highest `sort`) nothing is sellable, so
    // every per-tier button is gone — and before this the screen offered the
    // user nothing at all.
    debugShowPaidUpsell = true;
    await _pump(tester, current: 'max-20x');

    expect(find.text('Subscribe on the web'), findsNothing);
    expect(find.text('Manage subscription on saqqaar.com'), findsOneWidget);
  });

  testWidgets('it is there on a lower tier too, alongside the upgrades',
      (tester) async {
    // Not a fallback that only appears when the upgrades vanish — managing an
    // existing subscription is a separate errand from buying a bigger one.
    debugShowPaidUpsell = true;
    await _pump(tester, current: 'pro');

    expect(find.text('Subscribe on the web'), findsOneWidget); // → Business
    expect(find.text('Manage subscription on saqqaar.com'), findsOneWidget);
  });

  testWidgets('with the purchase surface off, neither button exists',
      (tester) async {
    // The iOS-shaped build. App Store 3.1.1 forbids steering to an external
    // purchase, and "manage your subscription on our website" is steering.
    debugShowPaidUpsell = false;
    await _pump(tester, current: 'max-20x');

    expect(find.text('Manage subscription on saqqaar.com'), findsNothing);
    expect(find.text('Subscribe on the web'), findsNothing);
    // What replaces it: a statement of fact with no link and no button.
    expect(find.text('Plans are managed on saqqaar.com.'), findsOneWidget);
  });

  testWidgets('the Arabic label is Arabic', (tester) async {
    debugShowPaidUpsell = true;
    await _pump(tester, current: 'max-20x', locale: 'ar');

    expect(find.text('إدارة الاشتراك على saqqaar.com'), findsOneWidget);
  });

  test('it opens the plain catalogue, not a tier page', () {
    // An empty slug means no `?plan=`: the user is going to manage what they
    // already have, and preselecting a tier would be the app guessing at an
    // errand it can't see.
    expect(WebCheckout.nextPath(''), '/pricing/');
    expect(WebCheckout.nextPath('pro'), '/pricing/?plan=pro');
  });
}
