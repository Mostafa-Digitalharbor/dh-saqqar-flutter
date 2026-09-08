// The seven cards against the payloads the server actually sends.
//
// Every other test in this suite feeds the parsers a fixture written by
// hand from the doc. This one feeds them `test/fixtures/real_pulse_payloads
// .json` — captured 2026-09-07 from the live API for all seven guided apps
// (Sijil IT / `test` environment), with partner, product and employee names
// replaced by placeholders and everything else, keys, numbers, shapes and
// the Arabic notes, left exactly as the server sent it.
//
// It exists because the doc's key list and the live payload disagree in
// places that matter: quality guard nests its buckets under `quality_gate`
// and `spec_guard`, the accountant sends `blocks` next to `counters`, HR
// sends `recruitment` / `payroll` / `time_off` as their own keys. Fixtures
// written from prose would have kept passing while the cards rendered
// nothing.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saqqar_app/core/i18n/app_strings.dart';
import 'package:saqqar_app/features/chat/data/app_pulse_payloads.dart';
import 'package:saqqar_app/features/chat/data/interactive_cards.dart';
import 'package:saqqar_app/features/chat/data/pulse_actions.dart';

Map<String, dynamic> _payload(String key) {
  final raw = File('test/fixtures/real_pulse_payloads.json').readAsStringSync();
  final all = jsonDecode(raw) as Map<String, dynamic>;
  return (all[key] as Map).cast<String, dynamic>();
}

void main() {
  final en = AppStrings(const Locale('en'));
  final ar = AppStrings(const Locale('ar'));

  const kinds = <String, InteractiveCardKind>{
    'money': InteractiveCardKind.finance,
    'inventory': InteractiveCardKind.inventory,
    'factory': InteractiveCardKind.factory,
    'purchasing': InteractiveCardKind.purchasing,
    'quality': InteractiveCardKind.qualityGuard,
    'accountant': InteractiveCardKind.accountant,
    'hr': InteractiveCardKind.hr,
  };

  group('the live payloads parse into cards', () {
    kinds.forEach((name, kind) {
      test('$name renders as a card, not as a text dump', () {
        final payload = _payload(name);

        // Stage 2 of the chain: the visibility filter keeps the message
        // only if some parser can use the payload.
        expect(hasRenderableInteractiveCard(payload), isTrue,
            reason: '$name would fall through to a plain text bubble');
        expect(interactiveCardKind(payload), kind);
      });
    });

    test('finance reads the aging the server really sends', () {
      final parsed = FinancePulsePayload.parse(_payload('money'))!;

      expect(parsed.envelope.status, PulseStatus.ok);
      expect(parsed.collectionAging, isNotNull);
      // The bands are `days_1_30` / `days_31_60` / `days_61_plus` on the
      // wire — the doc never said so.
      expect(parsed.collectionAging!.bands, isNotEmpty);
      for (final band in parsed.collectionAging!.bands) {
        expect(band.label, isNot(contains('_')),
            reason: 'a machine key reached the screen');
      }
    });

    test('quality guard finds its numbers under the nested stat objects', () {
      final parsed = QualityGuardPulsePayload.parse(_payload('quality'))!;

      // At least one of the sixteen has to have come through, or the card
      // is a row of em dashes.
      final numbers = [
        parsed.outOfSpec,
        parsed.failedChecks,
        parsed.pendingChecks,
        parsed.qualityAlerts,
        parsed.reviewCases,
        parsed.deepDiscounts,
        parsed.undocumentedSubstitutes,
      ].whereType<int>();
      expect(numbers, isNotEmpty);
    });

    test('the accountant gets both its counters and their audit trail', () {
      final parsed = AccountantPulsePayload.parse(_payload('accountant'))!;

      expect(parsed.counters, isNotEmpty);
      final withTrail = parsed.counters
          .where((c) => parsed.detailsFor(c.key).isNotEmpty)
          .toList();
      expect(withTrail, isNotEmpty,
          reason: '`blocks` is on the wire; a counter should be able to '
              'show the rows behind it');
    });

    test('HR reads recruitment, payroll and time off', () {
      final parsed = HrPulsePayload.parse(_payload('hr'))!;

      // All three keys are on the wire for this database.
      expect(parsed.recruitment, isNotNull);
      expect(parsed.payroll, isNotNull);
      expect(parsed.timeOff, isNotNull);
      expect(parsed.counters, isNotEmpty);
    });
  });

  group('the live payloads produce the web\'s action rows', () {
    // The database these came from is a freshly seeded test Odoo: several
    // of its cards legitimately have nothing to act on, and the web shows
    // its "looks calm in the current read" line for exactly that. So what
    // is asserted here is the pair — a row where there is something to do,
    // the empty-state sentence where there is not — never silence.
    kinds.forEach((name, kind) {
      test('$name either offers a button or says it is calm', () {
        final payload = _payload(name);

        for (final tr in [en, ar]) {
          final actions = pulseActions(kind, payload, tr);
          final deep = pulseDeepActions(kind, payload, tr);
          final all = [...actions, ...deep];

          if (all.isEmpty) {
            expect(
              pulseEmptyStateText(kind, tr),
              isNotEmpty,
              reason: '$name renders neither an action nor an empty state, '
                  'so the card just stops after its numbers',
            );
          }
          for (final action in all) {
            expect(action.label, isNotEmpty);
            expect(action.prompt, isNotEmpty);
            // A missing key would surface as the raw `pulse_act_…` string.
            expect(action.label, isNot(startsWith('pulse_act_')));
            expect(action.prompt, isNot(startsWith('pulse_act_')));
            // An unsubstituted placeholder would read as "{n} invoice(s)".
            expect(action.main, isNot(contains('{')));
            expect(action.cause, isNot(contains('{')));
            expect(action.title, isNot(contains('{')));
          }
        }
      });
    });

    test('never more than one filled button on a card', () {
      // At most one, not exactly one: the web marks a row primary only
      // where it has a lead to give (finance's first row, purchasing's late
      // receipts), and inventory's rows are all ghosts there too. Two
      // filled buttons would be the actual defect — a card with two
      // "start here" answers.
      for (final entry in kinds.entries) {
        final actions = pulseActions(entry.value, _payload(entry.key), en);
        expect(
          actions.where((a) => a.primary).length,
          lessThanOrEqualTo(1),
          reason: '${entry.key} has ${actions.length} rows',
        );
      }
    });

    test('the counter-driven cards act on this database', () {
      // HR and the accountant both have counters here, so both must offer
      // buttons — these are the two kinds with no empty state to fall back
      // on, which makes silence a real failure rather than good news.
      for (final kind in [
        InteractiveCardKind.accountant,
        InteractiveCardKind.hr,
      ]) {
        final name = kind == InteractiveCardKind.hr ? 'hr' : 'accountant';
        final actions = pulseActions(kind, _payload(name), en);
        final deep = pulseDeepActions(kind, _payload(name), en);
        expect([...actions, ...deep], isNotEmpty, reason: name);
      }
    });

    test('the numbers in a row are formatted, never raw', () {
      for (final entry in kinds.entries) {
        for (final action
            in pulseActions(entry.value, _payload(entry.key), en)) {
          // `1234.5678` would mean formatPulseNumber never ran.
          expect(
            RegExp(r'\d+\.\d{3,}').hasMatch(action.main),
            isFalse,
            reason: '${entry.key}: ${action.main}',
          );
        }
      }
    });
  });
}
