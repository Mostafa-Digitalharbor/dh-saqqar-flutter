// docs/WEB_UI_PARITY_GAPS.md §4 — the three interactive cards, and the
// dispatch that picks them.
//
// The gap these close: a message carrying `tool_payload.kind` used to render
// as a monospace JSON blob with nothing to tap, while a web user got a card to
// choose from. So the assertions here are about what the user can DO —
// selecting a chip, typing an answer, and the exact text that leaves for the
// server as a result.

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saqqar_app/core/i18n/app_localizations.dart';
import 'package:saqqar_app/core/i18n/app_strings.dart';
import 'package:saqqar_app/core/theme/app_theme.dart';
import 'package:saqqar_app/features/chat/data/interactive_cards.dart';
import 'package:saqqar_app/features/chat/widgets/message_row.dart';
import 'package:saqqar_app/features/chat/widgets/report_builder_card.dart';
import 'package:saqqar_app/features/chat/data/chat_view_models.dart';

ChatMessage _toolMessage(Map<String, dynamic>? payload) => ChatMessage(
      id: 'm1',
      role: ChatMessageRole.assistant,
      content: '{"kind":"…"}',
      time: '10:00',
      toolName: 'prompt_tool',
      toolPayload: payload,
    );

Future<void> _pumpRow(
  WidgetTester tester,
  ChatMessage message, {
  Locale locale = const Locale('en'),
  bool dark = false,
  ValueChanged<String>? onSend,
  ValueChanged<String>? onSeed,
  ReportEntityLoader? entityLoader,
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
      theme: dark ? AppTheme.dark(locale) : AppTheme.light(locale),
      home: Scaffold(
        body: SingleChildScrollView(
          child: MessageRow(
            message: message,
            isFirstOfGroup: true,
            isLastOfGroup: true,
            onCardSend: onSend,
            onCardSeed: onSeed,
            entityLoader: entityLoader,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

const _clarifyPayload = {
  'kind': 'prompt_clarify',
  'original': 'build me a report',
  'intro': 'A couple of quick questions before I start',
  'questions': [
    {
      'question': 'Which period?',
      'options': ['This month', 'This quarter'],
      'default': 1,
    },
  ],
};

void main() {
  final en = AppStrings(const Locale('en'));
  final ar = AppStrings(const Locale('ar'));

  group('dispatch', () {
    testWidgets('a card kind outranks the generic tool-activity card',
        (tester) async {
      await _pumpRow(tester, _toolMessage(_clarifyPayload), onSend: (_) {});

      expect(find.text(en.clarifyTitle), findsOneWidget);
      expect(find.text(en.clarifyBuildSend), findsOneWidget);
      // The raw payload must NOT be what the user sees.
      expect(find.text('{"kind":"…"}'), findsNothing);
    });

    testWidgets('an unrecognised payload keeps the ordinary message path',
        (tester) async {
      await _pumpRow(
        tester,
        _toolMessage({'tool_calls': <String>[]}),
        onSend: (_) {},
      );

      expect(find.text(en.clarifyTitle), findsNothing);
      expect(find.text(en.reportTitle), findsNothing);
    });

    testWidgets('an unanswerable card falls through instead of rendering',
        (tester) async {
      // Right `kind`, no questions — nothing to tap, so it must not claim to
      // be a card.
      await _pumpRow(
        tester,
        _toolMessage({'kind': 'prompt_clarify', 'questions': <Object>[]}),
        onSend: (_) {},
      );

      expect(find.text(en.clarifyTitle), findsNothing);
    });

    testWidgets('no send handler → no card (it would be untappable)',
        (tester) async {
      await _pumpRow(tester, _toolMessage(_clarifyPayload));

      expect(find.text(en.clarifyTitle), findsNothing);
    });
  });

  group('prompt_clarify card (§4a)', () {
    testWidgets('composes answers-only text from the smart default',
        (tester) async {
      final sent = <String>[];
      await _pumpRow(tester, _toolMessage(_clarifyPayload), onSend: sent.add);

      // `default: 1` pre-selects "This quarter" — the user taps Build & send
      // without touching anything.
      await tester.tap(find.text(en.clarifyBuildSend));
      await tester.pumpAndSettle();

      expect(sent, hasLength(1));
      expect(
        sent.single,
        '${en.clarifyAnswersHeader}\n- Which period? This quarter',
        reason: 'Appendix A.1: answers only — the original request is '
            'already a message above',
      );
    });

    testWidgets('a tapped chip replaces the pre-selected default',
        (tester) async {
      final sent = <String>[];
      await _pumpRow(tester, _toolMessage(_clarifyPayload), onSend: sent.add);

      await tester.tap(find.text('This month'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(en.clarifyBuildSend));
      await tester.pumpAndSettle();

      expect(sent.single, endsWith('- Which period? This month'));
    });

    testWidgets('free text wins over the chip, and clears it', (tester) async {
      final sent = <String>[];
      await _pumpRow(tester, _toolMessage(_clarifyPayload), onSend: sent.add);

      await tester.enterText(find.byType(TextFormField), 'Last 90 days');
      await tester.pumpAndSettle();
      await tester.tap(find.text(en.clarifyBuildSend));
      await tester.pumpAndSettle();

      expect(sent.single, endsWith('- Which period? Last 90 days'));
    });

    testWidgets('Prepare & review seeds instead of sending', (tester) async {
      final sent = <String>[];
      final seeded = <String>[];
      await _pumpRow(
        tester,
        _toolMessage(_clarifyPayload),
        onSend: sent.add,
        onSeed: seeded.add,
      );

      await tester.tap(find.text(en.clarifyPrepareReview));
      await tester.pumpAndSettle();

      expect(seeded, hasLength(1));
      expect(sent, isEmpty, reason: 'review must not fire a send');
    });

    testWidgets('refuses to send with no answer at all', (tester) async {
      final sent = <String>[];
      await _pumpRow(
        tester,
        _toolMessage({
          'kind': 'prompt_clarify',
          'questions': [
            {
              'question': 'Which period?',
              'options': ['This month'],
            },
          ],
        }),
        onSend: sent.add,
      );

      await tester.tap(find.text(en.clarifyBuildSend));
      await tester.pumpAndSettle();

      expect(sent, isEmpty);
      expect(find.text(en.clarifyNeedsAnswer), findsOneWidget);
    });

    testWidgets('renders the Arabic actions', (tester) async {
      await _pumpRow(
        tester,
        _toolMessage(_clarifyPayload),
        locale: const Locale('ar'),
        onSend: (_) {},
      );

      expect(find.text(ar.clarifyBuildSend), findsOneWidget);
      expect(find.text(ar.clarifyPrepareReview), findsOneWidget);
      expect(ar.clarifyNeedsAnswer, 'اختر إجابة واحدة على الأقل');
    });
  });

  group('prompt_suggestion card (§4c)', () {
    const payload = {
      'kind': 'prompt_suggestion',
      'improved': 'List unpaid customer invoices for June 2026.',
      'note': 'Narrowed to a period.',
    };

    testWidgets('Approve & use sends the text in the field', (tester) async {
      final sent = <String>[];
      await _pumpRow(tester, _toolMessage(payload), onSend: sent.add);

      expect(find.text(en.suggestionTitle), findsOneWidget);
      await tester.tap(find.text(en.suggestionApprove));
      await tester.pumpAndSettle();

      expect(sent, ['List unpaid customer invoices for June 2026.']);
    });

    testWidgets('an edit is what gets sent, not the original suggestion',
        (tester) async {
      final sent = <String>[];
      await _pumpRow(tester, _toolMessage(payload), onSend: sent.add);

      await tester.enterText(find.byType(TextFormField), 'My own wording');
      await tester.pumpAndSettle();
      await tester.tap(find.text(en.suggestionApprove));
      await tester.pumpAndSettle();

      expect(sent, ['My own wording']);
    });

    testWidgets('Keep mine dismisses without sending', (tester) async {
      final sent = <String>[];
      await _pumpRow(tester, _toolMessage(payload), onSend: sent.add);

      await tester.tap(find.text(en.suggestionKeepMine));
      await tester.pumpAndSettle();

      expect(sent, isEmpty);
      expect(find.text(en.suggestionTitle), findsNothing);
    });

    testWidgets('an emptied field disables Approve & use', (tester) async {
      final sent = <String>[];
      await _pumpRow(tester, _toolMessage(payload), onSend: sent.add);

      await tester.enterText(find.byType(TextFormField), '   ');
      await tester.pumpAndSettle();
      await tester.tap(find.text(en.suggestionApprove));
      await tester.pumpAndSettle();

      expect(sent, isEmpty);
    });

    testWidgets('uses the exact Arabic labels the web team gave',
        (tester) async {
      await _pumpRow(
        tester,
        _toolMessage(payload),
        locale: const Locale('ar'),
        onSend: (_) {},
      );

      expect(ar.suggestionApprove, 'اعتمد الصياغة');
      expect(ar.suggestionKeepMine, 'أبقِ صياغتي');
      expect(find.text(ar.suggestionApprove), findsOneWidget);
    });
  });

  group('report_builder card (§4b)', () {
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
          },
        ],
      },
    };

    testWidgets('renders a chip group per dimension', (tester) async {
      await _pumpRow(tester, _toolMessage(payload), onSend: (_) {});

      expect(find.text(en.reportTitle), findsOneWidget);
      expect(find.text(en.reportType), findsOneWidget);
      expect(find.text(en.reportPeriod), findsOneWidget);
      expect(find.text(en.reportFormat), findsOneWidget);
      expect(find.text('Sales orders'), findsOneWidget);
      // Lens chips only appear once a type that has them is picked.
      expect(find.text('By customer'), findsNothing);
    });

    testWidgets('cannot build before a type is picked', (tester) async {
      final sent = <String>[];
      await _pumpRow(tester, _toolMessage(payload), onSend: sent.add);

      await tester.tap(find.text(en.reportBuild));
      await tester.pumpAndSettle();

      expect(sent, isEmpty);
    });

    testWidgets('composes a request from the picked chips', (tester) async {
      final sent = <String>[];
      await _pumpRow(tester, _toolMessage(payload), onSend: sent.add);

      await tester.tap(find.text('Sales orders'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('This month'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('PDF'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(en.reportBuild));
      await tester.pumpAndSettle();

      expect(sent, hasLength(1));
      expect(sent.single, contains('Sales orders'));
      expect(sent.single, contains('This month'));
      expect(sent.single, contains('PDF'));
    });

    testWidgets('picking a type reveals only its own lenses', (tester) async {
      await _pumpRow(tester, _toolMessage(payload), onSend: (_) {});

      await tester.tap(find.text('Customer aging'));
      await tester.pumpAndSettle();

      expect(find.text(en.reportLens), findsOneWidget);
      expect(find.text('By customer'), findsOneWidget);
    });

    testWidgets('a customer-family lens loads records to tick',
        (tester) async {
      final queries = <(String, String)>[];
      await _pumpRow(
        tester,
        _toolMessage(payload),
        onSend: (_) {},
        entityLoader: (entity, query) async {
          queries.add((entity, query));
          return const ReportEntityPage(
            items: [
              ReportEntity(id: '42', name: 'Acme Co'),
              ReportEntity(id: '43', name: 'Globex'),
            ],
          );
        },
      );

      await tester.tap(find.text('Customer aging'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('By customer'));
      await tester.pumpAndSettle();

      expect(
        queries,
        contains(('customers', '')),
        reason: 'the lens entity is what /report-entities/ is asked for',
      );
      expect(find.text('Acme Co'), findsOneWidget);
    });

    testWidgets('ticked records ride along in the composed request',
        (tester) async {
      final sent = <String>[];
      await _pumpRow(
        tester,
        _toolMessage(payload),
        onSend: sent.add,
        entityLoader: (_, __) async => const ReportEntityPage(
          items: [ReportEntity(id: '42', name: 'Acme Co')],
        ),
      );

      await tester.tap(find.text('Customer aging'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('By customer'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Acme Co'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(en.reportBuild));
      await tester.pumpAndSettle();

      expect(sent.single, contains('Acme Co'));
    });

    testWidgets('a truncated page says so instead of looking complete',
        (tester) async {
      await _pumpRow(
        tester,
        _toolMessage(payload),
        onSend: (_) {},
        entityLoader: (_, __) async => const ReportEntityPage(
          items: [ReportEntity(id: '42', name: 'Acme Co')],
          truncated: true,
        ),
      );

      await tester.tap(find.text('Customer aging'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('By customer'));
      await tester.pumpAndSettle();

      expect(find.text(en.reportRecordsTruncated(1)), findsOneWidget);
    });

    testWidgets('no loader → no record picker, but the card still builds',
        (tester) async {
      final sent = <String>[];
      await _pumpRow(tester, _toolMessage(payload), onSend: sent.add);

      await tester.tap(find.text('Customer aging'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('By customer'));
      await tester.pumpAndSettle();

      expect(find.text(en.reportPickRecords), findsNothing);

      await tester.tap(find.text(en.reportBuild));
      await tester.pumpAndSettle();
      expect(sent, hasLength(1));
    });

    testWidgets('the record search re-queries with the typed term',
        (tester) async {
      final queries = <(String, String)>[];
      await _pumpRow(
        tester,
        _toolMessage(payload),
        onSend: (_) {},
        entityLoader: (entity, query) async {
          queries.add((entity, query));
          return ReportEntityPage(
            items: [
              ReportEntity(id: '42', name: query.isEmpty ? 'Acme Co' : 'Globex'),
            ],
            // The server capped the first page; the whole point of the
            // search box is to get past that.
            truncated: query.isEmpty,
          );
        },
      );

      await tester.tap(find.text('Customer aging'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('By customer'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField), 'glob');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();

      expect(queries, [('customers', ''), ('customers', 'glob')]);
      expect(find.text('Globex'), findsOneWidget);
      // The truncation warning clears once the narrowed page is complete.
      expect(find.text(en.reportRecordsTruncated(1)), findsNothing);
    });

    testWidgets('a server-authored submit sentence wins over the template',
        (tester) async {
      final sent = <String>[];
      await _pumpRow(
        tester,
        _toolMessage({
          'kind': 'report_builder',
          'types': [
            {'key': 'aging', 'label': 'Aging'},
          ],
          'lenses': {
            'aging': [
              {
                'key': 'by_customer',
                'label': 'By customer',
                'submit_en': 'Build the customer aging report',
              },
            ],
          },
        }),
        onSend: sent.add,
      );

      await tester.tap(find.text('Aging'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('By customer'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(en.reportBuild));
      await tester.pumpAndSettle();

      expect(sent.single, startsWith('Build the customer aging report'));
    });
  });

  // Behaviours the source comments CLAIM. A comment that says "keyed by id so
  // re-querying never drops a selection" is a promise; until it is a test it
  // is only a promise, and this is exactly the kind of state bug that reaches
  // production because it needs three interactions in the right order.
  group('card state under real interaction sequences', () {
    testWidgets('a ticked record survives a later search', (tester) async {
      final sent = <String>[];
      await _pumpRow(
        tester,
        _toolMessage(const {
          'kind': 'report_builder',
          'types': [
            {'key': 'customers_aging', 'label': 'Customer aging'},
          ],
          'lenses': {
            'customers_aging': [
              {'key': 'by_customer', 'label': 'By customer', 'entity': 'customers'},
            ],
          },
        }),
        onSend: sent.add,
        entityLoader: (_, query) async => ReportEntityPage(
          items: [
            if (query.isEmpty) const ReportEntity(id: '42', name: 'Acme Co'),
            if (query.isNotEmpty) const ReportEntity(id: '43', name: 'Globex'),
          ],
        ),
      );

      await tester.tap(find.text('Customer aging'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('By customer'));
      await tester.pumpAndSettle();

      // Tick Acme, then search for something that does NOT return Acme.
      await tester.tap(find.text('Acme Co'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField), 'glob');
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await tester.pumpAndSettle();

      expect(find.text('Acme Co'), findsNothing, reason: 'off the new page');
      expect(find.text(en.reportSelectedCount(1)), findsOneWidget);

      // Tick Globex too, then build: BOTH must be in the request even though
      // they were never on screen together.
      await tester.tap(find.text('Globex'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(en.reportBuild));
      await tester.pumpAndSettle();

      expect(sent.single, contains('Acme Co'));
      expect(sent.single, contains('Globex'));
    });

    testWidgets('switching to a different entity family clears the ticks',
        (tester) async {
      final sent = <String>[];
      await _pumpRow(
        tester,
        _toolMessage(const {
          'kind': 'report_builder',
          'types': [
            {'key': 'aging', 'label': 'Aging'},
          ],
          'lenses': {
            'aging': [
              {'key': 'by_customer', 'label': 'By customer', 'entity': 'customers'},
              {'key': 'by_vendor', 'label': 'By vendor', 'entity': 'vendors'},
            ],
          },
        }),
        onSend: sent.add,
        entityLoader: (entity, _) async => ReportEntityPage(
          items: [
            ReportEntity(id: '1', name: entity == 'customers' ? 'Acme' : 'Bolt'),
          ],
        ),
      );

      await tester.tap(find.text('Aging'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('By customer'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Acme'));
      await tester.pumpAndSettle();
      expect(find.text(en.reportSelectedCount(1)), findsOneWidget);

      // Vendors are a different family — a customer id carried over would
      // filter the report by a record that isn't in it.
      await tester.tap(find.text('By vendor'));
      await tester.pumpAndSettle();

      expect(find.text(en.reportSelectedCount(1)), findsNothing);
      await tester.tap(find.text(en.reportBuild));
      await tester.pumpAndSettle();
      expect(sent.single, isNot(contains('Acme')));
    });

    testWidgets('a multi-question clarify composes one line per answer',
        (tester) async {
      final sent = <String>[];
      await _pumpRow(
        tester,
        _toolMessage(const {
          'kind': 'prompt_clarify',
          'questions': [
            {
              'question': 'Which period?',
              'options': ['This month', 'This quarter'],
              'default': 0,
            },
            {
              'question': 'Which format?',
              'options': ['PDF', 'Excel'],
            },
            {
              'question': 'Which currency?',
              'options': ['EGP', 'USD'],
            },
          ],
        }),
        onSend: sent.add,
      );

      // Q1 keeps its default, Q2 gets a chip, Q3 gets free text — the mixed
      // case, which is what real use looks like.
      await tester.tap(find.text('Excel'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).last, 'SAR');
      await tester.pumpAndSettle();
      await tester.tap(find.text(en.clarifyBuildSend));
      await tester.pumpAndSettle();

      expect(
        sent.single,
        '${en.clarifyAnswersHeader}\n'
            '- Which period? This month\n'
            '- Which format? Excel\n'
            '- Which currency? SAR',
      );
    });

    testWidgets('an unanswered question is skipped, not sent blank',
        (tester) async {
      final sent = <String>[];
      await _pumpRow(
        tester,
        _toolMessage(const {
          'kind': 'prompt_clarify',
          'questions': [
            {
              'question': 'Which period?',
              'options': ['This month'],
            },
            {
              'question': 'Which format?',
              'options': ['PDF'],
            },
          ],
        }),
        onSend: sent.add,
      );

      await tester.tap(find.text('PDF'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(en.clarifyBuildSend));
      await tester.pumpAndSettle();

      expect(sent.single, '${en.clarifyAnswersHeader}\n- Which format? PDF');
      expect(sent.single, isNot(contains('Which period?')));
    });

    testWidgets('tapping the selected chip again clears that answer',
        (tester) async {
      final sent = <String>[];
      await _pumpRow(tester, _toolMessage(_clarifyPayload), onSend: sent.add);

      // `default: 1` is pre-selected; tapping it deselects, which must leave
      // the card with no answer at all.
      await tester.tap(find.text('This quarter'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(en.clarifyBuildSend));
      await tester.pumpAndSettle();

      expect(sent, isEmpty);
      expect(find.text(en.clarifyNeedsAnswer), findsOneWidget);
    });

    testWidgets('a dismissed suggestion stays dismissed across a rebuild',
        (tester) async {
      await _pumpRow(
        tester,
        _toolMessage(const {
          'kind': 'prompt_suggestion',
          'improved': 'Clearer wording',
        }),
        onSend: (_) {},
      );

      await tester.tap(find.text(en.suggestionKeepMine));
      await tester.pumpAndSettle();
      expect(find.text(en.suggestionTitle), findsNothing);

      // A poll tick rebuilds the chat every 1.5 s. If dismissal lived in a
      // rebuilt-away place, the card would pop back moments after the user
      // dismissed it.
      await tester.pump();
      await tester.pumpAndSettle();
      expect(find.text(en.suggestionTitle), findsNothing);
    });
  });

  // §4 acceptance: "all three are bilingual + RTL and theme-aware". The
  // Arabic tests above prove the copy; these prove the LAYOUT flips and that
  // nothing is hard-coded to a light palette — a card built out of
  // `EdgeInsets.only(left:)` and a literal `Colors.white` passes every
  // string assertion and still ships broken to half the users.
  group('RTL and dark theme', () {
    const payloads = <String, Map<String, dynamic>>{
      'clarify': _clarifyPayload,
      'suggestion': {
        'kind': 'prompt_suggestion',
        'improved': 'Clearer wording',
      },
      'report': {
        'kind': 'report_builder',
        'types': [
          {'key': 'sales_orders', 'label': 'Sales orders'},
        ],
      },
    };

    testWidgets('every card lays out RTL under the ar locale', (tester) async {
      for (final entry in payloads.entries) {
        await _pumpRow(
          tester,
          _toolMessage(entry.value),
          locale: const Locale('ar'),
          onSend: (_) {},
        );

        expect(
          Directionality.of(tester.element(find.byType(MessageRow))),
          TextDirection.rtl,
          reason: '${entry.key} card',
        );
        expect(tester.takeException(), isNull, reason: '${entry.key} card');
      }
    });

    testWidgets('every card renders in dark theme', (tester) async {
      for (final entry in payloads.entries) {
        await _pumpRow(
          tester,
          _toolMessage(entry.value),
          dark: true,
          onSend: (_) {},
        );

        expect(tester.takeException(), isNull, reason: '${entry.key} card');
      }
    });

    testWidgets('every card fits a 320 px viewport in Arabic', (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      for (final entry in payloads.entries) {
        await _pumpRow(
          tester,
          _toolMessage(entry.value),
          locale: const Locale('ar'),
          onSend: (_) {},
        );

        expect(tester.takeException(), isNull, reason: '${entry.key} card');
      }
    });
  });
}
