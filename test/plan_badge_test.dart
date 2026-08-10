import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:saqqar_app/core/i18n/app_localizations.dart';
import 'package:saqqar_app/core/theme/app_theme.dart';
import 'package:saqqar_app/features/account/widgets/plan_badge.dart';
import 'package:saqqar_app/features/account/widgets/plan_usage_card.dart';
import 'package:saqqar_app/features/billing/data/plan_models.dart';
import 'package:saqqar_app/features/billing/data/plan_tier_models.dart';
import 'package:saqqar_app/features/billing/view_model/plan_cubit.dart';

/// Guards the plan badge against naming a tier the user is already on for free.
///
/// [PlanBadge]'s contract is "only render this for non-free plans", but two of
/// its three call sites ignored [PlanSnapshot.showBadge] and passed
/// `name.isEmpty ? slug : name` — so a free account with an empty server-side
/// plan name rendered a pill reading the raw wire slug: **`free`**.
///
/// App Review screenshotted exactly that pill on the Usage screen and opened a
/// Guideline 2.1(b) inquiry: a tier called "free" implies a paid tier exists,
/// which implies a purchase happening somewhere outside In-App Purchase.
/// Nothing is for sale — the badge was pure noise, against its own contract.
///
/// The contract these tests pin: a badge renders only when the plan is *both*
/// non-free *and* server-named. No slug ever reaches the screen.
void main() {
  UsageWindow window() =>
      const UsageWindow(used: 0, cap: 625000, pct: 0, remaining: 625000);

  PlanSnapshot snapshot({required String slug, required String name}) =>
      PlanSnapshot(
        slug: slug,
        name: name,
        exempt: false,
        day: window(),
        week: window(),
        month: window(),
        features: const PlanFeatures(),
      );

  PlanTier tier({required String slug, required String name}) => PlanTier(
        slug: slug,
        name: name,
        sort: 0,
        priceMonthlyCents: 0,
        priceAnnualCents: 0,
        dailyTokens: 625000,
        dailyBurstTokens: 625000,
        weeklyTokens: 3500000,
        monthlyTokens: 15000000,
        maxProjects: null,
        maxEnvsPerProject: null,
        features: const PlanFeatures(),
      );

  group('PlanSnapshot.showBadge', () {
    test('is false on the free tier, named or not', () {
      expect(snapshot(slug: 'free', name: '').showBadge, isFalse);
      expect(snapshot(slug: 'free', name: 'Free').showBadge, isFalse);
    });

    test('is false for a paid tier the server left unnamed', () {
      // The case that produced the "free" pill: no name to show, and the old
      // fallback reached for the slug instead of rendering nothing.
      expect(snapshot(slug: 'pro', name: '').showBadge, isFalse);
    });

    test('is true for a named paid tier', () {
      expect(snapshot(slug: 'pro', name: 'Pro').showBadge, isTrue);
    });
  });

  group('PlanTier.showBadge', () {
    test('mirrors PlanSnapshot — free and unnamed tiers get no badge', () {
      expect(tier(slug: 'free', name: 'Free').showBadge, isFalse);
      expect(tier(slug: 'pro', name: '').showBadge, isFalse);
      expect(tier(slug: 'pro', name: 'Pro').showBadge, isTrue);
    });
  });

  group('PlanUsageCard', () {
    Widget host(PlanSnapshot plan, {String locale = 'en'}) =>
        BlocProvider<PlanCubit>(
          create: (_) => PlanCubit()..update(plan),
          child: MaterialApp(
            locale: Locale(locale),
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: const [Locale('en'), Locale('ar')],
            theme: AppTheme.light(Locale(locale)),
            home: const Scaffold(body: PlanUsageCard()),
          ),
        );

    testWidgets('a free account sees usage bars but no plan badge',
        (tester) async {
      await tester.pumpWidget(host(snapshot(slug: 'free', name: '')));
      await tester.pump();

      expect(find.byType(PlanBadge), findsNothing);
      // The exact pill App Review screenshotted — the slug must never render.
      expect(find.text('free'), findsNothing);
      // The usage bars are informational and stay on every platform.
      expect(find.byType(LinearProgressIndicator), findsNWidgets(3));
    });

    testWidgets('a named paid account still gets its badge', (tester) async {
      await tester.pumpWidget(host(snapshot(slug: 'pro', name: 'Pro')));
      await tester.pump();

      expect(find.byType(PlanBadge), findsOneWidget);
      // "Professional", not the snapshot's "Pro". The badge resolves through
      // `PlanCopy.nameFor`, which is what lets the Arabic case below work at
      // all — and it also settles a disagreement the app used to ship with:
      // `/usage/` calls this tier "Pro", `/plans/` and saqqaar.com call it
      // "Professional", and the account badge and the pricing card sat side
      // by side saying different things.
      expect(find.text('Professional'), findsOneWidget);
    });

    testWidgets('the badge is Arabic on an Arabic device', (tester) async {
      // The regression this guards: `plan_name` is English on the wire, so a
      // bare `PlanBadge(name: plan.name)` put a Latin pill on an otherwise
      // Arabic account screen.
      await tester.pumpWidget(
        host(snapshot(slug: 'pro', name: 'Pro'), locale: 'ar'),
      );
      await tester.pump();

      expect(find.text('الاحترافي'), findsOneWidget);
      expect(find.text('Pro'), findsNothing);
    });

    testWidgets('an unknown slug keeps whatever the server called it',
        (tester) async {
      // No copy on this side ⇒ no override. The badge is still filled, just
      // from the wire — the same degradation the pricing card makes.
      await tester.pumpWidget(
        host(snapshot(slug: 'max-100x', name: 'Enterprise'), locale: 'ar'),
      );
      await tester.pump();

      expect(find.text('Enterprise'), findsOneWidget);
    });
  });
}
