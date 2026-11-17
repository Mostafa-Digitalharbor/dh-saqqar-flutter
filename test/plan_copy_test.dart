// The plans screen says what saqqaar.com/pricing says — because it is now
// reading the same source.
//
// History, because it explains the shape of these tests. `/api/v1/plans/`
// used to carry the commercial facts and nothing a customer would call a plan
// description, so this screen filled the space with what it had: two token
// caps quoted in "ST" — a unit that appears nowhere on the website — a
// projects count, and four capability booleans drawn as a green-tick /
// grey-cross matrix the website does not publish. Someone comparing the two
// surfaces before paying found two different products.
//
// The stopgap was a slug-keyed mirror of the website's wording inside the app.
// It matched on the day it was written, and it was a snapshot, not a
// mechanism: an edit on saqqaar.com would have left the app wrong until a
// build cleared store review.
//
// As of the backend deploy on 2026-08-09 the endpoint carries `tagline`,
// `features_intro`, `features_text`, `price_note` and `most_popular` from the
// same server module the web page renders from, plus a `vat` object. The
// mirror is gone. What is left on this side is Arabic — the endpoint is
// English-only by design, because the web page itself translates in the
// browser — so `PlanCopy.translate` is the mobile half of that same
// mechanism, keyed by the English text.
//
// These tests pin: the copy arrives from the wire and renders, the Arabic map
// still catches it, an UNKNOWN tier is fully described with no release, and an
// UNTRANSLATED bullet degrades to English rather than vanishing.

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saqqar_app/core/i18n/app_localizations.dart';
import 'package:saqqar_app/core/theme/app_theme.dart';
import 'package:saqqar_app/features/account/widgets/current_plan_card.dart';
import 'package:saqqar_app/features/billing/data/billing_visibility.dart';
import 'package:saqqar_app/features/billing/data/plan_copy.dart';
import 'package:saqqar_app/features/billing/data/plan_tier_models.dart';
import 'package:saqqar_app/features/billing/data/plans_api.dart';
import 'package:saqqar_app/features/billing/view/pricing_screen.dart';
import 'package:saqqar_app/features/billing/view_model/plan_cubit.dart';

/// **A verbatim capture of `GET https://saqqaar.com/api/v1/plans/`,
/// 2026-08-09.** Not a hand-written approximation — the copy fields are the
/// whole subject of these tests, and a fixture someone typed from memory would
/// pass while the real payload rendered blank.
///
/// Slugs matter more than names: `max-5x` is the tier the website calls Solo
/// and `max-20x` is Business. The two have nothing to do with each other,
/// which is why the name is looked up rather than derived.
const Map<String, Object?> _kPlansWire = {
  'ok': true,
  'current_plan': null,
  'vat': {'active': true, 'included_in_price': false, 'rate_percent': 15.0},
  'plans': <Object?>[
    {
      'slug': 'free',
      'name': 'Free',
      'sort': 0,
      'price_monthly_cents': 0,
      'price_annual_cents': 0,
      'features': {
        'voice': false,
        'postgres': false,
        'github': false,
        'server_shell': false,
      },
      'tagline': 'Try Saqqar',
      'most_popular': false,
      'features_intro': null,
      'features_text': <Object?>[
        'Chat with Saqqar on web and mobile',
        'Connect one Odoo database',
        'Search, read and count records',
        'Generate Excel, PDF and Word reports',
        'Voice input (speech to text)',
        'Read Odoo addons',
        'Memory across conversations',
      ],
      'price_note': 'Free for everyone',
    },
    {
      'slug': 'starter',
      'name': 'Starter',
      'sort': 1,
      'price_monthly_cents': 200,
      'price_annual_cents': 100,
      'tagline': 'Get started',
      'most_popular': false,
      'features_intro': 'Everything in Free, plus:',
      'features_text': <Object?>[
        'A little more monthly usage',
        'Priority over the free tier at busy times',
      ],
      'price_note':
          r'$1/mo billed annually ($12/yr) · $2/mo billed monthly ($24/yr).',
    },
    {
      'slug': 'max-5x',
      'name': 'Solo',
      'sort': 2,
      'price_monthly_cents': 1000,
      'price_annual_cents': 500,
      'tagline': 'For individuals',
      'most_popular': false,
      'features_intro': 'Everything in Starter, plus:',
      'features_text': <Object?>[
        'Much higher monthly usage',
        'Create and edit Odoo records (with approval)',
        'Multiple databases and environments',
        'Bulk imports (create-many / load)',
        'Priority access to the best models',
      ],
      'price_note':
          r'$5/mo billed annually ($60/yr) · $10/mo billed monthly ($120/yr).',
    },
    {
      'slug': 'pro',
      'name': 'Professional',
      'sort': 3,
      'price_monthly_cents': 2000,
      'price_annual_cents': 1000,
      'features': {
        'voice': true,
        'postgres': true,
        'github': true,
        'server_shell': true,
      },
      'tagline': 'For power users',
      'most_popular': true,
      'features_intro': 'Everything in Solo, plus:',
      'features_text': <Object?>[
        'Build and edit Odoo addons, download as .zip',
        'Trigger server actions and install modules',
        'Higher usage limits',
        'Priority support',
      ],
      'price_note':
          r'$10/mo billed annually ($120/yr) · $20/mo billed monthly ($240/yr).',
    },
    {
      'slug': 'max-20x',
      'name': 'Business',
      'sort': 4,
      'price_monthly_cents': 9800,
      'price_annual_cents': 4900,
      'tagline': 'For teams & heavy use',
      'most_popular': false,
      'features_intro': 'Everything in Professional, plus:',
      'features_text': <Object?>[
        'Highest usage limits',
        'Direct database and secure server access',
        'Early access to new features',
        'Priority support',
        'Dedicated onboarding',
      ],
      'price_note':
          r'$49/mo billed annually ($588/yr) · $98/mo billed monthly ($1176/yr).',
    },
  ],
};

