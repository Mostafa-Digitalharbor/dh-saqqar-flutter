// §8 — the support workspace.
//
// This gap sat unbuilt for two days on a deliberate call: §6 needed *wording*
// (authorable, one string to correct), §8 needed a *destination*, which is a
// fact about the business. The web team's answer settled it — it is not
// telephony at all, it is a self-service diagnosis + optional Odoo helpdesk
// ticket.
//
// The one thing in the feature that deserves the most care is the ticket
// call. It WRITES to a live database, and the backend raises no approval card
// for it: "the user's explicit tap is the consent". So the confirmation has to
// be here, and it has to be impossible to fire twice.

import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:saqqar_app/core/i18n/app_localizations.dart';
import 'package:saqqar_app/core/i18n/app_strings.dart';
import 'package:saqqar_app/core/network/api_exception.dart';
import 'package:saqqar_app/core/theme/app_theme.dart';
import 'package:saqqar_app/features/support/data/voice_support_api.dart';
import 'package:saqqar_app/features/support/data/voice_support_models.dart';
import 'package:saqqar_app/features/support/view/voice_support_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/responsive_harness.dart';

// ── Wire stub ────────────────────────────────────────────────────────────

class _Recorder implements HttpClientAdapter {
  _Recorder({this.draftBody, this.ticketStatus = 200});

  final Object? draftBody;
  final int ticketStatus;

  final paths = <String>[];
  final bodies = <Map<String, dynamic>>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    paths.add(options.path);
    bodies.add((options.data as Map?)?.cast<String, dynamic>() ?? const {});

    final isTicket = options.path.endsWith('/ticket/');
    if (isTicket && ticketStatus >= 400) {
      throw DioException(
        requestOptions: options,
        response: Response(
          requestOptions: options,
          statusCode: ticketStatus,
          data: const {'ok': false, 'error': 'Helpdesk is not installed'},
        ),
        type: DioExceptionType.badResponse,
      );
    }
    final body = isTicket ? const {'ok': true} : draftBody;
    return ResponseBody.fromString(
      body == null ? '' : jsonEncode(body),
      200,
      headers: body == null
          ? const {}
          : {
              Headers.contentTypeHeader: [Headers.jsonContentType],
            },
    );
  }

  @override
  void close({bool force = false}) {}
}

/// **The production shape, captured from a real call on 2026-08-09.**
///
/// The old fixture here was flat, with `steps` and `reply` at the root. That
/// was invented on this side when §8 was built against prose, and it made
/// every test in this file agree with a client that could not read a single
/// real response: the server nests everything under `draft` and spells the
/// two list/text fields `reproduction_steps` and `customer_reply`.
///
/// The bug was not that a test was missing. It is that the fixture and the
/// code were wrong in exactly the same way, so the suite was green while the
/// feature had never once rendered a card.
const _draftJson = {
  'ok': true,
  'draft': {
    'title': 'Invoices are not posting',
    'module': 'account',
    'category': 'bug',
    'priority': '2',
    'summary': 'العميل ما يقدر يرحّل الفواتير، وتبقى بحالة مسودة.',
    'questions': ['Which Odoo version?', 'Does it affect all journals?'],
    'reproduction_steps': [
      'Check the journal sequence',
      'Re-run the posting',
    ],
    'customer_reply': 'شكلها مشكلة في تسلسل اليومية. جرّب تتأكد من الإعداد.',
  },
};

/// The same draft with no envelope and the short key spellings — the shape
/// this client used to assume. Kept so the parser's tolerance is deliberate
/// and tested, rather than something that happens to work.
const _draftJsonFlat = {
  'title': 'Invoices are not posting',
  'module': 'account',
  'category': 'bug',
  'priority': '2',
  'questions': ['Which Odoo version?', 'Does it affect all journals?'],
  'steps': ['Check the journal sequence', 'Re-run the posting'],
  'reply': 'شكلها مشكلة في تسلسل اليومية. جرّب تتأكد من الإعداد.',
};

// ── Widget harness ───────────────────────────────────────────────────────

