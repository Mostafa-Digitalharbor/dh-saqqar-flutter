// The destructive-delete outage, and the button that replaces the typed gate.
//
// Reported in `docs/updates/WEB_TO_MOBILE_PARITY_AND_DELETE_FIX.md` Part A: a
// user typed the exactly-correct phrase `delete 12` into the chat composer
// dozens of times and the approval never resolved. It could not have: a
// composer message goes to the send endpoint, never to
// `/approvals/<id>/decision/`.
//
// The root cause underneath that is narrower and worse than "no input field".
// Mobile HAD a type-to-confirm dialog, and the phrase the user typed into it
// was matched, accepted — and then thrown away, because `ApprovalsApi.decide`
// had no `confirm_phrase` parameter and posted `{approved: true}`. The backend
// gate (`views.py:approval_decision`) refuses a bare approve on a destructive
// delete with HTTP 400. So the dialog was pure friction in front of a call that
// could never succeed, and no amount of typing anywhere could resolve a delete
// from this app.
//
// The fix (web shipped the same design on 2026-08-17, commit `c0653a5`) is to
// stop making the user reproduce a string the server already sent us: one red
// "Delete N" button that echoes `confirm_phrase` back verbatim.
//
// These tests are ordered as the bug was: the wire call first, because that is
// the half that was actually broken.

import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:saqqar_app/core/i18n/app_localizations.dart';
import 'package:saqqar_app/core/theme/app_theme.dart';
import 'package:saqqar_app/features/chat/widgets/chat_approval_card.dart';
import 'package:saqqar_app/features/chat/widgets/chat_markdown.dart';
import 'package:saqqar_app/features/demo/saqqar_demo_data.dart';
import 'package:saqqar_app/features/inbox/data/approval_models.dart';
import 'package:saqqar_app/features/inbox/data/approvals_api.dart';