class _FakePlansApi extends PlansApi {
  _FakePlansApi([this.wire = _kPlansWire]) : super(Dio());

  final Map<String, Object?> wire;

  @override
  Future<PlansResponse> list() async =>
      PlansResponse.fromJson(Map<String, dynamic>.from(wire));
}

Future<void> _pump(
  WidgetTester tester, {
  String locale = 'en',
  PlansApi? api,
  Size size = const Size(1000, 8000),
}) async {
  // Tall viewport by default: the cards live in a `ListView`, and a sliver
  // never inflates children below the fold — at 800×600 a bullet on the
  // Business card is not missing, it does not exist yet, and `findsNothing`
  // would pass for the wrong reason.
  tester.view.physicalSize = size;
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
            RepositoryProvider<PlansApi>(create: (_) => api ?? _FakePlansApi()),
            RepositoryProvider<Dio>(create: (_) => Dio()),
          ],
          child: const PricingScreen(),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// The account screen's current-plan card, on the tier [current].
Future<void> _pumpAccountCard(
  WidgetTester tester, {
  required String current,
  String locale = 'en',
}) async {
  tester.view.physicalSize = const Size(1000, 4000);
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
            RepositoryProvider<PlansApi>(
              create: (_) => _FakePlansApi({
                ..._kPlansWire,
                'current_plan': current,
              }),
            ),
            RepositoryProvider<Dio>(create: (_) => Dio()),
          ],
          child: const Scaffold(body: CurrentPlanCard()),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// Every English string the live payload can put on screen.
List<String> _wireEnglish() {
  final out = <String>[];
  for (final row in (_kPlansWire['plans']! as List).cast<Map<String, Object?>>()) {
    for (final key in ['tagline', 'features_intro']) {
      final v = row[key];
      if (v is String && v.isNotEmpty) out.add(v);
    }
    out.addAll((row['features_text']! as List).cast<String>());
  }
  return out;
}

