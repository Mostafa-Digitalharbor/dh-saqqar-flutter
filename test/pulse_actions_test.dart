// The action rows an app-pulse card offers, and the prompt each button
// sends (`pulse_actions.dart`).
//
// The bug these pin: mobile rendered the seven cards as read-only numbers
// while the web rendered the same payload as rows ending in a button that
// hands the agent a prompt. "بص في زراير زي ابدا التحصيل صقار بياخد اكشن من
// الزوار ويبيتدي يشتغل" — the phone had the numbers and no way to act.
//
// The prompt is the contract with the agent, so these assert on the prompt
// text, not just on the button being there: a button that sends different
// words is a different feature.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saqqar_app/core/i18n/app_strings.dart';
import 'package:saqqar_app/features/chat/data/interactive_card_kind.dart';
import 'package:saqqar_app/features/chat/data/pulse_actions.dart';

void main() {
  final en = AppStrings(const Locale('en'));
  final ar = AppStrings(const Locale('ar'));

  group('finance', () {
    // The payload behind the card in the web screenshot: aging, horizon,
    // an unreconciled bank line and two drafts.
    const payload = {
      'kind': 'finance',
      'cash': {'available': true, 'balance': 14816.36},
      'receivables': {
        'overdue': {
          'available': true,
          'count': 13,
          'total': 303194.0,
          'items': [
            {
              'name': 'INV/2026/00002',
              'partner': 'Acme Corporation',
              'amount': 41750.0,
            },
          ],
        },
      },
      'payables': {
        'overdue': {'available': true, 'count': 6, 'total': 90.0},
        'due_soon': {'available': true, 'count': 0},
      },
      'drafts': {
        'customer_invoices': {'available': true, 'count': 1},
        'vendor_bills': {'available': true, 'count': 2},
      },
      'bank_reconciliation': {'available': true, 'count': 21, 'total': 898.35},
      'collection_aging': {
        'available': true,
        'total_overdue': 303194.0,
        'days_1_30': {'available': true, 'count': 5, 'total': 95250.0},
        'days_31_60': {'available': true, 'count': 4, 'total': 64810.25},
        'days_61_plus': {'available': true, 'count': 4, 'total': 143133.75},
      },
      'payment_horizon': {
        'available': true,
        'total_due_7d': 90.0,
        'total_due_30d': 90.0,
        'overdue': {'available': true, 'count': 6, 'total': 90.0},
        'due_today': {'available': true, 'count': 0, 'total': 0},
        'days_1_7': {'available': true, 'count': 0, 'total': 0},
      },
      'liquidity_7d': {
        'available': true,
        'cash_gap': 14726.36,
        'after_collection_gap': 14726.36,
      },
    };

    test('offers the same four actions the web offers, in order', () {
      final actions = pulseActions(InteractiveCardKind.finance, payload, en);

      expect(
        actions.map((a) => a.label),
        [
          'Start collection',
          'Plan payments',
          'Reconcile bank',
          'Review close',
        ],
      );
      // Only the first row gets the filled button.
      expect(actions.where((a) => a.primary), hasLength(1));
      expect(actions.first.primary, isTrue);
    });

    test('the collect button sends the web\'s own prompt', () {
      final actions = pulseActions(InteractiveCardKind.finance, payload, en);

      expect(
        actions.first.prompt,
        'Show customer receivables aging by 1-30, 31-60, and 60+, then start '
        'with the oldest or highest-value follow-up without executing it.',
      );
    });

    test('reads the aging bands into the row, formatted like the web', () {
      final actions = pulseActions(InteractiveCardKind.finance, payload, en);

      expect(
        actions.first.main,
        '13 invoice(s): 1-30 95,250 / 31-60 64,810.25 / 60+ 143,133.75',
      );
      expect(actions.first.cause,
          'Largest: INV/2026/00002 / Acme Corporation / 41,750');
    });

    test('Arabic sends the Arabic prompt, not a translated English one', () {
      final actions = pulseActions(InteractiveCardKind.finance, payload, ar);

      expect(actions.first.label, 'ابدأ التحصيل');
      expect(
        actions.first.prompt,
        'اعرض أعمار مديونيات العملاء 1-30 و31-60 و+60، وابدأ بالأقدم أو الأعلى '
        'قيمة واقترح متابعة بدون تنفيذ.',
      );
    });

    test('a liquidity gap leads the card when the cash is short', () {
      final actions = pulseActions(InteractiveCardKind.finance, {
        ...payload,
        'liquidity_7d': {
          'available': true,
          'cash_gap': -4200.0,
          'after_collection_gap': -1200.0,
        },
      }, en);

      expect(actions.first.label, 'Cover gap');
      expect(actions.first.main, 'Short before collection by 4,200');
      expect(actions.first.cause, 'After near collections: -1,200');
      expect(actions.first.primary, isTrue);
    });

    test('a quiet payload offers nothing rather than empty buttons', () {
      expect(
        pulseActions(InteractiveCardKind.finance, const {'kind': 'finance'}, en),
        isEmpty,
      );
    });
  });

  group('factory', () {
    test('every at-risk order gets both of the web\'s buttons', () {
      final actions = pulseActions(
        InteractiveCardKind.factory,
        const {
          'kind': 'factory',
          'top_risks': [
            {
              'order': 'SO/0042',
              'customer': 'Acme',
              'lead_days': 21,
              'worst_product': 'Steel bracket',
            },
          ],
        },
        en,
      );

      // ONE row, TWO buttons — the web's `.fc-risk` shape. Emitting two rows
      // printed the order, the customer and the cause twice each.
      expect(actions, hasLength(1));
      expect(
        actions.single.buttons.map((b) => b.label),
        ['Delivery date', 'Cover shortage'],
      );
      // The order number is interpolated into both prompts — a button that
      // asked about "the order" without naming it would start the agent on
      // the wrong one.
      for (final button in actions.single.buttons) {
        expect(button.prompt, contains('SO/0042'));
      }
      // Cover shortage is the filled one, as on the web.
      expect(actions.single.buttons.map((b) => b.primary), [false, true]);
      expect(actions.first.cause, '21 days waiting on "Steel bracket"');
    });

    test('two at-risk orders are two rows, not four', () {
      final actions = pulseActions(
        InteractiveCardKind.factory,
        const {
          'kind': 'factory',
          'top_risks': [
            {'order': 'SO/0042', 'customer': 'Acme', 'lead_days': 21},
            {'order': 'SO/0043', 'customer': 'Globex', 'lead_days': 3},
          ],
        },
        en,
      );

      expect(actions.map((a) => a.title), ['SO/0042', 'SO/0043']);
      expect(actions.map((a) => a.main), ['Acme', 'Globex']);
    });

    test('a risk row with no order number is skipped', () {
      final actions = pulseActions(
        InteractiveCardKind.factory,
        const {
          'kind': 'factory',
          'top_risks': [
            {'customer': 'Acme'},
          ],
        },
        en,
      );
      expect(actions, isEmpty);
    });
  });

  group('purchasing / inventory / quality', () {
    test('purchasing names the blocking supplier on the first row', () {
      final actions = pulseActions(
        InteractiveCardKind.purchasing,
        const {
          'kind': 'purchasing',
          'late_incoming_receipts': {
            'available': true,
            'count': 2,
            'items': [
              {'name': 'WH/IN/0007', 'vendor': 'Acme Supplies'},
            ],
          },
          'late_purchase_orders': {'available': true, 'count': 1},
        },
        en,
      );

      expect(actions.first.label, 'Chase supplier');
      expect(actions.first.main, '2 receipt(s), 1 PO(s) late');
      expect(actions.first.cause, 'First follow-up: WH/IN/0007 / Acme Supplies');
      expect(actions.first.primary, isTrue);
    });

    test('inventory reads the product line the way the web reads it', () {
      final actions = pulseActions(
        InteractiveCardKind.inventory,
        const {
          'kind': 'inventory',
          'demand_shortage': {
            'available': true,
            'count': 4,
            'items': [
              {
                'name': 'Steel bracket 40mm',
                'code': 'SB-40',
                'qty_available': 0,
                'virtual_available': 12,
              },
            ],
          },
        },
        en,
      );

      expect(actions.single.label, 'Review shortage');
      expect(actions.single.cause,
          '[SB-40] Steel bracket 40mm / on hand 0 / forecast 12');
    });

    test('quality guard leads with the measurement gate', () {
      final actions = pulseActions(
        InteractiveCardKind.qualityGuard,
        const {
          'kind': 'quality_guard',
          'out_of_spec': 2,
          'failed_checks': 1,
          'quality_alerts': 3,
        },
        en,
      );

      expect(actions.first.label, 'Review measurements');
      expect(actions.first.main, '2 out-of-spec measurement(s)');
      expect(actions[1].label, 'Open rejects');
      expect(actions[1].main, '1 failed, 0 pending, 3 alert(s)');
    });
  });

  group('accountant and hr counters', () {
    const accountant = {
      'kind': 'accountant',
      'counters': [
        {'key': 'journal', 'label': 'Entries to review', 'value': 4},
        {'key': 'bank', 'label': 'Bank items pending', 'value': 21},
        // A key this client has never seen: no button rather than a guess.
        {'key': 'brand_new_check', 'label': 'Something new', 'value': 2},
      ],
    };

    test('one action per known counter, none for an unknown one', () {
      final actions =
          pulseActions(InteractiveCardKind.accountant, accountant, en);

      expect(actions.map((a) => a.label), ['Review entries', 'Reconcile bank']);
      expect(actions.first.title, 'Entries to review');
      expect(actions.first.main, '4');
      expect(
        actions.last.prompt,
        'Run the bank-matching review from Odoo and show the unmatched lines '
        'and payments.',
      );
    });

    test('Arabic prefers the server\'s own wording for the button', () {
      final actions = pulseActions(
        InteractiveCardKind.accountant,
        const {
          'kind': 'accountant',
          'counters': [
            {
              'key': 'journal',
              'label': 'قيود للمراجعة',
              'value': 4,
              'action': 'افحص القيود',
            },
          ],
        },
        ar,
      );

      // The server writes `action` in the conversation's language, so it is
      // the better label — the table is the fallback, not the override.
      expect(actions.single.label, 'افحص القيود');
      expect(actions.single.prompt, startsWith('شغّل مراجعة القيود'));
    });

    test('deep-dive chips drop the ones already on a counter button', () {
      final chips =
          pulseDeepActions(InteractiveCardKind.accountant, accountant, en);

      expect(chips.first.label, 'The opinion');
      // "Reconcile bank" is already a counter button above; no chip repeats
      // a label that is already on the card.
      final labels = chips.map((c) => c.label).toSet();
      final actions = pulseActions(InteractiveCardKind.accountant, accountant, en)
          .map((a) => a.label)
          .toSet();
      expect(labels.intersection(actions), isEmpty);
    });

    test('hr counters carry the recruitment prompts', () {
      final actions = pulseActions(
        InteractiveCardKind.hr,
        const {
          'kind': 'hr',
          'counters': [
            {'key': 'applicants', 'label': 'Applicants to screen', 'value': 12},
          ],
        },
        en,
      );

      expect(actions.single.label, 'Screen applicants');
      expect(actions.single.prompt, contains('Odoo Recruitment'));
    });

    test('the free-text action exists on exactly three cards', () {
      expect(pulseFreeTextAction(InteractiveCardKind.accountant), isNotNull);
      expect(pulseFreeTextAction(InteractiveCardKind.hr), isNotNull);
      expect(pulseFreeTextAction(InteractiveCardKind.inventory), isNotNull);
      expect(pulseFreeTextAction(InteractiveCardKind.finance), isNull);
      expect(pulseFreeTextAction(InteractiveCardKind.factory), isNull);
      expect(pulseFreeTextAction(InteractiveCardKind.purchasing), isNull);
      expect(pulseFreeTextAction(InteractiveCardKind.qualityGuard), isNull);
    });
  });

  // The web's `EXTRA` array and `.ac-explain` box, which the phone never
  // had. Reported from a live database: "في الكارت ناقص بانر السيرش التتبع".
  group('the inventory chips and tracking box', () {
    test('four chips, in the web\'s order, the first one filled', () {
      final chips = pulseDeepActions(
        InteractiveCardKind.inventory,
        const {'kind': 'inventory'},
        en,
      );

      expect(
        chips.map((c) => c.label),
        ['Track shipments', 'Stalled transfers', 'Stock accuracy',
          'Locate a product'],
      );
      expect(chips.map((c) => c.primary), [true, false, false, false]);
      for (final chip in chips) {
        expect(chip.prompt, isNotEmpty);
        expect(chip.prompt, isNot(startsWith('pulse_act_')));
      }
    });

    test('a chip whose label is already a bucket button is dropped', () {
      // Same rule as the accountant's `dropChipsAlreadyOnTiles`. None of the
      // four overlaps today; this pins that it would be caught if one did.
      const busy = {
        'kind': 'inventory',
        'low_stock': {'available': true, 'count': 4},
        'stagnant_stock': {'available': true, 'count': 2},
      };
      final chips = pulseDeepActions(InteractiveCardKind.inventory, busy, en)
          .map((c) => c.label)
          .toSet();
      final buttons = pulseActions(InteractiveCardKind.inventory, busy, en)
          .map((a) => a.label)
          .toSet();

      expect(chips.intersection(buttons), isEmpty);
    });

    test('the tracker names the reference; an empty one asks for everything',
        () {
      final spec = pulseFreeTextAction(InteractiveCardKind.inventory)!;

      expect(en.format(spec.promptKey, {'ref': 'WH/OUT/00042'}),
          contains('WH/OUT/00042'));
      // An empty box is not silence here: it sends the same prompt the
      // Track-shipments chip does, which is the web's behaviour.
      expect(spec.emptyPromptKey, 'pulse_act_inventory_deep_track_prompt');
      expect(en.lookup(spec.emptyPromptKey!), isNotEmpty);
      // The other two have no such fallback — "explain ''" is not a question.
      expect(pulseFreeTextAction(InteractiveCardKind.accountant)!.emptyPromptKey,
          isNull);
      expect(pulseFreeTextAction(InteractiveCardKind.hr)!.emptyPromptKey,
          isNull);
    });

    test('every chip and the tracker resolve in Arabic too', () {
      final chips = pulseDeepActions(
        InteractiveCardKind.inventory,
        const {'kind': 'inventory'},
        ar,
      );
      expect(chips, hasLength(4));
      for (final chip in chips) {
        expect(chip.label, matches(RegExp(r'[؀-ۿ]')));
        expect(chip.prompt, matches(RegExp(r'[؀-ۿ]')));
      }

      final spec = pulseFreeTextAction(InteractiveCardKind.inventory)!;
      expect(ar.lookup(spec.hint), isNotEmpty);
      expect(ar.lookup(spec.label), isNotEmpty);
      expect(ar.format(spec.promptKey, {'ref': 'ورق'}), contains('ورق'));
    });
  });

  group('formatPulseNumber — the web\'s own number formatting', () {
    test('groups thousands and keeps at most two decimals', () {
      expect(formatPulseNumber(303194), '303,194');
      expect(formatPulseNumber(64810.25), '64,810.25');
      expect(formatPulseNumber(14726.361), '14,726.36');
      expect(formatPulseNumber(95250.0), '95,250');
      expect(formatPulseNumber(-1200), '-1,200');
      expect(formatPulseNumber(0), '0');
    });

    test('an absent value is an em dash, never a zero', () {
      expect(formatPulseNumber(null), '—');
      expect(formatPulseNumber(''), '—');
    });

    test('a non-numeric value prints as itself rather than throwing', () {
      expect(formatPulseNumber('covered'), 'covered');
    });
  });

  group('hostile payloads', () {
    test('never throw, whatever the server sends', () {
      const hostile = <Map<String, dynamic>>[
        {'kind': 'finance', 'receivables': 'nope', 'liquidity_7d': 42},
        {'kind': 'finance', 'collection_aging': <Object?>[]},
        {'kind': 'factory', 'top_risks': 'nope'},
        {
          'kind': 'factory',
          'top_risks': [null, 5, 'x'],
        },
        {'kind': 'purchasing', 'vendor_bills': <Object?>[]},
        {'kind': 'inventory', 'demand_shortage': {'items': 'nope'}},
        {'kind': 'quality_guard', 'spec_guard': 'nope'},
        {'kind': 'accountant', 'counters': 'nope'},
        {'kind': 'hr', 'counters': <Object?>[null, 5]},
      ];

      for (final payload in hostile) {
        for (final kind in InteractiveCardKind.values) {
          expect(() => pulseActions(kind, payload, en), returnsNormally,
              reason: '$kind / $payload');
          expect(() => pulseDeepActions(kind, payload, ar), returnsNormally,
              reason: '$kind / $payload');
        }
      }
    });
  });

  group('every action string resolves in both locales', () {
    // The builder looks its copy up by constructed key, so nothing but this
    // test stands between a typo and a button labelled with a raw key.
    test('no key falls back to empty', () {
      const payloads = <InteractiveCardKind, Map<String, dynamic>>{
        InteractiveCardKind.finance: {
          'kind': 'finance',
          'receivables': {
            'overdue': {'available': true, 'count': 2, 'total': 10.0},
          },
          'payables': {
            'overdue': {'available': true, 'count': 1, 'total': 5.0},
          },
          'drafts': {
            'customer_invoices': {'available': true, 'count': 1},
            'vendor_bills': {'available': true, 'count': 1},
          },
          'bank_reconciliation': {'available': true, 'count': 3},
          'liquidity_7d': {'available': true, 'cash_gap': -1.0},
        },
        InteractiveCardKind.factory: {
          'kind': 'factory',
          'top_risks': [
            {'order': 'SO/1', 'lead_days': 2, 'worst_product': 'X'},
          ],
        },
        InteractiveCardKind.purchasing: {
          'kind': 'purchasing',
          'late_purchase_orders': {'available': true, 'count': 1},
          'awaiting_approval': {'available': true, 'count': 1},
          'open_rfqs': {'available': true, 'count': 1},
          'to_bill': {'available': true, 'count': 1},
          'vendor_bills': {
            'overdue': {'available': true, 'count': 1},
          },
        },
        InteractiveCardKind.inventory: {
          'kind': 'inventory',
          'demand_shortage': {'available': true, 'count': 1},
          'low_stock': {'available': true, 'count': 1},
          'fast_reorder': {'available': true, 'count': 1},
          'stagnant_stock': {'available': true, 'count': 1},
          'overstock': {'available': true, 'count': 1},
          'missing_data': {'available': true, 'count': 1},
        },
        InteractiveCardKind.qualityGuard: {
          'kind': 'quality_guard',
          'out_of_spec': 1,
          'failed_checks': 1,
          'lower_cost_substitutes': 1,
          'missing_numeric_specs': 1,
          'spec_guard': {
            'findings': [
              {
                'order': 'SO/1',
                'requested_product': 'A',
                'actual_product': 'B',
                'discount': 10,
                'risk_score': 3,
              },
            ],
          },
        },
      };

      for (final tr in [en, ar]) {
        payloads.forEach((kind, payload) {
          for (final action in pulseActions(kind, payload, tr)) {
            expect(action.label, isNotEmpty, reason: '$kind label');
            expect(action.prompt, isNotEmpty, reason: '$kind prompt');
            expect(action.label, isNot(startsWith('pulse_act_')));
            expect(action.prompt, isNot(startsWith('pulse_act_')));
            expect(action.main, isNot(contains('{')), reason: '$kind main');
            expect(action.cause, isNot(contains('{')), reason: '$kind cause');
          }
        });

        for (final kind in [
          InteractiveCardKind.accountant,
          InteractiveCardKind.hr,
        ]) {
          final name = kind == InteractiveCardKind.hr ? 'hr' : 'accountant';
          for (final key in pulseCounterActionKeys(name)) {
            final actions = pulseActions(
              kind,
              {
                'kind': name,
                'counters': [
                  {'key': key, 'label': 'L', 'value': 1},
                ],
              },
              tr,
            );
            expect(actions, hasLength(1), reason: '$name/$key');
            expect(actions.single.label, isNotEmpty, reason: '$name/$key');
            expect(actions.single.prompt, isNotEmpty, reason: '$name/$key');
          }
          for (final chip in pulseDeepActions(kind, {'kind': name}, tr)) {
            expect(chip.label, isNotEmpty);
            expect(chip.prompt, isNotEmpty);
          }
          final spec = pulseFreeTextAction(kind)!;
          expect(tr.lookup(spec.hint), isNotEmpty);
          expect(tr.lookup(spec.label), isNotEmpty);
          expect(tr.format(spec.promptKey, {'ref': 'INV/1'}),
              contains('INV/1'));
        }
      }
    });
  });
}