/// Captures the decision POST so the body can be asserted on.
class _CapturingAdapter implements HttpClientAdapter {
  Map<String, dynamic>? body;
  String? path;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    path = options.path;
    body = (options.data as Map).cast<String, dynamic>();
    return ResponseBody.fromString(
      '{"ok":true,"approval":{"id":"9ba6585a","action_type":"odoo_write",'
      '"status":"approved"}}',
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

/// The real `9ba6585a` object from the reported conversation, as inlined in
/// the report's §A.6 — kept verbatim so the parse is tested against the wire
/// shape rather than against a fixture someone wrote to match the parser.
Map<String, dynamic> get _deleteApprovalJson => <String, dynamic>{
      'id': '9ba6585a-841a-48a2-a85a-2cc8994a3a35',
      'action_type': 'odoo_write',
      'status': 'pending',
      'prompt': 'حذف 12 سجل من Sales Order Line',
      'model_label': {'ar': 'Sales Order Line', 'en': 'Sales Order Line'},
      'record_count': 12,
      'confirm_phrase': 'delete 12',
      'confirm_word': 'delete',
      'payload': {
        'model': 'sale.order.line',
        'operation': 'delete',
        'record_count': 12,
        'records': [
          {'id': 6108, 'name': 'SO001/1'},
          {'id': 6109, 'name': 'SO001/2'},
        ],
        'record_ids': [6108, 6109, 6110],
        'model_label': {'ar': 'Sales Order Line', 'en': 'Sales Order Line'},
      },
    };

void main() {
  _linkResolverTests();

  group('the wire call — the half that was actually broken', () {
    late _CapturingAdapter adapter;
    late ApprovalsApi api;

    setUp(() {
      adapter = _CapturingAdapter();
      api = ApprovalsApi(
        Dio(BaseOptions(baseUrl: 'https://example.test'))
          ..httpClientAdapter = adapter,
      );
    });

    test('a destructive approve carries confirm_phrase verbatim', () async {
      // The whole outage in one assertion. Without this key the backend
      // returns 400 "To confirm this permanent deletion, type: delete 12" and
      // the approval stays pending forever.
      await api.decide(
        id: '9ba6585a',
        approved: true,
        confirmPhrase: 'delete 12',
      );

      expect(
        adapter.body!['confirm_phrase'],
        'delete 12',
        reason: 'The decision POST dropped the phrase, so the server refuses '
            'the delete no matter what the user does in the UI.',
      );
      expect(adapter.body!['approved'], isTrue);
    });

    test('it is echoed exactly, not rebuilt or normalized client-side',
        () async {
      // The server re-normalizes what it receives and accepts a superset
      // (`delete N`, `حذف N`, `احذف N`). Echoing its own string back is what
      // makes the client immune to the wording changing again — it has
      // already changed once, when the model name was dropped from it.
      await api.decide(
        id: 'x',
        approved: true,
        confirmPhrase: 'حذف ١٢',
      );
      expect(adapter.body!['confirm_phrase'], 'حذف ١٢');
    });

    test('a non-destructive approve sends no phrase key at all', () async {
      // Absent, not null. A `confirm_phrase: null` on an ordinary write is a
      // key the server never expects on that path.
      await api.decide(id: 'x', approved: true);
      expect(adapter.body!.containsKey('confirm_phrase'), isFalse);
    });

    test('a reject needs no phrase', () async {
      // Per the report: "reject (any approval): no phrase needed".
      await api.decide(id: 'x', approved: false);
      expect(adapter.body!.containsKey('confirm_phrase'), isFalse);
      expect(adapter.body!['approved'], isFalse);
    });

    test('a delete is never batched', () async {
      // The second, latent bug (§A.2): the server answers `scope: "batch"` on
      // a delete with 400 "Deletes must be approved one at a time", because a
      // batch scope matches on MODEL — batching a delete would pre-approve
      // deleting any record of that model.
      await api.decide(
        id: 'x',
        approved: true,
        confirmPhrase: 'delete 12',
      );
      expect(adapter.body!.containsKey('scope'), isFalse);
    });
  });

  group('the model reads what the server already sends', () {
    test('confirm_phrase and the delete operation are parsed', () {
      final approval = Approval.fromJson(_deleteApprovalJson);
      expect(approval.confirmPhrase, 'delete 12');
      expect(
        approval.isDestructiveDelete,
        isTrue,
        reason: 'Detected from `payload.operation == "delete"`, per §A.6 — '
            'never guessed from the prompt text.',
      );
    });

    test('an ordinary write is not a destructive delete', () {
      final approval = Approval.fromJson(const <String, dynamic>{
        'id': 'a',
        'action_type': 'odoo_write',
        'status': 'pending',
        'payload': {'operation': 'create', 'record_count': 3},
      });
      expect(approval.isDestructiveDelete, isFalse);
      expect(approval.confirmPhrase, isNull);
    });

    test('records are read from payload.records when present', () {
      final approval = Approval.fromJson(_deleteApprovalJson);
      expect(approval.deleteRecords, ['SO001/1', 'SO001/2']);
    });

    test('records fall back to record_ids when records[] is absent', () {
      // §A.6: "may be absent on some deletes" — the ids are the fallback list,
      // and showing `#6108` beats showing nothing before an irreversible act.
      final json = Map<String, dynamic>.from(_deleteApprovalJson);
      json['payload'] = {
        'operation': 'delete',
        'record_ids': [6108, 6109, 6110],
      };
      final approval = Approval.fromJson(json);
      expect(approval.deleteRecords, ['#6108', '#6109', '#6110']);
    });

    test('neither present degrades to an empty list, not a crash', () {
      final approval = Approval.fromJson(const <String, dynamic>{
        'id': 'a',
        'action_type': 'odoo_write',
        'status': 'pending',
        'payload': {'operation': 'delete'},
      });
      expect(approval.deleteRecords, isEmpty);
    });
  });

  group('the card — one red button, and nothing to type', () {
    Widget harness(Widget child, {Locale locale = const Locale('en')}) =>
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
          home: Scaffold(body: SingleChildScrollView(child: child)),
        );

    DemoApproval deleteApproval({int count = 12}) => DemoApproval(
          id: '9ba6585a',
          title: 'Delete records',
          prompt: 'Delete 12 records from Sales Order Line',
          actionType: 'odoo_write',
          risk: 'high',
          status: DemoApprovalStatus.pending,
          payload: const {'operation': 'delete', 'model': 'sale.order.line'},
          recordCount: count,
          confirmPhrase: 'delete $count',
          deleteRecords: const ['SO001/1', 'SO001/2', 'SO001/3'],
        );

    testWidgets('there is no text field to type a phrase into', (tester) async {
      // The product decision of 2026-08-17: "the user must NOT type anything."
      // Typing `delete 12` proved too hard for real users — it is what caused
      // the outage.
      await tester.pumpWidget(
        harness(
          ChatApprovalCard(
            approval: deleteApproval(),
            onApprove: () {},
            onReject: () {},
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(TextField), findsNothing);
    });

    testWidgets('one tap approves — no dialog stands in the way',
        (tester) async {
      var approvals = 0;
      await tester.pumpWidget(
        harness(
          ChatApprovalCard(
            approval: deleteApproval(),
            onApprove: () => approvals++,
            onReject: () {},
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.text('Delete 12'));
      await tester.pumpAndSettle();

      expect(
        approvals,
        1,
        reason: 'The red button did not fire. It must approve directly — the '
            'informed consent is the count in its own label plus the record '
            'list above it, not a modal.',
      );
    });

    testWidgets('the button names the count, so the user sees how many die',
        (tester) async {
      // §A.3: the count stays in the button label — "that is the
      // informed-consent that used to live in the typed count".
      await tester.pumpWidget(
        harness(
          ChatApprovalCard(
            approval: deleteApproval(count: 7),
            onApprove: () {},
            onReject: () {},
          ),
        ),
      );
      await tester.pump();
      expect(find.text('Delete 7'), findsOneWidget);
    });

    testWidgets('the records are listed for review', (tester) async {
      await tester.pumpWidget(
        harness(
          ChatApprovalCard(
            approval: deleteApproval(),
            onApprove: () {},
            onReject: () {},
          ),
        ),
      );
      await tester.pump();
      expect(find.textContaining('SO001/1'), findsWidgets);
      expect(find.textContaining('SO001/3'), findsWidgets);
    });

    testWidgets('"Approve all" is never offered on a delete', (tester) async {
      // §A.2 — the server 400s a batched delete outright.
      var batched = 0;
      await tester.pumpWidget(
        harness(
          ChatApprovalCard(
            approval: deleteApproval(),
            onApprove: () {},
            onReject: () {},
            onApproveAllSimilar: () => batched++,
          ),
        ),
      );
      await tester.pump();
      expect(find.text('Approve all similar'), findsNothing);
      expect(batched, 0);
    });

    testWidgets('the Arabic card still offers one button and no field',
        (tester) async {
      // The outage was reported by an Arabic-speaking user, and the previous
      // design asked them to type an English string.
      await tester.pumpWidget(
        harness(
          ChatApprovalCard(
            approval: deleteApproval(),
            onApprove: () {},
            onReject: () {},
          ),
          locale: const Locale('ar'),
        ),
      );
      await tester.pump();
      expect(find.byType(TextField), findsNothing);
      expect(find.textContaining('12'), findsWidgets);
    });

    testWidgets('an ordinary write keeps the normal Approve button',
        (tester) async {
      // Only `operation == "delete"` changes — everything else keeps the
      // Approve/Reject (and batching) it already had.
      var approvals = 0;
      await tester.pumpWidget(
        harness(
          ChatApprovalCard(
            approval: const DemoApproval(
              id: 'a',
              title: 'Create records',
              prompt: 'Create 3 records',
              actionType: 'odoo_write',
              risk: 'medium',
              status: DemoApprovalStatus.pending,
              payload: {'operation': 'create'},
              recordCount: 3,
            ),
            onApprove: () => approvals++,
            onReject: () {},
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Approve'), findsOneWidget);
      await tester.tap(find.text('Approve'));
      await tester.pumpAndSettle();
      expect(approvals, 1);
    });
  });
}

/// §B.7 — the sources / download footers the server bakes into message
/// markdown are frequently ROOT-RELATIVE, and a launcher that only accepts
/// `http(s)` refused every one of them.
void _linkResolverTests() {
  group('§B.7 — a relative download link resolves instead of being copied',
      () {
    test('a /media path becomes an absolute URL on the API host', () {
      final uri = resolveMarkdownLink('/media/exports/report.xlsx');
      expect(uri, isNotNull);
      expect(
        uri!.scheme,
        anyOf('http', 'https'),
        reason: 'A relative href kept its empty scheme, so the launcher '
            'refused it and the user got a path fragment on their clipboard '
            'instead of their file.',
      );
      expect(uri.path, '/media/exports/report.xlsx');
    });

    test('an /artifacts path resolves the same way', () {
      final uri = resolveMarkdownLink('/artifacts/9ba6585a/output.pdf');
      expect(uri!.scheme, anyOf('http', 'https'));
      expect(uri.path, '/artifacts/9ba6585a/output.pdf');
    });

    test('an absolute http(s) link is left exactly alone', () {
      final uri = resolveMarkdownLink('https://example.test/a/b.pdf');
      expect(uri.toString(), 'https://example.test/a/b.pdf');
    });

    test('a non-http scheme is not rewritten into one', () {
      // The web allows http(s) + relative and blocks everything else. Turning
      // `javascript:` into an absolute URL would be inventing a link the
      // server never sent.
      for (final href in ['mailto:a@b.test', 'javascript:alert(1)']) {
        expect(resolveMarkdownLink(href)!.scheme, isNot(anyOf('http', 'https')),
            reason: href);
      }
    });

    test('a bare relative name is left alone rather than guessed at', () {
      // `report.xlsx` has no base to resolve against — the message carries
      // none — so guessing would produce a plausible URL pointing somewhere
      // wrong, which is worse than falling back to copy.
      expect(resolveMarkdownLink('report.xlsx')!.hasScheme, isFalse);
    });
  });
}
