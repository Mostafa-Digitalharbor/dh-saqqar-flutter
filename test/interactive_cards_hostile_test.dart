// Hostile-input sweep for the interactive-card parsers.
//
// These run on the render path of the app's main surface: `isVisibleMessage`
// calls `hasRenderableInteractiveCard` for EVERY message in a snapshot, on
// every poll. A parser that throws on one malformed payload doesn't lose one
// card — it takes down the whole conversation, on a 1.5 s loop, with no way
// for the user to get back in.
//
// So the contract is absolute: **never throw, always answer**. Every input
// below is either a real shape the backend could send during a partial
// rollout, or the kind of junk a proxy/serializer produces when something
// upstream goes wrong. Each must return either a usable payload or null.
//
// Mirrors the "5 hostile responses" convention the other API clients follow.

import 'package:flutter_test/flutter_test.dart';
import 'package:saqqar_app/features/chat/data/interactive_cards.dart';

/// Every payload here must be survivable by every parser.
const _hostile = <String, Object?>{
  'null payload': null,
  'empty map': <String, dynamic>{},
  'kind is null': {'kind': null},
  'kind is a number': {'kind': 7},
  'kind is a list': {'kind': <String>[]},
  'kind is empty string': {'kind': ''},
  'unknown kind': {'kind': 'totally_new_card'},
  'clarify: questions is a string': {
    'kind': 'prompt_clarify',
    'questions': 'nope',
  },
  'clarify: questions is a map': {
    'kind': 'prompt_clarify',
    'questions': {'a': 1},
  },
  'clarify: question entries are junk': {
    'kind': 'prompt_clarify',
    'questions': [1, 'two', null, true],
  },
  'clarify: options is a string': {
    'kind': 'prompt_clarify',
    'questions': [
      {'question': 'Q', 'options': 'a,b,c'},
    ],
  },
  'clarify: default is a string': {
    'kind': 'prompt_clarify',
    'questions': [
      {
        'question': 'Q',
        'options': ['a'],
        'default': 'first',
      },
    ],
  },
  'clarify: default is a double': {
    'kind': 'prompt_clarify',
    'questions': [
      {
        'question': 'Q',
        'options': ['a', 'b'],
        'default': 1.9,
      },
    ],
  },
  'clarify: intro is a number': {
    'kind': 'prompt_clarify',
    'intro': 42,
    'questions': [
      {'question': 'Q', 'options': <String>[]},
    ],
  },
  'suggestion: improved is a number': {
    'kind': 'prompt_suggestion',
    'improved': 42,
  },
  'suggestion: improved is a map': {
    'kind': 'prompt_suggestion',
    'improved': {'text': 'hi'},
  },
  'suggestion: note is a list': {
    'kind': 'prompt_suggestion',
    'improved': 'ok',
    'note': <String>[],
  },
  'report: types is a string': {'kind': 'report_builder', 'types': 'sales'},
  'report: type entries are junk': {
    'kind': 'report_builder',
    'types': [null, 3, 'x'],
  },
  'report: lenses is a string': {
    'kind': 'report_builder',
    'types': [
      {'key': 'a', 'label': 'A'},
    ],
    'lenses': 'by_customer',
  },
  'report: lens group is a string': {
    'kind': 'report_builder',
    'types': [
      {'key': 'a', 'label': 'A'},
    ],
    'lenses': {'a': 'by_customer'},
  },
  'report: lens entries are junk': {
    'kind': 'report_builder',
    'types': [
      {'key': 'a', 'label': 'A'},
    ],
    'lenses': {
      'a': [null, 5, 'x'],
    },
  },
  'report: numeric keys and labels': {
    'kind': 'report_builder',
    'types': [
      {'key': 7, 'label': 9},
    ],
  },
  'report: periods/formats are maps': {
    'kind': 'report_builder',
    'types': [
      {'key': 'a', 'label': 'A'},
    ],
    'periods': {'this_month': 'This month'},
    'formats': 12,
  },
};

Map<String, dynamic>? _payload(Object? raw) =>
    raw == null ? null : (raw as Map).cast<String, dynamic>();

