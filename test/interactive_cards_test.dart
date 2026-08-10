// docs/WEB_UI_PARITY_GAPS.md §4 + Appendix A — parsing the interactive-card
// payloads.
//
// These parsers stand between a server payload and a card the user taps, so
// every one of them has two jobs: read the documented shape, and return
// `null` for anything it cannot honestly render. `null` means "fall through
// to an ordinary message" — a card with no answerable question, or an
// "Approve & use" button over an empty field, is worse than no card at all,
// and an exception here would take the whole chat list down.

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saqqar_app/core/i18n/app_strings.dart';
import 'package:saqqar_app/features/chat/data/interactive_cards.dart';

void main() {
  group('kind dispatch', () {
    test('recognises the three web kinds', () {
      expect(
        interactiveCardKind({'kind': 'prompt_clarify'}),
        InteractiveCardKind.promptClarify,
      );
      expect(
        interactiveCardKind({'kind': 'report_builder'}),
        InteractiveCardKind.reportBuilder,
      );
      expect(
        interactiveCardKind({'kind': 'prompt_suggestion'}),
        InteractiveCardKind.promptSuggestion,
      );
    });

    test('an ordinary tool payload is not a card', () {
      // What `tool_calls` payloads look like — these must keep rendering on
      // the generic tool-activity card.
      expect(interactiveCardKind(null), isNull);
      expect(interactiveCardKind({}), isNull);
      expect(interactiveCardKind({'tool_calls': <String>[]}), isNull);
      expect(interactiveCardKind({'kind': 'something_new'}), isNull);
      expect(interactiveCardKind({'kind': 42}), isNull);
    });
  });

  group('prompt_clarify (A.1)', () {
    const payload = {
      'kind': 'prompt_clarify',
      'original': 'build me a report',
      'intro': 'A couple of quick questions before I start 👇',
      'questions': [
        {
          'question': 'Which period?',
          'options': ['This month', 'This quarter', 'This year'],
          'default': 1,
        },
        {
          'question': 'Which format?',
          'options': ['PDF', 'Excel'],
        },
      ],
    };

    test('reads the documented shape', () {
      final parsed = PromptClarifyPayload.parse(payload)!;

      expect(parsed.original, 'build me a report');
      expect(parsed.intro, startsWith('A couple of quick questions'));
      expect(parsed.questions, hasLength(2));
      expect(parsed.questions.first.options, hasLength(3));
      expect(parsed.questions.first.defaultIndex, 1);
      expect(parsed.questions[1].defaultIndex, isNull);
    });

    test('normalises an out-of-range or -1 default away', () {
      // Appendix A.1: "-1/absent = none". An index past the end would make
      // the card highlight a chip that isn't there — or throw.
      for (final bad in [-1, 3, 99]) {
        final parsed = PromptClarifyPayload.parse({
          'kind': 'prompt_clarify',
          'questions': [
            {
              'question': 'Q',
              'options': ['a', 'b'],
              'default': bad,
            },
          ],
        })!;
        expect(parsed.questions.single.defaultIndex, isNull, reason: '$bad');
      }
    });

    test('falls through when there is nothing to answer', () {
      expect(
        PromptClarifyPayload.parse({
          'kind': 'prompt_clarify',
          'questions': <Object>[],
        }),
        isNull,
      );
      // A question with no text is not a question.
      expect(
        PromptClarifyPayload.parse({
          'kind': 'prompt_clarify',
          'questions': [
            {'question': '', 'options': ['a']},
          ],
        }),
        isNull,
      );
      // Wrong kind → not this parser's payload.
      expect(
        PromptClarifyPayload.parse({'kind': 'report_builder'}),
        isNull,
      );
    });

    test('survives junk inside the questions list', () {
      final parsed = PromptClarifyPayload.parse({
        'kind': 'prompt_clarify',
        'questions': [
          'not a map',
          null,
          {
            'question': 'Which period?',
            'options': ['This month', null, ''],
          },
        ],
      })!;

      expect(parsed.questions, hasLength(1));
      expect(parsed.questions.single.options, ['This month']);
    });
  });

  group('prompt_suggestion (A.3)', () {
    test('reads improved + note', () {
      final parsed = PromptSuggestionPayload.parse({
        'kind': 'prompt_suggestion',
        'improved': 'List unpaid customer invoices for June 2026.',
        'note': 'Narrowed to a period so the query stays cheap.',
      })!;

      expect(parsed.improved, startsWith('List unpaid'));
      expect(parsed.note, isNotEmpty);
    });

    test('falls through with no suggestion text', () {
      expect(
        PromptSuggestionPayload.parse({
          'kind': 'prompt_suggestion',
          'improved': '   ',
        }),
        isNull,
      );
      expect(
        PromptSuggestionPayload.parse({'kind': 'prompt_suggestion'}),
        isNull,
      );
    });
  });

  group('report_builder (A.2)', () {
    const payload = {
      'kind': 'report_builder',
      'types': [
        {'key': 'sales_orders', 'label': 'Sales orders'},
        {'key': 'customers_aging', 'label': 'Customer aging'},
      ],
      'periods': [
        {'key': 'this_month', 'label': 'This month'},
      ],
      'formats': [
        {'key': 'pdf', 'label': 'PDF'},
      ],
      'lenses': {
        'customers_aging': [
          {
            'key': 'by_customer',
            'label': 'By customer',
            'entity': 'customers',
            'submit_en': 'Build a customer aging report',
            'submit_ar': 'أنشئ تقرير أعمار ديون العملاء',
          },
        ],
      },
    };

    test('reads chips and keys lenses by report type', () {
      final parsed = ReportBuilderPayload.parse(payload)!;

      expect(parsed.types.map((t) => t.key),
          ['sales_orders', 'customers_aging']);
      expect(parsed.periods.single.label, 'This month');
      expect(parsed.formats.single.key, 'pdf');
      // A lens group applies only to its own type.
      expect(parsed.lensesFor('sales_orders'), isEmpty);
      expect(parsed.lensesFor('customers_aging'), hasLength(1));
    });

    test('a lens carries its entity family and per-locale submit text', () {
      final lens =
          ReportBuilderPayload.parse(payload)!.lensesFor('customers_aging')
              .single;

      expect(lens.entity, 'customers');
      expect(ReportBuilderPayload.entityFamilies, contains(lens.entity));
      expect(lens.submitFor(arabic: false), 'Build a customer aging report');
      expect(lens.submitFor(arabic: true), 'أنشئ تقرير أعمار ديون العملاء');
    });

    test('submitFor falls back to the other locale rather than going blank',
        () {
      const lens = ReportLens(
        key: 'k',
        label: 'L',
        submitEn: 'English only',
      );

      expect(lens.submitFor(arabic: true), 'English only');
    });

    test('accepts lenses sent as a flat list — they apply to every type', () {
      final parsed = ReportBuilderPayload.parse({
        'kind': 'report_builder',
        'types': [
          {'key': 'a', 'label': 'A'},
        ],
        'lenses': [
          {'key': 'l1', 'label': 'L1'},
        ],
      })!;

      expect(parsed.lensesFor('a'), hasLength(1));
      expect(parsed.lensesFor('anything_else'), hasLength(1));
    });

    test('accepts a lens group sent as a key → object map', () {
      final parsed = ReportBuilderPayload.parse({
        'kind': 'report_builder',
        'types': [
          {'key': 'a', 'label': 'A'},
        ],
        'lenses': {
          'a': {
            'by_x': {'label': 'By X', 'entity': 'vendors'},
          },
        },
      })!;

      final lens = parsed.lensesFor('a').single;
      expect(lens.key, 'by_x');
      expect(lens.label, 'By X');
      expect(lens.entity, 'vendors');
    });

    group('chip label resolution (web parity for rbType_/rbPeriod_/…)', () {
      final en = AppStrings(const Locale('en'));

      test('falls back to the server label when no client key exists', () {
        // The state the app ships in today: the key table is empty on purpose
        // (a half-translated chip row reads as a bug), so every chip shows
        // exactly what the server sent.
        const option = ReportOption(key: 'sales_orders', label: 'Sales orders');

        expect(
          option.displayLabel(en, ReportLabelKeys.type),
          'Sales orders',
        );
      });

      test('a client key wins over the server label when one is added', () {
        // Proves the seam works, using a key that already exists in the
        // table. When the web team sends the chip-key list, adding
        // `rbType_sales_orders` entries is all that is needed — no code.
        const option = ReportOption(key: 'Url', label: 'Server label');

        expect(option.displayLabel(en, 'cred'), isNot('Server label'));
        expect(option.displayLabel(en, 'cred'), en.lookup('credUrl'));
      });

      test('an unknown key never leaks onto the screen', () {
        const option = ReportOption(key: 'brand_new_type', label: 'Brand new');

        final shown = option.displayLabel(en, ReportLabelKeys.type);
        expect(shown, 'Brand new');
        expect(shown, isNot(contains('rbType_')));
      });

      test('a lens resolves through its own prefix', () {
        const lens = ReportLens(key: 'by_customer', label: 'By customer');

        expect(lens.displayLabel(en), 'By customer');
      });
    });

    test('a chip with no label shows its key rather than a blank pill', () {
      final parsed = ReportBuilderPayload.parse({
        'kind': 'report_builder',
        'types': [
          {'key': 'sales_orders'},
        ],
      })!;

      expect(parsed.types.single.label, 'sales_orders');
    });

    test('falls through when there is no type to pick', () {
      expect(
        ReportBuilderPayload.parse({
          'kind': 'report_builder',
          'types': <Object>[],
        }),
        isNull,
      );
      // A keyless entry can't compose a request.
      expect(
        ReportBuilderPayload.parse({
          'kind': 'report_builder',
          'types': [
            {'label': 'orphan'},
          ],
        }),
        isNull,
      );
    });
  });

  group('report-entities response (A.2)', () {
    test('reads items and the truncation flag', () {
      final page = ReportEntityPage.fromJson(const {
        'ok': true,
        'items': [
          {'id': 42, 'name': 'Acme Co'},
          {'id': 43, 'name': 'Globex'},
        ],
        'truncated': true,
      });

      expect(page.items.map((e) => e.id), ['42', '43']);
      expect(page.items.first.name, 'Acme Co');
      expect(page.truncated, isTrue);
    });

    test('drops rows that could not be ticked or labelled', () {
      final page = ReportEntityPage.fromJson(const {
        'items': [
          {'id': 1, 'name': 'Fine'},
          {'id': 2, 'name': ''},
          {'name': 'No id'},
          'junk',
        ],
      });

      expect(page.items, hasLength(1));
      expect(page.truncated, isFalse);
    });
  });
}
