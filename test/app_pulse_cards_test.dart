// Task 1 (MOBILE_TASKS_2026-09.md) — rendering the app-pulse cards.
//
// `app_pulse_payloads_test.dart` pins the parsers; this pins what actually
// reaches the screen: the four server-behaviour rules the doc calls out
// (available:false vs. null vs. status:error vs. verbatim Arabic notes), in
// both locales, and that the widgets survive a payload with nothing usable
// in it at all.

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saqqar_app/core/i18n/app_localizations.dart';
import 'package:saqqar_app/core/i18n/app_strings.dart';
import 'package:saqqar_app/core/theme/app_theme.dart';
import 'package:saqqar_app/features/chat/data/app_pulse_payloads.dart';
import 'package:saqqar_app/features/chat/data/interactive_card_kind.dart';
import 'package:saqqar_app/features/chat/widgets/app_pulse/accountant_pulse_card.dart';
import 'package:saqqar_app/features/chat/widgets/app_pulse/factory_pulse_card.dart';
import 'package:saqqar_app/features/chat/widgets/app_pulse/finance_pulse_card.dart';
import 'package:saqqar_app/features/chat/widgets/app_pulse/hr_pulse_card.dart';
import 'package:saqqar_app/features/chat/widgets/app_pulse/inventory_pulse_card.dart';
import 'package:saqqar_app/features/chat/widgets/app_pulse/pulse_card_shell.dart';
import 'package:saqqar_app/features/chat/widgets/app_pulse/pulse_counter_list.dart';
import 'package:saqqar_app/features/chat/widgets/app_pulse/purchasing_pulse_card.dart';
import 'package:saqqar_app/features/chat/widgets/app_pulse/quality_guard_pulse_card.dart';

Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  Locale locale = const Locale('en'),
}) async {
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
      home: Scaffold(body: SingleChildScrollView(child: child)),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  final en = AppStrings(const Locale('en'));
  final ar = AppStrings(const Locale('ar'));

  group('PulseCardShell', () {
    testWidgets('shows the app title and the as-of date', (tester) async {
      await _pump(
        tester,
        const PulseCardShell(
          kind: InteractiveCardKind.factory,
          envelope: PulseEnvelope(status: PulseStatus.ok, asOf: '2026-09-05'),
          children: [],
        ),
      );
      expect(find.text(en.lookup('app_name_factory')), findsOneWidget);
      expect(find.textContaining('2026'), findsOneWidget);
    });

    testWidgets('status: error renders the message, not the children — '
        'rule 3', (tester) async {
      var builtChild = false;
      await _pump(
        tester,
        PulseCardShell(
          kind: InteractiveCardKind.factory,
          envelope: const PulseEnvelope(
            status: PulseStatus.error,
            error: 'تعذّر الاتصال بقاعدة بيانات أودو.',
          ),
          children: [
            Builder(builder: (context) {
              builtChild = true;
              return const SizedBox();
            }),
          ],
        ),
      );
      expect(find.text('تعذّر الاتصال بقاعدة بيانات أودو.'), findsOneWidget);
      expect(
        builtChild,
        isFalse,
        reason: 'an error payload must not also try to render tiles built '
            'from data it does not have',
      );
    });

    testWidgets('an empty error string falls back to the generic copy',
        (tester) async {
      await _pump(
        tester,
        const PulseCardShell(
          kind: InteractiveCardKind.factory,
          envelope: PulseEnvelope(status: PulseStatus.error),
          children: [],
        ),
      );
      expect(find.text(en.defaultApiError), findsOneWidget);
    });

    testWidgets('notes render verbatim — never through context.tr — rule 4',
        (tester) async {
      const note = 'بعض بيانات المصنع غير متاحة لأن التطبيق غير مثبت.';
      await _pump(
        tester,
        const PulseCardShell(
          kind: InteractiveCardKind.factory,
          envelope: PulseEnvelope(status: PulseStatus.ok, notes: [note]),
          children: [],
        ),
        // English screen locale — the note must still show up in Arabic,
        // unchanged, because rule 4 says the server writes it in Arabic
        // regardless of the app's own locale.
      );
      expect(find.text(note), findsOneWidget);
      expect(find.text(en.pulseNotesTitle), findsOneWidget);
    });

    testWidgets('priorities render under their own heading, separate from '
        'notes', (tester) async {
      await _pump(
        tester,
        const PulseCardShell(
          kind: InteractiveCardKind.inventory,
          envelope: PulseEnvelope(status: PulseStatus.ok, notes: ['note A']),
          priorities: ['priority A'],
          children: [],
        ),
      );
      expect(find.text(en.pulseNotesTitle), findsOneWidget);
      expect(find.text(en.pulsePrioritiesTitle), findsOneWidget);
      expect(find.text('note A'), findsOneWidget);
      expect(find.text('priority A'), findsOneWidget);
    });
  });

  group('FactoryPulseCard', () {
    const fullPayload = {
      'kind': 'factory',
      'status': 'ok',
      'as_of': '2026-09-05',
      'mo_running': 12,
      'mo_late': 3,
      'mo_done_today': 5,
      'po_late': 2,
      'orders_at_risk': 4,
      'top_risks': [
        {
          'order': 'SO/0042',
          'customer': 'Al Rajhi Trading',
          'missing_lines': 3,
          'lead_days': 21,
          'worst_product': 'Steel bracket 40mm',
        },
      ],
    };

    testWidgets('renders every tile value and the risk row', (tester) async {
      final payload = FactoryPulsePayload.parse(fullPayload)!;
      await _pump(tester, FactoryPulseCard(payload: payload));

      expect(find.text('12'), findsOneWidget);
      expect(find.text('3'), findsWidgets); // mo_late AND missing_lines
      expect(find.text('5'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      expect(find.text('4'), findsOneWidget);
      expect(find.textContaining('SO/0042'), findsOneWidget);
      expect(find.text('Steel bracket 40mm'), findsOneWidget);
      expect(find.text(en.pulseTopRisksTitle), findsOneWidget);
    });

    testWidgets('null scalars (app not installed) show — not 0 — rule 2',
        (tester) async {
      final payload = FactoryPulsePayload.parse(const {
        'kind': 'factory',
        'orders_at_risk': 4,
      })!;
      await _pump(tester, FactoryPulseCard(payload: payload));

      expect(
        find.text('0'),
        findsNothing,
        reason: 'a null scalar must never render as a manufactured zero',
      );
      expect(find.text('—'), findsWidgets);
      expect(find.text('4'), findsOneWidget);
    });

    testWidgets('renders in Arabic with no crash and the Arabic title',
        (tester) async {
      final payload = FactoryPulsePayload.parse(fullPayload)!;
      await _pump(
        tester,
        FactoryPulseCard(payload: payload),
        locale: const Locale('ar'),
      );
      expect(find.text(ar.lookup('app_name_factory')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a payload with nothing usable still renders something '
        'sensible, never throws', (tester) async {
      final payload = FactoryPulsePayload.parse(const {'kind': 'factory'})!;
      await _pump(tester, FactoryPulseCard(payload: payload));
      expect(tester.takeException(), isNull);
      expect(find.text(en.lookup('app_name_factory')), findsOneWidget);
    });
  });

  group('InventoryPulseCard', () {
    testWidgets('available: false renders the localized Unavailable label — '
        'rule 1', (tester) async {
      final payload = InventoryPulsePayload.parse(const {
        'kind': 'inventory',
        // Every other bucket explicit and available, so the one "false"
        // is the only source of the unavailable label — a bucket the
        // payload never mentions defaults to unavailable too (asserted
        // separately below), which would otherwise make this assertion
        // pass for the wrong reason.
        'inventory_value': {'available': true, 'total': 1.0},
        'low_stock': {'available': false},
        'demand_shortage': {'available': true, 'count': 0},
        'stagnant_stock': {'available': true, 'count': 2},
        'overstock': {'available': true, 'count': 3},
        'fast_reorder': {'available': true, 'count': 4},
        'missing_data': {'available': true, 'count': 5},
      })!;
      await _pump(tester, InventoryPulseCard(payload: payload));

      expect(find.text(en.pulseUnavailable), findsOneWidget);
      expect(
        find.text('0'),
        findsOneWidget,
        reason: 'a genuinely available bucket with count 0 must still say '
            'so, not be swallowed by the unavailable branch',
      );
    });

    testWidgets('a compacted total renders for the value bucket',
        (tester) async {
      final payload = InventoryPulsePayload.parse(const {
        'kind': 'inventory',
        'inventory_value': {'available': true, 'total': 984000.0},
      })!;
      await _pump(tester, InventoryPulseCard(payload: payload));
      expect(find.textContaining('984'), findsOneWidget);
    });

    testWidgets('renders in Arabic with no crash', (tester) async {
      final payload = InventoryPulsePayload.parse(const {
        'kind': 'inventory',
        'sales_days': 90,
        'product_count': 1840,
      })!;
      await _pump(
        tester,
        InventoryPulseCard(payload: payload),
        locale: const Locale('ar'),
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('FinancePulseCard', () {
    testWidgets('renders cash, bucket and liquidity tiles', (tester) async {
      final payload = FinancePulsePayload.parse(const {
        'kind': 'finance',
        'status': 'ok',
        'cash': {'balance': 12500.0, 'journals': ['Bank'], 'available': true},
        'receivables': {
          'overdue': {'count': 3, 'items': <Object?>[], 'total': 4200.0, 'available': true},
        },
        'liquidity_7d': {'status': 'covered', 'available': true},
      })!;
      await _pump(tester, FinancePulseCard(payload: payload));

      expect(find.text('3'), findsOneWidget);
      expect(find.text('covered'), findsOneWidget);
      expect(find.text(en.pulseFinanceReceivablesOverdue), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('an unavailable cash bucket shows Unavailable, not zero',
        (tester) async {
      final payload = FinancePulsePayload.parse(const {
        'kind': 'finance',
        'cash': {'available': false},
      })!;
      await _pump(tester, FinancePulseCard(payload: payload));

      expect(find.text(en.pulseUnavailable), findsWidgets);
      expect(find.text('0'), findsNothing);
    });

    testWidgets('renders in Arabic with no crash', (tester) async {
      final payload = FinancePulsePayload.parse(const {'kind': 'finance'})!;
      await _pump(tester, FinancePulseCard(payload: payload),
          locale: const Locale('ar'));
      expect(tester.takeException(), isNull);
    });
  });

  group('PurchasingPulseCard', () {
    testWidgets('renders bucket counts and the vendor delay tile',
        (tester) async {
      final payload = PurchasingPulsePayload.parse(const {
        'kind': 'purchasing',
        'open_rfqs': {'count': 4, 'items': <Object?>[], 'available': true},
        'vendor_delay_summary': [
          {'vendor': 'Acme'},
        ],
      })!;
      await _pump(tester, PurchasingPulseCard(payload: payload));

      expect(find.text('4'), findsOneWidget);
      expect(find.text('1'), findsOneWidget);
      expect(find.text(en.pulsePurchasingVendorDelays), findsOneWidget);
    });

    testWidgets('a payload with nothing usable still renders, never throws',
        (tester) async {
      final payload =
          PurchasingPulsePayload.parse(const {'kind': 'purchasing'})!;
      await _pump(tester, PurchasingPulseCard(payload: payload));
      expect(tester.takeException(), isNull);
      expect(find.text(en.lookup('app_name_purchase_pulse')), findsOneWidget);
    });
  });

  group('HrPulseCard', () {
    testWidgets('renders operations tiles, counters and flagged employees',
        (tester) async {
      final payload = HrPulsePayload.parse(const {
        'kind': 'hr',
        'counters': [
          {'key': 'contracts', 'label': 'موظفون وعقود للمراجعة', 'value': 1, 'action': 'راجع العقود'},
        ],
        'operations': {
          'available': true,
          'active_employees': 9,
          'missing_managers': 9,
          'items': [
            {'employee': 'Ahmed Mohamed', 'reason': 'المدير غير محدد'},
          ],
        },
      })!;
      await _pump(tester, HrPulseCard(payload: payload));

      expect(find.text('9'), findsWidgets);
      expect(find.text('موظفون وعقود للمراجعة'), findsOneWidget);
      expect(find.text('راجع العقود'), findsOneWidget);
      expect(find.text('Ahmed Mohamed'), findsOneWidget);
      expect(find.text('المدير غير محدد'), findsOneWidget);
    });

    testWidgets('a payload with nothing usable still renders, never throws',
        (tester) async {
      final payload = HrPulsePayload.parse(const {'kind': 'hr'})!;
      await _pump(tester, HrPulseCard(payload: payload));
      expect(tester.takeException(), isNull);
    });
  });

  group('AccountantPulseCard', () {
    testWidgets('renders the month badge and counter rows', (tester) async {
      final payload = AccountantPulsePayload.parse(const {
        'kind': 'accountant',
        'month': '2026-08',
        'counters': [
          {'key': 'tax', 'label': 'ملاحظات ضريبية', 'value': 1, 'action': 'راجع الضريبة'},
        ],
      })!;
      await _pump(tester, AccountantPulseCard(payload: payload));

      expect(find.textContaining('2026-08'), findsOneWidget);
      expect(find.text('ملاحظات ضريبية'), findsOneWidget);
      expect(find.text('راجع الضريبة'), findsOneWidget);
    });

    testWidgets('no month, no counters — still renders, never throws',
        (tester) async {
      final payload =
          AccountantPulsePayload.parse(const {'kind': 'accountant'})!;
      await _pump(tester, AccountantPulseCard(payload: payload));
      expect(tester.takeException(), isNull);
    });
  });

  group('QualityGuardPulseCard', () {
    testWidgets('renders quality and spec-guard tiles', (tester) async {
      final payload = QualityGuardPulsePayload.parse(const {
        'kind': 'quality_guard',
        'priorities': ['راجع القياسات دوريًا.'],
        'quality_stats': {'out_of_spec': 2, 'failed_checks': 1},
        'spec_stats': {'review_cases': 1, 'cost_saving_total': 450.0},
      })!;
      await _pump(tester, QualityGuardPulseCard(payload: payload));

      expect(find.text('2'), findsOneWidget);
      expect(find.text('1'), findsWidgets); // failed_checks AND review_cases
      expect(find.text(en.pulsePrioritiesTitle), findsOneWidget);
      expect(find.text('راجع القياسات دوريًا.'), findsOneWidget);
    });

    testWidgets('null stats render as a dash, never a manufactured zero',
        (tester) async {
      final payload =
          QualityGuardPulsePayload.parse(const {'kind': 'quality_guard'})!;
      await _pump(tester, QualityGuardPulseCard(payload: payload));

      expect(find.text('0'), findsNothing);
      expect(find.text('—'), findsWidgets);
      expect(tester.takeException(), isNull);
    });
  });

  group('PulseCounterList', () {
    testWidgets('renders every counter label verbatim, with its value',
        (tester) async {
      await _pump(
        tester,
        const PulseCounterList(counters: [
          PulseCounter(key: 'a', label: 'قيود للمراجعة', value: 0, action: 'راجع القيود'),
          PulseCounter(key: 'b', label: 'ملاحظات ضريبية', value: 2, action: 'راجع الضريبة'),
        ]),
      );

      expect(find.text('قيود للمراجعة'), findsOneWidget);
      expect(find.text('ملاحظات ضريبية'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      // A zero-value counter has nothing to act on, so its action caption
      // stays hidden — only the flagged (value > 0) row shows one.
      expect(find.text('راجع القيود'), findsNothing);
      expect(find.text('راجع الضريبة'), findsOneWidget);
    });

    testWidgets('an empty list renders nothing, not an empty section',
        (tester) async {
      await _pump(tester, const PulseCounterList(counters: []));
      expect(tester.takeException(), isNull);
    });
  });
}
