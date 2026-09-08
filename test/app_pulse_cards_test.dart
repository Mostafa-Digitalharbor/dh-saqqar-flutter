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
import 'package:saqqar_app/features/chat/data/pulse_actions.dart';
import 'package:saqqar_app/features/chat/widgets/app_pulse/pulse_action_list.dart';
import 'package:saqqar_app/features/chat/widgets/app_pulse/accountant_pulse_card.dart';
import 'package:saqqar_app/features/chat/widgets/app_pulse/factory_pulse_card.dart';
import 'package:saqqar_app/features/chat/widgets/app_pulse/finance_pulse_card.dart';
import 'package:saqqar_app/features/chat/widgets/app_pulse/hr_pulse_card.dart';
import 'package:saqqar_app/features/chat/widgets/app_pulse/inventory_pulse_card.dart';
import 'package:saqqar_app/features/chat/widgets/app_pulse/pulse_bands_list.dart';
import 'package:saqqar_app/features/chat/widgets/app_pulse/pulse_card_shell.dart';
import 'package:saqqar_app/features/chat/widgets/app_pulse/pulse_counter_list.dart';
import 'package:saqqar_app/features/chat/widgets/app_pulse/pulse_raw_items.dart';
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
          stats: [],
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
          stats: [
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
          stats: [],
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
          stats: [],
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
          stats: [],
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
    testWidgets('renders bucket counts and names the delayed vendors',
        (tester) async {
      final payload = PurchasingPulsePayload.parse(const {
        'kind': 'purchasing',
        'open_rfqs': {'count': 4, 'items': <Object?>[], 'available': true},
        'vendor_delay_summary': [
          {'vendor': 'Acme', 'avg_delay_days': 6},
        ],
      })!;
      await _pump(tester, PurchasingPulseCard(payload: payload));

      expect(find.text('4'), findsOneWidget);
      // The vendor is named, not just counted — the count alone can't start
      // a phone call.
      expect(find.text(en.pulsePurchasingVendorDelays), findsOneWidget);
      expect(find.text('Acme'), findsOneWidget);
      expect(find.textContaining('avg_delay_days: 6'), findsOneWidget);
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

    testWidgets('a counter with a trail hides it until it is asked for',
        (tester) async {
      await _pump(
        tester,
        PulseCounterList(
          counters: const [
            PulseCounter(key: 'no_reference', label: 'قيود بدون مرجع', value: 2),
          ],
          detailsFor: (key) => const [
            {'move': 'INV/2026/0031', 'amount': 1250.0},
          ],
        ),
      );

      expect(find.text('INV/2026/0031'), findsNothing);
      await tester.tap(find.text(en.showDetails));
      await tester.pumpAndSettle();
      expect(find.text('INV/2026/0031'), findsOneWidget);
      expect(find.textContaining('amount: 1.3K'), findsOneWidget);
    });
  });

  // ── What the doc's undocumented arrays actually render ─────────────────

  group('PulseRawItemsList', () {
    testWidgets('names each row and shows its numbers first', (tester) async {
      await _pump(
        tester,
        const PulseRawItemsList(
          title: 'Low stock',
          items: [
            {
              'product': 'Steel bracket 40mm',
              'qty_on_hand': 0,
              'state': 'confirmed',
            },
          ],
        ),
      );

      expect(find.text('Low stock'), findsOneWidget);
      expect(find.text('Steel bracket 40mm'), findsOneWidget);
      // Numbers lead; the row's own name is never repeated as a fact.
      expect(find.textContaining('qty_on_hand: 0'), findsOneWidget);
      expect(find.textContaining('product:'), findsNothing);
    });

    testWidgets('a row with no name, and a row that is not a map, both print',
        (tester) async {
      await _pump(
        tester,
        const PulseRawItemsList(
          title: 'Anything',
          items: [
            {'qty': 4},
            'a bare string row',
            42,
          ],
        ),
      );

      expect(find.text('a bare string row'), findsOneWidget);
      expect(find.text('42'), findsOneWidget);
      // A row that names nothing is led by its first fact — never by Dart's
      // own `{qty: 4}` map syntax, which is not something to show a user.
      expect(find.text('qty: 4'), findsOneWidget);
      expect(find.textContaining('{'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('an Odoo many2one [id, name] pair reads as the name',
        (tester) async {
      await _pump(
        tester,
        const PulseRawItemsList(
          title: 'Vendors',
          items: [
            {
              'partner': <Object?>[7, 'Acme Supplies'],
              'avg_delay_days': 9,
            },
          ],
        ),
      );
      expect(find.text('Acme Supplies'), findsOneWidget);
    });

    testWidgets('no items renders nothing at all — not an empty heading',
        (tester) async {
      await _pump(
        tester,
        const PulseRawItemsList(title: 'Low stock', items: []),
      );
      expect(find.text('Low stock'), findsNothing);
    });
  });

  group('PulseBandsList', () {
    testWidgets('renders each band with its amount and invoice count',
        (tester) async {
      await _pump(
        tester,
        const PulseBandsList(
          title: 'Collection aging',
          bands: PulseBands(
            available: true,
            bands: [
              PulseBand(label: '0–30', amount: 84000, count: 12),
              PulseBand(label: '90+', amount: 3100),
            ],
          ),
        ),
      );

      expect(find.text('Collection aging'), findsOneWidget);
      expect(find.text('0–30'), findsOneWidget);
      expect(find.text('84K'), findsOneWidget);
      expect(find.text(en.pulseBandInvoices(12)), findsOneWidget);
      expect(find.text('3.1K'), findsOneWidget);
    });

    testWidgets('a named band is translated; a numeric one is left alone',
        (tester) async {
      await _pump(
        tester,
        const PulseBandsList(
          title: 'أعمار الديون',
          bands: PulseBands(
            available: true,
            bands: [
              PulseBand(label: 'not due', amount: 0),
              PulseBand(label: 'due today', amount: 0),
              PulseBand(label: '0–30', amount: 0),
              // A band nobody has seen before keeps the server's word.
              PulseBand(label: 'some new band', amount: 0),
            ],
          ),
        ),
        locale: const Locale('ar'),
      );

      expect(find.text('غير مستحقة'), findsOneWidget);
      expect(find.text('مستحقة اليوم'), findsOneWidget);
      expect(find.text('0–30'), findsOneWidget);
      expect(find.text('some new band'), findsOneWidget);
      expect(find.text('not due'), findsNothing);
    });

    testWidgets('unavailable says so — rule 1, never an empty row of zeroes',
        (tester) async {
      await _pump(
        tester,
        const PulseBandsList(
          title: 'Collection aging',
          bands: PulseBands(available: false),
        ),
      );

      expect(find.text(en.pulseUnavailable), findsOneWidget);
      expect(find.text('0'), findsNothing);
    });

    testWidgets('available with nothing in it renders nothing', (tester) async {
      await _pump(
        tester,
        const PulseBandsList(
          title: 'Collection aging',
          bands: PulseBands(available: true),
        ),
      );
      expect(find.text('Collection aging'), findsNothing);
    });
  });

  // ── The buttons the phone was missing ─────────────────────────────────

  group('action rows', () {
    const financePayload = {
      'kind': 'finance',
      'receivables': {
        'overdue': {'available': true, 'count': 13, 'total': 303194.0},
      },
      'bank_reconciliation': {'available': true, 'count': 21},
    };

    testWidgets('a card with a composer behind it shows the web\'s buttons',
        (tester) async {
      final sent = <String>[];
      final actions =
          pulseActions(InteractiveCardKind.finance, financePayload, en);
      await _pump(
        tester,
        FinancePulseCard(
          payload: FinancePulsePayload.parse(financePayload)!,
          actions: actions,
          onSend: sent.add,
        ),
      );

      expect(find.text('Start collection'), findsOneWidget);
      expect(find.text('Reconcile bank'), findsOneWidget);

      await tester.tap(find.text('Start collection'));
      await tester.pumpAndSettle();

      expect(sent.single, actions.first.prompt);
      expect(sent.single, contains('receivables aging'));
    });

    testWidgets('a read-only surface shows the card without dead buttons',
        (tester) async {
      await _pump(
        tester,
        FinancePulseCard(
          payload: FinancePulsePayload.parse(financePayload)!,
          actions: pulseActions(InteractiveCardKind.finance, financePayload, en),
          // No composer here — the shared transcript view.
        ),
      );

      expect(find.text('Start collection'), findsNothing);
      // The numbers are still worth reading.
      expect(find.text('13'), findsOneWidget);
    });

    testWidgets('the rows read right in Arabic', (tester) async {
      final sent = <String>[];
      await _pump(
        tester,
        FinancePulseCard(
          payload: FinancePulsePayload.parse(financePayload)!,
          actions: pulseActions(InteractiveCardKind.finance, financePayload, ar),
          onSend: sent.add,
        ),
        locale: const Locale('ar'),
      );

      expect(find.text('ابدأ التحصيل'), findsOneWidget);
      await tester.tap(find.text('ابدأ التحصيل'));
      await tester.pumpAndSettle();
      expect(sent.single, startsWith('اعرض أعمار مديونيات العملاء'));
    });

    testWidgets('the accountant card carries its chips and its free-text ask',
        (tester) async {
      const payload = {
        'kind': 'accountant',
        'counters': [
          {'key': 'journal', 'label': 'Entries to review', 'value': 4},
        ],
      };
      final sent = <String>[];
      await _pump(
        tester,
        AccountantPulseCard(
          payload: AccountantPulsePayload.parse(payload)!,
          actions: pulseActions(InteractiveCardKind.accountant, payload, en),
          deepActions:
              pulseDeepActions(InteractiveCardKind.accountant, payload, en),
          onSend: sent.add,
        ),
      );

      expect(find.text('Review entries'), findsOneWidget);
      expect(find.text('The opinion'), findsOneWidget);

      // The free-text row: an empty box sends nothing, a filled one sends
      // the document number inside the prompt.
      await tester.tap(find.text('Explain'));
      await tester.pumpAndSettle();
      expect(sent, isEmpty);

      await tester.enterText(find.byType(TextField), 'INV/2026/0031');
      await tester.tap(find.text('Explain'));
      await tester.pumpAndSettle();
      expect(sent.single, contains('INV/2026/0031'));
      expect(sent.single, contains('walk the chain'));
    });

    testWidgets('a payload with nothing to act on shows no button row',
        (tester) async {
      const quiet = {'kind': 'finance'};
      await _pump(
        tester,
        FinancePulseCard(
          payload: FinancePulsePayload.parse(quiet)!,
          actions: pulseActions(InteractiveCardKind.finance, quiet, en),
          onSend: (_) {},
        ),
      );
      expect(find.byType(PulseActionList), findsOneWidget);
      expect(find.text('Start collection'), findsNothing);
    });
  });

  group('the sections that used to be dropped', () {
    testWidgets('inventory names the products behind a bucket count',
        (tester) async {
      final payload = InventoryPulsePayload.parse(const {
        'kind': 'inventory',
        'demand_shortage': {
          'available': true,
          'count': 2,
          'items': [
            {'product': 'Steel bracket 40mm', 'qty_needed': 1450},
            {'product': 'Copper wire 2.5mm', 'qty_needed': 300},
          ],
        },
      })!;
      await _pump(tester, InventoryPulseCard(payload: payload));

      expect(find.text('Steel bracket 40mm'), findsOneWidget);
      expect(find.text('Copper wire 2.5mm'), findsOneWidget);
      // Compacted the way the rest of the app writes four-digit numbers.
      expect(find.textContaining('qty_needed: 1.4K'), findsOneWidget);
    });

    testWidgets('inventory says WHY data is missing, not just how much',
        (tester) async {
      final payload = InventoryPulsePayload.parse(const {
        'kind': 'inventory',
        'missing_data': {
          'available': true,
          'count': 22,
          'counts': {'no_cost': 8, 'no_lead_time': 14},
        },
      })!;
      await _pump(tester, InventoryPulseCard(payload: payload));

      expect(find.text(en.pulseInventoryMissingDataReasons), findsOneWidget);
      expect(find.text('no cost'), findsOneWidget);
      expect(find.text('14'), findsOneWidget);
    });

    testWidgets('finance renders both aging breakdowns', (tester) async {
      // Every other bucket is answerable, so the only "Unavailable" on this
      // card is the horizon's — which is the point of the assertion.
      final payload = FinancePulsePayload.parse(const {
        'kind': 'finance',
        'cash': {'available': true, 'balance': 12500.0},
        'receivables': {
          'overdue': {'available': true, 'count': 3},
          'due_soon': {'available': true, 'count': 1},
        },
        'payables': {
          'overdue': {'available': true, 'count': 2},
          'due_soon': {'available': true, 'count': 4},
        },
        'drafts': {
          'vendor_bills': {'available': true, 'count': 5},
          'customer_invoices': {'available': true, 'count': 6},
        },
        'bank_reconciliation': {'available': true, 'count': 7},
        'collection_aging': {
          'available': true,
          'd0_30': 84000.0,
          'over_90': 3100.0,
        },
        'payment_horizon': {'available': false},
      })!;
      await _pump(tester, FinancePulseCard(payload: payload));

      expect(find.text(en.pulseFinanceCollectionAging), findsOneWidget);
      expect(find.text('0–30'), findsOneWidget);
      expect(find.text('84K'), findsOneWidget);
      expect(find.text('90+'), findsOneWidget);
      expect(find.text(en.pulseFinancePaymentHorizon), findsOneWidget);
      expect(find.text(en.pulseUnavailable), findsOneWidget);
    });

    testWidgets('the accountant tiles the five checks and names them',
        (tester) async {
      final payload = AccountantPulsePayload.parse(const {
        'kind': 'accountant',
        'no_reference': {'available': true, 'count': 4},
        'manual_on_control': 7,
        'edited_after_post': {'available': false},
      })!;
      await _pump(tester, AccountantPulseCard(payload: payload));

      expect(find.text(en.pulseAccountantCheck('no_reference')), findsOneWidget);
      expect(find.text('4'), findsOneWidget);
      expect(find.text('7'), findsOneWidget);
      // The check the database can't answer says so instead of showing 0.
      expect(find.text(en.pulseUnavailable), findsOneWidget);
      expect(find.text('0'), findsNothing);
    });

    testWidgets('HR states an unavailable operations section, never hides it',
        (tester) async {
      final payload = HrPulsePayload.parse(const {
        'kind': 'hr',
        'operations': {'available': false},
        'recruitment': {
          'available': true,
          'count': 6,
          'items': [
            {'name': 'Sara Ali', 'stage': 'interview'},
          ],
        },
        'payroll': {'available': false},
      })!;
      await _pump(tester, HrPulseCard(payload: payload));

      // Operations and payroll both unavailable — two statements, not two
      // blanks.
      expect(find.text(en.pulseUnavailable), findsNWidgets(2));
      expect(find.text(en.pulseHrRecruitment), findsWidgets);
      expect(find.text('6'), findsOneWidget);
      expect(find.text('Sara Ali'), findsOneWidget);
      // `time_off` was never sent, so it gets no tile at all.
      expect(find.text(en.pulseHrTimeOff), findsNothing);
    });

    testWidgets('quality guard reads the doc\'s flat keys and the live shape '
        'identically', (tester) async {
      const flat = {
        'kind': 'quality_guard',
        'deep_discounts': 5,
        'lower_cost_substitutes': 2,
        'documented_substitutes': 1,
        'undocumented_substitutes': 4,
        'discount_value_estimate': 18400.0,
        'standard_odoo_only': true,
      };
      const nested = {
        'kind': 'quality_guard',
        'spec_stats': {
          'deep_discounts': 5,
          'lower_cost_substitutes': 2,
          'documented_substitutes': 1,
          'undocumented_substitutes': 4,
          'discount_value_estimate': 18400.0,
        },
        'standard_odoo_only': true,
      };

      for (final payload in [flat, nested]) {
        await _pump(
          tester,
          QualityGuardPulseCard(
            payload: QualityGuardPulsePayload.parse(payload)!,
          ),
        );

        expect(find.text(en.pulseQualityDeepDiscounts), findsOneWidget);
        expect(find.text('5'), findsOneWidget);
        expect(find.text(en.pulseQualityUndocumentedSubstitutes),
            findsOneWidget);
        expect(find.text('4'), findsOneWidget);
        expect(find.text('18.4K'), findsOneWidget);
        expect(find.text(en.pulseQualityStandardOdooOnly), findsOneWidget);
      }
    });

    testWidgets('every new section renders in Arabic without throwing',
        (tester) async {
      final finance = FinancePulsePayload.parse(const {
        'kind': 'finance',
        'collection_aging': {'available': true, 'd0_30': 84000.0},
        'payment_horizon': {'available': false},
      })!;
      await _pump(tester, FinancePulseCard(payload: finance),
          locale: const Locale('ar'));
      expect(find.text(ar.pulseFinanceCollectionAging), findsOneWidget);
      expect(find.text(ar.pulseFinancePaymentHorizon), findsOneWidget);
      // Bands are digits, so they read the same in both locales; the
      // heading and the unavailable state are what localize.
      expect(find.text('0–30'), findsOneWidget);
      expect(find.text(ar.pulseUnavailable), findsWidgets);

      final hr = HrPulsePayload.parse(const {
        'kind': 'hr',
        'operations': {'available': false},
        'time_off': {'available': true, 'count': 3},
      })!;
      await _pump(tester, HrPulseCard(payload: hr), locale: const Locale('ar'));
      expect(find.text(ar.pulseHrTimeOff), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
