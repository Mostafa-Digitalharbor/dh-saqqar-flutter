// How the flat message list becomes renderable slots.
//
// This is the SECOND place an interactive card can silently disappear. The
// first is the visibility filter (`message_visibility_test`); this one is
// subtler, because the message does reach the screen — it just gets folded
// into a multi-step agent turn, where every message except the last is
// collapsed inside the "Saqqar thinking" pill. A card in there is on screen
// and unreachable: the user cannot tap chips that are behind a fold.
//
// Both failures look identical to the user ("the card never showed up"), and
// neither is visible to a widget test that pumps a `MessageRow` on its own.
// So the grouping gets its own tests, including the ordering cases that only
// happen in a real transcript.

import 'package:flutter_test/flutter_test.dart';
import 'package:saqqar_app/features/chat/data/chat_timeline.dart';
import 'package:saqqar_app/features/chat/data/chat_view_models.dart';

const _clarify = {
  'kind': 'prompt_clarify',
  'questions': [
    {
      'question': 'Which period?',
      'options': ['This month'],
    },
  ],
};

const _report = {
  'kind': 'report_builder',
  'types': [
    {'key': 'sales_orders', 'label': 'Sales orders'},
  ],
};

ChatMessage _msg(
  String id,
  ChatMessageRole role, {
  String content = 'text',
  Map<String, dynamic>? payload,
  DateTime? at,
}) =>
    ChatMessage(
      id: id,
      role: role,
      content: content,
      time: '10:00',
      toolPayload: payload,
      createdAt: at,
    );

ChatMessage _user(String id) => _msg(id, ChatMessageRole.user);
ChatMessage _agent(String id) => _msg(id, ChatMessageRole.assistant);
ChatMessage _card(String id, [Map<String, dynamic> payload = _clarify]) =>
    _msg(id, ChatMessageRole.assistant, content: '', payload: payload);

/// The ids in an entry, in render order — the shape a test actually cares
/// about, without matching on widget internals.
List<String> _ids(TimelineEntry entry) => switch (entry) {
      SingleMessageEntry(:final message) => [message.id],
      AgentTurnEntry(:final thinkingSteps, :final finalReply) => [
          ...thinkingSteps.map((m) => m.id),
          finalReply.id,
        ],
    };

/// Every test in this file exercises the idle-conversation grouping — the
/// §B.1 idle-only gate (mid-run, a card never stands alone) has its own
/// dedicated group at the bottom.
List<TimelineEntry> _idle(List<ChatMessage> messages) =>
    buildChatTimeline(messages, isRunning: false);

