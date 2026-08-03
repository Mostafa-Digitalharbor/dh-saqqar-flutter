// What the conversations list is allowed to show as a chat's summary line.
//
// `last_message_preview` is whatever the last message contained, verbatim.
// Most of the time that's prose. But the newest row in a chat is very often
// not prose at all — it's a tool call, and while an agent is mid-run it stays
// that way for the whole run. Rendering it raw puts the model's own plumbing
// where the user expects a summary of their conversation.
//
// Two shapes have been caught doing this in production:
//
//   * JSON envelopes — `{"status": "approval_required", …}`.
//   * Model control tokens — `<｜｜DSML｜tool_calls｜>…`, where the bars are
//     U+FF5C FULLWIDTH VERTICAL LINE rather than ASCII `|`. Found on a live
//     1,451-message chat whose card read exactly that for the whole run.
//
// The detection is deliberately narrow in both cases: it is much worse to
// blank a message a user actually wrote than to let one payload through, so
// every rule here keys on something that cannot occur in ordinary prose.

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saqqar_app/core/i18n/app_localizations.dart';
import 'package:saqqar_app/core/theme/app_theme.dart';
import 'package:saqqar_app/features/chat/view_model/running_agents_cubit.dart';
import 'package:saqqar_app/features/conversations/data/conversation_models.dart';
import 'package:saqqar_app/features/conversations/data/conversations_repository.dart';
import 'package:saqqar_app/features/conversations/view_model/conversations_cubit.dart';
import 'package:saqqar_app/features/conversations/widgets/conversation_card.dart';

/// The card reads its pinned flag from the cubit, so one has to be in scope.
/// It is never driven here.
class _InertRepo implements ConversationsRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

ConversationSummary _summary(String preview) => ConversationSummary(
      id: 'c1',
      title: 'Q3 ledger close',
      createdAt: DateTime.utc(2026, 7, 25, 9),
      updatedAt: DateTime.utc(2026, 7, 25, 10),
      isArchived: false,
      messageCount: 24,
      lastMessagePreview: preview,
      // Load-bearing: a running chat replaces the preview line with the
      // "Saqqar is working" indicator, which would hide what we're testing.
      isRunning: false,
    );

Future<void> _pump(WidgetTester tester, String preview) async {
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en'), Locale('ar')],
      theme: AppTheme.light(const Locale('en')),
      home: Scaffold(
        body: MultiBlocProvider(
          providers: [
            BlocProvider(
              create: (_) => ConversationsCubit(repository: _InertRepo()),
            ),
            BlocProvider(create: (_) => RunningAgentsCubit()),
          ],
          child: ConversationCard(
            conversation: _summary(preview),
            onTap: () {},
            onAction: (_) {},
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  group('machine payloads never reach the summary line', () {
    testWidgets('model control-token envelope is replaced', (tester) async {
      // The exact bytes read off the device: U+003C then two U+FF5C, `DSML`,
      // another U+FF5C. Written with escapes so the intent survives an editor
      // that would happily normalise the fullwidth bars to ASCII.
      const payload = '<｜｜DSML｜tool_calls｜>'
          '{"name": "odoo.search_read"}';
      await _pump(tester, payload);

      expect(find.textContaining('DSML'), findsNothing);
      expect(find.textContaining('tool_calls'), findsNothing);
      expect(find.textContaining('｜'), findsNothing);
    });

    testWidgets('JSON envelope is replaced', (tester) async {
      await _pump(tester, '{"status": "approval_required", "app": "sale"}');
      expect(find.textContaining('approval_required'), findsNothing);
    });
  });

  group('the user\'s own words are left alone', () {
    testWidgets('Arabic prose survives', (tester) async {
      const prose = 'تمام، فهمت. خليني أوضح لك الفرق بين الحسابين';
      await _pump(tester, prose);
      expect(find.text(prose), findsOneWidget);
    });

    testWidgets('prose that merely mentions a brace survives', (tester) async {
      // The narrowness that matters: a message about JSON is not JSON.
      const prose = 'The export uses { as its delimiter, is that expected?';
      await _pump(tester, prose);
      expect(find.text(prose), findsOneWidget);
    });

    testWidgets('a comparison opening with < survives', (tester) async {
      // Opens with `<` like the control-token envelope does, but carries no
      // fullwidth bar — so it is prose, and blanking it would be the worse
      // failure of the two.
      const prose = '< 30 days overdue should not trigger the dunning letter';
      await _pump(tester, prose);
      expect(find.text(prose), findsOneWidget);
    });
  });
}