void main() {
  setUp(() => debugShowPaidUpsell = true);
  tearDown(() => debugShowPaidUpsell = null);

  group('the wire is the source', () {
    test('the model reads every descriptive field the server sends', () {
      final pro = PlansResponse.fromJson(
        Map<String, dynamic>.from(_kPlansWire),
      ).plans.firstWhere((p) => p.slug == 'pro');

      expect(pro.tagline, 'For power users');
      expect(pro.mostPopular, isTrue);
      expect(pro.featuresIntro, 'Everything in Solo, plus:');
      expect(pro.featuresText, hasLength(4));
      expect(pro.featuresText.first, 'Build and edit Odoo addons, download as .zip');
      // `features_text` and `features` are two different objects and always
      // will be — one is sales copy, the other gates behaviour. Reading the
      // bullets off the boolean object is the mistake the naming exists to
      // prevent.
      expect(pro.features.enabled('server_shell'), isTrue);
    });

    test('the free tier has no ladder header, and says so with null', () {
      final free = PlansResponse.fromJson(
        Map<String, dynamic>.from(_kPlansWire),
      ).plans.first;

      expect(free.slug, 'free');
      expect(free.featuresIntro, isEmpty); // wire null → no header rendered
      expect(free.priceNote, 'Free for everyone');
    });

    test('VAT is read, not assumed', () {
      final vat = PlansResponse.fromJson(
        Map<String, dynamic>.from(_kPlansWire),
      ).vat;

      expect(vat.active, isTrue);
      expect(vat.includedInPrice, isFalse);
      expect(vat.addedAtCheckout, isTrue);
      // `15.0` must print as "15". A rate rendered as "15.0% VAT" reads as a
      // rounding artefact on a price list.
      expect(vat.rateLabel, '15');
    });

    test('a server with no vat object claims no tax at all', () {
      // The rate used to be written into the string. Absent `vat`, the honest
      // reading is "we were not told", which must not render as 15%.
      final vat = PlansResponse.fromJson(const {'plans': <Object?>[]}).vat;
      expect(vat.addedAtCheckout, isFalse);
    });

    test('one malformed row does not empty the price list', () {
      final res = PlansResponse.fromJson(const {
        'plans': <Object?>[
          'not a plan',
          {'slug': 'pro', 'name': 'Professional', 'sort': 3},
        ],
      });
      expect(res.plans, hasLength(1));
      expect(res.plans.single.slug, 'pro');
    });
  });

  group('the Arabic map still catches what the server sends', () {
    test('every key PlanCopy references resolves to real English copy', () {
      // `lookup` returns its fallback for a key neither table has, so a typo
      // renders the server's English rather than the identifier — invisible in
      // review. Arabic is covered by `i18n_parity_test`, which already
      // requires both tables to define the same key set.
      final en = AppStrings(const Locale('en'));
      final missing = PlanCopy.allKeys
          .where((k) => en.lookup(k, fallback: '').trim().isEmpty)
          .toList();

      expect(
        missing,
        isEmpty,
        reason: 'plan_copy.dart references i18n keys that do not exist: '
            '$missing — add them to BOTH tables in app_strings.dart.',
      );
    });

    test('every English string the live payload sends has a translation', () {
      // THE load-bearing test. The lookup keys on the English text, so an edit
      // to either side — the server's wording or ours — silently reverts a
      // tier to English on an Arabic phone. Nothing else would catch that:
      // the screen still renders, just in the wrong language.
      final ar = AppStrings(const Locale('ar'));
      final untranslated = [
        for (final english in _wireEnglish())
          if (PlanCopy.translate(ar, english) == english) english,
      ];

      expect(
        untranslated,
        isEmpty,
        reason: 'These strings come off /api/v1/plans/ with no Arabic — the '
            'English in app_strings.dart must match the server byte for '
            'byte:\n${untranslated.join('\n')}',
      );
    });

    test('it localizes exactly the five tier names the server serves', () {
      expect(
        PlanCopy.knownSlugs,
        containsAll(<String>['free', 'starter', 'max-5x', 'pro', 'max-20x']),
      );
    });

    test('an untranslated string renders as the server sent it, not blank', () {
      // A bullet the backend adds tomorrow. Showing it in English is the
      // point: a tier silently missing one of its selling points is worse
      // than a tier that mixes languages for one line.
      final ar = AppStrings(const Locale('ar'));
      expect(
        PlanCopy.translate(ar, 'A brand new selling point'),
        'A brand new selling point',
      );
      expect(PlanCopy.translate(ar, null), isEmpty);
      expect(PlanCopy.translate(ar, '   '), isEmpty);
    });

    test('matching survives case and stray whitespace', () {
      final ar = AppStrings(const Locale('ar'));
      expect(
        PlanCopy.translate(ar, '  for power users  '),
        PlanCopy.translate(ar, 'For power users'),
      );
    });

    test('the bullet two tiers share translates the same on both', () {
      // "Priority support" is on Professional and on Business. The reverse
      // index can only hold one key for it; both must mean the same thing.
      final ar = AppStrings(const Locale('ar'));
      expect(
        ar.lookup('plan_copy_pro_f4'),
        ar.lookup('plan_copy_business_f4'),
        reason: 'two tiers send the same English bullet but this build '
            'translates it two different ways — the reverse index picks one '
            'arbitrarily, so one of the cards would be wrong',
      );
    });
  });

  group('English', () {
    testWidgets('each tier carries the website tagline and bullets',
        (tester) async {
      await _pump(tester);

      // Taglines — the line under the name on every web card.
      expect(find.text('Try Saqqar'), findsOneWidget);
      expect(find.text('For individuals'), findsOneWidget);
      expect(find.text('For power users'), findsOneWidget);
      expect(find.text('For teams & heavy use'), findsOneWidget);

      // The ladder headers, which is what makes a four-item list mean "four
      // *more* than the tier below".
      expect(find.text('Everything in Free, plus:'), findsOneWidget);
      expect(find.text('Everything in Starter, plus:'), findsOneWidget);
      expect(find.text('Everything in Solo, plus:'), findsOneWidget);
      expect(find.text('Everything in Professional, plus:'), findsOneWidget);

      // One bullet from each tier — first, last and a middle one, so a list
      // silently truncated at the top or bottom is caught.
      expect(find.text('Chat with Saqqar on web and mobile'), findsOneWidget);
      expect(find.text('Memory across conversations'), findsOneWidget);
      expect(
        find.text('Priority over the free tier at busy times'),
        findsOneWidget,
      );
      expect(
        find.text('Create and edit Odoo records (with approval)'),
        findsOneWidget,
      );
      expect(
        find.text('Build and edit Odoo addons, download as .zip'),
        findsOneWidget,
      );
      expect(find.text('Dedicated onboarding'), findsOneWidget);
    });

    testWidgets('the badge lands on the tier the SERVER pushes', (tester) async {
      // `most_popular` used to be a boolean written into the app beside a
      // slug. It now rides on the row, so the backend can move the badge.
      await _pump(tester);
      expect(find.text('Most popular'), findsOneWidget);
    });

    testWidgets('prices come from the wire, both cycles, with the VAT rider',
        (tester) async {
      await _pump(tester);

      // Annual is the default cycle, so the headline figure is the annual
      // per-month one: pro = 1000 cents → $10.
      expect(find.text('\$10'), findsOneWidget);
      expect(find.text('\$49'), findsOneWidget); // Business annual
      expect(find.text('\$0'), findsOneWidget); // Free

      // Every figure below is interpolated from the same cents this row
      // carries, so the line cannot disagree with the figure above it.
      expect(
        find.text(
          '\$1/mo billed annually (\$12/yr) · \$2/mo billed monthly (\$24/yr).',
        ),
        findsOneWidget,
      );
      expect(
        find.text(
          '\$49/mo billed annually (\$588/yr) · '
          '\$98/mo billed monthly (\$1176/yr).',
        ),
        findsOneWidget,
      );

      // Free is billed on neither cycle, so it gets the server's own note
      // instead of a two-cycle line that would read "$0 · $0".
      expect(find.text('Free for everyone'), findsOneWidget);
      expect(find.text('+ VAT'), findsNWidgets(4)); // every tier but Free
      expect(
        find.text('Prices exclude VAT. 15% VAT is added at checkout.'),
        findsOneWidget,
      );
    });

    testWidgets('composed price lines agree with the server, to the character',
        (tester) async {
      // The paid tiers compose this line locally so Arabic can read it, which
      // is only safe while it says exactly what `price_note` says. This is the
      // test that keeps that true — if the backend rewords the note, it fails
      // here rather than shipping two different sentences to two surfaces.
      await _pump(tester);
      for (final row
          in (_kPlansWire['plans']! as List).cast<Map<String, Object?>>()) {
        if (row['slug'] == 'free') continue;
        expect(
          find.text(row['price_note']! as String),
          findsOneWidget,
          reason: '${row['slug']}: the composed billing line no longer matches '
              'the server\'s price_note',
        );
      }
    });

    testWidgets('the cycle switch moves the headline figure only',
        (tester) async {
      await _pump(tester);
      expect(find.text('\$10'), findsOneWidget); // pro, annual

      await tester.tap(find.text('Monthly'));
      await tester.pumpAndSettle();

      expect(find.text('\$20'), findsOneWidget); // pro, monthly
      expect(find.text('\$98'), findsOneWidget); // Business, monthly
      // The two-cycle line quotes both regardless, so switching never hides
      // what the other cycle costs.
      expect(
        find.text(
          '\$49/mo billed annually (\$588/yr) · '
          '\$98/mo billed monthly (\$1176/yr).',
        ),
        findsOneWidget,
      );
    });
  });

  group('Arabic', () {
    testWidgets('the tier names and bullets are Arabic, as on the web',
        (tester) async {
      await _pump(tester, locale: 'ar');

      // The wire `name` is English-only ("Professional") and stays that way
      // permanently — the backend confirmed it on 2026-08-09. The website's
      // Arabic page says "الاحترافي".
      expect(find.text('الاحترافي'), findsOneWidget);
      expect(find.text('الأعمال'), findsOneWidget);
      expect(find.text('المبتدئ'), findsOneWidget);
      expect(find.text('الفردي'), findsOneWidget);

      expect(find.text('للمستخدمين المتقدمين'), findsOneWidget);
      expect(find.text('كل ما في الفردي، بالإضافة إلى:'), findsOneWidget);
      expect(find.text('الدردشة مع صقّار على الويب والجوال'), findsOneWidget);
      expect(find.text('إعداد مخصص'), findsOneWidget);
      expect(find.text('الأكثر شيوعًا'), findsOneWidget);
    });

    testWidgets('no English is left in the price block', (tester) async {
      await _pump(tester, locale: 'ar');

      // saqqaar.com leaves this line in English on its Arabic page, where the
      // bidi algorithm reorders it into nonsense. Composed here instead — from
      // the server's own cents.
      expect(find.textContaining('billed annually'), findsNothing);
      expect(find.textContaining('عند الدفع السنوي'), findsWidgets);
      expect(find.text('+ ض.ق.م'), findsNWidgets(4));
      expect(find.textContaining('تُضاف 15%'), findsOneWidget);
      expect(find.text('مجاني للجميع'), findsOneWidget);
    });
  });

  group('what is gone', () {
    testWidgets('the ST caps, the projects row and the tick matrix',
        (tester) async {
      // All four were the screen describing the API instead of the product.
      // "ST" is not a unit any buyer has seen; the boolean rows drew a
      // capability matrix saqqaar.com does not publish, complete with grey
      // crosses telling a Free user four things they cannot have.
      await _pump(tester);

      expect(find.textContaining('ST'), findsNothing);
      expect(find.text('Projects'), findsNothing);
      expect(find.text('Postgres queries'), findsNothing);
      expect(find.text('Server shell'), findsNothing);
      expect(find.text('Daily'), findsNothing);
    });
  });

  group('with the purchase surface off (the iOS-shaped build)', () {
    testWidgets('no price survives, but the plan descriptions do',
        (tester) async {
      // App Store 3.1.1 is about prices and steering, not about describing
      // what a plan includes — and a comparison with the numbers stripped is
      // exactly what this screen is for on iOS.
      debugShowPaidUpsell = false;
      await _pump(tester);

      expect(find.text('\$10'), findsNothing);
      expect(find.text('+ VAT'), findsNothing);
      expect(find.textContaining('billed annually'), findsNothing);
      expect(find.text('Monthly'), findsNothing); // the cycle switch
      expect(find.text('Free for everyone'), findsNothing);

      expect(find.text('For power users'), findsOneWidget);
      expect(find.text('Everything in Solo, plus:'), findsOneWidget);
      expect(find.text('Dedicated onboarding'), findsOneWidget);
    });
  });

  group('the account card says the same thing as the catalogue', () {
    // Two screens describing one plan used to disagree completely: the
    // account card listed "18M ST" daily and monthly and named the tier
    // "Professional" even in Arabic, while the catalogue listed bullets. Both
    // now read the tier the server sent, so "the same description" is a fact
    // rather than a convention two files have to keep.
    testWidgets('it carries the tagline and bullets, not the ST caps',
        (tester) async {
      await _pumpAccountCard(tester, current: 'pro');

      expect(find.text('For power users'), findsOneWidget);
      expect(find.text('Build and edit Odoo addons, download as .zip'),
          findsOneWidget);
      expect(find.textContaining('ST'), findsNothing);
      expect(find.text('Daily'), findsNothing);
    });

    testWidgets('the badge is the localized name', (tester) async {
      await _pumpAccountCard(tester, current: 'pro', locale: 'ar');

      expect(find.text('الاحترافي'), findsOneWidget);
      expect(find.text('Professional'), findsNothing);
      expect(find.text('للمستخدمين المتقدمين'), findsOneWidget);
    });

    test('every plan-name site resolves through one helper', () {
      // The three badges (account card, plan & usage card, profile hero) drift
      // the moment one of them reads `plan.name` directly again.
      final ar = AppStrings(const Locale('ar'));
      expect(
        PlanCopy.nameFor(ar, slug: 'max-20x', fallback: 'Business'),
        'الأعمال',
      );
      // A slug with no copy keeps whatever the server sent rather than
      // rendering blank.
      expect(
        PlanCopy.nameFor(ar, slug: 'max-100x', fallback: 'Enterprise'),
        'Enterprise',
      );
      // …but a RENAMED slug still finds its Arabic by the English name, so a
      // slug change on the server does not silently un-translate a tier.
      expect(
        PlanCopy.nameFor(ar, slug: 'pro-v2', fallback: 'Professional'),
        'الاحترافي',
      );
    });
  });

  group('a tier this build has never heard of', () {
    testWidgets('is fully described anyway, with no release', (tester) async {
      // The whole point of the 2026-08-09 change. Under the old mirror this
      // tier rendered a bare name and nothing else, and stayed that way until
      // someone shipped a build.
      await _pump(
        tester,
        api: _FakePlansApi(const {
          'plans': <Object?>[
            {
              'slug': 'max-100x',
              'name': 'Enterprise',
              'sort': 9,
              'price_monthly_cents': 50000,
              'price_annual_cents': 25000,
              'tagline': 'For very large teams',
              'most_popular': true,
              'features_intro': 'Everything in Business, plus:',
              'features_text': <Object?>['A dedicated cluster'],
            },
          ],
        }),
      );

      expect(find.text('Enterprise'), findsOneWidget);
      expect(find.text('\$250'), findsOneWidget);
      expect(find.text('For very large teams'), findsOneWidget);
      expect(find.text('Everything in Business, plus:'), findsOneWidget);
      expect(find.text('A dedicated cluster'), findsOneWidget);
      expect(find.text('Most popular'), findsOneWidget);
    });

    testWidgets('a tier the server does not describe invents nothing',
        (tester) async {
      await _pump(
        tester,
        api: _FakePlansApi(const {
          'plans': <Object?>[
            {
              'slug': 'max-100x',
              'name': 'Enterprise',
              'sort': 9,
              'price_monthly_cents': 50000,
              'price_annual_cents': 25000,
            },
          ],
        }),
      );

      // Name and price came down the wire, so they render. Nothing else does:
      // bullets borrowed from a neighbouring tier is how a price list starts
      // lying.
      expect(find.text('Enterprise'), findsOneWidget);
      expect(find.text('\$250'), findsOneWidget);
      expect(find.textContaining('Everything in'), findsNothing);
      expect(find.text('Most popular'), findsNothing);
    });
  });
}