void main() {
  group('no parser throws on hostile input', () {
    _hostile.forEach((name, raw) {
      test(name, () {
        final payload = _payload(raw);

        // Each returns "a card" or "not a card" — never an exception.
        expect(() => interactiveCardKind(payload), returnsNormally);
        expect(() => PromptClarifyPayload.parse(payload), returnsNormally);
        expect(() => PromptSuggestionPayload.parse(payload), returnsNormally);
        expect(() => ReportBuilderPayload.parse(payload), returnsNormally);
        expect(
          () => hasRenderableInteractiveCard(payload),
          returnsNormally,
        );
      });
    });
  });

  group('hostile input never produces a half-built card', () {
    test('the render gate agrees with the parsers, always', () {
      // `hasRenderableInteractiveCard` is what the visibility filter trusts.
      // If it ever says yes while the matching parser says null, the message
      // is kept and then renders as an empty bubble.
      for (final raw in _hostile.values) {
        final payload = _payload(raw);
        final renderable = hasRenderableInteractiveCard(payload);
        final parsed = PromptClarifyPayload.parse(payload) ??
            PromptSuggestionPayload.parse(payload) ??
            ReportBuilderPayload.parse(payload);

        expect(
          renderable,
          parsed != null,
          reason: 'gate and parser disagree on $payload',
        );
      }
    });

    test('an unusable clarify card is null, not an empty question list', () {
      final parsed = PromptClarifyPayload.parse(const {
        'kind': 'prompt_clarify',
        'questions': [1, 'two', null],
      });

      expect(parsed, isNull);
    });

    test('a report card with only junk types is null', () {
      expect(
        ReportBuilderPayload.parse(const {
          'kind': 'report_builder',
          'types': [null, 3, 'x'],
        }),
        isNull,
      );
    });
  });

  group('salvageable input is salvaged, not discarded', () {
    test('junk questions are skipped but good ones survive', () {
      final parsed = PromptClarifyPayload.parse(const {
        'kind': 'prompt_clarify',
        'questions': [
          'junk',
          {'question': 'Which period?', 'options': ['This month', null, 42]},
          null,
        ],
      })!;

      expect(parsed.questions, hasLength(1));
      // `42` stringifies rather than being dropped — it is a server-authored
      // option, and showing "42" beats silently losing a choice.
      expect(parsed.questions.single.options, ['This month', '42']);
    });

    test('a non-integer default degrades to no pre-selection', () {
      final parsed = PromptClarifyPayload.parse(const {
        'kind': 'prompt_clarify',
        'questions': [
          {
            'question': 'Q',
            'options': ['a', 'b'],
            'default': 'first',
          },
        ],
      })!;

      expect(parsed.questions.single.defaultIndex, isNull);
    });

    test('a 1.9 default truncates to a valid index, not a crash', () {
      final parsed = PromptClarifyPayload.parse(const {
        'kind': 'prompt_clarify',
        'questions': [
          {
            'question': 'Q',
            'options': ['a', 'b'],
            'default': 1.9,
          },
        ],
      })!;

      expect(parsed.questions.single.defaultIndex, 1);
    });

    test('numeric report keys stringify instead of dropping the chip', () {
      final parsed = ReportBuilderPayload.parse(const {
        'kind': 'report_builder',
        'types': [
          {'key': 7, 'label': 9},
        ],
      })!;

      expect(parsed.types.single.key, '7');
      // The label stringifies too — it is still a server-authored value, and
      // showing "9" beats dropping the chip or blanking it.
      expect(parsed.types.single.label, '9');
    });

    test('a junk lens group leaves the rest of the card usable', () {
      final parsed = ReportBuilderPayload.parse(const {
        'kind': 'report_builder',
        'types': [
          {'key': 'a', 'label': 'A'},
        ],
        'lenses': {'a': 'by_customer'},
      })!;

      expect(parsed.types, hasLength(1));
      expect(parsed.lensesFor('a'), isEmpty);
    });
  });

  group('report-entities responses', () {
    test('hostile bodies never throw', () {
      const bodies = <Map<String, dynamic>>[
        {},
        {'items': null},
        {'items': 'nope'},
        {'items': 42},
        {'items': [null, 1, 'x']},
        {'items': <Object>[], 'truncated': 'yes'},
        {
          'items': [
            {'id': null, 'name': null},
          ],
        },
      ];

      for (final body in bodies) {
        expect(() => ReportEntityPage.fromJson(body), returnsNormally,
            reason: '$body');
        expect(ReportEntityPage.fromJson(body).items, isA<List<ReportEntity>>());
      }
    });

    test('a non-bool truncated flag reads as false, not as "there is more"', () {
      // Better to under-warn than to permanently show a warning the user
      // cannot clear.
      expect(
        ReportEntityPage.fromJson(const {
          'items': <Object>[],
          'truncated': 'yes',
        }).truncated,
        isFalse,
      );
    });
  });
}
