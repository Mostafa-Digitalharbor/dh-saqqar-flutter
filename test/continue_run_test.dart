// The one-tap "Continue" under a reply that stopped at the tool-round ceiling.
//
// Found in the full web-vs-mobile sweep. When a run exhausts the agent's
// allowance of tool rounds it stops and says so, and the server flags the last
// message with `tool_payload.continue_available`. The web puts a Continue
// button under it; mobile had nothing, so the only way forward on a phone was
// to type something and hope the agent read it as "keep going".
//
// It is NOT the resume banner (MOBILE_TASKS_2026-09.md Task 2). That one is for
// a run that stopped saying nothing at all and is driven by a field on the
// CONVERSATION; this is driven by a field on a MESSAGE, and the run already
// explained itself. Both can be false, and only one of them is ever true.

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saqqar_app/core/i18n/app_localizations.dart';
import 'package:saqqar_app/core/theme/app_theme.dart';
import 'package:saqqar_app/features/chat/data/chat_view_models.dart';
import 'package:saqqar_app/features/chat/widgets/continue_run_button.dart';
import 'package:saqqar_app/features/chat/widgets/message_row.dart';

ChatMessage _reply({
  Object? continueAvailable = true,
  String content = 'I stopped after a lot of steps.',
}) =>
    ChatMessage(
      id: 'm1',
      role: ChatMessageRole.assistant,
      content: content,
      time: '10:00',
      toolPayload: continueAvailable == null
          ? null
          : {'continue_available': continueAvailable},
    );

Future<List<String>> _pump(
  WidgetTester tester,
  ChatMessage message, {
  bool isLatestAssistant = true,
  bool isRunning = false,
  bool withHandler = true,
  Locale locale = const Locale('en'),
}) async {
  final sent = <String>[];
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
          child: MessageRow(
            message: message,
            isFirstOfGroup: true,
            isLastOfGroup: true,
            isRunning: isRunning,
            isLatestAssistant: isLatestAssistant,
            onCardSend: withHandler ? sent.add : null,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return sent;
}

void main() {
  final en = AppStrings(const Locale('en'));
  final ar = AppStrings(const Locale('ar'));

  group('when the button appears', () {
    testWidgets('the newest reply, idle, with the server flag set',
        (tester) async {
      await _pump(tester, _reply());

      expect(find.byType(ContinueRunButton), findsOneWidget);
      expect(find.text(en.continueRun), findsOneWidget);
    });

    testWidgets('never on an older reply', (tester) async {
      // A button halfway up the transcript would offer to continue a run that
      // finished hours ago.
      await _pump(tester, _reply(), isLatestAssistant: false);

      expect(find.byType(ContinueRunButton), findsNothing);
    });

    testWidgets('never while the agent is still working', (tester) async {
      await _pump(tester, _reply(), isRunning: true);

      expect(find.byType(ContinueRunButton), findsNothing);
    });

    testWidgets('never without the server flag', (tester) async {
      // Absent payload, absent key, explicit false, and the shapes a
      // forward-compatible server might send instead of a bool. Only a real
      // `true` counts — a truthy string must not light up a button that
      // sends a message on the user's behalf.
      for (final value in <Object?>[
        null,
        false,
        'true',
        1,
        <String, dynamic>{},
      ]) {
        await _pump(tester, _reply(continueAvailable: value));
        expect(find.byType(ContinueRunButton), findsNothing,
            reason: 'continue_available=$value');
      }

      await _pump(
        tester,
        const ChatMessage(
          id: 'm1',
          role: ChatMessageRole.assistant,
          content: 'hi',
          time: '10:00',
          toolPayload: {'something_else': true},
        ),
      );
      expect(find.byType(ContinueRunButton), findsNothing);
    });

    testWidgets('never on a user message', (tester) async {
      await _pump(
        tester,
        const ChatMessage(
          id: 'm1',
          role: ChatMessageRole.user,
          content: 'do the thing',
          time: '10:00',
          toolPayload: {'continue_available': true},
        ),
      );

      expect(find.byType(ContinueRunButton), findsNothing);
    });

    testWidgets('never on a surface with nowhere to send', (tester) async {
      // A button that cannot do anything is worse than no button.
      await _pump(tester, _reply(), withHandler: false);

      expect(find.byType(ContinueRunButton), findsNothing);
    });
  });

  group('what the tap does', () {
    testWidgets('sends the exact sentence the web sends', (tester) async {
      final sent = await _pump(tester, _reply());

      await tester.tap(find.text(en.continueRun));
      await tester.pumpAndSettle();

      expect(sent, [en.continueRunMessage]);
      expect(sent.single, 'Continue from where you stopped.');
    });

    testWidgets('and its Arabic counterpart under an Arabic locale',
        (tester) async {
      final sent = await _pump(tester, _reply(), locale: const Locale('ar'));

      expect(find.text(ar.continueRun), findsOneWidget);
      await tester.tap(find.text(ar.continueRun));
      await tester.pumpAndSettle();

      expect(sent, [ar.continueRunMessage]);
      // The English sentence must not leak into an Arabic conversation — the
      // message is sent TO the agent, which answers in the language it is
      // asked in.
      expect(sent.single, isNot(en.continueRunMessage));
    });

    testWidgets('twice in a row still sends once', (tester) async {
      // Sending sets the conversation running, which removes the button — but
      // that is a network round-trip away, and a double tap inside that
      // window would ask the agent to continue twice.
      final sent = await _pump(tester, _reply());

      await tester.tap(find.text(en.continueRun));
      await tester.pump();
      await tester.tap(find.text(en.continueRun), warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(sent, hasLength(1));
    });

    testWidgets('the reply itself is still readable next to it',
        (tester) async {
      // The button is added below the bubble, not in place of it.
      await _pump(tester, _reply(content: 'Here is how far I got.'));

      expect(find.textContaining('Here is how far I got.'), findsOneWidget);
      expect(find.byType(ContinueRunButton), findsOneWidget);
    });
  });
}