void main() {
  group('a card is never folded into a thinking pill', () {
    test('a card between two agent steps splits the run', () {
      // The exact shape that buries it: the card is mid-run, so the old
      // grouping made it a "thinking step" — collapsed and untappable.
      final timeline = _idle([
        _user('u1'),
        _agent('a1'),
        _card('c1'),
        _agent('a2'),
      ]);

      expect(timeline.map(_ids), [
        ['u1'],
        ['a1'],
        ['c1'],
        ['a2'],
      ]);
      expect(timeline[2], isA<SingleMessageEntry>());
    });

    test('a card at the END of a run of agent steps stands alone', () {
      final timeline = _idle([
        _agent('a1'),
        _agent('a2'),
        _card('c1'),
      ]);

      // a1 + a2 still collapse into one turn — the card does not.
      expect(timeline, hasLength(2));
      expect(timeline.first, isA<AgentTurnEntry>());
      expect(_ids(timeline.first), ['a1', 'a2']);
      expect(timeline.last, isA<SingleMessageEntry>());
      expect(_ids(timeline.last), ['c1']);
    });

    test('a card at the START of a run stands alone', () {
      final timeline = _idle([
        _card('c1'),
        _agent('a1'),
        _agent('a2'),
      ]);

      expect(timeline.first, isA<SingleMessageEntry>());
      expect(_ids(timeline.first), ['c1']);
      expect(timeline.last, isA<AgentTurnEntry>());
      expect(_ids(timeline.last), ['a1', 'a2']);
    });

    test('back-to-back cards each get their own slot', () {
      final timeline = _idle([
        _card('c1'),
        _card('c2', _report),
      ]);

      expect(timeline, hasLength(2));
      expect(timeline.every((e) => e is SingleMessageEntry), isTrue);
      expect(timeline.map(_ids), [
        ['c1'],
        ['c2'],
      ]);
    });

    test('every card kind is treated the same way', () {
      for (final payload in [
        _clarify,
        _report,
        const {'kind': 'prompt_suggestion', 'improved': 'Clearer'},
      ]) {
        final timeline = _idle([
          _agent('a1'),
          _card('c1', payload),
          _agent('a2'),
        ]);

        expect(
          timeline.map(_ids),
          [
            ['a1'],
            ['c1'],
            ['a2'],
          ],
          reason: '${payload['kind']}',
        );
      }
    });

    test('a run with a card in the middle splits into three slots', () {
      // The long-transcript shape: two thinking steps, a card, two more.
      final timeline = _idle([
        _agent('a1'),
        _agent('a2'),
        _card('c1'),
        _agent('a3'),
        _agent('a4'),
      ]);

      expect(timeline, hasLength(3));
      expect(_ids(timeline[0]), ['a1', 'a2']);
      expect(_ids(timeline[1]), ['c1']);
      expect(_ids(timeline[2]), ['a3', 'a4']);
    });
  });

  group('ordinary grouping is unchanged', () {
    test('an empty transcript yields no entries', () {
      expect(_idle(const []), isEmpty);
    });

    test('a lone agent reply is a single bubble, not a turn', () {
      final timeline = _idle([_user('u1'), _agent('a1')]);

      expect(timeline.every((e) => e is SingleMessageEntry), isTrue);
    });

    test('2+ agent messages collapse, last one is the reply', () {
      final timeline = _idle([
        _user('u1'),
        _agent('a1'),
        _agent('a2'),
        _agent('a3'),
      ]);

      expect(timeline, hasLength(2));
      final turn = timeline.last as AgentTurnEntry;
      expect(turn.thinkingSteps.map((m) => m.id), ['a1', 'a2']);
      expect(turn.finalReply.id, 'a3');
    });

    test('a user message never joins a run', () {
      final timeline = _idle([
        _agent('a1'),
        _user('u1'),
        _agent('a2'),
      ]);

      expect(timeline.map(_ids), [
        ['a1'],
        ['u1'],
        ['a2'],
      ]);
    });

    test('an ordinary tool_calls payload does NOT split a run', () {
      // Only interactive kinds stand alone. An assistant message that merely
      // carries `tool_calls` is still a thinking step.
      final timeline = _idle([
        _agent('a1'),
        _msg(
          'a2',
          ChatMessageRole.assistant,
          payload: {'tool_calls': <String>[]},
        ),
        _agent('a3'),
      ]);

      expect(timeline, hasLength(1));
      expect(_ids(timeline.single), ['a1', 'a2', 'a3']);
    });

    test('every input message appears exactly once in the output', () {
      // The invariant that matters most: grouping REARRANGES, it never drops
      // or duplicates. A dropped message is a message the user never reads.
      final input = [
        _user('u1'),
        _agent('a1'),
        _agent('a2'),
        _card('c1'),
        _user('u2'),
        _agent('a3'),
        _card('c2', _report),
        _agent('a4'),
        _agent('a5'),
      ];

      final flattened = _idle(input).expand(_ids).toList();

      expect(flattened, input.map((m) => m.id).toList());
    });
  });

  group('turn duration', () {
    test('measures first thinking step → final reply', () {
      final turn = _idle([
        _msg('a1', ChatMessageRole.assistant, at: DateTime(2026, 8, 4, 10, 0)),
        _msg('a2', ChatMessageRole.assistant, at: DateTime(2026, 8, 4, 10, 0, 5)),
        _msg('a3', ChatMessageRole.assistant, at: DateTime(2026, 8, 4, 10, 0, 14)),
      ]).single as AgentTurnEntry;

      expect(turn.duration, const Duration(seconds: 14));
    });

    test('is null without timestamps, so the pill hides the segment', () {
      final turn =
          _idle([_agent('a1'), _agent('a2')]).single as AgentTurnEntry;

      expect(turn.duration, isNull);
    });

    test('is null rather than negative on out-of-order timestamps', () {
      // Clock skew between the server and a cached row would otherwise
      // render "· -3s".
      final turn = _idle([
        _msg('a1', ChatMessageRole.assistant, at: DateTime(2026, 8, 4, 10, 0, 9)),
        _msg('a2', ChatMessageRole.assistant, at: DateTime(2026, 8, 4, 10, 0)),
      ]).single as AgentTurnEntry;

      expect(turn.duration, isNull);
    });
  });

  group('anchors used by the date separator', () {
    test('a turn anchors on its first step and its final reply', () {
      final turn = _idle([_agent('a1'), _agent('a2')]).single;

      expect(turn.firstMessage.id, 'a1');
      expect(turn.lastMessage.id, 'a2');
    });

    test('a single entry anchors on itself both ways', () {
      final entry = _idle([_card('c1')]).single;

      expect(entry.firstMessage.id, 'c1');
      expect(entry.lastMessage.id, 'c1');
    });
  });

  // Observed on a real device, 2026-08-09: a Health Radar report posted into
  // an 11-hour-old conversation was glued to the previous assistant message,
  // and the pill announced `Saqqar thinking · 1 steps · 684m 5s`.
  //
  // The grouper ran on ROLE alone, which was correct while every assistant
  // message followed the turn before it. The §6 tools broke that: they post
  // into an existing conversation whenever the user asks, so "the previous
  // assistant message" can be from yesterday.
  group('a long pause ends the turn', () {
    test('a report posted hours later is its own entry', () {
      final entries = _idle([
        _msg('a1', ChatMessageRole.assistant, at: DateTime(2026, 8, 9, 11, 3)),
        // Health Radar, run by the user this evening.
        _msg('a2', ChatMessageRole.assistant, at: DateTime(2026, 8, 9, 22, 27)),
      ]);

      expect(
        entries, hasLength(2),
        reason: 'an 11-hour gap is a new turn, not eleven hours of thinking',
      );
      expect(entries.first.lastMessage.id, 'a1');
      expect(entries.last.firstMessage.id, 'a2');
    });

    test('a real chain of tool calls still groups', () {
      // The behaviour the pill exists for must survive the fix: seconds
      // apart is one turn.
      final entries = _idle([
        _msg('a1', ChatMessageRole.assistant, at: DateTime(2026, 8, 9, 10, 0)),
        _msg('a2', ChatMessageRole.assistant,
            at: DateTime(2026, 8, 9, 10, 0, 6)),
        _msg('a3', ChatMessageRole.assistant,
            at: DateTime(2026, 8, 9, 10, 0, 21)),
      ]);

      expect(entries, hasLength(1));
      expect(entries.single.lastMessage.id, 'a3');
    });

    test('messages with no timestamps group as before', () {
      // Nothing to measure — falling back to the old behaviour beats
      // splitting every turn in a transcript the server timestamps sparsely.
      final entries = _idle([_agent('a1'), _agent('a2')]);

      expect(entries, hasLength(1));
    });
  });

  // WEB_TO_MOBILE_PARITY_AND_DELETE_FIX.md §B.1 — the web only ever pulls a
  // `tool_payload.kind` message out to stand alone once the run has gone
  // idle. Every group above proves the idle grouping; this one proves the
  // mid-run behaviour reverts to ordinary role-based grouping instead.
  group('idle-only gate (§B.1) — mid-run, a card never stands alone', () {
    test('a card mid-run folds into the surrounding turn like any other '
        'step', () {
      final timeline = buildChatTimeline(
        [_agent('a1'), _card('c1'), _agent('a2')],
        isRunning: true,
      );

      expect(timeline, hasLength(1), reason: 'one collapsed turn, no split');
      final turn = timeline.single as AgentTurnEntry;
      expect(turn.thinkingSteps.map((m) => m.id), ['a1', 'c1']);
      expect(turn.finalReply.id, 'a2');
    });

    test('a card as the sole message is still just a solo bubble, not '
        'forced into AgentTurnEntry shape', () {
      // A run of length 1 never becomes an AgentTurnEntry regardless of the
      // card rule — this pins that the mid-run gate doesn't change that.
      final timeline = buildChatTimeline([_card('c1')], isRunning: true);

      expect(timeline.single, isA<SingleMessageEntry>());
    });

    test('every card kind folds the same way while running', () {
      for (final payload in [
        _clarify,
        _report,
        const {'kind': 'prompt_suggestion', 'improved': 'Clearer'},
      ]) {
        final timeline = buildChatTimeline(
          [_agent('a1'), _card('c1', payload), _agent('a2')],
          isRunning: true,
        );

        expect(timeline, hasLength(1), reason: '${payload['kind']}');
        expect(_ids(timeline.single), ['a1', 'c1', 'a2'],
            reason: '${payload['kind']}');
      }
    });

    test('the exact same transcript splits once idle', () {
      final messages = [_agent('a1'), _card('c1'), _agent('a2')];

      final running = buildChatTimeline(messages, isRunning: true);
      expect(running, hasLength(1));

      final idle = buildChatTimeline(messages, isRunning: false);
      expect(idle, hasLength(3));
      expect(idle[1], isA<SingleMessageEntry>());
    });

    test('no message is dropped or duplicated while running either', () {
      final input = [
        _user('u1'),
        _agent('a1'),
        _card('c1'),
        _user('u2'),
        _agent('a3'),
        _card('c2', _report),
        _agent('a4'),
      ];

      final flattened = buildChatTimeline(input, isRunning: true)
          .expand(_ids)
          .toList();

      expect(flattened, input.map((m) => m.id).toList());
    });
  });
}