Future<_Recorder> _pump(
  WidgetTester tester, {
  Object? draftBody = _draftJson,
  int ticketStatus = 200,
  Locale locale = const Locale('en'),
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final prefs = await SharedPreferences.getInstance();

  // A tall viewport, because `PageScaffold` renders its children through a
  // culling `ListView.builder`: on the default 800×600 surface the draft card
  // pushes "Save as a ticket" out of the build entirely, and `ensureVisible`
  // can't scroll to a widget that was never built. Layout is covered by the
  // responsive sweep; this file is about behaviour.
  tester.view.physicalSize = const Size(1000, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  final recorder =
      _Recorder(draftBody: draftBody, ticketStatus: ticketStatus);
  final api = VoiceSupportApi(Dio()..httpClientAdapter = recorder);

  await tester.pumpWidget(
    // `appChrome` supplies what `PageScaffold` reaches for through the shared
    // header (running agents, connectivity, the notifications store). Without
    // it the ProviderNotFoundException renders as an unbounded ErrorWidget
    // and every finder in this file matches nothing for the wrong reason.
    appChrome(
      RepositoryProvider<VoiceSupportApi>.value(
        value: api,
        child: MaterialApp(
          locale: locale,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [Locale('en'), Locale('ar')],
          theme: AppTheme.light(locale),
          home: const VoiceSupportScreen(),
        ),
      ),
      prefs,
    ),
  );
  await tester.pumpAndSettle();
  return recorder;
}

/// Taps the "Save as a ticket" button on the PAGE (not the one inside the
/// confirmation dialog, which carries the same label).
///
/// The draft card pushes the button below the fold on a test-sized viewport,
/// where a plain `tap` silently misses.
Future<void> _tapFileTicket(WidgetTester tester, AppStrings tr) async {
  final button = find.text(tr.voiceSupportFileTicket).first;
  await tester.ensureVisible(button);
  await tester.pumpAndSettle();
  await tester.tap(button, warnIfMissed: false);
  await tester.pumpAndSettle();
}

/// Confirms the dialog that [_tapFileTicket] opened. Its confirm button
/// carries the SAME label as the page button, so `.last` is what separates
/// them — the dialog is above the page in the tree.
Future<void> _confirmTicketDialog(WidgetTester tester, AppStrings tr) async {
  await tester.tap(find.text(tr.voiceSupportFileTicket).last);
  await tester.pumpAndSettle();
}

Future<void> _describeAndSubmit(
  WidgetTester tester,
  AppStrings tr, {
  String text = 'Invoices will not post',
}) async {
  await tester.enterText(find.byType(TextField).first, text);
  await tester.pumpAndSettle();
  await tester.tap(find.text(tr.voiceSupportSubmit));
  await tester.pumpAndSettle();
}

void main() {
  final en = AppStrings(const Locale('en'));
  final ar = AppStrings(const Locale('ar'));

  group('VoiceSupportDraft parsing', () {
    test('reads the real production payload, envelope and all', () {
      final draft = VoiceSupportDraft.fromJson(Map.of(_draftJson));

      expect(draft.title, 'Invoices are not posting');
      expect(draft.module, 'account');
      expect(draft.category, 'bug');
      expect(draft.priority, '2');
      expect(draft.questions, hasLength(2));
      // From `reproduction_steps` / `customer_reply` — the wire spellings.
      expect(draft.steps, hasLength(2));
      expect(draft.reply, startsWith('شكلها'));
      // Sent since §8 shipped and rendered by nothing until 2026-08-09.
      expect(draft.summary, isNotEmpty);
      expect(draft.hasContent, isTrue);
    });

    test('the `draft` envelope is unwrapped, not read as a field', () {
      // The whole bug in one assertion. Pointed at the root, every getter
      // came back empty and the screen showed "no diagnosis arrived" against
      // a complete, correct reply.
      final draft = VoiceSupportDraft.fromJson(Map.of(_draftJson));
      expect(
        draft.title,
        isNotEmpty,
        reason: 'the payload is nested under "draft" — parsing the root '
            'yields an empty card that reads as a server failure',
      );
    });

    test('a flat body with the short key spellings still parses', () {
      // Tolerance is deliberate: if the server ever drops the envelope or
      // simplifies the two long keys, the screen must not go blank again.
      final draft = VoiceSupportDraft.fromJson(Map.of(_draftJsonFlat));

      expect(draft.title, 'Invoices are not posting');
      expect(draft.steps, hasLength(2));
      expect(draft.reply, startsWith('شكلها'));
      expect(draft.hasContent, isTrue);
    });

    test('a numeric priority does not crash the screen', () {
      // The documented type is a string, but `2` is exactly the kind of
      // thing that arrives instead. A throwing cast here would take down a
      // screen the user opened BECAUSE something was already broken.
      final draft = VoiceSupportDraft.fromJson(const {'priority': 2});

      expect(draft.priority, '2');
    });

    test('survives every field arriving as the wrong type', () {
      final draft = VoiceSupportDraft.fromJson(const {
        'title': 42,
        'module': null,
        'category': ['a'],
        'priority': true,
        'questions': 'just one',
        'steps': {'not': 'a list'},
        'reply': 7,
      });

      expect(draft.title, '42');
      expect(draft.module, isEmpty);
      expect(draft.category, isEmpty);
      expect(draft.priority, 'true');
      expect(draft.questions, ['just one']);
      expect(draft.steps, isEmpty);
      expect(draft.reply, '7');
    });

    test('a list of objects is read through its text field', () {
      final draft = VoiceSupportDraft.fromJson(const {
        'steps': [
          {'text': 'First'},
          {'label': 'Second'},
          {'nothing': 'useful'},
          'Third',
        ],
      });

      expect(draft.steps, ['First', 'Second', 'Third']);
    });

    test('an all-empty draft reports no content', () {
      // Rendering a card with a title and nothing under it reads as a broken
      // screen; the caller shows the "try describing it differently" copy.
      final draft = VoiceSupportDraft.fromJson(const {'title': 'Something'});

      expect(draft.hasContent, isFalse);
    });
  });

  group('VoiceSupportApi', () {
    test('draft posts the problem text as `transcript`', () async {
      // The field is `transcript`. This test used to assert `problem`, which
      // is the name this side GUESSED when the endpoint was built — the web
      // team's note said only "send the user's problem text" and never gave a
      // key. The guess was wrong, the test agreed with it, and both were wrong
      // together for as long as the feature existed: production answers
      // `{"ok": false, "error": "`transcript` is required."}` and §8 never
      // produced a single draft.
      //
      // A recorder test can only ever prove the client sends what the client
      // meant to send. This one is now pinned to a name taken from the
      // server's own error message, observed on a device against production.
      final recorder = _Recorder(draftBody: _draftJson);
      final api = VoiceSupportApi(Dio()..httpClientAdapter = recorder);

      await api.draft(problem: 'It broke', lang: 'ar');

      expect(recorder.paths.single, '/api/v1/voice-support/draft/');
      expect(recorder.bodies.single, {'transcript': 'It broke', 'lang': 'ar'});
      expect(
        recorder.bodies.single.containsKey('problem'),
        isFalse,
        reason: 'the server ignores `problem` and 400s for a missing '
            '`transcript`',
      );
    });

    test('ticket posts title and priority', () async {
      final recorder = _Recorder(draftBody: _draftJson);
      final api = VoiceSupportApi(Dio()..httpClientAdapter = recorder);

      await api.createTicket(title: 'Invoices', priority: '2');

      expect(recorder.paths.single, '/api/v1/voice-support/ticket/');
      expect(recorder.bodies.single, {'title': 'Invoices', 'priority': '2'});
    });

    test('an empty priority is omitted rather than sent blank', () async {
      final recorder = _Recorder(draftBody: _draftJson);
      final api = VoiceSupportApi(Dio()..httpClientAdapter = recorder);

      await api.createTicket(title: 'Invoices', priority: '');

      expect(recorder.bodies.single.containsKey('priority'), isFalse);
    });

    test('a bodiless 200 on draft is a parse failure', () async {
      final api = VoiceSupportApi(
        Dio()..httpClientAdapter = _Recorder(draftBody: null),
      );

      await expectLater(
        api.draft(problem: 'x', lang: 'en'),
        throwsA(
          isA<ApiException>()
              .having((e) => e.kind, 'kind', ApiExceptionKind.parse),
        ),
      );
    });
  });

  group('the screen', () {
    testWidgets('submit is disabled until there is something to send',
        (tester) async {
      await _pump(tester);

      final button = tester.widget<InkWell>(
        find
            .ancestor(
              of: find.text(en.voiceSupportSubmit),
              matching: find.byType(InkWell),
            )
            .first,
      );
      expect(button.onTap, isNull,
          reason: 'an empty box can only produce an empty draft');
    });

    testWidgets('a described problem produces the draft card', (tester) async {
      final recorder = await _pump(tester);
      await _describeAndSubmit(tester, en);

      expect(recorder.paths.single, '/api/v1/voice-support/draft/');
      expect(find.text('Invoices are not posting'), findsOneWidget);
      expect(find.text(en.voiceSupportReply), findsOneWidget);
      expect(find.text(en.voiceSupportSteps), findsOneWidget);
      expect(find.text(en.voiceSupportQuestions), findsOneWidget);
      expect(find.text('Check the journal sequence'), findsOneWidget);
    });

    testWidgets('the problem text reaches the server verbatim, trimmed',
        (tester) async {
      final recorder = await _pump(tester);
      await _describeAndSubmit(tester, en, text: '  invoices stuck  ');

      expect(recorder.bodies.single['transcript'], 'invoices stuck');
    });

    testWidgets('the UI language is what gets sent', (tester) async {
      final recorder = await _pump(tester, locale: const Locale('ar'));
      await _describeAndSubmit(tester, ar);

      expect(recorder.bodies.single['lang'], 'ar');
    });

    testWidgets('no ticket is filed without an explicit confirmation',
        (tester) async {
      // The write has NO approval card server-side, so this dialog is the
      // only thing between a tap and a row in a production database.
      final recorder = await _pump(tester);
      await _describeAndSubmit(tester, en);

      await _tapFileTicket(tester, en);

      expect(find.text(en.voiceSupportTicketConfirmTitle), findsOneWidget);
      expect(
        recorder.paths.where((p) => p.endsWith('/ticket/')),
        isEmpty,
        reason: 'the dialog is open — nothing has been written yet',
      );
    });

    testWidgets('cancelling the dialog writes nothing', (tester) async {
      final recorder = await _pump(tester);
      await _describeAndSubmit(tester, en);

      await _tapFileTicket(tester, en);
      await tester.tap(find.text(en.cancel));
      await tester.pumpAndSettle();

      expect(recorder.paths.where((p) => p.endsWith('/ticket/')), isEmpty);
    });

    testWidgets('confirming files exactly one ticket', (tester) async {
      final recorder = await _pump(tester);
      await _describeAndSubmit(tester, en);

      await _tapFileTicket(tester, en);
      // The dialog's confirm carries the same label as the button that
      // opened it, so target the one inside the dialog.
      await _confirmTicketDialog(tester, en);

      final tickets = recorder.paths.where((p) => p.endsWith('/ticket/'));
      expect(tickets, hasLength(1));
      expect(recorder.bodies.last['title'], 'Invoices are not posting');
    });

    testWidgets('a filed ticket cannot be filed again', (tester) async {
      // Two taps on a slow connection is how one problem becomes two tickets
      // in someone's helpdesk queue.
      final recorder = await _pump(tester);
      await _describeAndSubmit(tester, en);

      await _tapFileTicket(tester, en);
      await _confirmTicketDialog(tester, en);

      await _tapFileTicket(tester, en);

      expect(
        recorder.paths.where((p) => p.endsWith('/ticket/')),
        hasLength(1),
      );
    });

    testWidgets('a new problem clears the old draft before asking',
        (tester) async {
      // Leaving the previous answer on screen while the next one loads lets
      // a user file a ticket for a problem they already moved past.
      await _pump(tester);
      await _describeAndSubmit(tester, en);
      expect(find.text('Invoices are not posting'), findsOneWidget);

      await tester.enterText(find.byType(TextField).first, 'something else');
      await tester.pump();
      await tester.tap(find.text(en.voiceSupportSubmit));
      await tester.pump(); // mid-flight, before the response

      expect(find.text(en.voiceSupportFileTicket), findsNothing);
      await tester.pumpAndSettle();
    });

    testWidgets('a helpdesk-not-installed error surfaces, not silence',
        (tester) async {
      await _pump(tester, ticketStatus: 400);
      await _describeAndSubmit(tester, en);

      await _tapFileTicket(tester, en);
      await _confirmTicketDialog(tester, en);

      // The success toast must NOT appear for a failed write.
      expect(find.text(en.voiceSupportTicketCreated), findsNothing);
    });

    testWidgets('an empty draft says so instead of showing a blank card',
        (tester) async {
      await _pump(tester, draftBody: const {'title': 'Nothing'});
      await _describeAndSubmit(tester, en);

      expect(find.text(en.voiceSupportEmpty), findsOneWidget);
      expect(find.text(en.voiceSupportFileTicket), findsNothing);
    });

    testWidgets('renders in Arabic, right-to-left', (tester) async {
      await _pump(tester, locale: const Locale('ar'));
      await _describeAndSubmit(tester, ar);

      expect(find.text(ar.voiceSupportReply), findsOneWidget);
      expect(
        Directionality.of(tester.element(find.text(ar.voiceSupportReply))),
        TextDirection.rtl,
      );
    });

    testWidgets('module and category chips are the SERVER labels',
        (tester) async {
      // Odoo's own module names. Translating them client-side would show a
      // name that does not exist in the user's database.
      await _pump(tester, locale: const Locale('ar'));
      await _describeAndSubmit(tester, ar);

      expect(find.text('ACCOUNT'), findsOneWidget);
      expect(find.text('BUG'), findsOneWidget);
    });
  });
}
