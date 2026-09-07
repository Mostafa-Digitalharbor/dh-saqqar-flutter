// End-to-end: a raw server snapshot → a card the user can tap.
//
// The three unit files next door each cover one stage. This one runs all four
// stages in order, on the JSON the server actually sends, because the defect
// that nearly shipped was not IN any stage — it was BETWEEN them. Every card
// widget test passed while the cards were unreachable, since a widget test
// starts at stage 4 and the message never survived stage 1.
//
//   1. `ConversationSnapshot.fromJson`  — does `tool_payload` decode?
//   2. `isVisibleMessage`               — does the row survive the filter?
//   3. `adaptApiMessage`                — does the payload cross into the UI model?
//   4. `buildChatTimeline` + MessageRow — is the card its own slot, and rendered?
//
// A break anywhere in the chain fails here even if all four unit files still
// pass, which is the whole point of keeping it.

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saqqar_app/core/i18n/app_localizations.dart';
import 'package:saqqar_app/core/i18n/app_strings.dart';
import 'package:saqqar_app/core/theme/app_theme.dart';
import 'package:saqqar_app/features/chat/data/chat_timeline.dart';
import 'package:saqqar_app/features/chat/data/interactive_cards.dart';
import 'package:saqqar_app/features/chat/data/message_adapter.dart';
import 'package:saqqar_app/features/chat/data/message_visibility.dart';
import 'package:saqqar_app/features/chat/widgets/message_row.dart';
import 'package:saqqar_app/features/conversations/data/conversation_models.dart';
import 'package:saqqar_app/features/chat/data/chat_view_models.dart';

/// The clarify payload from Appendix A.1, verbatim.
const _clarifyPayload = {
  'kind': 'prompt_clarify',
  'original': 'build me a report',
  'intro': 'A couple of quick questions before I start 👇',
  'questions': [
    {
      'question': 'Which period?',
      'options': ['This month', 'This quarter', 'This year'],
      'default': 1,
    },
  ],
};

/// A snapshot body shaped like the server's, with the card message carried on
/// whichever [role] / [content] combination the caller wants to prove out.
Map<String, dynamic> _snapshotWithCard({
  required String role,
  required String content,
  Map<String, dynamic> payload = _clarifyPayload,
}) =>
    {
      'conversation': {
        'id': 'c1',
        'title': 'Reports',
        'auto_approve': false,
        'is_running': false,
        'stop_requested': false,
      },
      'messages': [
        {
          'id': 'm1',
          'role': 'user',
          'content': 'build me a report',
          'created_at': '2026-08-04T10:00:00Z',
        },
        {
          'id': 'm2',
          'role': role,
          'content': content,
          'created_at': '2026-08-04T10:00:05Z',
          'tool_payload': payload,
        },
      ],
    };

/// Runs stages 1–3 and returns what the chat list would be handed.
///
/// Filters against the snapshot's OWN `conversation.isRunning` — realistic,
/// since that's exactly what `chat_screen.dart` does — rather than a
/// separate parameter, so every existing fixture (`is_running: false`)
/// keeps its original meaning unchanged.
List<ChatMessage> _pipeline(Map<String, dynamic> body) {
  final snapshot = ConversationSnapshot.fromJson(body);
  final running = snapshot.conversation.isRunning;
  return snapshot.messages
      .where((m) => isVisibleMessage(m, isRunning: running))
      .map((m) => adaptApiMessage(m, time: '10:00'))
      .toList();
}

