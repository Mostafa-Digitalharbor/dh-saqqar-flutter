// The Saqqar Apps gallery, driven through the widget it actually ships.
//
// `apps_test.dart` covers the model and the cubit; `apps_localization_test`
// covers the string resolution in isolation. Neither of them renders a tile,
// so the thing the user complained about — "the Apps page is all English" —
// was true while every one of those tests passed. The catalogue arrives from
// the server in English and the screen is the only place the two halves meet.
//
// So these tests assert on PIXELS: what the grid, the chips and the filter
// pills say in each locale, for the packages the server really sends.

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saqqar_app/core/i18n/app_localizations.dart';
import 'package:saqqar_app/core/theme/app_theme.dart';
import 'package:saqqar_app/features/apps/data/app_package_models.dart';
import 'package:saqqar_app/features/apps/data/apps_api.dart';
import 'package:saqqar_app/features/apps/view/apps_screen.dart';
import 'package:saqqar_app/features/apps/view_model/apps_cubit.dart';

/// The live catalogue, field for field, captured from `GET /api/v1/apps/`
/// on a signed-in device (2026-08-22). Copied verbatim rather than invented,
/// because the two details that broke the screen are both details of the real
/// data: the **hyphenated** slugs (`chart-of-accounts`), and the fifth
/// package (`factory` / "Your factory"), which no key matched at all.
final _live = <SaqqarApp>[
  SaqqarApp.fromJson(const {
    'slug': 'zatca',
    'name': 'ZATCA e-invoicing',
    'tagline': 'Onboard Saudi Fatoora Phase-2 e-invoicing on your Odoo — '
        'CSR, OTP, and go-live.',
    'category': 'Compliance · KSA',
    'group': 'Finance',
    'accent': '#14B8A6',
    'icon_svg': '<svg/>',
    'env_required': true,
  }),
  SaqqarApp.fromJson(const {
    'slug': 'whatsapp',
    'name': 'WhatsApp integration',
    'tagline': 'Connect WhatsApp Business (Cloud API) so Odoo can send and '
        'receive messages.',
    'category': 'Messaging',
    'group': 'Integrations',
    'accent': '#25D366',
    'icon_svg': '<svg/>',
    'env_required': true,
  }),
  SaqqarApp.fromJson(const {
    'slug': 'chart-of-accounts',
    'name': 'Chart of Accounts builder',
    'tagline': 'Build or import a clean, localized chart of accounts and '
        'wire up default postings.',
    'category': 'Accounting',
    'group': 'Accounting',
    'accent': '#6366F1',
    'icon_svg': '<svg/>',
    'env_required': true,
  }),
  SaqqarApp.fromJson(const {
    'slug': 'bank-reconciliation',
    'name': 'Bank reconciliation',
    'tagline': 'Set up bank journals, statement import, and reconciliation '
        'rules that match automatically.',
    'category': 'Accounting',
    'group': 'Accounting',
    'accent': '#8B5CF6',
    'icon_svg': '<svg/>',
    'env_required': true,
  }),
  SaqqarApp.fromJson(const {
    'slug': 'factory',
    'name': 'Your factory',
    'tagline': 'Production status, missing material, and a delivery date '
        'computed from your Odoo.',
    'category': 'Manufacturing',
    'group': 'Operations',
    'accent': '#F97316',
    'icon_svg': '<svg/>',
    'env_required': true,
  }),
];

class _FakeAppsApi implements AppsApi {
  _FakeAppsApi({List<SaqqarApp>? apps, this.error}) : apps = apps ?? _live;

  final List<SaqqarApp> apps;

  /// Thrown from [list] instead of returning, so the screen's failure branch
  /// can be pumped from the same fake.
  final Object? error;
  int listCalls = 0;

  @override
  Future<List<SaqqarApp>> list() async {
    listCalls++;
    if (error != null) throw error!;
    return apps;
  }

  @override
  Future<String> launch(String slug, {String? environmentId}) async => 'c1';
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
    home: child,
  );
}

Future<void> _pumpGallery(
  WidgetTester tester, {
  Locale locale = const Locale('en'),
  _FakeAppsApi? api,
  Size size = const Size(1000, 2400),
}) async {
  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(_harness(
    BlocProvider(
      create: (_) => AppsCubit(api ?? _FakeAppsApi()),
      child: const AppsScreen(),
    ),
    locale: locale,
  ));
  await tester.pumpAndSettle();
}

/// Taps a group chip by its label, scrolling the horizontal strip to it first
/// (the strip is a lazy `ListView`, so a chip past the edge is not built).
Future<void> _tapPill(WidgetTester tester, String label) async {
  final chip = find.text(label);
  if (chip.evaluate().isEmpty) {
    final strip = find.byType(Scrollable).at(1);
    await tester.dragUntilVisible(chip, strip, const Offset(120, 0));
  } else {
    await tester.ensureVisible(chip);
  }
  await tester.pumpAndSettle();
  await tester.tap(chip);
  await tester.pumpAndSettle();
}

