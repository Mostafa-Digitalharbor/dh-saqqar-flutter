// The filter that decides which server messages reach the chat stream.
//
// This file exists because of a defect that every other test in the suite
// missed. `docs/WEB_UI_PARITY_GAPS.md` Appendix A says the interactive-card
// payload arrives "on an assistant/tool message" — and the visibility filter
// dropped *every* tool-role row and *every* empty-content assistant row as
// agent plumbing. So all three cards rendered perfectly in widget tests
// (which pump a `MessageRow` directly, below the filter) while being
// unreachable in the running app.
//
// The lesson is the test, not the fix: a card is only shipped when the filter
// lets it through, so the filter is what gets asserted here.

import 'package:flutter_test/flutter_test.dart';
import 'package:saqqar_app/features/chat/data/message_visibility.dart';
import 'package:saqqar_app/features/conversations/data/conversation_models.dart';

Message _message({
  required MessageRole role,
  String content = '',
  Map<String, dynamic>? toolPayload,
}) =>
    Message(
      id: 'm1',
      role: role,
      content: content,
      createdAt: DateTime(2026, 8, 4),
      toolPayload: toolPayload,
    );

const _clarify = {
  'kind': 'prompt_clarify',
  'questions': [
    {
      'question': 'Which period?',
      'options': ['This month'],
    },
  ],
};

void main() {
  group('interactive cards survive the filter', () {
    test('on a TOOL-role message', () {
      // The rule above this one drops every tool row. A card riding on one
      // would never have reached the screen.
      expect(
        isVisibleMessage(
          _message(role: MessageRole.tool, content: '', toolPayload: _clarify),
          isRunning: false,
        ),
        isTrue,
      );
    });

    test('on an assistant message with EMPTY content', () {
      // The payload IS the content for these rows — the empty-assistant rule
      // is the second way the card vanished.
      expect(
        isVisibleMessage(
          _message(
            role: MessageRole.assistant,
            content: '',
            toolPayload: _clarify,
          ),
          isRunning: false,
        ),
        isTrue,
      );
    });

    test('for all three kinds', () {
      final payloads = [
        _clarify,
        {
          'kind': 'report_builder',
          'types': [
            {'key': 'sales_orders', 'label': 'Sales orders'},
          ],
        },
        {'kind': 'prompt_suggestion', 'improved': 'Clearer wording'},
      ];

      for (final payload in payloads) {
        expect(
          isVisibleMessage(
            _message(role: MessageRole.tool, toolPayload: payload),
            isRunning: false,
          ),
          isTrue,
          reason: '${payload['kind']} must reach the stream',
        );
      }
    });
  });

  group('a payload that is not a real card is still filtered', () {
    test('right kind, nothing to answer → dropped', () {
      // Letting this through would put an empty bubble in the conversation.
      // The filter must key off "does it render", not "does it claim a kind".
      expect(
        isVisibleMessage(
          _message(
            role: MessageRole.assistant,
            content: '',
            toolPayload: {'kind': 'prompt_clarify', 'questions': <Object>[]},
          ),
          isRunning: false,
        ),
        isFalse,
      );
      expect(
        isVisibleMessage(
          _message(
            role: MessageRole.tool,
            toolPayload: {'kind': 'prompt_suggestion', 'improved': '  '},
          ),
          isRunning: false,
        ),
        isFalse,
      );
    });

    test('an ordinary tool_calls payload → dropped', () {
      expect(
        isVisibleMessage(
          _message(
            role: MessageRole.tool,
            content: '{"rows": 42}',
            toolPayload: {'tool_calls': <String>[]},
          ),
          isRunning: false,
        ),
        isFalse,
      );
    });
  });

  group('the pre-existing rules are unchanged', () {
    test('tool output and empty assistant rows stay hidden', () {
      expect(
        isVisibleMessage(
          _message(role: MessageRole.tool, content: 'rows: 42'),
          isRunning: false,
        ),
        isFalse,
      );
      expect(
        isVisibleMessage(
          _message(role: MessageRole.assistant, content: '  '),
          isRunning: false,
        ),
        isFalse,
      );
    });

    test('a real assistant reply is shown', () {
      expect(
        isVisibleMessage(
          _message(role: MessageRole.assistant, content: 'Here you go.'),
          isRunning: false,
        ),
        isTrue,
      );
    });

    test('system-injected user payloads stay hidden', () {
      for (final content in ['approve', 'REJECTED', '{"a":1}', '[1,2]', '']) {
        expect(
          isVisibleMessage(
            _message(role: MessageRole.user, content: content),
            isRunning: false,
          ),
          isFalse,
          reason: '"$content"',
        );
      }
    });

    test('short real replies are NOT mistaken for acks', () {
      for (final content in ['تمام', 'yes', 'ok']) {
        expect(
          isVisibleMessage(
            _message(role: MessageRole.user, content: content),
            isRunning: false,
          ),
          isTrue,
          reason: '"$content"',
        );
      }
    });

    test('agent-control directives stay hidden', () {
      expect(
        isVisibleMessage(
          _message(role: MessageRole.user, content: '[agent-control] proceed'),
          isRunning: false,
        ),
        isFalse,
      );
      expect(
        isVisibleMessage(
          _message(
            role: MessageRole.user,
            content: "Approval 'abc' is approved, continue.",
          ),
          isRunning: false,
        ),
        isFalse,
      );
    });
  });

  // WEB_TO_MOBILE_PARITY_AND_DELETE_FIX.md §B.1 — web only promotes a
  // `tool_payload.kind` message to a card once the run has gone idle;
  // mid-run the exact same payload is just another step. The carve-out at
  // the top of `isVisibleMessage` is what force-keeps an otherwise-filtered
  // card row visible, so gating it on `!isRunning` is what makes the whole
  // rule take effect: mid-run, a card message reverts to whatever the
  // ordinary tool/empty-content rules would have done with it anyway.
  group('idle-only gate (§B.1) — mid-run, a card is just another step', () {
    test('tool-role card message reverts to hidden while running', () {
      expect(
        isVisibleMessage(
          _message(role: MessageRole.tool, content: '', toolPayload: _clarify),
          isRunning: true,
        ),
        isFalse,
        reason: 'mid-run this is ordinary tool plumbing, not a card',
      );
    });

    test('empty-content assistant card message reverts to hidden while '
        'running', () {
      expect(
        isVisibleMessage(
          _message(
            role: MessageRole.assistant,
            content: '',
            toolPayload: _clarify,
          ),
          isRunning: true,
        ),
        isFalse,
        reason: 'mid-run this is the ordinary empty-assistant rule',
      );
    });

    test('a card message WITH real prose content stays visible while '
        'running — as prose, not because of the card carve-out', () {
      expect(
        isVisibleMessage(
          _message(
            role: MessageRole.assistant,
            content: 'Before I start, a couple of questions:',
            toolPayload: _clarify,
          ),
          isRunning: true,
        ),
        isTrue,
        reason: 'non-empty assistant content is visible on its own merits',
      );
    });

    test('the exact same message becomes visible the moment the run goes '
        'idle', () {
      final message = _message(
        role: MessageRole.tool,
        content: '',
        toolPayload: _clarify,
      );
      expect(isVisibleMessage(message, isRunning: true), isFalse);
      expect(isVisibleMessage(message, isRunning: false), isTrue);
    });
  });
}