Future<void> _pumpTimeline(
  WidgetTester tester,
  List<ChatMessage> messages, {
  Locale locale = const Locale('en'),
  required ValueChanged<String> onSend,
  bool isRunning = false,
}) async {
  final timeline = buildChatTimeline(messages, isRunning: isRunning);
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
      home: Scaffold(
        body: SingleChildScrollView(
          child: Column(
            children: [
              // Mirrors the screen: every entry renders, and only a
              // SingleMessageEntry can be a card.
              for (final entry in timeline)
                if (entry is SingleMessageEntry)
                  MessageRow(
                    message: entry.message,
                    isFirstOfGroup: true,
                    isLastOfGroup: true,
                    isRunning: isRunning,
                    onCardSend: onSend,
                  )
                else
                  MessageRow(
                    message: (entry as AgentTurnEntry).finalReply,
                    isFirstOfGroup: true,
                    isLastOfGroup: true,
                    isRunning: isRunning,
                    onCardSend: onSend,
                  ),
            ],
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  final en = AppStrings(const Locale('en'));

  group('the payload survives every stage', () {
    test('decodes off the wire', () {
      final snapshot = ConversationSnapshot.fromJson(
        _snapshotWithCard(role: 'tool', content: ''),
      );

      expect(snapshot.messages.last.toolPayload?['kind'], 'prompt_clarify');
    });

    test('crosses into the UI model', () {
      // Deleting `toolPayload:` from the adapter breaks every card while
      // still compiling and still passing every widget test.
      final adapted = adaptApiMessage(
        Message.fromJson(const {
          'id': 'm2',
          'role': 'tool',
          'content': '',
          'tool_payload': _clarifyPayload,
        }),
        time: '10:00',
      );

      expect(adapted.toolPayload?['kind'], 'prompt_clarify');
      expect(adapted.role, ChatMessageRole.assistant);
    });
  });

  group('every message shape the server might use', () {
    // Appendix A: "the server sends these as `message.tool_payload` on an
    // assistant/tool message". Which of these it actually picks is still an
    // open question with the web team — so all three are pinned.
    const shapes = [
      ('tool role, empty content', 'tool', ''),
      ('assistant role, empty content', 'assistant', ''),
      ('assistant role, with prose', 'assistant', 'Before I start:'),
    ];

    for (final (name, role, content) in shapes) {
      test('$name — reaches the chat list', () {
        final messages = _pipeline(
          _snapshotWithCard(role: role, content: content),
        );

        expect(messages, hasLength(2), reason: 'user turn + the card');
        expect(messages.last.toolPayload?['kind'], 'prompt_clarify');
      });

      testWidgets('$name — renders as a tappable card', (tester) async {
        final sent = <String>[];
        await _pumpTimeline(
          tester,
          _pipeline(_snapshotWithCard(role: role, content: content)),
          onSend: sent.add,
        );

        expect(find.text(en.clarifyTitle), findsOneWidget);
        expect(find.text('This quarter'), findsOneWidget);

        // …and it actually composes and sends. `default: 1` pre-selects
        // "This quarter", so a single tap is enough.
        await tester.tap(find.text(en.clarifyBuildSend));
        await tester.pumpAndSettle();

        expect(
          sent.single,
          '${en.clarifyAnswersHeader}\n- Which period? This quarter',
        );
      });
    }
  });

  group('all three kinds make it through', () {
    const payloads = <String, Map<String, dynamic>>{
      'prompt_clarify': _clarifyPayload,
      'report_builder': {
        'kind': 'report_builder',
        'types': [
          {'key': 'sales_orders', 'label': 'Sales orders'},
        ],
      },
      'prompt_suggestion': {
        'kind': 'prompt_suggestion',
        'improved': 'List unpaid invoices for June.',
      },
    };

    for (final entry in payloads.entries) {
      testWidgets('${entry.key} renders end to end', (tester) async {
        await _pumpTimeline(
          tester,
          _pipeline(_snapshotWithCard(
            role: 'tool',
            content: '',
            payload: entry.value,
          )),
          onSend: (_) {},
        );

        final title = switch (entry.key) {
          'prompt_clarify' => en.clarifyTitle,
          'report_builder' => en.reportTitle,
          _ => en.suggestionTitle,
        };
        expect(find.text(title), findsOneWidget);
      });
    }
  });

  group('the card is not swallowed by a multi-step turn', () {
    /// A real transcript: user asks, agent thinks twice, posts a card, then
    /// keeps working. The card sits mid-run — the exact position that used to
    /// bury it inside the collapsed thinking pill.
    Map<String, dynamic> midRunSnapshot() => {
          'conversation': {
            'id': 'c1',
            'title': 'Reports',
            'auto_approve': false,
            'is_running': false,
            'stop_requested': false,
          },
          'messages': [
            {'id': 'm1', 'role': 'user', 'content': 'build me a report'},
            {'id': 'm2', 'role': 'assistant', 'content': 'Checking Odoo…'},
            {'id': 'm3', 'role': 'assistant', 'content': 'Found 3 models.'},
            {
              'id': 'm4',
              'role': 'tool',
              'content': '',
              'tool_payload': _clarifyPayload,
            },
            {'id': 'm5', 'role': 'assistant', 'content': 'Standing by.'},
          ],
        };

    test('gets its own timeline slot', () {
      final timeline =
          buildChatTimeline(_pipeline(midRunSnapshot()), isRunning: false);

      final cardEntries = timeline
          .whereType<SingleMessageEntry>()
          .where((e) => e.message.id == 'm4');
      expect(cardEntries, hasLength(1));

      // The two thinking steps still collapse — the fix must not have
      // flattened ordinary turns into one bubble each.
      expect(timeline.whereType<AgentTurnEntry>(), hasLength(1));
    });

    testWidgets('and is on screen and tappable', (tester) async {
      final sent = <String>[];
      await _pumpTimeline(tester, _pipeline(midRunSnapshot()), onSend: sent.add);

      expect(find.text(en.clarifyTitle), findsOneWidget);
      await tester.tap(find.text(en.clarifyBuildSend));
      await tester.pumpAndSettle();
      expect(sent, hasLength(1));
    });
  });

  group('non-card plumbing still stays hidden', () {
    test('a tool result is filtered out, card or no card', () {
      final messages = _pipeline({
        'conversation': {
          'id': 'c1',
          'title': 'T',
          'auto_approve': false,
          'is_running': false,
          'stop_requested': false,
        },
        'messages': [
          {'id': 'm1', 'role': 'user', 'content': 'hi'},
          {
            'id': 'm2',
            'role': 'tool',
            'content': '{"rows": 42}',
            'tool_name': 'count_odoo_records',
            'tool_payload': {'model': 'res.partner'},
          },
          {'id': 'm3', 'role': 'assistant', 'content': 'You have 42.'},
        ],
      });

      expect(messages.map((m) => m.id), ['m1', 'm3']);
    });

    test('a malformed card does not become an empty bubble', () {
      final messages = _pipeline(_snapshotWithCard(
        role: 'tool',
        content: '',
        payload: const {'kind': 'prompt_clarify', 'questions': <Object>[]},
      ));

      expect(messages.map((m) => m.id), ['m1']);
    });
  });

  // The backend confirmed the wire shape on 2026-08-09 and flagged one case as
  // critical: `tool_payload` is ALSO present on ordinary assistant messages,
  // carrying `{"tool_calls": [...]}` — internal plumbing, and crucially with
  // **no `kind`**. Rendering that as a card would put an empty interactive
  // widget under a perfectly good answer, on the app's main surface.
  //
  // The rule that covers both directions: a card renders only when
  // `tool_payload.kind` is one this build recognises; everything else is prose.
  group('§Q12 — the confirmed wire shape', () {
    test('assistant + prose + payload is the card shape, and both survive', () {
      // Not an empty-content assistant and not `role:"tool"` — the two shapes
      // the filter is otherwise built to drop.
      final messages = _pipeline(_snapshotWithCard(
        role: 'assistant',
        content: 'A couple of quick questions before I start 👇',
      ));

      expect(messages.map((m) => m.id), ['m1', 'm2']);
      final card = messages.last;
      expect(card.content, 'A couple of quick questions before I start 👇');
      expect(MessageRow.interactiveKindOf(card),
          InteractiveCardKind.promptClarify);
    });

    test('tool_calls with no kind is prose, not a card', () {
      final messages = _pipeline(_snapshotWithCard(
        role: 'assistant',
        content: 'You have 42 partners.',
        payload: const {
          'tool_calls': [
            {'name': 'count_odoo_records', 'args': {'model': 'res.partner'}},
          ],
        },
      ));

      expect(messages.map((m) => m.id), ['m1', 'm2']);
      expect(
        MessageRow.interactiveKindOf(messages.last),
        isNull,
        reason: 'a payload with no `kind` is internal plumbing — rendering it '
            'as a card puts an empty widget under a real answer',
      );
    });

    test('a kind this build does not ship yet leaves the prose alone', () {
      // `odoo_health_radar`, `executive_brief`, `what_if_intro` and `what_if`
      // are live kinds this build has no widget for. The message must still
      // read as the agent's answer rather than vanish — which is what the
      // empty-content assistant rule would otherwise do to it.
      for (final kind in const [
        'odoo_health_radar',
        'executive_brief',
        'what_if_intro',
        'what_if',
      ]) {
        final messages = _pipeline(_snapshotWithCard(
          role: 'assistant',
          content: 'Here is what I found.',
          payload: {'kind': kind, 'sections': const <Object>[]},
        ));

        expect(messages.map((m) => m.id), ['m1', 'm2'], reason: kind);
        expect(MessageRow.interactiveKindOf(messages.last), isNull,
            reason: kind);
      }
    });
  });

  testWidgets('renders end to end in Arabic', (tester) async {
    await _pumpTimeline(
      tester,
      _pipeline(_snapshotWithCard(role: 'tool', content: '')),
      locale: const Locale('ar'),
      onSend: (_) {},
    );

    final ar = AppStrings(const Locale('ar'));
    expect(find.text(ar.clarifyBuildSend), findsOneWidget);
    // The server's own option strings pass through untranslated, as they must.
    expect(find.text('This quarter'), findsOneWidget);
  });

  // WEB_TO_MOBILE_PARITY_AND_DELETE_FIX.md §B.1's other precondition: web
  // renders a `kind` card only for the run's final message once `is_running`
  // is false. All four stages, on a snapshot whose `conversation` really is
  // `is_running: true` — the shape every other test in this file deliberately
  // is NOT (they all set it false), so this is the one place the whole chain
  // is proven end to end for the live-run case.
  group('§B.1 idle-only — a running conversation never shows the card', () {
    Map<String, dynamic> runningSnapshot({
      required String role,
      required String content,
    }) =>
        {
          'conversation': {
            'id': 'c1',
            'title': 'Reports',
            'auto_approve': false,
            'is_running': true,
            'stop_requested': false,
          },
          'messages': [
            {'id': 'm1', 'role': 'user', 'content': 'build me a report'},
            {
              'id': 'm2',
              'role': role,
              'content': content,
              'tool_payload': _clarifyPayload,
            },
          ],
        };

    test('empty-content card message never reaches the chat list while '
        'running', () {
      final messages =
          _pipeline(runningSnapshot(role: 'tool', content: ''));

      expect(messages.map((m) => m.id), ['m1'],
          reason: 'mid-run this is ordinary tool plumbing');
    });

    testWidgets('a card message with prose reaches the screen as prose, '
        'not a tappable card, while running', (tester) async {
      final sent = <String>[];
      await _pumpTimeline(
        tester,
        _pipeline(runningSnapshot(
          role: 'assistant',
          content: 'Before I start, a couple of questions:',
        )),
        onSend: sent.add,
        isRunning: true,
      );

      expect(find.text(en.clarifyTitle), findsNothing,
          reason: 'no card chrome while the run is live');
      expect(find.text('Before I start, a couple of questions:'),
          findsOneWidget);
    });

    testWidgets('the identical payload promotes to a real tappable card '
        'the moment the run goes idle', (tester) async {
      final sent = <String>[];
      await _pumpTimeline(
        tester,
        _pipeline(_snapshotWithCard(
          role: 'assistant',
          content: 'Before I start, a couple of questions:',
        )),
        onSend: sent.add,
        isRunning: false,
      );

      expect(find.text(en.clarifyTitle), findsOneWidget);
      await tester.tap(find.text(en.clarifyBuildSend));
      await tester.pumpAndSettle();
      expect(sent, hasLength(1));
    });
  });
}