/// Every `Text` currently on screen, flattened — the cheapest way to ask
/// "is there any Latin left on this Arabic page?".
List<String> _visibleText(WidgetTester tester) => [
      for (final t in tester.widgetList<Text>(find.byType(Text)))
        t.data ?? t.textSpan?.toPlainText() ?? '',
    ];

void main() {
  group('English', () {
    testWidgets('renders one tile per package with name and tagline',
        (tester) async {
      await _pumpGallery(tester);

      expect(find.text('ZATCA e-invoicing'), findsOneWidget);
      expect(find.text('WhatsApp integration'), findsOneWidget);
      expect(find.text('Chart of Accounts builder'), findsOneWidget);
      expect(find.text('Bank reconciliation'), findsOneWidget);
      expect(find.text('Your factory'), findsOneWidget);
      expect(find.text('Apps'), findsOneWidget);
      expect(
        find.textContaining('Onboard Saudi Fatoora'),
        findsOneWidget,
        reason: 'the tagline is half the card',
      );
    });

    testWidgets('the group chips show the taxonomy', (tester) async {
      await _pumpGallery(tester, size: const Size(1000, 900));

      expect(find.text('Finance'), findsOneWidget);
      expect(find.text('Integrations'), findsOneWidget);
      expect(find.text('Accounting'), findsOneWidget);
      expect(find.text('Operations'), findsOneWidget);
    });
  });

  group('Arabic', () {
    testWidgets('every package name and tagline is Arabic', (tester) async {
      await _pumpGallery(tester, locale: const Locale('ar'));

      expect(find.text('الفوترة الإلكترونية (زاتكا)'), findsOneWidget);
      expect(find.text('تكامل واتساب'), findsOneWidget);
      expect(find.text('مُنشئ شجرة الحسابات'), findsOneWidget);
      expect(find.text('التسوية البنكية'), findsOneWidget);
      // The card that was English on an otherwise Arabic screen — the whole
      // reason this file exists.
      expect(find.text('مصنعك'), findsOneWidget);
      expect(find.text('التطبيقات'), findsOneWidget);
    });

    testWidgets('the group chips are Arabic too', (tester) async {
      await _pumpGallery(tester, locale: const Locale('ar'));

      // `findsWidgets`, not an exact count: the pill strip is a lazy
      // horizontal list, so how many of the 5 pills are BUILT depends on the
      // viewport width. The claim under test is "these read as Arabic", not
      // "the strip is this wide".
      expect(find.text('المالية'), findsWidgets);
      expect(find.text('التكاملات'), findsWidgets);
      expect(find.text('المحاسبة'), findsWidgets);
      expect(find.text('العمليات'), findsWidgets);
      expect(find.text('FINANCE'), findsNothing);
      expect(find.text('ACCOUNTING'), findsNothing);
    });

    testWidgets('no Latin sentence survives anywhere on the page',
        (tester) async {
      // The regression this whole change exists for. A single English tagline
      // among four Arabic cards is the exact complaint, and it is invisible to
      // any test that only asserts what IS there.
      await _pumpGallery(tester, locale: const Locale('ar'));

      // Two Latin words in a row = an English phrase. Brand tokens that are
      // legitimately Latin inside Arabic copy ("Cloud API", "Odoo") are one
      // word each in their own right, so the rule keys on prose, not on the
      // presence of the alphabet.
      final englishProse = RegExp(r'[A-Za-z]{2,}\s+[A-Za-z]{2,}');
      final offenders = [
        for (final text in _visibleText(tester))
          if (englishProse.hasMatch(text) && !text.contains('Cloud API')) text,
      ];

      expect(offenders, isEmpty, reason: 'English prose on an Arabic screen');
    });

    testWidgets('lays out right-to-left', (tester) async {
      await _pumpGallery(tester, locale: const Locale('ar'));

      expect(
        Directionality.of(tester.element(find.text('تكامل واتساب'))),
        TextDirection.rtl,
      );
    });
  });

  group('the filter pills', () {
    testWidgets('one per distinct group, plus All', (tester) async {
      // Wide enough that the lazy strip builds every chip.
      await _pumpGallery(tester, size: const Size(1000, 900));

      expect(find.text('All'), findsOneWidget);
      for (final g in ['Accounting', 'Finance', 'Integrations', 'Operations']) {
        expect(find.text(g), findsOneWidget, reason: g);
      }
    });

    testWidgets('tapping one narrows the grid to that group', (tester) async {
      await _pumpGallery(tester);

      await _tapPill(tester, 'Integrations');

      expect(find.text('WhatsApp integration'), findsOneWidget);
      expect(find.text('ZATCA e-invoicing'), findsNothing);
      expect(find.text('Bank reconciliation'), findsNothing);
    });

    testWidgets('and tapping All restores the full catalogue', (tester) async {
      await _pumpGallery(tester);

      await _tapPill(tester, 'Integrations');
      await _tapPill(tester, 'All');

      expect(find.text('ZATCA e-invoicing'), findsOneWidget);
      expect(find.text('Bank reconciliation'), findsOneWidget);
    });

    testWidgets('the Arabic filter works on the Arabic label', (tester) async {
      await _pumpGallery(tester, locale: const Locale('ar'));

      await _tapPill(tester, 'التكاملات');

      expect(find.text('تكامل واتساب'), findsOneWidget);
      expect(find.text('الفوترة الإلكترونية (زاتكا)'), findsNothing);
    });

    testWidgets('the chip row is hidden when there is nothing to filter',
        (tester) async {
      // One group across the whole catalogue: a row offering only "All" is a
      // control that cannot do anything.
      await _pumpGallery(
        tester,
        api: _FakeAppsApi(apps: [_live[2], _live[3]]), // both Accounting
      );

      expect(find.text('All'), findsNothing);
      expect(find.text('Bank reconciliation'), findsOneWidget);
    });
  });

  group('a package this build has never seen', () {
    testWidgets('renders the server strings rather than a blank card',
        (tester) async {
      final unknown = SaqqarApp.fromJson(const {
        'slug': 'warehouse-slotting',
        'name': 'Warehouse slotting advisor',
        'tagline': 'Suggest bin locations from movement history.',
        'category': 'Inventory · Optimization',
        'group': 'Inventory',
        'accent': 'not-a-colour',
        'icon_svg': '',
        'env_required': false,
      });

      await _pumpGallery(
        tester,
        locale: const Locale('ar'),
        api: _FakeAppsApi(apps: [..._live, unknown]),
      );

      expect(find.text('Warehouse slotting advisor'), findsOneWidget);
      expect(
        find.text('المخزون'),
        findsWidgets,
        reason: 'its GROUP is still translated even though its copy is not — '
            'the taxonomy is a closed set the client owns',
      );
      expect(find.textContaining('app_name_'), findsNothing);
    });

    testWidgets('a malformed accent falls back instead of throwing',
        (tester) async {
      await _pumpGallery(
        tester,
        api: _FakeAppsApi(apps: [
          SaqqarApp.fromJson(const {
            'slug': 'x',
            'name': 'Broken accent',
            'tagline': 't',
            'category': 'c',
            'group': 'Finance',
            'accent': '##zzz',
            'icon_svg': '',
            'env_required': false,
          }),
        ]),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('Broken accent'), findsOneWidget);
    });
  });

  group('states other than a full grid', () {
    testWidgets('an empty catalogue shows the empty state, still refreshable',
        (tester) async {
      await _pumpGallery(
        tester,
        locale: const Locale('ar'),
        api: _FakeAppsApi(apps: const []),
      );

      expect(find.text('لا توجد تطبيقات بعد'), findsOneWidget);
      expect(
        find.byType(Scrollable),
        findsWidgets,
        reason: 'pull-to-refresh has to survive the empty state',
      );
    });

    testWidgets('the catalogue is fetched exactly once on open',
        (tester) async {
      final api = _FakeAppsApi();
      await _pumpGallery(tester, api: api);

      expect(api.listCalls, 1);
    });

    testWidgets('a failed load shows a retry, in Arabic, not a blank grid',
        (tester) async {
      // The failure branch is the one a user on a bad connection actually
      // sees, and it is rendered by shared machinery the Apps screen passes
      // no copy to — so it is exactly the branch that can be English while
      // every card above it is Arabic.
      await _pumpGallery(
        tester,
        locale: const Locale('ar'),
        api: _FakeAppsApi(apps: const [], error: Exception('offline')),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('ZATCA e-invoicing'), findsNothing);

      final latin = RegExp(r'[A-Za-z]{2,}\s+[A-Za-z]{2,}');
      expect(
        [for (final t in _visibleText(tester)) if (latin.hasMatch(t)) t],
        isEmpty,
        reason: 'the error branch has to speak the UI language too',
      );
    });
  });

  group('accessibility and layout', () {
    testWidgets('tiles survive a 1.6x text scale without overflowing',
        (tester) async {
      // The grid cell's height comes from its width via the aspect ratio, so
      // it is fixed against text scale while the copy inside it is not.
      tester.view
        ..physicalSize = const Size(320, 640)
        ..devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(_harness(
        MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(1.6)),
          child: BlocProvider(
            create: (_) => AppsCubit(_FakeAppsApi()),
            child: const AppsScreen(),
          ),
        ),
        locale: const Locale('ar'),
      ));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  });
}
